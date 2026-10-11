# Official APIv2 CHECK response; no reporting/write endpoint is used.
abuseipdb_response_is_valid(){
emulate -LR zsh
print -rn -- "$1"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg target "$2" '
  include "json_values";
  type == "object" and .errors == null and (.data | type == "object") and
  .data.ipAddress == $target and
  (.data.abuseConfidenceScore | type == "number" and floor == . and . >= 0 and . <= 100) and
  text_or_null(.data.usageType; 128) and
  (.data.countryCode == null or (.data.countryCode | type == "string" and test("^[A-Z]{2}$")))
' >/dev/null 2>&1
}
