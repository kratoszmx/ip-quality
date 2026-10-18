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
local field
provider_json_fields "$RESPONSE" '.data.asn.type, .data.company.type, .data.country,
  .data.privacy.proxy, .data.privacy.tor, .data.privacy.vpn, .data.privacy.hosting,
  (.data.asn.asn | if type == "string" then ltrimstr("AS") else . end), .data.asn.name,
  .data.city, .data.postal, .data.timezone, .data.loc, .data.abuse.country' \
  usetype comtype countrycode proxy tor vpn server asn org city post timezone loc regcountrycode||{
ipinfo[status]=invalid_response
return 0
}
for field in usetype comtype countrycode proxy tor vpn server asn org city post timezone regcountrycode;do
ipinfo[$field]="${provider_fields[$field]}"
done
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
local ISO3166=$(<"$REF_DIR/iso3166.json") location="${provider_fields[loc]}"
# "lat,lon"; without a comma both halves keep the raw value and fail the decimal checks.
ipinfo[lat]="${location%%,*}"
ipinfo[lon]="${${location#*,}%%,*}"
ipinfo[country]=$(print -rn -- "$ISO3166"|jq --arg code "${ipinfo[countrycode]}" -r '.[] | select(.["alpha-2"] == $code) | .name')
ipinfo[continent]=$(print -rn -- "$ISO3166"|jq --arg code "${ipinfo[countrycode]}" -r '.[] | select(.["alpha-2"] == $code) | .region')
ipinfo[regcountrycode]=$(print -rn -- "$RESPONSE"|jq -r '.data.abuse.country')
ipinfo[regcountry]=$(print -rn -- "$ISO3166"|jq --arg code "${ipinfo[regcountrycode]}" -r '.[] | select(.["alpha-2"] == $code) | .name')
if is_signed_decimal "${ipinfo[lat]}"&&is_signed_decimal "${ipinfo[lon]}";then
ipinfo[dms]=$(generate_dms "${ipinfo[lat]}" "${ipinfo[lon]}")
ipinfo[map]=$(generate_googlemap_url "${ipinfo[lat]}" "${ipinfo[lon]}" "1001")
else
ipinfo[dms]="null"
ipinfo[map]="null"
fi
}
