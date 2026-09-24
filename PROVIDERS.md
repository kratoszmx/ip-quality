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
IPinfo, Check.Place, `ip.sb`, Ping0, ICanHazIP, ipify, ifconfig.co, and Ident.me.
IPv6 discovery uses the same order without IPinfo. It accepts the first
syntactically valid, non-private address, so only services reached before that
success receive a discovery request.

A positional public IP skips egress discovery and is accepted only for
`reputation` or `dnsbl`. Reputation providers receive that target while also
seeing the connection's real transport egress. Ping0 is skipped for positional
targets because its public `/geo` endpoint reports the caller's egress, not an
arbitrary address.

The route runner maintains two honest measurement boundaries:

- Direct mode removes inherited proxy variables, starts no
  Mihomo process, defaults to IPv4, and runs `reputation` over the system route. A
  system-level VPN or TUN can still affect that route.
- Exact-leaf mode runs only `reputation`. Its HTTP(S) requests use a verified
  loopback Mihomo for one selected cached-subscription leaf. DNSBL, SMTP, and
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

## Reputation providers

| Report source | Access style | Retained observations |
| --- | --- | --- |
| Check.Place response labeled MaxMind by the upstream payload | Upstream relay | ASN, organization, city/region, registered region, coordinates, timezone |
| IPinfo public demo widget | Direct public demo component, not the token-authenticated API | ASN/company type, country, privacy flags, location |
| Ipregistry IP Intelligence | Direct official API when `IPREGISTRY_API_KEY` is configured | Connection/company type, country, proxy, VPN, Tor, cloud-hosting, abuse/attack signals |
| Scamalytics via `ipinfo.check.place` | Upstream relay | Fraud score, proxy, VPN, Tor, blacklist/bot indicators |
| ipapi.is | Direct public API; anonymous or optional free-tier key | Anonymous ASN/ownership/geography context, or keyed ASN/company type, provider-supplied abuser-score label, and risk factors |
| IPWHOIS website demo | Direct public demo, no account/key | Country, network context and any supplied proxy/VPN/Tor/hosting flags; explicit demo rate-limit status |
| DB-IP website visitor demo | Public page token used transiently, no account | Original low/medium/high threat label plus geography, only if returned egress matches target; explicit demo failures |
| Cloudflare Security Center IP Intelligence | Direct official API when both Cloudflare credentials are configured | Country, ASN/provider context, infrastructure type, named threat categories; no universal numeric score |
| AbuseIPDB via `ipinfo.check.place` | Upstream relay | Abuse-confidence score and usage type |
| IP2Location via `ipinfo.check.place` | Upstream relay | 0-99 potential-risk score, usage/company type, proxy-category factors |
| ipdata via `ipinfo.check.place` | Upstream relay | Country and threat factors |
| IPQualityScore | Direct official API with `IPQS_API_KEY`; otherwise the named Check.Place relay | Connection type, 0-100 fraud score, country, proxy/VPN/Tor/abuse/bot factors |
| Ping0 public `/geo` | Direct official public endpoint | Exact returned IP match, location, ASN, organization; no public risk score |
| RIPEstat Network Info | Direct official public API | Covering routed prefix and origin ASNs; context, not a score |
| Shodan InternetDB | Direct official public API, IPv4 only | Observed ports, hostname count, tags, known-vulnerability count; context, not a score |

Terminal output maps those sources by meaning rather than pretending that all
fields are comparable:

| Destination | Sources |
| --- | --- |
| Basic information | Check.Place/MaxMind-shaped response, with IPinfo as fallback |
| Type matrix | IPinfo, Ipregistry, IPQS, ipapi.is, IP2Location, AbuseIPDB when a type exists in the response |
| Score section | IP2Location, Scamalytics, ipapi.is, AbuseIPDB, IPQS; Cloudflare and DB-IP have named columns with null numeric scores. Cloudflare supplies threat categories; DB-IP supplies its original threat label when available |
| Factor matrix | IP2Location, Ipregistry, IPQS, Scamalytics, ipdata, IPinfo when a factor exists; ipapi.is and IPWHOIS retain columns and lookup status even when risk data is missing |
| Official/public network observations | Ping0, RIPEstat, Shodan InternetDB; anonymous ipapi context if relevant. Cloudflare, DB-IP and IPWHOIS are absent from section 5 |

