# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# Strict parser for ipapi.is's keyed and anonymous IP intelligence responses.
#
# The no-key free endpoint intentionally returns a flat, minimal response while
# a keyed response uses nested ASN/company/location objects.  Validate both
# contracts before reading child fields so rate-limit/error bodies and schema
# drift become unavailable evidence without emitting jq diagnostics.
# Parsers use provider_json_fields; standalone fixture runs load it here.
(( ${+functions[provider_json_fields]} ))||source "${${(%):-%x}:A:h:h}/common/provider_values.zsh"

typeset -gA ipapi_parsed=()

ipapi_parse_response(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset expected_ip="${2:-}"

ipapi_parsed=()
print -rn -- "$response"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg expected "$expected_ip" '
  include "json_values";
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
      | all(boolean_or_null(.)));
  def valid_ip:
    (.ip | type == "string" and length <= 128 and (contains("\u0000") | not));
  def valid_full_response:
    .docs == null and valid_asn_object(.asn) and
    valid_company_object(.company) and
    valid_location(.location) and
    valid_boolean_fields and
    ((.asn | type) == "object" or (.company | type) == "object" or (.location | type) == "object");
  def valid_anonymous_response:
    valid_ip and .location == null and
    ((.asn == null) or text_or_null(.asn; 256) or integer_or_null(.asn; 0; 4294967295)) and
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

# One pass; missing optional values stay empty, booleans keep false.
provider_json_fields "$response" '.ip,
  (if (.docs|type) == "string" or (.asn|type) == "string" or (.asn|type) == "number" or (.company|type) == "string" then "anonymous" else "full" end),
  (if (.asn|type) == "object" then (.asn.type // "") else "" end),
  (if (.company|type) == "object" then (if .company.abuser_score == null then "" else (.company.abuser_score|tostring) end) else "" end),
  (if (.company|type) == "object" then (.company.type // "") else "" end),
  (if (.location|type) == "object" then (.location.country_code // "") elif (.country|type) == "string" and (.country|length) == 2 then .country else "" end),
  (if (.asn|type) == "string" or (.asn|type) == "number" then (.asn|tostring) else "" end),
  ([.company, .country, .city, .region, .timezone] | map(if type == "string" then . else "" end) | .[]),
  ([.is_proxy, .is_tor, .is_vpn, .is_datacenter, .is_abuser, .is_crawler] | map(if . == null then "" else . end) | .[])' \
  ip mode usage_type score_text company_type country_code anonymous_asn anonymous_company anonymous_country \
  anonymous_city anonymous_region anonymous_timezone proxy tor vpn server abuser robot||return 1
typeset field
for field in ip mode usage_type company_type score_text country_code anonymous_asn anonymous_company \
  anonymous_country anonymous_city anonymous_region anonymous_timezone;do
ipapi_parsed[$field]="${provider_fields[$field]}"
done
if [[ "${ipapi_parsed[mode]}" == "anonymous" ]];then
ipapi_parsed[status]="ok"
return 0
fi
for field in proxy tor vpn server abuser robot;do
ipapi_parsed[$field]="${provider_fields[$field]}"
done
ipapi_parsed[status]="ok"
return 0
}

db_ipapi(){
show_progress "${sinfo[database]}ipapi"
ipapi=()
ipapi[status]="unknown"
typeset api_key="${provider_credentials[IPAPI_API_KEY]:-}"
ipapi[credential_mode]=anonymous
[[ -n "$api_key" ]]&&ipapi[credential_mode]=key
typeset endpoint="https://api.ipapi.is/?q=$IP"
[[ -n "$api_key" ]]&&endpoint="$endpoint&key=$api_key"
typeset wire_response RESPONSE
if [[ -n "$api_key" ]];then
wire_response=$(curl_with_secret_url "$endpoint" $CurlARG -sS -L -$1 -m 10 \
  --max-filesize 262144 --write-out $'\n%{http_code}' 2>/dev/null)
else
wire_response=$(curl -q $CurlARG -sS -L -$1 -m 10 -H 'origin: https://ipapi.is' \
  --max-filesize 262144 --write-out $'\n%{http_code}' "$endpoint" 2>/dev/null)
fi
provider_decode_http_response "$wire_response" "$?"
ipapi[status]="${provider_http_response[status]}"
[[ "${ipapi[status]}" == ok ]]||return 1
RESPONSE="${provider_http_response[body]}"
if ! ipapi_parse_response "$RESPONSE" "$IP";then
ipapi[status]="invalid_response"
return 1
fi
ipapi[status]="ok"
ipapi[source]="public_api"
ipapi[mode]="${ipapi_parsed[mode]}"
ipapi[ip]="${ipapi_parsed[ip]}"
ipapi[anonymous_asn]="${ipapi_parsed[anonymous_asn]}"
ipapi[anonymous_company]="${ipapi_parsed[anonymous_company]}"
ipapi[anonymous_country]="${ipapi_parsed[anonymous_country]}"
ipapi[anonymous_city]="${ipapi_parsed[anonymous_city]}"
ipapi[anonymous_region]="${ipapi_parsed[anonymous_region]}"
ipapi[anonymous_timezone]="${ipapi_parsed[anonymous_timezone]}"
ipapi[usetype]="${ipapi_parsed[usage_type]}"
ipapi[comtype]="${ipapi_parsed[company_type]}"
ipapi[susetype]=$(styled_provider_type "${ipapi[usetype]}")
ipapi[scomtype]=$(styled_provider_type "${ipapi[comtype]}")
ipapi[scoretext]="${ipapi_parsed[score_text]}"
# "0.0012 (Low)": the first word is the ratio, the parenthesized word its label.
local score_word score_rest
read -r score_word score_rest <<< "${ipapi[scoretext]}"
ipapi[scorenum]="$score_word"
ipapi[risktext]=""
if [[ "${ipapi[scoretext]}" == *[\(\)]* ]];then
score_rest="${ipapi[scoretext]#*[\(\)]}"
ipapi[risktext]="${score_rest%%[\(\)]*}"
fi
if is_nonnegative_decimal "${ipapi[scorenum]}";then
ipapi[score]=$(printf '%.2f%%' "$(( ${ipapi[scorenum]} * 100.0 ))")
case ${ipapi[risktext]} in
"Very Low")ipapi[risk]="${sscore[verylow]}"
;;
"Low")ipapi[risk]="${sscore[low]}"
;;
"Elevated")ipapi[risk]="${sscore[elevated]}"
;;
"High")ipapi[risk]="${sscore[high]}"
;;
"Very High")ipapi[risk]="${sscore[veryhigh]}"
esac
else
ipapi[scorenum]=""
ipapi[score]=""
ipapi[risk]=""
fi
ipapi[countrycode]="${ipapi_parsed[country_code]}"
ipapi[proxy]="${ipapi_parsed[proxy]}"
ipapi[tor]="${ipapi_parsed[tor]}"
ipapi[vpn]="${ipapi_parsed[vpn]}"
ipapi[server]="${ipapi_parsed[server]}"
ipapi[abuser]="${ipapi_parsed[abuser]}"
ipapi[robot]="${ipapi_parsed[robot]}"
ipapi[risk_status]=not_provided
provider_has_observation "${ipapi[proxy]}" "${ipapi[vpn]}" "${ipapi[tor]}" "${ipapi[server]}" "${ipapi[abuser]}" "${ipapi[robot]}"&&ipapi[risk_status]=ok
return 0
}
