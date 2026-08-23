# Terminal rendering for reputation observations. Providers are columns and
# source-specific dimensions are rows; score scales are never collapsed.

report_unknown_label(){
[[ "$YY" == "cn" ]]&&print -rn -- "未知"||print -rn -- "Unknown"
}

report_is_unknown(){
typeset value
value=$(clean_ansi "$1")
[[ -z "$value" || "$value" == "null" ]]
}

report_unknown(){
print -rn -- "$Font_Purple$(report_unknown_label)$Font_Suffix"
}

report_plain(){
typeset value
value=$(clean_ansi "$1")
if report_is_unknown "$value";then
report_unknown
else
print -rn -- "$value"
fi
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

show_type(){
print -r -- "$Font_B${stype[title]}$Font_Suffix"
if [[ "$YY" == "cn" ]];then
print -r -- "每个平台仅显示其实际提供的分类；未提供的字段保持未知。"
report_table_row "${Font_B}参数${Font_Suffix}" 12 23 "$Font_B$Font_Cyan IPinfo$Font_Suffix" "$Font_B$Font_Cyan ipapi.is$Font_Suffix" "$Font_B$Font_Cyan IP2Location$Font_Suffix" "$Font_B$Font_Cyan AbuseIPDB$Font_Suffix"
report_table_rule 4 12 23
report_table_row "来源" 12 23 "$(report_neutral_value '直接公开端点')" "$(report_neutral_value '直接公开端点')" "$(report_neutral_value '上游中继')" "$(report_neutral_value '上游中继')"
report_table_row "使用类型" 12 23 "$(report_preserved_value "${ipinfo[susetype]}")" "$(report_preserved_value "${ipapi[susetype]}")" "$(report_preserved_value "${ip2location[susetype]}")" "$(report_preserved_value "${abuseipdb[susetype]}")"
report_table_row "公司类型" 12 23 "$(report_preserved_value "${ipinfo[scomtype]}")" "$(report_preserved_value "${ipapi[scomtype]}")" "$(report_preserved_value "${ip2location[scomtype]}")" "$(report_unknown)"
else
print -r -- "Each provider column contains only classifications that source returned; unavailable fields stay Unknown."
report_table_row "${Font_B}Field${Font_Suffix}" 12 23 "$Font_B$Font_Cyan IPinfo$Font_Suffix" "$Font_B$Font_Cyan ipapi.is$Font_Suffix" "$Font_B$Font_Cyan IP2Location$Font_Suffix" "$Font_B$Font_Cyan AbuseIPDB$Font_Suffix"
report_table_rule 4 12 23
report_table_row "Source" 12 23 "$(report_neutral_value 'direct public endpoint')" "$(report_neutral_value 'direct public endpoint')" "$(report_neutral_value 'upstream relay')" "$(report_neutral_value 'upstream relay')"
report_table_row "Usage type" 12 23 "$(report_preserved_value "${ipinfo[susetype]}")" "$(report_preserved_value "${ipapi[susetype]}")" "$(report_preserved_value "${ip2location[susetype]}")" "$(report_preserved_value "${abuseipdb[susetype]}")"
report_table_row "Company type" 12 23 "$(report_preserved_value "${ipinfo[scomtype]}")" "$(report_preserved_value "${ipapi[scomtype]}")" "$(report_preserved_value "${ip2location[scomtype]}")" "$(report_unknown)"
fi
}

show_score(){
print -r -- "$Font_B${sscore[title]}$Font_Suffix"
if [[ "$YY" == "cn" ]];then
print -r -- "不同平台的分值定义不可直接横向比较；分段可能来自平台标签或本地阈值；未知不等于低风险。"
report_table_row "${Font_B}参数${Font_Suffix}" 12 18 "$Font_B$Font_Cyan IP2Location$Font_Suffix" "$Font_B$Font_Cyan Scamalytics$Font_Suffix" "$Font_B$Font_Cyan ipapi.is$Font_Suffix" "$Font_B$Font_Cyan AbuseIPDB$Font_Suffix" "$Font_B$Font_Cyan IPQualityScore$Font_Suffix"
report_table_rule 5 12 18
report_table_row "分值" 12 18 "$(report_neutral_value "${ip2location[score]}")" "$(report_neutral_value "${scamalytics[score]}")" "$(report_neutral_value "${ipapi[score]}")" "$(report_neutral_value "${abuseipdb[score]}")" "$(report_neutral_value "${ipqs[score]}")"
report_table_row "分段／标签" 12 18 "$(report_preserved_value "${ip2location[risk]}")" "$(report_preserved_value "${scamalytics[risk]}")" "$(report_preserved_value "${ipapi[risk]}")" "$(report_preserved_value "${abuseipdb[risk]}")" "$(report_preserved_value "${ipqs[risk]}")"
report_table_row "量表" 12 18 "$(report_neutral_value '0-100 fraud')" "$(report_neutral_value '0-100 fraud')" "$(report_neutral_value '0-100% abuse')" "$(report_neutral_value '0-100 confidence')" "$(report_neutral_value '0-100 fraud')"
else
print -r -- "Provider scores are not directly comparable; bands may be provider labels or local thresholds; Unknown never means low risk."
report_table_row "${Font_B}Field${Font_Suffix}" 12 18 "$Font_B$Font_Cyan IP2Location$Font_Suffix" "$Font_B$Font_Cyan Scamalytics$Font_Suffix" "$Font_B$Font_Cyan ipapi.is$Font_Suffix" "$Font_B$Font_Cyan AbuseIPDB$Font_Suffix" "$Font_B$Font_Cyan IPQualityScore$Font_Suffix"
report_table_rule 5 12 18
report_table_row "Score" 12 18 "$(report_neutral_value "${ip2location[score]}")" "$(report_neutral_value "${scamalytics[score]}")" "$(report_neutral_value "${ipapi[score]}")" "$(report_neutral_value "${abuseipdb[score]}")" "$(report_neutral_value "${ipqs[score]}")"
report_table_row "Band / label" 12 18 "$(report_preserved_value "${ip2location[risk]}")" "$(report_preserved_value "${scamalytics[risk]}")" "$(report_preserved_value "${ipapi[risk]}")" "$(report_preserved_value "${abuseipdb[risk]}")" "$(report_preserved_value "${ipqs[risk]}")"
report_table_row "Scale" 12 18 "$(report_neutral_value '0-100 fraud')" "$(report_neutral_value '0-100 fraud')" "$(report_neutral_value '0-100% abuse')" "$(report_neutral_value '0-100 confidence')" "$(report_neutral_value '0-100 fraud')"
fi
}

show_factor(){
print -r -- "$Font_B${sfactor[title]}$Font_Suffix"
typeset field_label
[[ "$YY" == "cn" ]]&&field_label="参数"||field_label="Field"
report_table_row "${Font_B}${field_label}${Font_Suffix}" 10 14 "$Font_B$Font_Cyan IP2Location$Font_Suffix" "$Font_B$Font_Cyan ipapi.is$Font_Suffix" "$Font_B$Font_Cyan IPQualityScore$Font_Suffix" "$Font_B$Font_Cyan Scamalytics$Font_Suffix" "$Font_B$Font_Cyan ipdata$Font_Suffix" "$Font_B$Font_Cyan IPinfo$Font_Suffix"
report_table_rule 6 10 14
if [[ "$YY" == "cn" ]];then
report_table_row "地区" 10 14 "$(report_factor_value "${ip2location[countrycode]}")" "$(report_factor_value "${ipapi[countrycode]}")" "$(report_factor_value "${ipqs[countrycode]}")" "$(report_factor_value "${scamalytics[countrycode]}")" "$(report_factor_value "${ipdata[countrycode]}")" "$(report_factor_value "${ipinfo[countrycode]}")"
report_table_row "代理" 10 14 "$(report_factor_value "${ip2location[proxy]}")" "$(report_factor_value "${ipapi[proxy]}")" "$(report_factor_value "${ipqs[proxy]}")" "$(report_factor_value "${scamalytics[proxy]}")" "$(report_factor_value "${ipdata[proxy]}")" "$(report_factor_value "${ipinfo[proxy]}")"
report_table_row "VPN" 10 14 "$(report_factor_value "${ip2location[vpn]}")" "$(report_factor_value "${ipapi[vpn]}")" "$(report_factor_value "${ipqs[vpn]}")" "$(report_factor_value "${scamalytics[vpn]}")" "$(report_factor_value "${ipdata[vpn]}")" "$(report_factor_value "${ipinfo[vpn]}")"
report_table_row "Tor" 10 14 "$(report_factor_value "${ip2location[tor]}")" "$(report_factor_value "${ipapi[tor]}")" "$(report_factor_value "${ipqs[tor]}")" "$(report_factor_value "${scamalytics[tor]}")" "$(report_factor_value "${ipdata[tor]}")" "$(report_factor_value "${ipinfo[tor]}")"
report_table_row "机房" 10 14 "$(report_factor_value "${ip2location[server]}")" "$(report_factor_value "${ipapi[server]}")" "$(report_factor_value "${ipqs[server]}")" "$(report_factor_value "${scamalytics[server]}")" "$(report_factor_value "${ipdata[server]}")" "$(report_factor_value "${ipinfo[server]}")"
report_table_row "滥用" 10 14 "$(report_factor_value "${ip2location[abuser]}")" "$(report_factor_value "${ipapi[abuser]}")" "$(report_factor_value "${ipqs[abuser]}")" "$(report_factor_value "${scamalytics[abuser]}")" "$(report_factor_value "${ipdata[abuser]}")" "$(report_factor_value "${ipinfo[abuser]}")"
report_table_row "机器人" 10 14 "$(report_factor_value "${ip2location[robot]}")" "$(report_factor_value "${ipapi[robot]}")" "$(report_factor_value "${ipqs[robot]}")" "$(report_factor_value "${scamalytics[robot]}")" "$(report_factor_value "${ipdata[robot]}")" "$(report_factor_value "${ipinfo[robot]}")"
else
report_table_row "Region" 10 14 "$(report_factor_value "${ip2location[countrycode]}")" "$(report_factor_value "${ipapi[countrycode]}")" "$(report_factor_value "${ipqs[countrycode]}")" "$(report_factor_value "${scamalytics[countrycode]}")" "$(report_factor_value "${ipdata[countrycode]}")" "$(report_factor_value "${ipinfo[countrycode]}")"
report_table_row "Proxy" 10 14 "$(report_factor_value "${ip2location[proxy]}")" "$(report_factor_value "${ipapi[proxy]}")" "$(report_factor_value "${ipqs[proxy]}")" "$(report_factor_value "${scamalytics[proxy]}")" "$(report_factor_value "${ipdata[proxy]}")" "$(report_factor_value "${ipinfo[proxy]}")"
report_table_row "VPN" 10 14 "$(report_factor_value "${ip2location[vpn]}")" "$(report_factor_value "${ipapi[vpn]}")" "$(report_factor_value "${ipqs[vpn]}")" "$(report_factor_value "${scamalytics[vpn]}")" "$(report_factor_value "${ipdata[vpn]}")" "$(report_factor_value "${ipinfo[vpn]}")"
report_table_row "Tor" 10 14 "$(report_factor_value "${ip2location[tor]}")" "$(report_factor_value "${ipapi[tor]}")" "$(report_factor_value "${ipqs[tor]}")" "$(report_factor_value "${scamalytics[tor]}")" "$(report_factor_value "${ipdata[tor]}")" "$(report_factor_value "${ipinfo[tor]}")"
report_table_row "Hosting" 10 14 "$(report_factor_value "${ip2location[server]}")" "$(report_factor_value "${ipapi[server]}")" "$(report_factor_value "${ipqs[server]}")" "$(report_factor_value "${scamalytics[server]}")" "$(report_factor_value "${ipdata[server]}")" "$(report_factor_value "${ipinfo[server]}")"
report_table_row "Abuse" 10 14 "$(report_factor_value "${ip2location[abuser]}")" "$(report_factor_value "${ipapi[abuser]}")" "$(report_factor_value "${ipqs[abuser]}")" "$(report_factor_value "${scamalytics[abuser]}")" "$(report_factor_value "${ipdata[abuser]}")" "$(report_factor_value "${ipinfo[abuser]}")"
report_table_row "Bot" 10 14 "$(report_factor_value "${ip2location[robot]}")" "$(report_factor_value "${ipapi[robot]}")" "$(report_factor_value "${ipqs[robot]}")" "$(report_factor_value "${scamalytics[robot]}")" "$(report_factor_value "${ipdata[robot]}")" "$(report_factor_value "${ipinfo[robot]}")"
fi
}

show_ping0(){
print -r -- "$Font_B${sping0[title]}$Font_Suffix"
if [[ "${ping0[status]}" == "verified" && "${ping0[match]}" == "true" ]];then
print -r -- "$Font_Cyan${sping0[status]}$Font_Green${sping0[match]}$Font_Suffix"
print -r -- "$Font_Cyan${sping0[location]}$Font_Suffix${ping0[location]}"
print -r -- "$Font_Cyan${sping0[asn]}$Font_Suffix${ping0[asn]}"
print -r -- "$Font_Cyan${sping0[org]}$Font_Suffix${ping0[org]}"
elif [[ "${ping0[status]}" == "ip_mismatch" ]];then
print -r -- "$Font_Cyan${sping0[status]}$Font_Red${sping0[mismatch]}$Font_Suffix"
else
print -r -- "$Font_Cyan${sping0[status]}$Font_Purple${sping0[unknown]}$Font_Suffix"
fi
print -r -- "$Font_Cyan${sping0[risk]}$Font_Purple${sping0[unknown]}$Font_Suffix (${sping0[norisk]})"
}

show_routing(){
if [[ "$YY" == "cn" ]];then
print -r -- "${Font_B}官方路由观测（RIPEstat / RIPE RIS）${Font_Suffix}"
print -r -- "${Font_Cyan}状态：${Font_Suffix}$(report_plain "${ripestat[status]}")"
print -r -- "${Font_Cyan}路由前缀：${Font_Suffix}$(report_plain "${ripestat[prefix]}")"
print -r -- "${Font_Cyan}起源 ASN：${Font_Suffix}$(report_plain "${ripestat[origins]}")"
else
print -r -- "${Font_B}Official routing observation (RIPEstat / RIPE RIS)${Font_Suffix}"
print -r -- "${Font_Cyan}Status: ${Font_Suffix}$(report_plain "${ripestat[status]}")"
print -r -- "${Font_Cyan}Routed prefix: ${Font_Suffix}$(report_plain "${ripestat[prefix]}")"
print -r -- "${Font_Cyan}Origin ASN: ${Font_Suffix}$(report_plain "${ripestat[origins]}")"
fi
}

show_exposure(){
if [[ "$YY" == "cn" ]];then
print -r -- "${Font_B}公开暴露面观测（Shodan InternetDB；非风险分数）${Font_Suffix}"
print -r -- "${Font_Cyan}状态：${Font_Suffix}$(report_plain "${internetdb[status]}")"
print -r -- "${Font_Cyan}端口：${Font_Suffix}$(report_plain "${internetdb[ports]}")（数量 $(report_plain "${internetdb[port_count]}")）"
print -r -- "${Font_Cyan}已知漏洞数量：${Font_Suffix}$(report_plain "${internetdb[vulnerability_count]}")"
print -r -- "${Font_Cyan}标签：${Font_Suffix}$(report_plain "${internetdb[tags]}")"
else
print -r -- "${Font_B}Public exposure observation (Shodan InternetDB; not a risk score)${Font_Suffix}"
print -r -- "${Font_Cyan}Status: ${Font_Suffix}$(report_plain "${internetdb[status]}")"
print -r -- "${Font_Cyan}Ports: ${Font_Suffix}$(report_plain "${internetdb[ports]}") (count $(report_plain "${internetdb[port_count]}") )"
print -r -- "${Font_Cyan}Known-vulnerability count: ${Font_Suffix}$(report_plain "${internetdb[vulnerability_count]}")"
print -r -- "${Font_Cyan}Tags: ${Font_Suffix}$(report_plain "${internetdb[tags]}")"
fi
}
