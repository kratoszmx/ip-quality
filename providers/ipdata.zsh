# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# The website publishes a demo credential for its own public lookup. Discover it
# afresh, use it in memory once, and never treat it as an owned account/API key.
ipdata_demo_key_from_page(){
emulate -LR zsh
(( ${#1} <= 262144 ))||return 1
print -rn -- "$1"|jq -Rrse '
  [match("\\$\\.get\\(\"https://api\\.ipdata\\.co/\" \\+ ip \\+ \u0027\\?api-key=(?<key>[a-f0-9]{32,128})\u0027"; "g") | .captures[0].string] |
  select(length == 1) | .[0]
' 2>/dev/null
}

ipdata_response_is_valid(){
emulate -LR zsh
print -rn -- "$1"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg target "$2" '
  include "json_values";
  type == "object" and .ip == $target and .message == null and .error == null and
  (.country_code | type == "string" and test("^[A-Z]{2}$")) and
  (.threat | type == "object") and
  ([.threat.is_proxy, .threat.is_vpn, .threat.is_tor, .threat.is_datacenter,
    .threat.is_threat, .threat.is_known_abuser, .threat.is_known_attacker] |
    all(boolean_or_null(.)) and any(. != null))
' >/dev/null 2>&1
}

db_ipdata(){
show_progress "${sinfo[database]}ipdata"
ipdata=()
ipdata[source]=check_place_relay
check_place_fetch_json "$1" "$IP" "db=ipdata"||true
ipdata[status]="$PROVIDER_RESPONSE_STATUS"
local RESPONSE="$PROVIDER_RESPONSE_BODY"
if [[ "${ipdata[status]}" == ok ]] && ! ipdata_response_is_valid "$RESPONSE" "$IP";then
ipdata[status]=invalid_response
fi
if [[ "${ipdata[status]}" != ok ]];then
ipdata[relay_status]="${ipdata[status]}"
ipdata[source]=public_demo
typeset wire_response demo_key
wire_response=$(curl -q $CurlARG -sS -$1 -m 10 --max-filesize 262144 \
  --write-out $'\n%{http_code}' 'https://ipdata.co/' 2>/dev/null)
provider_decode_http_response "$wire_response" "$?"
ipdata[status]="${provider_http_response[status]}"
[[ "${ipdata[status]}" == ok ]]||return 0
if ! demo_key=$(ipdata_demo_key_from_page "${provider_http_response[body]}");then
ipdata[status]=invalid_response
return 0
fi
wire_response=$(curl_with_secret_url "https://api.ipdata.co/$IP?api-key=$demo_key" \
  $CurlARG -sS -$1 -m 10 --max-filesize 262144 \
  -H 'Referer: https://ipdata.co/' -H 'Origin: https://ipdata.co' \
  --write-out $'\n%{http_code}' 2>/dev/null)
provider_decode_http_response "$wire_response" "$?"
demo_key=""
ipdata[status]="${provider_http_response[status]}"
[[ "${ipdata[status]}" == ok ]]||return 0
RESPONSE="${provider_http_response[body]}"
if ! ipdata_response_is_valid "$RESPONSE" "$IP";then
ipdata[status]=invalid_response
return 0
fi
fi
ipdata[countrycode]=$(echo "$RESPONSE"|jq -r '.country_code')
ipdata[proxy]=$(echo "$RESPONSE"|jq -r '.threat.is_proxy')
ipdata[vpn]=$(echo "$RESPONSE"|jq -r '.threat.is_vpn')
ipdata[tor]=$(echo "$RESPONSE"|jq -r '.threat.is_tor')
ipdata[server]=$(echo "$RESPONSE"|jq -r '.threat.is_datacenter')
ipdata[abuser1]=$(echo "$RESPONSE"|jq -r '.threat.is_threat')
ipdata[abuser2]=$(echo "$RESPONSE"|jq -r '.threat.is_known_abuser')
ipdata[abuser3]=$(echo "$RESPONSE"|jq -r '.threat.is_known_attacker')
ipdata[abuser]=$(provider_merge_boolean_signals "${ipdata[abuser1]}" "${ipdata[abuser2]}" "${ipdata[abuser3]}")
}