## Interpretation rules

- Results remain per source. Conflicting answers stay visible and score scales
  are never averaged into a synthetic rating.
- A provider failure, rate limit, quota response, malformed body, target mismatch,
  or schema change is `Unknown`/unavailable, not clean. A missing required command
  stops the run with an explicit dependency error before a report is produced.
- The ipapi.is adapter validates the returned IP and accepts both documented
  response tiers: the flat anonymous response and the keyed nested response.
  Anonymous data is shown as context only; it supplies no proxy, VPN, Tor,
  hosting, abuse, type, or score evidence. Error bodies, quota responses, and
  malformed nested sections become an explicit unavailable status, with the
  upstream body and jq diagnostics kept out of the terminal report.
  Section 4 keeps the ipapi.is column on failures or anonymous responses. Its
  footer distinguishes the key actually supplied, response tier and missing
  risk data; `FactorMeta.ipapi` records these separately from API availability.
  Curl timeout, TLS-handshake and certificate-verification failures have separate
  statuses; none implies an exhausted API allowance. A 2026-09-24 comparison
  returned a full keyed response over direct access and curl 35 before HTTP
  over isolated ATT, including a TLS 1.2 and official diagnostic-host check.
  This establishes a route-specific transport failure, not its remote cause.
  Runtime keeps certificate checks and the chosen route; it does not secretly
  fetch the observation through direct access or pin a diagnostic hostname.
- IPWHOIS uses its current homepage demo, `https://ipwhois.io/demo?ip={IP}`.
  The old upstream used `/widget`; its current JavaScript uses `/demo`.
  Requests include its website Origin/Referer and browser request headers. On
  2026-09-24 a paired direct-route check returned a rate-limit body without
  those headers and valid security fields with them. A limit message alone
  therefore does not prove the user's own daily allowance was exhausted.
  Section 4 accepts only actual boolean proxy/VPN/Tor/hosting fields in
  `security`, bound to the exact returned target. Missing fields stay null,
  including abuse/bot fields that the demo does not supply. HTTP 200 with
  `success:false` and a rate-limit message means `rate_limited`, not usable.
  `FactorMeta.IPWhois` records `public_demo` and the risk-query status.
- DB-IP reads `https://db-ip.com/api/core/`, extracts its bounded public visitor
  token into memory, then reads `https://api.db-ip.com/v2/{token}/self?convertCurrencies`
  with the website headers. This visitor endpoint returned a risk label when
  the old `/demo/home.php` target lookup reported its query limit. Both requests
  preserve the selected route and IP family. The token URL is sent through curl
  stdin, never saved or printed. No remote script is executed. The returned
  `ipAddress` must equal the tested IP; an explicit unrelated target or changed
  egress becomes `ip_mismatch`, never another IP's risk. It validates bounded
  geography and a `threatLevel` of low/medium/high. A missing label remains unknown. The original
  label is in section 3 and `ScoreMeta.DBIP.Band`; `Score.DBIP` remains null.
  HTTP 200 with `OVER_QUERY_LIMIT` or explicit query-limit text means `rate_limited`. No label is
  converted to a 0/50/100 score. No public embedded API key is scraped or saved.
  The no-key free geography contract is retained only for the MCP's optional
  `free_api` probe; unexpected premium fields there still cannot supply risk.
- Cloudflare IP Intelligence validates the target IP, ASN reference, and bounded
  threat-category objects. Its categories remain source-specific observations;
  they are not converted into the project's other boolean factors or a score.
  A live response on 2026-09-22 supplied a numeric ASN despite the documentation's
  string example; valid 32-bit numeric ASNs are normalized to `AS<number>`.
  Missing `risk_types` stays `null` in JSON, while an explicitly empty array stays
  `[]`. A null `threat_summary` supplies no clean-IP evidence.
  Section 3 includes a Cloudflare column, official query status and actual threat
  categories. Missing categories say "not supplied"; an empty array says none
  listed, without claiming a clean IP. Score.Cloudflare remains null.
  Cloudflare's current WAF documentation says legacy Threat Score is always 0
  and no longer populated. The old upstream fetched `.ip.riskScore` from the
  third-party `ip.nodeget.com` and assigned local risk bands. That old zero is
  not restored as a low-risk result. JSON marks LegacyThreatScore as
  `retired_constant_zero`; the terminal also explains the retirement.
