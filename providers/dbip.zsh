# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# DB-IP public website demo; original threat labels, never invented scores.
typeset -gA dbip_parsed=()

dbip_demo_key_from_page(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset pattern='data-api-key="([A-Za-z0-9_-]{8,128})"'
[[ "$1" =~ "$pattern" ]]||return 1
print -rn -- "${match[0]}"
}

dbip_parse_response(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1" expected_ip="$2"
dbip_parsed=()
print -rn -- "$response"|jq -e 'type == "object"' >/dev/null 2>&1||return 1
if print -rn -- "$response"|jq -e 'type == "object" and (.errorCode != null or .error != null)' >/dev/null 2>&1;then
dbip_parsed[status]=upstream_error
if print -rn -- "$response"|jq -e '.errorCode == "OVER_QUERY_LIMIT" or (.error | type == "string" and test("maximum number of queries per day"; "i"))' >/dev/null 2>&1;then
dbip_parsed[status]=daily_quota_exhausted
elif print -rn -- "$response"|jq -e '.error | type == "string" and test("over query limit|maximum number of queries"; "i")' >/dev/null 2>&1;then
dbip_parsed[status]=rate_limited
fi
return 1
fi
if print -rn -- "$response"|jq -e --arg expected "$expected_ip" '.ipAddress | type == "string" and . != $expected' >/dev/null 2>&1;then
dbip_parsed[status]=ip_mismatch
return 1
fi
print -rn -- "$response"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg expected "$expected_ip" '
  include "json_values";
  type == "object" and .error == null and .errorCode == null and
  (.ipAddress | type == "string" and . == $expected) and
  (.countryCode | type == "string" and test("^[A-Z]{2}$")) and
  text_or_null(.countryName; 256) and text_or_null(.stateProv; 256) and text_or_null(.city; 256) and
  (.threatLevel == null or
    (.threatLevel | type == "string" and test("^(low|medium|high)$"; "i")))
' >/dev/null 2>&1||return 1
dbip_parsed[ip]=$(print -rn -- "$response"|jq -r '.ipAddress')
dbip_parsed[country_code]=$(print -rn -- "$response"|jq -r '.countryCode')
dbip_parsed[country]=$(print -rn -- "$response"|jq -r '.countryName // empty')
dbip_parsed[region]=$(print -rn -- "$response"|jq -r '.stateProv // empty')
dbip_parsed[city]=$(print -rn -- "$response"|jq -r '.city // empty')
dbip_parsed[risk_status]=not_provided
dbip_parsed[threat_level]=$(print -rn -- "$response"|jq -r '.threatLevel // empty | ascii_downcase')
[[ -n "${dbip_parsed[threat_level]}" ]]&&dbip_parsed[risk_status]=ok
dbip_parsed[status]=ok
}

db_dbip(){
show_progress "${sinfo[database]}DB-IP public demo"
dbip=()
dbip[source]="public_demo"
dbip[status]=unknown
typeset wire_response response_body guest_key endpoint
typeset -a demo_headers
demo_headers=(-A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36' \
  -H 'Accept: */*' -H 'Origin: https://db-ip.com' -H 'Referer: https://db-ip.com/')
# The website's current visitor demo is bound to the requesting egress. Keep
# both requests on this route, including IPv6; never substitute another IP.
endpoint='https://db-ip.com/api/core/'
typeset step
for step in page observation;do
wire_response=$(curl_with_secret_url "$endpoint" $CurlARG -sS -$1 -m 10 \
  --max-filesize 262144 --write-out $'\n%{http_code}' "${demo_headers[@]}" 2>/dev/null)
provider_decode_http_response "$wire_response" "$?"
dbip[status]="${provider_http_response[status]}"
[[ "${dbip[status]}" == ok ]]||return 0
response_body="${provider_http_response[body]}"
if [[ "${provider_http_response[http_code]}" != 200 ]];then
dbip[status]=invalid_response
return 0
fi
if [[ "$step" == page ]];then
guest_key=$(dbip_demo_key_from_page "$response_body")||{
dbip[status]=invalid_response
return 0
}
endpoint="https://api.db-ip.com/v2/$guest_key/self?convertCurrencies"
fi
done
if dbip_parse_response "$response_body" "$IP";then
dbip[status]=ok
dbip[risk_status]="${dbip_parsed[risk_status]}"
dbip[threat_level]="${dbip_parsed[threat_level]}"
case "${dbip[threat_level]}" in
low)dbip[risk]="${sscore[low]}" ;;
medium)dbip[risk]="${sscore[medium]}" ;;
high)dbip[risk]="${sscore[high]}" ;;
esac
dbip[ip]="${dbip_parsed[ip]}"
dbip[countrycode]="${dbip_parsed[country_code]}"
dbip[country]="${dbip_parsed[country]}"
dbip[region]="${dbip_parsed[region]}"
dbip[city]="${dbip_parsed[city]}"
else
dbip[status]="${dbip_parsed[status]:-invalid_response}"
fi
}
