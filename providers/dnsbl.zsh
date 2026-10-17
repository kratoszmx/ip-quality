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
  local reversed_ip="$1"
  local zone="$2"
  local result
  result=$(dig +time=3 +tries=1 +short "$reversed_ip.$zone" A 2>/dev/null)
  local lookup_status=$?
  if (( lookup_status != 0 )); then
    printf "%s\t%s\n" "$zone" "Unknown"
  elif [[ "$result" == 127.255.255.* ]]; then
    printf "%s\t%s\n" "$zone" "Unknown"
  elif [[ -z "$result" ]]; then
    printf "%s\t%s\n" "$zone" "Clean"
  elif [[ "$result" == "127.0.0.2" ]]; then
    printf "%s\t%s\n" "$zone" "Blacklisted"
  else
    printf "%s\t%s\n" "$zone" "Marked"
  fi
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
smail[blacklisted_zones]=$(print -r -- "$dnsbl_results"|awk -F '\t' '$2 == "Blacklisted" {print $1}'|paste -sd, -|sed 's/,/, /g')
smail[marked_zones]=$(print -r -- "$dnsbl_results"|awk -F '\t' '$2 == "Marked" {print $1}'|paste -sd, -|sed 's/,/, /g')
smail[sdnsbl]="$Font_Cyan${smail[dnsbl]}  ${smail[available]}${smail[t]}   ${smail[clean]}${smail[c]}   ${smail[marked]}${smail[m]}   ${smail[blacklisted]}${smail[b]}   ${smail[unknown]}${smail[u]}$Font_Suffix"
}
