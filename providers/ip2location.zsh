# IP2Location's public lookup embeds a target-specific JSON example. Read that
# data without executing page scripts or deriving false flags from missing text.
ip2location_page_response(){
emulate -LR zsh
typeset page="$1" target="$2"
(( ${#page} <= 262144 ))||return 1
print -rn -- "$page"|jq -Rrse --arg target "$target" '
  def one: if length == 1 then .[0] else null end;
  ([match("<h1\\b[^>]*>IP Address (?<ip>[0-9a-fA-F:.]+)</h1>"; "g") | .captures[0].string] | one) as $heading |
  ([match("<pre\\b[^>]*\\bid=\"code2\"[^>]*>\\s*<code\\b[^>]*>(?<json>[^<]*)</code>\\s*</pre>"; "gs") | .captures[0].string] | one) as $example |
  select($heading == $target and $example != null) |
  ($example | gsub("&quot;"; "\"") | gsub("&#39;"; "\u0027") |
    gsub("&lt;"; "<") | gsub("&gt;"; ">") | gsub("&amp;"; "&") | fromjson) |
  select(type == "object" and .ip == $target)
' 2>/dev/null
}

ip2location_response_is_valid(){
emulate -LR zsh
print -rn -- "$1"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg target "$2" '
  include "json_values";
  type == "object" and .ip == $target and .error == null and
  (.as_info == null or (.as_info | type == "object")) and
  (.proxy == null or (.proxy | type == "object")) and
  (.country_code == null or (.country_code | type == "string" and test("^[A-Z]{2}$"))) and
  text_or_null(.usage_type; 128) and text_or_null(.as_info.as_usage_type; 128) and
  integer_or_null(.fraud_score; 0; 99) and
  ([.is_proxy, .proxy.is_public_proxy, .proxy.is_web_proxy, .proxy.is_tor,
    .proxy.is_vpn, .proxy.is_data_center, .proxy.is_spammer, .proxy.is_web_crawler,
    .proxy.is_scanner, .proxy.is_botnet] | all(boolean_or_null(.))) and
  ([.fraud_score, .is_proxy, .proxy.is_vpn, .proxy.is_tor, .proxy.is_data_center] | any(. != null))
' >/dev/null 2>&1
}