- The additional providers retain visible source status in their risk sections.
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
- Check.Place rows are explicitly labeled `Upstream relay`; they are not treated
  as owner-controlled official accounts. Its MaxMind-shaped payload does not
  prove that this machine owns a `.mmdb`, a MaxMind subscription, or a known
  edition/build.
- Each Check.Place-backed request keeps an independent HTTP status. The parser
  distinguishes its known Cloudflare block page from an ordinary HTTP 403, and
  one relay failure cannot erase a successful sibling. JSON exposes these states
  in `ProviderStatus`.
- Ping0 accepts exactly four bounded lines and requires the returned IP to match.
  RIPEstat validates prefix/ASN structure. Shodan validates the target IP and
  bounded arrays; its documented no-information response means no public record,
  not a clean reputation judgment. Arbitrary upstream error text is not echoed.
- Default terminal and JSON output mask both the tested address and any RIPEstat
  prefix derived from it. `-f` is required to reveal either.

## Optional official credentials

The global data-only assignment file is
`${XDG_CONFIG_HOME:-$HOME/.config}/ipquality/credentials` and accepts only:

```text
IPREGISTRY_API_KEY=...
IPAPI_API_KEY=...
IPQS_API_KEY=...
CLOUDFLARE_API_TOKEN=...
CLOUDFLARE_ACCOUNT_ID=...
```

This checkout can instead or additionally use ignored raw-key files:

```text
secrets/ipregistry
secrets/ipapi
secrets/ipqs
secrets/cloudflare_token
secrets/cloudflare_account_id
```

Project-local values override the corresponding global value. Credential files
must be regular, readable, owned by the current user, and mode `600` or stricter;
links and group/other permission bits are rejected. Names, duplicates, file
syntax, and key characters are validated without executing the file. Keys are
fed to curl through standard-input configuration, so they do not appear in
process arguments, Git configuration, or reports.

Without an Ipregistry key, its optional column is absent. Without an IPQS key,
the reporter uses the named Check.Place relay and records that source. With an
IPQS key, it first calls the account-usage endpoint; a confirmed zero balance or
insufficient-credit response stops before the reputation request. Other failures
remain attributed to the official path rather than being described as a clean IP.
When the account preflight and the official lookup both succeed, the report marks
IPQS as `官方/可用`; the current terminal and JSON reports do not expose the
account's remaining credit balance. The preflight value is used only to gate the
paid lookup.
The anonymous `ipapi.is` path requires no key and returns a minimal response.
On 2026-09-24 its official pages disagree on the anonymous daily limit (30 on
the free-tier page; 100 on the developer page). Treat HTTP 429/Retry-After as
authoritative for an actual request, without retrying into a firewall ban. A free
ipapi.is account key raises the documented allowance to 1,000 lookups per day
and unlocks the complete response used by the type, score, and factor tables.
The reporter reads that optional key from `IPAPI_API_KEY` or `secrets/ipapi`.
DB-IP's permanent free endpoint is `https://api.db-ip.com/v2/free/{IP}` and
documents 500 requests per day. It requires no account, key, billing or 2FA.
Its country/state/city response is distinct from the paid Extended API's threat
level, crawler and proxy fields. No paid trial or Extended credential is used.
The free `ipwho.is` endpoint requires no key and documents a limit of 1,000
requests per client IP per day; its free response has no security data. These
permanent free quotas do **not** describe the separate website demos used by the
reporter. Demo quotas are unspecified and their availability is not guaranteed.
IPWHOIS gets one bounded target request; DB-IP gets one page and one bounded
visitor lookup per report. There is no automatic retry,
route rotation, paid signup, account or 2FA. No geography-only fallback hides a
failed risk lookup behind an "available" risk status. The account MCP can probe
either `free_api` or `public_demo` separately without account creation.

