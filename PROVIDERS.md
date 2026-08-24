# Provider and disclosure inventory

Every live scope first discovers the current egress address through a bounded
fallback list of HTTPS IP-echo services. It then sends that address, or traffic
originating from it, to the selected sources below. A listed source can observe
the IP, request time, user agent, and ordinary transport metadata.

## Egress address discovery

The fallback set is IPinfo, Check.Place, `ip.sb`, Ping0, ICanHazIP, ipify,
ifconfig.co, and Ident.me. The first syntactically valid answer is used; private
or malformed addresses are not accepted as a successful public result.

## Reputation scope

| Report row | Access style | Main observations |
| --- | --- | --- |
| Check.Place relay (upstream labels the payload as MaxMind) | Upstream relay | ASN, organization, city/region, registered region, coordinates, timezone |
| IPinfo public demo widget | Direct public demo component, not the token-authenticated API | ASN/company type, country, privacy flags, location |
| Scamalytics via `ipinfo.check.place` | Upstream relay | score, proxy, VPN, Tor, blacklist/bot indicators |
| ipapi.is | Direct public API | ASN/type, provider-supplied abuser-score label, and risk factors |
| AbuseIPDB via `ipinfo.check.place` | Upstream relay | abuse score and usage/risk factors |
| IP2Location via `ipinfo.check.place` | Upstream relay | 0–99 potential-risk score and proxy-category factors |
| ipdata via `ipinfo.check.place` | Upstream relay | country and threat factors |
| IPQualityScore via `ipinfo.check.place` | Upstream relay | fraud score and proxy/VPN/Tor/bot factors |
| Ping0 public `/geo` | Direct official public endpoint | returned IP, location, ASN, and organization; the returned IP must exactly match the tested address |
| RIPEstat Network Info | Direct official public API | routed prefix and origin ASN data from RIPE routing data; context only, not a reputation score |
| Shodan InternetDB | Direct official public API, IPv4 | observed public ports, hostnames, tags, and known-vulnerability count; context only, not a reputation score |

“Upstream relay” is intentionally visible in the report model: it is not treated
as equivalent to a user-owned subscription to each vendor's official API. If a
relay or direct page changes schema, its result is unknown rather than clean.
Allowlisted provider failures are kept more specific: an exhausted upstream
IPQualityScore credit pool is reported as such, and Shodan's documented
no-information response is reported as no public record. Neither state is a
clean reputation result, and arbitrary upstream error text is never echoed.
Score scales are shown per provider and are not averaged. A textual label is
shown only when that provider explicitly returned it. The reporter does not
invent a band from local thresholds: a missing label remains `Unknown`, even
when the numeric score is present. At present, ipapi.is supplies an informal
label inside `company.abuser_score`; the relay responses used for Scamalytics,
AbuseIPDB, IP2Location, and IPQualityScore supply numbers without a label.

The basic-information heading deliberately does not claim that this machine owns
or queries a local MaxMind database. No `.mmdb`, MaxMind account credential, or
GeoIP updater is part of this repository. The relay payload uses MaxMind-shaped
field names, but its edition, build date, and transformation chain cannot be
verified locally. Treat it as one attributed upstream observation.

For a future credentialed implementation, use locally updated official MaxMind
GeoLite2 City and ASN databases for approximate geography and routing ownership,
then add the paid GeoIP Anonymous IP or IP Risk product only if those risk fields
are actually licensed. Keep direct IPinfo/ipapi.is observations and RIPEstat
routing context alongside MaxMind instead of replacing all sources with one
database. Geography, network type, anonymization, abuse, and open-port context are
different questions and must remain separate.

