# Scamalytics public target page. This is not its subscription JSON API.
# Match both page identity and its embedded example, then project only known
# labels. Missing/conflicting table cells remain unknown rather than false.
typeset -gA scamalytics_parsed=()

scamalytics_parse_page(){
emulate -LR zsh
typeset page="$1" target="$2" projection field value
scamalytics_parsed=()
(( ${#page} <= 262144 ))||return 1
projection=$(print -rn -- "$page"|jq -Rrse --arg target "$target" '
  def one: if length == 1 then .[0] else null end;
  def row($label):
    [match("<tr>\\s*<th>" + $label + "</th>\\s*<td>(?<cell>.*?)</td>\\s*</tr>"; "gs")
      | .captures[0].string] | one;
  def flag($label):
    row($label) // "" |
    if test("^\\s*<div class=\"risk( stretch)? yes\">Yes</div>\\s*$") then true
    elif test("^\\s*<div class=\"risk( stretch)? no\">No</div>\\s*$") then false
    else null end;
  def anyflag: if any(. == true) then true elif all(. == false) then false else null end;
  . as $page |
  ([match("<h1>(?<ip>[0-9A-Fa-f:.]+) Fraud Risk</h1>"; "g") | .captures[0].string] | one) as $heading |
  ([match("<div class=\"score\">Fraud Score: (?<score>[0-9]+)</div>"; "g") | .captures[0].string] | one) as $badge |
  ([match("<pre\\b[^>]*>(?<body>[^<]*)</pre>"; "gs") | .captures[0].string |
    capture("^\\s*\"ip\":\\s*\"(?<ip>[0-9A-Fa-f:.]+)\",\\s*\"score\":\\s*\"(?<score>[0-9]+)\",\\s*\"risk\":\\s*\"(?<risk>[a-z ]+)\",\\s*\"is_blacklisted_external\":\\s*(?<abuser>true|false),\\s*\\.\\.\\.\\s*$")
    ] | one) as $example |
  select($heading == $target and $example.ip == $target and $badge == $example.score) |
  select(($example.score | tonumber) >= 0 and ($example.score | tonumber) <= 100) |
  select(["very low", "low", "medium", "high", "very high"] | index($example.risk)) |
  ($page | row("Country Code") // "") as $country |
  {score: $example.score, risk: $example.risk, abuser: ($example.abuser == "true"),
   countrycode: (if $country | test("^[A-Z]{2}$") then $country else null end),
   vpn: ($page | flag("Anonymizing VPN")), tor: ($page | flag("Tor Exit Node")),
   server: ($page | flag("Server")),
   proxy: ([$page | flag("Public Proxy"), flag("Web Proxy"), flag("Residential Proxy")] | anyflag),
   robot: ([$page | flag("Search Engine Robot"), flag("X4Bnet Spambot")] | anyflag)} |
  to_entries[] | [.key, (if .value == null then "" else (.value | tostring) end)] | @tsv
' 2>/dev/null)||return 1
[[ -n "$projection" ]]||return 1
while IFS=$'\t' read -r field value;do
scamalytics_parsed[$field]="$value"
done <<< "$projection"
return 0
}
