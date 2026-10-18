# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# IPWHOIS public website demo; missing security flags remain unknown.
# Parsers use provider_json_fields; standalone fixture runs load it here.
(( ${+functions[provider_json_fields]} ))||source "${${(%):-%x}:A:h:h}/common/provider_values.zsh"

typeset -gA ipwhois_parsed=()

ipwhois_parse_response(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset expected_ip="$2"

ipwhois_parsed=()
if print -rn -- "$response"|jq -e 'type == "object" and .success == false' >/dev/null 2>&1;then
ipwhois_parsed[status]=upstream_error
if print -rn -- "$response"|jq -e '.message | type == "string" and test("rate limit|too many requests"; "i")' >/dev/null 2>&1;then
ipwhois_parsed[status]=rate_limited
fi
return 1
fi
print -rn -- "$response"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg expected "$expected_ip" '
  include "json_values";
  def asn_or_null($value):
    $value == null or
      (($value | type) == "number" and $value >= 0 and $value <= 4294967295 and ($value | floor) == $value) or
      (($value | type) == "string" and ($value | test("^[0-9]{1,10}$")) and ($value | tonumber) <= 4294967295);
  type == "object" and
  .success == true and
  (.ip | type == "string" and . == $expected and length <= 128) and
  text_or_null(.country_code; 16) and
  (.connection == null or
    ((.connection | type) == "object" and
      asn_or_null(.connection.asn) and
      text_or_null(.connection.org; 256) and
      text_or_null(.connection.isp; 256))) and
  (.timezone == null or
    ((.timezone | type) == "object" and text_or_null(.timezone.id; 128))) and
  (.security == null or
    ((.security | type) == "object" and
      ([.security.proxy, .security.vpn, .security.tor, .security.hosting]
        | all(boolean_or_null(.)))))
' >/dev/null 2>&1||return 1

provider_json_fields "$response" '
  ([if (.country_code|type) == "string" then .country_code else empty end] | if length == 0 then "" else .[0] end),
  ([if (.connection|type) == "object" and .connection.asn != null then (.connection.asn|tostring) else empty end] | if length == 0 then "" else .[0] end),
  ([if (.connection|type) == "object" then (.connection.org // empty) else empty end] | if length == 0 then "" else .[0] end),
  ([if (.connection|type) == "object" then (.connection.isp // empty) else empty end] | if length == 0 then "" else .[0] end),
  ([if (.timezone|type) == "object" then (.timezone.id // empty) else empty end] | if length == 0 then "" else .[0] end)' country_code asn organization isp timezone||return 1
ipwhois_parsed+=("${(@kv)provider_fields[@]}")
ipwhois_parsed[risk_status]=not_provided
typeset field
for field in proxy vpn tor hosting;do
ipwhois_parsed[$field]=$(print -rn -- "$response"|jq -r --arg key "$field" 'if .security[$key] == null then empty else .security[$key] end')
done
if print -rn -- "$response"|jq -e '[.security.proxy, .security.vpn, .security.tor, .security.hosting] | any(. != null)' >/dev/null 2>&1;then
ipwhois_parsed[risk_status]=ok
fi
ipwhois_parsed[status]="ok"
return 0
}

db_ipwhois(){
show_progress "${sinfo[database]}IPWHOIS public demo"
ipwhois=()
ipwhois[status]="unknown"
ipwhois[source]="public_demo"
provider_fetch_public_json "$1" "https://ipwhois.io/demo?ip=$IP" 131072 \
  -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36' \
  -H 'Accept: */*' -H 'Origin: https://ipwhois.io' -H 'Referer: https://ipwhois.io/' \
  -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin'||true
ipwhois[status]="$PROVIDER_RESPONSE_STATUS"
local RESPONSE="$PROVIDER_RESPONSE_BODY"
[[ "${ipwhois[status]}" == "ok" ]]||return 0
if ipwhois_parse_response "$RESPONSE" "$IP";then
ipwhois[status]="ok"
ipwhois[risk_status]="${ipwhois_parsed[risk_status]}"
ipwhois[countrycode]="${ipwhois_parsed[country_code]}"
ipwhois[asn]="${ipwhois_parsed[asn]}"
ipwhois[org]="${ipwhois_parsed[organization]}"
ipwhois[isp]="${ipwhois_parsed[isp]}"
ipwhois[timezone]="${ipwhois_parsed[timezone]}"
ipwhois[proxy]="${ipwhois_parsed[proxy]}"
ipwhois[vpn]="${ipwhois_parsed[vpn]}"
ipwhois[tor]="${ipwhois_parsed[tor]}"
ipwhois[server]="${ipwhois_parsed[hosting]}"
else
ipwhois[status]="${ipwhois_parsed[status]:-invalid_response}"
fi
}
