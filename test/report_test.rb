# frozen_string_literal: true

require_relative "support/reporter_test_case"

class ReportTest < ReporterTestCase
  def test_ipapi_factor_column_survives_anonymous_rate_limited_and_failed_queries
    probe = <<~'ZSH'
      source "$1"
      source "$2"
      YY="$3"
      typeset -A sfactor ipapi ipqs
      sfactor[title]=Factors
      ipqs[proxy]=false
      ipapi[status]="$4" ipapi[mode]="$5" ipapi[credential_mode]="$6"
      if [[ "${ipapi[status]}" == ok ]];then
        if [[ "${ipapi[mode]}" == anonymous ]];then
          ipapi[risk_status]=not_provided
        else
          ipapi[risk_status]=ok ipapi[proxy]=false
        fi
      fi
      show_factor
    ZSH
    {
      ["cn", "ok", "anonymous", "anonymous"] => "未提供风险",
      ["en", "ok", "anonymous", "anonymous"] => "risk not supplied",
      ["cn", "rate_limited", "", "key"] => "限流",
      ["en", "rate_limited", "", "key"] => "rate limit",
      ["cn", "network_error", "", "key"] => "连接失败",
      ["cn", "tls_error", "", "key"] => "TLS 握手失败",
      ["en", "tls_error", "", "key"] => "TLS handshake failed",
      ["cn", "timeout", "", "key"] => "连接超时",
      ["cn", "invalid_response", "", "key"] => "响应格式异常",
      ["cn", "tls_verification_failed", "", "key"] => "TLS 证书验证失败",
      ["en", "tls_verification_failed", "", "key"] => "TLS certificate rejected",
      ["cn", "ok", "full", "key"] => "可用",
      ["en", "ok", "full", "key"] => "available"
    }.each do |args, expected|
      stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe,
        "ipapi-factor-status", REPUTATION_REPORT, TERMINAL_LIBRARY, *args)
      assert status.success?, stderr
      assert_empty stderr
      assert_match(/(?:参数|Field)\s+\|.*ipapi\.is.*IPQS/, stdout)
      assert_match(/(?:查询状态|Status)\s+\|\s+#{Regexp.escape(expected)}\s+\|/, stdout)
      refute_match(/^ipapi\.is[：:]/, stdout)
      table_widths = stdout.lines.select { |line| line.include?(" | ") }.map do |line|
        line.split("|").map { |cell| cell.chars.sum { |char| char.ascii_only? ? 1 : 2 } }
      end
      assert_equal 1, table_widths.uniq.length, stdout
      if args[2] == "full"
        assert_match(/(?:代理|Proxy)\s+\|\s+(?:否|No)\s+\|/, stdout)
      else
        assert_match(/(?:代理|Proxy)\s+\|\s+-\s+\|/, stdout)
      end
    end
  end

  def test_demo_risk_fields_are_visible_in_the_requested_sections_without_fake_scores
    probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      source "$2"
      YY=cn
      typeset -A sscore sfactor cloudflare dbip ipwhois ipapi
      sscore[title]='三、风险评分' sfactor[title]='四、风险因子'
      cloudflare[status]=ok cloudflare[threats]='Phishing, Malware'
      cloudflare[threats_json]='["Phishing","Malware"]' dbip[status]=ok dbip[risk_status]=ok dbip[risk]=低风险
      ipwhois[status]=ok ipwhois[risk_status]=ok ipwhois[countrycode]=US ipapi[proxy]=true
      ipwhois[proxy]=false ipwhois[vpn]=true ipwhois[server]=true
      show_score
      show_factor
    ZSH
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "source-sections", REPUTATION_REPORT, TERMINAL_LIBRARY)
    assert status.success?, stderr
    assert_empty stderr
    score, factors = stdout.split("四、风险因子", 2)
    assert_includes score, "三、风险评分"
    assert_match(/参数\s+\|\s+DB-IP/, score)
    assert_match(/分值\s+\|\s+-/, score)
    assert_match(/分段\/标签\s+\|\s+低风险/, score)
    refute_includes score, "Cloudflare"
    refute_includes score, "Phishing"
    assert_includes score, "公开示例/可用"
    assert_includes factors, "IPWHOIS"
    assert_match(/代理\s+\|\s+是\s+\|\s+否/, factors)
    assert_match(/VPN\s+\|\s+-\s+\|\s+是/, factors)
    assert_match(/查询状态\s+\|\s+可用\s+\|\s+可用/, factors)
    refute_match(/^(?:Cloudflare|DB-IP|ipapi\.is|IPWHOIS)[：:]/, stdout)
    refute_match(/Threat Score|不是“否”|原始风险等级/, stdout)
  end

  def test_cloudflare_missing_and_empty_threats_never_imply_a_clean_ip
    probe = <<~'ZSH'
      source "$1"
      source "$2"
      YY=en
      typeset -A sscore cloudflare
      sscore[title]='3. Risk Score'
      cloudflare[status]="$3" cloudflare[threats_json]="$4"
      show_cloudflare_basic
      show_score
    ZSH
    { ["ok", "null"] => "-", ["ok", "[]"] => "none listed", ["rate_limited", "null"] => "-" }.each do |(state, threats), expected|
      stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "threat-absence", REPUTATION_REPORT, TERMINAL_LIBRARY, state, threats)
      assert status.success?, stderr
      assert_empty stderr
      refute_includes stdout, "3. Risk Score"
      if threats == "[]"
        assert_includes stdout, "Threat categories: #{expected}"
      else
        refute_includes stdout, "Threat categories"
      end
      assert_includes stdout, state == "ok" ? "official/available" : "official/rate limit"
      refute_includes stdout, "Threat Score"
      refute_includes stdout, "Low"
    end
  end

  def test_demo_limitations_are_visible_in_risk_sections_without_clean_claims
    probe = <<~'ZSH'
      source "$1"
      source "$2"
      YY=cn
      typeset -A sscore sfactor dbip ipwhois
      sscore[title]='三、风险评分' sfactor[title]='四、风险因子'
      dbip[status]=rate_limited ipwhois[status]=rate_limited
      show_score
      show_factor
    ZSH
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "demo-limits", REPUTATION_REPORT, TERMINAL_LIBRARY)
    assert status.success?, stderr
    assert_empty stderr
    assert_includes stdout, "DB-IP"
    assert_match(/参数\s+\|\s+IPWHOIS/, stdout)
    assert_match(/查询状态\s+\|\s+限流/, stdout)
    assert_match(/来源\/状态\s+\|\s+公开示例\/限流/, stdout)
    refute_match(/低风险|\|\s+否/, stdout)
  end

  def test_cloudflare_is_in_basic_information_for_both_report_routes_and_languages
    probe = reporter_functions("check_IP", "show_basic", "show_basic_lite") + <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      source "$2"
      YY="$3"
      mode_lite="$4" mode_json=0 mode_output=0
      typeset -A sbasic stype sscore sfactor smail smailstatus smail_response maxmind ipinfo ip2location cloudflare dbip
      sbasic[title]='1. Basic Information (relay)' sbasic[title_lite]='1. Basic Information (fallback)'
      stype[title]='2. IP Type' sscore[title]='3. Risk Score' sfactor[title]='4. Risk Factors'
      maxmind[dms]=null ipinfo[dms]=null
      ip2location[susetype]=ISP ip2location[score]=0 dbip[status]=ok dbip[risk_status]=ok dbip[risk]=low
      cloudflare[status]=ok cloudflare[threats]='Phishing, Malware'
      cloudflare[threats_json]='["Phishing","Malware"]'
      cloudflare[network]=AS9808 cloudflare[countrycode]=CN
      cloudflare[infrastructure]=isp cloudflare[org]='China Mobile Communications Group Co., Ltd.'
      scope_includes(){ [[ "$1" == reputation ]]; }
      for operation in hide_ipv4 show_head show_tail show_unavailable_sources \
        db_maxmind_relay db_ipinfo db_ipregistry db_scamalytics db_ipapi db_ipwhois \
        db_dbip db_cloudflare db_abuseipdb db_ip2location db_ipdata db_ipqs db_ping0 \
        db_ripestat db_shodan_internetdb;do
        functions[$operation]='return 0'
      done
      check_IP 198.51.100.23 4
    ZSH
    %w[cn en].product(%w[0 1]).each do |language, lite|
      stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe,
        "cloudflare-basic-context", REPUTATION_REPORT, TERMINAL_LIBRARY, language, lite)
      assert status.success?, stderr
      assert_empty stderr
      basic, remaining = stdout.split("2. IP Type", 2)
      assert_includes basic, lite == "0" ? "1. Basic Information (relay)" : "1. Basic Information (fallback)"
      assert_includes basic, "Cloudflare"
      assert_includes basic, "ASN=AS9808"
      assert_includes basic, language == "cn" ? "ASN所属地=CN" : "ASN country=CN"
      assert_includes basic, language == "cn" ? "ASN类型=isp" : "ASN type=isp"
      assert_includes basic, "China Mobile Communications Group Co., Ltd."
      assert_includes basic, "Phishing, Malware"
      refute_nil remaining
      assert_includes remaining, "3. Risk Score"
      refute_match(/Cloudflare|AS9808|ASN|Phishing|China Mobile/, remaining)
    end
  end

  def test_cloudflare_unavailable_context_does_not_repeat_network_rows
    probe = <<~'ZSH'
      source "$1"
      source "$2"
      YY=en
      typeset -A sscore cloudflare
      sscore[title]=Scores
      cloudflare[status]="$3"
      [[ "$3" != ok ]]&&cloudflare[network]=AS64500
      show_cloudflare_basic
      show_score
    ZSH
    %w[ok rate_limited not_configured invalid_response].each do |state|
      stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe,
        "cloudflare-no-asn-context", REPUTATION_REPORT, TERMINAL_LIBRARY, state)
      assert status.success?, stderr
      assert_empty stderr
      assert_includes stdout, "Cloudflare"
      refute_match(/ASN|AS64500|Low/, stdout)
    end
  end

  def test_score_rows_align_with_independent_column_widths
    probe = <<~'ZSH'
      setopt KSH_ARRAYS
      source "$1"
      source "$2"
      YY="$3"
      typeset -A sscore cloudflare dbip
      sscore[title]=Scores
      cloudflare[status]=ok dbip[status]=ok dbip[risk_status]=not_provided
      show_score
    ZSH
    %w[cn en].each do |language|
      stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "long-score-cells", REPUTATION_REPORT, TERMINAL_LIBRARY, language)
      assert status.success?, stderr
      assert_empty stderr
      rows = stdout.lines.select { |line| line.include?(" | ") }
      assert_operator rows.length, :>=, 4
      positions = rows.map do |line|
        column = 0
        line.each_char.map do |char|
          current = column
          column += char.ascii_only? ? 1 : 2
          current if char == "|"
        end.compact
      end
      assert_equal 1, positions.uniq.length, rows.join
    end
  end

