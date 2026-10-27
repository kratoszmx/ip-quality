# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# The official free API supplies geography only; it cannot replace risk flags.
# Parsers use provider_json_fields; standalone fixture runs load it here.
(( ${+functions[provider_json_fields]} ))||source "${${(%):-%x}:A:h:h}/common/provider_values.zsh"
ipdata_free_response_is_valid(){
emulate -LR zsh
print -rn -- "$1"|jq -se --arg target "$2" '
  length == 1 and (.[0] |
  type == "object" and .ip == $target and .message == null and .error == null and
  (.country | type == "string" and test("^[A-Z]{2}$")))
' >/dev/null 2>&1
}

ipdata_response_is_valid(){
emulate -LR zsh
print -rn -- "$1"|jq -L "${${(%):-%x}:A:h:h}/common" -se --arg target "$2" '
  include "json_values";
  length == 1 and (.[0] |
  type == "object" and .ip == $target and .message == null and .error == null and
  (.country_code | type == "string" and test("^[A-Z]{2}$")) and
  (.threat | type == "object") and
  ([.threat.is_proxy, .threat.is_vpn, .threat.is_tor, .threat.is_datacenter,
    .threat.is_threat, .threat.is_known_abuser, .threat.is_known_attacker] |
    all(boolean_or_null(.)) and any(. != null)))
' >/dev/null 2>&1
}

db_ipdata(){
show_progress "${sinfo[database]}ipdata"
ipdata=()
ipdata[source]=check_place_relay
check_place_fetch_json "$1" "$IP" "db=ipdata"||true
ipdata[status]="$PROVIDER_RESPONSE_STATUS"
local RESPONSE="$PROVIDER_RESPONSE_BODY"
if [[ "${ipdata[status]}" == ok ]] && ! ipdata_response_is_valid "$RESPONSE" "$IP";then
ipdata[status]=invalid_response
fi
if [[ "${ipdata[status]}" != ok ]];then
ipdata[relay_status]="${ipdata[status]}"
ipdata[source]=official_free_api
provider_fetch_public_json "$1" "https://ipdata.free/$IP" 262144 --max-redirs 0||true
ipdata[status]="$PROVIDER_RESPONSE_STATUS"
[[ "${ipdata[status]}" == ok ]]||return 0
RESPONSE="$PROVIDER_RESPONSE_BODY"
if ! ipdata_free_response_is_valid "$RESPONSE" "$IP";then
ipdata[status]=invalid_response
return 0
fi
ipdata[countrycode]=$(print -rn -- "$RESPONSE"|jq -r '.country')
ipdata[risk_status]=not_provided
ipdata[reason]=free_geolocation_only
return 0
fi
ipdata[risk_status]=ok
provider_json_fields "$RESPONSE" '
  ([.country_code] | if length == 0 then "" else .[0] end),
  ([.threat.is_proxy] | if length == 0 then "" else .[0] end),
  ([.threat.is_vpn] | if length == 0 then "" else .[0] end),
  ([.threat.is_tor] | if length == 0 then "" else .[0] end),
  ([.threat.is_datacenter] | if length == 0 then "" else .[0] end)' countrycode proxy vpn tor server||true
ipdata+=("${(@kv)provider_fields[@]}")
ipdata[abuser1]=$(print -rn -- "$RESPONSE"|jq -r '.threat.is_threat')
ipdata[abuser2]=$(print -rn -- "$RESPONSE"|jq -r '.threat.is_known_abuser')
ipdata[abuser3]=$(print -rn -- "$RESPONSE"|jq -r '.threat.is_known_attacker')
ipdata[abuser]=$(provider_merge_boolean_signals "${ipdata[abuser1]}" "${ipdata[abuser2]}" "${ipdata[abuser3]}")
}
