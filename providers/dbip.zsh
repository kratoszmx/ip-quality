# DB-IP's permanent free endpoint exposes geography only. Paid security fields
# are never inferred from missing values, or consumed from an unexpected body.
typeset -gA dbip_parsed=()

dbip_parse_response(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1" expected_ip="$2"
dbip_parsed=()
print -rn -- "$response"|jq -e --arg expected "$expected_ip" '
  def text_or_null($value):
    $value == null or (($value | type) == "string" and ($value | length) <= 256 and ($value | test("[\u0000-\u001f\u007f]") | not));
  type == "object" and .error == null and .errorCode == null and
  (.ipAddress | type == "string" and . == $expected) and
  (.countryCode | type == "string" and test("^[A-Z]{2}$")) and
  text_or_null(.countryName) and text_or_null(.stateProv) and text_or_null(.city)
' >/dev/null 2>&1||return 1
dbip_parsed[ip]=$(print -rn -- "$response"|jq -r '.ipAddress')
dbip_parsed[country_code]=$(print -rn -- "$response"|jq -r '.countryCode')
dbip_parsed[country]=$(print -rn -- "$response"|jq -r '.countryName // empty')
dbip_parsed[region]=$(print -rn -- "$response"|jq -r '.stateProv // empty')
dbip_parsed[city]=$(print -rn -- "$response"|jq -r '.city // empty')
dbip_parsed[status]=ok
}
