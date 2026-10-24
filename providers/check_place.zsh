# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# Check.Place owns several relay datasets. A confirmed block/rate limit pauses
# this run's remaining relay requests for the same target and address family.
# Parsers use provider_json_fields; standalone fixture runs load it here.
(( ${+functions[provider_json_fields]} ))||source "${${(%):-%x}:A:h:h}/common/provider_values.zsh"
typeset -gA check_place_pauses
check_place_pauses=()

check_place_fetch_json(){
emulate -LR zsh
typeset address_family="$1" target="$2" query="$3" maximum_bytes="${4:-262144}"
typeset pause_key="$address_family/$target" request_result
PROVIDER_RESPONSE_BODY=""
if [[ -n "${check_place_pauses[$pause_key]:-}" ]];then
PROVIDER_RESPONSE_STATUS="skipped_relay_${check_place_pauses[$pause_key]}"
return 1
fi
provider_fetch_public_json "$address_family" "https://ipinfo.check.place/$target?$query" "$maximum_bytes"
request_result=$?
case "$PROVIDER_RESPONSE_STATUS" in
cloudflare_blocked|rate_limited)check_place_pauses[$pause_key]="$PROVIDER_RESPONSE_STATUS" ;;
esac
return "$request_result"
}

maxmind_response_is_valid(){
emulate -LR zsh
print -rn -- "$1"|jq -L "${${(%):-%x}:A:h:h}/common" -es '
  include "json_values";
  def object_or_null: . == null or type == "object";
  def decimal_or_null:
    . == null or type == "number" or
    (type == "string" and length <= 32 and test("^-?[0-9]+(\\.[0-9]+)?$"));
  length == 1 and (.[0] |
  type == "object" and .error == null and .success != false and
  ([.ASN, .City, .Country, .City.Continent, .City.Country, .City.Location,
    .Country.RegisteredCountry] | all(object_or_null)) and
  (.City.Subdivisions == null or
    ((.City.Subdivisions | type) == "array" and
     (.City.Subdivisions | all(object_or_null)))) and
  (integer_or_null(.ASN.AutonomousSystemNumber; 0; 4294967295) or
    ((.ASN.AutonomousSystemNumber | type) == "string" and
     (.ASN.AutonomousSystemNumber | test("^[0-9]{1,10}$")) and
     (.ASN.AutonomousSystemNumber | tonumber) <= 4294967295)) and
  ([.City.Latitude, .City.Longitude, .City.AccuracyRadius] | all(decimal_or_null)) and
  ([.ASN.AutonomousSystemOrganization, .City.Name, .City.PostalCode,
    .City.Continent.Code, .City.Continent.Name, .City.Country.IsoCode,
    .City.Country.Name, .City.Location.TimeZone, .City.Subdivisions[]?.IsoCode,
    .City.Subdivisions[]?.Name, .Country.IsoCode, .Country.Name,
    .Country.RegisteredCountry.IsoCode, .Country.RegisteredCountry.Name]
    | all(text_or_null(.; 512))) and
  ([.ASN.AutonomousSystemNumber, .ASN.AutonomousSystemOrganization,
    .City.Name, .City.Latitude, .City.Longitude, .City.Country.IsoCode,
    .Country.IsoCode, .Country.Name] | any(. != null and . != "")))
' >/dev/null 2>&1
}

# Relay fields in display order; one jq pass per response (primary and English).
typeset -ga maxmind_field_names=(asn org city post lat lon rad continentcode continent
  citycountrycode citycountry timezone subcode sub countrycode country regcountrycode regcountry)
typeset -g maxmind_field_program='.ASN.AutonomousSystemNumber, .ASN.AutonomousSystemOrganization,
  .City.Name, .City.PostalCode, .City.Latitude, .City.Longitude, .City.AccuracyRadius,
  .City.Continent.Code, .City.Continent.Name, .City.Country.IsoCode, .City.Country.Name,
  .City.Location.TimeZone,
  (if (.City.Subdivisions | length) > 0 then .City.Subdivisions[0].IsoCode else "N/A" end),
  (if (.City.Subdivisions | length) > 0 then .City.Subdivisions[0].Name else "N/A" end),
  .Country.IsoCode, .Country.Name, .Country.RegisteredCountry.IsoCode, .Country.RegisteredCountry.Name'

db_maxmind_relay(){
show_progress "${sinfo[database]}Check.Place / MaxMind relay"
maxmind=()
basic_source=ipinfo
check_place_fetch_json "$1" "$IP" "lang=$YY"||true
maxmind[status]="$PROVIDER_RESPONSE_STATUS"
local RESPONSE="$PROVIDER_RESPONSE_BODY" field
[[ "${maxmind[status]}" == ok ]]||return 1
if ! maxmind_response_is_valid "$RESPONSE"||! provider_json_fields "$RESPONSE" "$maxmind_field_program" "${maxmind_field_names[@]}";then
maxmind[status]=invalid_response
return 1
fi
basic_source=maxmind
for field in "${maxmind_field_names[@]}";do
maxmind[$field]="${provider_fields[$field]}"
done
if [[ $YY != "en" ]];then
check_place_fetch_json "$1" "$IP" "lang=en"||true
local backup_response="$PROVIDER_RESPONSE_BODY"
# A failed translation must not erase valid primary fields or emit jq errors.
if [[ "$PROVIDER_RESPONSE_STATUS" == ok ]]&&maxmind_response_is_valid "$backup_response"&&
  provider_json_fields "$backup_response" "$maxmind_field_program" "${maxmind_field_names[@]}";then
for field in "${maxmind_field_names[@]}";do
[[ "${maxmind[$field]}" == "null" ]]&&maxmind[$field]="${provider_fields[$field]}"
done
fi
fi
if is_signed_decimal "${maxmind[lat]}"&&is_signed_decimal "${maxmind[lon]}"&&is_nonnegative_decimal "${maxmind[rad]}";then
maxmind[dms]=$(generate_dms "${maxmind[lat]}" "${maxmind[lon]}")
maxmind[map]=$(location_map_url "${maxmind[lat]}" "${maxmind[lon]}" "${maxmind[rad]}")
else
maxmind[dms]="null"
maxmind[map]="null"
fi
}
