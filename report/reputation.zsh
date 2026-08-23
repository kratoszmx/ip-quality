# Terminal rendering for reputation observations. Each provider gets its own
# row because score scales and available dimensions are not interchangeable.

report_unknown(){
[[ "$YY" == "cn" ]]&&print -rn -- "未知"||print -rn -- "Unknown"
}

report_plain(){
typeset value
value=$(clean_ansi "$1")
if [[ -z "$value" || "$value" == "null" ]];then
report_unknown
else
print -rn -- "$value"
fi
}

report_factor_value(){
case "$1" in
true) [[ "$YY" == "cn" ]]&&print -rn -- "是"||print -rn -- "Yes"
;;
false) [[ "$YY" == "cn" ]]&&print -rn -- "否"||print -rn -- "No"
;;
??) print -rn -- "$1"
;;
*) report_unknown
esac
}

report_type_row(){
typeset provider="$1"
typeset access="$2"
typeset usage company
usage=$(report_plain "$3")
company=$(report_plain "$4")
if [[ "$YY" == "cn" ]];then
printf '\r%s%-18s%s 来源=%s | 使用类型=%s | 公司类型=%s%s\n' "$Font_Cyan" "$provider" "$Font_Suffix" "$access" "$usage" "$company" "$Font_Suffix"
else
printf '\r%s%-18s%s source=%s | usage=%s | company=%s%s\n' "$Font_Cyan" "$provider" "$Font_Suffix" "$access" "$usage" "$company" "$Font_Suffix"
fi
}

show_type(){
print -r -- "${stype[title]}"
if [[ "$YY" == "cn" ]];then
print -r -- "每个平台仅显示其实际提供的分类；未提供的字段保持未知。"
report_type_row "IPinfo" "直接公开端点" "${ipinfo[susetype]}" "${ipinfo[scomtype]}"
report_type_row "ipapi.is" "直接公开端点" "${ipapi[susetype]}" "${ipapi[scomtype]}"
report_type_row "IP2Location" "上游中继" "${ip2location[susetype]}" "${ip2location[scomtype]}"
report_type_row "AbuseIPDB" "上游中继" "${abuseipdb[susetype]}" ""
else
print -r -- "Each row shows only classifications actually returned by that provider; unavailable fields stay Unknown."
report_type_row "IPinfo" "direct public" "${ipinfo[susetype]}" "${ipinfo[scomtype]}"
report_type_row "ipapi.is" "direct public" "${ipapi[susetype]}" "${ipapi[scomtype]}"
report_type_row "IP2Location" "upstream relay" "${ip2location[susetype]}" "${ip2location[scomtype]}"
report_type_row "AbuseIPDB" "upstream relay" "${abuseipdb[susetype]}" ""
fi
}

report_score_row(){
typeset provider="$1"
typeset score risk scale
score=$(report_plain "$2")
risk=$(report_plain "$3")
scale="$4"
if [[ "$YY" == "cn" ]];then
printf '\r%s%-18s%s 分值=%s | 分段/标签=%s | 量表=%s\n' "$Font_Cyan" "$provider" "$Font_Suffix" "$score" "$risk" "$scale"
else
printf '\r%s%-18s%s score=%s | band/label=%s | scale=%s\n' "$Font_Cyan" "$provider" "$Font_Suffix" "$score" "$risk" "$scale"
fi
}

show_score(){
print -r -- "${sscore[title]}"
if [[ "$YY" == "cn" ]];then
print -r -- "不同平台的分值定义不可直接横向比较；分段可能来自平台标签或本地阈值；未知不等于低风险。"
else
print -r -- "Provider scores are not directly comparable; bands may be provider labels or local thresholds; Unknown never means low risk."
fi
report_score_row "IP2Location" "${ip2location[score]}" "${ip2location[risk]}" "0-100 fraud"
report_score_row "Scamalytics" "${scamalytics[score]}" "${scamalytics[risk]}" "0-100 fraud"
report_score_row "ipapi.is" "${ipapi[score]}" "${ipapi[risk]}" "0-100% abuse"
report_score_row "AbuseIPDB" "${abuseipdb[score]}" "${abuseipdb[risk]}" "0-100 confidence"
report_score_row "IPQualityScore" "${ipqs[score]}" "${ipqs[risk]}" "0-100 fraud"
}

