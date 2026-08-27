# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "json"
require "tmpdir"

class IpQualityTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "bin", "ip-quality")
  DNSBL = File.join(ROOT, "ref", "dnsbl.list")
  ISO3166 = File.join(ROOT, "ref", "iso3166.json")
  COMMON_PROVIDER_LIBRARY = File.join(ROOT, "providers", "common.zsh")
  CREDENTIALS_LIBRARY = File.join(ROOT, "providers", "credentials.zsh")
  IPREGISTRY_LIBRARY = File.join(ROOT, "providers", "ipregistry.zsh")
  IPQUALITYSCORE_LIBRARY = File.join(ROOT, "providers", "ipqualityscore.zsh")
  PING0_LIBRARY = File.join(ROOT, "providers", "ping0.zsh")
  RIPESTAT_LIBRARY = File.join(ROOT, "providers", "ripestat.zsh")
  INTERNETDB_LIBRARY = File.join(ROOT, "providers", "shodan_internetdb.zsh")
  REPUTATION_REPORT = File.join(ROOT, "report", "reputation.zsh")
  REPORT_OUTPUT = File.join(ROOT, "report", "output.zsh")
  PING0_GEO_FIXTURE = File.join(ROOT, "test", "fixtures", "ping0", "public-geo.txt")
  PING0_CHALLENGE_FIXTURE = File.join(ROOT, "test", "fixtures", "ping0", "challenge.html")
  RIPESTAT_FIXTURE = File.join(ROOT, "test", "fixtures", "ripestat", "network-info.json")
  INTERNETDB_FIXTURE = File.join(ROOT, "test", "fixtures", "shodan", "internetdb.json")
  INTERNETDB_NO_INFORMATION_FIXTURE = File.join(ROOT, "test", "fixtures", "shodan", "no-information.json")
  IPQUALITYSCORE_CREDITS_FIXTURE = File.join(ROOT, "test", "fixtures", "ipqualityscore", "insufficient-credits.json")
  IPQUALITYSCORE_USAGE_FIXTURE = File.join(ROOT, "test", "fixtures", "ipqualityscore", "usage.json")
  IPREGISTRY_FIXTURE = File.join(ROOT, "test", "fixtures", "ipregistry", "ip-intelligence.json")
  IPQUALITYSCORE_OFFICIAL_FIXTURE = File.join(ROOT, "test", "fixtures", "ipqualityscore", "official.json")
  CHECK_PLACE_CLOUDFLARE_FIXTURE = File.join(ROOT, "test", "fixtures", "check_place", "cloudflare-blocked.html")

  BANNED_SOURCE_PATTERNS = {
    bash_runtime: /(^|[^A-Za-z0-9_])bash([^A-Za-z0-9_]|$)/i,
    bash_match_array: /BASH_REMATCH/,
    bash_shell_option: /\bshopt\b/,
    bash_mapfile: /\bmapfile\b/,
    dynamic_eval: /\beval\s/,
    remote_shell_pipe: /curl[^\n]*(?:\|\s*(?:sh|zsh)|<\((?:sh|zsh))/i,
    telemetry: /hits\.xykt\.de/i,
    report_upload: /upload\.check\.place/i,
    remote_reference: /(?:raw\.githubusercontent\.com|cdn\.jsdelivr\.net|rawgithub)/i,
    package_installer: /(?:brew\s+install|apt-get\s+install|dnf\s+install|yum\s+install|pacman\s+-S|apk\s+add|xbps-install)/i,
    background_disown: /\bdisown\b/,
    return_trap: /trap[^\n]*RETURN/,
    cookie_bundle: /ref\/cookies\.txt/,
    bundled_cookie_header: /curl_safe[^\n]+(?:\s-b\s|Cookie:)/i,
    embedded_authorization_header: /authorization:/i,
    dynamic_api_key_scrape: /apiKey=/
  }.freeze

  def test_default_is_a_no_network_disclosure_plan
    stdout, stderr, status = run_script

    assert status.success?, stderr
    assert_includes stdout, "no network access has occurred"
    assert_includes stdout, "scope: full"
    assert_includes stdout, "telemetry/report upload/remote code: disabled"
    assert_includes stdout, "--confirm-network-lookup"
    assert_empty stderr
  end

  def test_each_scope_has_a_bounded_plan
    {
      "reputation" => "reputation sources:",
      "dnsbl" => "DNSBL sources:",
      "media-ai" => "media/AI sources:",
      "mail" => "mail sources:"
    }.each do |scope, marker|
      stdout, stderr, status = run_script("--scope", scope)

      assert status.success?, "scope=#{scope}: #{stderr}"
      assert_includes stdout, "scope: #{scope}"
      assert_includes stdout, marker
      assert_empty stderr
    end

    stdout, stderr, status = run_script("--scope", "mail-dnsbl")
    assert status.success?, stderr
    assert_includes stdout, "scope: mail-dnsbl"
    assert_includes stdout, "mail sources:"
    assert_includes stdout, "DNSBL sources:"
    assert_empty stderr
  end

  def test_explicit_plan_still_prevents_network_after_confirmation
    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--plan",
      "--scope",
      "full"
    )

    assert status.success?, stderr
    assert_includes stdout, "no network access has occurred"
    assert_empty stderr
  end

  def test_offline_self_test_covers_zsh_validators_and_dnsbl_aggregation
    stdout, stderr, status = run_script("--self-test")

    assert status.success?, stderr
    assert_match(/SELF-TEST OK: zsh runtime, validators, provider parsers, and \d+ DNSBL entries/, stdout)
    assert_empty stderr
  end

  def test_json_stdout_preserves_escaped_control_characters
    output_probe = <<~'ZSH'
      source "$1"
      value=$'tab\tline\nterminal\033[31mred\033[0m'
      payload=$(jq -n --arg value "$value" '{value: $value}') || exit $?
      report_emit_stdout "$payload"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      output_probe,
      "report-output-test",
      REPORT_OUTPUT
    )

    assert status.success?, stderr
    assert_equal "tab\tline\nterminal\e[31mred\e[0m", JSON.parse(stdout).fetch("value")
    assert_empty stderr
    assert_includes File.read(SCRIPT), 'report_emit_stdout "$ipjson"'
    refute_match(/echo -ne "\\r\$ipjson/, File.read(SCRIPT))
    assert_includes File.read(SCRIPT), "Font_Green=$'\\033[32m'"
    assert_includes File.read(SCRIPT), "Font_Red=$'\\033[31m'"
    refute_match(/Font_(?:Green|Red)="\\033/, File.read(SCRIPT))
  end

  def test_terminal_stdout_keeps_real_green_and_red_ansi_bytes
    output_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      Font_B=$'\033[1m' Font_Red=$'\033[31m' Font_Green=$'\033[32m'
      Font_Purple=$'\033[35m' Font_Cyan=$'\033[36m' Font_Suffix=$'\033[0m'
      YY=cn
      typeset -A sfactor ipinfo ipapi ip2location abuseipdb scamalytics ipqs ipdata
      sfactor[title]='四、风险因子'
      ipapi[proxy]=false
      ipapi[vpn]=true
      clean_ansi(){ print -rn -- "$1" }
      source "$1"
      source "$2"
      report=$(show_factor)
      report_emit_stdout "$report"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      output_probe,
      "report-color-output-test",
      REPUTATION_REPORT,
      REPORT_OUTPUT
    )

    assert status.success?, stderr
    assert_includes stdout, "\e[32m\e[1m否"
    assert_includes stdout, "\e[31m\e[1m是"
    refute_includes stdout, "\\033["
    assert_empty stderr
  end

  def test_reputation_plan_discloses_ping0_public_result_and_risk_limitation
    stdout, stderr, status = run_script("--scope", "reputation")

    assert status.success?, stderr
    assert_includes stdout, "official-contract sources"
    assert_includes stdout, "configured Ipregistry/IPQS APIs"
    assert_includes stdout, "supplementary sources"
    assert_includes stdout, "Ping0"
    assert_includes stdout, "official free /geo endpoint"
    assert_includes stdout, "not a risk score"
    assert_empty stderr
  end

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

  def test_ipqs_account_quota_preflight_skips_a_lookup_that_would_spend_credit
    function_match = File.read(SCRIPT, encoding: "UTF-8").match(
      /^db_ipqs\(\)\{\n.*?^\}\n(?=db_ping0\(\)\{)/m
    )
    refute_nil function_match

    quota_probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      source "$2"
      eval "$3"
      typeset -A provider_credentials ipqs sinfo stype
      provider_credentials[IPQS_API_KEY]='fixture-key'
      IP='198.51.100.23' CurlARG='' ibar_step=0
      sinfo[ldatabase]=0
      quota_fixture="$4" success_fixture="$5"
      Font_Cyan='' Font_B='' Font_I='' Font_Suffix=''
      show_progress_bar(){ :; }
      styled_provider_type(){ print -rn -- "$1"; }
      curl_with_secret_url(){
        case "$1" in
          */api/json/account/*) print -rn -- "$(<"$quota_fixture")" ;;
          */api/json/ip/*) print -rn -- "$(<"$success_fixture")" ;;
          *) return 9 ;;
        esac
      }
      db_ipqs 4 || exit $?
      print -r -- "${ipqs[status]}|${ipqs[score]}"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", quota_probe,
      "ipqs-quota-preflight-test",
      COMMON_PROVIDER_LIBRARY,
      IPQUALITYSCORE_LIBRARY,
      function_match[0],
      IPQUALITYSCORE_CREDITS_FIXTURE,
      IPQUALITYSCORE_OFFICIAL_FIXTURE
    )

    assert status.success?, stderr
    assert_equal "official_insufficient_credits|\n", stdout
    assert_empty stderr
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

  def test_reputation_report_uses_provider_rows_without_the_fragile_score_bar
    report_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      Font_Cyan='' Font_Suffix='' Font_B='' Font_Green='' Font_Red='' Font_Purple=''
      YY=cn
      typeset -A stype sscore sfactor sping0
      typeset -A ipinfo ipregistry ipapi ip2location abuseipdb scamalytics ipqs ipdata ping0 ripestat internetdb
      stype[title]='二、IP类型属性'
      sscore[title]='三、风险评分'
      sfactor[title]='四、风险因子'
      ipinfo[susetype]='家宽'
      ip2location[score]=21
      ipapi[risk]='High'
      ipapi[proxy]=false
      ipqs[vpn]=true
      clean_ansi(){ print -rn -- "$1" }
      source "$1"
      show_type
      show_score
      show_factor
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      report_probe,
      "report-test",
      REPUTATION_REPORT
    )
    assert status.success?, stderr
    assert_includes stdout, "IP2Location"
    assert_match(/参数\s+\|.*IP2Location.*ipapi\.is/, stdout)
    assert_includes stdout, "公开示例组件"
    assert_match(/分值\s+\|\s+21/, stdout)
    assert_includes stdout, "分段/标签"
    assert_includes stdout, "量表"
    assert_includes stdout, "0-99 potential"
    assert_includes stdout, "IPQS"
    assert_match(/分段\/标签\s+\|\s+-/, stdout)
    refute_includes stdout, "Scamalytics"
    refute_includes stdout, "未知"
    refute_includes stdout, "风险等级："
    refute_match(/IP2Location\s+分值=/, stdout)
    assert_operator stdout.lines.map { |line| line.chomp.length }.max, :<=, 80
    refute_includes stderr, "unrecognized modifier"
  end

  def test_reputation_tables_stay_single_block_and_align_after_ansi_highlighting
    report_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      Font_B=$'\033[1m' Font_Red=$'\033[31m' Font_Green=$'\033[32m'
      Font_Yellow=$'\033[33m' Font_Purple=$'\033[35m' Font_Cyan=$'\033[36m'
      Font_White=$'\033[37m' Back_Red=$'\033[41m' Back_Green=$'\033[42m'
      Back_Yellow=$'\033[43m' Back_Purple=$'\033[45m' Font_Suffix=$'\033[0m'
      YY=cn
      typeset -A stype sscore sfactor
      typeset -A ipinfo ipregistry ipapi ip2location abuseipdb scamalytics ipqs ipdata
      stype[title]='二、IP类型属性' sscore[title]='三、风险评分' sfactor[title]='四、风险因子'
      stype[isp]="   $Back_Green$Font_White$Font_B 家宽 $Font_Suffix   "
      stype[mobile]="   $Back_Green$Font_White$Font_B 手机 $Font_Suffix   "
      stype[hosting]="   $Back_Red$Font_White$Font_B 机房 $Font_Suffix   "
      sscore[low]="$Font_Green${Font_B}低风险$Font_Suffix"
      sscore[verylow]="$Font_Green${Font_B}极低风险$Font_Suffix"
      sscore[medium]="$Font_Yellow${Font_B}中风险$Font_Suffix"
      sscore[high]="$Font_Red${Font_B}高风险$Font_Suffix"
      ipinfo[susetype]="${stype[isp]}" ipinfo[scomtype]="${stype[isp]}"
      ipregistry[susetype]="${stype[hosting]}" ipregistry[scomtype]="${stype[hosting]}"
      ipqs[susetype]="${stype[hosting]}" ipqs[source]=official_api
      ipapi[susetype]="${stype[isp]}" ipapi[scomtype]="${stype[isp]}"
      ip2location[susetype]="${stype[mobile]}" ip2location[scomtype]="${stype[mobile]}"
      abuseipdb[susetype]="${stype[isp]}"
      ip2location[score]=3 scamalytics[score]=3 ipapi[score]='0.00%' abuseipdb[score]=0
      ipapi[risk]="${sscore[verylow]}"
      ipqs[score]=87 ipqs[risk]="${sscore[high]}"
      ip2location[countrycode]=CN ipapi[countrycode]=CN ipregistry[countrycode]=CN
      ipqs[countrycode]=CN scamalytics[countrycode]=CN
      ipdata[countrycode]=CN ipinfo[countrycode]=CN
      ip2location[proxy]=false ipapi[proxy]=false ipregistry[proxy]=false
      ipqs[proxy]=true scamalytics[proxy]=false
      ipdata[proxy]=false ipinfo[proxy]=false
      ip2location[vpn]=false ipapi[vpn]=false ipregistry[vpn]=false
      ipqs[vpn]=true scamalytics[vpn]=false ipinfo[vpn]=false
      clean_ansi(){ print -rn -- "$1" | sed $'s/\033\\[[0-9;]*m//g' }
      source "$1"
      show_type
      show_score
      show_factor
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", report_probe,
      "report-alignment-test", REPUTATION_REPORT
    )

    assert status.success?, stderr
    assert_includes stdout, "\e[32m"
    assert_includes stdout, "\e[31m"
    plain = stdout.gsub(/\e\[[0-9;]*m/, "")
    assert_match(/^分段\/标签 {2}\|/, plain)
    assert_match(/参数\s+\|.*Ipregistry.*IPQS.*ipapi\.is/, plain)
    refute_includes plain, "分段／标签"
    refute_includes plain, "—"
    assert_match(/^分值 {7}\| 3 {16}\| 3 {16}\| 0\.00% {12}\| 0 {16}\| 87 {14}$/, plain)
    sections = [
      plain[/二、IP类型属性\n(.*?)三、风险评分\n/m, 1],
      plain[/三、风险评分\n(.*?)四、风险因子\n/m, 1],
      plain[/四、风险因子\n(.*)\z/m, 1]
    ]
    sections.each do |section|
      refute_nil section
      table_lines = section.lines.map(&:chomp).select { |line| line.include?("|") }
      refute_empty table_lines
      assert_equal 1, table_lines.map { |line| line.count("|") }.uniq.length, table_lines.join("\n")
      separators = table_lines.map do |line|
        positions = []
        display_column = 0
        line.each_char do |character|
          positions << display_column if character == "|"
          display_column += character.ascii_only? ? 1 : 2
        end
        positions
      end
      assert_equal 1, separators.uniq.length, table_lines.join("\n")
    end
    assert_equal 1, sections[0].lines.count { |line| line.start_with?("参数") }
    assert_equal 1, sections[1].lines.count { |line| line.start_with?("参数") }
    assert_equal 1, sections[2].lines.count { |line| line.start_with?("参数") }
    assert_match(/参数\s+\|.*Ipregistry.*IPQS.*Scamalytics/, sections[2])
    assert_operator plain.lines.map { |line| line.chomp.length }.max, :<=, 130
    assert_empty stderr
  end

  def test_ping0_routing_and_shodan_share_one_compact_observation_section
    context_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      Font_B='' Font_Red='' Font_Green='' Font_Purple='' Font_Cyan='' Font_Suffix=''
      YY=cn fullIP=1
      typeset -A ping0 ripestat internetdb sping0
      ping0[status]=verified ping0[match]=true ping0[location]='东京'
      ping0[asn]=AS64500 ping0[org]='Example Network'
      ripestat[status]=announced ripestat[prefix]='198.51.100.0/24' ripestat[origins]=AS64500
      internetdb[status]=ok internetdb[ports]='22, 443' internetdb[port_count]=2
      internetdb[hostname_count]=1
      internetdb[vulnerability_count]=1 internetdb[tags]='vpn'
      clean_ansi(){ print -rn -- "$1" }
      source "$1"
      show_network_context
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", context_probe,
      "network-context-report-test", REPUTATION_REPORT
    )

    assert status.success?, stderr
    assert_equal 4, stdout.lines.length
    assert_equal 1, stdout.scan("五、官方网络观测").length
    assert_includes stdout, "Ping0：已核对"
    assert_includes stdout, "RIPEstat：状态=announced"
    assert_includes stdout, "Shodan：端口=22, 443"
    assert_includes stdout, "主机名数量=1"
    refute_includes stdout, "Ping0 官方公开观测"
    refute_includes stdout, "官方路由观测（RIPEstat"
    assert_empty stderr
  end

  def test_unavailable_sources_stay_compact_while_ipqs_keeps_a_visible_status_column
    report_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      Font_Cyan='' Font_Suffix='' Font_B='' Font_Green='' Font_Red='' Font_Purple=''
      YY=cn
      typeset -A maxmind ipinfo ipregistry ipapi ip2location abuseipdb scamalytics ipdata ipqs ping0 ripestat internetdb sping0 sscore
      sscore[title]='三、风险评分'
      ipregistry[status]=not_configured
      ping0[status]=unknown
      ipqs[status]=upstream_insufficient_credits
      ipqs[source]=check_place_relay
      maxmind[status]=cloudflare_blocked ip2location[status]=cloudflare_blocked
      abuseipdb[status]=cloudflare_blocked scamalytics[status]=cloudflare_blocked ipdata[status]=cloudflare_blocked
      internetdb[status]=not_found
      clean_ansi(){ print -rn -- "$1" }
      source "$1"
      show_score
      show_network_context
      show_unavailable_sources
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      report_probe,
      "report-unavailable-test",
      REPUTATION_REPORT
    )

    assert status.success?, stderr
    assert_includes stdout, "IPQS"
    assert_includes stdout, "来源/状态"
    assert_includes stdout, "中继/额度用完"
    assert_includes stdout, "五、官方网络观测"
    assert_includes stdout, "Shodan：无公开记录（不等于无风险）"
    summary = stdout.lines.last
    assert_includes summary, "本次无可用资料（不等于低风险）"
    assert_includes summary, "RIPEstat"
    assert_includes summary, "Check.Place 被 Cloudflare 阻挡（MaxMind、IP2Location、AbuseIPDB、Scamalytics、ipdata）"
    refute_includes summary, "Check.Place/MaxMind、IP2Location"
    refute_includes summary, "IPQualityScore"
    refute_includes summary, "Shodan"
    refute_includes summary, "Ipregistry"
    refute_includes stdout, "状态：unknown"
    refute_includes stdout, "风险分数："
    assert_empty stderr
  end

  def test_ipqs_failure_status_does_not_suppress_successful_provider_results
    report_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      Font_Cyan='' Font_Suffix='' Font_B='' Font_Green='' Font_Red='' Font_Purple=''
      YY=cn
      typeset -A sscore sfactor
      typeset -A ipinfo ipregistry ipapi ip2location abuseipdb scamalytics ipqs ipdata
      sscore[title]='三、风险评分' sfactor[title]='四、风险因子'
      ip2location[score]=3 ip2location[countrycode]=US ip2location[proxy]=false
      scamalytics[score]=4 scamalytics[countrycode]=US scamalytics[vpn]=false
      abuseipdb[score]=2
      ipdata[countrycode]=US ipdata[server]=false
      ipqs[source]=official_api ipqs[status]=official_insufficient_credits
      clean_ansi(){ print -rn -- "$1" }
      source "$1"
      show_score
      show_factor
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", report_probe,
      "ipqs-independent-report-test", REPUTATION_REPORT
    )

    assert status.success?, stderr
    assert_match(/参数\s+\|.*IP2Location.*Scamalytics.*AbuseIPDB.*IPQS/, stdout)
    assert_includes stdout, "官方/额度用完"
    assert_match(/参数\s+\|.*IP2Location.*Scamalytics.*ipdata/, stdout)
    assert_includes stdout, "分值"
    assert_includes stdout, "地区"
    assert_empty stderr
  end

  def test_reputation_factor_colors_distinguish_safe_risk_and_unknown_values
    color_probe = <<~'ZSH'
      Font_B=$'\033[1m' Font_Red=$'\033[31m' Font_Green=$'\033[32m'
      Font_Purple=$'\033[35m' Font_Cyan=$'\033[36m' Font_Suffix=$'\033[0m'
      YY=cn
      clean_ansi(){ print -rn -- "$1" }
      source "$1"
      report_factor_value false
      print -rn -- '|'
      report_factor_value true
      print -rn -- '|'
      report_factor_value ''
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      color_probe,
      "report-color-test",
      REPUTATION_REPORT
    )

    assert status.success?, stderr
    assert_includes stdout, "\e[32m\e[1m否"
    assert_includes stdout, "\e[31m\e[1m是"
    assert_includes stdout, "\e[35m未知"
    assert_empty stderr
  end

  def test_report_identifies_the_relay_and_online_repository_without_claiming_a_local_maxmind_database
    source = File.read(SCRIPT, encoding: "UTF-8")

    assert_includes source, "https://github.com/kratoszmx/ip-quality"
    assert_includes source, "Check.Place 中继；上游标注 MaxMind"
    assert_includes source, "Check.Place relay; MaxMind-labeled upstream data"
    assert_includes source, "IPinfo public demo widget"
    assert_includes source, 'info_source="IPinfo public demo widget"'
    assert_includes source, '--arg info_source "$info_source"'
    refute_includes source, '--arg info_source "Check.Place upstream relay; MaxMind-labeled response"'
    refute_includes source, "/Users/zmx/gitrepos/ipquality.git"
    refute_includes source, "/Users/zmx/gitrepos/network-manager.git"
    refute_includes source, "Maxmind 数据库"
  end

  def test_concurrency_is_hard_bounded
    %w[0 51 nope].each do |value|
      _stdout, stderr, status = run_script("--scope", "dnsbl", "--dnsbl-concurrency", value)

      assert_equal 64, status.exitstatus, "value=#{value}"
      assert_includes stderr, "must be an integer from 1 through 50"
    end

    stdout, stderr, status = run_script("--scope", "dnsbl", "--dnsbl-concurrency", "50")
    assert status.success?, stderr
    assert_includes stdout, "DNSBL concurrency cap: 50"
  end

  def test_dnsbl_live_path_keeps_every_zone_result_with_a_fixture_dig
    Dir.mktmpdir("ipquality-dnsbl-dig-test") do |directory|
      fake_dig = File.join(directory, "dig")
      File.write(fake_dig, <<~'ZSH')
        #!/bin/zsh -f
        case "$*" in
          *dnsbl-3.uceprotect.net*) print -r -- 127.0.0.2 ;;
          *bl.spamcop.net*) print -r -- 127.0.0.3 ;;
          *.b.barracudacentral.org*) exit 9 ;;
          *) exit 0 ;;
        esac
      ZSH
      File.chmod(0o700, fake_dig)
      stdout, stderr, status = Open3.capture3(
        { "PATH" => "#{directory}:#{ENV.fetch("PATH")}" },
        "/bin/zsh", "-f", SCRIPT,
        "--confirm-network-lookup", "--scope", "dnsbl",
        "--dnsbl-concurrency", "7", "-4", "-j", "12.217.32.68"
      )

      assert status.success?, stderr
      dnsbl = JSON.parse(stdout).dig("Mail", "DNSBlacklist")
      assert_equal 422, dnsbl.fetch("Total")
      assert_equal 419, dnsbl.fetch("Clean")
      assert_equal 1, dnsbl.fetch("Marked")
      assert_equal 1, dnsbl.fetch("Blacklisted")
      assert_equal 1, dnsbl.fetch("Unknown")
      assert_equal 422, dnsbl.fetch("Results").length
      assert_equal "Blacklisted", dnsbl.dig("Results", "dnsbl-3.uceprotect.net")
      assert_equal "Marked", dnsbl.dig("Results", "bl.spamcop.net")
      assert_equal "Unknown", dnsbl.dig("Results", "b.barracudacentral.org")
      assert_includes stderr, "正在检测黑名单数据库"
    end
  end

  def test_smtp_probe_uses_the_system_route_without_binding_the_public_nat_address
    function_match = File.read(SCRIPT, encoding: "UTF-8").match(
      /^smtp_probe\(\)\{\n.*?^\}\n(?=check_email_service\(\)\{)/m
    )
    refute_nil function_match

    Dir.mktmpdir("ipquality-smtp-route-test") do |directory|
      fake_nc = File.join(directory, "nc")
      arguments_file = File.join(directory, "arguments.txt")
      File.write(fake_nc, <<~'ZSH')
        #!/bin/zsh -f
        print -r -- "$@" > "$IPQUALITY_NC_ARGUMENTS_FILE"
        print -r -- "220 fixture SMTP"
      ZSH
      File.chmod(0o700, fake_nc)

      stdout, stderr, status = Open3.capture3(
        {
          "PATH" => "#{directory}:#{ENV.fetch("PATH")}",
          "IPQUALITY_NC_ARGUMENTS_FILE" => arguments_file
        },
        "/bin/zsh", "-f", "-c",
        'eval "$1"; IP=198.51.100.23; smtp_probe smtp.example 25 2',
        "smtp-system-route-test", function_match[0]
      )

      assert status.success?, stderr
      assert_equal "-w 2 smtp.example 25\n", File.read(arguments_file)
      assert_equal "220 fixture SMTP\n", stdout
      refute_includes File.read(arguments_file), "198.51.100.23"
      assert_empty stderr
    end
  end

  def test_dnsbl_report_explains_aggregate_uceprotect_levels
    function_match = File.read(SCRIPT, encoding: "UTF-8").match(
      /^show_dnsbl\(\)\{\n.*?^\}\n(?=show_tail\(\)\{)/m
    )
    refute_nil function_match

    report_probe = <<~'ZSH'
      typeset -A smail
      YY=cn Font_Red='' Font_Yellow='' Font_Cyan='' Font_Suffix=''
      smail[sdnsbl]='IP地址黑名单数据库：有效 422'
      smail[blacklisted_zones]='dnsbl-2.uceprotect.net, dnsbl-3.uceprotect.net'
      smail[marked_zones]=''
      eval "$1"
      show_dnsbl
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", report_probe,
      "dnsbl-aggregate-context-test", function_match[0]
    )

    assert status.success?, stderr
    assert_includes stdout, "dnsbl-2.uceprotect.net, dnsbl-3.uceprotect.net"
    assert_includes stdout, "网段／ASN 级记录"
    assert_includes stdout, "不等于这个单独 IP 曾发送垃圾邮件"
    assert_empty stderr
  end

  def test_only_implemented_report_languages_are_advertised_and_accepted
    source = File.read(SCRIPT, encoding: "UTF-8")
    assert_includes source, "-l cn|en"
    refute_match(/cn\|en\|jp|\"jp\"\|\"es\"/, source)

    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "reputation",
      "-l",
      "jp"
    )
    assert_equal 1, status.exitstatus
    assert_includes stdout, "不支持的参数"
    assert_empty stderr
  end

  def test_removed_upstream_mutation_and_remote_execution_flags_are_rejected
    %w[-xhttp://127.0.0.1:1 -y -M].each do |flag|
      _stdout, stderr, status = run_script(flag)

      assert_equal 64, status.exitstatus, "flag=#{flag}"
      assert_includes stderr, "disabled"
    end
  end

  def test_live_gate_rejects_incompatible_family_and_unsafe_interface_before_lookup
    %w[dnsbl mail-dnsbl].each do |scope|
      stdout, stderr, status = run_script(
        "--confirm-network-lookup",
        "--scope",
        scope,
        "-6"
      )
      assert_equal 61, status.exitstatus
      assert_includes stdout, "DNSBL"
      assert_empty stderr
    end

    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "reputation",
      "-i",
      "en0 --proxy http://example.invalid"
    )
    assert_equal 7, status.exitstatus
    assert_includes stdout, "指定的网卡"
    assert_empty stderr
  end

  def test_explicit_public_target_is_parsed_before_network_and_restricted_to_honest_scopes
    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "full",
      "12.217.32.68"
    )
    assert_equal 62, status.exitstatus
    assert_includes stdout, "指定公网IP仅支持信誉或DNSBL范围"
    assert_empty stderr

    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "reputation",
      "-6",
      "12.217.32.68"
    )
    assert_equal 63, status.exitstatus
    assert_includes stdout, "IPv4/IPv6类型冲突"
    assert_empty stderr

    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "reputation",
      "192.168.1.10"
    )
    assert_equal 2, status.exitstatus
    assert_includes stdout, "IP地址格式错误"
    assert_empty stderr
  end

  def test_source_is_zsh_native_and_contains_no_removed_runtime_paths
    source = File.binread(SCRIPT)

    assert source.start_with?("#!/bin/zsh\n")
    assert_includes source, "--confirm-network-lookup"
    assert_includes source, "typeset -A"
    assert_includes source, "/bin/zsh -fc"
    assert_includes source, 'command curl -q "$@"'
    assert_includes source, '--arg score_ipqs "${ipqs[score]:-}"'
    assert_includes source, '--arg type_ipregistry_usage'
    assert_includes source, '--arg type_ipqs_usage'
    assert_includes source, '--arg exposure_hostname_count'
    refute_includes source, '--arg band_dbip'
    assert_includes source, '--arg info_org "$info_org"'
    refute_includes source, "shead[command]"
    refute_includes source, "factor_updates"
    refute_match(/jq\s+"\$head_updates/, source)
    BANNED_SOURCE_PATTERNS.each do |name, pattern|
      refute_match pattern, source, "#{name} unexpectedly remains"
    end
  end

  def test_report_output_uses_exclusive_nofollow_descriptor_instead_of_check_then_append
    source = File.read(SCRIPT, encoding: "UTF-8")

    assert_includes source, "zmodload zsh/system"
    assert_includes source, "sysopen -w -m 600 -o creat,excl,nofollow,cloexec,sync"
    assert_includes source, 'print -r -u "$output_fd" -- "$payload"'
    refute_match(/>>\s*"?\$outputfile/, source)
    assert_includes source, '[[ -e $outputfile || -L $outputfile ]]'
  end

  def test_vendored_references_are_regular_local_data_without_cookie_state
    [
      DNSBL,
      ISO3166,
      COMMON_PROVIDER_LIBRARY,
      CREDENTIALS_LIBRARY,
      IPREGISTRY_LIBRARY,
      IPQUALITYSCORE_LIBRARY,
      PING0_LIBRARY,
      RIPESTAT_LIBRARY,
      INTERNETDB_LIBRARY,
      REPUTATION_REPORT,
      REPORT_OUTPUT,
      PING0_GEO_FIXTURE,
      PING0_CHALLENGE_FIXTURE,
      RIPESTAT_FIXTURE,
      INTERNETDB_FIXTURE,
      IPREGISTRY_FIXTURE,
      IPQUALITYSCORE_OFFICIAL_FIXTURE,
      IPQUALITYSCORE_USAGE_FIXTURE,
      CHECK_PLACE_CLOUDFLARE_FIXTURE
    ].each do |path|
      assert File.file?(path), "missing reference: #{path}"
      refute File.symlink?(path), "symlinked reference: #{path}"
      refute_includes File.binread(path), "\0", "binary reference: #{path}"
    end

    refute File.exist?(File.join(ROOT, "ref", "cookies.txt"))
    refute File.exist?(File.join(ROOT, "ref", "iata-icao.csv"))
    zones = File.readlines(DNSBL, chomp: true)
    assert_operator zones.length, :>=, 100
    assert_equal zones.uniq, zones
    assert zones.all? { |zone| zone.match?(/\A[A-Za-z0-9._-]+\z/) }
    countries = JSON.parse(File.read(ISO3166))
    assert_operator countries.length, :>=, 200
    assert countries.all? { |country| country.key?("alpha-2") && country.key?("name") }
  end

  def test_provenance_license_and_provider_disclosure_are_present
    upstream = File.read(File.join(ROOT, "UPSTREAM.md"))
    providers = File.read(File.join(ROOT, "PROVIDERS.md"))
    license = File.read(File.join(ROOT, "LICENSE"))

    assert_includes upstream, "b59787d9832ab163cdf93c10759000ed4ba76cb0"
    assert_includes upstream, "760c1d7c44da4c904662ab37591c409ac58371fa2439a77e091f2c23c83251c8"
    assert_includes upstream, "cookies.txt"
    assert_includes providers, "Upstream relay"
    assert_includes providers, "Unknown"
    assert_includes providers, "Ping0"
    assert_includes providers, "public `/geo`"
    assert_includes providers, "invent a band from local thresholds"
    ["IpScore", "IPLeak", "Whoer", "Wave Broadband", "GreyNoise", "VirusTotal"].each do |candidate|
      assert_includes providers, candidate
    end
    assert_includes license, "GNU AFFERO GENERAL PUBLIC LICENSE"
  end

  def test_directory_has_no_nested_git_metadata_or_opaque_binary
    root_git_directory = File.join(ROOT, ".git")
    nested_git_directories = Dir.glob(File.join(ROOT, "**", ".git"))
                                .reject { |path| path == root_git_directory }
    assert_empty nested_git_directories
    refute File.exist?(File.join(ROOT, "README.md"))

    Dir.glob(File.join(ROOT, "**", "*"), File::FNM_DOTMATCH).each do |path|
      next if path == root_git_directory || path.start_with?(root_git_directory + File::SEPARATOR)
      next unless File.file?(path)

      refute_includes File.binread(path), "\0", "NUL byte in #{path}"
    end
  end

  def test_obsolete_local_remote_wrapper_is_absent
    refute File.exist?(File.join(ROOT, "scripts", "git-receive-pack-usb-clean"))
  end

  private

  def run_script(*arguments)
    Open3.capture3("/bin/zsh", "-f", SCRIPT, *arguments)
  end
end
