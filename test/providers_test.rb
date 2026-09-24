# frozen_string_literal: true

require_relative "support/reporter_test_case"

class ProvidersTest < ReporterTestCase
  def test_ping0_parser_accepts_exact_four_line_geo_and_rejects_challenge_html
    parser_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      response=$(<"$2")
      ping0_parse_geo "$response" "$3" || exit $?
      print -r -- "${ping0_parsed[0]}|${ping0_parsed[2]}|${ping0_parsed[3]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      parser_probe,
      "ping0-parser-test",
      PING0_LIBRARY,
      PING0_GEO_FIXTURE,
      "198.51.100.23"
    )
    assert status.success?, stderr
    assert_equal "198.51.100.23|AS64500|Example Network\n", stdout
    assert_empty stderr

    _stdout, _stderr, challenge_status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      parser_probe,
      "ping0-parser-test",
      PING0_LIBRARY,
      PING0_CHALLENGE_FIXTURE,
      "198.51.100.23"
    )
    refute challenge_status.success?
  end

  def test_official_context_provider_parsers_reject_mismatches_and_keep_dimensions
    parser_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      response=$(<"$2")
      ripestat_parse_network_info "$response" || exit $?
      print -r -- "${ripestat_parsed[prefix]}|${ripestat_parsed[origins]}"
      source "$3"
      response=$(<"$4")
      internetdb_parse_response "$response" "$5" || exit $?
      print -r -- "${internetdb_parsed[ports]}|${internetdb_parsed[hostname_count]}|${internetdb_parsed[vulnerability_count]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      parser_probe,
      "provider-parser-test",
      RIPESTAT_LIBRARY,
      RIPESTAT_FIXTURE,
      INTERNETDB_LIBRARY,
      INTERNETDB_FIXTURE,
      "198.51.100.23"
    )
    assert status.success?, stderr
    assert_equal "198.51.100.0/24|AS64500\n22, 443|1|1\n", stdout
    assert_empty stderr

    _stdout, _stderr, malformed_asn_status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      'setopt KSH_ARRAYS; source "$1"; ripestat_parse_network_info "$2"',
      "ripestat-malformed-asn-test",
      RIPESTAT_LIBRARY,
      '{"status":"ok","data":{"prefix":"198.51.100.0/24","asns":["AS64500"]}}'
    )
    refute malformed_asn_status.success?

    _stdout, _stderr, mismatch_status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      'setopt KSH_ARRAYS; source "$1"; internetdb_parse_response "$(<"$2")" "$3"',
      "provider-mismatch-test",
      INTERNETDB_LIBRARY,
      INTERNETDB_FIXTURE,
      "198.51.100.24"
    )
    refute mismatch_status.success?
  end

  def test_common_provider_helpers_validate_objects_and_merge_boolean_signals_conservatively
    helper_probe = <<~'ZSH'
      source "$1"
      provider_json_is_object '{"provider":"fixture"}' || exit 1
      provider_json_is_object '[]' && exit 2
      provider_integer_in_range 99 0 99 || exit 3
      provider_integer_in_range 100 0 99 && exit 4
      provider_has_observation null unknown '' && exit 5
      provider_has_observation null false || exit 6
      print -r -- "$(provider_merge_boolean_signals false true null)|$(provider_merge_boolean_signals false false)|$(provider_merge_boolean_signals false null)"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      helper_probe,
      "common-provider-test",
      COMMON_PROVIDER_LIBRARY
    )

    assert status.success?, stderr
    assert_equal "true|false|\n", stdout
    assert_empty stderr
  end

  def test_credentialed_provider_parsers_keep_official_dimensions_without_invented_scores
    parser_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      source "$2"
      ipregistry_parse_response "$(<"$3")" 198.51.100.23 || exit 11
      print -r -- "${ipregistry_parsed[usage_type]}|${ipregistry_parsed[server]}|${ipregistry_parsed[tor]}|${ipregistry_parsed[abuser]}"
      source "$4"
      ipqualityscore_parse_response "$(<"$5")" || exit 13
      print -r -- "${ipqualityscore_parsed[score]}|${ipqualityscore_parsed[connection_type]}|${ipqualityscore_parsed[proxy]}|${ipqualityscore_parsed[tor]}|${ipqualityscore_parsed[server]}"
      ipqualityscore_parse_usage_response "$(<"$6")" || exit 14
      print -r -- "${ipqualityscore_usage[credits]}|${ipqualityscore_usage[usage]}|${ipqualityscore_usage[proxy_usage]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      parser_probe,
      "credentialed-provider-parser-test",
      COMMON_PROVIDER_LIBRARY,
      IPREGISTRY_LIBRARY,
      IPREGISTRY_FIXTURE,
      IPQUALITYSCORE_LIBRARY,
      IPQUALITYSCORE_OFFICIAL_FIXTURE,
      IPQUALITYSCORE_USAGE_FIXTURE
    )

    assert status.success?, stderr
    assert_equal "hosting|true|false|false\n87|Data Center|true|false|true\n12|7|3\n", stdout
    assert_empty stderr

    _stdout, _stderr, mismatch_status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      'setopt KSH_ARRAYS; source "$1"; source "$2"; ipregistry_parse_response "$(<"$3")" 198.51.100.24',
      "ipregistry-mismatch-test",
      COMMON_PROVIDER_LIBRARY,
      IPREGISTRY_LIBRARY,
      IPREGISTRY_FIXTURE
    )
    refute mismatch_status.success?
  end

  def test_ipapi_parser_distinguishes_full_and_anonymous_responses
    parser_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      response=$(<"$2")
      ipapi_parse_response "$response" "$3" || exit $?
      print -r -- "${ipapi_parsed[mode]}|${ipapi_parsed[usage_type]}|${ipapi_parsed[company_type]}|${ipapi_parsed[score_text]}|${ipapi_parsed[country_code]}|${ipapi_parsed[proxy]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", parser_probe,
      "ipapi-parser-test", IPAPI_LIBRARY, IPAPI_FIXTURE, "198.51.100.23"
    )
    assert status.success?, stderr
    assert_equal "full|isp|isp|0.01 (Very Low)|US|false\n", stdout
    assert_empty stderr

    anonymous_stdout, anonymous_stderr, anonymous_status = Open3.capture3(
      "/bin/zsh", "-f", "-c", parser_probe,
      "ipapi-anonymous-test", IPAPI_LIBRARY, IPAPI_ANONYMOUS_FIXTURE, "198.51.100.23"
    )
    assert anonymous_status.success?, anonymous_stderr
    assert_equal "anonymous|||||\n", anonymous_stdout
    assert_empty anonymous_stderr

    _stdout, malformed_stderr, malformed_status = Open3.capture3(
      "/bin/zsh", "-f", "-c",
      'setopt KSH_ARRAYS; source "$1"; ipapi_parse_response "$(<"$2")" "198.51.100.23"',
      "ipapi-schema-drift-test", IPAPI_LIBRARY, IPAPI_MALFORMED_FIXTURE
    )
    refute malformed_status.success?
    assert_empty malformed_stderr
  end

  def test_anonymous_ipapi_never_supplies_risk_flags_and_rejects_mixed_contracts
    response = JSON.parse(File.read(IPAPI_ANONYMOUS_FIXTURE))
    response["is_proxy"] = false
    response["is_abuser"] = false
    probe = <<~'ZSH'
      source "$1"
      ipapi_parse_response "$2" "198.51.100.23" || exit 1
      print -r -- "${ipapi_parsed[mode]}|${ipapi_parsed[proxy]}|${ipapi_parsed[abuser]}"
    ZSH
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "anonymous-flags", IPAPI_LIBRARY, JSON.generate(response))
    assert status.success?, stderr
    assert_equal "anonymous||\n", stdout
    response["location"] = { "country_code" => "US" }
    _stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "mixed-contract", IPAPI_LIBRARY, JSON.generate(response))
    refute status.success?
    assert_empty stderr
  end

  def test_cloudflare_category_names_preserve_commas_in_json
    response = { "success" => true, "result" => [{ "ip" => "198.51.100.23", "risk_types" => [{ "name" => "Malware, command and control" }] }] }
    probe = 'source "$1"; cloudflare_parse_response "$2" "198.51.100.23" || exit 1; print -r -- "${cloudflare_parsed[threat_categories_json]}"'
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "threat-categories", CLOUDFLARE_LIBRARY, JSON.generate(response))
    assert status.success?, stderr
    assert_equal ["Malware, command and control"], JSON.parse(stdout)
    assert_empty stderr
  end

  def test_ipapi_runtime_marks_schema_drift_unavailable_without_writing_jq_errors
    function_source = reporter_functions("db_ipapi")
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      eval "$2"
      typeset -A ipapi sinfo stype sscore
      IP='198.51.100.23' CurlARG='' ibar_step=0 fixture="$3"
      sinfo[database]=0 sinfo[ldatabase]=0
      Font_Cyan='' Font_B='' Font_I='' Font_Suffix=''
      show_progress_bar(){ :; }
      curl_safe(){ cat "$fixture"; print -r -- 200; }
      db_ipapi 4
      exit_code=$?
      print -r -- "$exit_code|${ipapi[status]:-missing}|${ipapi[usetype]:-}|${ipapi[score]:-}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", probe,
      "ipapi-runtime-schema-drift-test", IPAPI_LIBRARY, function_source,
      IPAPI_MALFORMED_FIXTURE
    )
    assert status.success?, stderr
    assert_equal "1|invalid_response||\n", stdout
    assert_empty stderr
  end

  def test_ipapi_free_account_key_uses_secret_url_configuration
    function_source = reporter_functions("db_ipapi")
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      eval "$2"
      typeset -A provider_credentials ipapi sinfo stype sscore
      provider_credentials[IPAPI_API_KEY]='fixture-ipapi-key'
      source "$4"
      IP='198.51.100.23' CurlARG='' ibar_step=0 fixture="$3"
      sinfo[database]=0 sinfo[ldatabase]=0
      Font_Cyan='' Font_B='' Font_I='' Font_Suffix=''
      stype[isp]='ISP' stype[unknown]='Unknown'
      sscore[verylow]='Very Low'
      is_nonnegative_decimal(){ [[ "$1" =~ '^[0-9]+([.][0-9]+)?$' ]]; }
      show_progress_bar(){ :; }
      curl_with_secret_url(){ print -r -- "$(<"$fixture")"; print -r -- 200; }
      db_ipapi 4
      print -r -- "${ipapi[status]}|${ipapi[usetype]}|${ipapi[score]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", probe,
      "ipapi-key-runtime-test", IPAPI_LIBRARY, function_source, IPAPI_FIXTURE, COMMON_PROVIDER_LIBRARY
    )
    assert status.success?, stderr
    assert_equal "ok|isp|1.00%\n", stdout
    assert_empty stderr

    source = File.read(SCRIPT, encoding: "UTF-8")
    refute_match(/curl_safe[^\n]*\$api_key/, source)
  end

  def test_ipapi_anonymous_runtime_keeps_minimal_context_without_fake_risk
    function_source = reporter_functions("db_ipapi")
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      eval "$2"
      source "$4"
      typeset -A ipapi sinfo stype sscore
      IP='198.51.100.23' CurlARG='' ibar_step=0 fixture="$3"
      sinfo[database]=0 sinfo[ldatabase]=0
      Font_Cyan='' Font_B='' Font_I='' Font_Suffix=''
      stype[unknown]='Unknown'
      is_nonnegative_decimal(){ [[ "$1" =~ '^[0-9]+([.][0-9]+)?$' ]]; }
      show_progress_bar(){ :; }
      curl_safe(){ cat "$fixture"; print -r -- 200; }
      db_ipapi 4
      print -r -- "${ipapi[status]}|${ipapi[mode]}|${ipapi[anonymous_asn]}|${ipapi[anonymous_company]}|${ipapi[score]:-missing}|${ipapi[proxy]:-missing}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", probe,
      "ipapi-anonymous-runtime-test", IPAPI_LIBRARY, function_source, IPAPI_ANONYMOUS_FIXTURE, COMMON_PROVIDER_LIBRARY
    )
    assert status.success?, stderr
    assert_equal "ok|anonymous|AS64500 Example ISP|Example ISP|missing|missing\n", stdout
    assert_empty stderr
  end

  def test_ipapi_runtime_exposes_rate_limit_status_without_parsing_error_json
    function_source = reporter_functions("db_ipapi")
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      eval "$2"
      typeset -A ipapi sinfo
      IP='198.51.100.23' CurlARG='' ibar_step=0 fixture="$3"
      sinfo[database]=0 sinfo[ldatabase]=0
      Font_Cyan='' Font_B='' Font_I='' Font_Suffix=''
      source "$4"
      show_progress_bar(){ :; }
      curl_safe(){ cat "$fixture"; print -r -- 429; }
      db_ipapi 4
      print -r -- "$?|${ipapi[status]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", probe,
      "ipapi-rate-limit-runtime-test", IPAPI_LIBRARY, function_source, IPAPI_RATE_LIMIT_FIXTURE, COMMON_PROVIDER_LIBRARY
    )
    assert status.success?, stderr
    assert_equal "1|rate_limited\n", stdout
    assert_empty stderr
  end

  def test_ipapi_transport_failure_is_not_reported_as_quota_exhaustion
    probe = <<~'ZSH'
      eval "$1"
      typeset -A provider_credentials ipapi sinfo
      provider_credentials[IPAPI_API_KEY]=fixture-key
      IP=198.51.100.23 ibar_step=0
      sinfo[ldatabase]=0
      show_progress_bar(){ :; }
      curl_with_secret_url(){ return "$failure"; }
      for failure in 28 35 60 7;do
        db_ipapi 4
        print -r -- "$?|${ipapi[status]}|${ipapi[credential_mode]}|${ipapi[proxy]}"
      done
    ZSH
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "ipapi-transport", reporter_functions("db_ipapi"))
    assert status.success?, stderr
    assert_empty stderr
    assert_equal "1|timeout|key|\n1|tls_error|key|\n1|tls_verification_failed|key|\n1|network_error|key|\n", stdout
  end

  def test_ipwhois_parser_keeps_demo_context_without_security_and_rejects_target_mismatch
    parser_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      ipwhois_parse_response "$(<"$2")" "$3" || exit $?
      print -r -- "${ipwhois_parsed[country_code]}|${ipwhois_parsed[asn]}|${ipwhois_parsed[organization]}|${ipwhois_parsed[isp]}|${ipwhois_parsed[timezone]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", parser_probe,
      "ipwhois-parser-test", IPWHOIS_LIBRARY, IPWHOIS_FIXTURE, "198.51.100.23"
    )
    assert status.success?, stderr
    assert_equal "US|64500|Example Network|Example ISP|America/Los_Angeles\n", stdout
    assert_empty stderr

    _stdout, mismatch_stderr, mismatch_status = Open3.capture3(
      "/bin/zsh", "-f", "-c", parser_probe,
      "ipwhois-mismatch-test", IPWHOIS_LIBRARY, IPWHOIS_MISMATCH_FIXTURE, "198.51.100.23"
    )
    refute mismatch_status.success?
    assert_empty mismatch_stderr
  end

  def test_cloudflare_parser_keeps_threat_categories_and_rejects_schema_drift
    parser_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      cloudflare_parse_response "$(<"$2")" "$3" || exit $?
      print -r -- "${cloudflare_parsed[status]}|${cloudflare_parsed[country_code]}|${cloudflare_parsed[network]}|${cloudflare_parsed[organization]}|${cloudflare_parsed[infrastructure_type]}|${cloudflare_parsed[threat_categories]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", parser_probe,
      "cloudflare-parser-test", CLOUDFLARE_LIBRARY, CLOUDFLARE_FIXTURE, "198.51.100.23"
    )
    assert status.success?, stderr
    assert_equal "ok|US|AS64500|Example Network|hosting_provider|Phishing, Malware\n", stdout
    assert_empty stderr

    empty_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      cloudflare_parse_response "$(<"$2")" "$3" || exit $?
      print -r -- "${cloudflare_parsed[status]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", empty_probe,
      "cloudflare-empty-test", CLOUDFLARE_LIBRARY, CLOUDFLARE_EMPTY_FIXTURE, "198.51.100.23"
    )
    assert status.success?, stderr
    assert_equal "not_found\n", stdout
    assert_empty stderr

    _stdout, malformed_stderr, malformed_status = Open3.capture3(
      "/bin/zsh", "-f", "-c", empty_probe,
      "cloudflare-schema-drift-test", CLOUDFLARE_LIBRARY, CLOUDFLARE_INVALID_RISK_FIXTURE, "198.51.100.23"
    )
    refute malformed_status.success?
    assert_empty malformed_stderr
  end

  def test_cloudflare_numeric_asn_and_missing_threats_remain_useful_but_unknown
    fixture = JSON.parse(File.read(File.join(File.dirname(CLOUDFLARE_FIXTURE), "numeric-asn.json")))
    probe = 'source "$1"; cloudflare_parse_response "$2" "198.51.100.23" || exit 1; print -r -- "${cloudflare_parsed[network]}|${cloudflare_parsed[threat_categories_json]}"'
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "cloudflare-live-shape", CLOUDFLARE_LIBRARY, JSON.generate(fixture))
    assert status.success?, stderr
    assert_equal "AS64500|null\n", stdout
    assert_empty stderr
    fixture["result"][0]["risk_types"] = []
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "cloudflare-empty-risks", CLOUDFLARE_LIBRARY, JSON.generate(fixture))
    assert status.success?, stderr
    assert_equal "AS64500|[]\n", stdout
    [-1, 1.5, 4294967296].each do |invalid_asn|
      fixture["result"][0]["belongs_to_ref"]["value"] = invalid_asn
      _stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "cloudflare-invalid-asn", CLOUDFLARE_LIBRARY, JSON.generate(fixture))
      refute status.success?
      assert_empty stderr
    end
  end

  def test_cloudflare_runtime_requires_both_credentials_and_uses_official_response
    function_source = reporter_functions("db_cloudflare")
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      source "$2"
      eval "$3"
      typeset -A cloudflare provider_credentials sinfo
      IP='198.51.100.23' CurlARG='' ibar_step=0 fixture="$4"
      sinfo[database]=0 sinfo[ldatabase]=0
      Font_Cyan='' Font_B='' Font_I='' Font_Suffix=''
      show_progress_bar(){ :; }
      curl_with_secret_header(){
        print -r -- "$(<"$fixture")"
        print -r -- 200
      }
      provider_credentials[CLOUDFLARE_API_TOKEN]='fixture-token'
      provider_credentials[CLOUDFLARE_ACCOUNT_ID]='fixture-account'
      db_cloudflare 4
      print -r -- "${cloudflare[status]}|${cloudflare[network]}|${cloudflare[threats]}"
      provider_credentials[CLOUDFLARE_ACCOUNT_ID]=''
      db_cloudflare 4
      print -r -- "${cloudflare[status]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", probe,
      "cloudflare-runtime-test", COMMON_PROVIDER_LIBRARY, CLOUDFLARE_LIBRARY,
      function_source, CLOUDFLARE_FIXTURE
    )
    assert status.success?, stderr
    assert_equal "ok|AS64500|Phishing, Malware\ninvalid_configuration\n", stdout
    assert_empty stderr
  end

  def test_ipqs_account_quota_preflight_skips_a_lookup_that_would_spend_credit
    function_source = reporter_functions("db_ipqs")

    quota_probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      source "$2"
      eval "$3"
      typeset -A provider_credentials ipqs sinfo stype
      provider_credentials[IPQS_API_KEY]='fixture-key'
      IP='198.51.100.23' CurlARG='' ibar_step=0
      sinfo[ldatabase]=0
      quota_fixture="$4" calls_file="$5"
      Font_Cyan='' Font_B='' Font_I='' Font_Suffix=''
      show_progress_bar(){ :; }
      styled_provider_type(){ print -rn -- "$1"; }
      curl_with_secret_url(){
        case "$1" in
          */api/json/account/*)
            print -r -- account >> "$calls_file"
            print -rn -- "$(<"$quota_fixture")" ;;
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
      zero_balance = File.join(directory, "zero-balance.json")
      File.write(zero_balance, JSON.generate("success" => true, "credits" => 0, "usage" => 10))
      calls_file = File.join(directory, "calls.txt")
      [IPQUALITYSCORE_CREDITS_FIXTURE, zero_balance].each do |quota|
        File.write(calls_file, "")
        stdout, stderr, status = Open3.capture3(
          "/bin/zsh", "-f", "-c", quota_probe, "ipqs-quota-preflight-test",
          COMMON_PROVIDER_LIBRARY, IPQUALITYSCORE_LIBRARY, function_source, quota, calls_file
        )

        assert status.success?, stderr
        assert_equal "official_insufficient_credits|\n", stdout
        assert_equal "account\n", File.read(calls_file), "zero credit must prevent the paid lookup"
        assert_empty stderr
      end
    end
  end

  def test_optional_credentials_are_data_only_private_and_never_curl_arguments
    loader_probe = <<~'ZSH'
      source "$1"
      provider_load_credentials "$2" || exit $?
      print -r -- "${provider_credentials[IPREGISTRY_API_KEY]}|${provider_credentials[IPQS_API_KEY]}"
    ZSH

    Dir.mktmpdir("ipquality-credentials-test") do |directory|
      credentials = File.join(directory, "credentials")
      File.write(
        credentials,
        "# fixture keys only\nIPREGISTRY_API_KEY=registry123\nIPQS_API_KEY=ipqs12345\n"
      )
      File.chmod(0o600, credentials)
      stdout, stderr, status = Open3.capture3(
        "/bin/zsh", "-f", "-c", loader_probe,
        "credential-loader-test", CREDENTIALS_LIBRARY, credentials
      )
      assert status.success?, stderr
      assert_equal "registry123|ipqs12345\n", stdout
      assert_empty stderr

      File.chmod(0o644, credentials)
      _stdout, insecure_stderr, insecure_status = Open3.capture3(
        "/bin/zsh", "-f", "-c", loader_probe,
        "credential-loader-mode-test", CREDENTIALS_LIBRARY, credentials
      )
      refute insecure_status.success?
      assert_includes insecure_stderr, "mode 600"

      marker = File.join(directory, "must-not-exist")
      File.write(credentials, "IPQS_API_KEY=$(touch #{marker})\n")
      File.chmod(0o600, credentials)
      _stdout, _stderr, malicious_status = Open3.capture3(
        "/bin/zsh", "-f", "-c", loader_probe,
        "credential-loader-code-test", CREDENTIALS_LIBRARY, credentials
      )
      refute malicious_status.success?
      refute File.exist?(marker)
    end

    source = File.read(SCRIPT, encoding: "UTF-8")
    assert_includes source, "--config -"
    refute_match(/curl_safe[^\n]*\$api_key/, source)
  end

  def test_optional_provider_credentials_are_loaded_from_the_private_assignment_file
    loader_probe = <<~'ZSH'
      source "$1"
      provider_load_credentials "$2" || exit $?
      print -r -- "${provider_credentials[IPAPI_API_KEY]}|${provider_credentials[CLOUDFLARE_API_TOKEN]}|${provider_credentials[CLOUDFLARE_ACCOUNT_ID]}"
    ZSH
    Dir.mktmpdir("ipquality-cloudflare-credentials-test") do |directory|
      credentials = File.join(directory, "credentials")
      File.write(credentials, "IPAPI_API_KEY=ipapi_fixture_123\nCLOUDFLARE_API_TOKEN=token_fixture_123\nCLOUDFLARE_ACCOUNT_ID=account_fixture_123\n")
      File.chmod(0o600, credentials)
      stdout, stderr, status = Open3.capture3(
        "/bin/zsh", "-f", "-c", loader_probe,
        "optional-provider-credential-loader-test", CREDENTIALS_LIBRARY, credentials
      )
      assert status.success?, stderr
      assert_equal "ipapi_fixture_123|token_fixture_123|account_fixture_123\n", stdout
      assert_empty stderr
    end
  end

  def test_known_provider_failures_are_classified_without_echoing_upstream_messages
    parser_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      ipqualityscore_parse_unavailability "$(<"$2")" || exit $?
      print -r -- "${ipqualityscore_unavailable[status]}"
      source "$3"
      internetdb_parse_unavailability "$(<"$4")" || exit $?
      print -r -- "${internetdb_unavailable[status]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      parser_probe,
      "provider-unavailability-test",
      IPQUALITYSCORE_LIBRARY,
      IPQUALITYSCORE_CREDITS_FIXTURE,
      INTERNETDB_LIBRARY,
      INTERNETDB_NO_INFORMATION_FIXTURE
    )

    assert status.success?, stderr
    assert_equal "upstream_insufficient_credits\nnot_found\n", stdout
    refute_includes stdout, "You have insufficient credits"
    assert_empty stderr
  end

  def test_check_place_cloudflare_block_is_distinct_from_a_generic_http_403
    classifier_probe = <<~'ZSH'
      source "$1"
      print -r -- "$(provider_http_failure_status 403 "$(<"$2")")"
      print -r -- "$(provider_http_failure_status 403 '<html>forbidden</html>')"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", classifier_probe,
      "check-place-cloudflare-classifier-test",
      COMMON_PROVIDER_LIBRARY,
      CHECK_PLACE_CLOUDFLARE_FIXTURE
    )

    assert status.success?, stderr
    assert_equal "cloudflare_blocked\nhttp_403\n", stdout
    assert_empty stderr
  end

  def test_private_project_secret_files_load_by_provider_name_and_override_global_defaults
    loader_probe = <<~'ZSH'
      source "$1"
      provider_load_credentials "$2" "$3" || exit $?
      print -r -- "${provider_credentials[IPREGISTRY_API_KEY]}|${provider_credentials[IPQS_API_KEY]}"
    ZSH

    Dir.mktmpdir("ipquality-project-secrets-test") do |directory|
      credentials = File.join(directory, "credentials")
      project_secrets = File.join(directory, "secrets")
      Dir.mkdir(project_secrets, 0o700)
      File.write(
        credentials,
        "IPREGISTRY_API_KEY=globalregistry123\nIPQS_API_KEY=globalipqs12345\n"
      )
      File.chmod(0o600, credentials)
      File.write(File.join(project_secrets, "ipregistry"), "projectregistry123\n")
      File.write(File.join(project_secrets, "ipqs"), "projectipqs12345\n")
      File.chmod(0o600, File.join(project_secrets, "ipregistry"))
      File.chmod(0o600, File.join(project_secrets, "ipqs"))

      stdout, stderr, status = Open3.capture3(
        "/bin/zsh", "-f", "-c", loader_probe,
        "project-secret-loader-test", CREDENTIALS_LIBRARY, credentials, project_secrets
      )
      assert status.success?, stderr
      assert_equal "projectregistry123|projectipqs12345\n", stdout
      assert_empty stderr

      File.chmod(0o644, File.join(project_secrets, "ipqs"))
      _stdout, insecure_stderr, insecure_status = Open3.capture3(
        "/bin/zsh", "-f", "-c", loader_probe,
        "project-secret-mode-test", CREDENTIALS_LIBRARY, credentials, project_secrets
      )
      refute insecure_status.success?
      assert_includes insecure_stderr, "mode 600"
    end

    source = File.read(SCRIPT, encoding: "UTF-8")
    assert_includes source, 'provider_load_credentials "" "$SCRIPT_DIR/secrets"'
  end
end
