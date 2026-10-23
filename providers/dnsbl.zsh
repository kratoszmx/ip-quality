# DNSBL scope: bounded parallel lookups against the vendored ref/dnsbl.list.
# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.

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
sort -u "$DNSBL_FILE"|xargs -P "$parallel_jobs" -I {} /bin/zsh -fc '
  emulate -LR zsh
  setopt EXTENDED_GLOB
  local reversed_ip="$1"
  local zone="$2"
  local result
  result=$(dig +time=3 +tries=1 +short "$reversed_ip.$zone" A 2>/dev/null)
  local lookup_status=$?
  # dig +short may print several records. DNSBLs answer only in 127/8, and
  # 127.255.255.x is a zone error, so any other address is resolver
  # interference (NXDOMAIN hijacking), never evidence of a listing.
  local -a answers=("${(@f)result}")
  local state
  if (( lookup_status != 0 )) || (( ${answers[(I)127.255.255.*]} )); then
    state=Unknown
  elif [[ -z "$result" ]]; then
    state=Clean
  elif (( ${answers[(I)^127.*]} )); then
    state=Unknown
  elif (( ${answers[(Ie)127.0.0.2]} )); then
    state=Blacklisted
  else
    state=Marked
  fi
  printf "%s\t%s\n" "$zone" "$state"
' ip-quality-dnsbl "$reversed_ip" "{}"|LC_ALL=C sort
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