def test_optional_mail_section_follows_reputation_context
  source = File.read(SCRIPT)
  assert_includes source, 'smail[title]="6. Email service availability and blacklist detection"'
  assert_includes source, 'smail[title]="六、邮局连通性及黑名单检测"'
  refute_match(/MediaUnlockTest|OpenAITest|media_trace_country_code/, source)
end

  def test_report_files_preserve_json_escapes_ansi_bytes_and_plain_layout
    value = "tab\tline\nterminal\e[31mred\e[0m"
    json = JSON.generate("value" => value)
    ansi = "  \e[32mfixture\e[0m  \nnext"
    formats = { "JSON" => json, "ansi" => ansi, "txt" => "  fixture  \nnext" }
    Dir.mktmpdir("ipquality-report-formats-") do |directory|
      formats.each do |extension, expected|
        path = File.join(directory, "report.#{extension}")
        stdout, stderr, status = write_report(path, json, ansi)
        assert status.success?, stderr
        assert_equal expected + "\n", File.binread(path)
        assert_equal 0o600, File.stat(path).mode & 0o777
        assert_empty stdout
        assert_empty stderr
      end
      assert_equal value, JSON.parse(File.read(File.join(directory, "report.JSON"))).fetch("value")
    end
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
      source "$1"
      source "$2"
      report=$(show_factor)
      print -r -- "$report"
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh",
      "-f",
      "-c",
      output_probe,
      "report-color-output-test",
      REPUTATION_REPORT,
      TERMINAL_LIBRARY
    )

    assert status.success?, stderr
    assert_includes stdout, "\e[32m\e[1m否"
    assert_includes stdout, "\e[31m\e[1m是"
    refute_includes stdout, "\\033["
    assert_empty stderr
  end

  def test_shared_terminal_cleanup_preserves_layout_and_normalizes_values
    probe = <<~'ZSH'
      source "$1"
      value=$' \t\\033[31m中\\033[0m \033[2K\033[3G\033[1;2H\033[F\n  next \t\n\n'
      clean_ansi "$value" "$2"
    ZSH
    { "preserve" => " \t中 \n  next \t\n\n", "" => "中\nnext" }.each do |mode, expected|
      stdout, stderr, status = Open3.capture3(
        "/bin/zsh", "-f", "-c", probe, "terminal-cleanup-test", TERMINAL_LIBRARY, mode
      )
      assert status.success?, stderr
      assert_equal expected, stdout
      assert_empty stderr
    end
  end

  def test_shared_display_width_aligns_ascii_unicode_ansi_and_whitespace
    probe = reporter_functions("calc_padding") + <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT NO_CASE_MATCH
      source "$1"
      source "$2"
      for value in 'abc' '中文' $'\033[31mA中\033[0m' ' A中 ' '\033[31mA中\033[0m'; do
        print -r -- "$(display_width "$value")"
      done
      terminal_table_cell $'\033[31m A中 \033[0m' 8
      print -r -- '|'
      calc_padding ' A中 ' 11
      print -r -- "${#PADDING}"
      [[ -o KSH_ARRAYS && -o SH_WORD_SPLIT && -o NO_CASE_MATCH ]]
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", probe, "terminal-width-test", TERMINAL_LIBRARY, REPUTATION_REPORT
    )
    assert status.success?, stderr
    assert_equal "3\n4\n3\n5\n3\n\e[31m A中 \e[0m   |\n3\n", stdout
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
      source "$2"
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
      REPUTATION_REPORT,
      TERMINAL_LIBRARY
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
      source "$2"
      source "$1"
      show_type
      show_score
      show_factor
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", report_probe,
      "report-alignment-test", REPUTATION_REPORT, TERMINAL_LIBRARY
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
      source "$2"
      source "$1"
      show_network_context
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", context_probe,
      "network-context-report-test", REPUTATION_REPORT, TERMINAL_LIBRARY
    )

    assert status.success?, stderr
    assert_equal 4, stdout.lines.length
    assert_equal 1, stdout.scan("五、官方网络观测").length
    refute_includes stdout, "Cloudflare"
    refute_includes stdout, "IPWHOIS"
    assert_includes stdout, "Ping0：已核对"
    assert_includes stdout, "RIPEstat：状态=announced"
    assert_includes stdout, "Shodan：端口=22, 443"
    assert_includes stdout, "主机名数量=1"
    refute_includes stdout, "Ping0 官方公开观测"
    refute_includes stdout, "官方路由观测（RIPEstat"
    assert_empty stderr
  end

  def test_cloudflare_dbip_and_ipwhois_stay_out_of_section_five
    context_probe = <<~'ZSH'
      setopt KSH_ARRAYS
      Font_B='' Font_Red='' Font_Green='' Font_Purple='' Font_Cyan='' Font_Suffix=''
      YY=cn fullIP=1
      typeset -A ipapi ipwhois cloudflare dbip ping0 ripestat internetdb sping0
      dbip[status]=ok dbip[countrycode]=US dbip[city]='Example City'
      ipapi[mode]=anonymous ipapi[anonymous_asn]='AS64500 Example ISP'
      ipapi[anonymous_company]='Example ISP' ipapi[anonymous_country]='United States'
      ipapi[anonymous_city]='Example City' ipapi[anonymous_timezone]='America/Los_Angeles'
      ipwhois[status]=ok ipwhois[countrycode]=US ipwhois[asn]=64500
      ipwhois[org]='Example Network' ipwhois[isp]='Example ISP' ipwhois[timezone]='America/Los_Angeles'
      cloudflare[status]=ok cloudflare[countrycode]=US cloudflare[network]=AS64500
      cloudflare[org]='Example Network' cloudflare[infrastructure]=hosting_provider
      cloudflare[threats]='Phishing, Malware'
      source "$2"
      source "$1"
      show_network_context
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", context_probe,
      "additional-provider-context-test", REPUTATION_REPORT, TERMINAL_LIBRARY
    )

    assert status.success?, stderr
    assert_equal 2, stdout.lines.length
    assert_includes stdout, "ipapi.is：匿名最小响应 | ASN=AS64500 Example ISP"
    refute_includes stdout, "ipwho.is"
    refute_includes stdout, "IPWHOIS"
    refute_includes stdout, "Cloudflare"
    refute_includes stdout, "DB-IP"
    refute_includes stdout, "风险评分"
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
      source "$2"
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
      REPUTATION_REPORT,
      TERMINAL_LIBRARY
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
      source "$2"
      source "$1"
      show_score
      show_factor
    ZSH
    stdout, stderr, status = Open3.capture3(
      "/bin/zsh", "-f", "-c", report_probe,
      "ipqs-independent-report-test", REPUTATION_REPORT, TERMINAL_LIBRARY
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

  def test_dnsbl_report_explains_aggregate_uceprotect_levels
    function_source = reporter_functions("show_dnsbl")

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
      "dnsbl-aggregate-context-test", function_source
    )

    assert status.success?, stderr
    assert_includes stdout, "dnsbl-2.uceprotect.net, dnsbl-3.uceprotect.net"
    assert_includes stdout, "网段／ASN 级记录"
    assert_includes stdout, "不等于这个单独 IP 曾发送垃圾邮件"
    assert_empty stderr
  end

  def test_report_writer_rejects_existing_files_links_and_missing_parents
    Dir.mktmpdir("ipquality-report-paths-") do |directory|
      existing = File.join(directory, "existing.txt")
      missing = File.join(directory, "must-not-exist.txt")
      symlink = File.join(directory, "link.txt")
      dangling = File.join(directory, "dangling.txt")
      File.write(existing, "keep me")
      File.symlink(existing, symlink)
      File.symlink(missing, dangling)

      [existing, symlink, dangling, File.join(directory, "absent", "report.txt")].each do |path|
        _stdout, stderr, status = write_report(path, "{}", "replacement")
        assert_equal 73, status.exitstatus, path
        assert_includes stderr, "cannot create the report path exclusively and safely"
        assert_equal "keep me", File.read(existing)
        refute File.exist?(missing)
      end
      assert File.symlink?(symlink)
      assert File.symlink?(dangling)
    end
  end

  private

  def write_report(path, json, ansi)
    probe = reporter_functions("open_report_output", "write_report_output", "close_report_output") + <<~'ZSH'
      source "$1"
      umask 000
      typeset outputfile="$2" ipjson="$3" YY=en
      typeset -i output_fd=-1
      write_report_output "$4" || exit $?
      close_report_output
      [[ $output_fd -eq -1 ]]
    ZSH
    Open3.capture3("/bin/zsh", "-f", "-c", probe, "report-writer-test",
                   TERMINAL_LIBRARY, path, json, ansi)
  end
end
