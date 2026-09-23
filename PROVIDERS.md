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
| ipwho.is | Direct public API, no key | Country, ASN, organization, ISP, timezone context; the free tier does not expose security fields |
| DB-IP Free | Direct public API, no account/key | Country, region and city only; no free threat level or proxy/VPN signals |
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
| Score section | Numeric matrix: IP2Location, Scamalytics, ipapi.is, AbuseIPDB, IPQS. Named status lines: Cloudflare threat categories and DB-IP's free-tier score limitation |
| Factor matrix | IP2Location, ipapi.is, Ipregistry, IPQS, Scamalytics, ipdata, IPinfo when a factor exists; ipwho.is shows country plus explicit unavailable security fields |
| Official/public network observations | Ping0, RIPEstat, Shodan InternetDB, ipwho.is, DB-IP Free, Cloudflare IP Intelligence when configured |

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
- `ipwho.is` validates the returned target IP and retains only the free endpoint's
  location/network/timezone fields. The absence of its paid security object is
  not treated as a clean proxy, VPN, Tor, hosting, or abuse result.
  Section 4 keeps its named column and query status; unavailable factors are `-`.
  JSON retains null factors and explains the free-tier limitation in FactorMeta.
- DB-IP Free validates the exact target and bounded geography fields. Its
  section-3 status explains why no free risk grade exists, while section 5 keeps
  the geography and DB-IP attribution. Unexpected premium/security fields are
  ignored, not promoted to free risk evidence. JSON Score.DBIP is null and
  ScoreMeta.DBIP.Reason is free_tier_geography_only.
- Cloudflare IP Intelligence validates the target IP, ASN reference, and bounded
  threat-category objects. Its categories remain source-specific observations;
  they are not converted into the project's other boolean factors or a score.
  A live response on 2026-09-22 supplied a numeric ASN despite the documentation's
  string example; valid 32-bit numeric ASNs are normalized to `AS<number>`.
  Missing `risk_types` stays `null` in JSON, while an explicitly empty array stays
  `[]`. A null `threat_summary` supplies no clean-IP evidence.
  Section 3 shows its official status and actual threat categories beside the
  numeric score matrix. Missing categories say "not supplied"; an empty array
  says none listed, without claiming a clean IP. Score.Cloudflare remains null.
- The additional providers always have a visible source-status line.
  Anonymous ipapi explicitly explains the free-key requirement; missing
  Cloudflare credentials are shown as unconfigured. Context IP fields use the
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
The anonymous `ipapi.is` path requires no key, is limited to 100 lookups per
client IPv4 or IPv6 `/64` per UTC day, and returns a minimal response. A free
ipapi.is account key raises the documented allowance to 1,000 lookups per day
and unlocks the complete response used by the type, score, and factor tables.
The reporter reads that optional key from `IPAPI_API_KEY` or `secrets/ipapi`.
DB-IP's permanent free endpoint is `https://api.db-ip.com/v2/free/{IP}` and
documents 500 requests per day. It requires no account, key, billing or 2FA.
Its country/state/city response is distinct from the paid Extended API's threat
level, crawler and proxy fields. No paid trial or Extended credential is used.
The free `ipwho.is` endpoint requires no key and documents a limit of 1,000
requests per client IP per day; its free response has no security data. Cloudflare
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

## Official references

DB-IP, Cloudflare IP Intelligence and ipwho.is contracts checked on 2026-09-24;
the remaining references were checked on 2026-09-22:

- [IPinfo developer documentation](https://ipinfo.io/developers)
- [ipapi.is developer documentation](https://ipapi.is/developers.html)
- [ipwho.is API documentation](https://ipwhois.io/documentation)
- [DB-IP permanent free API](https://db-ip.com/api/free), [response contract](https://db-ip.com/api/doc.php), and [paid Extended fields](https://db-ip.com/api/extended)
- [Cloudflare IP Intelligence API](https://developers.cloudflare.com/api/resources/intel/subresources/ips/methods/get/)
- [Cloudflare Threat Intelligence API limits](https://developers.cloudflare.com/security-center/intel-apis/limits/)
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
