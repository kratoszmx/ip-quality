# Pure classification for credential and quota errors returned by the
# IPQualityScore upstream relay. Arbitrary upstream messages are never printed.

typeset -gA ipqualityscore_unavailable=()
typeset -gA ipqualityscore_parsed=()
typeset -gA ipqualityscore_usage=()

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
print -rn -- "$response"|jq -e '
  type == "object" and .success == true and
  (.fraud_score | type == "number" and . >= 0 and . <= 100) and
  (.country_code == null or (.country_code | type == "string")) and
  ([.proxy, .vpn, .tor, .recent_abuse, .bot_status]
    | all(. == null or type == "boolean")) and
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
ipqualityscore_parsed[server]=$(provider_connection_type_server_flag "${ipqualityscore_parsed[connection_type]}")
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
