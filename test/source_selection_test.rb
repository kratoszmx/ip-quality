# frozen_string_literal: true

require_relative "support/reporter_test_case"
load File.expand_path("../bin/test-clash-leaf", __dir__) unless defined?(IpQuality::ClashLeafCommand)

class SourceSelectionTest < ReporterTestCase
  DIRECT_ENV = %w[HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy IPQUALITY_ISOLATED_EGRESS].to_h { |key| [key, nil] }.freeze

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
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", <<~'ZSH', "catalog", File.join(ROOT, "providers", "selection.zsh"))
      source "$1"
      print -r -- "${(j:,:)reputation_source_ids}"
    ZSH
    assert status.success?, stderr
    assert_equal IpQuality::ClashLeafCommand::SOURCE_IDS, stdout.strip.split(",")

    Dir.mktmpdir("source-runner-") do |directory|
      arguments = File.join(directory, "arguments")
      reporter = File.join(directory, "reporter")
      File.write(reporter, 'print -rl -- "$@" > "$IPQUALITY_TEST_ARGUMENTS"' + "\n")
      code = <<~'RUBY'
        load ARGV.shift
        command = IpQuality::ClashLeafCommand.new(reporter_path: ARGV.shift)
        exit command.run(ARGV)
      RUBY
      _out, err, result = Open3.capture3({"IPQUALITY_TEST_ARGUMENTS" => arguments},
        "/usr/bin/ruby", "--disable-gems", "-e", code, File.join(ROOT, "bin", "test-clash-leaf"), reporter,
        "--direct", "--sources", "ipapi,ipqs", "--ipqs-dns", "alidns", "--confirm-network-lookup")
      assert result.success?, err
      assert_equal %w[--confirm-network-lookup --scope reputation -4 --sources ipapi,ipqs --ipqs-dns alidns], File.readlines(arguments, chomp: true)
    end
  end

  def test_ipqs_doh_requires_explicit_direct_selection_and_never_changes_proxy_dns
    stdout, stderr, status = run_script("--ipqs-dns", "alidns", "--sources", "ipqs", env: DIRECT_ENV)
    assert status.success?, stderr
    assert_includes stdout, "https://dns.alidns.com/dns-query"
    assert_includes stdout, "not the API key or target"
    [{"HTTPS_PROXY" => "http://127.0.0.1:1"}, {"IPQUALITY_ISOLATED_EGRESS" => "1"}].each do |proxy_env|
      _out, err, result = run_script("--ipqs-dns", "alidns", "--confirm-network-lookup", env: DIRECT_ENV.merge(proxy_env))
      assert_equal 64, result.exitstatus
      assert_includes err, "direct route"
    end
    _out, _err, result = run_script("--ipqs-dns", "invalid")
    assert_equal 64, result.exitstatus
  end

  def test_only_selected_ipqs_is_queried_with_doh_at_both_stages_and_private_auth
    calls = File.join(reporter_workspace, "curl-arguments")
    config = File.join(reporter_workspace, "curl-config")
    FileUtils.mkdir_p(File.join(reporter_workspace, "secrets"))
    File.write(File.join(reporter_workspace, "secrets", "ipqs"), "fixturekey123", perm: 0o600)
    write_fake_command("curl", <<~'ZSH')
      print -rl -- "$@" >> "$IPQUALITY_TEST_CALLS"
      request=$(cat)
      print -r -- "$request" >> "$IPQUALITY_TEST_CONFIG"
      if [[ "$request" == *"/api/json/account/"* ]];then
        print -rn -- $'{"success":true,"credits":100,"usage":1}\n200'
      elif [[ "$request" == *"/api/json/ip/fixturekey123/12.217.32.68?"* ]];then
        print -r -- "$(<"$IPQUALITY_TEST_RESPONSE")"
        print -rn -- 200
      else
        print -r -- unexpected >> "$IPQUALITY_TEST_NETWORK_ATTEMPTS"
        exit 97
      fi
    ZSH
    stdout, stderr, status = run_script("--sources", "ipqs", "--ipqs-dns", "alidns",
      "--confirm-network-lookup", "-4", "-j", "12.217.32.68", env: DIRECT_ENV.merge(
        "IPQUALITY_TEST_CALLS" => calls,
        "IPQUALITY_TEST_CONFIG" => config, "IPQUALITY_TEST_RESPONSE" => IPQUALITYSCORE_OFFICIAL_FIXTURE))
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
    refute_includes File.read(calls), "fixturekey123"
    refute_includes File.read(calls), "--resolve"
    refute_includes File.read(calls), "--insecure"
    assert_includes File.read(config), "/12.217.32.68?"
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

  def test_doh_failure_and_missing_key_do_not_fall_back_to_a_relay_or_another_resolver
    calls = File.join(reporter_workspace, "calls")
    write_fake_command("curl", <<~'ZSH')
      print -r -- called >> "$IPQUALITY_TEST_CALLS"
      print -rn -- $'\n000'
      exit 28
    ZSH
    options = ["--sources", "ipqs", "--ipqs-dns", "alidns", "--confirm-network-lookup", "-4", "-j", "12.217.32.68"]
    stdout, stderr, status = run_script(*options, env: DIRECT_ENV.merge("IPQUALITY_TEST_CALLS" => calls))
    assert status.success?, stderr
    assert_equal "not_configured", JSON.parse(stdout).dig("ProviderStatus", "IPQS")
    refute File.exist?(calls)
    FileUtils.mkdir_p(File.join(reporter_workspace, "secrets"))
    File.write(File.join(reporter_workspace, "secrets", "ipqs"), "fixturekey123", perm: 0o600)
    stdout, stderr, status = run_script(*options, env: DIRECT_ENV.merge("IPQUALITY_TEST_CALLS" => calls))
    assert status.success?, stderr
    report = JSON.parse(stdout)
    assert_equal "timeout", report.dig("ProviderStatus", "IPQS")
    assert_nil report.dig("Score", "IPQS")
    assert_equal ["called"], File.readlines(calls, chomp: true)
  end
end
