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
print -rn -- "${Font_Purple:-}—${Font_Suffix:-}"
}

report_neutral_value(){
if report_is_unknown "$1";then
report_unknown
else
print -rn -- "$Font_Cyan$(clean_ansi "$1")$Font_Suffix"
fi
}

report_preserved_value(){
if report_is_unknown "$1";then
report_unknown
elif [[ "$1" == *$'\033['* ]];then
print -rn -- "$1"
else
print -rn -- "$Font_Cyan$(clean_ansi "$1")$Font_Suffix"
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
en:ipinfo)print -rn -- "public demo widget"
;;
en:direct)print -rn -- "direct public API"
;;
*)print -rn -- "upstream relay"
esac
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
[[ $padding -lt 1 ]]&&padding=1
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
typeset -a headers scores risks scales
if report_any_known "${ip2location[score]}" "${ip2location[risk]}";then
headers+=("${Font_B}${Font_Cyan}IP2Location$Font_Suffix")
scores+=("${ip2location[score]}") risks+=("${ip2location[risk]}") scales+=("0-99 potential")
fi
if report_any_known "${scamalytics[score]}" "${scamalytics[risk]}";then
headers+=("${Font_B}${Font_Cyan}Scamalytics$Font_Suffix")
scores+=("${scamalytics[score]}") risks+=("${scamalytics[risk]}") scales+=("0-100 fraud")
fi
if report_any_known "${ipapi[score]}" "${ipapi[risk]}";then
headers+=("${Font_B}${Font_Cyan}ipapi.is$Font_Suffix")
scores+=("${ipapi[score]}") risks+=("${ipapi[risk]}") scales+=("0-100% abuse")
fi
if report_any_known "${abuseipdb[score]}" "${abuseipdb[risk]}";then
headers+=("${Font_B}${Font_Cyan}AbuseIPDB$Font_Suffix")
scores+=("${abuseipdb[score]}") risks+=("${abuseipdb[risk]}") scales+=("0-100 confidence")
fi
if report_any_known "${ipqs[score]}" "${ipqs[risk]}";then
headers+=("${Font_B}${Font_Cyan}IPQualityScore$Font_Suffix")
scores+=("${ipqs[score]}") risks+=("${ipqs[risk]}") scales+=("0-100 fraud")
fi
(( ${#headers[@]} ))||return 0
print -r -- "$Font_B${sscore[title]}$Font_Suffix"
typeset value
typeset -a rendered_scores rendered_risks rendered_scales
for value in "${scores[@]}";do rendered_scores+=("$(report_neutral_or_dash "$value")");done
for value in "${risks[@]}";do rendered_risks+=("$(report_preserved_or_dash "$value")");done
for value in "${scales[@]}";do rendered_scales+=("$(report_neutral_value "$value")");done
typeset field_label score_label band_label scale_label note
if [[ "$YY" == "cn" ]];then
field_label="参数" score_label="分值" band_label="分段／标签" scale_label="量表"
note="注：各平台量表不同；— 表示该来源本次未提供。"
else
field_label="Field" score_label="Score" band_label="Band / label" scale_label="Scale"
note="Note: provider scales differ; — means that source did not supply the field."
fi
print -r -- "$note"
report_table_row "${Font_B}${field_label}${Font_Suffix}" 10 16 "${headers[@]}"
report_table_rule "${#headers[@]}" 10 16
report_table_row "$score_label" 10 16 "${rendered_scores[@]}"
report_any_known "${risks[@]}"&&report_table_row "$band_label" 10 16 "${rendered_risks[@]}"
report_table_row "$scale_label" 10 16 "${rendered_scales[@]}"
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

show_ping0(){
if [[ "${ping0[status]}" == "verified" && "${ping0[match]}" == "true" ]];then
if [[ "$YY" == "cn" ]];then
print -r -- "$Font_B${sping0[title]}（公开端点不含风险分数）$Font_Suffix"
print -r -- "${Font_Cyan}状态：${Font_Green}${sping0[match]}$Font_Suffix"
print -r -- "${Font_Cyan}位置：$Font_Suffix${ping0[location]} | ${Font_Cyan}网络：$Font_Suffix${ping0[asn]} · ${ping0[org]}"
else
print -r -- "$Font_B${sping0[title]} (public endpoint has no risk score)$Font_Suffix"
print -r -- "${Font_Cyan}Status: ${Font_Green}${sping0[match]}$Font_Suffix"
print -r -- "${Font_Cyan}Location: $Font_Suffix${ping0[location]} | ${Font_Cyan}Network: $Font_Suffix${ping0[asn]} · ${ping0[org]}"
fi
elif [[ "${ping0[status]}" == "ip_mismatch" ]];then
print -r -- "$Font_B${sping0[title]}$Font_Suffix"
[[ "$YY" == "cn" ]]&&print -r -- "${Font_Cyan}状态：$Font_Red${sping0[mismatch]}$Font_Suffix"||print -r -- "${Font_Cyan}Status: $Font_Red${sping0[mismatch]}$Font_Suffix"
fi
}

show_routing(){
report_any_known "${ripestat[status]}" "${ripestat[prefix]}" "${ripestat[origins]}"||return 0
typeset displayed_prefix="${ripestat[prefix]}"
if [[ ${fullIP:-0} -ne 1 && -n "$displayed_prefix" ]];then
displayed_prefix=$(mask_network_prefix "$displayed_prefix")||displayed_prefix=""
fi
if [[ "$YY" == "cn" ]];then
print -r -- "${Font_B}官方路由观测（RIPEstat / RIPE RIS）${Font_Suffix}"
print -r -- "${Font_Cyan}状态：${Font_Suffix}$(report_neutral_or_dash "${ripestat[status]}") | ${Font_Cyan}前缀：${Font_Suffix}$(report_neutral_or_dash "$displayed_prefix") | ${Font_Cyan}起源：${Font_Suffix}$(report_neutral_or_dash "${ripestat[origins]}")"
else
print -r -- "${Font_B}Official routing observation (RIPEstat / RIPE RIS)${Font_Suffix}"
print -r -- "${Font_Cyan}Status: ${Font_Suffix}$(report_neutral_or_dash "${ripestat[status]}") | ${Font_Cyan}Prefix: ${Font_Suffix}$(report_neutral_or_dash "$displayed_prefix") | ${Font_Cyan}Origin: ${Font_Suffix}$(report_neutral_or_dash "${ripestat[origins]}")"
fi
}

show_exposure(){
report_any_known "${internetdb[ports]}" "${internetdb[port_count]}" "${internetdb[vulnerability_count]}" "${internetdb[tags]}"||return 0
if [[ "$YY" == "cn" ]];then
print -r -- "${Font_B}公开暴露面观测（Shodan InternetDB；非风险分数）${Font_Suffix}"
print -r -- "${Font_Cyan}端口：${Font_Suffix}$(report_neutral_or_dash "${internetdb[ports]}")（$(report_neutral_or_dash "${internetdb[port_count]}")） | ${Font_Cyan}漏洞：${Font_Suffix}$(report_neutral_or_dash "${internetdb[vulnerability_count]}") | ${Font_Cyan}标签：${Font_Suffix}$(report_neutral_or_dash "${internetdb[tags]}")"
else
print -r -- "${Font_B}Public exposure observation (Shodan InternetDB; not a risk score)${Font_Suffix}"
print -r -- "${Font_Cyan}Ports: ${Font_Suffix}$(report_neutral_or_dash "${internetdb[ports]}") ($(report_neutral_or_dash "${internetdb[port_count]}") ) | ${Font_Cyan}Vulnerabilities: ${Font_Suffix}$(report_neutral_or_dash "${internetdb[vulnerability_count]}") | ${Font_Cyan}Tags: ${Font_Suffix}$(report_neutral_or_dash "${internetdb[tags]}")"
fi
}

show_unavailable_sources(){
typeset -a missing
report_any_known "${maxmind[asn]}" "${maxmind[countrycode]}" "${maxmind[city]}"||missing+=("Check.Place/MaxMind")
report_any_known "${ipinfo[susetype]}" "${ipinfo[scomtype]}" "${ipinfo[countrycode]}" "${ipinfo[proxy]}" "${ipinfo[vpn]}" "${ipinfo[tor]}" "${ipinfo[server]}"||missing+=("IPinfo")
report_any_known "${ipapi[susetype]}" "${ipapi[scomtype]}" "${ipapi[score]}" "${ipapi[countrycode]}" "${ipapi[proxy]}" "${ipapi[vpn]}" "${ipapi[tor]}" "${ipapi[server]}" "${ipapi[abuser]}" "${ipapi[robot]}"||missing+=("ipapi.is")
report_any_known "${ip2location[susetype]}" "${ip2location[scomtype]}" "${ip2location[score]}" "${ip2location[countrycode]}" "${ip2location[proxy]}" "${ip2location[vpn]}" "${ip2location[tor]}" "${ip2location[server]}" "${ip2location[abuser]}" "${ip2location[robot]}"||missing+=("IP2Location")
report_any_known "${abuseipdb[susetype]}" "${abuseipdb[score]}"||missing+=("AbuseIPDB")
report_any_known "${scamalytics[score]}" "${scamalytics[countrycode]}" "${scamalytics[proxy]}" "${scamalytics[vpn]}" "${scamalytics[tor]}" "${scamalytics[server]}" "${scamalytics[abuser]}" "${scamalytics[robot]}"||missing+=("Scamalytics")
report_any_known "${ipdata[countrycode]}" "${ipdata[proxy]}" "${ipdata[tor]}" "${ipdata[server]}" "${ipdata[abuser]}"||missing+=("ipdata")
if ! report_any_known "${ipqs[score]}" "${ipqs[countrycode]}" "${ipqs[proxy]}" "${ipqs[vpn]}" "${ipqs[tor]}" "${ipqs[server]}" "${ipqs[abuser]}" "${ipqs[robot]}";then
case "$YY:${ipqs[status]}" in
cn:upstream_insufficient_credits)missing+=("IPQualityScore（上游额度不足）")
;;
cn:rate_limited)missing+=("IPQualityScore（上游限流）")
;;
en:upstream_insufficient_credits)missing+=("IPQualityScore (upstream credits exhausted)")
;;
en:rate_limited)missing+=("IPQualityScore (upstream rate limit)")
;;
*)missing+=("IPQualityScore")
esac
fi
[[ "${ping0[status]}" == "verified" || "${ping0[status]}" == "ip_mismatch" ]]||missing+=("Ping0")
report_any_known "${ripestat[status]}" "${ripestat[prefix]}" "${ripestat[origins]}"||missing+=("RIPEstat")
if ! report_any_known "${internetdb[ports]}" "${internetdb[port_count]}" "${internetdb[vulnerability_count]}" "${internetdb[tags]}";then
case "$YY:${internetdb[status]}" in
cn:not_found)missing+=("Shodan InternetDB（无公开记录）")
;;
en:not_found)missing+=("Shodan InternetDB (no public record)")
;;
*)missing+=("Shodan InternetDB")
esac
fi
(( ${#missing[@]} ))||return 0
if [[ "$YY" == "cn" ]];then
print -r -- "${Font_Purple}本次无可用资料（不等于低风险）：${(j:、:)missing[@]}${Font_Suffix}"
else
print -r -- "${Font_Purple}No usable data this run (not a clean result): ${(j:, :)missing[@]}${Font_Suffix}"
fi
}
