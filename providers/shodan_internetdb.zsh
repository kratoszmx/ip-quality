# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# Pure parser for Shodan InternetDB responses. InternetDB is exposure context,
# not a reputation score; missing data is kept unknown rather than called clean.

typeset -gA internetdb_parsed=()
typeset -gA internetdb_unavailable=()

internetdb_parse_unavailability(){
emulate -LR zsh
typeset response="$1"
typeset detail

internetdb_unavailable=()
print -rn -- "$response"|jq -e '
  type == "object" and
  (.detail | type == "string" and length <= 512)
' >/dev/null 2>&1||return 1
detail=$(print -rn -- "$response"|jq -r '.detail')
[[ "${detail:l}" == *"no information available"* ]]||return 1
internetdb_unavailable[status]="not_found"
return 0
}

internetdb_parse_response(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset expected_ip="$2"

internetdb_parsed=()
print -rn -- "$response"|jq -L "${${(%):-%x}:A:h:h}/common" -e --arg expected "$expected_ip" '
  include "json_values";
  type == "object" and
  .ip == $expected and
  (.ports | type == "array") and
  (.ports | length <= 256) and
  all(.ports[]; . != null and integer_or_null(.; 1; 65535)) and
  (.vulns | type == "array") and
  (.vulns | length <= 1024) and
  all(.vulns[]; . != null and text_or_null(.; 128)) and
  (.tags | type == "array") and
  (.tags | length <= 128) and
  all(.tags[]; . != null and text_or_null(.; 128)) and
  (.hostnames | type == "array") and
  (.hostnames | length <= 128) and
  all(.hostnames[]; . != null and text_or_null(.; 512))
' >/dev/null 2>&1||return 1

internetdb_parsed[status]="available"
internetdb_parsed[ports]=$(print -rn -- "$response"|jq -r '.ports | map(tostring) | join(", ")')
internetdb_parsed[port_count]=$(print -rn -- "$response"|jq -r '.ports | length')
internetdb_parsed[vulnerability_count]=$(print -rn -- "$response"|jq -r '.vulns | length')
internetdb_parsed[tags]=$(print -rn -- "$response"|jq -r '.tags | join(", ")')
internetdb_parsed[hostname_count]=$(print -rn -- "$response"|jq -r '.hostnames | length')
return 0
}

db_shodan_internetdb(){
internetdb=()
internetdb[status]="unknown"
if [[ "$1" -ne 4 ]];then
internetdb[status]="not supported for IPv6"
return 0
fi
show_progress "${sinfo[database]}Shodan InternetDB"
local RESPONSE=$(curl -q $CurlARG -sS -L -4 -m 10 --max-filesize 262144 "https://internetdb.shodan.io/$IP" 2>/dev/null)
if internetdb_parse_response "$RESPONSE" "$IP";then
internetdb[status]="${internetdb_parsed[status]}"
internetdb[ports]="${internetdb_parsed[ports]}"
internetdb[port_count]="${internetdb_parsed[port_count]}"
internetdb[vulnerability_count]="${internetdb_parsed[vulnerability_count]}"
internetdb[tags]="${internetdb_parsed[tags]}"
internetdb[hostname_count]="${internetdb_parsed[hostname_count]}"
elif internetdb_parse_unavailability "$RESPONSE";then
internetdb[status]="${internetdb_unavailable[status]}"
fi
}
