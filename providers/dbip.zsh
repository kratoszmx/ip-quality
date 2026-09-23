# DB-IP public website demo; original threat labels, never invented scores.
typeset -gA dbip_parsed=()

dbip_parse_response(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1" expected_ip="$2"
dbip_parsed=()
print -rn -- "$response"|jq -e 'type == "object" and .status == "ok" and (.demoInfo | type == "object")' >/dev/null 2>&1||return 1
response=$(print -rn -- "$response"|jq -c '.demoInfo')
if print -rn -- "$response"|jq -e 'type == "object" and (.errorCode != null or .error != null)' >/dev/null 2>&1;then
dbip_parsed[status]=upstream_error
if print -rn -- "$response"|jq -e '.errorCode == "OVER_QUERY_LIMIT"' >/dev/null 2>&1;then
dbip_parsed[status]=rate_limited
fi
return 1
fi
print -rn -- "$response"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg expected "$expected_ip" '
  include "json_values";
  type == "object" and .error == null and .errorCode == null and
  (.ipAddress | type == "string" and . == $expected) and
  (.countryCode | type == "string" and test("^[A-Z]{2}$")) and
  text_or_null(.countryName; 256) and text_or_null(.stateProv; 256) and text_or_null(.city; 256) and
  (.threatLevel == null or
    (.threatLevel | type == "string" and test("^(low|medium|high)$"; "i")))
' >/dev/null 2>&1||return 1
dbip_parsed[ip]=$(print -rn -- "$response"|jq -r '.ipAddress')
dbip_parsed[country_code]=$(print -rn -- "$response"|jq -r '.countryCode')
dbip_parsed[country]=$(print -rn -- "$response"|jq -r '.countryName // empty')
dbip_parsed[region]=$(print -rn -- "$response"|jq -r '.stateProv // empty')
dbip_parsed[city]=$(print -rn -- "$response"|jq -r '.city // empty')
dbip_parsed[risk_status]=not_provided
dbip_parsed[threat_level]=$(print -rn -- "$response"|jq -r '.threatLevel // empty | ascii_downcase')
[[ -n "${dbip_parsed[threat_level]}" ]]&&dbip_parsed[risk_status]=ok
dbip_parsed[status]=ok
}
