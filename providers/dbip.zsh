# Strict parser for DB-IP's official Extended API response. DB-IP returns a
# qualitative threatLevel; this adapter deliberately does not invent a number.

typeset -gA dbip_parsed=()

dbip_parse_response(){
emulate -LR zsh
typeset response="$1"
typeset expected_ip="$2"
typeset proxy_type usage_type details_kind

dbip_parsed=()
print -rn -- "$response"|jq -e --arg expected "$expected_ip" '
  type == "object" and .ipAddress == $expected and
  ([.countryCode, .usageType, .proxyType, .threatLevel]
    | all(. == null or type == "string")) and
  ([.isCrawler, .isProxy] | all(. == null or type == "boolean")) and
  (.threatDetails == null or
    (.threatDetails | type == "array" and all(type == "string")))
' >/dev/null 2>&1||return 1

dbip_parsed[country_code]=$(print -rn -- "$response"|jq -r '.countryCode // empty')
dbip_parsed[proxy]=$(print -rn -- "$response"|jq -r 'if .isProxy == null then empty else .isProxy end')
dbip_parsed[robot]=$(print -rn -- "$response"|jq -r 'if .isCrawler == null then empty else .isCrawler end')
dbip_parsed[threat_level]=$(print -rn -- "$response"|jq -r '.threatLevel // empty')
proxy_type=$(print -rn -- "$response"|jq -r '.proxyType // empty'|tr '[:upper:]' '[:lower:]')
usage_type=$(print -rn -- "$response"|jq -r '.usageType // empty'|tr '[:upper:]' '[:lower:]')
details_kind=$(print -rn -- "$response"|jq -r 'if .threatDetails == null then "unknown" else "array" end')

case "$proxy_type:${dbip_parsed[proxy]}" in
vpn:*)dbip_parsed[vpn]="true"
;;
*:false|http:true|tor:true)dbip_parsed[vpn]="false"
esac
case "$proxy_type:${dbip_parsed[proxy]}" in
tor:*)dbip_parsed[tor]="true"
;;
*:false|http:true|vpn:true)dbip_parsed[tor]="false"
esac
case "$usage_type" in
hosting)dbip_parsed[server]="true"
;;
corporate|consumer|reserved)dbip_parsed[server]="false"
esac
if [[ "$details_kind" == "array" ]];then
if print -rn -- "$response"|jq -e '.threatDetails | any(
  . == "attack-source" or . == "port-scan" or . == "fake-crawler" or
  . == "bot" or startswith("bot-")
)' >/dev/null 2>&1;then
dbip_parsed[abuser]="true"
else
dbip_parsed[abuser]="false"
fi
if print -rn -- "$response"|jq -e '.threatDetails | any(
  . == "bot" or . == "fake-crawler" or startswith("bot-")
)' >/dev/null 2>&1;then
dbip_parsed[robot]="true"
elif [[ -z "${dbip_parsed[robot]}" ]];then
dbip_parsed[robot]="false"
fi
fi
dbip_parsed[status]="ok"
return 0
}