The earlier 2026-09-24 failures came from the old DB-IP target demo and bare
IPWHOIS requests. Later direct comparisons returned a DB-IP `low` visitor label
and real IPWHOIS security booleans using the requests above. The precise server
throttling policy is unpublished. Do not attribute these failures to an exhausted
personal quota or dismiss all website demos as unavailable. Permanent geography
API quotas are separate and cannot promise security fields. If the corrected
request is throttled, stop, respect a supplied Retry-After/reset time, and keep
the remaining sources; repeated requests or rotating accounts is not a fix.

Cloudflare
Security Center's IP Intelligence endpoint requires an account ID and an API
token with Intel Read (or Intel Write) permission. Cloudflare documents 100
Threat Intelligence API calls per month on Free, Pro, and Business plans; calls
made by other Security Center features also consume that monthly quota. The
reporter does not attempt to estimate remaining provider quota.
The similarly named `ipapi.co` is a different product with a contact-gated free
trial. This project uses `ipapi.is`, with a free key when configured; the two
providers must not be silently combined.

## Mail scope

The reporter resolves public MX records for Gmail, Outlook, Yahoo, Apple, QQ,
Mail.ru, AOL, GMX, Mail.com, 163, Sohu, and Sina. For each service it selects one
MX host with the lowest numeric preference, makes a bounded TCP/25 connection,
looks for an SMTP `220` greeting, sends `QUIT`, and submits no message. It does
not retry alternate MX hosts. A separate Mailgun greeting probe describes local
outbound TCP/25 reachability. The operating system chooses the actual local
source address, so the check works on a directly addressed host or behind NAT.

## DNSBL scope

The reporter reverses one IPv4 address and queries every unique zone in the
vendored `ref/dnsbl.list`. The current self-test validates 422 zones. Concurrency
is configurable from 1 through the hard maximum of 50.

Outcomes follow the implemented command result:

- `Clean`: `dig` succeeds and returns no address;
- `Blacklisted`: the answer is exactly `127.0.0.2`;
- `Marked`: a different non-empty ordinary answer is returned;
- `Unknown`: `dig` fails, times out, or returns a `127.255.255.*` resolver-policy
  error.

Terminal output names every `Blacklisted` and `Marked` zone. JSON retains a
per-zone `Results` object as well as totals. Spamhaus codes such as
`127.255.255.252`, `.254`, and `.255` are therefore errors, not listing or clean
evidence. Resolver policy and each zone operator's terms still determine whether
a DNSBL answer is authoritative.

UCEPROTECT Level 2 and Level 3 are netblock/allocation and ASN/provider-level
signals; they are not proof that the individual address sent spam. DNSBL, MX,
and SMTP checks always remain system-route observations and are never attributed
to an isolated HTTP proxy leaf.

## Deliberate non-sources

IpScore, IPLeak, Whoer, Wave Broadband, GreyNoise, VirusTotal, and
NodeQuality are not implemented report sources. NodeQuality's disk, CPU, memory,
and iperf sections are host benchmarks rather than IP reputation observations;
they remain outside this reporter's scope. Historical research mentions are not
report evidence; the old DB-IP scraper/paid-adapter removal and other exclusions are recorded in
[UPSTREAM.md](UPSTREAM.md). A new source needs a named access contract,
sanitized fixture, conservative parser, route boundary, and disclosure.

### Comparing the supplied NodeQuality report

The user's [NodeQuality report](https://nodequality.com/r/IHfGBj2jD8OT7BqBNUbCWTWV3XRIbpMB)
states 2025-03-24 and v2025-03-13. That upstream version queried DB-IP's old
target demo, IPWHOIS /widget and third-party ip.nodeget.com/json .ip.riskScore
under the Cloudflare label. On 2026-09-24 that third-party endpoint returned
HTTP 200 without riskScore in a direct check. This does not invalidate the
historical report, but it cannot establish today's field availability.
Cloudflare's own current documentation independently says its old Threat Score
is no longer populated and is always zero. The current official Intel API
provides categories, not that historical numeric field.

[Current NodeQuality source](https://github.com/LloydAsp/NodeQuality/blob/main/NodeQuality.sh)
still launches IP.Check.Place. Its current IPQuality source identifies itself as
v2026-09-16, has no Cloudflare/IPWHOIS query functions, and uses DB-IP's visitor
demo. The current request contract was useful: it led to a working DB-IP
integration here. Historical and current code, and a successful API response
versus a populated risk field, should be compared separately.

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
