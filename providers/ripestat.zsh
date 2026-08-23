# Pure parser for RIPEstat Network Info responses. Network access remains in
# ip-quality.zsh so malformed, stale, and fixture responses can be tested
# without contacting RIPE NCC.

typeset -gA ripestat_parsed=()

ripestat_parse_network_info(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset prefix origins

ripestat_parsed=()
print -rn -- "$response"|jq -e '
  type == "object" and
  .status == "ok" and
  (.data | type == "object") and
  (.data.prefix | type == "string") and
  (.data.asns | type == "array") and
  (.data.asns | length <= 64) and
  all(.data.asns[]; type == "number" and . >= 0 and . <= 4294967295)
' >/dev/null 2>&1||return 1

prefix=$(print -rn -- "$response"|jq -r '.data.prefix')
origins=$(print -rn -- "$response"|jq -r '[.data.asns[] | "AS" + tostring] | join(", ")')
[[ -n "$prefix" && ${#prefix} -le 128 && "$prefix" == */* && "$prefix" != *[[:cntrl:]]* ]]||return 1
[[ ${#origins} -le 1024 && "$origins" != *[[:cntrl:]]* ]]||return 1

ripestat_parsed[prefix]="$prefix"
ripestat_parsed[origins]="$origins"
[[ -n "$origins" ]]&&ripestat_parsed[status]="announced"||ripestat_parsed[status]="not_announced"
return 0
}
