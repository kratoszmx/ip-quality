# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# Pure classification for credential and quota errors returned by the
# IPQualityScore upstream relay. Arbitrary upstream messages are never printed.

typeset -gA ipqualityscore_unavailable=()
typeset -gA ipqualityscore_parsed=()
typeset -gA ipqualityscore_usage=()

# IPQS connection_type vocabulary, used by its official and relay adapters.
ipqualityscore_connection_type_server_flag(){
emulate -LR zsh
case "${1:l}" in
"data center")print -rn -- "true"
;;
residential|corporate|education|mobile)print -rn -- "false"
;;
esac
}

ipqualityscore_parse_usage_response(){
emulate -LR zsh
typeset response="$1"

ipqualityscore_usage=()
print -rn -- "$response"|jq -e '
  type == "object" and .success == true and
  (.credits | type == "number" and . >= 0 and floor == .) and
  (.usage | type == "number" and . >= 0 and floor == .) and
  (.proxy_usage == null or
    (.proxy_usage | type == "number" and . >= 0 and floor == .))
' >/dev/null 2>&1||return 1

ipqualityscore_usage[credits]=$(print -rn -- "$response"|jq -r '.credits')
ipqualityscore_usage[usage]=$(print -rn -- "$response"|jq -r '.usage')
ipqualityscore_usage[proxy_usage]=$(print -rn -- "$response"|jq -r '.proxy_usage // empty')
ipqualityscore_usage[status]="ok"
return 0
}

ipqualityscore_parse_response(){
emulate -LR zsh
typeset response="$1"

ipqualityscore_parsed=()
print -rn -- "$response"|jq -L "${${(%):-%x}:A:h:h}/common" -e '
  include "json_values";
  type == "object" and .success == true and
  (.fraud_score | type == "number" and . >= 0 and . <= 100) and
  (.country_code == null or (.country_code | type == "string")) and
  ([.proxy, .vpn, .tor, .recent_abuse, .bot_status]
    | all(boolean_or_null(.))) and
  (.connection_type == null or (.connection_type | type == "string"))
' >/dev/null 2>&1||return 1

ipqualityscore_parsed[score]=$(print -rn -- "$response"|jq -r '.fraud_score')
ipqualityscore_parsed[country_code]=$(print -rn -- "$response"|jq -r '.country_code // empty')
ipqualityscore_parsed[proxy]=$(print -rn -- "$response"|jq -r 'if .proxy == null then empty else .proxy end')
ipqualityscore_parsed[vpn]=$(print -rn -- "$response"|jq -r 'if .vpn == null then empty else .vpn end')
ipqualityscore_parsed[tor]=$(print -rn -- "$response"|jq -r 'if .tor == null then empty else .tor end')
ipqualityscore_parsed[abuser]=$(print -rn -- "$response"|jq -r 'if .recent_abuse == null then empty else .recent_abuse end')
ipqualityscore_parsed[robot]=$(print -rn -- "$response"|jq -r 'if .bot_status == null then empty else .bot_status end')
ipqualityscore_parsed[connection_type]=$(print -rn -- "$response"|jq -r '.connection_type // empty')
ipqualityscore_parsed[server]=$(ipqualityscore_connection_type_server_flag "${ipqualityscore_parsed[connection_type]}")
ipqualityscore_parsed[status]="ok"
return 0
}

ipqualityscore_parse_unavailability(){
emulate -LR zsh
typeset response="$1"
typeset message

ipqualityscore_unavailable=()
print -rn -- "$response"|jq -e '
  type == "object" and
  .success == false and
  (.message | type == "string" and length <= 1024)
' >/dev/null 2>&1||return 1

message=$(print -rn -- "$response"|jq -r '.message')
case "${message:l}" in
*insufficient*credits*)ipqualityscore_unavailable[status]="upstream_insufficient_credits"
;;
*rate*limit*|*too*many*requests*)ipqualityscore_unavailable[status]="rate_limited"
;;
*)ipqualityscore_unavailable[status]="upstream_error"
esac
return 0
}

