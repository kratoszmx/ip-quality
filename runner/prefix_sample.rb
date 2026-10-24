# frozen_string_literal: true

require "ipaddr"
require "json"
require "time"
require "tmpdir"
require_relative "safe_snapshot"
require_relative "source_catalog"

module IpQuality
  # Target sampling policy and local batch evidence, not a network scanner.
  # Process ownership/termination stays with RouteCommand.
  class PrefixSample
    class Error < StandardError; end

    MAX_PREFIXES = 20
    MAX_INPUT_BYTES = 4096
    HOST_OCTETS = [23, 127, 231].freeze
    # The reporter reads the same list, so both reject one public-IPv4 boundary.
    NON_PUBLIC = File.readlines(File.expand_path("../ref/non_public_ipv4.txt", __dir__), chomp: true)
      .reject { |line| line.empty? || line.start_with?("#") }
      .map { |cidr| IPAddr.new(cidr) }.freeze
    SCORE_SOURCES = {"IPQS" => "IPQS", "SCAMALYTICS" => "Scamalytics",
      "ipapi" => "ipapi", "AbuseIPDB" => "AbuseIPDB", "IP2LOCATION" => "IP2Location"}.freeze
    NON_FAILURE = %w[ok verified available announced not_announced not_found disabled not_applicable_target not_provided].freeze

    attr_reader :samples, :directory

    def initialize(input, sources: "all", ipqs_dns: "auto")
      raise Error, "prefix input is too large" if input.bytesize > MAX_INPUT_BYTES
      raise Error, "prefix input must be valid UTF-8 text" unless input.valid_encoding?

      entries = input.split(/[[:space:],，]+/).reject(&:empty?)
      raise Error, "enter at least one IPv4 prefix" if entries.empty?

      prefixes = entries.map do |entry|
        match = /\A((?:0|[1-9][0-9]{0,2})\.(?:0|[1-9][0-9]{0,2})\.(?:0|[1-9][0-9]{0,2}))(?:\.0\/24)?\z/.match(entry)
        raise Error, "use three IPv4 octets or a network ending in .0/24" unless match

        prefix = match[1]
        raise Error, "IPv4 octets must be between 0 and 255" unless prefix.split(".").all? { |part| part.to_i <= 255 }
        address = IPAddr.new("#{prefix}.23")
        raise Error, "prefixes must contain public IPv4 addresses" if NON_PUBLIC.any? { |range| range.include?(address) }

        prefix
      end.uniq
      raise Error, "at most #{MAX_PREFIXES} distinct prefixes per run" if prefixes.length > MAX_PREFIXES

      @sources = sources
      @ipqs_dns = ipqs_dns
      @samples = prefixes.flat_map do |prefix|
        HOST_OCTETS.map { |host| {"prefix" => "#{prefix}.0/24", "ip" => "#{prefix}.#{host}", "status" => "pending"} }
      end
      @state = "planned"
      @created_at = Time.now.iso8601
    end

    def plan
      lines = ["IPv4 /24 sampling plan / 網段抽樣計畫",
        "  #{samples.length / 3} 段，共 #{samples.length} 個樣本；每段固定 .23、.127、.231（不代表整段，也不是節點連線或速度測試）。",
        "  targets: #{samples.map { |sample| sample.fetch('ip') }.join(', ')}",
        "  sources: #{@sources}; providers receive each target plus the system-route egress.",
        "  route: current system IPv4 route; inherited proxies removed; live Clash state unchanged.",
        "  IPQS DNS policy: #{@ipqs_dns}; auto/alidns use verified AliDNS HTTPS (hostname only, not key or target).",
        "  reputation sources:", *SourceCatalog.disclosure_lines(@sources, explicit_target: true),
        "  本機保存完整樣本 IP、各來源結果及失敗狀態；依序查詢，會消耗現有 API 額度，不自動重跑失敗樣本。"]
      lines.join("\n") + "\n"
    end

    def run(reports_root:, stdout:, stderr:)
      parent = File.expand_path(reports_root)
      SafeSnapshot.verify_directory(File.dirname(parent))
      begin
        Dir.mkdir(parent, 0o700)
      rescue Errno::EEXIST
        # Existing report roots are checked, not replaced or chmod'ed.
      end
      SafeSnapshot.verify_directory(parent)
      @directory = Dir.mktmpdir("prefix-samples-#{Time.now.strftime('%Y%m%d-%H%M%S')}-", parent)
      @state = "running"
      stderr.puts "Local reports / 本機報告：#{directory}"
      save_summary
      samples.each_with_index do |sample, index|
        stderr.puts "[#{index + 1}/#{samples.length}] #{sample.fetch('ip')} ..."
        sample["status"] = "running"
        sample["report"] = "#{sample.fetch('ip')}.json"
        sample["text_report"] = "#{sample.fetch('ip')}.txt"
        sample["log"] = "#{sample.fetch('ip')}.stderr"
        save_summary
        result = nil
        open_new(sample.fetch("report")) do |output|
          open_new(sample.fetch("log")) do |errors|
            result = yield(sample.fetch("ip"), output, errors, File.join(directory, sample.fetch("text_report")))
          end
        end
        sample["exit_status"] = result.exitstatus
        sample["checked_at"] = Time.now.iso8601
        sample["status"] = result.success? ? "ok" : "reporter_failed"
        read_observation(sample) if result.success?
        save_summary
        stderr.puts "[#{index + 1}/#{samples.length}] #{sample.fetch('ip')}: #{sample.fetch('status')}"
      end
      @state = samples.all? { |sample| sample["status"] == "ok" } ? "completed" : "partial"
      save_summary
      stdout.puts markdown
      stdout.puts "完整報告及來源狀態：#{File.join(directory, 'summary.md')}"
      # Source failures are valid unknown observations; a broken reporter is not.
      samples.all? { |sample| %w[ok partial].include?(sample["status"]) } ? 0 : 1
    rescue Interrupt
      @state = "interrupted"
      samples.each { |sample| sample["status"] = "interrupted" if sample["status"] == "running" }
      save_summary if directory
      raise
    end

    def summary
      {"schema_version" => 1, "created_at" => @created_at, "status" => @state,
       "query_route" => "system_ipv4_without_proxy_environment", "sources" => @sources, "ipqs_dns_policy" => @ipqs_dns,
       "sampling" => {"assumed_prefix_length" => 24, "host_octets" => HOST_OCTETS,
         "whole_prefix_verdict" => nil, "node_connectivity_tested" => false},
       "not_applicable" => {"DBIP" => "visitor_egress_only", "Ping0" => "visitor_egress_only"},
       "samples" => samples}
    end

    def markdown
      lines = ["# IPv4 /24 網段抽樣", "", "時間：#{@created_at}；批次狀態：#{@state}", "",
        "每段抽查 .23、.127、.231。結果只適用於列出的樣本與查詢時間，不代表整段或實際分配的 IP。",
        "這是第三方資料庫查詢，沒有以樣本 IP 作為出口，也不測試連線、速度或網站解鎖。", "",
        "各平台獨立計分；ipapi % 為公司網路的濫用比例，非單一 IP 詐欺機率。未知與失敗不當作 0／否。",
        "DB-IP、Ping0 僅支援查詢連線出口，在本模式不發請求。", "",
        "| 樣本 IP | 國別 / ASN | IPQS /100 | Scamalytics /100 | ipapi % | AbuseIPDB /100 | IP2Location /99 | IPQS 代理 / VPN | 狀態 |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
      samples.each do |sample|
        cells = [sample.fetch("ip"), sample["network"] || "—"]
        SCORE_SOURCES.each { |score, provider| cells << score_cell(sample, score, provider) }
        cells << %w[proxy vpn].map { |flag| boolean_cell(sample.dig("ipqs_flags", flag)) }.join(" / ")
        cells << sample.fetch("status")
        lines << "| #{cells.map { |cell| cell_text(cell) }.join(' | ')} |"
      end
      lines.concat(["", "## 查詢狀態與逐筆報告", ""])
      samples.each do |sample|
        statuses = (sample["provider_status"] || {}).map { |name, status| "#{name}=#{status}" }.join("; ")
        report = sample["report"] ? "[JSON](#{sample.fetch('report')}) · [文字](#{sample.fetch('text_report')}) · [log](#{sample.fetch('log')})" : "未執行"
        lines << "- #{sample.fetch('ip')}：#{report}；#{cell_text(statuses.empty? ? sample.fetch('status') : statuses)}"
      end
      lines.join("\n") + "\n"
    end

    private

    def read_observation(sample)
      path = File.join(directory, sample.fetch("report"))
      report = JSON.parse(SafeSnapshot.read(path, allowed_modes: [0o600], max_bytes: 2 * 1024 * 1024).bytes)
      valid = report.is_a?(Hash) && report["Head"].is_a?(Hash) && report["Query"].is_a?(Hash) &&
        report.dig("Head", "IP") == sample.fetch("ip") && report.dig("Query", "TargetMode") == "explicit_target" &&
        report["Score"].is_a?(Hash) && report["ProviderStatus"].is_a?(Hash) &&
        report["ProviderStatus"].values.all? { |value| value.is_a?(String) }
      unless valid
        sample["status"] = "invalid_report"
        return
      end
      sample["scores"] = report.fetch("Score")
      sample["provider_status"] = report.fetch("ProviderStatus").dup
      {"Ping0" => "Ping0", "RIPEstat" => "Routing", "Shodan" => "Exposure"}.each do |name, key|
        sample["provider_status"][name] = report.dig(key, "Status") || "unknown"
      end
      if sample.dig("provider_status", "IPQS") == "ok"
        sample["ipqs_flags"] = {"proxy" => report.dig("Factor", "Proxy", "IPQS"), "vpn" => report.dig("Factor", "VPN", "IPQS")}
      end
      sample["query"] = report.fetch("Query")
      context = report.dig("ProviderContext", "Cloudflare")
      if context.is_a?(Hash) && context["Status"] == "ok"
        sample["network"] = [context["CountryCode"], context["Network"]].compact.join(" / ")
      else
        context = report.dig("ProviderContext", "IPWhois")
        if context.is_a?(Hash) && context["Status"] == "ok"
          sample["network"] = [context["CountryCode"], context["ASN"] && "AS#{context['ASN']}"].compact.join(" / ")
        end
      end
      sample["status"] = "partial" if sample.fetch("provider_status").values.any? { |value| !NON_FAILURE.include?(value) }
    rescue JSON::ParserError, TypeError, SafeSnapshot::Error
      %w[scores provider_status ipqs_flags query network].each { |key| sample.delete(key) }
      sample["status"] = "invalid_report"
    end

    def score_cell(sample, score, provider)
      status = sample.dig("provider_status", provider)
      fallback = %w[ok partial].include?(sample["status"]) ? "unknown" : sample.fetch("status")
      return "— (#{status || fallback})" unless status == "ok"

      value = sample.dig("scores", score)
      pattern = score == "ipapi" ? /\A[0-9]+(?:\.[0-9]+)?%?\z/ : /\A[0-9]+(?:\.[0-9]+)?\z/
      value.to_s.match?(pattern) ? value : "—"
    end

    def boolean_cell(value)
      return "是" if value == true
      return "否" if value == false

      "—"
    end

    def cell_text(value)
      value.to_s.gsub(/[[:cntrl:]|<>]/, " ").gsub("`", "'")
    end

    def open_new(filename, &block)
      File.open(File.join(directory, filename), File::WRONLY | File::CREAT | File::EXCL, 0o600, &block)
    end

    def save_summary
      {"summary.json" => JSON.pretty_generate(summary) + "\n", "summary.md" => markdown}.each do |filename, content|
        # Only replace our own batch files; no user-selected output path.
        staging = "#{filename}.part"
        begin
          open_new(staging) { |file| file.write(content) }
          File.rename(File.join(directory, staging), File.join(directory, filename))
        ensure
          File.unlink(File.join(directory, staging)) if File.exist?(File.join(directory, staging))
        end
      end
    end
  end
end
