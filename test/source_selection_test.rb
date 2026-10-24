# frozen_string_literal: true

require_relative "support/reporter_test_case"

class SourceSelectionTest < ReporterTestCase
  parallelize_me!

  def test_presets_and_custom_lists_are_network_free_and_reject_invalid_ids
    stdout, stderr, status = run_script("--sources", "independent")
    assert status.success?, stderr
    assert_includes stdout, "no Check.Place requests"
    assert_includes stdout, "selected source IDs: ipinfo,ipregistry,ipapi,ipwhois,dbip,cloudflare,ipqs,ping0,ripestat,shodan"
    stdout, stderr, status = run_script("--sources=ipapi,ipqs,ipapi", "--confirm-network-lookup", "--plan")
    assert status.success?, stderr
    assert_includes stdout, "selected source IDs: ipapi,ipqs\n"
    ["", "ipapi,", ",ipapi", "ipapi,,ipqs", "bogus", "ipapi,all", "IPQS", "ipapi;id"].each do |selection|
      _out, _err, result = run_script("--sources", selection, "--confirm-network-lookup")
      assert_equal 64, result.exitstatus, selection
    end
  end

  def test_runner_and_reporter_accept_the_same_source_ids_and_forward_choices
    stdout, stderr, status = zsh(<<~'ZSH', provider_library("selection"))
      source "$1"
      print -r -- "${(j:,:)reputation_source_ids}"
    ZSH
    assert status.success?, stderr
    assert_equal IpQuality::SourceCatalog::IDS, stdout.strip.split(",")

    Dir.mktmpdir("source-runner-") do |directory|
      arguments = File.join(directory, "arguments")
      reporter = File.join(directory, "reporter")
      File.write(reporter, 'print -rl -- "$@" > "$IPQUALITY_TEST_ARGUMENTS"' + "\n")
      code = <<~'RUBY'
        load ARGV.shift
        command = IpQuality::RouteCommand.new(reporter_path: ARGV.shift)
        exit command.run(ARGV)
      RUBY
      _out, err, result = Open3.capture3({"IPQUALITY_TEST_ARGUMENTS" => arguments},
        "/usr/bin/ruby", "--disable-gems", "-e", code, RUNNER, reporter,
        "--direct", "--sources", "ipapi,ipqs", "--ipqs-dns", "alidns", "--confirm-network-lookup")
      assert result.success?, err
      assert_equal %w[--confirm-network-lookup --scope reputation -4 --sources ipapi,ipqs --ipqs-dns alidns], File.readlines(arguments, chomp: true)
    end
  end

  def test_explicit_ipqs_doh_requires_direct_selection_and_never_changes_proxy_dns
    stdout, stderr, status = run_script("--ipqs-dns", "alidns", "--sources", "ipqs", env: NO_PROXY_ENV)
    assert status.success?, stderr
    assert_includes stdout, "https://dns.alidns.com/dns-query"
    assert_includes stdout, "not the API key or target"
    [{"HTTPS_PROXY" => "http://127.0.0.1:1"}, {"IPQUALITY_ISOLATED_EGRESS" => "1"}].each do |proxy_env|
      _out, err, result = run_script("--ipqs-dns", "alidns", "--confirm-network-lookup", env: NO_PROXY_ENV.merge(proxy_env))
      assert_equal 64, result.exitstatus
      assert_includes err, "direct route"
    end
    _out, _err, result = run_script("--ipqs-dns", "invalid")
    assert_equal 64, result.exitstatus
  end

  def test_default_full_run_repairs_direct_ipv4_dns_and_uses_scamalytics_page_after_relay_failure
    calls = File.join(reporter_workspace, "curl-arguments")
    page = File.join(reporter_workspace, "page.html")
    text_path = File.join(reporter_workspace, "report.txt")
    File.write(page, File.read(fixture_path("scamalytics/public-page.html")).gsub("198.51.100.23", "12.217.32.68"))
    write_ipqs_key
    write_fake_command("curl", <<~'ZSH')
      print -rl -- "$@" >> "$IPQUALITY_TEST_CALLS"
      request=$(cat)
      if [[ "$request" == *"/api/json/account/"* ]];then
        print -rn -- $'{"success":true,"credits":100,"usage":1}\n200'
      elif [[ "$request" == *"/api/json/ip/fixturekey123/12.217.32.68?"* ]];then
        print -r -- "$(<"$IPQUALITY_TEST_RESPONSE")"
        print -rn -- 200
      elif [[ "$*" == *'https://scamalytics.com/ip/12.217.32.68'* ]];then
        print -r -- "$(<"$IPQUALITY_TEST_PAGE")"
        print -rn -- 200
      elif [[ "$*" == *'https://ipinfo.check.place/'* ]];then
        print -rn -- $'Sorry, you have been blocked by Cloudflare\n403'
      else
        print -rn -- $'\n000'
        exit 35
      fi
    ZSH
    stdout, stderr, status = run_script("--confirm-network-lookup", "-4", "-j", "-o", text_path,
      "12.217.32.68", env: NO_PROXY_ENV.merge("IPQUALITY_TEST_CALLS" => calls,
        "IPQUALITY_TEST_RESPONSE" => IPQS_FIXTURE, "IPQUALITY_TEST_PAGE" => page))
    assert status.success?, stderr
    report = JSON.parse(stdout)
    assert_equal "all", report.dig("Query", "SourceSelection")
    assert_equal IpQuality::SourceCatalog::IDS, report.dig("Query", "SelectedSources")
    refute_includes report.fetch("ProviderStatus").values, "disabled"
    assert_equal "alidns", report.dig("Query", "IPQSDNS")
    assert_equal "ok", report.dig("ProviderStatus", "IPQS")
    assert_equal "87", report.dig("Score", "IPQS")
    assert_equal "ok", report.dig("ProviderStatus", "Scamalytics")
    assert_equal "0", report.dig("Score", "SCAMALYTICS")
    assert_equal "public_demo", report.dig("ScoreMeta", "SCAMALYTICS", "Source")
    assert_equal "skipped_relay_cloudflare_blocked", report.dig("ScoreMeta", "SCAMALYTICS", "RelayStatus")
    assert_equal "public_demo", report.dig("FactorMeta", "SCAMALYTICS", "Source")
    assert_equal false, report.dig("Factor", "Proxy", "SCAMALYTICS")
    arguments = File.readlines(calls, chomp: true)
    assert_equal 2, arguments.count("--doh-url")
    assert_equal 1, arguments.count("https://scamalytics.com/ip/12.217.32.68")
    assert_equal 1, arguments.count { |value| value.start_with?("https://ipinfo.check.place/") }
    refute_includes File.read(calls), "fixturekey123"
    assert_includes File.read(text_path), "公开示例/可用"
    %w[IP2Location AbuseIPDB ipdata IPQS Scamalytics].each { |name| assert_includes File.read(text_path), name }
  end

  def test_automatic_dns_keeps_proxy_ipv6_and_explicit_system_routes_unchanged
    calls = File.join(reporter_workspace, "calls")
    write_ipqs_key
    write_fake_command("curl", <<~'ZSH')
      print -rl -- "$@" >> "$IPQUALITY_TEST_CALLS"
      print -r -- "proxy=${HTTPS_PROXY:-none},isolated=${IPQUALITY_ISOLATED_EGRESS:-none}" >> "$IPQUALITY_TEST_CALLS"
      request=$(cat)
      if [[ "$request" == *"/api/json/account/"* ]];then
        print -rn -- $'{"success":true,"credits":100,"usage":1}\n200'
      else
        print -r -- "$(<"$IPQUALITY_TEST_RESPONSE")"
        print -rn -- 200
      fi
    ZSH
    cases = [
      ["-4", "12.217.32.68", {"HTTPS_PROXY" => "http://127.0.0.1:12345", "IPQUALITY_ISOLATED_EGRESS" => "1"}, []],
      ["-4", "12.217.32.68", {"HTTPS_PROXY" => "http://127.0.0.1:12345"}, []],
      ["-6", "2606:4700:4700::1111", {}, []],
      ["-4", "12.217.32.68", {}, ["--ipqs-dns", "system"]]
    ]
    cases.each do |family, target, environment, options|
      File.write(calls, "")
      stdout, stderr, status = run_script("--confirm-network-lookup", "--sources", "ipqs", family, "-j",
        *options, target, env: NO_PROXY_ENV.merge(environment).merge("IPQUALITY_TEST_CALLS" => calls,
          "IPQUALITY_TEST_RESPONSE" => IPQS_FIXTURE))
      assert status.success?, stderr
      assert_equal "system", JSON.parse(stdout).dig("Query", "IPQSDNS")
      refute_includes File.read(calls), "--doh-url"
      assert_equal 2, File.readlines(calls).count { |line| line.start_with?("proxy=#{environment.fetch('HTTPS_PROXY', 'none')},") }
      refute_includes File.read(calls), "--noproxy"
      refute_includes File.read(calls), "--resolve"
    end
  end

  def test_selected_failure_keeps_its_column_while_deselected_sources_are_absent
    calls = File.join(reporter_workspace, "calls")
    report_path = File.join(reporter_workspace, "report.txt")
    write_fake_command("curl", <<~'ZSH')
      print -r -- called >> "$IPQUALITY_TEST_CALLS"
      print -rn -- $'\n000'
      exit 35
    ZSH
    stdout, stderr, status = run_script("--sources", "ipapi", "--confirm-network-lookup",
      "-4", "-j", "-o", report_path, "12.217.32.68", env: {"IPQUALITY_TEST_CALLS" => calls})
    assert status.success?, stderr
    report = JSON.parse(stdout)
    assert_equal "tls_error", report.dig("ProviderStatus", "ipapi")
    assert_equal "disabled", report.dig("ProviderStatus", "IPQS")
    assert_nil report.dig("Score", "IPQS")
    assert_equal 1, File.readlines(calls).length
    text = File.read(report_path)
    assert_includes text, "ipapi.is"
    assert_includes text, "TLS 握手失败"
    %w[Scamalytics IPQS Check.Place IPWHOIS Cloudflare RIPEstat].each { |name| refute_includes text, name }
  end

  def test_independent_mode_never_uses_a_relay_when_ipqs_has_no_key
    write_fake_command("curl", <<~'ZSH')
      if [[ "$*" == *check.place* ]];then
        print -r -- forbidden-relay >> "$IPQUALITY_TEST_NETWORK_ATTEMPTS"
      fi
      print -rn -- $'\n000'
      exit 28
    ZSH
    stdout, stderr, status = run_script("--sources", "independent", "--confirm-network-lookup",
      "-4", "-j", "12.217.32.68", env: {"IPQS_API_KEY" => nil})
    assert status.success?, stderr
    report = JSON.parse(stdout)
    assert_equal "not_configured", report.dig("ProviderStatus", "IPQS")
    %w[CheckPlaceMaxMind Scamalytics AbuseIPDB IP2Location ipdata].each do |name|
      assert_equal "disabled", report.dig("ProviderStatus", name)
    end
    assert_equal "timeout", report.dig("ProviderStatus", "ipapi")
  end

  def test_forced_alidns_ipqs_needs_a_key_uses_doh_at_both_stages_and_never_falls_back
    calls = File.join(reporter_workspace, "curl-arguments")
    config = File.join(reporter_workspace, "curl-config")
    write_fake_command("curl", <<~'ZSH')
      print -rl -- "$@" >> "$IPQUALITY_TEST_CALLS"
      request=$(cat)
      print -r -- "$request" >> "$IPQUALITY_TEST_CONFIG"
      if [[ -n "${IPQUALITY_TEST_FAIL:-}" ]];then
        print -rn -- $'\n000'
        exit 28
      elif [[ "$request" == *"/api/json/account/"* ]];then
        print -rn -- $'{"success":true,"credits":100,"usage":1}\n200'
      elif [[ "$request" == *"/api/json/ip/fixturekey123/12.217.32.68?"* ]];then
        print -r -- "$(<"$IPQUALITY_TEST_RESPONSE")"
        print -rn -- 200
      else
        print -r -- unexpected >> "$IPQUALITY_TEST_NETWORK_ATTEMPTS"
        exit 97
      fi
    ZSH
    options = ["--sources", "ipqs", "--ipqs-dns", "alidns", "--confirm-network-lookup", "-4", "-j", "12.217.32.68"]
    env = NO_PROXY_ENV.merge("IPQUALITY_TEST_CALLS" => calls, "IPQUALITY_TEST_CONFIG" => config,
                             "IPQUALITY_TEST_RESPONSE" => IPQS_FIXTURE)

    # Without a key there is no request at all, not a relay or resolver fallback.
    stdout, stderr, status = run_script(*options, env: env)
    assert status.success?, stderr
    assert_equal "not_configured", JSON.parse(stdout).dig("ProviderStatus", "IPQS")
    refute File.exist?(calls)

    write_ipqs_key
    stdout, stderr, status = run_script(*options, env: env)
    assert status.success?, stderr
    report = JSON.parse(stdout)
    assert_equal "ok", report.dig("ProviderStatus", "IPQS")
    assert_equal "disabled", report.dig("ProviderStatus", "CheckPlaceMaxMind")
    assert_equal ["ipqs"], report.dig("Query", "SelectedSources")
    assert_equal "explicit_target", report.dig("Query", "TargetMode")
    assert_equal "alidns", report.dig("Query", "IPQSDNS")
    assert_equal "none", report.dig("Info", "Source")
    arguments = File.readlines(calls, chomp: true)
    assert_equal 2, arguments.count("https://dns.alidns.com/dns-query")
    assert_equal 2, arguments.count("--doh-url")
    assert_equal 2, arguments.count("-4")
    refute_match(/fixturekey123|--resolve|--insecure/, File.read(calls))
    assert_includes File.read(config), "/12.217.32.68?"

    File.write(calls, "")
    stdout, stderr, status = run_script(*options, env: env.merge("IPQUALITY_TEST_FAIL" => "1"))
    assert status.success?, stderr
    report = JSON.parse(stdout)
    assert_equal "timeout", report.dig("ProviderStatus", "IPQS")
    assert_nil report.dig("Score", "IPQS")
    # One AliDNS request (account preflight), then no relay or system-resolver retry.
    assert_equal [1, 1], ["-q", "--doh-url"].map { |flag| File.readlines(calls, chomp: true).count(flag) }
  end
end
