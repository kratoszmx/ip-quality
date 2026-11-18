# Current handoff

Current state only. Each lane (writer) keeps at most one validation entry and
replaces only its own; older entries stay in Git history
(`git show <commit>:HANDOFF.md`; the last untrimmed version is
`git show 6dd3b3e:HANDOFF.md`). Lasting behavior belongs in the documents
listed in [AGENTS.md](AGENTS.md#start-here).

## Latest entry per lane

### user1 — 2026-11-16: direct shared record predicates

Provider-account public API and ipdata parsers now import `isRecord` directly
from `@myutils/value-shapes`, removing two equivalent local predicates. Their
provider schemas, target binding and identity checks retain their existing
contracts. The provider-account manifest and MCP lockfile declare the direct
dependency. The full `/bin/zsh -f scripts/test-offline` passed with 152 reporter
cases / 4,410 assertions, 35 IPQS cases and 60 provider-account cases.

### user2 — 2026-11-15: DB-IP page read on text-browser 0.6.0

text-browser 0.6.0 removes reads that answer a verification. The DB-IP
daily-limit fallback now takes the shared default path: it names no backend and
no longer requires `nativeRecovery.recipe=dbip-public-ip`; the IP heading,
title and explicit threat label still decide the observation, and the proxy
choice is unchanged. Offline aggregate passed against the 0.6.0 build: 152
reporter cases / 4,410 assertions, 35 IPQS and 60 provider-account cases. No
live lookup was run.

### zmxmacm4 — 2026-11-10: Steam keychain audit and account-read route fix

Reporter version: `v2026-11-10-standalone.56`.

Reviewed Claude's `Steam-mcp` session and the current shared launcher. Steam's
saved-profile cookie loss outside macOS Aqua is applicable to persistent native
Chrome launches. IPQuality's routine checks use HTTP; its native account flows
use fresh temporary profiles with separately saved state, and isolated reads
use fresh browser contexts. DB-IP uses no account state. No production path
reopens a saved native profile. The shared persistent launcher now protects
explicit manual recovery by default; its five offline keychain tests passed.
Local Supervisor inventory lists this project's weekly offline suite, with no
IPQS live account/API probe. No scheduler or account settings were changed.

The audit found and reproduced a route bug in provider browser reads: explicit
`DIRECT` (or no proxy) was replaced with `http://127.0.0.1:7897`. The reader now
passes `accountNetworkOptions().proxyServer` unchanged to myutils. An offline
entrypoint regression fails on the old code and passes after the fix; it also
checks proxy precedence, cleanup and saved-state preservation on failures.
Documentation now distinguishes this project's temporary sessions from Steam's
persistent profiles and corrects the stale IPQS isolated-reader description.
Full offline aggregate passed: 152 reporter cases / 4,410 assertions, 35 IPQS
cases and 60 provider-account cases. Evidence:
`reports/keychain-audit-20261110/offline.log`. No live login or provider lookup
was needed for this audit.

## Current behavior and ownership

- The current reporter version is `script_version` in `bin/ip-quality`.
- The runner defaults to `reputation` with all sources. Direct, specific-IP,
  prefix-sample and isolated-leaf routes share one reporter. Every attempted
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
  the ipdata free developer account (verified October 27) are current; account
  state and history are in [MCP.md](MCP.md) and
  [CREDENTIALS.md](CREDENTIALS.md#account-mcp-files).
- Code layout and shared helpers: [AGENTS.md](AGENTS.md#architecture) and
  [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md). Account MCPs: [MCP.md](MCP.md).
  No project daemon exists. Supervisor owns the weekly
  `test.ipquality.test-offline` and the finite support-reply watch described in
  [SERVICES.md](SERVICES.md).

## Open issues

- **ATT to IPQS:** October 26 curl still fails with 35/HTTP 000 for `/login`
  and the account API, including pinned IPv4/TLS 1.2. Direct IPv4 website login
  and API succeeded with the same credentials. The route/intermediary/edge
  cause remains unconfirmed. A later October 26 Gmail read succeeded and
  confirmed support's October 20 request for IPv4 website/account access and
  full curl failure output; the earlier OAuth failure was not persistent.
  After reviewing privacy-minimized drafts, the user explicitly authorized an
  IPQS reply on October 26. It was sent once to the latest support message;
  native Sent readback confirmed the same thread and reply headers. The earlier
  refusal still applies to the separate ipapi appeal, which was not sent.
  A later October 26 isolated ATT reporter run returned score 75 through
  `direct_fallback`, with `OriginalRouteFailure=tls_error` and
  `TargetUnchanged=true`. The reputation lookup works through fallback; the
  unresolved original transport is not a prerequisite for that result.
  The reply states this distinction, uses a generic connection description,
  omits network identifiers and exact timestamps, and supplies only a minimal
  error excerpt. It preserves the incoming support subject for threading, with
  no attachments or quoted history. Detailed diagnostics remain private.
  Supervisor watch `mail.ipqs-tls-reply-20261026` is active; delivery/read and a
  provider diagnosis are not yet confirmed.
  See [support record](mcp/ipqs/SUPPORT-TLS-20261010.md).
- **Check.Place relay:** The later October 26 recheck still returned HTTP 403
  for the fixed-target ipapi URL on default proxy, direct IPv4, isolated ATT and
  isolated `awshk` (three distinct egresses verified). Direct Chrome failed in
  both windowless and visible modes with the branded block page; no IP data was
  returned. One `awshk` response was plain-text 403, followed by the branded
  block page on its bounded recheck. This is not a TLS connection failure or
  proof of one bad node. The exact WAF/security rule requires the site owner's
  Ray-ID lookup; no new relay recovery is established. Private evidence:
  `reports/access-recheck-20261026/`; [contract](providers/check_place.md).
  A further audit of current NodeQuality and its fetched xykt script found the
  same relay URLs. Reproducing the two original request shapes against each
  route's actual IPv4 egress returned six branded 403s on default proxy, direct
  and ATT. Upstream can still render a Lite report by skipping several relay
  sources; that is not relay recovery. Source versions, evidence and scope:
  [NodeQuality comparison](providers/check_place.md#current-nodequality-comparison).
- **Cloudflare account:** Native hidden Chrome loaded the login form, but one
  password submission required human verification. Existing saved HTTP identity
  returned 403 on proxy/direct. Official Intel API still succeeded; no GUI
  fallback or challenge automation was performed.
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
