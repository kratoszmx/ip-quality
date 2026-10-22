# JSON report assembly; provider values keep their own types and scales.
# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.

save_json(){
local query_target_mode=discovered_egress
[[ -n "${requested_ip:-}" ]]&&query_target_mode=explicit_target
local info_type="" info_source="Check.Place upstream relay; MaxMind-labeled response"
local -A info
if [[ "$basic_source" == maxmind ]];then
info=("${(@kv)maxmind[@]}")
else
info_source="IPinfo public demo widget"
[[ "${ipinfo[status]:-}" == disabled ]]&&info_source="none"
# The IPinfo widget has no subdivision or continent code.
info=("${(@kv)ipinfo[@]}" subcode "" sub "" continentcode "")
fi
if [[ -n "${info[countrycode]:-}" && "${info[countrycode]:-}" != "null" ]];then
if [[ "${info[countrycode]:-}" == "${info[regcountrycode]:-}" ]];then
info_type=$(clean_ansi "${sbasic[type0]:-}")
else
info_type=$(clean_ansi "${sbasic[type1]:-}")
fi
fi

local reputation_enabled=false
scope_includes reputation&&reputation_enabled=true
local mail_port25=null
local mail_services='{}'
local service service_value
local -a mail_service_args=()
if scope_includes mail;then
case "${smail[local]:-0}" in
1)mail_port25=true
;;
2)mail_port25=null
;;
*)mail_port25=false
esac
for service in "${services[@]}";do
case "${smail[local]:-0}:${smailstatus[$service]:-false}" in
1:true)service_value=true
;;
2:*)service_value=null
;;
*)service_value=false
esac
mail_service_args+=(--argjson "$service" "$service_value")
done
mail_services=$(jq -cn "${mail_service_args[@]}" '$ARGS.named')||return 1
fi

