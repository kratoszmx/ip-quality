# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# Strict parser for Cloudflare Security Center IP Intelligence responses.
#
# The official endpoint returns ASN infrastructure context and named threat
# categories. It does not return a universal numeric reputation score, so the
# categories remain an independent observation.

typeset -gA cloudflare_parsed=()

cloudflare_parse_response(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset expected_ip="$2"

cloudflare_parsed=()
print -rn -- "$response"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg expected "$expected_ip" '
  include "json_values";
  def network_or_null($value):
    text_or_null($value; 256) or (($value | type) == "number" and ($value | floor) == $value and $value >= 1 and $value <= 4294967295);
  type == "object" and
  .success == true and
  (.result | type == "array" and length <= 1) and
  all(.result[];
    type == "object" and
    text_or_null(.ip; 128) and
    (.ip == null or .ip == $expected) and
    (.belongs_to_ref == null or
      ((.belongs_to_ref | type) == "object" and
        text_or_null(.belongs_to_ref.id; 256) and
        text_or_null(.belongs_to_ref.country; 64) and
        text_or_null(.belongs_to_ref.description; 256) and
        text_or_null(.belongs_to_ref.type; 64) and
        network_or_null(.belongs_to_ref.value))) and
    (.risk_types == null or
      (.risk_types |
        type == "array" and length <= 128 and
        all(.[]; type == "object" and integer_or_null(.id; 0; 2147483647) and
          text_or_null(.name; 128) and integer_or_null(.super_category_id; 0; 2147483647)))))
' >/dev/null 2>&1||return 1

cloudflare_parsed[status]="ok"
if [[ $(print -rn -- "$response"|jq -r '.result|length') == "0" ]];then
cloudflare_parsed[status]="not_found"
return 0
fi
cloudflare_parsed[ip]=$(print -rn -- "$response"|jq -r '.result[0].ip // empty')
cloudflare_parsed[country_code]=$(print -rn -- "$response"|jq -r '.result[0].belongs_to_ref.country // empty')
cloudflare_parsed[network]=$(print -rn -- "$response"|jq -r '.result[0].belongs_to_ref.value | if type == "number" then "AS\(.)" else . // empty end')
cloudflare_parsed[organization]=$(print -rn -- "$response"|jq -r '.result[0].belongs_to_ref.description // empty')
cloudflare_parsed[infrastructure_type]=$(print -rn -- "$response"|jq -r '.result[0].belongs_to_ref.type // empty')
cloudflare_parsed[threat_categories]=$(print -rn -- "$response"|jq -r '[.result[0].risk_types[]?.name // empty] | map(select(type == "string" and length > 0)) | join(", ")')
cloudflare_parsed[threat_categories_json]=$(print -rn -- "$response"|jq -c 'if (.result[0].risk_types | type) == "array" then [.result[0].risk_types[]?.name // empty] | map(select(type == "string" and length > 0)) else null end')
return 0
}

db_cloudflare(){
show_progress "${sinfo[database]}Cloudflare IP Intelligence"
cloudflare=()
cloudflare[status]="not_configured"
typeset api_token="${provider_credentials[CLOUDFLARE_API_TOKEN]:-}"
typeset account_id="${provider_credentials[CLOUDFLARE_ACCOUNT_ID]:-}"
[[ -n "$api_token" || -n "$account_id" ]]||return 0
if [[ -z "$api_token" || -z "$account_id" ]];then
cloudflare[status]="invalid_configuration"
return 0
fi
cloudflare[status]="unknown"
local query_name="ipv4"
[[ "$IP" == *:* ]]&&query_name="ipv6"
local endpoint="https://api.cloudflare.com/client/v4/accounts/$account_id/intel/ip?$query_name=$IP"
local response_body
query_route_begin "$1" system system
query_route_request "$endpoint" 131072 Authorization "Bearer $api_token"||true
cloudflare[query_route]="${query_route[route]}"
cloudflare[primary_status]="${query_route[primary_status]}"
cloudflare[status]="${provider_http_response[status]}"
[[ "${cloudflare[status]}" == ok ]]||return 0
response_body="${provider_http_response[body]}"
if ! provider_json_is_object "$response_body";then
cloudflare[status]="invalid_response"
return 0
fi
if ! cloudflare_parse_response "$response_body" "$IP";then
cloudflare[status]="invalid_response"
return 0
fi
cloudflare[status]="${cloudflare_parsed[status]}"
cloudflare[source]="official_api"
cloudflare[ip]="${cloudflare_parsed[ip]}"
cloudflare[countrycode]="${cloudflare_parsed[country_code]}"
cloudflare[network]="${cloudflare_parsed[network]}"
cloudflare[org]="${cloudflare_parsed[organization]}"
cloudflare[infrastructure]="${cloudflare_parsed[infrastructure_type]}"
cloudflare[threats]="${cloudflare_parsed[threat_categories]}"
cloudflare[threats_json]="${cloudflare_parsed[threat_categories_json]:-null}"
}
