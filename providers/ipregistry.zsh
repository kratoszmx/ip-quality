# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# Strict parser for Ipregistry's official IP Intelligence API.
# Parsers use provider_json_fields; standalone fixture runs load it here.
(( ${+functions[provider_json_fields]} ))||source "${${(%):-%x}:A:h:h}/common/provider_values.zsh"

typeset -gA ipregistry_parsed=()

ipregistry_parse_response(){
emulate -LR zsh
typeset response="$1"
typeset expected_ip="$2"

ipregistry_parsed=()
print -rn -- "$response"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg expected "$expected_ip" '
  include "json_values";
  type == "object" and .ip == $expected and
  (.connection | type == "object") and
  (.company | type == "object") and
  (.location.country | type == "object") and
  (.security | type == "object") and
  ([.connection.type, .company.type, .location.country.code]
    | all(. == null or type == "string")) and
  ([.security.is_proxy, .security.is_vpn, .security.is_tor,
    .security.is_tor_exit, .security.is_cloud_provider,
    .security.is_abuser, .security.is_attacker, .security.is_threat]
    | all(boolean_or_null(.)))
' >/dev/null 2>&1||return 1

provider_json_fields "$response" '
  ([.connection.type // empty] | if length == 0 then "" else .[0] end),
  ([.company.type // empty] | if length == 0 then "" else .[0] end),
  ([.location.country.code // empty] | if length == 0 then "" else .[0] end),
  ([if .security.is_proxy == null then empty else .security.is_proxy end] | if length == 0 then "" else .[0] end),
  ([if .security.is_vpn == null then empty else .security.is_vpn end] | if length == 0 then "" else .[0] end)' usage_type company_type country_code proxy vpn||return 1
ipregistry_parsed+=("${(@kv)provider_fields[@]}")
ipregistry_parsed[tor]=$(provider_merge_boolean_signals \
  "$(print -rn -- "$response"|jq -r 'if .security.is_tor == null then empty else .security.is_tor end')" \
  "$(print -rn -- "$response"|jq -r 'if .security.is_tor_exit == null then empty else .security.is_tor_exit end')")
ipregistry_parsed[server]=$(print -rn -- "$response"|jq -r 'if .security.is_cloud_provider == null then empty else .security.is_cloud_provider end')
ipregistry_parsed[abuser]=$(provider_merge_boolean_signals \
  "$(print -rn -- "$response"|jq -r 'if .security.is_abuser == null then empty else .security.is_abuser end')" \
  "$(print -rn -- "$response"|jq -r 'if .security.is_attacker == null then empty else .security.is_attacker end')" \
  "$(print -rn -- "$response"|jq -r 'if .security.is_threat == null then empty else .security.is_threat end')")
ipregistry_parsed[status]="ok"
return 0
}

db_ipregistry(){
ipregistry=()
ipregistry[status]="not_configured"
typeset api_key="${provider_credentials[IPREGISTRY_API_KEY]:-}"
[[ -n "$api_key" ]]||return 0
show_progress "${sinfo[database]}Ipregistry official API"
typeset RESPONSE wire_response
wire_response=$(curl_with_secret_header "Authorization" "ApiKey $api_key" \
  "https://api.ipregistry.co/$IP" $CurlARG -sS -$1 -m 10 \
  --max-filesize 262144 --write-out $'\n%{http_code}' 2>/dev/null)
provider_decode_http_response "$wire_response" "$?"
ipregistry[status]="${provider_http_response[status]}"
[[ "${ipregistry[status]}" == ok ]]||return 0
RESPONSE="${provider_http_response[body]}"
if ipregistry_parse_response "$RESPONSE" "$IP";then
ipregistry[status]="ok"
ipregistry[source]="official_api"
ipregistry[usetype]="${ipregistry_parsed[usage_type]}"
ipregistry[comtype]="${ipregistry_parsed[company_type]}"
ipregistry[susetype]=$(styled_provider_type "${ipregistry[usetype]}")
ipregistry[scomtype]=$(styled_provider_type "${ipregistry[comtype]}")
ipregistry[countrycode]="${ipregistry_parsed[country_code]}"
ipregistry[proxy]="${ipregistry_parsed[proxy]}"
ipregistry[vpn]="${ipregistry_parsed[vpn]}"
ipregistry[tor]="${ipregistry_parsed[tor]}"
ipregistry[server]="${ipregistry_parsed[server]}"
ipregistry[abuser]="${ipregistry_parsed[abuser]}"
else
ipregistry[status]=invalid_response
fi
}
