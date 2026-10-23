# frozen_string_literal: true

require_relative "support/reporter_test_case"
require "stringio"
require "timeout"
load File.expand_path("../bin/ip-quality-route", __dir__) unless defined?(IpQuality::RouteCommand)

class PrefixSampleTest < ReporterTestCase
  Result = Struct.new(:exitstatus) do
    def success?
      exitstatus == 0
    end
  end

  def test_three_octets_and_explicit_networks_deduplicate_before_sampling
    batch = IpQuality::PrefixSample.new("128.241.47\n154.43.44.0/24，128.241.47.0/24\u00a0154.43.44\n")
    assert_equal %w[128.241.47.23 128.241.47.127 128.241.47.231 154.43.44.23 154.43.44.127 154.43.44.231], batch.samples.map { |row| row["ip"] }
    assert_equal ["128.241.47.0/24", "154.43.44.0/24"], batch.samples.map { |row| row["prefix"] }.uniq
    assert_nil batch.summary.dig("sampling", "whole_prefix_verdict")
    assert_equal false, batch.summary.dig("sampling", "node_connectivity_tested")
  end

  def test_rejects_incomplete_ambiguous_reserved_and_unbounded_inputs
    ["", "美国", "128.241", "128.241.47.23", "128.241.47.1/24", "128.241.47.0/16",
     "128.024.47", "256.1.1", "2001:4860::", "8.8.8;touch x", "8.8.8\e[31m",
     (1..21).map { |n| "8.8.#{n}" }.join("\n"), "8.8.8 " * 1000,
     "bad\xff".dup.force_encoding("UTF-8")].each do |input|
      assert_raises(IpQuality::PrefixSample::Error) { IpQuality::PrefixSample.new(input) }
    end
    IpQuality::PrefixSample::NON_PUBLIC.each do |network|
      prefix = network.to_s.split(".").first(3).join(".")
      assert_raises(IpQuality::PrefixSample::Error) { IpQuality::PrefixSample.new(prefix) }
    end
    # Both entrypoints read ref/non_public_ipv4.txt; compare them at every range
    # edge and at the neighbouring addresses just outside it.
    edges = IpQuality::PrefixSample::NON_PUBLIC.flat_map do |network|
      first = network.to_range.first.to_i
      last = network.to_range.last.to_i
      [first - 1, first, last, last + 1].select { |value| value.between?(0, 2**32 - 1) }
    end.uniq.map { |value| IPAddr.new(value, Socket::AF_INET).to_s }
    stdout, errors, result = Open3.capture3("/bin/zsh", "-f", "-c",
      'source "$1"; shift; for ip in "$@";do is_private_ipv4 "$ip"&&print -r -- "$ip private"||print -r -- "$ip public";done',
      "boundary", SCRIPT, *edges)
    assert result.success?, errors
    expected = edges.map do |ip|
      address = IPAddr.new(ip)
      "#{ip} #{IpQuality::PrefixSample::NON_PUBLIC.any? { |range| range.include?(address) } ? 'private' : 'public'}"
    end
    assert_equal expected, stdout.lines(chomp: true)
    assert_includes expected, "100.63.255.255 public"
    assert_includes expected, "198.20.0.0 public"
    assert_equal 60, IpQuality::PrefixSample.new((1..20).map { |n| "8.8.#{n}" }.join(" ")).samples.length
  end

  def test_menu_plan_needs_neither_clash_cache_nor_consent_and_creates_no_report
    with_command("3\n128.241.47\n154.43.44\n\n") do |command, directory, out, err|
      assert_equal 0, command.run(["-4", "--ipqs-dns", "system"])
      assert_includes out.string, "6 個樣本"
      assert_includes out.string, "128.241.47.231"
      assert_includes out.string, "No network access has occurred"
      assert_includes out.string, "sources: all"
      assert_includes out.string, "IPQS DNS policy: system"
      assert_includes out.string, "    DB-IP: not applicable to an explicit target"
      assert_includes out.string, "    Ping0: not applicable to an explicit target"
      assert_includes err.string, "Cached subscriptions unavailable"
      refute File.exist?(File.join(directory, "reports"))
    end
  end

  def test_bad_input_or_conflicting_options_stop_before_starting_any_sample
    [["3\n128.241.47\n10.1.2\n\n", []], ["3\n\n", []],
     ["3\n128.241.47\n\n", ["-6"]], ["3\n", ["-j"]], ["3\n", ["-o", "/unused"]]].each do |input, flags|
      with_command(input) do |command, directory, _out, _err|
        assert_equal 64, command.run(["--confirm-network-lookup", *flags])
        refute File.exist?(File.join(directory, "reports"))
      end
    end
  end

  def test_real_runner_uses_exact_targets_clears_proxies_and_saves_private_reports
    with_command("3\n128.241.47\n\n") do |command, directory, out, err|
      fake = File.join(directory, "reporter")
      File.write(fake, <<~'ZSH')
        [[ -z "${HTTP_PROXY+x}${https_proxy+x}${No_PrOxY+x}" ]] || exit 71
        [[ "$*" == *'--confirm-network-lookup --scope reputation -4'* ]] || exit 72
        args=("$@")
        for (( i=1; i<=$#args; i++ ));do
          [[ "${args[$i]}" == -o ]] && output="${args[$((i+1))]}"
        done
        ip="${args[-1]}"
        umask 077
        print -r -- "report for $ip" > "$output"
        print -ru2 -- "fixture progress"
        jq -n --arg ip "$ip" '{Head:{IP:$ip},Query:{TargetMode:"explicit_target"},
          Score:{IPQS:"0",ipapi:null,AbuseIPDB:"0"},ProviderStatus:{IPQS:"ok",ipapi:"timeout",AbuseIPDB:"ok",DBIP:"not_applicable_target"},
          Factor:{Proxy:{IPQS:false},VPN:{IPQS:true}},ProviderContext:{Cloudflare:{Status:"ok",CountryCode:"US",Network:"AS64500"}},
          Ping0:{Status:"not_applicable_target"},Routing:{Status:"announced"},Exposure:{Status:"available"}}
          | if ($ip | endswith(".231")) then .Score.ipapi="0.14%" | .ProviderStatus.ipapi="ok"
            | .ProviderStatus.IPQS="tls_error" else . end'
      ZSH
      env = {"HTTP_PROXY" => "http://127.0.0.1:1", "https_proxy" => "http://127.0.0.1:2", "No_PrOxY" => "invalid"}
      saved = env.keys.to_h { |key| [key, ENV[key]] }
      begin
        env.each { |key, value| ENV[key] = value }
        assert_equal 0, command.run(["--confirm-network-lookup", "-4"]), err.string
      ensure
        saved.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
      end
      batch_dir = Dir.glob(File.join(directory, "reports", "prefix-samples-*")).fetch(0)
      assert_equal 0o700, File.stat(batch_dir).mode & 0o777
      Dir.children(batch_dir).each { |name| assert_equal 0o600, File.stat(File.join(batch_dir, name)).mode & 0o777 }
      data = JSON.parse(File.read(File.join(batch_dir, "summary.json")))
      assert_equal "partial", data.fetch("status")
      assert_equal %w[128.241.47.23 128.241.47.127 128.241.47.231], data.fetch("samples").map { |row| row["ip"] }
      assert_includes out.string, "0 | — (unknown) | — (timeout) | 0"
      assert_includes out.string, "否 / 是"
      assert_includes out.string, "US / AS64500"
      assert_includes out.string, "ipapi=timeout"
      assert_includes out.string, "DBIP=not_applicable_target"
      assert_includes out.string, "0.14%"
      assert_includes out.string, "— (tls_error)"
      assert_nil data.fetch("samples").last["ipqs_flags"]
      assert_empty Dir.glob(File.join(batch_dir, "*.part"))
    end
  end

  def test_reporter_failure_bad_json_and_wrong_target_remain_unknown_and_do_not_stop_later_samples
    ["bad json", {"Head" => {"IP" => "8.8.8.8"}, "Query" => {"TargetMode" => "explicit_target"}}, []].each do |bad|
      Dir.mktmpdir("prefix-evidence-") do |directory|
        batch = IpQuality::PrefixSample.new("128.241.47")
        calls = []
        result = batch.run(reports_root: File.join(directory, "reports"), stdout: StringIO.new, stderr: StringIO.new) do |ip, output, _err, _text|
          calls << ip
          output.write(bad.is_a?(String) ? bad : JSON.generate(bad))
          Result.new(ip.end_with?(".127") ? 37 : 0)
        end
        assert_equal 1, result
        assert_equal 3, calls.length
        assert_equal %w[invalid_report reporter_failed invalid_report], batch.samples.map { |row| row["status"] }
        assert_includes batch.markdown, "— (reporter_failed)"
        assert_nil batch.samples[0]["scores"]
      end
    end
  end

  def test_interrupt_retains_completed_evidence_and_marks_unstarted_samples
    Dir.mktmpdir("prefix-interrupt-") do |directory|
      batch = IpQuality::PrefixSample.new("128.241.47")
      assert_raises(Interrupt) do
        batch.run(reports_root: File.join(directory, "reports"), stdout: StringIO.new, stderr: StringIO.new) do |ip, output, _err, _text|
          raise Interrupt if ip.end_with?(".127")

          output.write(JSON.generate("Head" => {"IP" => ip}, "Query" => {"TargetMode" => "explicit_target"},
            "Score" => {"IPQS" => "95"}, "ProviderStatus" => {"IPQS" => "tls_error"}))
          Result.new(0)
        end
      end
      data = JSON.parse(File.read(File.join(batch.directory, "summary.json")))
      assert_equal "interrupted", data["status"]
      assert_equal %w[partial interrupted pending], data["samples"].map { |row| row["status"] }
      assert_includes batch.markdown, "— (tls_error)"
      refute_includes batch.markdown, "| 95 |"
    end
  end

  def test_report_directory_rejects_links_without_running_reporter
    Dir.mktmpdir("prefix-path-") do |directory|
      linked = File.join(directory, "reports")
      destination = File.join(directory, "other")
      Dir.mkdir(destination, 0o700)
      File.symlink(destination, linked)
      batch = IpQuality::PrefixSample.new("128.241.47")
      assert_raises(IpQuality::SafeSnapshot::Error) do
        batch.run(reports_root: linked, stdout: StringIO.new, stderr: StringIO.new) { flunk "reporter must not run" }
      end
      assert_empty Dir.children(destination)
    end
  end

  def test_sigterm_stops_active_sample_and_preserves_batch_without_starting_next_target
    Dir.mktmpdir("prefix-signal-") do |directory|
      reporter = File.join(directory, "reporter")
      pid_path = File.join(directory, "reporter.pid")
      File.write(reporter, <<~'ZSH')
        print -r -- $$ > "$IPQUALITY_TEST_PID"
        while true;do /bin/sleep 1;done
      ZSH
      program = <<~'RUBY'
        require 'stringio'
        load ARGV.shift
        root = ARGV.shift
        command = IpQuality::RouteCommand.new(stdin: StringIO.new("3\n128.241.47\n\n"),
          app_root: File.join(root, 'absent-clash'), reporter_path: File.join(root, 'reporter'),
          reports_root: File.join(root, 'reports'))
        exit command.run(['--confirm-network-lookup', '-4'])
      RUBY
      pid = Process.spawn({"IPQUALITY_TEST_PID" => pid_path}, "/usr/bin/ruby", "--disable-gems", "-e", program,
        File.join(ROOT, "bin/ip-quality-route"), directory, out: File::NULL, err: File::NULL)
      begin
        Timeout.timeout(10) { sleep 0.02 until File.file?(pid_path) && !File.read(pid_path).empty? }
        child = Integer(File.read(pid_path))
        Process.kill("TERM", pid)
        _, status = Timeout.timeout(10) { Process.wait2(pid) }
        pid = nil
        assert_equal 130, status.exitstatus
        assert_raises(Errno::ESRCH) { Process.kill(0, child) }
        path = Dir.glob(File.join(directory, "reports", "*", "summary.json")).fetch(0)
        data = JSON.parse(File.read(path))
        assert_equal "interrupted", data["status"]
        assert_equal %w[interrupted pending pending], data["samples"].map { |row| row["status"] }
        assert_equal 1, Dir.glob(File.join(File.dirname(path), "*.stderr")).length
      ensure
        if pid
          Process.kill("KILL", pid) rescue Errno::ESRCH
          Process.waitpid(pid) rescue Errno::ECHILD
        end
        Process.kill("KILL", -child) rescue Errno::ESRCH if child
      end
    end
  end

  def test_dbip_explicit_targets_skip_both_visitor_requests_and_show_inapplicable_status
    stdout, stderr, status = run_script("--sources", "dbip,ping0", "--confirm-network-lookup", "-4", "-j", "8.8.8.8")
    assert status.success?, stderr
    report = JSON.parse(stdout)
    assert_equal "not_applicable_target", report.dig("ProviderStatus", "DBIP")
    assert_equal "not_applicable_target", report.dig("ScoreMeta", "DBIP", "Status")
    assert_nil report.dig("Score", "DBIP")
    assert_equal "not_applicable_target", report.dig("Ping0", "Status")
    stdout, errors, result = run_script("--sources", "dbip", "--confirm-network-lookup", "-4", "8.8.8.8")
    assert result.success?, errors
    assert_includes stdout, "不支持指定 IP"
    refute File.exist?(File.join(reporter_workspace, "network-attempts"))
  end

  private

  def with_command(input)
    Dir.mktmpdir("prefix-command-") do |directory|
      out = StringIO.new
      err = StringIO.new
      command = IpQuality::RouteCommand.new(stdin: StringIO.new(input), stdout: out, stderr: err,
        app_root: File.join(directory, "absent-clash"), reporter_path: File.join(directory, "reporter"),
        reports_root: File.join(directory, "reports"))
      yield command, directory, out, err
    end
  end
end
