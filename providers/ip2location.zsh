# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# IP2Location's public lookup embeds a target-specific JSON example. Read that
# data without executing page scripts or deriving false flags from missing text.
ip2location_page_response(){
emulate -LR zsh
typeset page="$1" target="$2"
(( ${#page} <= 262144 ))||return 1
print -rn -- "$page"|jq -Rrse --arg target "$target" '
  def one: if length == 1 then .[0] else null end;
  ([match("<h1\\b[^>]*>IP Address (?<ip>[0-9a-fA-F:.]+)</h1>"; "g") | .captures[0].string] | one) as $heading |
  ([match("<pre\\b[^>]*\\bid=\"code2\"[^>]*>\\s*<code\\b[^>]*>(?<json>[^<]*)</code>\\s*</pre>"; "gs") | .captures[0].string] | one) as $example |
  select($heading == $target and $example != null) |
  ($example | gsub("&quot;"; "\"") | gsub("&#39;"; "\u0027") |
    gsub("&lt;"; "<") | gsub("&gt;"; ">") | gsub("&amp;"; "&") | fromjson) |
  select(type == "object" and .ip == $target)
' 2>/dev/null
}

ip2location_response_is_valid(){
emulate -LR zsh
print -rn -- "$1"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg target "$2" '
  include "json_values";
  type == "object" and .ip == $target and .error == null and
  (.as_info == null or (.as_info | type == "object")) and
  (.proxy == null or (.proxy | type == "object")) and
  (.country_code == null or (.country_code | type == "string" and test("^[A-Z]{2}$"))) and
  text_or_null(.usage_type; 128) and text_or_null(.as_info.as_usage_type; 128) and
  integer_or_null(.fraud_score; 0; 99) and
  ([.is_proxy, .proxy.is_public_proxy, .proxy.is_web_proxy, .proxy.is_tor,
    .proxy.is_vpn, .proxy.is_data_center, .proxy.is_spammer, .proxy.is_web_crawler,
    .proxy.is_scanner, .proxy.is_botnet] | all(boolean_or_null(.))) and
  ([.fraud_score, .is_proxy, .proxy.is_vpn, .proxy.is_tor, .proxy.is_data_center] | any(. != null))
' >/dev/null 2>&1
}

db_ip2location(){
show_progress "${sinfo[database]}IP2LOCATION"
ip2location=()
ip2location[source]=check_place_relay
check_place_fetch_json "$1" "$IP" "db=ip2location"||true
ip2location[status]="$PROVIDER_RESPONSE_STATUS"
local RESPONSE="$PROVIDER_RESPONSE_BODY"
if [[ "${ip2location[status]}" == ok ]] && ! ip2location_response_is_valid "$RESPONSE" "$IP";then
ip2location[status]=invalid_response
fi
if [[ "${ip2location[status]}" != ok ]];then
ip2location[relay_status]="${ip2location[status]}"
ip2location[source]=public_demo
typeset wire_response
wire_response=$(curl -q $CurlARG -sS -$1 -m 10 --max-filesize 262144 \
  --write-out $'\n%{http_code}' "https://www.ip2location.com/$IP" 2>/dev/null)
provider_decode_http_response "$wire_response" "$?"
ip2location[status]="${provider_http_response[status]}"
[[ "${ip2location[status]}" == ok ]]||return 0
if ! RESPONSE=$(ip2location_page_response "${provider_http_response[body]}" "$IP") ||
   ! ip2location_response_is_valid "$RESPONSE" "$IP";then
ip2location[status]=invalid_response
return 0
fi
fi
ip2location[usetype]=$(print -rn -- "$RESPONSE"|jq -r '.usage_type')
ip2location[comtype]=$(print -rn -- "$RESPONSE"|jq -r '.as_info.as_usage_type')
local first_use="${ip2location[usetype]%%/*}"
case $first_use in
"COM")ip2location[susetype]="${stype[business]}"
;;
"DCH")ip2location[susetype]="${stype[hosting]}"
;;
"EDU")ip2location[susetype]="${stype[education]}"
;;
"GOV")ip2location[susetype]="${stype[government]}"
;;
"ORG")ip2location[susetype]="${stype[organization]}"
;;
"MIL")ip2location[susetype]="${stype[military]}"
;;
"LIB")ip2location[susetype]="${stype[library]}"
;;
"CDN")ip2location[susetype]="${stype[cdn]}"
;;
"ISP")ip2location[susetype]="${stype[lineisp]}"
;;
"MOB")ip2location[susetype]="${stype[mobile]}"
;;
"SES")ip2location[susetype]="${stype[spider]}"
;;
"RSV")ip2location[susetype]="${stype[reserved]}"
;;
""|"null")ip2location[susetype]="${stype[unknown]}"
;;
*)ip2location[susetype]="${stype[other]}"
esac
first_use="${ip2location[comtype]%%/*}"
case $first_use in
"COM")ip2location[scomtype]="${stype[business]}"
;;
"DCH")ip2location[scomtype]="${stype[hosting]}"
;;
"EDU")ip2location[scomtype]="${stype[education]}"
;;
"GOV")ip2location[scomtype]="${stype[government]}"
;;
"ORG")ip2location[scomtype]="${stype[organization]}"
;;
"MIL")ip2location[scomtype]="${stype[military]}"
;;
"LIB")ip2location[scomtype]="${stype[library]}"
;;
"CDN")ip2location[scomtype]="${stype[cdn]}"
;;
"ISP")ip2location[scomtype]="${stype[lineisp]}"
;;
"MOB")ip2location[scomtype]="${stype[mobile]}"
;;
"SES")ip2location[scomtype]="${stype[spider]}"
;;
"RSV")ip2location[scomtype]="${stype[reserved]}"
;;
""|"null")ip2location[scomtype]="${stype[unknown]}"
;;
*)ip2location[scomtype]="${stype[other]}"
esac
ip2location[countrycode]=$(print -rn -- "$RESPONSE"|jq -r '.country_code')
ip2location[proxy0]=$(print -rn -- "$RESPONSE"|jq -r '.is_proxy')
ip2location[proxy1]=$(print -rn -- "$RESPONSE"|jq -r '.proxy.is_public_proxy')
ip2location[proxy2]=$(print -rn -- "$RESPONSE"|jq -r '.proxy.is_web_proxy')
ip2location[proxy]=$(provider_merge_boolean_signals "${ip2location[proxy0]}" "${ip2location[proxy1]}" "${ip2location[proxy2]}")
ip2location[tor]=$(print -rn -- "$RESPONSE"|jq -r '.proxy.is_tor')
ip2location[vpn]=$(print -rn -- "$RESPONSE"|jq -r '.proxy.is_vpn')
ip2location[server]=$(print -rn -- "$RESPONSE"|jq -r '.proxy.is_data_center')
ip2location[abuser]=$(print -rn -- "$RESPONSE"|jq -r '.proxy.is_spammer')
ip2location[robot1]=$(print -rn -- "$RESPONSE"|jq -r '.proxy.is_web_crawler')
ip2location[robot2]=$(print -rn -- "$RESPONSE"|jq -r '.proxy.is_scanner')
ip2location[robot3]=$(print -rn -- "$RESPONSE"|jq -r '.proxy.is_botnet')
ip2location[robot]=$(provider_merge_boolean_signals "${ip2location[robot1]}" "${ip2location[robot2]}" "${ip2location[robot3]}")
ip2location[score]=$(print -rn -- "$RESPONSE"|jq -r '.fraud_score')
if ! provider_integer_in_range "${ip2location[score]}" 0 99;then
ip2location[score]=""
fi
ip2location[risk]=""
}
