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
| MaxMind via `ipinfo.check.place` | Upstream relay | ASN, organization, city/region, registered region, coordinates, timezone |
| IPinfo public widget | Direct public web endpoint | ASN/company type, country, privacy flags, location |
| Scamalytics via `ipinfo.check.place` | Upstream relay | score, proxy, VPN, Tor, blacklist/bot indicators |
| ipapi.is | Direct public endpoint | ASN/type and risk factors |
| AbuseIPDB via `ipinfo.check.place` | Upstream relay | abuse score and usage/risk factors |
| IP2Location via `ipinfo.check.place` | Upstream relay | fraud score and proxy-category factors |
| DB-IP public page | Direct public page | crawler, proxy, abuse, country, estimated threat |
| ipdata via `ipinfo.check.place` | Upstream relay | country and threat factors |
| IPQualityScore via `ipinfo.check.place` | Upstream relay | fraud score and proxy/VPN/Tor/bot factors |
| Ping0 public `/geo` | Direct official public endpoint | returned IP, location, ASN, and organization; the returned IP must exactly match the tested address |

“Upstream relay” is intentionally visible in the report model: it is not treated
as equivalent to a user-owned subscription to each vendor's official API. If a
relay or direct page changes schema, its result is unknown rather than clean.

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

- `Clean`: the DNS query completed and the zone returned no listing, or its
  documented ignore-style `127.255.255.*` result;
- `Blacklisted`: the zone returned `127.0.0.2`;
- `Marked`: the zone returned another answer;
- `Unknown`: the DNS lookup itself failed or timed out.

The hard concurrency maximum is 50. A failed DNS command is never counted as a
clean result.
