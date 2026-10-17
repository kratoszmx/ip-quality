# Reporter-owned source selection. IDs are CLI/JSON policy, not provider scores.
# providers/sources.tsv is the one catalog of IDs, labels, the independent preset
# and plan disclosures; the Ruby runner reads the same file.
typeset -ga reputation_source_ids=() reputation_independent_sources=()
typeset -gA reputation_source_labels=() reputation_source_disclosures=() reputation_source_target_disclosures=()
() {
emulate -L zsh
local id label independent disclosure target_disclosure
[[ -f "$1" && -r "$1" && ! -L "$1" ]]||return 0
while IFS=$'\t' read -r id label independent disclosure target_disclosure;do
[[ -z "$id" || "$id" == \#* ]]&&continue
reputation_source_ids+=("$id")
reputation_source_labels[$id]="$label"
reputation_source_disclosures[$id]="$disclosure"
[[ "$target_disclosure" == - ]]&&target_disclosure="$disclosure"
reputation_source_target_disclosures[$id]="$target_disclosure"
[[ "$independent" == yes ]]&&reputation_independent_sources+=("$id")
done < "$1"
} "${${(%):-%x}:A:h}/sources.tsv"
typeset -gA reputation_source_functions=(
  maxmind db_maxmind_relay ipinfo db_ipinfo ipregistry db_ipregistry
  scamalytics db_scamalytics ipapi db_ipapi ipwhois db_ipwhois dbip db_dbip
  cloudflare db_cloudflare abuseipdb db_abuseipdb ip2location db_ip2location
  ipdata db_ipdata ipqs db_ipqs ping0 db_ping0 ripestat db_ripestat
  shodan db_shodan_internetdb
)
typeset -ga selected_reputation_sources=("${reputation_source_ids[@]}")
typeset -g source_selection=all

# Plan lines for the selected sources, in catalog order; an explicit target uses
# each source's explicit-target disclosure.
reputation_source_disclosure_lines(){
emulate -LR zsh
typeset source_id disclosure
for source_id in "${reputation_source_ids[@]}";do
reputation_source_selected "$source_id"||continue
disclosure="${reputation_source_disclosures[$source_id]}"
[[ -n "${1:-}" ]]&&disclosure="${reputation_source_target_disclosures[$source_id]}"
print -r -- "    ${reputation_source_labels[$source_id]}: $disclosure"
done
}

reputation_choose_sources(){
emulate -LR zsh
typeset choice="$1" source_id
typeset -aU selected
case "$choice" in
all)selected=("${reputation_source_ids[@]}") ;;
independent)selected=("${reputation_independent_sources[@]}") ;;
*)
if [[ -z "$choice" || "$choice" == ,* || "$choice" == *, || "$choice" == *,,* ]];then
print -ru2 -- "ERROR: --sources requires all, independent, or comma-separated source IDs."
return 64
fi
selected=("${(@s:,:)choice}")
for source_id in "${selected[@]}";do
if [[ -z "${reputation_source_functions[$source_id]:-}" ]];then
print -ru2 -- "ERROR: unknown source ID; allowed: ${(j:,:)reputation_source_ids}"
return 64
fi
done
;;
esac
source_selection="$choice"
selected_reputation_sources=("${selected[@]}")
}

reputation_source_selected(){
emulate -LR zsh
(( ${selected_reputation_sources[(Ie)$1]} > 0 ))
}
