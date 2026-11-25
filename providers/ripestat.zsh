# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# Pure parser for RIPEstat Network Info responses. Network access remains in
# bin/ip-quality so malformed, stale, and fixture responses can be tested
# without contacting RIPE NCC.

typeset -gA ripestat_parsed=()

ripestat_parse_network_info(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset prefix origins address prefix_length
# The reporter's address validators set family flags. Keep the flags local
# so this provider cannot affect discovery or the next family to report.
typeset IPV4work IPV6work

ripestat_parsed=()
print -rn -- "$response"|jq -e '
  type == "object" and
  .status == "ok" and
  (.data | type == "object") and
  (.data.prefix | type == "string") and
  (.data.asns | type == "array") and
  (.data.asns | length <= 64) and
  all(.data.asns[];
    (type == "number" and . >= 0 and . <= 4294967295 and floor == .) or
    (type == "string" and test("^[0-9]{1,10}$") and
      (tonumber >= 0 and tonumber <= 4294967295)))
' >/dev/null 2>&1||return 1

prefix=$(print -rn -- "$response"|jq -r '.data.prefix')
origins=$(print -rn -- "$response"|jq -r '[.data.asns[] | "AS" + tostring] | join(", ")')
[[ -n "$prefix" && ${#prefix} -le 128 && "$prefix" == */* && "$prefix" != *[[:cntrl:]]* ]]||return 1
[[ ${#origins} -le 1024 && "$origins" != *[[:cntrl:]]* ]]||return 1
address="${prefix%/*}"
prefix_length="${prefix##*/}"
[[ "$address" != *%* && ${#prefix_length} -le 3 ]]||return 1
if [[ "$address" == *:* ]];then
[[ "$prefix_length" == <0-128> ]]&&is_valid_ipv6 "$address"||return 1
else
[[ "$prefix_length" == <0-32> ]]&&is_valid_ipv4 "$address"||return 1
fi

ripestat_parsed[prefix]="$prefix"
ripestat_parsed[origins]="$origins"
[[ -n "$origins" ]]&&ripestat_parsed[status]="announced"||ripestat_parsed[status]="not_announced"
return 0
}

db_ripestat(){
show_progress "${sinfo[database]}RIPEstat routing"
ripestat=()
ripestat[status]="unknown"
local RESPONSE=$(curl -q $CurlARG -sS -L -$1 -m 10 --max-filesize 65536 --get --data-urlencode "resource=$IP" "https://stat.ripe.net/data/network-info/data.json" 2>/dev/null)
if ripestat_parse_network_info "$RESPONSE";then
ripestat[status]="${ripestat_parsed[status]}"
ripestat[prefix]="${ripestat_parsed[prefix]}"
ripestat[origins]="${ripestat_parsed[origins]}"
fi
}
