# IPinfo public widget: basic network/location context for the report header.
# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.

db_ipinfo(){
show_progress "${sinfo[database]}IPinfo"
ipinfo=()
typeset wire_response RESPONSE
if [[ $IP == *:* ]];then
wire_response=$(curl -q -Ls -m 10 --max-filesize 262144 --write-out $'\n%{http_code}' "https://ipinfo.io/widget/demo/$IP")
else
wire_response=$(curl -q $CurlARG -Ls -m 10 --max-filesize 262144 --write-out $'\n%{http_code}' "https://ipinfo.io/widget/demo/$IP")
fi
provider_decode_http_response "$wire_response" "$?"
ipinfo[status]="${provider_http_response[status]}"
[[ "${ipinfo[status]}" == ok ]]||return 0
RESPONSE="${provider_http_response[body]}"
if ! print -rn -- "$RESPONSE"|jq -e 'type == "object" and (.data | type == "object") and ([.data.asn, .data.company, .data.privacy, .data.abuse] | all(. == null or type == "object"))' >/dev/null 2>&1;then
ipinfo[status]=invalid_response
return 0
fi
ipinfo[usetype]=$(echo "$RESPONSE"|jq -r '.data.asn.type')
ipinfo[comtype]=$(echo "$RESPONSE"|jq -r '.data.company.type')
case ${ipinfo[usetype]} in
"business")ipinfo[susetype]="${stype[business]}"
;;
"isp")ipinfo[susetype]="${stype[isp]}"
;;
"hosting")ipinfo[susetype]="${stype[hosting]}"
;;
"education")ipinfo[susetype]="${stype[education]}"
;;
""|"null")ipinfo[susetype]="${stype[unknown]}"
;;
*)ipinfo[susetype]="${stype[other]}"
esac
case ${ipinfo[comtype]} in
"business")ipinfo[scomtype]="${stype[business]}"
;;
"isp")ipinfo[scomtype]="${stype[isp]}"
;;
"hosting")ipinfo[scomtype]="${stype[hosting]}"
;;
"education")ipinfo[scomtype]="${stype[education]}"
;;
""|"null")ipinfo[scomtype]="${stype[unknown]}"
;;
*)ipinfo[scomtype]="${stype[other]}"
esac
ipinfo[countrycode]=$(echo "$RESPONSE"|jq -r '.data.country')
ipinfo[proxy]=$(echo "$RESPONSE"|jq -r '.data.privacy.proxy')
ipinfo[tor]=$(echo "$RESPONSE"|jq -r '.data.privacy.tor')
ipinfo[vpn]=$(echo "$RESPONSE"|jq -r '.data.privacy.vpn')
ipinfo[server]=$(echo "$RESPONSE"|jq -r '.data.privacy.hosting')
local ISO3166=$(<"$REF_DIR/iso3166.json")
ipinfo[asn]=$(echo "$RESPONSE"|jq -r '.data.asn.asn'|sed 's/^AS//')
ipinfo[org]=$(echo "$RESPONSE"|jq -r '.data.asn.name')
ipinfo[city]=$(echo "$RESPONSE"|jq -r '.data.city')
ipinfo[post]=$(echo "$RESPONSE"|jq -r '.data.postal')
ipinfo[timezone]=$(echo "$RESPONSE"|jq -r '.data.timezone')
local tmp_str=$(echo "$RESPONSE"|jq -r '.data.loc')
ipinfo[lat]=$(echo "$tmp_str"|cut -d',' -f1)
ipinfo[lon]=$(echo "$tmp_str"|cut -d',' -f2)
ipinfo[countrycode]=$(echo "$RESPONSE"|jq -r '.data.country')
ipinfo[country]=$(echo "$ISO3166"|jq --arg code "${ipinfo[countrycode]}" -r '.[] | select(.["alpha-2"] == $code) | .name')
ipinfo[continent]=$(echo "$ISO3166"|jq --arg code "${ipinfo[countrycode]}" -r '.[] | select(.["alpha-2"] == $code) | .region')
ipinfo[regcountrycode]=$(echo "$RESPONSE"|jq -r '.data.abuse.country')
ipinfo[regcountry]=$(echo "$ISO3166"|jq --arg code "${ipinfo[regcountrycode]}" -r '.[] | select(.["alpha-2"] == $code) | .name')
if is_signed_decimal "${ipinfo[lat]}"&&is_signed_decimal "${ipinfo[lon]}";then
ipinfo[dms]=$(generate_dms "${ipinfo[lat]}" "${ipinfo[lon]}")
ipinfo[map]=$(generate_googlemap_url "${ipinfo[lat]}" "${ipinfo[lon]}" "1001")
else
ipinfo[dms]="null"
ipinfo[map]="null"
fi
}
