# frozen_string_literal: true

require_relative "support/reporter_test_case"

class ProvidersTest < ReporterTestCase
  def test_provider_adapters_read_literal_json_without_interpreting_backslash_escapes
    cases = [
      ["ipinfo", {data: {asn: {asn: "AS64500", name: "Example Network"}, country: "US", loc: "0,0"}}, "64500"],
      ["scamalytics", {scamalytics: {scamalytics_score: 7}}, "7"],
      ["abuseipdb", {data: {ipAddress: "198.51.100.23", abuseConfidenceScore: 3}}, "3"],
      ["ip2location", {ip: "198.51.100.23", fraud_score: 4}, "4"],
      ["ipdata", fixture_json("ipdata/public-response.json"), "false"],
      ["ipqs", JSON.parse(File.read(IPQS_FIXTURE)), "87"]
    ]
    probe = <<~'ZSH'
      source "$1"
      fixture_response="$2" adapter="$3"
      IP=198.51.100.23
      show_progress(){ :; }
      curl(){ print -r -- "$fixture_response"; print -rn -- 200; }
      check_place_fetch_json(){ PROVIDER_RESPONSE_STATUS=ok; PROVIDER_RESPONSE_BODY="$fixture_response"; }
      "db_$adapter" 4
      case "$adapter" in
      ipinfo) print -r -- "${ipinfo[status]}|${ipinfo[asn]}" ;;
      scamalytics) print -r -- "${scamalytics[status]}|${scamalytics[score]}" ;;
      abuseipdb) print -r -- "${abuseipdb[status]}|${abuseipdb[score]}" ;;
      ip2location) print -r -- "${ip2location[status]}|${ip2location[score]}" ;;
      ipdata) print -r -- "${ipdata[status]}|${ipdata[proxy]}" ;;
      ipqs) print -r -- "${ipqs[status]}|${ipqs[score]}" ;;
      esac
    ZSH
    cases.each do |name, payload, expected|
      # Unknown text fields are allowed; their JSON escapes must not corrupt
      # an otherwise valid response before the requested observations are read.
      payload["description"] = 'Example \\quality'
      assert_equal "ok|#{expected}\n", zsh!(probe, SCRIPT, JSON.generate(payload), name), name
    end
  end

  def test_ipinfo_and_ipregistry_keep_transport_and_schema_failures_without_old_values
    probe = <<~'ZSH'
      source "$1"
      eval "$2"
      typeset -A ipinfo ipregistry provider_credentials sinfo
      IP=198.51.100.23
      provider_credentials[IPREGISTRY_API_KEY]=fixture-key
      show_progress(){ :; }
      curl(){ return 35; }
      curl_with_secret_header(){ return 28; }
      ipinfo[countrycode]=US ipregistry[proxy]=false
      db_ipinfo
      db_ipregistry 4
      print -r -- "${ipinfo[status]}|${ipinfo[countrycode]}|${ipregistry[status]}|${ipregistry[proxy]}"
      curl(){ print -r -- $'{"data":"schema drift"}\n200'; }
      db_ipinfo
      print -r -- "${ipinfo[status]}|${ipinfo[proxy]}"
    ZSH
    assert_equal "tls_error||timeout|\ninvalid_response|\n",
      zsh!(probe, COMMON_PROVIDER_LIBRARY, reporter_functions("db_ipinfo", "db_ipregistry"))
  end

  def test_ping0_parser_accepts_exact_four_line_geo_and_rejects_challenge_html_or_another_ip
    probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      ping0_parse_geo "$(<"$2")" "$3" || exit $?
      print -r -- "${ping0_parsed[0]}|${ping0_parsed[2]}|${ping0_parsed[3]}"
    ZSH
    library = provider_library("ping0")
    assert_equal "198.51.100.23|AS64500|Example Network\n",
      zsh!(probe, library, fixture_path("ping0/public-geo.txt"), "198.51.100.23")
    refute zsh(probe, library, fixture_path("ping0/challenge.html"), "198.51.100.23")[2].success?
    refute zsh(probe, library, fixture_path("ping0/public-geo.txt"), "198.51.100.24")[2].success?
  end

  def test_ping0_runtime_keeps_transport_http_and_schema_failures_without_old_observations
    geo = File.read(fixture_path("ping0/public-geo.txt")).strip
    cases = [
      ["#{geo}\n200", 0, "verified", true, "AS64500"],
      ["#{geo}\n000", 35, "tls_error", nil, nil],
      ["\n000", 28, "timeout", nil, nil],
      ["\n000", 60, "tls_verification_failed", nil, nil],
      ["#{geo}\n429", 0, "rate_limited", nil, nil],
      ["#{geo}\n503", 0, "http_503", nil, nil],
      ["<html>challenge</html>\n200", 0, "invalid_response", nil, nil],
      ["#{geo.sub('198.51.100.23', '198.51.100.24')}\n200", 0, "ip_mismatch", false, nil]
    ]
    probe = <<~'ZSH'
      source "$1"
      wire="$2" curl_code="$3" IP=198.51.100.23
      ping0=([status]=verified [match]=true [asn]=AS999 [org]=stale)
      show_progress(){ :; }
      curl(){ print -rn -- "$wire"; return "$curl_code"; }
      db_ping0 4
      save_json
      print -r -- "$ipjson"
    ZSH
    cases.each do |wire, curl_code, state, match, asn|
      observation = JSON.parse(zsh!(probe, SCRIPT, wire, curl_code.to_s)).fetch("Ping0")
      assert_equal state, observation.fetch("Status")
      assert_equal [match, asn], [observation.fetch("IPMatch"), observation.fetch("ASN")], state
      assert_nil observation.fetch("Organization") unless state == "verified"
    end
    report_probe = <<~'ZSH'
      source "$1"
      set_language
      ping0[status]=tls_error
      clean_ansi "$(show_unavailable_sources)"
    ZSH
    assert_includes zsh!(report_probe, SCRIPT), "Ping0 (TLS 握手失败)"
  end

  def test_official_context_provider_parsers_reject_mismatches_and_keep_dimensions
    probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      ripestat_parse_network_info "$(<"$2")" || exit $?
      print -r -- "${ripestat_parsed[prefix]}|${ripestat_parsed[origins]}"
      source "$3"
      internetdb_parse_response "$(<"$4")" "$5" || exit $?
      print -r -- "${internetdb_parsed[ports]}|${internetdb_parsed[port_count]}|${internetdb_parsed[hostname_count]}|${internetdb_parsed[vulnerability_count]}"
    ZSH
    arguments = [provider_library("ripestat"), fixture_path("ripestat/network-info.json"),
                 provider_library("shodan_internetdb"), fixture_path("shodan/internetdb.json")]
    assert_equal "198.51.100.0/24|AS64500\n22, 443|2|1|1\n", zsh!(probe, *arguments, "198.51.100.23")
    refute zsh(probe, *arguments, "198.51.100.24")[2].success?
    refute zsh('setopt KSH_ARRAYS; source "$1"; ripestat_parse_network_info "$2"', provider_library("ripestat"),
      '{"status":"ok","data":{"prefix":"198.51.100.0/24","asns":["AS64500"]}}')[2].success?
  end

  def test_shodan_rejects_fractional_ports_and_control_text_without_retaining_observations
    fixture = fixture_json("shodan/internetdb.json")
    probe = <<~'ZSH'
      source "$1"
      internetdb_parse_response "$(<"$2")" 198.51.100.23 || exit 1
      internetdb_parse_response "$3" 198.51.100.23 && exit 2
      (( ${#internetdb_parsed[@]} == 0 ))
    ZSH
    invalid = [22.5, -1, 0, 65536, nil, "443", true].map { |value| fixture.merge("ports" => [value]) }
    %w[tags vulns hostnames].each do |field|
      ["value\nnext", "\e[31mtext", "value\0", nil].each do |value|
        invalid << fixture.merge(field => [value])
      end
    end
    invalid.each do |body|
      assert_empty zsh!(probe, provider_library("shodan_internetdb"), fixture_path("shodan/internetdb.json"),
        JSON.generate(body)), "accepted malformed or retained previous fields: #{body.inspect}"
    end
  end

  def test_common_provider_helpers_validate_objects_and_merge_boolean_signals_conservatively
    probe = <<~'ZSH'
      source "$1"
      provider_json_is_object '{"provider":"fixture"}' || exit 1
      provider_json_is_object '[]' && exit 2
      provider_integer_in_range 99 0 99 || exit 3
      provider_integer_in_range 100 0 99 && exit 4
      provider_integer_in_range null 0 99 && exit 5
      provider_has_observation null unknown '' && exit 6
      provider_has_observation null false || exit 7
      print -r -- "$(provider_merge_boolean_signals false true null)|$(provider_merge_boolean_signals false false)|$(provider_merge_boolean_signals false null)"
    ZSH
    assert_equal "true|false|\n", zsh!(probe, COMMON_PROVIDER_LIBRARY)
  end

  def test_credentialed_provider_parsers_keep_official_dimensions_without_invented_scores
    probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      source "$2"
      ipregistry_parse_response "$(<"$3")" "$7" || exit 11
      print -r -- "${ipregistry_parsed[usage_type]}|${ipregistry_parsed[server]}|${ipregistry_parsed[tor]}|${ipregistry_parsed[abuser]}"
      source "$4"
      ipqualityscore_parse_response "$(<"$5")" || exit 13
      print -r -- "${ipqualityscore_parsed[score]}|${ipqualityscore_parsed[connection_type]}|${ipqualityscore_parsed[proxy]}|${ipqualityscore_parsed[tor]}|${ipqualityscore_parsed[server]}"
      ipqualityscore_parse_usage_response "$(<"$6")" || exit 14
      print -r -- "${ipqualityscore_usage[credits]}|${ipqualityscore_usage[usage]}|${ipqualityscore_usage[proxy_usage]}"
      print -r -- "$(ipqualityscore_connection_type_server_flag Residential)|$(ipqualityscore_connection_type_server_flag Unknown)"
    ZSH
    arguments = [COMMON_PROVIDER_LIBRARY, provider_library("ipregistry"), fixture_path("ipregistry/ip-intelligence.json"),
                 provider_library("ipqualityscore"), IPQS_FIXTURE, fixture_path("ipqualityscore/usage.json")]
    assert_equal "hosting|true|false|false\n87|Data Center|true|false|true\n12|7|3\nfalse|\n",
      zsh!(probe, *arguments, "198.51.100.23")
    assert_equal 11, zsh(probe, *arguments, "198.51.100.24")[2].exitstatus
  end

  def test_ipapi_parser_distinguishes_full_anonymous_and_mixed_contracts
    probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      ipapi_parse_response "$2" 198.51.100.23 || exit $?
      print -r -- "${ipapi_parsed[mode]}|${ipapi_parsed[usage_type]}|${ipapi_parsed[company_type]}|${ipapi_parsed[score_text]}|${ipapi_parsed[country_code]}|${ipapi_parsed[proxy]}|${ipapi_parsed[abuser]}"
    ZSH
    library = provider_library("ipapi")
    assert_equal "full|isp|isp|0.01 (Very Low)|US|false|false\n",
      zsh!(probe, library, File.read(fixture_path("ipapi/valid.json")))
    # Anonymous responses never supply risk flags, even when a field is present.
    anonymous = fixture_json("ipapi/anonymous.json").merge("is_proxy" => false, "is_abuser" => false)
    assert_equal "anonymous||||||\n", zsh!(probe, library, JSON.generate(anonymous))
    [File.read(fixture_path("ipapi/malformed.json")),
     JSON.generate(anonymous.merge("location" => {"country_code" => "US"}))].each do |body|
      _stdout, stderr, status = zsh(probe, library, body)
      refute status.success?
      assert_empty stderr
    end
  end

  def test_ipapi_runtime_reports_each_outcome_without_stale_or_invented_risk
    probe = <<~'ZSH'
      source "$1"
      shift
      IP=198.51.100.23
      show_progress(){ :; }
      respond(){ [[ -n "$fixture" ]]&&print -r -- "$(<"$fixture")"; print -rn -- "$http"; return "$curl_exit"; }
      curl(){ [[ "$mode" == anonymous ]]||exit 98; respond; }
      curl_with_secret_url(){ [[ "$mode" == key ]]||exit 98; respond; }
      while (( $# ));do
        mode="$1" fixture="$2" http="$3" curl_exit="$4"
        shift 4
        provider_credentials[IPAPI_API_KEY]=''
        [[ "$mode" == key ]]&&provider_credentials[IPAPI_API_KEY]=fixture-ipapi-key
        db_ipapi 4
        print -r -- "$?|${ipapi[status]}|${ipapi[credential_mode]}|${ipapi[mode]}|${ipapi[usetype]}|${ipapi[score]}|${ipapi[proxy]}|${ipapi[anonymous_asn]}"
      done
    ZSH
    cases = {
      ["key", "ipapi/valid.json", "200", 0] => "0|ok|key|full|isp|1.00%|false|",
      ["anonymous", "ipapi/anonymous.json", "200", 0] => "0|ok|anonymous|anonymous||||AS64500 Example ISP",
      ["anonymous", "ipapi/malformed.json", "200", 0] => "1|invalid_response|anonymous|||||",
      ["key", "ipapi/rate-limited.json", "429", 0] => "1|rate_limited|key|||||",
      # Transport failures are never quota exhaustion and keep no flags.
      ["key", "", "000", 28] => "1|timeout|key|||||",
      ["key", "", "000", 35] => "1|tls_error|key|||||",
      ["key", "", "000", 60] => "1|tls_verification_failed|key|||||",
      ["key", "", "000", 7] => "1|network_error|key|||||"
    }
    arguments = cases.keys.flat_map do |mode, fixture, http, code|
      [mode, fixture.empty? ? "" : fixture_path(fixture), http, code.to_s]
    end
    assert_equal cases.values, zsh!(probe, SCRIPT, *arguments).lines(chomp: true)
  end

  def test_ipwhois_parser_keeps_demo_context_without_security_and_rejects_target_mismatch
    probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      ipwhois_parse_response "$(<"$2")" 198.51.100.23 || exit $?
      print -r -- "${ipwhois_parsed[country_code]}|${ipwhois_parsed[asn]}|${ipwhois_parsed[organization]}|${ipwhois_parsed[isp]}|${ipwhois_parsed[timezone]}"
    ZSH
    library = provider_library("ipwhois")
    assert_equal "US|64500|Example Network|Example ISP|America/Los_Angeles\n",
      zsh!(probe, library, fixture_path("ipwhois/valid.json"))
    _stdout, stderr, status = zsh(probe, library, fixture_path("ipwhois/mismatch.json"))
    refute status.success?
    assert_empty stderr
  end

  def test_cloudflare_parser_keeps_categories_and_numeric_asns_and_rejects_schema_drift
    valid = cloudflare_parse(File.read(fixture_path("cloudflare/valid.json")))
    assert_equal ["ok", "US", "AS64500", "Example Network", "hosting_provider", "Phishing, Malware"], valid.first(6)
    commas = {"success" => true, "result" => [{"ip" => "198.51.100.23", "risk_types" => [{"name" => "Malware, command and control"}]}]}
    assert_equal ["Malware, command and control"], JSON.parse(cloudflare_parse(JSON.generate(commas)).last)
    assert_equal "not_found", cloudflare_parse(File.read(fixture_path("cloudflare/empty.json"))).first

    # Live responses carry numeric ASNs; absent categories stay unknown, not empty.
    numeric = fixture_json("cloudflare/numeric-asn.json")
    assert_equal %w[AS64500 null], cloudflare_parse(JSON.generate(numeric)).values_at(2, 6)
    numeric["result"][0]["risk_types"] = []
    assert_equal %w[AS64500 []], cloudflare_parse(JSON.generate(numeric)).values_at(2, 6)
    invalid = [-1, 1.5, 4_294_967_296].map do |asn|
      JSON.generate(numeric.merge("result" => [numeric["result"][0].merge("belongs_to_ref" =>
        numeric["result"][0]["belongs_to_ref"].merge("value" => asn))]))
    end
    (invalid << File.read(fixture_path("cloudflare/invalid-risk-type.json"))).each do |body|
      assert_nil cloudflare_parse(body), body
    end
  end

  def test_cloudflare_runtime_requires_both_credentials_and_uses_official_response
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      source "$2"
      source "$3"
      eval "$4"
      typeset -A cloudflare provider_credentials sinfo
      IP='198.51.100.23' CurlARG='' fixture="$5"
      show_progress(){ :; }
      curl_with_secret_header(){ print -r -- "$(<"$fixture")"; print -r -- 200; }
      provider_credentials[CLOUDFLARE_API_TOKEN]='fixture-token'
      provider_credentials[CLOUDFLARE_ACCOUNT_ID]='fixture-account'
      db_cloudflare 4
      print -r -- "${cloudflare[status]}|${cloudflare[network]}|${cloudflare[threats]}"
      provider_credentials[CLOUDFLARE_ACCOUNT_ID]=''
      db_cloudflare 4
      print -r -- "${cloudflare[status]}"
    ZSH
    assert_equal "ok|AS64500|Phishing, Malware\ninvalid_configuration\n",
      zsh!(probe, COMMON_PROVIDER_LIBRARY, provider_library("cloudflare"), QUERY_ROUTE_LIBRARY,
        reporter_functions("db_cloudflare", "http_route_is_proxied"), fixture_path("cloudflare/valid.json"))
  end

  def test_ipqs_account_quota_preflight_skips_a_lookup_that_would_spend_credit
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      source "$2"
      source "$3"
      eval "$4"
      typeset -A provider_credentials ipqs sinfo stype
      provider_credentials[IPQS_API_KEY]='fixture-key'
      IP='198.51.100.23' CurlARG=''
      quota_body="$5" calls_file="$6"
      show_progress(){ :; }
      styled_provider_type(){ print -rn -- "$1"; }
      curl_with_secret_url(){
        case "$1" in
          */api/json/account/*)
            print -r -- account >> "$calls_file"
            print -rn -- "$quota_body"$'\n200' ;;
          */api/json/ip/*)
            print -r -- lookup >> "$calls_file"
            return 97 ;;
          *) return 9 ;;
        esac
      }
      db_ipqs 4 || exit $?
      print -r -- "${ipqs[status]}|${ipqs[score]}"
    ZSH
    Dir.mktmpdir("ipquality-quota-") do |directory|
      calls_file = File.join(directory, "calls.txt")
      [File.read(fixture_path("ipqualityscore/insufficient-credits.json")),
       JSON.generate("success" => true, "credits" => 0, "usage" => 10)].each do |quota|
        File.write(calls_file, "")
        assert_equal "official_insufficient_credits|\n",
          zsh!(probe, COMMON_PROVIDER_LIBRARY, provider_library("ipqualityscore"), QUERY_ROUTE_LIBRARY,
            reporter_functions("db_ipqs", "http_route_is_proxied"), quota, calls_file)
        assert_equal "account\n", File.read(calls_file), "zero credit must prevent the paid lookup"
      end
    end
  end

  def test_ipqs_preserves_transport_http_and_schema_errors_at_both_request_stages
    probe = <<~'ZSH'
      unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy IPQUALITY_ISOLATED_EGRESS
      source "$1"
      source "$2"
      source "$3"
      eval "$4"
      typeset -A provider_credentials ipqs sinfo stype
      provider_credentials[IPQS_API_KEY]=fixture-key
      IP=198.51.100.23
      failed_stage="$5" curl_exit="$6" response_file="$7" calls_file="$8"
      show_progress(){ :; }
      styled_provider_type(){ print -rn -- "$1"; }
      curl_with_secret_url(){
        typeset phase=lookup
        [[ "$1" == */account/* ]]&&phase=account
        print -r -- "$phase" >> "$calls_file"
        if [[ "$phase" == "$failed_stage" ]];then
          print -rn -- "$(<"$response_file")"
          return "$curl_exit"
        fi
        print -rn -- $'{"success":true,"credits":100,"usage":1}\n200'
      }
      ipqs[score]=0 ipqs[proxy]=false
      db_ipqs 4
      print -r -- "${ipqs[status]}|${ipqs[score]}|${ipqs[proxy]}"
    ZSH
    cases = [
      [35, "\n000", "tls_error"], [28, "\n000", "timeout"],
      [60, "\n000", "tls_verification_failed"],
      [0, "Sorry, you have been blocked by Cloudflare\n403", "cloudflare_blocked"],
      [0, '{"success":true,"fraud_score":0}' + "\n401", "http_401"],
      [0, "slow down\n429", "rate_limited"],
      [0, '"changed schema"' + "\n200", "invalid_response"],
      [0, '{"success":false,"message":"Too many requests"}' + "\n200", "rate_limited"]
    ]
    functions = reporter_functions("db_ipqs", "http_route_is_proxied")
    Dir.mktmpdir("ipqs-failure-stages-") do |directory|
      response = File.join(directory, "response.txt")
      calls = File.join(directory, "calls.txt")
      %w[account lookup].each do |stage|
        stage_cases = cases.dup
        stage_cases << [0, File.read(IPQS_FIXTURE) + "\n200", "ok", "87", "true"] if stage == "lookup"
        stage_cases.each do |curl_exit, wire, expected, score, proxy|
          File.write(response, wire)
          File.write(calls, "")
          assert_equal "#{expected}|#{score}|#{proxy}\n",
            zsh!(probe, COMMON_PROVIDER_LIBRARY, provider_library("ipqualityscore"), QUERY_ROUTE_LIBRARY,
              functions, stage, curl_exit.to_s, response, calls)
          assert_equal stage == "account" ? "account\n" : "account\nlookup\n", File.read(calls)
        end
      end
    end
  end

  def test_optional_credentials_are_data_only_private_and_never_curl_arguments
    probe = <<~'ZSH'
      source "$1"
      provider_load_credentials "$2" || exit $?
      for key in IPREGISTRY_API_KEY IPQS_API_KEY IPAPI_API_KEY CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID;do
        print -rn -- "${provider_credentials[$key]}|"
      done
      provider_api_key_is_valid fixture_key-123456 || exit 3
      ! provider_api_key_is_valid $'bad\nkey' || exit 4
    ZSH
    library = provider_library("credentials")
    Dir.mktmpdir("ipquality-credentials-test") do |directory|
      credentials = File.join(directory, "credentials")
      File.write(credentials, "# fixture keys only\nIPREGISTRY_API_KEY=registry123\nIPQS_API_KEY=ipqs12345\n" \
        "IPAPI_API_KEY=ipapi_fixture_123\nCLOUDFLARE_API_TOKEN=token_fixture_123\nCLOUDFLARE_ACCOUNT_ID=account_fixture_123\n")
      File.chmod(0o600, credentials)
      assert_equal "registry123|ipqs12345|ipapi_fixture_123|token_fixture_123|account_fixture_123|",
        zsh!(probe, library, credentials)

      File.chmod(0o644, credentials)
      _stdout, insecure_stderr, insecure_status = zsh(probe, library, credentials)
      refute insecure_status.success?
      assert_includes insecure_stderr, "mode 600"

      marker = File.join(directory, "must-not-exist")
      File.write(credentials, "IPQS_API_KEY=$(touch #{marker})\n")
      File.chmod(0o600, credentials)
      refute zsh(probe, library, credentials)[2].success?
      refute File.exist?(marker)
    end

    source = REPORTER_SOURCES.map { |path| File.read(path, encoding: "UTF-8") }.join("\n")
    assert_includes source, "--config -"
    refute_match(/\bcurl\s[^\n]*\$api_key/, source)
  end

  def test_known_provider_failures_are_classified_without_echoing_upstream_messages
    probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      ipqualityscore_parse_unavailability "$(<"$2")" || exit $?
      print -r -- "${ipqualityscore_unavailable[status]}"
      source "$3"
      internetdb_parse_unavailability "$(<"$4")" || exit $?
      print -r -- "${internetdb_unavailable[status]}"
    ZSH
    stdout = zsh!(probe, provider_library("ipqualityscore"), fixture_path("ipqualityscore/insufficient-credits.json"),
      provider_library("shodan_internetdb"), fixture_path("shodan/no-information.json"))
    assert_equal "upstream_insufficient_credits\nnot_found\n", stdout
  end

  def test_private_project_secret_files_load_by_provider_name_and_override_global_defaults
    probe = <<~'ZSH'
      source "$1"
      provider_load_credentials "$2" "$3" || exit $?
      print -r -- "${provider_credentials[IPREGISTRY_API_KEY]}|${provider_credentials[IPQS_API_KEY]}"
    ZSH
    library = provider_library("credentials")
    Dir.mktmpdir("ipquality-project-secrets-test") do |directory|
      credentials = File.join(directory, "credentials")
      project_secrets = File.join(directory, "secrets")
      Dir.mkdir(project_secrets, 0o700)
      File.write(credentials, "IPREGISTRY_API_KEY=globalregistry123\nIPQS_API_KEY=globalipqs12345\n", perm: 0o600)
      File.write(File.join(project_secrets, "ipregistry"), "projectregistry123\n", perm: 0o600)
      File.write(File.join(project_secrets, "ipqs"), "projectipqs12345\n", perm: 0o600)
      assert_equal "projectregistry123|projectipqs12345\n", zsh!(probe, library, credentials, project_secrets)

      File.chmod(0o644, File.join(project_secrets, "ipqs"))
      _stdout, insecure_stderr, insecure_status = zsh(probe, library, credentials, project_secrets)
      refute insecure_status.success?
      assert_includes insecure_stderr, "mode 600"
    end

    assert_includes File.read(SCRIPT, encoding: "UTF-8"), 'provider_load_credentials "" "$SCRIPT_DIR/secrets"'
  end

  def test_one_type_styler_maps_every_provider_vocabulary
    probe = reporter_functions("styled_provider_type") + <<~'ZSH'
      typeset -A stype=([business]=B [isp]=I [mobile]=M [hosting]=H [education]=E [government]=G [banking]=K [reserved]=R [unknown]=U [other]=O)
      for raw in Business corporate ISP residential mobile Mobile "data center" hosting education government banking reserved "" null unknown satellite;do
        print -rn -- "$(styled_provider_type "$raw")"
      done
    ZSH
    assert_equal "BBIIMMHHEGKRUUUO", zsh!(probe)
  end

  def test_ipinfo_widget_fields_map_in_one_pass_with_country_names
    payload = {data: {asn: {asn: "AS64500", name: "Example Network", type: "hosting"},
      company: {type: "business"}, country: "US", city: "Example City", postal: "00000",
      timezone: "America/Chicago", loc: "37.751,-97.822",
      privacy: {proxy: false, tor: false, vpn: true, hosting: true}, abuse: {country: "DE"}}}
    probe = <<~'ZSH'
      source "$1"
      IP=198.51.100.23
      show_progress(){ :; }
      fixture="$2"
      curl(){ print -r -- "$fixture"; print -rn -- 200; }
      db_ipinfo 4
      for key in status asn org usetype comtype countrycode country regcountrycode regcountry city post timezone lat lon proxy tor vpn server dms;do
        print -r -- "$key=${ipinfo[$key]}"
      done
    ZSH
    fields = zsh!(probe, SCRIPT, JSON.generate(payload)).lines(chomp: true).to_h { |line| line.split("=", 2) }
    countries = JSON.parse(File.read(ISO3166)).to_h { |row| [row.fetch("alpha-2"), row.fetch("name")] }
    assert_equal({"status" => "ok", "asn" => "64500", "org" => "Example Network", "usetype" => "hosting",
      "comtype" => "business", "countrycode" => "US", "country" => countries.fetch("US"),
      "regcountrycode" => "DE", "regcountry" => countries.fetch("DE"), "city" => "Example City",
      "post" => "00000", "timezone" => "America/Chicago", "lat" => "37.751", "lon" => "-97.822",
      "proxy" => "false", "tor" => "false", "vpn" => "true", "server" => "true",
      "dms" => "97°49′19″W, 37°45′4″N"}, fields)
  end

  private

  # Parsed Cloudflare fields, or nil when the parser rejects the body silently.
  def cloudflare_parse(body)
    probe = <<~'ZSH'
      source "$1"
      cloudflare_parse_response "$2" 198.51.100.23 || exit 1
      print -r -- "${cloudflare_parsed[status]}|${cloudflare_parsed[country_code]}|${cloudflare_parsed[network]}|${cloudflare_parsed[organization]}|${cloudflare_parsed[infrastructure_type]}|${cloudflare_parsed[threat_categories]}|${cloudflare_parsed[threat_categories_json]}"
    ZSH
    stdout, stderr, status = zsh(probe, provider_library("cloudflare"), body)
    assert_empty stderr
    status.success? ? stdout.chomp.split("|", -1) : nil
  end
end
