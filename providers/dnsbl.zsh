# DNSBL scope: bounded parallel lookups against the vendored ref/dnsbl.list.
# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.

# dig exits successfully even for SERVFAIL/REFUSED. Keep the DNS header so an
# empty error response cannot become a clean observation. Only complete,
# unambiguous A answers are listing evidence; malformed/alias replies stay unknown.
dnsbl_response_state(){
emulate -LR zsh
local response="$1" lookup_status="$2" line rcode="" answer_count=""
local owner ttl rrclass rrtype value extra
local header_pattern='^;; ->>HEADER<<- opcode: QUERY, status: ([A-Z0-9]+),'
local count_pattern='^;; flags: (.*); QUERY: [0-9]+, ANSWER: ([0-9]+),'
local address_pattern='^127\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$'
local -a answers
local invalid=0
if (( lookup_status != 0 ));then
print -r -- Unknown
return 0
fi
for line in "${(@f)response}";do
if [[ "$line" =~ $header_pattern ]];then
[[ -n "$rcode" ]]&&invalid=1
rcode="$match[1]"
elif [[ "$line" =~ $count_pattern ]];then
[[ -n "$answer_count" || " $match[1] " != *' qr '* || " $match[1] " == *' tc '* ]]&&invalid=1
answer_count="$match[2]"
elif [[ -n "$line" && "$line" != ';'* ]];then
read -r owner ttl rrclass rrtype value extra <<< "$line"
if [[ "$rrclass" != IN || "$rrtype" != A || -n "$extra" || ! "$value" =~ $address_pattern ]];then
invalid=1
elif (( match[1] > 255 || match[2] > 255 || match[3] > 255 ));then
invalid=1
else
answers+=("$value")
fi
fi
done
if (( invalid ))||[[ -z "$answer_count" || ( "$rcode" != NOERROR && "$rcode" != NXDOMAIN ) ]];then
print -r -- Unknown
elif (( answer_count != ${#answers} ));then
print -r -- Unknown
elif (( ${#answers} == 0 ));then
print -r -- Clean
elif [[ "$rcode" != NOERROR ]]||(( ${answers[(I)127.255.255.*]} ));then
print -r -- Unknown
elif (( ${answers[(Ie)127.0.0.2]} ));then
print -r -- Blacklisted
else
print -r -- Marked
fi
}

summarize_dnsbl_results(){
local total=0
local clean=0
local blacklisted=0
local other=0
local unknown=0
local line
while IFS= read -r line;do
[[ "$line" == *$'\t'* ]]&&line="${line##*$'\t'}"
((total++))
case "$line" in
"Clean")((clean++));;
"Blacklisted")((blacklisted++));;
"Other"|"Marked")((other++));;
*)((unknown++))
esac
done
print -r -- "$total $clean $other $blacklisted $unknown"
}
check_dnsbl_parallel(){
local ip_to_check="$1"
local parallel_jobs="$2"
local -a ip_octets=("${(@s:.:)ip_to_check}")
local reversed_ip="${ip_octets[3]}.${ip_octets[2]}.${ip_octets[1]}.${ip_octets[0]}"
local library="${${(%):-%x}:A}"
sort -u "$DNSBL_FILE"|xargs -P "$parallel_jobs" -I {} /bin/zsh -fc '
  emulate -LR zsh
  source "$1"
  local reversed_ip="$2"
  local zone="$3"
  local result
  result=$(dig +time=3 +tries=1 +noall +comments +answer "$reversed_ip.$zone" A 2>/dev/null)
  local lookup_status=$?
  printf "%s\t%s\n" "$zone" "$(dnsbl_response_state "$result" "$lookup_status")"
' ip-quality-dnsbl "$library" "$reversed_ip" "{}"|LC_ALL=C sort
}
check_dnsbl(){
show_progress "${sinfo[dnsbl]% }"
local dnsbl_results=$(check_dnsbl_parallel "$IP" "$2")
local num_array=($(print -r -- "$dnsbl_results"|summarize_dnsbl_results))
smail[t]=${num_array[0]:-0}
smail[c]=${num_array[1]:-0}
smail[m]=${num_array[2]:-0}
smail[b]=${num_array[3]:-0}
smail[u]=${num_array[4]:-0}
smail[dnsbl_results]="$dnsbl_results"
local line
local -a blacklisted_zones marked_zones
for line in "${(@f)dnsbl_results}";do
case "${line##*$'\t'}" in
Blacklisted)blacklisted_zones+=("${line%%$'\t'*}") ;;
Marked)marked_zones+=("${line%%$'\t'*}") ;;
esac
done
smail[blacklisted_zones]="${(j:, :)blacklisted_zones}"
smail[marked_zones]="${(j:, :)marked_zones}"
smail[sdnsbl]="$Font_Cyan${smail[dnsbl]}  ${smail[available]}${smail[t]}   ${smail[clean]}${smail[c]}   ${smail[marked]}${smail[m]}   ${smail[blacklisted]}${smail[b]}   ${smail[unknown]}${smail[u]}$Font_Suffix"
}
