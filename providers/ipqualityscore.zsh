# Pure classification for credential and quota errors returned by the
# IPQualityScore upstream relay. Arbitrary upstream messages are never printed.

typeset -gA ipqualityscore_unavailable=()
typeset -gA ipqualityscore_parsed=()

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
case "$(print -rn -- "$response"|jq -r '.connection_type // empty'|tr '[:upper:]' '[:lower:]')" in
"data center")ipqualityscore_parsed[server]="true"
;;
residential|corporate|education|mobile)ipqualityscore_parsed[server]="false"
esac
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
