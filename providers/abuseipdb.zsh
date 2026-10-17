# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# Official APIv2 CHECK response; no reporting/write endpoint is used.
abuseipdb_response_is_valid(){
emulate -LR zsh
print -rn -- "$1"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg target "$2" '
  include "json_values";
  type == "object" and .errors == null and (.data | type == "object") and
  .data.ipAddress == $target and
  (.data.abuseConfidenceScore | type == "number" and floor == . and . >= 0 and . <= 100) and
  text_or_null(.data.usageType; 128) and
  (.data.countryCode == null or (.data.countryCode | type == "string" and test("^[A-Z]{2}$")))
' >/dev/null 2>&1
}

db_abuseipdb(){
show_progress "${sinfo[database]}AbuseIPDB"
abuseipdb=()
local RESPONSE wire_response api_key="${provider_credentials[ABUSEIPDB_API_KEY]:-}"
abuseipdb[source]=check_place_relay
if [[ -n "$api_key" ]];then
abuseipdb[source]=official_api
wire_response=$(curl_with_secret_header Key "$api_key" \
  "https://api.abuseipdb.com/api/v2/check?ipAddress=$IP&maxAgeInDays=90" \
  $CurlARG -sS -$1 -m 10 -H 'Accept: application/json' --max-filesize 65536 \
  --write-out $'\n%{http_code}' 2>/dev/null)
provider_decode_http_response "$wire_response" "$?"
abuseipdb[status]="${provider_http_response[status]}"
RESPONSE="${provider_http_response[body]}"
else
check_place_fetch_json "$1" "$IP" "db=abuseipdb"||true
abuseipdb[status]="$PROVIDER_RESPONSE_STATUS"
RESPONSE="$PROVIDER_RESPONSE_BODY"
fi
[[ "${abuseipdb[status]}" == ok ]]||return 0
if ! abuseipdb_response_is_valid "$RESPONSE" "$IP";then
abuseipdb[status]=invalid_response
return 0
fi
abuseipdb[usetype]=$(echo "$RESPONSE"|jq -r '.data.usageType')
case ${abuseipdb[usetype]} in
"Commercial")abuseipdb[susetype]="${stype[business]}"
;;
"Data Center/Web Hosting/Transit")abuseipdb[susetype]="${stype[hosting]}"
;;
"University/College/School")abuseipdb[susetype]="${stype[education]}"
;;
"Government")abuseipdb[susetype]="${stype[government]}"
;;
"banking")abuseipdb[susetype]="${stype[banking]}"
;;
"Organization")abuseipdb[susetype]="${stype[organization]}"
;;
"Military")abuseipdb[susetype]="${stype[military]}"
;;
"Library")abuseipdb[susetype]="${stype[library]}"
;;
"Content Delivery Network")abuseipdb[susetype]="${stype[cdn]}"
;;
"Fixed Line ISP")abuseipdb[susetype]="${stype[lineisp]}"
;;
"Mobile ISP")abuseipdb[susetype]="${stype[mobile]}"
;;
"Search Engine Spider")abuseipdb[susetype]="${stype[spider]}"
;;
"Reserved")abuseipdb[susetype]="${stype[reserved]}"
;;
""|"null")abuseipdb[susetype]="${stype[unknown]}"
;;
*)abuseipdb[susetype]="${stype[other]}"
esac
abuseipdb[score]=$(echo "$RESPONSE"|jq -r '.data.abuseConfidenceScore')
if ! provider_integer_in_range "${abuseipdb[score]}" 0 100;then
abuseipdb[score]=""
fi
abuseipdb[risk]=""
}
