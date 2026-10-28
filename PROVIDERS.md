# Provider contracts and disclosure

This document describes what the current code queries, what each result means,
and what a live run discloses. It is not a claim that every third party is
available at any particular moment.

## Consent and route boundary

The default reporter and route-runner commands make no network request. A live
run requires the exact `--confirm-network-lookup` flag. Depending on scope, a
third party or DNS resolver can observe the caller's egress IP, the requested
target, query time, user agent, DNS name, and ordinary transport metadata. Raw
reports stay local unless the user separately moves them.

When no positional target is supplied, the reporter discovers a public egress
address before running the selected scope. IPv4 discovery tries, in order:
IPinfo, `ip.sb`, Ping0, ICanHazIP, ipify, ifconfig.co, and Ident.me.
IPv6 discovery uses the same order without IPinfo. It accepts the first
syntactically valid, non-private address, so only services reached before that
success receive a discovery request.

A positional public IP skips egress discovery and is accepted only for
`reputation` or `dnsbl`. Reputation providers receive that target while also
seeing the connection's real transport egress. Ping0 and the DB-IP visitor demo
are skipped for positional targets: their `/geo` and `/self` endpoints report
the caller's egress, not an arbitrary address. They remain visible as
`not_applicable_target`; neither makes a request in this mode.

The route runner maintains two honest measurement boundaries:

- Direct mode removes inherited proxy variables, starts no
  Mihomo process, defaults to IPv4, and runs `reputation` over the system route. A
  system-level VPN or TUN can still affect that route.
- Exact-leaf mode runs only `reputation`. Egress discovery and initial HTTP(S)
  requests use a verified loopback Mihomo for one selected cached-subscription
  leaf. IPQS/Cloudflare target lookups have the disclosed fallback below. DNSBL, SMTP, and
  other direct sockets are excluded because they would measure the host route.

The raw `bin/ip-quality` reporter retains inherited HTTP proxy variables;
DNS and SMTP sockets still use the system route. With proxy variables set, its
HTTP observations and direct-socket probes can therefore describe different
egresses. Use the runner's `--direct` mode for a consistent system-route report.
The raw reporter can attempt both address families unless `-4` or `-6` is given;
DNSBL runs only for IPv4, so an IPv6 `full` report has no DNSBL results. Two
successful families produce consecutive reports/JSON objects; select one family
when a single JSON document is needed.

## Query scopes

| Scope | What it measures | Route restrictions |
| --- | --- | --- |
| `reputation` | Named IP type, score, risk-factor, routing, and exposure observations | Supports automatic egress or one positional public IP; exact-leaf mode uses this scope only |
| `dnsbl` | Every vendored DNSBL zone | IPv4 only; automatic egress or one positional public IPv4 |
| `mail` | Public MX lookup, SMTP greeting probes, and outbound TCP/25 | Current system route; no positional target |
| `mail-dnsbl` | `mail` and `dnsbl` together | Current system IPv4 route |
| `full` | `reputation`, `mail`, and `dnsbl` | Explicit raw-reporter scope; SMTP and DNS use the system route |

`reputation` is the default for both entrypoints. Media/AI unlock tests and the
`Media` JSON section have been removed. `--scope media-ai` now reports an invalid
scope before any network access. Mail and DNSBL remain opt-in because their
many DNS/TCP probes add latency and cannot describe an HTTP-proxied leaf.

## Prefix sampling

Route menu 3 accepts incomplete IPv4 prefixes. It treats three octets as an
assumed /24, accepts explicit `.0/24` notation, deduplicates up to 20 networks
and queries `.23`, `.127`, `.231` from each. All input must
pass the public-IPv4 boundary in `ref/non_public_ipv4.txt` (IANA special-purpose
ranges, shared with the reporter) before any lookup starts. A blank line
finishes a multiline paste. Queries run sequentially over the current system
IPv4 route with proxy variables removed, with the normal sources and fallback
policy. The lookup transport is not the sampled IP's transport.

Each sample can consume the configured providers' API quota; there is no batch
retry loop for timeouts, blocks or rate limits. Per-source failures stay visible
and never become clean scores. The comparison retains each source's scale and
uses Cloudflare or IPWHOIS country/ASN context, without a combined score or a
claim about every IP in a prefix. DB-IP/Ping0 are inapplicable as above.

Batch artifacts contain **full sample IPs** under a unique private directory
in `reports/`: `summary.md`, `summary.json`, and each target's JSON, text report
and stderr log. Summary JSON has `schema_version: 1`, input prefixes/suffixes,
query route, per-sample scores, provider statuses and links to raw evidence.
The summary updates after every sample; Ctrl-C/TERM stops the owned reporter
process group, preserves completed results and marks pending samples. A failed
reporter or malformed/mismatched report is retained as such, while later samples
still run. An empty field is never substituted with another provider's score.

