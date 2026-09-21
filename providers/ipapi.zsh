# Strict parser for ipapi.is's keyed and anonymous IP intelligence responses.
#
# The no-key free endpoint intentionally returns a flat, minimal response while
# a keyed response uses nested ASN/company/location objects.  Validate both
# contracts before reading child fields so rate-limit/error bodies and schema
# drift become unavailable evidence without emitting jq diagnostics.

typeset -gA ipapi_parsed=()

ipapi_parse_response(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset expected_ip="${2:-}"

ipapi_parsed=()
print -rn -- "$response"|jq -e --arg expected "$expected_ip" '
  def text_or_null($value; $max):
    $value == null or (($value | type) == "string" and ($value | length) <= $max and ($value | contains("\u0000") | not));
  def integer_or_null($value):
    $value == null or (($value | type) == "number" and ($value | floor) == $value and $value >= 0 and $value <= 4294967295);
  def valid_asn_object($value):
    if $value == null then true
    elif ($value | type) != "object" then false
    elif $value.type == null then true
    else (($value.type | type) == "string" and ($value.type | length) <= 64)
    end;
  def valid_company_object($value):
    if $value == null then true
    elif ($value | type) != "object" then false
    elif ($value.type != null and (($value.type | type) != "string" or ($value.type | length) > 64)) then false
    elif $value.abuser_score == null then true
    elif ($value.abuser_score | type) == "string" then ($value.abuser_score | length) <= 256
    elif ($value.abuser_score | type) == "number" then ($value.abuser_score >= 0 and $value.abuser_score <= 1)
    else false
    end;
  def valid_location($value):
    if $value == null then true
    elif ($value | type) != "object" then false
    elif $value.country_code == null then true
    else (($value.country_code | type) == "string" and ($value.country_code | length) <= 16)
    end;
  def valid_boolean_fields:
    ([.is_bogon, .is_mobile, .is_satellite, .is_proxy, .is_tor, .is_vpn,
      .is_datacenter, .is_abuser, .is_crawler]
      | all(. == null or type == "boolean"));
  def valid_ip:
    (.ip | type == "string" and length <= 128 and (contains("\u0000") | not));
  def valid_full_response:
    valid_asn_object(.asn) and
    valid_company_object(.company) and
    valid_location(.location) and
    valid_boolean_fields and
    ((.asn | type) == "object" or (.company | type) == "object" or (.location | type) == "object");
  def valid_anonymous_response:
    valid_ip and
    ((.asn == null) or text_or_null(.asn; 256) or integer_or_null(.asn)) and
    ((.company == null) or text_or_null(.company; 256)) and
    text_or_null(.city; 128) and
    text_or_null(.region; 128) and
    text_or_null(.country; 128) and
    text_or_null(.timezone; 128) and
    text_or_null(.docs; 512) and
    valid_boolean_fields and
    ((.asn | type) == "string" or (.asn | type) == "number" or
      (.company | type) == "string" or .docs != null or .country != null or
      .city != null or .region != null or .timezone != null);
  type == "object" and
  (.error == null and .error_code == null) and
  ((.ip == null and $expected == "") or (valid_ip and ($expected == "" or .ip == $expected))) and
  (valid_full_response or valid_anonymous_response)
' >/dev/null 2>&1||return 1

ipapi_parsed[ip]=$(print -rn -- "$response"|jq -r '.ip')
ipapi_parsed[mode]="full"
if print -rn -- "$response"|jq -e '(.docs|type) == "string" or (.asn|type) == "string" or (.asn|type) == "number" or (.company|type) == "string"' >/dev/null 2>&1;then
ipapi_parsed[mode]="anonymous"
fi
ipapi_parsed[usage_type]=$(print -rn -- "$response"|jq -r 'if (.asn|type) == "object" then (.asn.type // empty) else empty end')
ipapi_parsed[company_type]=$(print -rn -- "$response"|jq -r 'if (.company|type) == "object" then (.company.type // empty) else empty end')
ipapi_parsed[score_text]=$(print -rn -- "$response"|jq -r 'if (.company|type) == "object" then (if .company.abuser_score == null then empty else (.company.abuser_score|tostring) end) else empty end')
ipapi_parsed[country_code]=$(print -rn -- "$response"|jq -r 'if (.location|type) == "object" then (.location.country_code // empty) elif (.country|type) == "string" and (.country|length) == 2 then .country else empty end')
ipapi_parsed[anonymous_asn]=$(print -rn -- "$response"|jq -r 'if (.asn|type) == "string" or (.asn|type) == "number" then (.asn|tostring) else empty end')
ipapi_parsed[anonymous_company]=$(print -rn -- "$response"|jq -r 'if (.company|type) == "string" then .company else empty end')
ipapi_parsed[anonymous_country]=$(print -rn -- "$response"|jq -r 'if (.country|type) == "string" then .country else empty end')
ipapi_parsed[anonymous_city]=$(print -rn -- "$response"|jq -r 'if (.city|type) == "string" then .city else empty end')
ipapi_parsed[anonymous_region]=$(print -rn -- "$response"|jq -r 'if (.region|type) == "string" then .region else empty end')
ipapi_parsed[anonymous_timezone]=$(print -rn -- "$response"|jq -r 'if (.timezone|type) == "string" then .timezone else empty end')
ipapi_parsed[proxy]=$(print -rn -- "$response"|jq -r 'if .is_proxy == null then empty else .is_proxy end')
ipapi_parsed[tor]=$(print -rn -- "$response"|jq -r 'if .is_tor == null then empty else .is_tor end')
ipapi_parsed[vpn]=$(print -rn -- "$response"|jq -r 'if .is_vpn == null then empty else .is_vpn end')
ipapi_parsed[server]=$(print -rn -- "$response"|jq -r 'if .is_datacenter == null then empty else .is_datacenter end')
ipapi_parsed[abuser]=$(print -rn -- "$response"|jq -r 'if .is_abuser == null then empty else .is_abuser end')
ipapi_parsed[robot]=$(print -rn -- "$response"|jq -r 'if .is_crawler == null then empty else .is_crawler end')
ipapi_parsed[status]="ok"
return 0
}
