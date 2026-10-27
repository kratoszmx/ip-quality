# frozen_string_literal: true
require_relative "support/reporter_test_case"

# DB-IP visitor demo and IPWHOIS public demo: parsers, runtime and target rules.
class PublicDemoTest < ReporterTestCase
  parallelize_me!

  def test_demo_parsers_preserve_labels_false_flags_and_unknown_fields
    dbip = fixture_json("dbip/demo.json")
    whois = fixture_json("ipwhois/demo.json")
    # DB-IP never turns a threat label or an unexpected premium flag into a score.
    assert_equal "0|ok|ok|low|||US|Example City", parse("dbip", dbip.merge("isProxy" => false))
    assert_equal "0|ok|ok|false|true|false|true", parse("ipwhois", whois)
    dbip.delete("threatLevel")
    whois.delete("security")
    assert_equal "0|ok|not_provided||||US|Example City", parse("dbip", dbip)
    assert_equal "0|ok|not_provided||||", parse("ipwhois", whois)
    whois["security"] = { "vpn" => false }
    assert_equal "0|ok|ok||false||", parse("ipwhois", whois)
  end

  def test_http_200_demo_rate_limits_clear_previous_data_and_remain_unknown
    %w[dbip ipwhois].each do |provider|
      result = parse(provider, fixture_json("#{provider}/demo-rate-limited.json"))
      expected = provider == "dbip" ? "daily_quota_exhausted" : "rate_limited"
      assert_match(/\A1\|#{expected}\|\|+\z/, result)
      refute_includes result, "false"
      refute_includes result, "low"
    end
  end

  def test_demo_parsers_reject_wrong_ip_bad_geography_string_booleans_and_nested_schema_drift
    dbip = fixture_json("dbip/demo.json")
    whois = fixture_json("ipwhois/demo.json")
    [nil, [], "not an object", { "status" => "ok", "demoInfo" => "error" },
     dbip.merge("ipAddress" => "8.8.8.8"), dbip.merge("countryCode" => ["US"]),
     dbip.merge("city" => "\e[31m"), dbip.merge("errorCode" => "QUOTA_EXCEEDED"),
     dbip.merge("threatLevel" => 0), dbip.merge("threatLevel" => "clean")].each do |body|
      assert_match(/\A1\|/, parse("dbip", body), body.inspect)
    end
    [nil, [], "not an object", whois.merge("ip" => "8.8.8.8"),
     whois.merge("security" => "premium"), whois.merge("security" => { "vpn" => "false" }),
     whois.merge("connection" => { "org" => "\e[31minjected" })].each do |body|
      assert_match(/\A1\|/, parse("ipwhois", body), body.inspect)
    end
  end

  def test_dbip_limit_code_alone_does_not_invent_a_daily_reset
    [nil, "too many requests", "maximum number of queries per minute exceeded", []].each do |message|
      result = parse("dbip", { "errorCode" => "OVER_QUERY_LIMIT", "error" => message })
      assert_match(/\A1\|rate_limited\|\|+\z/, result)
    end
    result = parse("dbip", { "error" => "maximum number of queries per day exceeded" })
    assert_match(/\A1\|daily_quota_exhausted\|\|+\z/, result)
  end

  def test_dbip_runtime_keeps_both_demo_requests_on_route_and_stops_on_failure_or_mismatch
    probe = <<~'ZSH'
      source "$1"
      source "$2"
      eval "$3"
      typeset -A dbip sinfo sscore
      IP=198.51.100.23
      CurlARG='--proxy http://127.0.0.1:12345'
      setopt SH_WORD_SPLIT
      fixture=$(<"$4") calls_file="$5"
      show_progress(){ :; }
      curl_with_secret_url(){
        print -r -- call >> "$calls_file"
        [[ "$*" == *'--proxy http://127.0.0.1:12345'* && "$*" == *'-6'* && "$*" == *'Origin: https://db-ip.com'* && "$*" == *'Referer: https://db-ip.com/'* ]] || exit 99
        if [[ "$1" == 'https://db-ip.com/api/core/' ]];then
          [[ "$scenario" == network_error ]]&&return 28
          if [[ "$scenario" == rate_limited ]];then
            print -r -- '{}'
            print -r -- 429
            return
          fi
          if [[ "$scenario" == invalid_response ]];then
            print -r -- '<html>unexpected page</html>'
          else
            print -r -- '<script data-api-key="fixture-guest-key"></script>'
          fi
        elif [[ "$1" == 'https://api.db-ip.com/v2/fixture-guest-key/self?convertCurrencies' ]];then
          if [[ "$scenario" == ip_mismatch ]];then
            print -r -- "$fixture"|jq -c '.ipAddress="8.8.8.8"'
          else
            print -r -- "$fixture"
          fi
        else
          exit 98
        fi
        print -r -- 200
      }
      for scenario in ok rate_limited invalid_response network_error ip_mismatch;do
        : > "$calls_file"
        db_dbip 6
        calls=$(wc -l < "$calls_file")
        print -r -- "${calls// /}|${dbip[status]}|${dbip[city]:-}"
      done
    ZSH
    Dir.mktmpdir("ipquality-dbip-test-") do |directory|
      assert_equal "2|ok|Example City\n1|rate_limited|\n1|invalid_response|\n1|timeout|\n2|ip_mismatch|\n",
        zsh!(probe, COMMON_PROVIDER_LIBRARY, provider_library("dbip"), reporter_functions("db_dbip"),
          fixture_path("dbip/free.json"), File.join(directory, "calls"))
    end
  end

  def test_dbip_guest_key_is_bounded_and_cannot_inject_a_url_or_curl_option
    probe = 'source "$1"; dbip_demo_key_from_page "$2"'
    ["a\" -K evil", "a/b", "a\nheader", "a" * 129, "short"].each do |key|
      stdout, stderr, status = zsh(probe, provider_library("dbip"), "<script data-api-key=\"#{key}\"></script>")
      refute status.success?
      assert_empty stdout
      assert_empty stderr
    end
  end

  def test_dbip_daily_limit_uses_one_public_page_and_keeps_both_outcomes_in_json
    probe = <<~'ZSH'
      source "$1"
      IP=198.51.100.23
      body="$2" calls="$3" scenario="$4"
      show_progress(){ :; }
      curl_with_secret_url(){
        if [[ "$1" == 'https://db-ip.com/api/core/' ]];then
          print -r -- '<script data-api-key="fixture-key"></script>'
        else
          print -r -- "{\"error\":\"$scenario\"}"
        fi
        print -r -- 200
      }
      dbip_lookup_page(){ [[ "$1" == 4 ]]||exit 99; print page >> "$calls"; print -r -- "$body"; }
      dbip[threat_level]=high
      db_dbip 4
      save_json
      print -r -- "$ipjson"
    ZSH
    Dir.mktmpdir("ipquality-dbip-page-test-") do |dir|
      calls = File.join(dir, "calls")
      [{status: "ok", ipAddress: "198.51.100.23", threatLevel: "low"},
       {status: "ok", ipAddress: "8.8.8.8", threatLevel: "low"},
       {status: "ok", ipAddress: "198.51.100.23", threatLevel: 0},
       {status: "cloudflare_blocked"}, {status: "dependency_missing"},
       {status: "timeout"}, {status: "rate_limited"}, {status: "invented"}, []].each do |body|
        File.write(calls, "")
        report = JSON.parse(zsh!(probe, SCRIPT, JSON.generate(body), calls, "maximum number of queries per day exceeded"))
        assert_equal ["page"], File.readlines(calls, chomp: true)
        meta = report.fetch("ScoreMeta").fetch("DBIP")
        success = body.is_a?(Hash) && body[:status] == "ok" && body[:ipAddress] == "198.51.100.23" && body[:threatLevel] == "low"
        assert_equal "daily_quota_exhausted", meta.fetch("DemoStatus")
        assert_equal success ? "ok" : "daily_quota_exhausted", meta.fetch("Status")
        assert_equal success ? "public_page" : "public_demo", meta.fetch("Source")
        assert_equal [success ? "low" : nil], [meta.fetch("Band")]
        assert_nil report.dig("Score", "DBIP")
        refute_equal "invented", meta.fetch("PageStatus")
      end
      File.write(calls, "")
      report = JSON.parse(zsh!(probe, SCRIPT, '{}', calls, "maximum number of queries per minute exceeded"))
      assert_empty File.read(calls)
      assert_equal "rate_limited", report.dig("ProviderStatus", "DBIP")
    end
  end

  def test_dbip_browser_never_drops_explicit_family_or_interface_or_requires_optional_dependencies
    probe = <<~'ZSH'
      source "$1"
      IP=198.51.100.23
      node(){ print -ru2 'unexpected browser'; exit 99; }
      dbip_lookup_page 6
      CurlARG='--interface fixture-interface'
      dbip_lookup_page 4
      CurlARG=''
      dbip_page_program=/nonexistent/ipquality-test.mjs
      dbip_lookup_page 4
    ZSH
    results = zsh!(probe, provider_library("dbip")).lines.map { |line| JSON.parse(line).fetch("status") }
    assert_equal %w[route_unsupported route_unsupported dependency_missing], results
  end

  def test_dbip_and_ping0_skip_visitor_requests_for_explicit_targets
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
  end

  def test_ipwhois_runtime_fetches_demo_once_and_clears_stale_fields
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      eval "$2"
      shift 2
      typeset -A ipwhois sinfo
      IP=198.51.100.23
      show_progress(){ :; }
      provider_fetch_public_json(){
        [[ "$1" == 4 && "$2" == 'https://ipwhois.io/demo?ip=198.51.100.23' ]] || exit 99
        [[ "$*" == *'Origin: https://ipwhois.io'* && "$*" == *'Referer: https://ipwhois.io/'* && "$*" == *Mozilla/5.0* ]] || exit 98
        ((calls+=1))
        PROVIDER_RESPONSE_STATUS=ok PROVIDER_RESPONSE_BODY="$body"
      }
      for body in "$@";do
        calls=0
        db_ipwhois 4
        print -r -- "$?|$calls|${ipwhois[status]}|${ipwhois[risk_status]}|${ipwhois[countrycode]}|${ipwhois[asn]}|${ipwhois[org]}|${ipwhois[isp]}|${ipwhois[timezone]}|${ipwhois[proxy]}|${ipwhois[vpn]}|${ipwhois[tor]}|${ipwhois[server]}"
      done
    ZSH
    # Reuse one runtime state: absent flags, quota failures and mismatched IPs
    # must never inherit a preceding successful result.
    responses = %w[demo valid demo-rate-limited demo mismatch].map do |name|
      File.read(fixture_path("ipwhois/#{name}.json"))
    end
    stdout = zsh!(probe, provider_library("ipwhois"), reporter_functions("db_ipwhois"), *responses)
    demo = [0, 1, "ok", "ok", "US", 64500, "Example Network", "Example ISP", "", false, true, false, true]
    context_only = [0, 1, "ok", "not_provided", "US", 64500, "Example Network", "Example ISP", "America/Los_Angeles", "", "", "", ""]
    expected = [demo, context_only, [0, 1, "rate_limited", *Array.new(10, "")],
                demo, [0, 1, "invalid_response", *Array.new(10, "")]]
    assert_equal expected.map { |fields| fields.join("|") }, stdout.lines.map(&:chomp)
  end

  private

  def parse(provider, body)
    fields = provider == "dbip" ? %w[threat_level score proxy country_code city] : %w[proxy vpn tor hosting]
    values = %w[status risk_status].concat(fields).map { |key| "${#{provider}_parsed[#{key}]}" }.join("|")
    probe = "source \"$1\"; #{provider}_parsed[#{fields.first}]=stale; #{provider}_parse_response \"$2\" 198.51.100.23; print -r -- \"$?|#{values}\""
    zsh!(probe, provider_library(provider), JSON.generate(body)).chomp
  end
end
