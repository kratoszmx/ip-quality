# Strict parser for ipapi.is's public IP intelligence response.
#
# The endpoint has returned schema-drifted scalar values for nested sections in
# the past.  Validate those sections before reading child fields so an upstream
# response can become unavailable evidence without emitting jq diagnostics.

typeset -gA ipapi_parsed=()

ipapi_parse_response(){
emulate -LR zsh
typeset response="$1"

ipapi_parsed=()
print -rn -- "$response"|jq -e '
  def valid_type_field($value):
    if $value == null then true
    elif ($value | type) != "object" then false
    elif $value.type == null then true
    else (($value.type | type) == "string" and ($value.type | length) <= 64)
    end;
  def valid_company($value):
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
  type == "object" and
  valid_type_field(.asn) and
  valid_company(.company) and
  valid_location(.location) and
  ([.is_proxy, .is_tor, .is_vpn, .is_datacenter, .is_abuser, .is_crawler]
    | all(. == null or type == "boolean"))
' >/dev/null 2>&1||return 1

ipapi_parsed[usage_type]=$(print -rn -- "$response"|jq -r 'if (.asn|type) == "object" then (.asn.type // empty) else empty end')
ipapi_parsed[company_type]=$(print -rn -- "$response"|jq -r 'if (.company|type) == "object" then (.company.type // empty) else empty end')
ipapi_parsed[score_text]=$(print -rn -- "$response"|jq -r 'if (.company|type) == "object" then (if .company.abuser_score == null then empty else (.company.abuser_score|tostring) end) else empty end')
ipapi_parsed[country_code]=$(print -rn -- "$response"|jq -r 'if (.location|type) == "object" then (.location.country_code // empty) else empty end')
ipapi_parsed[proxy]=$(print -rn -- "$response"|jq -r 'if .is_proxy == null then empty else .is_proxy end')
ipapi_parsed[tor]=$(print -rn -- "$response"|jq -r 'if .is_tor == null then empty else .is_tor end')
ipapi_parsed[vpn]=$(print -rn -- "$response"|jq -r 'if .is_vpn == null then empty else .is_vpn end')
ipapi_parsed[server]=$(print -rn -- "$response"|jq -r 'if .is_datacenter == null then empty else .is_datacenter end')
ipapi_parsed[abuser]=$(print -rn -- "$response"|jq -r 'if .is_abuser == null then empty else .is_abuser end')
ipapi_parsed[robot]=$(print -rn -- "$response"|jq -r 'if .is_crawler == null then empty else .is_crawler end')
ipapi_parsed[status]="ok"
return 0
}
