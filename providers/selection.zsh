# Reporter-owned source selection. IDs are CLI/JSON policy, not provider scores.
typeset -ga reputation_source_ids=(maxmind ipinfo ipregistry scamalytics ipapi ipwhois dbip cloudflare abuseipdb ip2location ipdata ipqs ping0 ripestat shodan)
typeset -gA reputation_source_functions=(
  maxmind db_maxmind_relay ipinfo db_ipinfo ipregistry db_ipregistry
  scamalytics db_scamalytics ipapi db_ipapi ipwhois db_ipwhois dbip db_dbip
  cloudflare db_cloudflare abuseipdb db_abuseipdb ip2location db_ip2location
  ipdata db_ipdata ipqs db_ipqs ping0 db_ping0 ripestat db_ripestat
  shodan db_shodan_internetdb
)
typeset -ga selected_reputation_sources=("${reputation_source_ids[@]}")
typeset -g source_selection=all

reputation_choose_sources(){
emulate -LR zsh
typeset choice="$1" source_id
typeset -aU selected
case "$choice" in
all)selected=("${reputation_source_ids[@]}") ;;
independent)selected=(ipinfo ipregistry ipapi ipwhois dbip cloudflare ipqs ping0 ripestat shodan) ;;
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
