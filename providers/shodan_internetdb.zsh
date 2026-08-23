# Pure parser for Shodan InternetDB responses. InternetDB is exposure context,
# not a reputation score; missing data is kept unknown rather than called clean.

typeset -gA internetdb_parsed=()

internetdb_parse_response(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset expected_ip="$2"

internetdb_parsed=()
print -rn -- "$response"|jq -e --arg expected "$expected_ip" '
  type == "object" and
  .ip == $expected and
  (.ports | type == "array") and
  (.ports | length <= 256) and
  all(.ports[]; type == "number" and . >= 1 and . <= 65535) and
  (.vulns | type == "array") and
  (.vulns | length <= 1024) and
  all(.vulns[]; type == "string" and length <= 128) and
  (.tags | type == "array") and
  (.tags | length <= 128) and
  all(.tags[]; type == "string" and length <= 128) and
  (.hostnames | type == "array") and
  (.hostnames | length <= 128) and
  all(.hostnames[]; type == "string" and length <= 512)
' >/dev/null 2>&1||return 1

internetdb_parsed[status]="available"
internetdb_parsed[ports]=$(print -rn -- "$response"|jq -r '.ports | map(tostring) | join(", ")')
internetdb_parsed[port_count]=$(print -rn -- "$response"|jq -r '.ports | length')
internetdb_parsed[vulnerability_count]=$(print -rn -- "$response"|jq -r '.vulns | length')
internetdb_parsed[tags]=$(print -rn -- "$response"|jq -r '.tags | join(", ")')
internetdb_parsed[hostname_count]=$(print -rn -- "$response"|jq -r '.hostnames | length')
return 0
}
