# The website publishes a demo credential for its own public lookup. Discover it
# afresh, use it in memory once, and never treat it as an owned account/API key.
ipdata_demo_key_from_page(){
emulate -LR zsh
(( ${#1} <= 262144 ))||return 1
print -rn -- "$1"|jq -Rrse '
  [match("\\$\\.get\\(\"https://api\\.ipdata\\.co/\" \\+ ip \\+ \u0027\\?api-key=(?<key>[a-f0-9]{32,128})\u0027"; "g") | .captures[0].string] |
  select(length == 1) | .[0]
' 2>/dev/null
}

ipdata_response_is_valid(){
emulate -LR zsh
print -rn -- "$1"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg target "$2" '
  include "json_values";
  type == "object" and .ip == $target and .message == null and .error == null and
  (.country_code | type == "string" and test("^[A-Z]{2}$")) and
  (.threat | type == "object") and
  ([.threat.is_proxy, .threat.is_vpn, .threat.is_tor, .threat.is_datacenter,
    .threat.is_threat, .threat.is_known_abuser, .threat.is_known_attacker] |
    all(boolean_or_null(.)) and any(. != null))
' >/dev/null 2>&1
}
