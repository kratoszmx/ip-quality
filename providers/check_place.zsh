# Check.Place owns several relay datasets. A confirmed block/rate limit pauses
# this run's remaining relay requests for the same target and address family.
typeset -gA check_place_pauses
check_place_pauses=()

check_place_fetch_json(){
emulate -LR zsh
typeset address_family="$1" target="$2" query="$3" maximum_bytes="${4:-262144}"
typeset pause_key="$address_family/$target" request_result
PROVIDER_RESPONSE_BODY=""
if [[ -n "${check_place_pauses[$pause_key]:-}" ]];then
PROVIDER_RESPONSE_STATUS="skipped_relay_${check_place_pauses[$pause_key]}"
return 1
fi
provider_fetch_public_json "$address_family" "https://ipinfo.check.place/$target?$query" "$maximum_bytes"
request_result=$?
case "$PROVIDER_RESPONSE_STATUS" in
cloudflare_blocked|rate_limited)check_place_pauses[$pause_key]="$PROVIDER_RESPONSE_STATUS" ;;
esac
return "$request_result"
}
