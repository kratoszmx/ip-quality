# Pure classification for credential and quota errors returned by the
# IPQualityScore upstream relay. Arbitrary upstream messages are never printed.

typeset -gA ipqualityscore_unavailable=()

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
