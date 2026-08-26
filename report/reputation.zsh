# Terminal rendering for reputation observations. Providers are columns and
# source-specific dimensions are rows; score scales are never collapsed.

report_unknown_label(){
[[ "$YY" == "cn" ]]&&print -rn -- "未知"||print -rn -- "Unknown"
}

report_is_unknown(){
typeset value compact
value=$(clean_ansi "$1")
compact="${value//[[:space:]]/}"
case "${compact:l}" in
""|"null"|"unknown")return 0
;;
"未知")return 0
;;
*)return 1
esac
}

report_unknown(){
print -rn -- "$Font_Purple$(report_unknown_label)$Font_Suffix"
}

report_dash(){
# Keep the missing-value marker ASCII. U+2014 has an ambiguous terminal width:
# some renderers use one cell while others use two, shifting every later column.
print -rn -- "${Font_Purple:-}-${Font_Suffix:-}"
}

report_neutral_value(){
if report_is_unknown "$1";then
report_unknown
else
print -rn -- "$Font_Cyan$(clean_ansi "$1")$Font_Suffix"
fi
}

report_preserved_value(){
typeset raw="$1" plain color="${Font_Cyan:-}"
if report_is_unknown "$raw";then
report_unknown
else
plain=$(clean_ansi "$raw")
# Legacy provider labels include presentation padding inside their ANSI
# background. Tables own their padding, so retain only the semantic label and
# map its colour to a foreground highlight.
plain="${plain#"${plain%%[![:space:]]*}"}"
plain="${plain%"${plain##*[![:space:]]}"}"
if [[ -n "${Back_Red:-}" && "$raw" == *"$Back_Red"* ]] ||
   [[ -n "${Font_Red:-}" && "$raw" == *"$Font_Red"* ]];then
color="${Font_Red:-}"
elif [[ -n "${Back_Green:-}" && "$raw" == *"$Back_Green"* ]] ||
     [[ -n "${Font_Green:-}" && "$raw" == *"$Font_Green"* ]];then
color="${Font_Green:-}"
elif [[ -n "${Back_Yellow:-}" && "$raw" == *"$Back_Yellow"* ]] ||
     [[ -n "${Font_Yellow:-}" && "$raw" == *"$Font_Yellow"* ]];then
color="${Font_Yellow:-}"
elif [[ -n "${Back_Purple:-}" && "$raw" == *"$Back_Purple"* ]] ||
     [[ -n "${Font_Purple:-}" && "$raw" == *"$Font_Purple"* ]];then
color="${Font_Purple:-}"
fi
print -rn -- "$color${Font_B:-}$plain${Font_Suffix:-}"
fi
}

report_neutral_or_dash(){
if report_is_unknown "$1";then
report_dash
else
report_neutral_value "$1"
fi
}

report_preserved_or_dash(){
if report_is_unknown "$1";then
report_dash
else
report_preserved_value "$1"
fi
}

report_factor_value(){
case "$1" in
true) [[ "$YY" == "cn" ]]&&print -rn -- "$Font_Red${Font_B}是$Font_Suffix"||print -rn -- "$Font_Red${Font_B}Yes$Font_Suffix"
;;
false) [[ "$YY" == "cn" ]]&&print -rn -- "$Font_Green${Font_B}否$Font_Suffix"||print -rn -- "$Font_Green${Font_B}No$Font_Suffix"
;;
??) print -rn -- "$Font_Cyan$1$Font_Suffix"
;;
*) report_unknown
esac
}

report_factor_or_dash(){
if report_is_unknown "$1";then
report_dash
else
report_factor_value "$1"
fi
}

report_any_known(){
typeset value
for value in "$@";do
report_is_unknown "$value"||return 0
done
return 1
}

report_type_source(){
case "$YY:$1" in
cn:ipinfo)print -rn -- "公开示例组件"
;;
cn:direct)print -rn -- "直接公开 API"
;;
cn:relay)print -rn -- "上游中继"
;;
cn:official)print -rn -- "官方 API"
;;
en:ipinfo)print -rn -- "public demo widget"
;;
en:direct)print -rn -- "direct public API"
;;
en:official)print -rn -- "official API"
;;
*)print -rn -- "upstream relay"
esac
}

