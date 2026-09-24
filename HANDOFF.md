# Current handoff

## 2026-09-24 provider request fixes

Worktree: /Users/zmx/Projects/projects/ipquality, main, reporter
v2026-09-24-standalone.21. All route choices remain reputation-only by default.
Media/AI probes stay removed; raw mail/DNSBL scopes remain optional.
The live interactive menu is:

    /usr/bin/ruby --disable-gems bin/test-clash-leaf --confirm-network-lookup -4

## Corrected findings

The earlier conclusion that DB-IP/IPWHOIS risk demos were simply unavailable
was too broad. Direct comparisons on 2026-09-24 established:

- Bare IPWHOIS /demo requests returned a rate-limit message. A matching request
  with website Origin/Referer and browser headers returned security booleans.
  The reporter and provider-account MCP now supply those headers.
- DB-IP's old /demo/home.php target lookup returned query-limit errors even with
  website headers. The current /api/core/ visitor demo returned a low label.
  The reporter and MCP now read that page and make one /self?convertCurrencies
  GET with its transient public visitor token. The token is bounded and never
  saved or printed; reporter URLs go through curl stdin.
- DB-IP is an egress observation. Both requests preserve the selected proxy
  and address family. The reporter rejects a returned IP different from the
  target as ip_mismatch. It never silently evaluates the requesting host in
  place of an unrelated target. The MCP labels this probe request_egress.
- True rate limits remain unavailable, without automatic retries or changing
  routes. Public demo limits are distinct from permanent free geography quotas.

The supplied NodeQuality report is dated 2025-03-24 and uses v2025-03-13.
Its upstream code uses third-party ip.nodeget.com/json .ip.riskScore under the
Cloudflare label, DB-IP's old target demo, and IPWHOIS /widget. Today's source
called by NodeQuality is v2026-09-16: it has no Cloudflare/IPWHOIS query
functions and uses the DB-IP visitor demo. No downloaded script was executed.
The old third-party Cloudflare-labeled endpoint returned HTTP 200 without
riskScore in a direct check. Cloudflare's own documentation independently says
legacy Threat Score is no longer populated and is always zero. We retain the
current official Intel categories/status, with no invented numeric score.
[PROVIDERS.md](PROVIDERS.md) links the sources and defines these contracts.

## ipapi visibility and transport

Section 4 previously hid ipapi.is whenever every risk/country field was unknown.
It now retains the attempted provider and explains key mode, anonymous response,
missing risk, and query failure. JSON FactorMeta.ipapi records those distinctions.
Timeout, TLS handshake, TLS certificate and other network errors are separate;
none is reported as an exhausted quota. False values remain actual observations.

A paired keyed 1.1.1.1 diagnostic returned HTTP 200/full data over direct access
in about 1.95 seconds. Isolated ATT returned curl 35 / SSL_ERROR_SYSCALL before
HTTP. TLS 1.2 and the documented US diagnostic host also failed on ATT.
The key is valid; the remaining route-specific TLS failure is not fixed or
attributed to a particular firewall/provider. Runtime retains the canonical
endpoint, TLS verification and selected route without a direct fallback.
Anonymous-quota pages currently disagree (30 versus 100/day); both agree that
a free account key returns full data with 1,000/day. Actual HTTP responses govern.

## Live evidence

The corrected ATT report (vps+yyssr22 / ATT) completed in 21.1 seconds, exit 0,
with zero jq errors. Ten provider statuses were ok, including DB-IP, IPWHOIS,
official Cloudflare and IPQS. DB-IP supplied low; IPWHOIS supplied US and false
for proxy/VPN/Tor/hosting. Missing abuse/bot fields remain null.
Cloudflare was available but supplied no threat categories. ipapi had a transport
failure and remained visible in section 4 with its configured-key explanation.

Private ignored evidence:
reports/risk-v21-att-20260924-121527.json, plus .ansi, .txt and .stderr.txt.
This snapshot predates the more specific TLS-error labels; the subsequent
transport diagnostics and offline cases establish that distinction.
Temporary Mihomo instances were stopped by their owner; live Clash was unchanged.
Direct native-HTTP MCP probes also returned usable DB-IP and IPWHOIS risk data.
No account, paid plan or 2FA was created for these account-free demos.

## Ownership and validation

IPQS stays entirely under mcp/ipqs with shared secrets/ipqs. The earlier removal
of the obsolete mcps package/key remains intact; central orchestration points
here. The provider-account MCP still uses mcps/common/shared directly. Existing
Cloudflare TOTP and the ipapi free account were preserved. There was no parent
mcps/Supervisor change, dependency install or registration mutation.

The prior common-library audit remains current: common/json_values.jq owns
bounded optional text/integer predicates, while IPQS-only connection-type
mapping belongs to providers/ipqualityscore.zsh. DB-IP guest-page parsing is
provider-specific and stays in providers/dbip.zsh, not common.
[COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md) describes the shared APIs.

/bin/zsh -f scripts/test-offline passed 96 reporter/route tests with 1,595
assertions, 22 IPQS tests plus build/doctor, and 29 provider-account tests.
Regressions cover website headers, two-step DB-IP route/family preservation,
token bounds, no retry after failure, target mismatch, JSON contract changes,
ipapi visibility in both languages, and transport-error classification.
[TESTING.md](TESTING.md) owns complete/focused validation instructions.

Only owned code/tests/docs are staged. Reports, credentials and temporary
state stay out of Git. Configured remotes are github-kratoszmx
(kratoszmx/ip-quality, existing remote name) and github-kratosbackup
(kratosbackup/ipquality). The local repository is ipquality.