IPinfo's documented API uses `api.ipinfo.io` with an access token. This project
currently calls the separate public `/widget/demo/` component and labels it as
such; it does not imply API-account ownership. ipapi.is documents its public
endpoint and the two-part `abuser_score` string, including the provider's own
informal description. See the [IPinfo developer documentation](https://ipinfo.io/developers)
and [ipapi.is developer documentation](https://ipapi.is/developers.html).

Ping0 is intentionally narrower than the other risk rows. Its documented free
`/geo` interface returns four text lines—IP, location, ASN, and organization—so
the report records those fields as a named observation and keeps
`RiskScore: null`. Ping0's detailed `apiloc` interface is a paid, API-keyed
service; this repository neither purchases access nor places an API key in a
URL. The interactive IP page currently requires browser verification and is not
scraped or bypassed. A malformed response, challenge page, or returned-IP
mismatch is `unknown`/rejected, never clean. See the
[official Ping0 API description](https://ping0.cc/ip/api) and
[official risk-score FAQ](https://ping0.cc/ip/faq).

RIPEstat's documented Network Info endpoint returns the covering prefix and
origin ASN set using RIPE routing data. The live API may encode ASN members as
decimal strings or JSON numbers; the strict parser accepts both forms, validates
the 32-bit ASN range, and normalizes report values to `AS<number>`. Shodan
InternetDB is a no-key, non-commercial public lookup updated from Shodan's
InternetDB dataset. Neither
source makes a cleanliness judgment, so the terminal and JSON reports keep
them under routing/exposure context rather than the risk-score table. See the
[RIPEstat Network Info documentation](https://stat.ripe.net/docs/data-api/api-endpoints/network-info.html),
[RIPEstat Data API documentation](https://stat.ripe.net/docs/data-api/ripestat-data-api),
and [Shodan InternetDB](https://internetdb.shodan.io/).

## Source-selection rationale

The working source order is intentionally simple:

1. Core official-contract observations: ipapi.is, Ping0, RIPEstat, and Shodan
   InternetDB.
2. Supplementary direct observation: IPinfo's public demo widget.
3. Supplementary relay observations: the named Check.Place-backed rows.

The relay rows remain useful for cross-checking type and risk signals, especially
when the corresponding formal AbuseIPDB, IPQualityScore, IP2Location, ipdata, and
Scamalytics APIs require customer access. They are labeled `Upstream relay` and
never silently promoted to the core tier. A wholly unavailable source disappears
from the matrices and is named once in the compact availability summary, so
keeping supplementary breadth does not recreate a wall of `Unknown` cells.

Even where a vendor publishes suggested decision thresholds, this relay-based
report does not synthesize a vendor label. For example, IPQualityScore documents
that strictness and other request options change the score, while this project
does not control or authenticate the relay's account settings. AbuseIPDB's
official API also requires an API key, and its `abuseConfidenceScore` is kept as
a confidence scale rather than converted into a local low/high verdict. See the
[IPQualityScore response parameters](https://www.ipqualityscore.com/documentation/proxy-detection-api/response-parameters),
[IPQualityScore advanced options](https://www.ipqualityscore.com/documentation/proxy-detection-api/advanced-options),
the [IP2Location IP2Proxy field documentation](https://www.ip2location.com/documentation/ip2proxy-libraries/lua/api),
and [AbuseIPDB API documentation](https://docs.abuseipdb.com/).

The former DB-IP HTML scraper is removed. In practice, scraping an unversioned
page and turning qualitative labels into invented 0/50/100 values produced more
confidence than evidence.

### Candidate review

- IpScore has a documented bearer-authenticated JSON API and returns separate
  fraud, risk, abuse, and Scamalytics fields. It is the strongest candidate from
  the suggested list once a user-owned API token and the desired score semantics
  are available. See the [IpScore API overview](https://docs.ipscore.me/) and
  [official `/check-ip` contract](https://docs.ipscore.me/checkers/check-ip).
- IPLeak is an AirVPN-operated browser/DNS/routing leak diagnostic. Its own page
  says the location data is partly MaxMind-based and may be cached. It is useful
  as a separate interactive leak test, not as another reputation-score column in
  this non-browser reporter. See [IPLeak's official service description](https://ipleak.net/about).
- Whoer combines IP data with browser fingerprint, WebRTC, DNS, language, time,
  and other interactive signals. That score answers browser disguise/leakage,
  not the exact-leaf reputation question. See [Whoer's official test description](https://whoer.net/).
- Wave Broadband is an ISP, not an IP reputation dataset or documented lookup
  API, so an ASN owned by Wave can appear as a result but Wave is not queried as
  a scoring provider.
- GreyNoise Community and VirusTotal are credible optional threat-intelligence
  candidates. GreyNoise describes whether an address has been observed scanning
  the Internet; VirusTotal exposes engine detections and community reputation.
  Those dimensions should become their own optional threat-intelligence section
  after credential handling is selected, rather than being folded into a generic
  residential-IP score. See the [GreyNoise Community API guide](https://docs.greynoise.io/docs/using-the-greynoise-community-api)
  and [VirusTotal IP object contract](https://docs.virustotal.com/reference/ip-object).

## Media and AI scope

The script performs public accessibility probes against TikTok, Netflix,
YouTube Premium, Prime Video, Reddit, and OpenAI endpoints. These checks answer
whether those particular public flows appear reachable and which region they
report; they do not log in, purchase, modify accounts, or prove that every
product feature will work.

The upstream Disney+ check is intentionally excluded. Its reference bundle was
mixed with historical third-party account cookies and session material, which is
not acceptable in this repository.

## Mail scope

The script resolves public MX records for Gmail, Outlook, Yahoo, Apple, QQ,
Mail.ru, AOL, GMX, Mail.com, 163, Sohu, and Sina, then performs a bounded TCP/25
SMTP greeting probe and immediately sends `QUIT`. It also probes Mailgun to
describe local outbound port-25 reachability. No message is submitted.

## DNSBL scope

The IPv4 address is reversed and queried against each zone in the vendored
`ref/dnsbl.list`. Lookup outcomes are kept as:

- `Clean`: the DNS query completed and the zone returned no listing;
- `Blacklisted`: the zone returned `127.0.0.2`;
- `Marked`: the zone returned another ordinary listing answer;
- `Unknown`: the DNS lookup itself failed or timed out.

The hard concurrency maximum is 50. A failed DNS command is never counted as a
clean result. Resolver-policy answers such as Spamhaus `127.255.255.252`,
`127.255.255.254`, and `127.255.255.255` are errors, not evidence that the IP is
listed or clean. DNSBL interpretation is therefore only authoritative when the
resolver is permitted and supported by the zone operator. See the
[Spamhaus DNSBL usage FAQ](https://www.spamhaus.org/faqs/dnsbl-usage/) and
[Spamhaus fair-use policy](https://www.spamhaus.org/blocklists/dnsbl-fair-use-policy/).