report_score_source_status(){
typeset source_kind="$1" query_state="$2"
typeset source_label state_label state_color="${Font_Purple:-}"
case "$YY:$source_kind" in
cn:official)source_label="官方"
;;
cn:direct)source_label="直连"
;;
cn:relay)source_label="中继"
;;
en:official)source_label="official"
;;
en:direct)source_label="direct"
;;
*)source_label="relay"
esac
case "$YY:$query_state" in
cn:ok)state_label="可用" state_color="${Font_Green:-}"
;;
cn:upstream_insufficient_credits|cn:official_insufficient_credits)state_label="额度用完"
;;
cn:rate_limited)state_label="限流"
;;
cn:http_403)state_label="HTTP 403"
;;
cn:not_configured)state_label="未配置"
;;
cn:*)state_label="查询失败"
;;
en:ok)state_label="available" state_color="${Font_Green:-}"
;;
en:upstream_insufficient_credits|en:official_insufficient_credits)state_label="no credit"
;;
en:rate_limited)state_label="rate limit"
;;
en:http_403)state_label="HTTP 403"
;;
en:not_configured)state_label="not set"
;;
*)state_label="failed"
esac
print -rn -- "${Font_Cyan:-}$source_label${Font_Suffix:-}/${state_color}$state_label${Font_Suffix:-}"
}

