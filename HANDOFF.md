# Current handoff

## 2026-09-24 risk sources and common-library audit

Worktree: /Users/zmx/Projects/projects/ipquality, main, reporter
v2026-09-24-standalone.20. All route choices default to reputation; media/AI
probes remain removed. Raw-reporter mail/DNSBL scopes remain optional.
A bare invocation is a network-free disclosure plan. The live menu is:

    /usr/bin/ruby --disable-gems bin/test-clash-leaf --confirm-network-lookup -4

## Report behavior and source investigation

Section 3 now contains Cloudflare and DB-IP columns. Cloudflare retains official
API status and actual threat categories. Its numeric score stays null: current
Cloudflare WAF documentation says legacy Threat Score is retired and always zero.
The report explains why zero is not low-risk evidence. Missing categories remain
null; an explicitly empty array remains [].

DB-IP queries its public homepage demo once for the exact target and accepts
only its original low/medium/high threat label. No invented 0/50/100 mapping,
embedded-key scraping, paid account or trial. IPWHOIS queries its current /demo
and displays actual boolean proxy/VPN/Tor/hosting fields in section 4. Missing
fields remain null. HTTP 200 quota errors from both demos are rate_limited.
Their failed risk lookup is not hidden by a geography-only fallback.

Cloudflare, DB-IP and IPWHOIS are absent from terminal section 5; their named
context remains in JSON. Section 5 keeps Ping0/RIPEstat/Shodan and anonymous ipapi
context when relevant. Score-table widths now include both row labels and cells,
fixing long Cloudflare scales and Chinese/English demo-status alignment.
The shared HTTP classifier also names HTTP 429 as rate_limited.

Historical upstream commit b3ad433931db9882673e070f59edaf17d56e05ac (v2025-03-13)
used DB-IP /demo/home.php, IPWHOIS /widget and third-party ip.nodeget.com
.ip.riskScore labelled Cloudflare. Today's DB-IP homepage still uses /demo/home.php;
IPWHOIS homepage JavaScript now uses /demo. Permanent free API and website-demo
capabilities differ. [PROVIDERS.md](PROVIDERS.md) records contracts and sources.

## Live evidence and remaining limitation

A live vps+yyssr22 / ATT reputation report on 2026-09-24 completed in **20.6
seconds**, exit 0, with **zero jq errors**. Nine ProviderStatus entries were ok,
including official IPQS, keyed ipapi and Cloudflare. DB-IP and IPWHOIS returned
rate_limited. Cloudflare supplied no threat categories on this lookup. Direct
demo probes also returned quota/limit errors. No automatic retry was added.

Private ignored evidence: reports/risk-v20-att-20260924-013151.json, with matching
.ansi, .txt and .stderr.txt. IP/prefix are masked. Stderr contains progress and
shutdown messages, not parser failures. The temporary Mihomo exited; no owned
leaf workspaces remained and live Clash was unchanged. The table-width repair
followed this measurement and was checked offline; no extra live query was spent
solely to reformat the evidence.

DB-IP/IPWHOIS live risk availability remains unproven in these attempts. Positive
fixtures model website schemas, not successful live measurements. A later
authorized run can display valid exact-target labels/booleans if returned.
Until then, limits and unknown values stay explicit. No paid account or new
2FA was created for these account-free demos.

## Shared-code and MCP ownership

common/json_values.jq centralizes optional bounded text/integer predicates used
by ipapi, Cloudflare, IPWHOIS and DB-IP. It rejects terminal control characters.
Provider schemas, endpoints, quota rules and risk meanings stay provider-local.
The reporter validates the module before lookup; offline runtime copies include it.

IPQS-specific connection-type mapping moved from common/provider_values.zsh to
providers/ipqualityscore.zsh. Official and relay adapters directly call
ipqualityscore_connection_type_server_flag; no old alias/wrapper remains.
Unused reporter free-geography branches were removed. The Node MCP retains its
optional free-API contracts. [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md) indexes
definitions, callers and examples. The rechecked myutils APIs are Python imports,
so the zsh/system-Ruby runtime reuses its own common library and the MCPs continue
using mcps shared Node packages. No new dependency or subproject was introduced.

The provider-account MCP tool now selects free_api or public_demo, using one
fixed 1.1.1.1 request, bounded bytes/time and no redirects/retries. observation,
riskLabelAvailable and riskFactorsAvailable describe only validated data.
HTTP 200 quota bodies remain unusable. Demo quotas are unspecified; permanent
free quotas are not applied to them. No dbipmcp account/profile/key was created.

Existing 2026-09-22 account setup is preserved: ipapi's verified free key uses the
user's IPQS email and Hong Kong; its UI had no native 2FA entry. Cloudflare retains
its scoped Intel Read token and previously server-confirmed/fresh-login-tested
TOTP. No factor was re-enrolled or replaced. Current API availability and that
prior authentication proof are separate. See [CREDENTIALS.md](CREDENTIALS.md)
and [the MCP guide](mcp/provider-accounts/AGENTS.md).

IPQS remains entirely under mcp/ipqs and shares secrets/ipqs with the reporter.
The earlier mcps cleanup removed its old package/key and empty security directory;
central orchestration points here. This turn changed no parent mcps/Supervisor
code or live Codex registration.

## Validation and synchronization

/bin/zsh -f scripts/test-offline passed **95 reporter tests / 1,473 assertions**,
**22 IPQS tests** plus build/doctor, and **28 provider-account tests**, all offline.
Coverage includes demo contracts/quotas, unknown-vs-false, target mismatch, schema
drift, state reset, one-request behavior, common value bounds, both table languages
and route isolation. [TESTING.md](TESTING.md) owns complete/focused commands.

Only owned code/tests/docs are eligible for staging; reports and credentials stay
ignored. Configured remotes are github-kratoszmx (kratoszmx/ip-quality, existing
remote name) and github-kratosbackup (kratosbackup/ipquality). The local project
is correctly named ipquality.
