# Current handoff

Current state only. Each lane (writer) keeps at most one validation entry and
replaces only its own; older entries stay in Git history
(`git show <commit>:HANDOFF.md`; the last untrimmed version is
`git show 6dd3b3e:HANDOFF.md`). Lasting behavior belongs in the documents
listed in [AGENTS.md](AGENTS.md#start-here).

## Latest entry per lane

### Report addresses and fixed-IP route — 2026-11-25

Reporter `v2026-11-25-standalone.60`. Menu 2 queries one complete public IP
and uses the standard reporter. The former batch route has been retired.
Terminal, plain text, ANSI and JSON reports show the full tested IPv4 or
IPv6 address and validated RIPEstat prefix. Existing commands can still
include `-f`. The full offline suite passed with 140 reporter cases /
4,034 assertions, 38 IPQS and 68 provider-account cases. Three separate
IPv4 runs in Terminal each exited successfully and saved a standard,
target-bound JSON report. Check.Place MaxMind was blocked in all three.

### user1 — 2026-11-16: direct shared record predicates

Provider-account public API and ipdata parsers now import `isRecord` directly
from `@myutils/value-shapes`, removing two equivalent local predicates. Their
provider schemas, target binding and identity checks retain their existing
contracts. The provider-account manifest and MCP lockfile declare the direct
dependency. The full `/bin/zsh -f scripts/test-offline` passed with 152 reporter
cases / 4,410 assertions, 35 IPQS cases and 60 provider-account cases.

### myutils native input — 2026-11-19

The shared inspector now takes `(page, activation)` without a caller-supplied
verification policy. `mcp/common/verification.mjs` uses that interface directly;
its account origin, bounded settling, TOTP and account identity remain owned here.
The complete `/bin/zsh -f scripts/test-offline` passed against myutils 0.8.0
(reporter, IPQS and all 67 provider-account tests). No credentials submitted.

### user2 — 2026-11-19: faster, tighter offline suites

Tests and documentation only; `script_version` is unchanged. The base test class
now gives Minitest one thread per core (system Ruby's 5.11 defaulted to two),
and the query-route retry matrix, invalid source IDs and malformed Shodan
bodies each run in one probe. The complete runner fell from 34.6 s to 10–15 s
(reporter 24.5 s to 5–8 s). Near-duplicate report, CLI-gate and leaf-plan tests
were merged. New coverage: failed egress discovery exits 40/60/7 before any
provider request or report file; credential files with links, unknown or
duplicate names or bad values are rejected without exposing values; `-f` JSON
unmasks the target and prefix. The IPQS support-reply watch has ended (see Open
issues). The full `/bin/zsh -f scripts/test-offline` passed: 146 reporter cases
/ 4,136 assertions, 36 IPQS and 67 provider-account cases. No live lookup.

### login move — 2026-11-21: account logins in the shared Chrome profile

Owner decision (見微): every account login lives in the text browser's saved
Chrome profile. IPQS and provider accounts no longer launch Chrome or keep
profiles, `http-session.json`, `{provider}-http.json` or pending-login files:
HTTP reads carry the shared profile's cookies and write back what the site
changed (`mcp/common/shared-cookies.mjs`, replacing `browser-state.mjs`); pages
are hidden tabs of the one dedicated Chrome (kept per flow, released by the
close tools); ipdata reads its Cognito token from the dashboard's localStorage
there. A Chrome that cannot start outside the GUI session is
`browser_unavailable`, not a logout. IPQS HTTP reads default to the system proxy
the shared Chrome uses. Also repointed `mcp/common/verification.mjs` to
`@myutils/web-text/verification/activation` (myutils 0.9.5 moved
`inspectNativeVerification`; the old import broke both MCPs). The old `.state/`
files stay on disk as rollback data. Full `/bin/zsh -f scripts/test-offline`:
146 reporter cases / 4,136 assertions, 37 IPQS and 68 provider-account cases.
Live, through the converted code: the move had not carried the IPQS, ipapi,
AbuseIPDB or ipdata session files (only older profiles), so IPQS, ipapi and
AbuseIPDB were signed in again with their saved-credential logins and ipdata's
dashboard session was copied from `.state/ipdata-http.json`, then refreshed by
its own web app. Pass: AbuseIPDB and ipapi HTTP identity, ipdata GetUser
(free plan, key matches), IPQS account API. IPQS login + TOTP reached the
dashboard but it now shows an updated Terms/Privacy acceptance modal, so
`auth:check` reports `unknown` (see Open issues). Cloudflare failed (below).
Two site changes were fixed: the IPQS 2FA challenge (`type=text`,
"Finish login") and ipapi's account fields (`#email-tf`, `#api-key`).

### zmxmacm4 — 2026-11-19: verified normal CAPTCHA preparation

Reporter `v2026-11-19-standalone.58`. A fresh myutils hidden read of DB-IP's
`1.1.1.1` page recovered from HTTP 403 to the exact HTTP 200 record/LOW label
with `verificationActivated=true` and confirmed cleanup; the production
`readDbipPage` adapter also returned `ok/low` on the configured system proxy.
Removed blanket CAPTCHA prohibitions and immediate-stop behavior: IPQS and
provider-account login/open/setup now share normal checkbox preparation in
`mcp/common/verification.mjs`. The remaining provider-wide ipapi password-login
disable branch is removed; its current official POST `/app/` form (`email`,
`pass`, `Sign In`) returned HTTP 200 and now shares the normal saved-credential
flow. Completed response fields no longer falsely
require human action merely because the verification label remains; TOTP and
exact account checks remain independent. Cloudflare's public login loaded in
Firefox/native hidden Chrome; Check.Place still returned an explicit block
without a verification control. No account credentials were submitted. Current
NodeQuality code still invokes xykt/IPQuality, whose Check.Place URLs remain.
The full offline suite passed: 152 reporter cases / 4,410 assertions, 36 IPQS
and 67 provider-account cases. Private live receipts and validation:
`reports/verification-20261119/` and `reports/ipapi-login-policy-20261119/`.

### wincn TLS retry — 2026-11-27: same-route retry after a dropped leaf

Reporter `v2026-11-27-standalone.61`. The user's `hongkongvps`/`wincn` run
showed most sources as `TLS 握手失败` after the first few answered. 30 and 180
bare handshakes through the isolated leaf and a full leaf run all succeeded
afterwards, so the node dropped for a while during that run. Every source whose
request fails the TLS handshake (curl 35, nothing sent) now gets one retry on the
same route and target after a 5 s pause. Timeouts and sources that already used
the IPQS/Cloudflare direct fallback are not retried. JSON `Query.TransportRetry`
lists them, and the terminal says which answered. RIPEstat and Shodan now keep
their transport/HTTP status (Shodan 404 no-information is `not_found`). They
appear in the unavailable-source line, and the label reads `网络备援`. Offline
suite: 142 reporter cases / 4,051 assertions, 38 IPQS, 68 provider-account.
Live `wincn` run (ripestat, shodan, ipapi): RIPEstat `announced`
120.235.128.0/21, Shodan `not_found`, ipapi `ok`, no retry needed. The retry
path itself is proven offline only. An outage that outlasts the pause stays
`tls_error`.

The IPQS `auth:check` also recognizes the Svelte dashboard's inline
`globalThis.staticUser` (numeric `id` + `email`; login/TOTP forms still veto).

## Current behavior and ownership

- The current reporter version is `script_version` in `bin/ip-quality`.
- The runner defaults to `reputation` with all sources. Direct, specific-IP
  and isolated-leaf routes share one reporter. Every attempted
  source stays visible on failure with unknown risk, never a clean result.
- Official direct IPv4 IPQS uses verified AliDNS HTTPS resolution
  automatically. Official IPQS/Cloudflare target queries recover from pre-HTTP
  connection failures through one direct IPv4 retry that keeps the target, the
  original failure and the effective route; IPQS keeps its credit preflight.
- Check.Place block/429 pauses later relay calls for the same target/family.
  Scamalytics and IP2Location fall back to their target-bound public pages;
  ipdata uses its owned official developer key for risk, or without a key falls
  back from relay to keyless geography with unknown risk. These paths stay on
  the selected route; an owned AbuseIPDB key selects its official API;
  basic data falls back to IPinfo. DB-IP keeps the visitor demo's selected
  route, with one optional public-page hidden-browser read after an explicit
  daily limit. ipapi's documented keyed account denial gets one same-route
  anonymous context lookup, while type/score/factor statuses keep the denial.
  Missing fallback data remains unknown. Contracts:
  [PROVIDERS.md](PROVIDERS.md).
- Provider accounts: the ipapi replacement account (verified October 28) and
  the ipdata free developer account (verified October 27) are current. Since
  2026-11-21 every account login (IPQS included) lives in the shared Chrome
  profile; account state and history are in [MCP.md](MCP.md) and
  [CREDENTIALS.md](CREDENTIALS.md#account-mcp-files).
- Code layout and shared helpers: [AGENTS.md](AGENTS.md#architecture) and
  [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md). Account MCPs: [MCP.md](MCP.md).
  No project daemon exists. Supervisor owns the weekly
  `test.ipquality.test-offline` ([SERVICES.md](SERVICES.md)).

## Open issues

- **ATT to IPQS:** Since October 10 the ATT route fails curl TLS (35/HTTP 000)
  for `/login` and the account API, including pinned IPv4/TLS 1.2, while direct
  IPv4 login and API work with the same credentials; the cause (route,
  intermediary or edge) is unconfirmed. Reputation lookups still succeed through
  the automatic direct fallback (October 26 isolated ATT run: score 75,
  `OriginalRouteFailure=tls_error`, `TargetUnchanged=true`). The user-authorized
  October 26 support reply was sent once and verified; Supervisor's watch
  `mail.ipqs-tls-reply-20261026` found support's answer on 2026-11-02 09:00 HKT
  and stopped. That answer has not been read or recorded here, so no provider
  diagnosis is known. [Support record](mcp/ipqs/SUPPORT-TLS-20261010.md).
- **Check.Place relay:** Since October 26 the fixed-target relay returns its
  branded HTTP 403 block page on default proxy, direct IPv4, isolated ATT and
  `awshk` (three distinct egresses), through curl and windowless or visible
  Chrome, with no verification control; November 19 still showed the block. The
  exact WAF rule needs the site owner's Ray-ID lookup; no relay recovery is
  established, and the reporter's own fallbacks cover the affected sources.
  Current NodeQuality still runs xykt/IPQuality with the same relay URLs; its
  original request shapes also got branded 403s, and upstream's Lite report only
  skips relay sources. Evidence: `reports/access-recheck-20261026/`;
  [contract and NodeQuality comparison](providers/check_place.md#current-nodequality-comparison).
- **IPQS terms:** since November 21 the signed-in dashboard shows "Review our
  updated terms" (Terms of Service and Privacy Policy, Accept / Decline and log
  out). Accepting is the owner's decision; until then the only logout link sits
  in that modal and the HTTP `auth:check` reports `unknown`. The account API
  works.
- **Cloudflare account:** on November 21 the saved-credential login in a hidden
  tab of the shared Chrome submitted once and ended at `/login`
  (`login_unconfirmed`); `/api/v4/user` returns 403 both in the page and over
  HTTP. The account has TOTP, and the MCP has no login-time TOTP step. Do not
  repeat the password submission; the owner signs in once in a window of the
  shared Chrome (`provider_account_open` with `surface=login`, `visible=true`).
  The Intel API key is independent.
- **Ping0 on ATT:** `tls_error` (curl 35) on 2026-10-23 while direct verified.
  Ping0 observes the caller, so a direct fallback would not measure ATT.

## Latest saved live evidence

Private reports under `reports/` are ignored by Git; superseded runs are in Git
history. Live runs never changed the active Clash state.

| Date / scope | Result / private evidence |
| --- | --- |
| October 28, ipapi replacement account | The new key returned full risk data for `1.1.1.1` on direct and default-proxy HTTP routes; a reporter run returned `Mode=full`, `CredentialMode=key` and `ok` in all three ipapi matrices. `reports/ipapi-account-20261028/` |
| October 27, direct all-source v50 | DB-IP page fallback returned `low` despite visitor daily quota; ipapi anonymous ASN/geography returned but keyed risk remained `account_restricted` (before the October 28 replacement account). Check.Place/MaxMind was blocked and IPinfo supplied basic data. Other sources, including IPQS/Cloudflare/Ping0, succeeded. `reports/direct-source-recheck-20261027/all-after.{json,ansi,log}` |
| October 27, ipdata v49 | Official owned free key succeeded through direct and isolated ATT: `ProviderStatus.ipdata=ok`, `FactorMeta.ipdata.Source=official_api`; proxy/Tor/server/abuse supplied, VPN/robot null. Native headless account/Profile and browserless GetUser proved the account and matching key. `reports/provider-recheck-20261027/{direct-keyed,att-keyed,ipdata-mcp}.json`; offline log and unsent bilingual ipapi draft in the same private directory. |
| October 23, direct all-source v43 | 14 of 15 sources returned usable observations, including IPQS, Cloudflare and Ping0. DB-IP returned `daily_quota_exhausted`. `reports/direct-20261023-codex-audit.{json,txt,stderr}` |
| October 23, ATT all-source v43 and focused recheck | Cloudflare, IP2Location and the other table providers succeeded except DB-IP's daily quota and IPQS's initial timeout after direct fallback. A focused IPQS recheck succeeded through direct fallback after selected-route TLS failure, with the same discovered target preserved. Ping0 was unavailable. `reports/att-20261023-codex-audit.{json,txt,stderr}` and `reports/att-ipqs-20261023-codex-audit-recheck.{json,txt,stderr}` |
| October 23, Ping0 v44 | Focused direct check returned `verified`; isolated ATT returned `tls_error`. A separate bounded ATT HTTP probe confirmed curl exit 35, HTTP 000 and no response body. `reports/ping0-{direct,att}-20261023-codex-audit-fixed.{json,stderr}` |
| October 23, DNSBL v44 | A loopback DNS responder verified NOERROR/NXDOMAIN/SERVFAIL/REFUSED handling against the real system `dig`. `reports/dnsbl-local-20261023-codex-audit-fixed.json` |
| October 18, prefix sampling (one /24, three addresses) | All 12 usable target providers returned data; Check.Place MaxMind was blocked and DB-IP/Ping0 were inapplicable. `reports/prefix-samples-20261018-010049-20261018-26159-p9t2sj/`; earlier six-prefix comparison `reports/us-prefix-samples-20261018/summary.md` |
| October 11, route diagnostics | ATT IPQS failed TLS before HTTP on multiple host/TLS variants, while the same key/target succeeded through another route. DB-IP supplied no recovery timestamp. `reports/att-ipqs-20261011-route-diagnostics.json`, `reports/dbip-20261011-route-diagnostics.json` |
