#!/bin/zsh
# Offline zsh self-test of reporter validators, parsers and JSON typing.
# Usage: /bin/zsh -f test/support/self_test.zsh PATH/TO/bin/ip-quality
# Sourcing the reporter loads its modules and state without running the CLI.
source "$1"||exit $?

run_self_test(){
[[ -n "$ZSH_VERSION" ]]||{
print -ru2 -- "SELF-TEST FAILED: not running under zsh"
return 1
}
local reference_file
for reference_file in "$DNSBL_FILE" "$REF_DIR/iso3166.json" "$REF_DIR/non_public_ipv4.txt";do
[[ -f "$reference_file" && -r "$reference_file" && ! -L "$reference_file" ]]||{
print -ru2 -- "SELF-TEST FAILED: unsafe or missing reference file: $reference_file"
return 1
}
done
local -a dnsbl_zones
dnsbl_zones=("${(@f)$(<"$DNSBL_FILE")}")
(( ${#dnsbl_zones[@]} >= 100 ))||{
print -ru2 -- "SELF-TEST FAILED: DNSBL dataset is unexpectedly small"
return 1
}
local zone zone_pattern='^[A-Za-z0-9._-]+$'
local -A seen_dnsbl_zones=()
for zone in "${dnsbl_zones[@]}";do
[[ -n "$zone" && "$zone" =~ $zone_pattern ]]||{
print -ru2 -- "SELF-TEST FAILED: invalid DNSBL zone"
return 1
}
[[ -z "${seen_dnsbl_zones[$zone]}" ]]||{
print -ru2 -- "SELF-TEST FAILED: duplicate DNSBL zone: $zone"
return 1
}
seen_dnsbl_zones[$zone]=1
done
is_valid_ipv4 "198.51.100.23"||{
print -ru2 -- "SELF-TEST FAILED: valid IPv4 rejected"
return 1
}
is_valid_ipv4 "999.51.100.23"&&{
print -ru2 -- "SELF-TEST FAILED: invalid IPv4 accepted"
return 1
}
is_private_ipv4 "192.168.1.1"||{
print -ru2 -- "SELF-TEST FAILED: private IPv4 not recognized"
return 1
}
is_private_ipv4 "8.8.8.8"&&{
print -ru2 -- "SELF-TEST FAILED: public IPv4 classified as private"
return 1
}
is_private_ipv6 "2001:db8::1"||{
print -ru2 -- "SELF-TEST FAILED: documentation IPv6 not recognized"
return 1
}
is_private_ipv6 "2001:4860:4860::8888"&&{
print -ru2 -- "SELF-TEST FAILED: global IPv6 classified as private"
return 1
}
is_valid_ipv6 "2001:4860:4860::8888"||{
print -ru2 -- "SELF-TEST FAILED: valid IPv6 rejected"
return 1
}
is_valid_ipv6 "2001:::1"&&{
print -ru2 -- "SELF-TEST FAILED: invalid IPv6 accepted"
return 1
}
(
query_scope="reputation"
requested_ip="8.8.8.8"
IPV4check=1 IPV6check=1 IPV4work=0 IPV6work=0 ERRORcode=0
prepare_explicit_target&&[[ "$IPV4" == "8.8.8.8" && $IPV4work -eq 1 && $IPV6check -eq 0 ]]
)||{
print -ru2 -- "SELF-TEST FAILED: explicit public target preparation changed"
return 1
}
provider_integer_in_range "0" 0 100&&provider_integer_in_range "100" 0 100&&! provider_integer_in_range "null" 0 100&&! provider_integer_in_range "100" 0 99||{
print -ru2 -- "SELF-TEST FAILED: risk score validation changed"
return 1
}
ipqualityscore_parse_unavailability '{"success":false,"message":"Insufficient credits"}'&&[[ "${ipqualityscore_unavailable[status]}" == "upstream_insufficient_credits" ]]||{
print -ru2 -- "SELF-TEST FAILED: IPQualityScore quota status changed"
return 1
}
ipqualityscore_parse_usage_response '{"success":true,"message":"Success","credits":12,"usage":7,"proxy_usage":3}'&&
  [[ "${ipqualityscore_usage[credits]}" == "12" && "${ipqualityscore_usage[proxy_usage]}" == "3" ]]||{
print -ru2 -- "SELF-TEST FAILED: IPQualityScore account usage parser changed"
return 1
}
provider_api_key_is_valid "fixture_key-123456"&&! provider_api_key_is_valid $'bad\nkey'||{
print -ru2 -- "SELF-TEST FAILED: provider credential validation changed"
return 1
}
ipregistry_parse_response '{"ip":"198.51.100.23","connection":{"type":"hosting"},"company":{"type":"hosting"},"location":{"country":{"code":"US"}},"security":{"is_proxy":true,"is_vpn":true,"is_tor":false,"is_tor_exit":false,"is_cloud_provider":true,"is_abuser":false,"is_attacker":false,"is_threat":false}}' "198.51.100.23"&&[[ "${ipregistry_parsed[server]}" == "true" && "${ipregistry_parsed[tor]}" == "false" ]]||{
print -ru2 -- "SELF-TEST FAILED: Ipregistry parser contract changed"
return 1
}
ipapi_parse_response '{"ip":"198.51.100.23","asn":{"type":"isp"},"company":{"type":"isp","abuser_score":"0.01 (Very Low)"},"location":{"country_code":"US"},"is_proxy":false,"is_tor":false,"is_vpn":false,"is_datacenter":false,"is_abuser":false,"is_crawler":false}' "198.51.100.23"&&[[ "${ipapi_parsed[usage_type]}" == "isp" && "${ipapi_parsed[score_text]}" == "0.01 (Very Low)" ]]||{
print -ru2 -- "SELF-TEST FAILED: ipapi parser contract changed"
return 1
}
ipapi_parse_response '{"asn":"AS64500","company":"Example ISP"}'&&{
print -ru2 -- "SELF-TEST FAILED: ipapi schema drift accepted"
return 1
}
ipapi_parse_response '{"ip":"198.51.100.23","asn":"AS64500 Example ISP","company":"Example ISP","country":"United States","docs":"https://ipapi.is/free-tier.html"}' "198.51.100.23"&&[[ "${ipapi_parsed[mode]}" == "anonymous" && "${ipapi_parsed[anonymous_company]}" == "Example ISP" ]]||{
print -ru2 -- "SELF-TEST FAILED: ipapi anonymous contract changed"
return 1
}
ipwhois_parse_response '{"ip":"198.51.100.23","success":true,"country_code":"US","connection":{"asn":64500,"org":"Example Network","isp":"Example ISP"},"timezone":{"id":"America/Los_Angeles"}}' "198.51.100.23"&&
  [[ "${ipwhois_parsed[asn]}" == "64500" && "${ipwhois_parsed[organization]}" == "Example Network" ]]||{
print -ru2 -- "SELF-TEST FAILED: ipwho.is parser contract changed"
return 1
}
cloudflare_parse_response '{"success":true,"result":[{"ip":"198.51.100.23","belongs_to_ref":{"country":"US","description":"Example Network","type":"hosting_provider","value":"AS64500"},"risk_types":[{"id":131,"name":"Phishing","super_category_id":21}]}]}' "198.51.100.23"&&
  [[ "${cloudflare_parsed[network]}" == "AS64500" && "${cloudflare_parsed[threat_categories]}" == "Phishing" ]]||{
print -ru2 -- "SELF-TEST FAILED: Cloudflare IP Intelligence parser contract changed"
return 1
}
ipqualityscore_parse_response '{"success":true,"fraud_score":87,"country_code":"US","proxy":true,"vpn":true,"tor":false,"recent_abuse":false,"bot_status":false,"connection_type":"Data Center"}'&&[[ "${ipqualityscore_parsed[score]}" == "87" && "${ipqualityscore_parsed[connection_type]}" == "Data Center" && "${ipqualityscore_parsed[server]}" == "true" ]]||{
print -ru2 -- "SELF-TEST FAILED: official IPQualityScore parser contract changed"
return 1
}
[[ "$(ipqualityscore_connection_type_server_flag 'Data Center')" == "true" && "$(ipqualityscore_connection_type_server_flag 'Residential')" == "false" && -z "$(ipqualityscore_connection_type_server_flag 'Unknown')" ]]||{
print -ru2 -- "SELF-TEST FAILED: provider connection-type normalization changed"
return 1
}
[[ "$(styled_provider_type 'Mobile')" == "${stype[mobile]}" ]]||{
print -ru2 -- "SELF-TEST FAILED: provider mobile display normalization changed"
return 1
}
(
curl(){ print -rn -- $'{"provider":"fixture"}\n200'; }
CurlARG=""
provider_fetch_public_json 4 "https://fixture.invalid" 1024&&
  [[ "$PROVIDER_RESPONSE_STATUS" == "ok" && "$PROVIDER_RESPONSE_BODY" == '{"provider":"fixture"}' ]]
)||{
print -ru2 -- "SELF-TEST FAILED: provider HTTP success classification changed"
return 1
}
(
curl(){ print -rn -- $'<html>Sorry, you have been blocked by Cloudflare</html>\n403'; }
CurlARG=""
! provider_fetch_public_json 4 "https://fixture.invalid" 1024&&
  [[ "$PROVIDER_RESPONSE_STATUS" == "cloudflare_blocked" && -z "$PROVIDER_RESPONSE_BODY" ]]
)||{
print -ru2 -- "SELF-TEST FAILED: provider Cloudflare classification changed"
return 1
}
(
curl(){ print -rn -- $'<html>forbidden</html>\n403'; }
CurlARG=""
! provider_fetch_public_json 4 "https://fixture.invalid" 1024&&
  [[ "$PROVIDER_RESPONSE_STATUS" == "http_403" && -z "$PROVIDER_RESPONSE_BODY" ]]
)||{
print -ru2 -- "SELF-TEST FAILED: generic provider HTTP failure classification changed"
return 1
}
is_nonnegative_decimal "0.25"&&! is_nonnegative_decimal '0; print unsafe'||{
print -ru2 -- "SELF-TEST FAILED: decimal validation changed"
return 1
}
ping0_parse_geo $'198.51.100.23\nExample Region\nAS64500\nExample Network\n' "198.51.100.23"||{
print -ru2 -- "SELF-TEST FAILED: valid Ping0 public geo fixture rejected"
return 1
}
[[ "${ping0_parsed[0]}" == "198.51.100.23" && "${ping0_parsed[2]}" == "AS64500" ]]||{
print -ru2 -- "SELF-TEST FAILED: Ping0 public geo fields changed"
return 1
}
ping0_parse_geo $'198.51.100.24\nExample Region\nAS64500\nExample Network\n' "198.51.100.23"&&{
print -ru2 -- "SELF-TEST FAILED: Ping0 IP mismatch accepted"
return 1
}
ripestat_parse_network_info '{"status":"ok","data":{"prefix":"198.51.100.0/24","asns":[64500]}}'||{
print -ru2 -- "SELF-TEST FAILED: valid RIPEstat fixture rejected"
return 1
}
[[ "${ripestat_parsed[prefix]}" == "198.51.100.0/24" && "${ripestat_parsed[origins]}" == "AS64500" ]]||{
print -ru2 -- "SELF-TEST FAILED: RIPEstat fields changed"
return 1
}
internetdb_parse_response '{"ip":"198.51.100.23","ports":[22,443],"vulns":["CVE-2099-0001"],"tags":["vpn"],"hostnames":["fixture.invalid"]}' "198.51.100.23"||{
print -ru2 -- "SELF-TEST FAILED: valid Shodan InternetDB fixture rejected"
return 1
}
[[ "${internetdb_parsed[port_count]}" == "2" && "${internetdb_parsed[hostname_count]}" == "1" && "${internetdb_parsed[vulnerability_count]}" == "1" ]]||{
print -ru2 -- "SELF-TEST FAILED: Shodan InternetDB fields changed"
return 1
}
internetdb_parse_response '{"ip":"198.51.100.24","ports":[],"vulns":[],"tags":[],"hostnames":[]}' "198.51.100.23"&&{
print -ru2 -- "SELF-TEST FAILED: Shodan InternetDB IP mismatch accepted"
return 1
}
internetdb_parse_unavailability '{"detail":"No information available"}'&&[[ "${internetdb_unavailable[status]}" == "not_found" ]]||{
print -ru2 -- "SELF-TEST FAILED: Shodan no-information status changed"
return 1
}
is_signed_decimal "-33.86"&&! is_signed_decimal '1; print unsafe'||{
print -ru2 -- "SELF-TEST FAILED: signed decimal validation changed"
return 1
}
[[ "$(mask_network_prefix '198.51.100.0/24')" == "198.51.*.*/24" && "$(mask_network_prefix '2001:db8:1234::/48')" == "2001:db8:*::/48" ]]||{
print -ru2 -- "SELF-TEST FAILED: network-prefix masking changed"
return 1
}
local dnsbl_summary=$(printf '%s\n' Clean Clean Blacklisted Other Unknown|summarize_dnsbl_results)
[[ "$dnsbl_summary" == "5 2 1 1 1" ]]||{
print -ru2 -- "SELF-TEST FAILED: DNSBL outcome aggregation changed"
return 1
}
provider_json_is_object '{"provider":"fixture"}'&& ! provider_json_is_object '[]'||{
print -ru2 -- "SELF-TEST FAILED: provider JSON object validation changed"
return 1
}
[[ "$(provider_merge_boolean_signals false true null)" == "true" && "$(provider_merge_boolean_signals false false)" == "false" && -z "$(provider_merge_boolean_signals false null)" ]]||{
print -ru2 -- "SELF-TEST FAILED: provider boolean signal merging changed"
return 1
}
set_language
local json_special=$'Example "Org" \\ relay\nsecond line'
query_scope="reputation"
fullIP=0
basic_source=maxmind
IP="198.51.100.23"
IPhide="198.51.*.*"
shead[time_raw]="2026-08-23T00:00:00Z"
maxmind=()
ipinfo=()
ipregistry=()
ipapi=()
ipwhois=()
cloudflare=()
dbip=()
ip2location=()
abuseipdb=()
scamalytics=()
ipqs=()
ipdata=()
ping0=()
ripestat=()
internetdb=()
maxmind[org]="$json_special"
maxmind[countrycode]="US"
maxmind[regcountrycode]="US"
maxmind[status]="ok"
ipinfo[status]="ok"
ipinfo[susetype]="${stype[hosting]}"
ipregistry[status]="ok"
ipregistry[susetype]="${stype[hosting]}"
ipregistry[scomtype]="${stype[hosting]}"
ipregistry[proxy]="false"
ip2location[susetype]="${stype[unknown]}"
ip2location[score]="3"
ip2location[status]="ok"
scamalytics[status]="invalid_response"
abuseipdb[status]="http_403"
ipdata[status]="network_error"
ipqs[score]="100"
ipqs[status]="ok"
ipqs[source]="official_api"
ipqs[susetype]="${stype[hosting]}"
ipapi[risk]=$'High "quoted"'
ipapi[status]="ok"
ipapi[mode]="full"
ipapi[ip]="198.51.100.23"
ipapi[countrycode]="US"
ipwhois[status]="ok"
ipwhois[countrycode]="US"
ipwhois[asn]="64500"
ipwhois[org]="Example Network"
ipwhois[isp]="Example ISP"
ipwhois[timezone]="America/Los_Angeles"
ipwhois[risk_status]=ok ipwhois[proxy]=false ipwhois[vpn]=true ipwhois[tor]=false ipwhois[server]=true
dbip[status]="ok" dbip[ip]="198.51.100.23" dbip[countrycode]="US"
dbip[risk_status]=ok dbip[threat_level]=low
dbip[country]="United States" dbip[region]="California" dbip[city]="Example City"
cloudflare[status]="ok"
cloudflare[ip]="198.51.100.23"
cloudflare[countrycode]="US"
cloudflare[network]="AS64500"
cloudflare[org]="Example Network"
cloudflare[infrastructure]="hosting_provider"
cloudflare[threats]="Phishing, Malware"
cloudflare[threats_json]='["Phishing", "Malware"]'
ipqs[proxy]="true"
ping0[status]="verified"
ping0[match]="true"
ping0[organization]="$json_special"
ping0[org]="$json_special"
ripestat[status]="ok"
ripestat[prefix]="198.51.100.0/24"
ripestat[origins]="AS64500"
internetdb[status]="ok"
internetdb[ports]="22, 443"
internetdb[port_count]="2"
internetdb[hostname_count]="1"
internetdb[vulnerability_count]="1"
internetdb[tags]="vpn, edge"
smail[t]="2"
smail[c]="1"
smail[m]="0"
smail[b]="1"
smail[u]="0"
smail[dnsbl_results]=$'dnsbl.example\tClean\nlisted.example\tBlacklisted'
save_json||{
print -ru2 -- "SELF-TEST FAILED: JSON rendering failed"
return 1
}
print -r -- "$ipjson"|jq -e --arg expected "$json_special" '
  .Info.Organization == $expected and
  .Type.Source.IPinfo == "public demo widget" and
  .Type.Source.Ipregistry == "official API" and
  .Type.Source.IPQS == "official_api" and
  .Type.Status.IPinfo == "ok" and
  .Type.Status.Ipregistry == "ok" and
  .Type.Status.IPQS == "ok" and
  .Type.Status.ipapi == "ok" and
  .Type.Status.IP2LOCATION == "ok" and
  .Type.Status.AbuseIPDB == "http_403" and
  .Type.Usage.IPQS != null and
  .Type.Usage.IP2LOCATION == null and
  .Score.IPQS == "100" and
  .ScoreMeta.IP2LOCATION.Scale == "0-99 potential risk" and
  .ScoreMeta.ipapi.Band == "High \"quoted\"" and
  .ScoreMeta.IPQS.Band == null and
  .ScoreMeta.IPQS.Status == "ok" and
  .ScoreMeta.IPQS.Source == "official_api" and
  .ProviderStatus.CheckPlaceMaxMind == "ok" and
  .ProviderStatus.IPinfo == "ok" and
  .ProviderStatus.ipapi == "ok" and
  .ProviderStatus.AbuseIPDB == "http_403" and
  .ProviderStatus.ipdata == "network_error" and
  .ProviderStatus.IPWhois == "ok" and
  .ProviderStatus.Cloudflare == "ok" and
  .ProviderStatus.DBIP == "ok" and
  .ProviderContext.DBIP.IP == .Head.IP and
  .ProviderContext.DBIP.City == "Example City" and
  .Score.Cloudflare == null and .Score.DBIP == null and
  .ScoreMeta.Cloudflare.Reason == "numeric_score_not_provided" and
  .ScoreMeta.Cloudflare.LegacyThreatScore == "retired_constant_zero" and
  .ScoreMeta.DBIP.Band == "low" and .ScoreMeta.DBIP.Source == "public_demo" and
  .Factor.CountryCode.IPWhois == "US" and .Factor.Proxy.IPWhois == false and
  .Factor.VPN.IPWhois == true and .Factor.Abuser.IPWhois == null and
  .FactorMeta.IPWhois.Source == "public_demo" and
  .ProviderContext.IPAPI.Mode == "full" and
  .ProviderContext.IPAPI.IP == .Head.IP and
  .ProviderContext.Cloudflare.IP == .Head.IP and
  (. | tostring | contains("198.51.100.23") | not) and
  (has("Media") | not) and
  .ProviderContext.IPAPI.CountryCode == "US" and
  .ProviderContext.IPWhois.ASN == "64500" and
  .ProviderContext.Cloudflare.ThreatCategories == ["Phishing", "Malware"] and
  .Factor.Proxy.IPQS == true and
  .Factor.Proxy.Ipregistry == false and
  .Factor.VPN.IPinfo == null and
  .Ping0.Organization == $expected and
  .Routing.Prefix == "198.51.*.*/24" and
  .Exposure.Ports == [22, 443] and
  .Exposure.HostnameCount == 1 and
  .Mail.DNSBlacklist.Results["dnsbl.example"] == "Clean" and
  .Mail.DNSBlacklist.Results["listed.example"] == "Blacklisted" and
  .Mail.Port25 == null
' >/dev/null||{
print -ru2 -- "SELF-TEST FAILED: JSON escaping or typing changed"
return 1
}
cloudflare[threats_json]=null
save_json || return 1
print -r -- "$ipjson" | jq -e '.ProviderContext.Cloudflare.ThreatCategories == null' >/dev/null || {
print -ru2 -- "SELF-TEST FAILED: missing Cloudflare threats became an empty result"
return 1
}
basic_source=ipinfo
ipinfo=([status]=ok [asn]=64501 [city]="Fallback City" [continent]=Asia [subcode]=stale)
save_json || return 1
print -r -- "$ipjson" | jq -e '
  .Info.Source == "IPinfo public demo widget" and .Info.ASN == "64501" and
  .Info.City.Name == "Fallback City" and .Info.City.SubCode == null and
  .Info.Continent.Code == null and .Info.Continent.Name == "Asia"
' >/dev/null || {
print -ru2 -- "SELF-TEST FAILED: IPinfo basic information changed"
return 1
}
query_scope=mail
services=(Gmail 163)
smailstatus=([Gmail]=true)
local port25 expected
for port25 expected in 1 '.Mail.Port25 == true and .Mail.Gmail == true and .Mail["163"] == false' \
  2 '.Mail.Port25 == null and .Mail.Gmail == null and .Mail["163"] == null' \
  0 '.Mail.Port25 == false and .Mail.Gmail == false and .Mail["163"] == false';do
smail[local]=$port25
save_json || return 1
print -r -- "$ipjson" | jq -e "$expected" >/dev/null || {
print -ru2 -- "SELF-TEST FAILED: mail service JSON changed for port-25 state $port25"
return 1
}
done
print -r -- "SELF-TEST OK: zsh runtime, validators, provider parsers, and ${#dnsbl_zones[@]} DNSBL entries"
}
run_self_test
