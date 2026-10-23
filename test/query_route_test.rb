# frozen_string_literal: true

require_relative "support/reporter_test_case"

class QueryRouteTest < ReporterTestCase
  TARGET = "8.8.8.8"

  def test_ipqs_account_failure_reuses_direct_route_for_the_same_target_lookup
    report, text, calls = lookup
    assert_equal ["account|selected|4|system", "account|direct|4|alidns", "lookup|direct|4|alidns"], calls
    assert_equal "ok", report.dig("ProviderStatus", "IPQS")
    assert_equal "87", report.dig("Score", "IPQS")
    assert_equal "alidns", report.dig("Query", "IPQSDNS")
    assert_transport report, "IPQS", "direct_fallback", "tls_error"
    assert_includes text, "可用·直连备援"
    assert_includes text, "原通路TLS 握手失败"
    assert_includes text, "查询目标仍为所选 IP"
    assert_equal 1, File.read(@config).scan("/api/json/ip/fixturekey123/#{TARGET}?").length
  end

  def test_ipqs_lookup_failure_retries_only_the_lookup_and_keeps_ipv6_target
    target = "2606:4700:4700::1111"
    report, text, calls = lookup(stage: "lookup", target: target, family: "-6", language: "en")
    assert_equal ["account|selected|6|system", "lookup|selected|6|system", "lookup|direct|4|alidns"], calls
    assert_transport report, "IPQS", "direct_fallback", "tls_error"
    assert_equal "ok", report.dig("ProviderStatus", "IPQS")
    assert_includes text, "available via direct fallback"
    assert_includes text, "original route TLS handshake failed"
    assert_includes text, "the selected target IP is unchanged"
    assert_equal 2, File.read(@config).scan("/api/json/ip/fixturekey123/#{target}?").length
  end

  def test_cloudflare_has_independent_route_state_and_preserves_target_validation
    report, text, calls = lookup(provider: "cloudflare", stage: "cloudflare")
    assert_equal ["cloudflare|selected|4|system", "cloudflare|direct|4|system"], calls
    assert_equal "ok", report.dig("ProviderStatus", "Cloudflare")
    assert_transport report, "Cloudflare", "direct_fallback", "tls_error"
    assert_includes text, "Cloudflare 查询通路"
    assert_includes text, "AS64500"
    assert_equal 2, File.read(@config).scan("ipv4=#{TARGET}").length
    refute_includes File.read(@arguments), "fixturetoken123"
    assert_nil report.dig("Query", "ProviderTransport", "IPQS", "Route")

    report, _text, _calls = lookup(provider: "cloudflare", stage: "cloudflare", wrong_target: true)
    assert_equal "invalid_response", report.dig("ProviderStatus", "Cloudflare")
    assert_transport report, "Cloudflare", "direct_fallback", "tls_error"
  end

  def test_a_failed_direct_fallback_is_bounded_and_cannot_supply_a_clean_score
    report, text, calls = lookup(direct_failure: true)
    assert_equal 2, calls.length
    assert_equal "tls_error", report.dig("ProviderStatus", "IPQS")
    assert_nil report.dig("Score", "IPQS")
    assert_transport report, "IPQS", "direct_fallback", "tls_error"
    assert_includes text, "TLS 握手失败·直连备援"
    refute_includes text, "可用·直连备援"
  end

  def test_response_errors_certificate_failures_and_size_limits_never_change_route
    [
      [0, "unauthorized\n401", "http_401"],
      [0, "Sorry, you have been blocked by Cloudflare\n403", "cloudflare_blocked"],
      [0, "quota\n429", "rate_limited"],
      [0, "not json\n200", "invalid_response"],
      [0, '{"success":true,"credits":0,"usage":10}' + "\n200", "official_insufficient_credits"],
      [60, "\n000", "tls_verification_failed"],
      [63, "\n000", "network_error"],
      [28, "partial response\n200", "timeout"]
    ].each do |exit_code, wire, expected|
      report, text, calls = lookup(exit_code: exit_code, wire: wire)
      assert_equal ["account|selected|4|system"], calls, expected
      assert_equal expected, report.dig("ProviderStatus", "IPQS")
      assert_nil report.dig("Score", "IPQS")
      assert_transport report, "IPQS", "selected_route", nil
      refute_includes text, "直连备援"
    end
  end

  def test_connection_errors_before_http_can_fall_back_but_direct_runs_do_not_retry
    [[6, "network_error"], [7, "network_error"], [28, "timeout"], [52, "network_error"], [56, "network_error"]].each do |code, expected|
      report, _text, calls = lookup(exit_code: code)
      assert_equal 3, calls.length
      assert_equal "ok", report.dig("ProviderStatus", "IPQS")
      assert_transport report, "IPQS", "direct_fallback", expected
    end
    report, _text, calls = lookup(proxy: false)
    assert_equal ["account|selected|4|alidns"], calls
    assert_equal "tls_error", report.dig("ProviderStatus", "IPQS")
    assert_transport report, "IPQS", "selected_route", nil
  end

  def test_successful_proxy_route_needs_no_extra_request_or_direct_disclosure
    report, text, calls = lookup(stage: "none")
    assert_equal ["account|selected|4|system", "lookup|selected|4|system"], calls
    assert_equal "ok", report.dig("ProviderStatus", "IPQS")
    assert_transport report, "IPQS", "selected_route", nil
    refute_includes text, "直连备援"
  end

  private

  def assert_transport(report, provider, route, failure)
    assert_equal({"Route" => route, "OriginalRouteFailure" => failure, "TargetUnchanged" => true},
      report.dig("Query", "ProviderTransport", provider))
  end

  def lookup(provider: "ipqs", stage: "account", exit_code: 35, wire: "\n000", direct_failure: false,
             proxy: true, family: "-4", target: TARGET, language: "cn", wrong_target: false)
    root = reporter_workspace
    @arguments = File.join(root, "arguments")
    @config = File.join(root, "config-input")
    calls_path = File.join(root, "calls")
    report_path = File.join(root, "report.txt")
    [@arguments, @config, calls_path].each { |path| File.write(path, "") }
    File.unlink(report_path) if File.exist?(report_path)
    failure_path = File.join(root, "failure.txt")
    File.write(failure_path, wire)
    cloudflare_path = File.join(root, "cloudflare.json")
    response = JSON.parse(File.read(fixture_path("cloudflare/valid.json")))
    response["result"][0]["ip"] = wrong_target ? "1.1.1.1" : target
    File.write(cloudflare_path, JSON.generate(response))
    write_ipqs_key
    FileUtils.mkdir_p(File.join(root, "config", "ipquality"))
    credentials = File.join(root, "config", "ipquality", "credentials")
    File.write(credentials, "CLOUDFLARE_API_TOKEN=fixturetoken123\nCLOUDFLARE_ACCOUNT_ID=fixtureaccount123\n", perm: 0o600)
    write_fake_command("curl", <<~'ZSH')
      request=$(cat)
      print -rl -- "$@" >> "$IPQUALITY_TEST_ARGUMENTS"
      print -r -- "$request" >> "$IPQUALITY_TEST_CONFIG"
      phase=unknown transport=selected family=none dns=system
      case "$request" in
        */api/json/account/*)phase=account ;;
        */api/json/ip/*)phase=lookup ;;
        */intel/ip*)phase=cloudflare ;;
        *)print -r -- unexpected >> "$IPQUALITY_TEST_NETWORK_ATTEMPTS"; exit 97 ;;
      esac
      args=("$@")
      for ((i=1;i<=${#args};i++));do
        case "${args[$i]}" in
          --proxy) [[ "${args[$((i+1))]}" == '' ]]&&transport=direct ;;
          -4)family=4 ;;
          -6)family=6 ;;
          --doh-url)dns=alidns ;;
        esac
      done
      if [[ "$transport" == direct && "$*" != *'--noproxy *'* ]];then exit 98;fi
      print -r -- "$phase|$transport|$family|$dns" >> "$IPQUALITY_TEST_CALLS"
      if [[ ( "$transport" == selected && "$phase" == "$IPQUALITY_TEST_FAIL_STAGE" ) || ( "$transport" == direct && "$IPQUALITY_TEST_DIRECT_FAILURE" == 1 ) ]];then
        print -rn -- "$(<"$IPQUALITY_TEST_FAILURE")"
        exit "$IPQUALITY_TEST_EXIT"
      fi
      case "$phase" in
        account)print -rn -- $'{"success":true,"credits":100,"usage":1}\n200' ;;
        lookup)print -r -- "$(<"$IPQUALITY_TEST_RESPONSE")";print -rn -- 200 ;;
        cloudflare)print -r -- "$(<"$IPQUALITY_TEST_CLOUDFLARE")";print -rn -- 200 ;;
      esac
    ZSH
    env = NO_PROXY_ENV.merge(
      "IPQUALITY_TEST_ARGUMENTS" => @arguments, "IPQUALITY_TEST_CONFIG" => @config,
      "IPQUALITY_TEST_CALLS" => calls_path, "IPQUALITY_TEST_FAIL_STAGE" => stage,
      "IPQUALITY_TEST_FAILURE" => failure_path, "IPQUALITY_TEST_EXIT" => exit_code.to_s,
      "IPQUALITY_TEST_DIRECT_FAILURE" => direct_failure ? "1" : "0",
      "IPQUALITY_TEST_RESPONSE" => IPQS_FIXTURE,
      "IPQUALITY_TEST_CLOUDFLARE" => cloudflare_path)
    env.merge!("HTTPS_PROXY" => "http://127.0.0.1:1", "IPQUALITY_ISOLATED_EGRESS" => "1") if proxy
    stdout, stderr, status = run_script("--confirm-network-lookup", "--sources", provider,
      family, "-j", "-l", language, "-o", report_path, target, env: env)
    assert status.success?, stderr
    refute_match(/jq: error|ERROR:|fixturekey123|fixturetoken123/, stderr)
    refute_includes stdout, "fixturekey123"
    refute_includes stdout, "fixturetoken123"
    refute_includes File.read(@arguments), "fixturekey123"
    refute_includes File.read(@arguments), "--insecure"
    [JSON.parse(stdout), File.read(report_path), File.readlines(calls_path, chomp: true)]
  end
end
