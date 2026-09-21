# Strict parser for the free ipwho.is IP intelligence response.
#
# The free endpoint supplies location, network, and timezone context. Its
# security fields are plan-gated, so this adapter deliberately does not invent
# proxy, VPN, Tor, hosting, or risk observations from their absence.

typeset -gA ipwhois_parsed=()

ipwhois_parse_response(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset expected_ip="$2"

ipwhois_parsed=()
print -rn -- "$response"|jq -e --arg expected "$expected_ip" '
  def text_or_null($value; $max):
    $value == null or (($value | type) == "string" and ($value | length) <= $max and ($value | contains("\u0000") | not));
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
    ((.timezone | type) == "object" and text_or_null(.timezone.id; 128)))
' >/dev/null 2>&1||return 1

ipwhois_parsed[country_code]=$(print -rn -- "$response"|jq -r 'if (.country_code|type) == "string" then .country_code else empty end')
ipwhois_parsed[asn]=$(print -rn -- "$response"|jq -r 'if (.connection|type) == "object" and .connection.asn != null then (.connection.asn|tostring) else empty end')
ipwhois_parsed[organization]=$(print -rn -- "$response"|jq -r 'if (.connection|type) == "object" then (.connection.org // empty) else empty end')
ipwhois_parsed[isp]=$(print -rn -- "$response"|jq -r 'if (.connection|type) == "object" then (.connection.isp // empty) else empty end')
ipwhois_parsed[timezone]=$(print -rn -- "$response"|jq -r 'if (.timezone|type) == "object" then (.timezone.id // empty) else empty end')
ipwhois_parsed[status]="ok"
return 0
}
