# frozen_string_literal: true

require_relative "support/reporter_test_case"

class PublicFallbacksTest < ReporterTestCase
  IP2_LIBRARY = File.join(ROOT, "providers", "ip2location.zsh")
  IPDATA_LIBRARY = File.join(ROOT, "providers", "ipdata.zsh")
  IP2_PAGE = File.join(ROOT, "test", "fixtures", "ip2location", "public-page.html")
  IPDATA_PAGE = File.join(ROOT, "test", "fixtures", "ipdata", "public-page.html")
  IPDATA_RESPONSE = File.join(ROOT, "test", "fixtures", "ipdata", "public-response.json")

  def test_ip2location_page_binds_both_heading_and_json_without_executing_scripts
    code = <<~'ZSH'
      source "$1"
      response=$(ip2location_page_response "$(cat)" "$2")||exit 1
      ip2location_response_is_valid "$response" "$2"||exit 1
      print -r -- "$response"|jq -c '{ip, fraud_score, vpn: .proxy.is_vpn}'
    ZSH
    page = File.read(IP2_PAGE)
    ["198.51.100.23", "2001:4860:4860::8888"].each do |ip|
      out, err, status = Open3.capture3("/bin/zsh", "-f", "-c", code, "ip2", IP2_LIBRARY, ip,
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
      out, err, status = Open3.capture3("/bin/zsh", "-f", "-c", code, "ip2", IP2_LIBRARY,
        "198.51.100.23", stdin_data: invalid)
      refute status.success?
      assert_empty out
      assert_empty err
    end
  end

  def test_ipdata_demo_key_requires_one_exact_public_origin_and_safe_value
    page = File.read(IPDATA_PAGE)
    [page, page + page, page.sub("api.ipdata.co", "attacker.invalid"),
      page.sub("abcdef0123456789abcdef0123456789", 'unsafe"value'), page + " " * 262_144].each_with_index do |body, index|
      out, err, status = Open3.capture3("/bin/zsh", "-f", "-c",
        'source "$1"; ipdata_demo_key_from_page "$(cat)"', "ipdata-key", IPDATA_LIBRARY, stdin_data: body)
      assert_empty err
      assert_equal index.zero?, status.success?
      assert_equal(index.zero? ? "abcdef0123456789abcdef0123456789\n" : "", out)
    end
  end

  def test_ipdata_rejects_error_bodies_mismatched_targets_and_non_boolean_factors
    valid = JSON.parse(File.read(IPDATA_RESPONSE))
    [valid, {"message" => "quota exceeded"}, valid.merge("ip" => "8.8.8.8"),
      valid.merge("threat" => "bad"), valid.merge("threat" => {"is_proxy" => "false"}),
      valid.merge("threat" => {}), valid.merge("threat" => {"is_proxy" => false})].each_with_index do |body, index|
      _out, err, status = Open3.capture3("/bin/zsh", "-f", "-c",
        'source "$1"; ipdata_response_is_valid "$(cat)" 198.51.100.23', "ipdata-schema", IPDATA_LIBRARY,
        stdin_data: JSON.generate(body))
      assert_empty err
      assert_equal [0, 6].include?(index), status.success?
    end
  end

  def test_default_report_recovers_both_sources_and_keeps_demo_key_out_of_arguments_and_report
    calls = File.join(reporter_workspace, "calls")
    text_report = File.join(reporter_workspace, "report.txt")
    write_fake_command("curl", <<~'ZSH')
      print -rl -- "$@" >> "$IPQUALITY_TEST_CALLS"
      request=$(cat)
      if [[ "$*" == *'https://www.ip2location.com/8.8.8.8'* ]];then
        sed 's/198.51.100.23/8.8.8.8/g' "$IPQUALITY_TEST_IP2_PAGE"
      elif [[ "$*" == *'https://ipdata.co/'* && "$*" != *'--config'* ]];then
        cat "$IPQUALITY_TEST_IPDATA_PAGE"
      elif [[ "$request" == *'https://api.ipdata.co/8.8.8.8?api-key=abcdef0123456789abcdef0123456789'* ]];then
        [[ "$*" == *'Origin: https://ipdata.co'* && "$*" == *'Referer: https://ipdata.co/'* ]]||exit 99
        print -r -- ipdata-lookup >> "$IPQUALITY_TEST_CALLS"
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
        "IPQUALITY_TEST_IPDATA_PAGE" => IPDATA_PAGE, "IPQUALITY_TEST_IPDATA_RESPONSE" => IPDATA_RESPONSE})
    assert status.success?, err
    refute_match(/jq: error/, err)
    report = JSON.parse(out)
    assert_equal "all", report.dig("Query", "SourceSelection")
    assert_equal "ok", report.dig("ProviderStatus", "IP2Location")
    assert_equal "0", report.dig("Score", "IP2LOCATION")
    assert_equal "ok", report.dig("ProviderStatus", "ipdata")
    %w[IP2LOCATION ipdata].each do |name|
      assert_equal false, report.dig("Factor", "VPN", name)
      assert_equal true, report.dig("Factor", "Server", name)
      assert_equal "public_demo", report.dig("FactorMeta", name, "Source")
      assert_equal "skipped_relay_cloudflare_blocked", report.dig("FactorMeta", name, "RelayStatus")
    end
    assert_equal "public_demo", report.dig("ScoreMeta", "IP2LOCATION", "Source")
    args = File.readlines(calls, chomp: true)
    assert_equal 1, args.count("https://www.ip2location.com/8.8.8.8")
    assert_equal 1, args.count("https://ipdata.co/")
    assert_equal 1, args.count("ipdata-lookup")
    assert_equal 1, args.count { |a| a.start_with?("https://ipinfo.check.place/") }
    [out, err, File.read(calls), File.read(text_report)].each do |text|
      refute_includes text, "abcdef0123456789abcdef0123456789"
    end
    assert_includes File.read(text_report), "公开示例/可用"
  end

  def test_fallbacks_preserve_route_stop_on_failure_and_leave_missing_flags_unknown
    probe = <<~'ZSH'
      source "$1"; source "$2"; source "$3"; eval "$4"; source "$9"
      typeset -A ip2location ipdata sinfo stype
      IP=198.51.100.23 ibar_step=0 sinfo[ldatabase]=0
      CurlARG='--proxy http://127.0.0.1:12345'; setopt SH_WORD_SPLIT
      show_progress(){ :; }
      calls_file="$5" page_file="$6" data_file="$7" scenario="$8"
      check_place_fetch_json(){ PROVIDER_RESPONSE_STATUS=skipped_relay_cloudflare_blocked; PROVIDER_RESPONSE_BODY=''; }
      curl(){
        print -r -- called >> "$calls_file"
        [[ "$*" == *'--proxy http://127.0.0.1:12345'* && "$*" == *'-6'* ]]||exit 99
        if [[ "$scenario" == tls ]];then print -rn -- $'\n000'; return 35;fi
        if [[ "$scenario" == limit ]];then print -rn -- $'limit\n429'; return 0;fi
        if [[ "$*" == *'--config'* ]];then
          request=$(cat)
          [[ "$request" == *'https://api.ipdata.co/198.51.100.23?api-key='* ]]||exit 99
          print -r -- '{"ip":"198.51.100.23","country_code":"US","threat":{"is_proxy":false}}'
        else print -r -- "$(<"$page_file")";fi
        print -rn -- 200
      }
      if [[ "$scenario" == ipdata ]];then
        db_ipdata 6
        print -r -- "${ipdata[status]}|${ipdata[proxy]}|${ipdata[vpn]}|${ipdata[abuser]}"
      else
        ip2location[score]=99; db_ip2location 6
        print -r -- "${ip2location[status]}|${ip2location[score]}"
      fi
    ZSH
    Dir.mktmpdir("source-fallback-") do |dir|
      calls = File.join(dir, "calls")
      [["tls", IP2_PAGE, "tls_error|\n", 1], ["limit", IP2_PAGE, "rate_limited|\n", 1],
        ["ipdata", IPDATA_PAGE, "ok|false|null|\n", 2]].each do |scenario, page, expected, count|
        File.write(calls, "")
        out, err, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "route",
          COMMON_PROVIDER_LIBRARY, IP2_LIBRARY, IPDATA_LIBRARY,
          reporter_functions("db_ip2location", "db_ipdata"), calls, page, IPDATA_RESPONSE, scenario, COMMON_HTTP_LIBRARY)
        assert status.success?, err
        assert_empty err
        assert_equal expected, out
        assert_equal count, File.readlines(calls).length
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
      IP=198.51.100.23 ibar_step=0 sinfo[ldatabase]=0
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
    out, err, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "relay",
      COMMON_PROVIDER_LIBRARY, IP2_LIBRARY, IPDATA_LIBRARY, reporter_functions("db_ip2location", "db_ipdata"))
    assert status.success?, err
    assert_empty err
    assert_equal "ok|check_place_relay|0|\nok|check_place_relay|false|\n", out
  end

  def test_abuseipdb_failures_clear_stale_scores_without_retry_or_relay
    probe = <<~'ZSH'
      source "$1"; source "$2"; eval "$3"; source "$7"
      typeset -A abuseipdb sinfo stype provider_credentials
      IP=198.51.100.23 ibar_step=0 sinfo[ldatabase]=0
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
      out, err, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "abuse-errors", COMMON_PROVIDER_LIBRARY,
        File.join(ROOT, "providers", "abuseipdb.zsh"), reporter_functions("db_abuseipdb"), response, code.to_s, calls, COMMON_HTTP_LIBRARY)
      assert status.success?, err
      assert_empty err
      assert_equal "one-request\n", File.read(calls)
      assert_equal "#{expected}|official_api|\n", out
    end
  end
end
