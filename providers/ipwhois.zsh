# IPWHOIS public website demo; missing security flags remain unknown.

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
        | all(. == null or type == "boolean"))))
' >/dev/null 2>&1||return 1

ipwhois_parsed[country_code]=$(print -rn -- "$response"|jq -r 'if (.country_code|type) == "string" then .country_code else empty end')
ipwhois_parsed[asn]=$(print -rn -- "$response"|jq -r 'if (.connection|type) == "object" and .connection.asn != null then (.connection.asn|tostring) else empty end')
ipwhois_parsed[organization]=$(print -rn -- "$response"|jq -r 'if (.connection|type) == "object" then (.connection.org // empty) else empty end')
ipwhois_parsed[isp]=$(print -rn -- "$response"|jq -r 'if (.connection|type) == "object" then (.connection.isp // empty) else empty end')
ipwhois_parsed[timezone]=$(print -rn -- "$response"|jq -r 'if (.timezone|type) == "object" then (.timezone.id // empty) else empty end')
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
