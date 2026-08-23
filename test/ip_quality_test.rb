# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "json"

class IpQualityTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "bin", "ip-quality")
  DNSBL = File.join(ROOT, "ref", "dnsbl.list")
  ISO3166 = File.join(ROOT, "ref", "iso3166.json")
  COMMON_PROVIDER_LIBRARY = File.join(ROOT, "providers", "common.zsh")
  IPQUALITYSCORE_LIBRARY = File.join(ROOT, "providers", "ipqualityscore.zsh")
  PING0_LIBRARY = File.join(ROOT, "providers", "ping0.zsh")
  RIPESTAT_LIBRARY = File.join(ROOT, "providers", "ripestat.zsh")
  INTERNETDB_LIBRARY = File.join(ROOT, "providers", "shodan_internetdb.zsh")
  REPUTATION_REPORT = File.join(ROOT, "report", "reputation.zsh")
  PING0_GEO_FIXTURE = File.join(ROOT, "test", "fixtures", "ping0", "public-geo.txt")
  PING0_CHALLENGE_FIXTURE = File.join(ROOT, "test", "fixtures", "ping0", "challenge.html")
  RIPESTAT_FIXTURE = File.join(ROOT, "test", "fixtures", "ripestat", "network-info.json")
  INTERNETDB_FIXTURE = File.join(ROOT, "test", "fixtures", "shodan", "internetdb.json")
  INTERNETDB_NO_INFORMATION_FIXTURE = File.join(ROOT, "test", "fixtures", "shodan", "no-information.json")
  IPQUALITYSCORE_CREDITS_FIXTURE = File.join(ROOT, "test", "fixtures", "ipqualityscore", "insufficient-credits.json")

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

  def test_reputation_plan_discloses_ping0_public_result_and_risk_limitation
    stdout, stderr, status = run_script("--scope", "reputation")

    assert status.success?, stderr
    assert_includes stdout, "Ping0 public geo"
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
      print -r -- "${internetdb_parsed[ports]}|${internetdb_parsed[vulnerability_count]}"
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
    assert_equal "198.51.100.0/24|AS64500\n22, 443|1\n", stdout
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

  def test_reputation_report_uses_provider_rows_without_the_fragile_score_bar
    report_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      Font_Cyan='' Font_Suffix='' Font_B='' Font_Green='' Font_Red='' Font_Purple=''
      YY=cn
      typeset -A stype sscore sfactor sping0
      typeset -A ipinfo ipapi ip2location abuseipdb scamalytics ipqs ipdata ping0 ripestat internetdb
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
    assert_includes stdout, "分段／标签"
    assert_includes stdout, "量表"
    assert_includes stdout, "0-99 potential"
    assert_includes stdout, "IPQS"
    assert_includes stdout, "—"
    refute_includes stdout, "Scamalytics"
    refute_includes stdout, "未知"
    refute_includes stdout, "风险等级："
    refute_match(/IP2Location\s+分值=/, stdout)
    assert_operator stdout.lines.map { |line| line.chomp.length }.max, :<=, 80
    refute_includes stderr, "unrecognized modifier"
  end

  def test_unavailable_reputation_sources_are_compacted_into_one_summary_line
    report_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      Font_Cyan='' Font_Suffix='' Font_B='' Font_Green='' Font_Red='' Font_Purple=''
      YY=cn
      typeset -A maxmind ipinfo ipapi ip2location abuseipdb scamalytics ipdata ipqs ping0 ripestat internetdb sping0
      ping0[status]=unknown
      ipqs[status]=upstream_insufficient_credits
      internetdb[status]=not_found
      clean_ansi(){ print -rn -- "$1" }
      source "$1"
      show_ping0
      show_routing
      show_exposure
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
    assert_equal 1, stdout.lines.length
    assert_includes stdout, "本次无可用资料（不等于低风险）"
    assert_includes stdout, "IPQualityScore（上游额度不足）"
    assert_includes stdout, "RIPEstat"
    assert_includes stdout, "Shodan InternetDB（无公开记录）"
    refute_includes stdout, "状态：unknown"
    refute_includes stdout, "风险分数："
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
    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "dnsbl",
      "-6"
    )
    assert_equal 61, status.exitstatus
    assert_includes stdout, "DNSBL"
    assert_empty stderr

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

  def test_source_is_zsh_native_and_contains_no_removed_runtime_paths
    source = File.binread(SCRIPT)

    assert source.start_with?("#!/bin/zsh\n")
    assert_includes source, "--confirm-network-lookup"
    assert_includes source, "typeset -A"
    assert_includes source, "/bin/zsh -fc"
    assert_includes source, 'command curl -q "$@"'
    assert_includes source, '--arg score_ipqs "${ipqs[score]:-}"'
    assert_includes source, '--arg info_org "$info_org"'
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
      PING0_LIBRARY,
      RIPESTAT_LIBRARY,
      INTERNETDB_LIBRARY,
      REPUTATION_REPORT,
      PING0_GEO_FIXTURE,
      PING0_CHALLENGE_FIXTURE,
      RIPESTAT_FIXTURE,
      INTERNETDB_FIXTURE
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