local displayed_ip="${IPhide:-}"
[[ $fullIP -eq 1 ]]&&displayed_ip="${IP:-}"
local displayed_routing_prefix="${ripestat[prefix]:-}"
if [[ $fullIP -ne 1 && -n "$displayed_routing_prefix" ]];then
displayed_routing_prefix=$(mask_network_prefix "$displayed_routing_prefix")||displayed_routing_prefix=""
fi
ipjson=$(jq -n \
--arg head_ip "$displayed_ip" \
--arg head_repository "${shead[git]:-}" \
--arg head_time "${shead[time_raw]:-}" \
--arg head_version "${script_version:-}" \
--arg source_selection "${source_selection:-all}" \
--arg selected_sources "${(j:,:)selected_reputation_sources[@]}" \
--arg target_mode "$query_target_mode" \
--arg ipqs_dns "${ipqs[dns]:-}" \
--arg info_source "$info_source" \
--arg info_asn "${info[asn]:-}" --arg info_org "${info[org]:-}" \
--arg info_lat "${info[lat]:-}" --arg info_lon "${info[lon]:-}" \
--arg info_dms "${info[dms]:-}" --arg info_map "${info[map]:-}" \
--arg info_timezone "${info[timezone]:-}" --arg info_city "${info[city]:-}" \
--arg info_post "${info[post]:-}" --arg info_subcode "${info[subcode]:-}" \
--arg info_sub "${info[sub]:-}" --arg info_countrycode "${info[countrycode]:-}" \
--arg info_country "${info[country]:-}" --arg info_continentcode "${info[continentcode]:-}" \
--arg info_continent "${info[continent]:-}" --arg info_regcountrycode "${info[regcountrycode]:-}" \
--arg info_regcountry "${info[regcountry]:-}" --arg info_type "$info_type" \
--arg type_ipinfo_usage "$(clean_ansi "${ipinfo[susetype]:-}")" \
--arg type_ipregistry_usage "$(clean_ansi "${ipregistry[susetype]:-}")" \
--arg type_ipqs_usage "$(clean_ansi "${ipqs[susetype]:-}")" \
--arg type_ipapi_usage "$(clean_ansi "${ipapi[susetype]:-}")" \
--arg type_ip2_usage "$(clean_ansi "${ip2location[susetype]:-}")" \
--arg type_abuse_usage "$(clean_ansi "${abuseipdb[susetype]:-}")" \
--arg type_ipinfo_company "$(clean_ansi "${ipinfo[scomtype]:-}")" \
--arg type_ipregistry_company "$(clean_ansi "${ipregistry[scomtype]:-}")" \
--arg type_ipapi_company "$(clean_ansi "${ipapi[scomtype]:-}")" \
--arg type_ip2_company "$(clean_ansi "${ip2location[scomtype]:-}")" \
--arg score_ip2 "${ip2location[score]:-}" --arg score_scam "${scamalytics[score]:-}" \
--arg score_ipapi "${ipapi[score]:-}" --arg score_abuse "${abuseipdb[score]:-}" \
--arg score_ipqs "${ipqs[score]:-}" \
--arg band_ip2 "$(clean_ansi "${ip2location[risk]:-}")" \
--arg band_scam "$(clean_ansi "${scamalytics[risk]:-}")" \
--arg band_ipapi "$(clean_ansi "${ipapi[risk]:-}")" \
--arg band_abuse "$(clean_ansi "${abuseipdb[risk]:-}")" \
--arg band_ipqs "$(clean_ansi "${ipqs[risk]:-}")" \
--arg status_ipqs "${ipqs[status]:-unknown}" \
--arg route_ipqs "${ipqs[query_route]:-}" --arg primary_status_ipqs "${ipqs[primary_status]:-}" \
--arg status_ipinfo "${ipinfo[status]:-unknown}" \
--arg source_ipqs "${ipqs[source]:-unknown}" \
--arg status_ipregistry "${ipregistry[status]:-not_configured}" \
--arg status_maxmind "${maxmind[status]:-unknown}" \
--arg status_scamalytics "${scamalytics[status]:-unknown}" \
--arg source_scamalytics "${scamalytics[source]:-check_place_relay}" \
--arg relay_status_scamalytics "${scamalytics[relay_status]:-}" \
--arg status_abuseipdb "${abuseipdb[status]:-unknown}" \
--arg source_abuseipdb "${abuseipdb[source]:-check_place_relay}" \
--arg status_ip2location "${ip2location[status]:-unknown}" \
--arg source_ip2location "${ip2location[source]:-check_place_relay}" \
--arg relay_status_ip2location "${ip2location[relay_status]:-}" \
--arg status_ipdata "${ipdata[status]:-unknown}" \
--arg source_ipdata "${ipdata[source]:-check_place_relay}" \
--arg relay_status_ipdata "${ipdata[relay_status]:-}" \
--arg status_ipapi "${ipapi[status]:-unknown}" \
--arg ipapi_risk_status "${ipapi[risk_status]:-${ipapi[status]:-unknown}}" --arg ipapi_credential_mode "${ipapi[credential_mode]:-}" \
--arg ipapi_mode "${ipapi[mode]:-}" --arg ipapi_ip "${ipapi[ip]:+$displayed_ip}" \
--arg ipapi_countrycode "${ipapi[countrycode]:-}" \
--arg ipapi_asn "${ipapi[anonymous_asn]:-}" --arg ipapi_company "${ipapi[anonymous_company]:-}" \
--arg ipapi_country "${ipapi[anonymous_country]:-}" --arg ipapi_city "${ipapi[anonymous_city]:-}" \
--arg ipapi_region "${ipapi[anonymous_region]:-}" --arg ipapi_timezone "${ipapi[anonymous_timezone]:-}" \
--arg status_ipwhois "${ipwhois[status]:-unknown}" \
--arg status_dbip "${dbip[status]:-unknown}" --arg dbip_ip "${dbip[ip]:+$displayed_ip}" \
--arg dbip_risk_status "${dbip[risk_status]:-${dbip[status]:-unknown}}" --arg band_dbip "${dbip[threat_level]:-}" \
--arg dbip_countrycode "${dbip[countrycode]:-}" --arg dbip_country "${dbip[country]:-}" \
--arg dbip_region "${dbip[region]:-}" --arg dbip_city "${dbip[city]:-}" \
--arg ipwhois_countrycode "${ipwhois[countrycode]:-}" \
--arg ipwhois_asn "${ipwhois[asn]:-}" --arg ipwhois_org "${ipwhois[org]:-}" \
--arg ipwhois_isp "${ipwhois[isp]:-}" --arg ipwhois_timezone "${ipwhois[timezone]:-}" \
--arg ipwhois_risk_status "${ipwhois[risk_status]:-${ipwhois[status]:-unknown}}" \
--arg ipwhois_proxy "${ipwhois[proxy]:-}" --arg ipwhois_vpn "${ipwhois[vpn]:-}" \
--arg ipwhois_tor "${ipwhois[tor]:-}" --arg ipwhois_server "${ipwhois[server]:-}" \
--arg status_cloudflare "${cloudflare[status]:-not_configured}" \
--arg route_cloudflare "${cloudflare[query_route]:-}" --arg primary_status_cloudflare "${cloudflare[primary_status]:-}" \
--arg cloudflare_ip "${cloudflare[ip]:+$displayed_ip}" --arg cloudflare_countrycode "${cloudflare[countrycode]:-}" \
--arg cloudflare_network "${cloudflare[network]:-}" --arg cloudflare_org "${cloudflare[org]:-}" \
--arg cloudflare_infrastructure "${cloudflare[infrastructure]:-}" \
--argjson cloudflare_threats "${cloudflare[threats_json]:-null}" \
--arg f_ip2_cc "${ip2location[countrycode]:-}" --arg f_ipapi_cc "${ipapi[countrycode]:-}" \
--arg f_ipregistry_cc "${ipregistry[countrycode]:-}" \
--arg f_ipqs_cc "${ipqs[countrycode]:-}" --arg f_scam_cc "${scamalytics[countrycode]:-}" \
--arg f_ipdata_cc "${ipdata[countrycode]:-}" --arg f_ipinfo_cc "${ipinfo[countrycode]:-}" \
--arg f_ip2_proxy "${ip2location[proxy]:-}" --arg f_ipapi_proxy "${ipapi[proxy]:-}" \
--arg f_ipregistry_proxy "${ipregistry[proxy]:-}" \
--arg f_ipqs_proxy "${ipqs[proxy]:-}" --arg f_scam_proxy "${scamalytics[proxy]:-}" \
--arg f_ipdata_proxy "${ipdata[proxy]:-}" --arg f_ipinfo_proxy "${ipinfo[proxy]:-}" \
--arg f_ip2_vpn "${ip2location[vpn]:-}" --arg f_ipapi_vpn "${ipapi[vpn]:-}" \
--arg f_ipregistry_vpn "${ipregistry[vpn]:-}" \
--arg f_ipqs_vpn "${ipqs[vpn]:-}" --arg f_scam_vpn "${scamalytics[vpn]:-}" \
--arg f_ipdata_vpn "${ipdata[vpn]:-}" --arg f_ipinfo_vpn "${ipinfo[vpn]:-}" \
--arg f_ip2_tor "${ip2location[tor]:-}" --arg f_ipapi_tor "${ipapi[tor]:-}" \
--arg f_ipregistry_tor "${ipregistry[tor]:-}" \
--arg f_ipqs_tor "${ipqs[tor]:-}" --arg f_scam_tor "${scamalytics[tor]:-}" \
--arg f_ipdata_tor "${ipdata[tor]:-}" --arg f_ipinfo_tor "${ipinfo[tor]:-}" \
--arg f_ip2_server "${ip2location[server]:-}" --arg f_ipapi_server "${ipapi[server]:-}" \
--arg f_ipregistry_server "${ipregistry[server]:-}" \
--arg f_ipqs_server "${ipqs[server]:-}" --arg f_scam_server "${scamalytics[server]:-}" \
--arg f_ipdata_server "${ipdata[server]:-}" --arg f_ipinfo_server "${ipinfo[server]:-}" \
--arg f_ip2_abuse "${ip2location[abuser]:-}" --arg f_ipapi_abuse "${ipapi[abuser]:-}" \
--arg f_ipregistry_abuse "${ipregistry[abuser]:-}" \
--arg f_ipqs_abuse "${ipqs[abuser]:-}" --arg f_scam_abuse "${scamalytics[abuser]:-}" \
--arg f_ipdata_abuse "${ipdata[abuser]:-}" --arg f_ipinfo_abuse "${ipinfo[abuser]:-}" \
--arg f_ip2_bot "${ip2location[robot]:-}" --arg f_ipapi_bot "${ipapi[robot]:-}" \
--arg f_ipregistry_bot "${ipregistry[robot]:-}" \
--arg f_ipqs_bot "${ipqs[robot]:-}" --arg f_scam_bot "${scamalytics[robot]:-}" \
--arg f_ipdata_bot "${ipdata[robot]:-}" --arg f_ipinfo_bot "${ipinfo[robot]:-}" \
--arg mail_port25 "$mail_port25" --argjson mail_services "$mail_services" \
--arg dns_total "${smail[t]:-}" --arg dns_clean "${smail[c]:-}" \
--arg dns_marked "${smail[m]:-}" --arg dns_blacklisted "${smail[b]:-}" \
--arg dns_unknown "${smail[u]:-}" --arg dns_results "${smail[dnsbl_results]:-}" \
--argjson reputation_enabled "$reputation_enabled" \
--arg ping_status "${ping0[status]:-unknown}" --arg ping_match "${ping0[match]:-}" \
--arg ping_location "${ping0[location]:-}" --arg ping_asn "${ping0[asn]:-}" \
--arg ping_org "${ping0[org]:-}" \
--arg ping_risk "${ping0[riskstatus]:-official_public_endpoint_does_not_expose_risk}" \
--arg routing_status "${ripestat[status]:-unknown}" --arg routing_prefix "$displayed_routing_prefix" \
--arg routing_origins "${ripestat[origins]:-}" \
--arg exposure_status "${internetdb[status]:-unknown}" --arg exposure_ports "${internetdb[ports]:-}" \
--arg exposure_port_count "${internetdb[port_count]:-}" \
--arg exposure_hostname_count "${internetdb[hostname_count]:-}" \
--arg exposure_vulns "${internetdb[vulnerability_count]:-}" \
--arg exposure_tags "${internetdb[tags]:-}" \
'
def opt($value):
  if $value == "" or $value == "null" or $value == "未知" or ($value | ascii_downcase) == "unknown"
  then null else $value end;
def boolnull($value): if $value == "true" then true elif $value == "false" then false else null end;
def factor($value):
  if $value == "true" then true
  elif $value == "false" then false
  elif ($value | test("^[A-Za-z]{2}$")) then $value
  else null end;
def intnull($value): try ($value | tonumber) catch null;
def list($value):
  if opt($value) == null then []
  else [$value | split(",")[] | gsub("^\\s+|\\s+$"; "") | select(length > 0)] end;
def numberlist($value): [list($value)[] | try tonumber catch empty];
def dnsresults($value):
  reduce ($value | split("\n")[] | split("\t") | select(length == 2)) as $row
    ({}; . + {($row[0]): $row[1]});
{
  Head: {
    IP: opt($head_ip), Repository: opt($head_repository),
    Time: opt($head_time), Version: opt($head_version)
  },
  Query: {
    SourceSelection: $source_selection,
    SelectedSources: (if $reputation_enabled then ($selected_sources | split(",") | map(select(length > 0))) else [] end),
    TargetMode: $target_mode,
    IPQSDNS: opt($ipqs_dns),
    ProviderTransport: {
      IPQS: {Route: opt($route_ipqs), OriginalRouteFailure: opt($primary_status_ipqs), TargetUnchanged: true},
      Cloudflare: {Route: opt($route_cloudflare), OriginalRouteFailure: opt($primary_status_cloudflare), TargetUnchanged: true}
    }
  },
  Info: {
    Source: $info_source, ASN: opt($info_asn), Organization: opt($info_org),
    Latitude: opt($info_lat), Longitude: opt($info_lon), DMS: opt($info_dms),
    Map: opt($info_map), TimeZone: opt($info_timezone), Type: opt($info_type),
    City: {Name: opt($info_city), PostalCode: opt($info_post), SubCode: opt($info_subcode), Subdivisions: opt($info_sub)},
    Region: {Code: opt($info_countrycode), Name: opt($info_country)},
    Continent: {Code: opt($info_continentcode), Name: opt($info_continent)},
    RegisteredRegion: {Code: opt($info_regcountrycode), Name: opt($info_regcountry)}
  },
  Type: {
    Source: {IPinfo: "public demo widget", Ipregistry: "official API", IPQS: $source_ipqs, ipapi: "direct public API", IP2LOCATION: "upstream relay", AbuseIPDB: "upstream relay"},
    Status: {IPinfo: $status_ipinfo, Ipregistry: $status_ipregistry, IPQS: $status_ipqs, ipapi: $status_ipapi, IP2LOCATION: $status_ip2location, AbuseIPDB: $status_abuseipdb},
    Usage: {IPinfo: opt($type_ipinfo_usage), Ipregistry: opt($type_ipregistry_usage), IPQS: opt($type_ipqs_usage), ipapi: opt($type_ipapi_usage), IP2LOCATION: opt($type_ip2_usage), AbuseIPDB: opt($type_abuse_usage)},
    Company: {IPinfo: opt($type_ipinfo_company), Ipregistry: opt($type_ipregistry_company), IPQS: null, ipapi: opt($type_ipapi_company), IP2LOCATION: opt($type_ip2_company), AbuseIPDB: null}
  },
  Score: {IP2LOCATION: opt($score_ip2), SCAMALYTICS: opt($score_scam), ipapi: opt($score_ipapi), AbuseIPDB: opt($score_abuse), IPQS: opt($score_ipqs), Cloudflare: null, DBIP: null},
  ScoreMeta: {
    IP2LOCATION: {Band: opt($band_ip2), Scale: "0-99 potential risk", Status: $status_ip2location, Source: $source_ip2location, RelayStatus: opt($relay_status_ip2location)},
    SCAMALYTICS: {Band: opt($band_scam), Scale: "0-100 fraud", Status: $status_scamalytics, Source: $source_scamalytics, RelayStatus: opt($relay_status_scamalytics)},
    ipapi: {Band: opt($band_ipapi), Scale: "0-100% abuse"},
    AbuseIPDB: {Band: opt($band_abuse), Scale: "0-100 confidence", Status: $status_abuseipdb, Source: $source_abuseipdb},
    IPQS: {Band: opt($band_ipqs), Scale: "0-100 fraud", Status: $status_ipqs, Source: $source_ipqs},
    Cloudflare: {Band: null, Scale: null, Status: $status_cloudflare, Source: "official_api", Reason: "numeric_score_not_provided", LegacyThreatScore: "retired_constant_zero", ThreatCategories: $cloudflare_threats},
    DBIP: {Band: opt($band_dbip), Scale: "low/medium/high (provider label)", Status: $dbip_risk_status, Source: "public_demo", Reason: "provider_label_only"}
  },
  ProviderStatus: {
    IPinfo: $status_ipinfo,
    CheckPlaceMaxMind: $status_maxmind,
    Ipregistry: $status_ipregistry,
    Scamalytics: $status_scamalytics,
    AbuseIPDB: $status_abuseipdb,
    IP2Location: $status_ip2location,
    ipdata: $status_ipdata,
    ipapi: $status_ipapi,
    IPWhois: $status_ipwhois,
    DBIP: $status_dbip,
    Cloudflare: $status_cloudflare,
    IPQS: $status_ipqs
  },
  Factor: {
    CountryCode: {IP2LOCATION: factor($f_ip2_cc), ipapi: factor($f_ipapi_cc), Ipregistry: factor($f_ipregistry_cc), IPQS: factor($f_ipqs_cc), SCAMALYTICS: factor($f_scam_cc), ipdata: factor($f_ipdata_cc), IPinfo: factor($f_ipinfo_cc)},
    Proxy: {IP2LOCATION: factor($f_ip2_proxy), ipapi: factor($f_ipapi_proxy), Ipregistry: factor($f_ipregistry_proxy), IPQS: factor($f_ipqs_proxy), SCAMALYTICS: factor($f_scam_proxy), ipdata: factor($f_ipdata_proxy), IPinfo: factor($f_ipinfo_proxy)},
    VPN: {IP2LOCATION: factor($f_ip2_vpn), ipapi: factor($f_ipapi_vpn), Ipregistry: factor($f_ipregistry_vpn), IPQS: factor($f_ipqs_vpn), SCAMALYTICS: factor($f_scam_vpn), ipdata: factor($f_ipdata_vpn), IPinfo: factor($f_ipinfo_vpn)},
    Tor: {IP2LOCATION: factor($f_ip2_tor), ipapi: factor($f_ipapi_tor), Ipregistry: factor($f_ipregistry_tor), IPQS: factor($f_ipqs_tor), SCAMALYTICS: factor($f_scam_tor), ipdata: factor($f_ipdata_tor), IPinfo: factor($f_ipinfo_tor)},
    Server: {IP2LOCATION: factor($f_ip2_server), ipapi: factor($f_ipapi_server), Ipregistry: factor($f_ipregistry_server), IPQS: factor($f_ipqs_server), SCAMALYTICS: factor($f_scam_server), ipdata: factor($f_ipdata_server), IPinfo: factor($f_ipinfo_server)},
    Abuser: {IP2LOCATION: factor($f_ip2_abuse), ipapi: factor($f_ipapi_abuse), Ipregistry: factor($f_ipregistry_abuse), IPQS: factor($f_ipqs_abuse), SCAMALYTICS: factor($f_scam_abuse), ipdata: factor($f_ipdata_abuse), IPinfo: factor($f_ipinfo_abuse)},
    Robot: {IP2LOCATION: factor($f_ip2_bot), ipapi: factor($f_ipapi_bot), Ipregistry: factor($f_ipregistry_bot), IPQS: factor($f_ipqs_bot), SCAMALYTICS: factor($f_scam_bot), ipdata: factor($f_ipdata_bot), IPinfo: factor($f_ipinfo_bot)}
  },
  FactorMeta: {
    IP2LOCATION: {Status: $status_ip2location, Source: $source_ip2location, RelayStatus: opt($relay_status_ip2location)},
    ipdata: {Status: $status_ipdata, Source: $source_ipdata, RelayStatus: opt($relay_status_ipdata)},
    SCAMALYTICS: {Status: $status_scamalytics, Source: $source_scamalytics},
    ipapi: {Status: $ipapi_risk_status, Source: "public_api", Mode: opt($ipapi_mode), CredentialMode: opt($ipapi_credential_mode)},
    IPWhois: {Status: $ipwhois_risk_status, Source: "public_demo", Reason: "website_demo_security_flags"}
  },
  ProviderContext: {
    DBIP: {
      Provider: "DB-IP", Status: $status_dbip, Mode: "public_demo", IP: opt($dbip_ip),
      CountryCode: opt($dbip_countrycode), Country: opt($dbip_country), Region: opt($dbip_region), City: opt($dbip_city),
      Attribution: "IP geolocation by DB-IP (https://db-ip.com/)"
    },
    IPAPI: {
      Provider: "ipapi.is", Status: $status_ipapi, Mode: opt($ipapi_mode),
      IP: opt($ipapi_ip), CountryCode: opt($ipapi_countrycode), ASN: opt($ipapi_asn), Organization: opt($ipapi_company),
      Country: opt($ipapi_country), City: opt($ipapi_city), Region: opt($ipapi_region),
      TimeZone: opt($ipapi_timezone)
    },
    IPWhois: {
      Provider: "IPWHOIS", Status: $status_ipwhois, Mode: "public_demo",
      CountryCode: opt($ipwhois_countrycode), ASN: opt($ipwhois_asn),
      Organization: opt($ipwhois_org), ISP: opt($ipwhois_isp),
      TimeZone: opt($ipwhois_timezone)
    },
    Cloudflare: {
      Provider: "Cloudflare Security Center IP Intelligence", Status: $status_cloudflare,
      IP: opt($cloudflare_ip), CountryCode: opt($cloudflare_countrycode),
      Network: opt($cloudflare_network), Organization: opt($cloudflare_org),
      InfrastructureType: opt($cloudflare_infrastructure),
      ThreatCategories: $cloudflare_threats
    }
  },
  Ping0: {}, Routing: {}, Exposure: {},
  Mail: ({Port25: boolnull($mail_port25)} + $mail_services + {
    DNSBlacklist: {
      Total: intnull($dns_total), Clean: intnull($dns_clean), Marked: intnull($dns_marked),
      Blacklisted: intnull($dns_blacklisted), Unknown: intnull($dns_unknown), Results: dnsresults($dns_results)
    }
  })
}
| .Factor |= with_entries(.value.IPWhois = null)
| .Factor.CountryCode.IPWhois = factor($ipwhois_countrycode)
| .Factor.Proxy.IPWhois = boolnull($ipwhois_proxy)
| .Factor.VPN.IPWhois = boolnull($ipwhois_vpn)
| .Factor.Tor.IPWhois = boolnull($ipwhois_tor)
| .Factor.Server.IPWhois = boolnull($ipwhois_server)
| if $reputation_enabled then
    .Ping0 = {
      Status: $ping_status, IPMatch: boolnull($ping_match), Location: opt($ping_location),
      ASN: opt($ping_asn), Organization: opt($ping_org), RiskScore: null, RiskStatus: $ping_risk
    }
    | .Routing = {
      Provider: "RIPEstat Network Info", Status: $routing_status,
      Prefix: opt($routing_prefix), OriginASNs: list($routing_origins)
    }
    | .Exposure = {
      Provider: "Shodan InternetDB", Status: $exposure_status,
      Ports: numberlist($exposure_ports), PortCount: intnull($exposure_port_count),
      HostnameCount: intnull($exposure_hostname_count),
      KnownVulnerabilityCount: intnull($exposure_vulns), Tags: list($exposure_tags),
      IsReputationScore: false
    }
  else . end
')||return 1
}
