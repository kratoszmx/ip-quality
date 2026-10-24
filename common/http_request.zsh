# True when curl would leave through an inherited proxy or the runner's isolated
# leaf (IPQUALITY_ISOLATED_EGRESS), i.e. not over the plain system route.
http_route_is_proxied(){
[[ -n "${IPQUALITY_ISOLATED_EGRESS:-}${http_proxy:-}${https_proxy:-}${all_proxy:-}${HTTP_PROXY:-}${HTTPS_PROXY:-}${ALL_PROXY:-}" ]]
}

# Keep credential-bearing curl options on stdin, out of process arguments.
# Callers own endpoint/key validation, route selection and request budgets.
curl_with_secret_url(){
emulate -LR zsh
typeset secret_url="$1"
shift
print -r -- "url = \"$secret_url\""|curl -q "$@" --config -
}

curl_with_secret_header(){
emulate -LR zsh
typeset header_name="$1"
typeset header_value="$2"
typeset endpoint="$3"
shift 3
{
print -r -- "header = \"$header_name: $header_value\""
print -r -- "url = \"$endpoint\""
}|curl -q "$@" --config -
}

# One bounded public JSON GET over the reporter's interface selection ($CurlARG).
# Sets PROVIDER_RESPONSE_STATUS/BODY; exit 0 only for a 2xx JSON object.
typeset -g PROVIDER_RESPONSE_BODY=""
typeset -g PROVIDER_RESPONSE_STATUS="unknown"
provider_fetch_public_json(){
emulate -LR zsh
setopt SH_WORD_SPLIT
typeset address_family="$1"
typeset endpoint="$2"
typeset maximum_bytes="${3:-262144}"
if (( $# >= 3 ));then shift 3;else shift 2;fi
typeset wire_response response_body

PROVIDER_RESPONSE_BODY=""
PROVIDER_RESPONSE_STATUS="unknown"
wire_response=$(curl -q $CurlARG -sS -L -$address_family -m 10 \
  --max-filesize "$maximum_bytes" --write-out $'\n%{http_code}' "$@" "$endpoint" 2>/dev/null)
provider_decode_http_response "$wire_response" "$?"
PROVIDER_RESPONSE_STATUS="${provider_http_response[status]}"
[[ "$PROVIDER_RESPONSE_STATUS" == ok ]]||return 1
response_body="${provider_http_response[body]}"
if ! provider_json_is_object "$response_body";then
PROVIDER_RESPONSE_STATUS="invalid_response"
return 1
fi
PROVIDER_RESPONSE_BODY="$response_body"
PROVIDER_RESPONSE_STATUS="ok"
return 0
}