## Source selection

The normal interactive command defaults to all sources. Users need no source
or DNS switches. The optional choices below are maintenance controls:

| Option | Reputation requests |
| --- | --- |
| `--sources all` | All supported sources, including the Check.Place relay datasets |
| `--sources independent` | IPinfo, Ipregistry, ipapi, IPWHOIS, DB-IP, Cloudflare, official IPQS, Ping0, RIPEstat and Shodan; no Check.Place requests, including no unkeyed IPQS relay fallback |
| `--sources ipinfo,ipregistry,ipapi,ipwhois,cloudflare` | Exactly these five reputation sources; an example useful when the relay and IPQS route are unavailable |

The complete, case-sensitive ID list is `maxmind,ipinfo,ipregistry,scamalytics,ipapi,ipwhois,dbip,cloudflare,abuseipdb,ip2location,ipdata,ipqs,ping0,ripestat,shodan`.
[providers/sources.tsv](providers/sources.tsv) is the single catalog of IDs, labels,
the independent preset and plan disclosures; the reporter and route runner both
read it, and plans list only the selected sources (explicit targets show DB-IP
and Ping0 as not applicable). `maxmind` names the Check.Place dataset, not a
direct MaxMind API. Duplicates are
deduplicated; unknown/empty IDs stop before network access. The plan and JSON
`Query.SelectedSources` record the selection. Deliberately unselected sources
have `disabled` status and no terminal column; selected failures remain visible
and unknown. A failed source cannot relabel another platform's score as its own.
Every source's fields reset between address families. Automatic public-egress
discovery remains a separate step unless an explicit target was supplied; it
no longer uses Check.Place, and is not limited by this reputation-source list.

