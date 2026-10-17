# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.
# Ping0's documented public /geo response parser. Network access stays
# in bin/ip-quality so this library is fixture-testable and reusable.

typeset -ga ping0_parsed=()

ping0_parse_geo(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset expected_ip="$2"
typeset normalized="${response//$'\r'/}"
typeset -a lines
typeset value

ping0_parsed=()
[[ "$normalized" == *$'\n' ]]&&normalized="${normalized%$'\n'}"
lines=("${(@f)normalized}")
(( ${#lines[@]} == 4 ))||return 1
for value in "${lines[@]}";do
[[ -n "$value" && ${#value} -le 512 && "$value" != *[[:cntrl:]]* ]]||return 1
done
[[ "${lines[0]}" == "$expected_ip" ]]||return 2
[[ "${lines[2]}" =~ '^AS[0-9]+$' ]]||return 1

ping0_parsed=("${lines[0]}" "${lines[1]}" "${lines[2]}" "${lines[3]}")
return 0
}

db_ping0(){
show_progress "${sinfo[database]}Ping0 public geo"
ping0=()
ping0[status]="unknown"
ping0[match]="null"
ping0[riskstatus]="official_public_endpoint_does_not_expose_risk"
if [[ -n "$requested_ip" ]];then
ping0[status]="not_applicable_target"
return 0
fi
local endpoint="https://ipv4.ping0.cc/geo"
[[ "$1" -eq 6 ]]&&endpoint="https://ipv6.ping0.cc/geo"
local RESPONSE=$(curl -q $CurlARG -sS -L -$1 -m 10 --max-filesize 4096 "$endpoint" 2>/dev/null)
ping0_parse_geo "$RESPONSE" "$IP"
local parse_status=$?
case "$parse_status" in
0)ping0[status]="verified"
ping0[match]="true"
ping0[location]="${ping0_parsed[1]}"
ping0[asn]="${ping0_parsed[2]}"
ping0[org]="${ping0_parsed[3]}"
;;
2)ping0[status]="ip_mismatch"
ping0[match]="false"
;;
*)ping0[status]="unknown"
ping0[match]="null"
esac
}
