# Report header, basic-information, mail/DNSBL and footer sections.
# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.

show_head(){
echo -ne "\r$(printf '%72s'|tr ' ' '#')\n"
if [ $fullIP -eq 1 ];then
calc_padding "$(printf '%*s' "${shead[ltitle]}" '')$IP" 72
echo -ne "\r$PADDING$Font_B${shead[title]}$Font_Cyan$IP$Font_Suffix\n"
else
calc_padding "$(printf '%*s' "${shead[ltitle]}" '')$IPhide" 72
echo -ne "\r$PADDING$Font_B${shead[title]}$Font_Cyan$IPhide$Font_Suffix\n"
fi
calc_padding "${shead[git]}" 72
echo -ne "\r$PADDING$Font_U${shead[git]}$Font_Suffix\n"
echo -ne "\r${shead[ptime]}${shead[time]}  ${shead[ver]}\n"
echo -ne "\r$(printf '%72s'|tr ' ' '#')\n"
}
show_basic(){
echo -ne "\r${sbasic[title]}\n"
if [[ -n ${maxmind[asn]} && ${maxmind[asn]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[asn]}${Font_Green}AS${maxmind[asn]}$Font_Suffix\n"
echo -ne "\r$Font_Cyan${sbasic[org]}$Font_Green${maxmind[org]}$Font_Suffix\n"
else
echo -ne "\r$Font_Cyan${sbasic[asn]}${sbasic[noasn]}$Font_Suffix\n"
fi
if [[ ${maxmind[dms]} != "null" && ${maxmind[map]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[location]}$Font_Green${maxmind[dms]}$Font_Suffix\n"
echo -ne "\r$Font_Cyan${sbasic[map]}$Font_U$Font_Green${maxmind[map]}$Font_Suffix\n"
fi
local city_info=""
if [[ -n ${maxmind[sub]} && ${maxmind[sub]} != "null" ]];then
city_info+="${maxmind[sub]}"
fi
if [[ -n ${maxmind[city]} && ${maxmind[city]} != "null" ]];then
[[ -n $city_info ]]&&city_info+=", "
city_info+="${maxmind[city]}"
fi
if [[ -n ${maxmind[post]} && ${maxmind[post]} != "null" ]];then
[[ -n $city_info ]]&&city_info+=", "
city_info+="${maxmind[post]}"
fi
if [[ -n $city_info ]];then
echo -ne "\r$Font_Cyan${sbasic[city]}$Font_Green$city_info$Font_Suffix\n"
fi
if [[ -n ${maxmind[countrycode]} && ${maxmind[countrycode]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[country]}$Font_Green[${maxmind[countrycode]}]${maxmind[country]}$Font_Suffix"
if [[ -n ${maxmind[continentcode]} && ${maxmind[continentcode]} != "null" ]];then
echo -ne "$Font_Green, [${maxmind[continentcode]}]${maxmind[continent]}$Font_Suffix\n"
else
echo -ne "\n"
fi
elif [[ -n ${maxmind[continentcode]} && ${maxmind[continentcode]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[continent]}$Font_Green[${maxmind[continentcode]}]${maxmind[continent]}$Font_Suffix\n"
fi
if [[ -n ${maxmind[regcountrycode]} && ${maxmind[regcountrycode]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[regcountry]}$Font_Green[${maxmind[regcountrycode]}]${maxmind[regcountry]}$Font_Suffix\n"
fi
if [[ -n ${maxmind[timezone]} && ${maxmind[timezone]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[timezone]}$Font_Green${maxmind[timezone]}$Font_Suffix\n"
fi
if [[ -n ${maxmind[countrycode]} && ${maxmind[countrycode]} != "null" ]];then
if [ "${maxmind[countrycode]}" == "${maxmind[regcountrycode]}" ];then
echo -ne "\r$Font_Cyan${sbasic[type]}$Back_Green$Font_B$Font_White${sbasic[type0]}$Font_Suffix\n"
else
echo -ne "\r$Font_Cyan${sbasic[type]}$Back_Red$Font_B$Font_White${sbasic[type1]}$Font_Suffix\n"
fi
fi
}
show_basic_lite(){
if [[ "${ipinfo[status]:-}" == disabled ]];then
[[ "$YY" == cn ]]&&print -r -- "一、基础信息（无可用的地理资料）"||print -r -- "1. Basic information (no geographic observation available)"
return 0
fi
echo -ne "\r${sbasic[title_lite]}\n"
if [[ -n ${ipinfo[asn]} && ${ipinfo[asn]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[asn]}${Font_Green}AS${ipinfo[asn]}$Font_Suffix\n"
echo -ne "\r$Font_Cyan${sbasic[org]}$Font_Green${ipinfo[org]}$Font_Suffix\n"
else
echo -ne "\r$Font_Cyan${sbasic[asn]}${sbasic[noasn]}$Font_Suffix\n"
fi
if [[ -n "${ipinfo[dms]}" && -n "${ipinfo[map]}" && ${ipinfo[dms]} != "null" && ${ipinfo[map]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[location]}$Font_Green${ipinfo[dms]}$Font_Suffix\n"
echo -ne "\r$Font_Cyan${sbasic[map]}$Font_U$Font_Green${ipinfo[map]}$Font_Suffix\n"
fi
local city_info=""
if [[ -n ${ipinfo[sub]} && ${ipinfo[sub]} != "null" ]];then
city_info+="${ipinfo[sub]}"
fi
if [[ -n ${ipinfo[city]} && ${ipinfo[city]} != "null" ]];then
[[ -n $city_info ]]&&city_info+=", "
city_info+="${ipinfo[city]}"
fi
if [[ -n ${ipinfo[post]} && ${ipinfo[post]} != "null" ]];then
[[ -n $city_info ]]&&city_info+=", "
city_info+="${ipinfo[post]}"
fi
if [[ -n $city_info ]];then
echo -ne "\r$Font_Cyan${sbasic[city]}$Font_Green$city_info$Font_Suffix\n"
fi
if [[ -n ${ipinfo[countrycode]} && ${ipinfo[countrycode]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[country]}$Font_Green[${ipinfo[countrycode]}]${ipinfo[country]}$Font_Suffix"
if [[ -n ${ipinfo[continent]} && ${ipinfo[continent]} != "null" ]];then
echo -ne "$Font_Green, ${ipinfo[continent]}$Font_Suffix\n"
else
echo -ne "\n"
fi
elif [[ -n ${ipinfo[continent]} && ${ipinfo[continent]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[continent]}$Font_Green${ipinfo[continent]}$Font_Suffix\n"
fi
if [[ -n ${ipinfo[regcountrycode]} && ${ipinfo[regcountrycode]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[regcountry]}$Font_Green[${ipinfo[regcountrycode]}]${ipinfo[regcountry]}$Font_Suffix\n"
fi
if [[ -n ${ipinfo[timezone]} && ${ipinfo[timezone]} != "null" ]];then
echo -ne "\r$Font_Cyan${sbasic[timezone]}$Font_Green${ipinfo[timezone]}$Font_Suffix\n"
fi
if [[ -n ${ipinfo[countrycode]} && ${ipinfo[countrycode]} != "null" ]];then
if [ "${ipinfo[countrycode]}" == "${ipinfo[regcountrycode]}" ];then
echo -ne "\r$Font_Cyan${sbasic[type]}$Back_Green$Font_B$Font_White${sbasic[type0]}$Font_Suffix\n"
else
echo -ne "\r$Font_Cyan${sbasic[type]}$Back_Red$Font_B$Font_White${sbasic[type1]}$Font_Suffix\n"
fi
fi
}
show_mail(){
echo -ne "\r${smail[title]}\n"
if [ ${smail[local]} -eq 1 ];then
echo -ne "\r$Font_Cyan${smail[port]}$Font_Suffix${smail[yes]}\n"
elif [ ${smail[local]} -eq 2 ];then
echo -ne "\r$Font_Cyan${smail[port]}$Font_Suffix${smail[occupied]}\n"
else
echo -ne "\r$Font_Cyan${smail[port]}$Font_Suffix${smail[no]}\n"
fi
if [ ${smail[remote]} -eq 1 ];then
echo -ne "\r$Font_Cyan${smail[provider]}$Font_Suffix"
for service in "${services[@]}";do
echo -ne "${smail[$service]}"
done
echo ""
else
echo -ne "\r$Font_Cyan${smail[provider]}${smail[blocked]}$Font_Suffix\n"
fi
}
show_dnsbl(){
echo -ne "\r${smail[sdnsbl]}\n"
if [[ -n "${smail[blacklisted_zones]}" ]];then
if [[ "$YY" == "cn" ]];then
print -r -- "${Font_Red}黑名单命中：${smail[blacklisted_zones]}${Font_Suffix}"
else
print -r -- "${Font_Red}Blacklisted by: ${smail[blacklisted_zones]}${Font_Suffix}"
fi
if [[ "${smail[blacklisted_zones]}" == *"dnsbl-2.uceprotect.net"* ||
      "${smail[blacklisted_zones]}" == *"dnsbl-3.uceprotect.net"* ]];then
if [[ "$YY" == "cn" ]];then
print -r -- "${Font_Yellow}说明：UCEPROTECT Level 2/3 是网段／ASN 级记录，不等于这个单独 IP 曾发送垃圾邮件。${Font_Suffix}"
else
print -r -- "${Font_Yellow}Note: UCEPROTECT Level 2/3 are netblock/ASN-level listings, not proof that this individual IP sent spam.${Font_Suffix}"
fi
fi
fi
if [[ -n "${smail[marked_zones]}" ]];then
if [[ "$YY" == "cn" ]];then
print -r -- "${Font_Yellow}其他标记：${smail[marked_zones]}${Font_Suffix}"
else
print -r -- "${Font_Yellow}Other listings: ${smail[marked_zones]}${Font_Suffix}"
fi
fi
}
show_tail(){
echo -ne "\r$(printf '%72s'|tr ' ' '=')\n"
echo -ne "\r$Font_I${stail[thanks]} $Font_Suffix\n"
echo -e ""
}
