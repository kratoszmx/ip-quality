# frozen_string_literal: true

require_relative "support/reporter_test_case"

class PublicFallbacksTest < ReporterTestCase
  parallelize_me!

  IP2_LIBRARY = File.join(ROOT, "providers", "ip2location.zsh")
  IPDATA_LIBRARY = File.join(ROOT, "providers", "ipdata.zsh")
  IP2_PAGE = File.join(ROOT, "test", "fixtures", "ip2location", "public-page.html")
  IPDATA_FREE_RESPONSE = File.join(ROOT, "test", "fixtures", "ipdata", "free-response.json")
  IPDATA_RESPONSE = File.join(ROOT, "test", "fixtures", "ipdata", "public-response.json")
  IPDATA_OFFICIAL_RESPONSE = File.join(ROOT, "test", "fixtures", "ipdata", "official-response.json")

  def test_ip2location_page_binds_both_heading_and_json_without_executing_scripts
    code = <<~'ZSH'
      source "$1"
      response=$(ip2location_page_response "$(cat)" "$2")||exit 1
      ip2location_response_is_valid "$response" "$2"||exit 1
      print -r -- "$response"|jq -c '{ip, fraud_score, vpn: .proxy.is_vpn}'
    ZSH
    page = File.read(IP2_PAGE)
    ["198.51.100.23", "2001:4860:4860::8888"].each do |ip|
      out, err, status = zsh(code, IP2_LIBRARY, ip,
        stdin_data: page.gsub("198.51.100.23", ip))
      assert status.success?, err
      assert_empty err
      assert_equal({"ip" => ip, "fraud_score" => 0, "vpn" => false}, JSON.parse(out))
    end
    [page.sub("Address 198.51.100.23", "Address 8.8.8.8"),
     page.sub('"ip": "198.51.100.23"', '"ip": "8.8.8.8"'),
     page + page, page.sub('"fraud_score": 0', '"fraud_score": 100'),
     page.sub('"is_vpn": false', '"is_vpn": "false"'),
     page.sub('"proxy": {', '"proxy": "bad", "unused": {'),
     "<html>Just a moment</html>", page + " " * 262_144].each do |invalid|
      out, err, status = zsh(code, IP2_LIBRARY,
        "198.51.100.23", stdin_data: invalid)
      refute status.success?
      assert_empty out
      assert_empty err
    end
  end

  def test_ipdata_free_api_accepts_reduced_geography_but_rejects_wrong_targets_and_error_bodies
    full = JSON.parse(File.read(IPDATA_FREE_RESPONSE))
    ["198.51.100.23", "2001:4860:4860::8888"].each do |ip|
      valid = full.merge("ip" => ip)
      [valid, valid.slice("ip", "country", "asn", "org")].each do |body|
        assert_equal "", zsh!('source "$1"; ipdata_free_response_is_valid "$(cat)" "$2"',
          IPDATA_LIBRARY, ip, stdin_data: JSON.generate(body))
      end
    end
    invalid = [full.merge("ip" => "8.8.8.8"), full.merge("country" => nil),
      full.merge("country" => "United States"), full.merge("country" => []),
      full.merge("country" => "us"), full.merge("error" => "blocked"),
      full.merge("message" => "quota exceeded"), {"message" => "quota exceeded"},
      [], "bad", nil].map { |body| JSON.generate(body) }
    invalid += ["{broken", "<html>Just a moment</html>", File.read(IPDATA_RESPONSE),
      JSON.generate(full) * 2, "null\n#{JSON.generate(full)}"]
    invalid.each do |body|
      out, err, status = zsh('source "$1"; ipdata_free_response_is_valid "$(cat)" 198.51.100.23',
        IPDATA_LIBRARY, stdin_data: body)
      refute status.success?
      assert_empty out
      assert_empty err
    end
  end

  def test_ipdata_rejects_error_bodies_mismatched_targets_and_non_boolean_factors
    valid = JSON.parse(File.read(IPDATA_RESPONSE))
    [valid, {"message" => "quota exceeded"}, valid.merge("ip" => "8.8.8.8"),
      valid.merge("threat" => "bad"), valid.merge("threat" => {"is_proxy" => "false"}),
      valid.merge("threat" => {}), valid.merge("threat" => {"is_proxy" => false})].each_with_index do |body, index|
      _out, err, status = zsh('source "$1"; ipdata_response_is_valid "$(cat)" 198.51.100.23', IPDATA_LIBRARY,
        stdin_data: JSON.generate(body))
      assert_empty err
      assert_equal [0, 6].include?(index), status.success?
    end
    [JSON.generate(valid) * 2, "null\n#{JSON.generate(valid)}"].each do |body|
      _out, err, status = zsh('source "$1"; ipdata_response_is_valid "$(cat)" 198.51.100.23',
        IPDATA_LIBRARY, stdin_data: body)
      refute status.success?
      assert_empty err
    end
  end

  def test_default_report_recovers_ip2location_and_keeps_ipdata_free_geography_separate_from_risk
    calls = File.join(reporter_workspace, "calls")
    text_report = File.join(reporter_workspace, "report.txt")
    write_fake_command("curl", <<~'ZSH')
      print -rl -- "$@" >> "$IPQUALITY_TEST_CALLS"
      if [[ "$*" == *'https://www.ip2location.com/8.8.8.8'* ]];then
        sed 's/198.51.100.23/8.8.8.8/g' "$IPQUALITY_TEST_IP2_PAGE"
      elif [[ "$*" == *'https://ipdata.free/8.8.8.8'* ]];then
        sed 's/198.51.100.23/8.8.8.8/g' "$IPQUALITY_TEST_IPDATA_RESPONSE"
      elif [[ "$*" == *'https://ipinfo.check.place/'* ]];then
        print -rn -- $'Sorry, you have been blocked by Cloudflare\n403'
        exit 0
      else
        print -rn -- $'\n000'
        exit 35
      fi
      print -rn -- 200
    ZSH
    out, err, status = run_script("--confirm-network-lookup", "-4", "-j", "-o", text_report, "8.8.8.8",
      env: {"IPQUALITY_TEST_CALLS" => calls, "IPQUALITY_TEST_IP2_PAGE" => IP2_PAGE,
        "IPQUALITY_TEST_IPDATA_RESPONSE" => IPDATA_FREE_RESPONSE})
    assert status.success?, err
    refute_match(/jq: error/, err)
    report = JSON.parse(out)
    assert_equal "all", report.dig("Query", "SourceSelection")
    assert_equal "ok", report.dig("ProviderStatus", "IP2Location")
    assert_equal "0", report.dig("Score", "IP2LOCATION")
    assert_equal false, report.dig("Factor", "VPN", "IP2LOCATION")
    assert_equal true, report.dig("Factor", "Server", "IP2LOCATION")
    assert_equal "public_demo", report.dig("FactorMeta", "IP2LOCATION", "Source")
    assert_equal "ok", report.dig("ProviderStatus", "ipdata")
    assert_equal "US", report.dig("Factor", "CountryCode", "ipdata")
    %w[Proxy VPN Tor Server Abuser Robot].each do |name|
      assert_nil report.dig("Factor", name, "ipdata")
    end
    assert_equal "official_free_api", report.dig("FactorMeta", "ipdata", "Source")
    assert_equal "not_provided", report.dig("FactorMeta", "ipdata", "Status")
    assert_equal "free_geolocation_only", report.dig("FactorMeta", "ipdata", "Reason")
    %w[IP2LOCATION ipdata].each do |name|
      assert_equal "skipped_relay_cloudflare_blocked", report.dig("FactorMeta", name, "RelayStatus")
    end
    assert_equal "public_demo", report.dig("ScoreMeta", "IP2LOCATION", "Source")
    args = File.readlines(calls, chomp: true)
    assert_equal 1, args.count("https://www.ip2location.com/8.8.8.8")
    assert_equal 1, args.count("https://ipdata.free/8.8.8.8")
    refute args.any? { |a| a.include?("ipdata.co") }
    assert_equal 1, args.count { |a| a.start_with?("https://ipinfo.check.place/") }
    assert_includes File.read(text_report), "公开示例/可用"
    assert_includes File.read(text_report), "官方/未提供风险"
  end

  def test_owned_ipdata_key_restores_risk_without_relay_or_exposing_credentials
    calls = File.join(reporter_workspace, "calls")
    text_report = File.join(reporter_workspace, "report.txt")
    FileUtils.mkdir_p(File.join(reporter_workspace, "secrets"))
    File.write(File.join(reporter_workspace, "secrets", "ipdata"), "fixtureipdata123", perm: 0o600)
    write_fake_command("curl", <<~'ZSH')
      print -rl -- "$@" >> "$IPQUALITY_TEST_CALLS"
      request=$(cat)
      [[ "$request" == 'url = "https://api.ipdata.co/8.8.8.8?api-key=fixtureipdata123"' && "$*" == *'-4'* ]]||exit 99
      sed 's/198.51.100.23/8.8.8.8/g' "$IPQUALITY_TEST_IPDATA_RESPONSE"
      print -rn -- 200
    ZSH
    out, err, status = run_script("--sources", "ipdata", "--confirm-network-lookup", "-4", "-j", "-o", text_report, "8.8.8.8",
      env: {"IPQUALITY_TEST_CALLS" => calls, "IPQUALITY_TEST_IPDATA_RESPONSE" => IPDATA_OFFICIAL_RESPONSE})
    assert status.success?, err
    refute_match(/jq: error/, err)
    report = JSON.parse(out)
    assert_equal "ok", report.dig("ProviderStatus", "ipdata")
    assert_equal "official_api", report.dig("FactorMeta", "ipdata", "Source")
    assert_equal "ok", report.dig("FactorMeta", "ipdata", "Status")
    assert_nil report.dig("FactorMeta", "ipdata", "RelayStatus")
    %w[Proxy Tor Abuser].each { |field| assert_equal false, report.dig("Factor", field, "ipdata") }
    assert_equal true, report.dig("Factor", "Server", "ipdata")
    %w[VPN Robot].each { |field| assert_nil report.dig("Factor", field, "ipdata") }
    args = File.read(calls)
    refute_match(/check\.place|ipdata\.free/, args)
    assert_equal 1, File.readlines(calls, chomp: true).count("--config")
    [out, err, args, File.read(text_report)].each { |text| refute_includes text, "fixtureipdata123" }
    assert_includes File.read(text_report), "官方/可用"
  end

  def test_owned_ipdata_key_keeps_route_and_precise_failures_without_stale_risk_or_retries
    probe = <<~'ZSH'
      source "$1"
      IP=198.51.100.23
      provider_credentials[IPDATA_API_KEY]=fixtureipdata123
      CurlARG='--proxy http://127.0.0.1:12345'
      setopt SH_WORD_SPLIT
      show_progress(){ :; }
      check_place_fetch_json(){ print -u2 -- unexpected-relay; return 99; }
      wire="$2" curl_exit="$3" calls="$4"
      curl(){
        print -r -- call >> "$calls"
        [[ "$*" == *'-6'* && "$*" == *'--proxy http://127.0.0.1:12345'* ]]||return 99
        request=$(cat)
        [[ "$request" == 'url = "https://api.ipdata.co/198.51.100.23?api-key=fixtureipdata123"' ]]||return 99
        print -rn -- "$wire"; return "$curl_exit"
      }
      ipdata[proxy]=false ipdata[server]=true ipdata[risk_status]=ok
      db_ipdata 6
      print -r -- "${ipdata[status]}|${ipdata[source]}|${ipdata[proxy]}|${ipdata[server]}|${ipdata[risk_status]}"
    ZSH
    calls = File.join(reporter_workspace, "calls")
    [["\n000", 35, "tls_error"], ["\n000", 28, "timeout"],
      ["{}\n403", 0, "http_403"], ["{}\n429", 0, "rate_limited"],
      ["{\"ip\":\"8.8.8.8\"}\n200", 0, "invalid_response"],
      ["{\"message\":\"quota reached\"}\n200", 0, "invalid_response"]].each do |wire, curl_exit, expected|
      File.write(calls, "")
      assert_equal "#{expected}|official_api|||\n", zsh!(probe, SCRIPT, wire, curl_exit.to_s, calls)
      assert_equal 1, File.readlines(calls).length
    end
  end

  def test_fallbacks_preserve_route_stop_on_failure_and_leave_missing_flags_unknown
    probe = <<~'ZSH'
      source "$1"; source "$2"; source "$3"; eval "$4"; source "$9"
      typeset -A ip2location ipdata sinfo stype
      IP=198.51.100.23
      CurlARG='--proxy http://127.0.0.1:12345'; setopt SH_WORD_SPLIT
      show_progress(){ :; }
      calls_file="$5" page_file="$6" family="$7" scenario="$8"
      check_place_fetch_json(){ PROVIDER_RESPONSE_STATUS=skipped_relay_cloudflare_blocked; PROVIDER_RESPONSE_BODY=''; }
      curl(){
        print -r -- called >> "$calls_file"
        [[ "$*" == *'--proxy http://127.0.0.1:12345'* && "$*" == *"-$family"* ]]||exit 99
        if [[ "$scenario" == ipdata* ]];then
          [[ "$*" == *'https://ipdata.free/198.51.100.23'* ]]||exit 99
        fi
        if [[ "$scenario" == *tls ]];then print -rn -- $'\n000'; return 35;fi
        if [[ "$scenario" == *limit ]];then print -rn -- $'limit\n429'; return 0;fi
        if [[ "$scenario" == *timeout ]];then print -rn -- $'\n000'; return 28;fi
        if [[ "$scenario" == *invalid ]];then
          print -r -- '{"ip":"8.8.8.8","country":"US"}'
        else
          # Even an unexpected threat field on this geo-only API is not a risk observation.
          jq '. + {threat: {is_proxy: false, is_vpn: true}}' "$page_file"
        fi
        print -rn -- 200
      }
      if [[ "$scenario" == ipdata* ]];then
        ipdata[proxy]=false ipdata[vpn]=true ipdata[countrycode]=CN ipdata[risk_status]=ok
        db_ipdata "$family"
        print -r -- "${ipdata[status]}|${ipdata[countrycode]}|${ipdata[risk_status]}|${ipdata[proxy]}|${ipdata[vpn]}|${ipdata[abuser]}"
      else
        ip2location[score]=99; db_ip2location "$family"
        print -r -- "${ip2location[status]}|${ip2location[score]}"
      fi
    ZSH
    Dir.mktmpdir("source-fallback-") do |dir|
      calls = File.join(dir, "calls")
      [["tls", "tls_error|\n"], ["limit", "rate_limited|\n"],
        ["ipdata", "ok|US|not_provided|||\n"], ["ipdata_tls", "tls_error|||||\n"],
        ["ipdata_limit", "rate_limited|||||\n"], ["ipdata_timeout", "timeout|||||\n"],
        ["ipdata_invalid", "invalid_response|||||\n"]].product(%w[4 6]).each do |(scenario, expected), family|
        File.write(calls, "")
        out, err, status = zsh(probe, COMMON_PROVIDER_LIBRARY, IP2_LIBRARY, IPDATA_LIBRARY,
          reporter_functions("db_ip2location", "db_ipdata"), calls, IPDATA_FREE_RESPONSE, family, scenario, COMMON_HTTP_LIBRARY)
        assert status.success?, err
        assert_empty err
        assert_equal expected, out
        assert_equal 1, File.readlines(calls).length
      end
    end
  end

  def test_abuseipdb_uses_the_owned_key_without_relay_and_keeps_auth_out_of_arguments
    calls = File.join(reporter_workspace, "calls")
    FileUtils.mkdir_p(File.join(reporter_workspace, "secrets"))
    File.write(File.join(reporter_workspace, "secrets", "abuseipdb"), "fixturekey123", perm: 0o600)
    write_fake_command("curl", <<~'ZSH')
      print -rl -- "$@" >> "$IPQUALITY_TEST_CALLS"
      request=$(cat)
      [[ "$request" == *'header = "Key: fixturekey123"'* && "$request" == *'https://api.abuseipdb.com/api/v2/check?ipAddress=8.8.8.8&maxAgeInDays=90'* ]]||exit 99
      print -rn -- $'{"data":{"ipAddress":"8.8.8.8","countryCode":"US","usageType":"Fixed Line ISP","abuseConfidenceScore":0}}\n200'
    ZSH
    out, err, status = run_script("--sources", "abuseipdb", "--confirm-network-lookup", "-4", "-j", "8.8.8.8", env: {"IPQUALITY_TEST_CALLS" => calls})
    assert status.success?, err
    refute_match(/jq: error|unexpected network/, err)
    report = JSON.parse(out)
    assert_equal "ok", report.dig("ProviderStatus", "AbuseIPDB")
    assert_equal "official_api", report.dig("ScoreMeta", "AbuseIPDB", "Source")
    assert_equal "0", report.dig("Score", "AbuseIPDB")
    refute_includes File.read(calls), "fixturekey123"
    refute_includes out, "fixturekey123"
    refute_includes File.read(calls), "check.place"
  end

  def test_successful_relays_do_not_make_public_fallback_requests
    probe = <<~'ZSH'
      source "$1"; source "$2"; source "$3"; eval "$4"
      typeset -A ip2location ipdata sinfo stype
      IP=198.51.100.23
      show_progress(){ :; }
      curl(){ print -u2 -- unexpected-fallback; return 99; }
      check_place_fetch_json(){
        PROVIDER_RESPONSE_STATUS=ok
        case "$3" in
          db=ip2location) PROVIDER_RESPONSE_BODY='{"ip":"198.51.100.23","fraud_score":0,"is_proxy":false}';;
          db=ipdata) PROVIDER_RESPONSE_BODY='{"ip":"198.51.100.23","country_code":"US","threat":{"is_proxy":false}}';;
        esac
      }
      db_ip2location 4; db_ipdata 4
      print -r -- "${ip2location[status]}|${ip2location[source]}|${ip2location[score]}|${ip2location[relay_status]}"
      print -r -- "${ipdata[status]}|${ipdata[source]}|${ipdata[proxy]}|${ipdata[relay_status]}"
    ZSH
    out, err, status = zsh(probe, COMMON_PROVIDER_LIBRARY, IP2_LIBRARY, IPDATA_LIBRARY, reporter_functions("db_ip2location", "db_ipdata"))
    assert status.success?, err
    assert_empty err
    assert_equal "ok|check_place_relay|0|\nok|check_place_relay|false|\n", out
  end

  def test_abuseipdb_failures_clear_stale_scores_without_retry_or_relay
    probe = <<~'ZSH'
      source "$1"; source "$2"; eval "$3"; source "$7"
      typeset -A abuseipdb sinfo stype provider_credentials
      IP=198.51.100.23
      provider_credentials[ABUSEIPDB_API_KEY]=fixturekey123
      abuseipdb[score]=0
      show_progress(){ :; }
      check_place_fetch_json(){ print -u2 -- unexpected-relay; return 99; }
      response="$4" exit_code="$5" calls_file="$6"
      curl(){
        [[ "$(cat)" == *'header = "Key: fixturekey123"'* ]]||return 99
        print -r -- one-request >> "$calls_file"
        print -rn -- "$response"; return "$exit_code"
      }
      db_abuseipdb 4
      print -r -- "${abuseipdb[status]}|${abuseipdb[source]}|${abuseipdb[score]}"
    ZSH
    [["{}\n429", 0, "rate_limited"], ["{}\n401", 0, "http_401"],
      ["\n000", 35, "tls_error"], ['{"errors":[{"detail":"quota"}]}' + "\n200", 0, "invalid_response"],
      ['{"data":{"ipAddress":"8.8.8.8","abuseConfidenceScore":0}}' + "\n200", 0, "invalid_response"]].each do |response, code, expected|
      calls = File.join(reporter_workspace, "abuse-calls")
      File.write(calls, "")
      out, err, status = zsh(probe, COMMON_PROVIDER_LIBRARY,
        provider_library("abuseipdb"), reporter_functions("db_abuseipdb"), response, code.to_s, calls, COMMON_HTTP_LIBRARY)
      assert status.success?, err
      assert_empty err
      assert_equal "one-request\n", File.read(calls)
      assert_equal "#{expected}|official_api|\n", out
    end
  end
end
