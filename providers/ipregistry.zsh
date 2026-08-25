# Strict parser for Ipregistry's official IP Intelligence API.

typeset -gA ipregistry_parsed=()

ipregistry_parse_response(){
emulate -LR zsh
typeset response="$1"
typeset expected_ip="$2"

ipregistry_parsed=()
print -rn -- "$response"|jq -e --arg expected "$expected_ip" '
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
    | all(. == null or type == "boolean"))
' >/dev/null 2>&1||return 1

ipregistry_parsed[usage_type]=$(print -rn -- "$response"|jq -r '.connection.type // empty')
ipregistry_parsed[company_type]=$(print -rn -- "$response"|jq -r '.company.type // empty')
ipregistry_parsed[country_code]=$(print -rn -- "$response"|jq -r '.location.country.code // empty')
ipregistry_parsed[proxy]=$(print -rn -- "$response"|jq -r 'if .security.is_proxy == null then empty else .security.is_proxy end')
ipregistry_parsed[vpn]=$(print -rn -- "$response"|jq -r 'if .security.is_vpn == null then empty else .security.is_vpn end')
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
