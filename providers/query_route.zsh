# Reporter policy for explicitly targeted official API reads. Never use this
# for egress discovery, visitor/self demos, DNS/SMTP, or account mutations.
query_route_begin(){
emulate -LR zsh
typeset -gA query_route
query_route=([family]="$1" [dns]="$2" [direct_dns]="$3" [route]=selected_route [primary_status]="")
query_route[can_fallback]=0
[[ -n "${IPQUALITY_ISOLATED_EGRESS:-}${http_proxy:-}${https_proxy:-}${all_proxy:-}${HTTP_PROXY:-}${HTTPS_PROXY:-}${ALL_PROXY:-}" ]]&&query_route[can_fallback]=1
return 0
}

query_route_request(){
emulate -LR zsh
setopt SH_WORD_SPLIT
typeset endpoint="$1" max_bytes="$2" header_name="${3:-}" header_value="${4:-}"
typeset wire_response request_exit_code attempt
typeset -a request_args
for attempt in 1 2;do
request_args=($CurlARG -sS -"${query_route[family]}" -m 10 --max-filesize "$max_bytes" --write-out $'\n%{http_code}')
if [[ "${query_route[route]}" == direct_fallback ]];then
# This is a lookup of the already fixed node IP over another transport, not a
# second egress measurement. Explicitly override inherited proxy variables.
request_args=(-sS -4 -m 10 --max-filesize "$max_bytes" --write-out $'\n%{http_code}' --proxy '' --noproxy '*')
query_route[dns]="${query_route[direct_dns]}"
fi
[[ "${query_route[dns]}" == alidns ]]&&request_args+=(--doh-url https://dns.alidns.com/dns-query)
if [[ -n "$header_name" ]];then
wire_response=$(curl_with_secret_header "$header_name" "$header_value" "$endpoint" "${request_args[@]}" 2>/dev/null)
request_exit_code=$?
else
wire_response=$(curl_with_secret_url "$endpoint" "${request_args[@]}" 2>/dev/null)
request_exit_code=$?
fi
provider_decode_http_response "$wire_response" "$request_exit_code"
[[ "${provider_http_response[status]}" == ok ]]&&return 0
# Retry only connectivity errors before any HTTP response. Quota, authentication,
# certificates, payload bounds and schema errors are not routing problems.
# A lost response can still consume a provider credit; cap this at one retry.
case "$request_exit_code" in
6|7|28|35|52|55|56) ;;
*)return 1 ;;
esac
[[ "${wire_response##*$'\n'}" == 000 ]]||return 1
[[ "$attempt" == 1 && "${query_route[can_fallback]}" == 1 && "${query_route[route]}" == selected_route ]]||return 1
query_route[primary_status]="${provider_http_response[status]}"
query_route[route]=direct_fallback
done
return 1
}