report_factor_row(){
typeset provider="$1"
typeset region proxy vpn tor server abuse bot
region=$(report_factor_value "$2")
proxy=$(report_factor_value "$3")
vpn=$(report_factor_value "$4")
tor=$(report_factor_value "$5")
server=$(report_factor_value "$6")
abuse=$(report_factor_value "$7")
bot=$(report_factor_value "$8")
if [[ "$YY" == "cn" ]];then
printf '\r%s%-18s%s 地区=%s | 代理=%s | VPN=%s | Tor=%s | 机房=%s | 滥用=%s | 机器人=%s\n' "$Font_Cyan" "$provider" "$Font_Suffix" "$region" "$proxy" "$vpn" "$tor" "$server" "$abuse" "$bot"
else
printf '\r%s%-18s%s region=%s | proxy=%s | VPN=%s | Tor=%s | hosting=%s | abuse=%s | bot=%s\n' "$Font_Cyan" "$provider" "$Font_Suffix" "$region" "$proxy" "$vpn" "$tor" "$server" "$abuse" "$bot"
fi
}

show_factor(){
print -r -- "${sfactor[title]}"
report_factor_row "IP2Location" "${ip2location[countrycode]}" "${ip2location[proxy]}" "${ip2location[vpn]}" "${ip2location[tor]}" "${ip2location[server]}" "${ip2location[abuser]}" "${ip2location[robot]}"
report_factor_row "ipapi.is" "${ipapi[countrycode]}" "${ipapi[proxy]}" "${ipapi[vpn]}" "${ipapi[tor]}" "${ipapi[server]}" "${ipapi[abuser]}" "${ipapi[robot]}"
report_factor_row "IPQualityScore" "${ipqs[countrycode]}" "${ipqs[proxy]}" "${ipqs[vpn]}" "${ipqs[tor]}" "${ipqs[server]}" "${ipqs[abuser]}" "${ipqs[robot]}"
report_factor_row "Scamalytics" "${scamalytics[countrycode]}" "${scamalytics[proxy]}" "${scamalytics[vpn]}" "${scamalytics[tor]}" "${scamalytics[server]}" "${scamalytics[abuser]}" "${scamalytics[robot]}"
report_factor_row "ipdata" "${ipdata[countrycode]}" "${ipdata[proxy]}" "${ipdata[vpn]}" "${ipdata[tor]}" "${ipdata[server]}" "${ipdata[abuser]}" "${ipdata[robot]}"
report_factor_row "IPinfo" "${ipinfo[countrycode]}" "${ipinfo[proxy]}" "${ipinfo[vpn]}" "${ipinfo[tor]}" "${ipinfo[server]}" "${ipinfo[abuser]}" "${ipinfo[robot]}"
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
print -r -- "$Font_B官方路由观测（RIPEstat / RIPE RIS）$Font_Suffix"
print -r -- "$Font_Cyan状态：$Font_Suffix$(report_plain "${ripestat[status]}")"
print -r -- "$Font_Cyan路由前缀：$Font_Suffix$(report_plain "${ripestat[prefix]}")"
print -r -- "$Font_Cyan起源 ASN：$Font_Suffix$(report_plain "${ripestat[origins]}")"
else
print -r -- "$Font_BOfficial routing observation (RIPEstat / RIPE RIS)$Font_Suffix"
print -r -- "$Font_CyanStatus: $Font_Suffix$(report_plain "${ripestat[status]}")"
print -r -- "$Font_CyanRouted prefix: $Font_Suffix$(report_plain "${ripestat[prefix]}")"
print -r -- "$Font_CyanOrigin ASN: $Font_Suffix$(report_plain "${ripestat[origins]}")"
fi
}

show_exposure(){
if [[ "$YY" == "cn" ]];then
print -r -- "$Font_B公开暴露面观测（Shodan InternetDB；非风险分数）$Font_Suffix"
print -r -- "$Font_Cyan状态：$Font_Suffix$(report_plain "${internetdb[status]}")"
print -r -- "$Font_Cyan端口：$Font_Suffix$(report_plain "${internetdb[ports]}")（数量 $(report_plain "${internetdb[port_count]}")）"
print -r -- "$Font_Cyan已知漏洞数量：$Font_Suffix$(report_plain "${internetdb[vulnerability_count]}")"
print -r -- "$Font_Cyan标签：$Font_Suffix$(report_plain "${internetdb[tags]}")"
else
print -r -- "$Font_BPublic exposure observation (Shodan InternetDB; not a risk score)$Font_Suffix"
print -r -- "$Font_CyanStatus: $Font_Suffix$(report_plain "${internetdb[status]}")"
print -r -- "$Font_CyanPorts: $Font_Suffix$(report_plain "${internetdb[ports]}") (count $(report_plain "${internetdb[port_count]}") )"
print -r -- "$Font_CyanKnown-vulnerability count: $Font_Suffix$(report_plain "${internetdb[vulnerability_count]}")"
print -r -- "$Font_CyanTags: $Font_Suffix$(report_plain "${internetdb[tags]}")"
fi
}
