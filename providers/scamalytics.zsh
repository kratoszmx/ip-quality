# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
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

db_scamalytics(){
show_progress "${sinfo[database]}Scamalytics"
scamalytics=()
scamalytics[source]=check_place_relay
check_place_fetch_json "$1" "$IP" "db=scamalytics"||true
scamalytics[status]="$PROVIDER_RESPONSE_STATUS"
local RESPONSE="$PROVIDER_RESPONSE_BODY"
if [[ "${scamalytics[status]}" == ok ]] && ! print -rn -- "$RESPONSE"|jq -e '
  type == "object" and (.scamalytics | type == "object") and
  (.scamalytics.scamalytics_score | tostring | test("^[0-9]{1,3}$")) and
  (.scamalytics.scamalytics_score | tonumber | . >= 0 and . <= 100) and
  ([.scamalytics.scamalytics_proxy, .external_datasources,
    .external_datasources.maxmind_geolite2, .external_datasources.firehol,
    .external_datasources.x4bnet] | all(. == null or type == "object"))
' >/dev/null 2>&1;then
scamalytics[status]=invalid_response
fi
if [[ "${scamalytics[status]}" != ok ]];then
scamalytics[relay_status]="${scamalytics[status]}"
scamalytics[source]=public_demo
typeset wire_response
wire_response=$(curl -q $CurlARG -sS -$1 -m 10 --max-filesize 262144 \
  --write-out $'\n%{http_code}' "https://scamalytics.com/ip/$IP" 2>/dev/null)
provider_decode_http_response "$wire_response" "$?"
scamalytics[status]="${provider_http_response[status]}"
[[ "${scamalytics[status]}" == ok ]]||return 0
if ! scamalytics_parse_page "${provider_http_response[body]}" "$IP";then
scamalytics[status]=invalid_response
return 0
fi
typeset field
for field in score risk countrycode proxy tor vpn server abuser robot;do
scamalytics[$field]="${scamalytics_parsed[$field]}"
done
return 0
fi
scamalytics[countrycode]=$(echo "$RESPONSE"|jq -r '.external_datasources.maxmind_geolite2.ip_country_code')
scamalytics[proxy]=$(echo "$RESPONSE"|jq -r '.external_datasources.firehol.is_proxy')
scamalytics[tor]=$(echo "$RESPONSE"|jq -r '.external_datasources.x4bnet.is_tor')
scamalytics[vpn]=$(echo "$RESPONSE"|jq -r '.scamalytics.scamalytics_proxy.is_vpn')
scamalytics[server]=$(echo "$RESPONSE"|jq -r '.scamalytics.scamalytics_proxy.is_datacenter')
scamalytics[abuser]=$(echo "$RESPONSE"|jq -r '.scamalytics.is_blacklisted_external')
scamalytics[robot1]=$(echo "$RESPONSE"|jq -r '.external_datasources.x4bnet.is_blacklisted_spambot')
scamalytics[robot2]=$(echo "$RESPONSE"|jq -r '.external_datasources.x4bnet.is_bot_operamini')
scamalytics[robot3]=$(echo "$RESPONSE"|jq -r '.external_datasources.x4bnet.is_bot_semrush')
scamalytics[robot]=$(provider_merge_boolean_signals "${scamalytics[robot1]}" "${scamalytics[robot2]}" "${scamalytics[robot3]}")
scamalytics[score]=$(echo "$RESPONSE"|jq -r '.scamalytics.scamalytics_score')
if ! provider_integer_in_range "${scamalytics[score]}" 0 100;then
scamalytics[score]=""
fi
scamalytics[risk]=""
}