report_display_width(){
typeset plain non_ascii
plain=$(clean_ansi "$1")
non_ascii="${plain//[[:ascii:]]/}"
print -rn -- $((${#plain}+${#non_ascii}))
}

report_table_cell(){
typeset value="$1"
typeset width="$2"
typeset visible padding
visible=$(report_display_width "$value")
padding=$((width-visible))
[[ $padding -lt 0 ]]&&padding=0
print -rn -- "$value"
printf '%*s' "$padding" ''
}

report_table_row(){
typeset label="$1"
typeset label_width="$2"
typeset cell_width="$3"
shift 3
report_table_cell "$label" "$label_width"
typeset value
for value in "$@";do
print -rn -- " | "
report_table_cell "$value" "$cell_width"
done
print
}

report_table_rule(){
typeset columns="$1"
typeset label_width="$2"
typeset cell_width="$3"
typeset rule=""
typeset index column
for ((index=0;index<label_width;index++));do rule+="-";done
for ((column=0;column<columns;column++));do
rule+="-+-"
for ((index=0;index<cell_width;index++));do rule+="-";done
done
print -r -- "$rule"
}

report_factor_row(){
typeset label="$1"
typeset label_width="$2"
typeset cell_width="$3"
shift 3
typeset -a values rendered
values=("$@")
report_any_known "${values[@]}"||return 0
typeset value
for value in "${values[@]}";do
rendered+=("$(report_factor_or_dash "$value")")
done
report_table_row "$label" "$label_width" "$cell_width" "${rendered[@]}"
}

show_type(){
typeset -a headers sources usages companies
if report_any_known "${ipinfo[susetype]}" "${ipinfo[scomtype]}";then
headers+=("${Font_B}${Font_Cyan}IPinfo$Font_Suffix")
sources+=("$(report_type_source ipinfo)")
usages+=("${ipinfo[susetype]}")
companies+=("${ipinfo[scomtype]}")
fi
if report_any_known "${ipregistry[susetype]}" "${ipregistry[scomtype]}";then
headers+=("${Font_B}${Font_Cyan}Ipregistry$Font_Suffix")
sources+=("$(report_type_source official)")
usages+=("${ipregistry[susetype]}")
companies+=("${ipregistry[scomtype]}")
fi
if report_any_known "${ipqs[susetype]}";then
headers+=("${Font_B}${Font_Cyan}IPQS$Font_Suffix")
if [[ "${ipqs[source]}" == "official_api" ]];then
sources+=("$(report_type_source official)")
else
sources+=("$(report_type_source relay)")
fi
usages+=("${ipqs[susetype]}")
companies+=("")
fi
if report_any_known "${ipapi[susetype]}" "${ipapi[scomtype]}";then
headers+=("${Font_B}${Font_Cyan}ipapi.is$Font_Suffix")
sources+=("$(report_type_source direct)")
usages+=("${ipapi[susetype]}")
companies+=("${ipapi[scomtype]}")
fi
if report_any_known "${ip2location[susetype]}" "${ip2location[scomtype]}";then
headers+=("${Font_B}${Font_Cyan}IP2Location$Font_Suffix")
sources+=("$(report_type_source relay)")
usages+=("${ip2location[susetype]}")
companies+=("${ip2location[scomtype]}")
fi
if report_any_known "${abuseipdb[susetype]}";then
headers+=("${Font_B}${Font_Cyan}AbuseIPDB$Font_Suffix")
sources+=("$(report_type_source relay)")
usages+=("${abuseipdb[susetype]}")
companies+=("")
fi
(( ${#headers[@]} ))||return 0
print -r -- "$Font_B${stype[title]}$Font_Suffix"
typeset source
typeset -a rendered_sources rendered_usages rendered_companies
for source in "${sources[@]}";do rendered_sources+=("$(report_neutral_value "$source")");done
for source in "${usages[@]}";do rendered_usages+=("$(report_preserved_or_dash "$source")");done
for source in "${companies[@]}";do rendered_companies+=("$(report_preserved_or_dash "$source")");done
typeset field_label source_label usage_label company_label cell_width
if [[ "$YY" == "cn" ]];then
field_label="参数" source_label="来源" usage_label="使用类型" company_label="公司类型" cell_width=15
else
field_label="Field" source_label="Source" usage_label="Usage" company_label="Company" cell_width=19
fi
report_table_row "${Font_B}${field_label}${Font_Suffix}" 10 "$cell_width" "${headers[@]}"
report_table_rule "${#headers[@]}" 10 "$cell_width"
report_table_row "$source_label" 10 "$cell_width" "${rendered_sources[@]}"
report_table_row "$usage_label" 10 "$cell_width" "${rendered_usages[@]}"
report_table_row "$company_label" 10 "$cell_width" "${rendered_companies[@]}"
}

show_score(){
typeset -a headers scores risks scales source_statuses
if report_any_known "${ip2location[score]}" "${ip2location[risk]}";then
headers+=("${Font_B}${Font_Cyan}IP2Location$Font_Suffix")
scores+=("${ip2location[score]}") risks+=("${ip2location[risk]}") scales+=("0-99 potential")
source_statuses+=("$(report_score_source_status relay ok)")
fi
if report_any_known "${scamalytics[score]}" "${scamalytics[risk]}";then
headers+=("${Font_B}${Font_Cyan}Scamalytics$Font_Suffix")
scores+=("${scamalytics[score]}") risks+=("${scamalytics[risk]}") scales+=("0-100 fraud")
source_statuses+=("$(report_score_source_status relay ok)")
fi
if report_any_known "${ipapi[score]}" "${ipapi[risk]}";then
headers+=("${Font_B}${Font_Cyan}ipapi.is$Font_Suffix")
scores+=("${ipapi[score]}") risks+=("${ipapi[risk]}") scales+=("0-100% abuse")
source_statuses+=("$(report_score_source_status direct ok)")
fi
if report_any_known "${abuseipdb[score]}" "${abuseipdb[risk]}";then
headers+=("${Font_B}${Font_Cyan}AbuseIPDB$Font_Suffix")
scores+=("${abuseipdb[score]}") risks+=("${abuseipdb[risk]}") scales+=("0-100 confidence")
source_statuses+=("$(report_score_source_status relay ok)")
fi
if report_any_known "${ipqs[score]}" "${ipqs[risk]}" ||
   [[ -n "${ipqs[source]}" || ( -n "${ipqs[status]}" && "${ipqs[status]}" != "unknown" ) ]];then
headers+=("${Font_B}${Font_Cyan}IPQS$Font_Suffix")
scores+=("${ipqs[score]}") risks+=("${ipqs[risk]}") scales+=("0-100 fraud")
typeset ipqs_source_kind="relay"
if [[ "${ipqs[source]}" == "official_api" || "${ipqs[status]}" == official_* ]];then
ipqs_source_kind="official"
fi
typeset ipqs_query_status="${ipqs[status]:-unknown}"
if report_any_known "${ipqs[score]}" "${ipqs[risk]}" && [[ "$ipqs_query_status" == "unknown" ]];then
ipqs_query_status="ok"
fi
source_statuses+=("$(report_score_source_status "$ipqs_source_kind" "$ipqs_query_status")")
fi
(( ${#headers[@]} ))||return 0
print -r -- "$Font_B${sscore[title]}$Font_Suffix"
typeset value
typeset -a rendered_scores rendered_risks rendered_scales
for value in "${scores[@]}";do rendered_scores+=("$(report_neutral_or_dash "$value")");done
for value in "${risks[@]}";do rendered_risks+=("$(report_preserved_or_dash "$value")");done
for value in "${scales[@]}";do rendered_scales+=("$(report_neutral_value "$value")");done
typeset field_label score_label band_label scale_label source_status_label note cell_width
if [[ "$YY" == "cn" ]];then
field_label="参数" score_label="分值" band_label="分段/标签" scale_label="量表" source_status_label="来源/状态" cell_width=16
note="注：各平台量表不同；- 表示该来源本次未提供。"
else
field_label="Field" score_label="Score" band_label="Band / label" scale_label="Scale" source_status_label="Source/status" cell_width=19
note="Note: provider scales differ; - means that source did not supply the field."
fi
print -r -- "$note"
report_table_row "${Font_B}${field_label}${Font_Suffix}" 10 "$cell_width" "${headers[@]}"
report_table_rule "${#headers[@]}" 10 "$cell_width"
report_table_row "$score_label" 10 "$cell_width" "${rendered_scores[@]}"
report_any_known "${risks[@]}"&&report_table_row "$band_label" 10 "$cell_width" "${rendered_risks[@]}"
report_table_row "$scale_label" 10 "$cell_width" "${rendered_scales[@]}"
report_table_row "$source_status_label" 10 "$cell_width" "${source_statuses[@]}"
}

show_factor(){
typeset -a headers countries proxies vpns tors servers abusers robots
if report_any_known "${ip2location[countrycode]}" "${ip2location[proxy]}" "${ip2location[vpn]}" "${ip2location[tor]}" "${ip2location[server]}" "${ip2location[abuser]}" "${ip2location[robot]}";then
headers+=("${Font_B}${Font_Cyan}IP2Location$Font_Suffix")
countries+=("${ip2location[countrycode]}") proxies+=("${ip2location[proxy]}")
vpns+=("${ip2location[vpn]}") tors+=("${ip2location[tor]}")
servers+=("${ip2location[server]}") abusers+=("${ip2location[abuser]}")
robots+=("${ip2location[robot]}")
fi
if report_any_known "${ipapi[countrycode]}" "${ipapi[proxy]}" "${ipapi[vpn]}" "${ipapi[tor]}" "${ipapi[server]}" "${ipapi[abuser]}" "${ipapi[robot]}";then
headers+=("${Font_B}${Font_Cyan}ipapi.is$Font_Suffix")
countries+=("${ipapi[countrycode]}") proxies+=("${ipapi[proxy]}")
vpns+=("${ipapi[vpn]}") tors+=("${ipapi[tor]}")
servers+=("${ipapi[server]}") abusers+=("${ipapi[abuser]}")
robots+=("${ipapi[robot]}")
fi
if report_any_known "${ipregistry[countrycode]}" "${ipregistry[proxy]}" "${ipregistry[vpn]}" "${ipregistry[tor]}" "${ipregistry[server]}" "${ipregistry[abuser]}";then
headers+=("${Font_B}${Font_Cyan}Ipregistry$Font_Suffix")
countries+=("${ipregistry[countrycode]}") proxies+=("${ipregistry[proxy]}")
vpns+=("${ipregistry[vpn]}") tors+=("${ipregistry[tor]}")
servers+=("${ipregistry[server]}") abusers+=("${ipregistry[abuser]}")
robots+=("")
fi
if report_any_known "${ipqs[countrycode]}" "${ipqs[proxy]}" "${ipqs[vpn]}" "${ipqs[tor]}" "${ipqs[server]}" "${ipqs[abuser]}" "${ipqs[robot]}";then
headers+=("${Font_B}${Font_Cyan}IPQS$Font_Suffix")
countries+=("${ipqs[countrycode]}") proxies+=("${ipqs[proxy]}")
vpns+=("${ipqs[vpn]}") tors+=("${ipqs[tor]}")
servers+=("${ipqs[server]}") abusers+=("${ipqs[abuser]}")
robots+=("${ipqs[robot]}")
fi
if report_any_known "${scamalytics[countrycode]}" "${scamalytics[proxy]}" "${scamalytics[vpn]}" "${scamalytics[tor]}" "${scamalytics[server]}" "${scamalytics[abuser]}" "${scamalytics[robot]}";then
headers+=("${Font_B}${Font_Cyan}Scamalytics$Font_Suffix")
countries+=("${scamalytics[countrycode]}") proxies+=("${scamalytics[proxy]}")
vpns+=("${scamalytics[vpn]}") tors+=("${scamalytics[tor]}")
servers+=("${scamalytics[server]}") abusers+=("${scamalytics[abuser]}")
robots+=("${scamalytics[robot]}")
fi
if report_any_known "${ipdata[countrycode]}" "${ipdata[proxy]}" "${ipdata[vpn]}" "${ipdata[tor]}" "${ipdata[server]}" "${ipdata[abuser]}" "${ipdata[robot]}";then
headers+=("${Font_B}${Font_Cyan}ipdata$Font_Suffix")
countries+=("${ipdata[countrycode]}") proxies+=("${ipdata[proxy]}")
vpns+=("${ipdata[vpn]}") tors+=("${ipdata[tor]}")
servers+=("${ipdata[server]}") abusers+=("${ipdata[abuser]}")
robots+=("${ipdata[robot]}")
fi
if report_any_known "${ipinfo[countrycode]}" "${ipinfo[proxy]}" "${ipinfo[vpn]}" "${ipinfo[tor]}" "${ipinfo[server]}" "${ipinfo[abuser]}" "${ipinfo[robot]}";then
headers+=("${Font_B}${Font_Cyan}IPinfo$Font_Suffix")
countries+=("${ipinfo[countrycode]}") proxies+=("${ipinfo[proxy]}")
vpns+=("${ipinfo[vpn]}") tors+=("${ipinfo[tor]}")
servers+=("${ipinfo[server]}") abusers+=("${ipinfo[abuser]}")
robots+=("${ipinfo[robot]}")
fi
(( ${#headers[@]} ))||return 0
print -r -- "$Font_B${sfactor[title]}$Font_Suffix"
typeset field_label
[[ "$YY" == "cn" ]]&&field_label="参数"||field_label="Field"
report_table_row "${Font_B}${field_label}${Font_Suffix}" 8 12 "${headers[@]}"
report_table_rule "${#headers[@]}" 8 12
if [[ "$YY" == "cn" ]];then
report_factor_row "地区" 8 12 "${countries[@]}"
report_factor_row "代理" 8 12 "${proxies[@]}"
report_factor_row "VPN" 8 12 "${vpns[@]}"
report_factor_row "Tor" 8 12 "${tors[@]}"
report_factor_row "机房" 8 12 "${servers[@]}"
report_factor_row "滥用" 8 12 "${abusers[@]}"
report_factor_row "机器人" 8 12 "${robots[@]}"
else
report_factor_row "Region" 8 12 "${countries[@]}"
report_factor_row "Proxy" 8 12 "${proxies[@]}"
report_factor_row "VPN" 8 12 "${vpns[@]}"
report_factor_row "Tor" 8 12 "${tors[@]}"
report_factor_row "Hosting" 8 12 "${servers[@]}"
report_factor_row "Abuse" 8 12 "${abusers[@]}"
report_factor_row "Bot" 8 12 "${robots[@]}"
fi
}

show_network_context(){
typeset -a observations
typeset displayed_prefix="${ripestat[prefix]}"
if [[ ${fullIP:-0} -ne 1 && -n "$displayed_prefix" ]];then
displayed_prefix=$(mask_network_prefix "$displayed_prefix")||displayed_prefix=""
fi

if [[ "${ping0[status]}" == "verified" && "${ping0[match]}" == "true" ]];then
if [[ "$YY" == "cn" ]];then
observations+=("${Font_Cyan}Ping0：${Font_Green}已核对${Font_Suffix} | 位置=${ping0[location]} | 网络=${ping0[asn]} · ${ping0[org]}")
else
observations+=("${Font_Cyan}Ping0: ${Font_Green}verified${Font_Suffix} | location=${ping0[location]} | network=${ping0[asn]} · ${ping0[org]}")
fi
elif [[ "${ping0[status]}" == "ip_mismatch" ]];then
if [[ "$YY" == "cn" ]];then
observations+=("${Font_Cyan}Ping0：${Font_Red}${sping0[mismatch]}${Font_Suffix}")
else
observations+=("${Font_Cyan}Ping0: ${Font_Red}${sping0[mismatch]}${Font_Suffix}")
fi
fi

if report_any_known "${ripestat[status]}" "${ripestat[prefix]}" "${ripestat[origins]}";then
if [[ "$YY" == "cn" ]];then
observations+=("${Font_Cyan}RIPEstat：${Font_Suffix}状态=$(report_neutral_or_dash "${ripestat[status]}") | 前缀=$(report_neutral_or_dash "$displayed_prefix") | 起源=$(report_neutral_or_dash "${ripestat[origins]}")")
else
observations+=("${Font_Cyan}RIPEstat: ${Font_Suffix}status=$(report_neutral_or_dash "${ripestat[status]}") | prefix=$(report_neutral_or_dash "$displayed_prefix") | origin=$(report_neutral_or_dash "${ripestat[origins]}")")
fi
fi

if report_any_known "${internetdb[ports]}" "${internetdb[port_count]}" "${internetdb[hostname_count]}" "${internetdb[vulnerability_count]}" "${internetdb[tags]}";then
if [[ "$YY" == "cn" ]];then
observations+=("${Font_Cyan}Shodan：${Font_Suffix}端口=$(report_neutral_or_dash "${internetdb[ports]}")（数量 $(report_neutral_or_dash "${internetdb[port_count]}")） | 主机名数量=$(report_neutral_or_dash "${internetdb[hostname_count]}") | 已知漏洞=$(report_neutral_or_dash "${internetdb[vulnerability_count]}") | 标签=$(report_neutral_or_dash "${internetdb[tags]}")")
else
observations+=("${Font_Cyan}Shodan: ${Font_Suffix}ports=$(report_neutral_or_dash "${internetdb[ports]}") (count $(report_neutral_or_dash "${internetdb[port_count]}")) | hostnames=$(report_neutral_or_dash "${internetdb[hostname_count]}") | known vulnerabilities=$(report_neutral_or_dash "${internetdb[vulnerability_count]}") | tags=$(report_neutral_or_dash "${internetdb[tags]}")")
fi
elif [[ "${internetdb[status]}" == "not_found" ]];then
if [[ "$YY" == "cn" ]];then
observations+=("${Font_Cyan}Shodan：${Font_Purple}无公开记录（不等于无风险）${Font_Suffix}")
else
observations+=("${Font_Cyan}Shodan: ${Font_Purple}no public record (not a clean result)${Font_Suffix}")
fi
fi

(( ${#observations[@]} ))||return 0
if [[ "$YY" == "cn" ]];then
print -r -- "${Font_B}五、官方网络观测（地理、路由与暴露面，不是综合风险分数）${Font_Suffix}"
else
print -r -- "${Font_B}5. Official network observations (geo, routing, and exposure; not a composite risk score)${Font_Suffix}"
fi
typeset observation
for observation in "${observations[@]}";do
print -r -- "$observation"
done
}

show_unavailable_sources(){
typeset -a missing relay_http_403
if ! report_any_known "${maxmind[asn]}" "${maxmind[countrycode]}" "${maxmind[city]}";then
[[ "${maxmind[status]}" == "http_403" ]]&&relay_http_403+=("MaxMind")||missing+=("Check.Place/MaxMind")
fi
report_any_known "${ipinfo[susetype]}" "${ipinfo[scomtype]}" "${ipinfo[countrycode]}" "${ipinfo[proxy]}" "${ipinfo[vpn]}" "${ipinfo[tor]}" "${ipinfo[server]}"||missing+=("IPinfo")
if [[ "${ipregistry[status]}" != "not_configured" ]] &&
   ! report_any_known "${ipregistry[susetype]}" "${ipregistry[scomtype]}" "${ipregistry[countrycode]}" "${ipregistry[proxy]}" "${ipregistry[vpn]}" "${ipregistry[tor]}" "${ipregistry[server]}" "${ipregistry[abuser]}";then
missing+=("Ipregistry")
fi
report_any_known "${ipapi[susetype]}" "${ipapi[scomtype]}" "${ipapi[score]}" "${ipapi[countrycode]}" "${ipapi[proxy]}" "${ipapi[vpn]}" "${ipapi[tor]}" "${ipapi[server]}" "${ipapi[abuser]}" "${ipapi[robot]}"||missing+=("ipapi.is")
if ! report_any_known "${ip2location[susetype]}" "${ip2location[scomtype]}" "${ip2location[score]}" "${ip2location[countrycode]}" "${ip2location[proxy]}" "${ip2location[vpn]}" "${ip2location[tor]}" "${ip2location[server]}" "${ip2location[abuser]}" "${ip2location[robot]}";then
[[ "${ip2location[status]}" == "http_403" ]]&&relay_http_403+=("IP2Location")||missing+=("IP2Location")
fi
if ! report_any_known "${abuseipdb[susetype]}" "${abuseipdb[score]}";then
[[ "${abuseipdb[status]}" == "http_403" ]]&&relay_http_403+=("AbuseIPDB")||missing+=("AbuseIPDB")
fi
if ! report_any_known "${scamalytics[score]}" "${scamalytics[countrycode]}" "${scamalytics[proxy]}" "${scamalytics[vpn]}" "${scamalytics[tor]}" "${scamalytics[server]}" "${scamalytics[abuser]}" "${scamalytics[robot]}";then
[[ "${scamalytics[status]}" == "http_403" ]]&&relay_http_403+=("Scamalytics")||missing+=("Scamalytics")
fi
if ! report_any_known "${ipdata[countrycode]}" "${ipdata[proxy]}" "${ipdata[tor]}" "${ipdata[server]}" "${ipdata[abuser]}";then
[[ "${ipdata[status]}" == "http_403" ]]&&relay_http_403+=("ipdata")||missing+=("ipdata")
fi
case "$YY:${ping0[status]}" in
cn:not_applicable_target)missing+=("Ping0（/geo 仅核对当前出口，指定目标时跳过）")
;;
en:not_applicable_target)missing+=("Ping0 (/geo verifies the current egress only; skipped for explicit targets)")
;;
*:verified|*:ip_mismatch) ;;
*)missing+=("Ping0")
esac
report_any_known "${ripestat[status]}" "${ripestat[prefix]}" "${ripestat[origins]}"||missing+=("RIPEstat")
if [[ "${internetdb[status]}" != "not_found" ]] &&
   ! report_any_known "${internetdb[ports]}" "${internetdb[port_count]}" "${internetdb[hostname_count]}" "${internetdb[vulnerability_count]}" "${internetdb[tags]}";then
missing+=("Shodan InternetDB")
fi
if (( ${#relay_http_403[@]} ));then
if [[ "$YY" == "cn" ]];then
missing+=("Check.Place 中继 HTTP 403（${(j:、:)relay_http_403[@]}）")
else
missing+=("Check.Place relay HTTP 403 (${(j:, :)relay_http_403[@]})")
fi
fi
(( ${#missing[@]} ))||return 0
if [[ "$YY" == "cn" ]];then
print -r -- "${Font_Purple}本次无可用资料（不等于低风险）：${(j:、:)missing[@]}${Font_Suffix}"
else
print -r -- "${Font_Purple}No usable data this run (not a clean result): ${(j:, :)missing[@]}${Font_Suffix}"
fi
}