The default `--ipqs-dns auto` repairs the observed direct IPv4 IPQS hostname
resolution failure automatically. Both official account and lookup requests use curl's
`--doh-url https://dns.alidns.com/dns-query`, with certificate verification and
the existing ten-second request deadline. [AliDNS](https://alidns.com/) sees the
IPQS hostname and the DNS request's egress, not the API key or target IP in the
lookup URL. IPQS still sees the original direct egress and requested target.
Only this provider's DNS changes; there is no system setting, fixed IP pin,
new credential or paid plan. Automatic mode preserves system/proxy resolution
on the initial IPv6 and proxy/leaf requests. Without an official key,
the normal all-source run retains its Check.Place IPQS relay path.
Maintenance overrides `system` and `alidns` remain available; forcing AliDNS
requires an official key and a route without proxy variables. JSON
`Query.IPQSDNS` records the effective policy as `system` or `alidns`, or null
when no official IPQS request was attempted. This is policy metadata, not proof
that a DNS packet left the machine. The resolver is not a transport-route fallback.
`Query.TargetMode` distinguishes a discovered egress from an explicit target;
an explicit-target lookup does not test connectivity from that target itself.

### Automatic query-route fallback

The normal all-source command tries the selected route first. For official
IPQS and Cloudflare IP Intelligence only, a connectivity failure before any HTTP
response permits one direct IPv4 retry of the exact same URL/target. This
implements the user's October 11 authorization to use alternate lookup routes.
It never repeats egress discovery: a report for ATT still queries ATT's IP.
IPv6 target addresses also remain unchanged when the lookup transport is IPv4.
Direct IPv4 means proxy variables and reporter interface bindings are overridden;
an existing system VPN/TUN can still influence that transport.

IPQS retains its account-credit preflight. When that request needs fallback,
the following IP lookup stays on direct + verified AliDNS rather than repeating
the broken proxy request. If only the lookup fails, only that lookup is retried.
Cloudflare's fallback uses system DNS. Each request keeps its ten-second deadline
and size bound. HTTP rejection, exhausted quota, certificate-verification errors,
oversized bodies and schema errors never switch route. A lost lookup response
could already have consumed a credit, so the retry is capped at one; failures
on direct do not trigger another provider, account or proxy chain.

The same provider sees the tested target plus the fallback's system-route egress.
The plan discloses this before confirmation. Terminal status uses
`網路備援/<status>` / `network fallback/<status>` for this route recovery and
DB-IP's page recovery. The route note retains the initial error; JSON
`Query.ProviderTransport.IPQS` and
`.Cloudflare` contain `Route` (`selected_route` or `direct_fallback`),
`OriginalRouteFailure` and `TargetUnchanged`. Unattempted official queries have
null route/failure. `ProviderStatus` describes the final response. This metadata
does not claim that the selected node can now connect to that provider.
The shared display label does not change provenance: JSON still distinguishes
`direct_fallback` transport from DB-IP's `public_page` source.

Other sources keep their existing selected-route contracts. In particular,
DB-IP's visitor/self demo and Ping0 observe the caller: changing their transport
would change the measured IP. Egress discovery, DNS and SMTP never use this
fallback. Source fallback (for example Check.Place to Scamalytics's own page)
remains distinct from lookup-route fallback to the same provider.

DB-IP adds one selected-route public IP page read only after its visitor demo
explicitly reports a daily quota. This optional hidden Chrome read uses myutils,
binds the already discovered IPv4 target, and accepts only the page's explicit
low/medium/high label after verified cleanup. It neither obtains another visitor
key nor claims the demo quota recovered. JSON preserves `DemoStatus`, `PageStatus`
and `Source=public_page`; missing browser dependencies leave risk unknown.
Browser transport follows the selected proxy/system route; unlike curl it does
not force an address family. IPv6 targets or curl interface bindings skip it.

ipapi's documented account-denied/invalid-key JSON errors allow one keyless
lookup for the same target on the same route/family. That published anonymous
tier supplies context only; type, score and factor tables preserve the primary
restriction. HTTP 429, generic 403, TLS and certificate errors do not trigger
this fallback. JSON records both outcomes and the provider's error code.

On October 10, a strict direct run with AliDNS completed the official IPQS
lookup; the same-key ATT route still failed TLS. IPinfo, Ipregistry, ipapi,
IPWHOIS and Cloudflare Intel worked on both routes. DB-IP was rate limited.
These are dated observations, not permanent availability guarantees.

## Reputation providers

| Report source | Access style | Retained observations |
| --- | --- | --- |
| Check.Place response labeled MaxMind by the upstream payload | Upstream relay | ASN, organization, city/region, registered region, coordinates, timezone |
| IPinfo public demo widget | Direct public demo component, not the token-authenticated API | ASN/company type, country, privacy flags, location |
| Ipregistry IP Intelligence | Direct official API when `IPREGISTRY_API_KEY` is configured | Connection/company type, country, proxy, VPN, Tor, cloud-hosting, abuse/attack signals |
| Scamalytics | Check.Place relay, then one official public target-page fallback on failure | Fraud score, provider risk label when supplied, country and available proxy/VPN/Tor/server/blacklist/bot indicators; source labeled separately |
| ipapi.is | Direct public API; anonymous or optional free-tier key | Anonymous ASN/ownership/geography context, or keyed ASN/company type, provider-supplied abuser-score label, and risk factors |
| IPWHOIS website demo | Direct public demo, no account/key | Country, network context and any supplied proxy/VPN/Tor/hosting flags; explicit demo rate-limit status |
| DB-IP website visitor demo and public detail page | Public visitor token used transiently; daily quota can use one hidden-browser page read, no account | Original low/medium/high label bound to the target; geography only when supplied by the demo; each outcome retained |
| Cloudflare Security Center IP Intelligence | Direct official API when both Cloudflare credentials are configured | Country, ASN/provider context, infrastructure type, named threat categories; no universal numeric score |
| AbuseIPDB | Official APIv2 with an owned key; otherwise Check.Place relay | Abuse-confidence score and usage type, validated against the requested IP |
| IP2Location | Check.Place relay, then its public target page on failure | Original 0-99 potential-risk score, usage/company type and explicit proxy-category flags |
| ipdata | Owned developer key: official API; otherwise Check.Place relay, then ipdata.free on failure | Owned free key/relay: country and supplied risk flags; keyless fallback: country only, risk unknown |
| IPQualityScore | Direct official API with `IPQS_API_KEY`; otherwise the named Check.Place relay | Connection type, 0-100 fraud score, country, proxy/VPN/Tor/abuse/bot factors |
| Ping0 public `/geo` | Direct official public endpoint | Exact returned IP match, location, ASN, organization; no public risk score |
| RIPEstat Network Info | Direct official public API | Covering routed prefix and origin ASNs; context, not a score |
| Shodan InternetDB | Direct official public API, IPv4 only | Observed ports, hostname count, tags, known-vulnerability count; context, not a score |

Terminal output maps those sources by meaning rather than pretending that all
fields are comparable:

| Destination | Sources |
| --- | --- |
| Basic information | Check.Place/MaxMind-shaped response, with IPinfo as fallback; separately named Cloudflare query status, ASN context and supplied threat categories |
| Type matrix | IPinfo, Ipregistry, IPQS, ipapi.is, IP2Location, AbuseIPDB; attempted/unconfigured sources retain columns and query status even without a type |
| Score section | IP2Location, Scamalytics, ipapi.is, AbuseIPDB, IPQS; DB-IP supplies its original threat label with a null numeric score. Cloudflare appears only in basic information |
| Factor matrix | IP2Location, ipapi.is, Ipregistry, IPQS, Scamalytics, ipdata, IPinfo and IPWHOIS; attempted sources retain columns and lookup status even when risk data is missing |
| Official/public network observations | Ping0, RIPEstat, Shodan InternetDB; anonymous ipapi context if relevant. Cloudflare, DB-IP and IPWHOIS are absent from section 5 |

All three matrices retain attempted-source columns after TLS/transport failures,
rate limits, quota exhaustion or schema errors. Type adds a query-status row;
score/factor retain their existing status rows. Missing values are `-`, never
zero/false. Explicit `not_configured` states also remain visible in applicable
matrices. Within those matrices, a source with neither status nor observation
is omitted.
JSON adds IPinfo status and fills every type source's status alongside the
existing provider statuses.

### Independent recovery for relay-backed sources

The default all-source run has independent fallbacks for three relay-backed sources:
[IP2Location](providers/ip2location.md), [ipdata](providers/ipdata.md) and
[AbuseIPDB](providers/abuseipdb.md) (owned key).

Each additional request uses the selected route/address family, a ten-second
deadline and a response-size bound. There is no redirect, retry or direct-route
escape. Successful IP2Location/ipdata relays need no fallback request. An owned
ipdata developer key selects its official risk API before any relay request;
keyed failures retain their status without trying another source.
`ScoreMeta.IP2LOCATION`, `FactorMeta.IP2LOCATION` and `FactorMeta.ipdata` retain
`Source`, final `Status` and `RelayStatus`; AbuseIPDB's score metadata records
its chosen source. Terminal labels distinguish relay, public demo and official
API. The provider schemas remain in `providers/`, using shared HTTP/value helpers.
For ipdata without a key, the keyless fallback restores only country data. Its provider status
is `ok`, while `FactorMeta.ipdata.Status=not_provided` and
`Reason=free_geolocation_only`; the factor table retains unknown risk cells.
The October 26 website redesign removed the previously published demo key.
The October 27 free developer account restored the supplied risk flags through
both direct and ATT, without relying on that old demo key or Check.Place.

On October 11, the current NodeQuality launcher still delegated to Check.Place.
Other tools such as [howismyip's IP2Location adapter](https://github.com/superagents-lab/howismyip/blob/main/packages/core/src/providers/ip2location.ts)
use provider website observations, while its AbuseIPDB adapter uses an owned
official key. Those access patterns informed these independently implemented
parsers. We do not copy inferred false flags or manufacture scores from booleans.

## Interpretation rules

Source-specific contracts live next to each adapter: [Check.Place relays and
MaxMind basic data](providers/check_place.md), [ipapi.is](providers/ipapi.md),
[IPWHOIS](providers/ipwhois.md), [DB-IP](providers/dbip.md),
[Cloudflare](providers/cloudflare.md), [Scamalytics](providers/scamalytics.md),
[IP2Location](providers/ip2location.md), [ipdata](providers/ipdata.md),
[AbuseIPDB](providers/abuseipdb.md) and [IPQS](providers/ipqualityscore.md).

- Results remain per source. Conflicting answers stay visible and score scales
  are never averaged into a synthetic rating.
- A provider failure, rate limit, quota response, malformed body, target mismatch,
  or schema change is `Unknown`/unavailable, not clean. A missing required command
  stops the run with an explicit dependency error before a report is produced.
- The additional providers retain visible source status in their assigned sections.
  Missing Cloudflare credentials are shown as unconfigured. Context IP fields use the
  same masking as `Head.IP`. Cloudflare category names remain intact JSON strings,
  including names containing commas.
- A field missing from an otherwise useful result appears as `-` in the terminal
  matrix and `null` in JSON. Unavailable sources retain their named status or a
  compact summary. IPQS remains visible with its source/status even without a
  numeric score, including when an official quota preflight prevents lookup.
- The reporter shows a provider's textual score label only when the response
  supplies it. It does not invent a band from local thresholds. Current numeric
  scales remain distinct: IP2Location 0-99 potential risk, Scamalytics 0-100
  fraud, ipapi.is 0-100% abuse, AbuseIPDB 0-100 confidence, and IPQS 0-100 fraud.
- Ping0 accepts exactly four bounded lines after a successful HTTP response and
  requires the returned IP to match. TLS, timeout, HTTP and malformed-response
  failures stay identifiable in JSON and the terminal unavailable-source summary.
  RIPEstat validates prefix/ASN structure. Shodan validates the target IP and
  bounded arrays. Ports must be integers from 1 through 65535, and text array
  elements must be bounded strings without control characters; malformed values
  are unavailable, not usable observations. Its documented no-information response means no public record,
  not a clean reputation judgment. Arbitrary upstream error text is not echoed.
- Default terminal and JSON output mask both the tested address and any RIPEstat
  prefix derived from it. `-f` is required to reveal either.

## Optional official credentials

Accepted key names, file locations, precedence and validation are in
[CREDENTIALS.md](CREDENTIALS.md#reporter-api-keys). Without an Ipregistry key,
no Ipregistry request is made; its type and factor columns remain visible with
`not_configured` and unknown values. Per-source key behavior and quotas are in
the linked source contracts; DB-IP/IPWHOIS free APIs versus their website demos
are compared in [providers/dbip.md](providers/dbip.md) and
[providers/ipwhois.md](providers/ipwhois.md).

## Mail and DNSBL scopes

Their probe and outcome contracts are in [providers/mail.md](providers/mail.md)
and [providers/dnsbl.md](providers/dnsbl.md). Both always remain system-route
observations and are never attributed to an isolated HTTP proxy leaf.

## Deliberate non-sources

IpScore, IPLeak, Whoer, Wave Broadband, GreyNoise, VirusTotal, and
NodeQuality are not implemented report sources. NodeQuality's disk, CPU, memory,
and iperf sections are host benchmarks rather than IP reputation observations;
they remain outside this reporter's scope. Historical research mentions are not
report evidence; the old DB-IP scraper/paid-adapter removal and other exclusions are recorded in
[UPSTREAM.md](UPSTREAM.md). A new source needs a named access contract,
sanitized fixture, conservative parser, route boundary, and disclosure.

## Official references

DB-IP, Cloudflare IP Intelligence and ipwho.is contracts checked on 2026-09-24;
the remaining references were checked on 2026-09-22:

- [IPinfo developer documentation](https://ipinfo.io/developers)
- [ipapi.is developer documentation](https://ipapi.is/developers.html)
- [IPWHOIS homepage demo](https://ipwhois.io/), [current demo JavaScript](https://ipwhois.io/js/theme.min.js), and [API documentation](https://ipwhois.io/documentation)
- [DB-IP public homepage demo](https://db-ip.com/)
- [DB-IP permanent free API](https://db-ip.com/api/free), [response contract](https://db-ip.com/api/doc.php), and [paid Extended fields](https://db-ip.com/api/extended)
- [Cloudflare IP Intelligence API](https://developers.cloudflare.com/api/resources/intel/subresources/ips/methods/get/)
- [Cloudflare Threat Intelligence API limits](https://developers.cloudflare.com/security-center/intel-apis/limits/)
- [Cloudflare legacy Threat Score retirement](https://developers.cloudflare.com/waf/tools/security-level/#threat-score)
- [Historical upstream v2025-03-13 source](https://github.com/xykt/IPQuality/blob/b3ad433931db9882673e070f59edaf17d56e05ac/ip.sh)
- [ipapi.co pricing and free-trial terms](https://ipapi.co/pricing/)
- [Ipregistry authentication](https://ipregistry.co/docs/authentication)
- [IPQualityScore API overview](https://www.ipqualityscore.com/documentation/proxy-detection-api/overview),
  [response parameters](https://www.ipqualityscore.com/documentation/proxy-detection-api/response-parameters),
  and [credit usage API](https://www.ipqualityscore.com/documentation/account-management/usage)
- [Ping0 public API description](https://ping0.cc/ip/api)
- [RIPEstat Network Info contract](https://stat.ripe.net/docs/data-api/api-endpoints/network-info.html)
- [Shodan InternetDB](https://internetdb.shodan.io/)
- [IP2Location IP2Proxy fields](https://www.ip2location.com/documentation/ip2proxy-libraries/lua/api)
- [AbuseIPDB API documentation](https://docs.abuseipdb.com/)
- [Spamhaus DNSBL usage and return codes](https://www.spamhaus.org/faqs/dnsbl-usage/)
  and [fair-use policy](https://www.spamhaus.org/blocklists/dnsbl-fair-use-policy/)
- [UCEPROTECT level overview](https://www.uceprotect.net/en/?m=7&s=0) and
  [Level 3 policy](https://www.uceprotect.net/en/index.php?m=3&s=5UCEPROTECT-Level)