db_ipqs(){
show_progress "${sinfo[database]}IPQS"
ipqs=()
ipqs[status]="unknown"
typeset api_key="${provider_credentials[IPQS_API_KEY]:-}"
typeset RESPONSE="" usage_response
if [[ -n "$api_key" ]];then
ipqs[source]="official_api"
ipqs[dns]="${ipqs_dns:-auto}"
if [[ "${ipqs[dns]}" == auto ]];then
ipqs[dns]=system
if [[ "$1" == 4 && -z "${IPQUALITY_ISOLATED_EGRESS:-}${http_proxy:-}${https_proxy:-}${all_proxy:-}${HTTP_PROXY:-}${HTTPS_PROXY:-}${ALL_PROXY:-}" ]];then
ipqs[dns]=alidns
fi
fi
query_route_begin "$1" "${ipqs[dns]}" alidns
query_route_request "https://www.ipqualityscore.com/api/json/account/$api_key" 65536||true
ipqs[query_route]="${query_route[route]}"
ipqs[primary_status]="${query_route[primary_status]}"
ipqs[dns]="${query_route[dns]}"
ipqs[status]="${provider_http_response[status]}"
[[ "${ipqs[status]}" == ok ]]||return 0
usage_response="${provider_http_response[body]}"
if ipqualityscore_parse_usage_response "$usage_response";then
ipqs[credits]="${ipqualityscore_usage[credits]}"
ipqs[usage]="${ipqualityscore_usage[usage]}"
if [[ "${ipqualityscore_usage[credits]}" == "0" ]];then
ipqs[status]="official_insufficient_credits"
ipqs[risk]=""
return 0
fi
elif ipqualityscore_parse_unavailability "$usage_response";then
ipqs[status]="${ipqualityscore_unavailable[status]}"
if [[ "${ipqs[status]}" == upstream_insufficient_credits ]];then
ipqs[status]="official_insufficient_credits"
fi
ipqs[risk]=""
return 0
else
ipqs[status]=invalid_response
return 0
fi
query_route_request "https://www.ipqualityscore.com/api/json/ip/$api_key/$IP?strictness=0&allow_public_access_points=true" 131072||true
ipqs[query_route]="${query_route[route]}"
ipqs[primary_status]="${query_route[primary_status]}"
ipqs[dns]="${query_route[dns]}"
ipqs[status]="${provider_http_response[status]}"
[[ "${ipqs[status]}" == ok ]]||return 0
RESPONSE="${provider_http_response[body]}"
if ipqualityscore_parse_response "$RESPONSE";then
ipqs[status]="ok"
ipqs[score]="${ipqualityscore_parsed[score]}"
ipqs[countrycode]="${ipqualityscore_parsed[country_code]}"
ipqs[usetype]="${ipqualityscore_parsed[connection_type]}"
ipqs[susetype]=$(styled_provider_type "${ipqs[usetype]}")
ipqs[proxy]="${ipqualityscore_parsed[proxy]}"
ipqs[tor]="${ipqualityscore_parsed[tor]}"
ipqs[vpn]="${ipqualityscore_parsed[vpn]}"
ipqs[server]="${ipqualityscore_parsed[server]}"
ipqs[abuser]="${ipqualityscore_parsed[abuser]}"
ipqs[robot]="${ipqualityscore_parsed[robot]}"
elif ipqualityscore_parse_unavailability "$RESPONSE";then
case "${ipqualityscore_unavailable[status]}" in
upstream_insufficient_credits)ipqs[status]="official_insufficient_credits"
;;
*)ipqs[status]="${ipqualityscore_unavailable[status]}"
esac
else
ipqs[status]=invalid_response
fi
else
if [[ "${source_selection:-all}" == independent || "${ipqs_dns:-system}" == alidns ]];then
ipqs[source]="official_api"
ipqs[status]="not_configured"
return 0
fi
ipqs[source]="check_place_relay"
check_place_fetch_json "$1" "$IP" "db=ipqualityscore" 65536||true
ipqs[status]="$PROVIDER_RESPONSE_STATUS"
RESPONSE="$PROVIDER_RESPONSE_BODY"
if ipqualityscore_parse_unavailability "$RESPONSE";then
ipqs[status]="${ipqualityscore_unavailable[status]}"
fi
ipqs[score]=$(echo "$RESPONSE"|jq -r '.fraud_score')
if ! provider_integer_in_range "${ipqs[score]}" 0 100;then
ipqs[score]=""
fi
ipqs[countrycode]=$(echo "$RESPONSE"|jq -r '.country_code')
ipqs[usetype]=$(echo "$RESPONSE"|jq -r 'if (.connection_type | type) == "string" and (.connection_type | length) <= 64 then .connection_type else empty end')
ipqs[susetype]=$(styled_provider_type "${ipqs[usetype]}")
ipqs[proxy]=$(echo "$RESPONSE"|jq -r '.proxy')
ipqs[tor]=$(echo "$RESPONSE"|jq -r '.tor')
ipqs[vpn]=$(echo "$RESPONSE"|jq -r '.vpn')
ipqs[server]=$(ipqualityscore_connection_type_server_flag "${ipqs[usetype]}")
ipqs[abuser]=$(echo "$RESPONSE"|jq -r '.recent_abuse')
ipqs[robot]=$(echo "$RESPONSE"|jq -r '.bot_status')
if provider_has_observation "${ipqs[score]}" "${ipqs[countrycode]}" "${ipqs[proxy]}" "${ipqs[tor]}" "${ipqs[vpn]}" "${ipqs[abuser]}" "${ipqs[robot]}";then
ipqs[status]="ok"
fi
fi
ipqs[risk]=""
}
