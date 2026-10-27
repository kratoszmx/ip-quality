# Current handoff

## Status — 2026-10-27

- Reporter `v2026-10-27-standalone.51` (`script_version` in `bin/ip-quality`).
- Last complete offline run, October 27: `/bin/zsh -f scripts/test-offline`
  passed — reporter 151 Minitest cases / 4397 assertions,
  IPQS MCP 22, provider accounts 55. The separate synthetic IPQS
  browser-text suite last passed 10/10 at commit `782bce3`, with no live requests.
- Live: complete all-source direct report on October 27; latest complete ATT
  remains October 23 (table below). Direct DB-IP recovered through its new
  public-page fallback; ipapi recovered anonymous context only, with its risk
  tables still account-restricted. Check.Place/MaxMind remained blocked and
  basic information used IPinfo. Every other selected source supplied data.
  Private receipts: `reports/direct-source-recheck-20261027/`. Offline success
  is not a provider-availability claim.
- October 27: user-approved ipdata free developer signup, email verification
  and key import restored official proxy/Tor/datacenter/abuse flags on direct
  and isolated ATT. Dashboard: Free Tier/$0/1,500 daily queries. VPN/robot remain
  unknown because the response lacks those fields. HTTP account identity and
  native headless dashboard/Profile passed; the existing provider-accounts
  MCP now maintains this account. No billing trial or 2FA control was enabled.
  ipapi still returns API 403 with `ERR_FORBIDDEN_NOT_ALLOWED`; saved HTTP
  identity confirms `bot_login` suspension. Its anonymous API root returns
  geography successfully, which does not establish access with this account's
  key. The requested bilingual appeal is saved privately and was not sent.
- Later October 27 website-only follow-up: the shared myutils text browser
  returned ipdata's full `1.1.1.1` page on the default proxy in fresh hidden
  Chrome, including Analysis, ASN/company and Trust score. It waits past the
  partial geography shell for the matching complete record and passive check.
  No API key or personal Safari state was used. Reporter/API behavior and keys
  are unchanged; implementation, tests and current usage belong to
  [myutils](/Users/zmx/Projects/myutils/docs/NETWORK_API.md#ipdata-public-ip-detail).
- DB-IP's visitor daily error returned October 27. The new automatic fallback
  read the same actual direct egress from the public page in fresh hidden
  Chrome, obtained the explicit `low` label and confirmed browser cleanup.
  Both focused and full reports kept `DemoStatus=daily_quota_exhausted` beside
  `Source=public_page` / `PageStatus=ok`. No personal account, key rotation or
  persistent cache was used; the visitor API itself remains limited.
- Later October 27 website fallback audit: fresh windowless Chrome completed
  an explicit `1.1.1.1` lookup on the ipapi homepage and IP-to-Abuser demo over
  direct access. Both returned anonymous location/ownership, without risk.
  The frontend's other full-risk displays include baked examples. Its live
  authenticated path uses the same API with a JSON `{q,key}` POST; reproducing
  that method with the saved key still returned 403/NOT_ALLOWED. No independent
  website risk fallback was established, so the existing HTTP context fallback
  stays in place. Details: [ipapi contract](providers/ipapi.md#public-website-fallback-investigation).
- October 27 new-account task: the user authorized a different ipapi identity
  with the existing password. Candidate credentials and durable submission
  receipts are private and separate; the active account/key were not replaced.
  A direct visible Chrome signup received an explicit automated-browser/CDP
  rejection (HTTP 200). The MCP now reports `automated_browser_blocked` and
  ends that wait without retrying; two regressions cover the refusal.
  Mail-manager authenticated the requested Outlook mailbox, including an
  all-folder search, but found no recent ipapi verification message.
  The user's next step is clicking Create Free Account in ordinary Chrome.
  myutils `openRealChrome` opened the persistent dedicated profile without CDP.
  After the user granted macOS Accessibility, native text controls bound to
  that exact Chrome process and signup URL filled and verified the candidate
  email, populated password and Hong Kong country. The browser's standard
  `--force-renderer-accessibility` flag exposes these controls; Chrome's
  "Allow JavaScript from Apple Events" setting is no longer needed. No
  screenshot/OCR or automatic form submission was used. Native Apple Events
  addressed by app name had resolved another Chrome process, so future native
  access must bind the owned profile's PID and verify the page URL. Private
  `native-fill-result.json` records the successful fill, not registration.
  Account creation, verification mail and a working new key remain unproved.
  Candidate paths: [CREDENTIALS.md](CREDENTIALS.md#account-mcp-files).
  Current offline evidence: `reports/ipapi-registration-20261027/offline.log`.
- Git: only `main`. Push to `github-kratoszmx` (`kratoszmx/ip-quality`) and
  `github-kratosbackup` (`kratosbackup/ipquality`), then read both back.

## Current behavior and ownership

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
- **ipapi account:** User-approved updated terms were accepted October 26.
  Exact-account HTTP and visible Chrome password login succeed, but the account
  explicitly reports `bot_login` suspension and API 403. Stored key matches.
  Automated password login is disabled. The user later authorized the normal
  dashboard key-regeneration action; it produced a new key, now saved in
  `secrets/ipapi`, but its test still returned 403/INVALID_API_KEY and suspension
  remained. Its old key and one-submit receipt are private. The Check.Place
  ipapi relay returned 403 on default proxy, direct IPv4 and isolated ATT too.
  A fresh direct Chrome read through a newly started MCP 0.5.17 also returned
  403/challenge; the user separately confirmed the same relay block in Safari.
  October 27 account HTTP identity still proves suspension. The official API
  now explicitly returns `ERR_FORBIDDEN_NOT_ALLOWED` (rather than the earlier
  invalid/disabled-key code), strengthening the account-restriction diagnosis.
  The appropriate next step is a support review at the official contact address,
  not another key rotation or paid upgrade. The user's hold on the ipapi appeal
  remains in force; this check sent no message and submitted no password.
- **Cloudflare account:** Native hidden Chrome loaded the login form, but one
  password submission required human verification. Existing saved HTTP identity
  returned 403 on proxy/direct. Official Intel API still succeeded; no GUI
  fallback or challenge automation was performed.
- **Ping0 on ATT:** `tls_error` (curl 35) on 2026-10-23 while direct verified.
  Ping0 observes the caller, so a direct fallback would not measure ATT.

## Recent changes worth knowing

Full detail is in `git log`; these are the ones a new session could trip over.

- v50: DB-IP daily-limit recovery directly reuses myutils/web-text from the
  existing Node workspace, verifies the exact public IPv4 record and cleanup,
  and keeps both surfaces' outcomes. No account MCP or GUI is launched. ipapi
  recognizes documented account/key denial codes and makes one anonymous
  context query without clearing the risk restriction. Its parser accepts
  documented crawler-name strings as positive full-tier detections. Offline
  regressions cover routes, consent, mismatches, missing labels, browser/error
  states, unchanged null risk and bilingual tables. The locked MCP dependency
  cache was replenished for missing existing tarballs and the workspace restored
  using `npm ci --offline --ignore-scripts`; no dependency versions were upgraded.
- v49: ipdata owned free developer-key support precedes the relay, keeps keys
  out of argv/output, validates target-bound booleans and preserves keyed
  failures. Added three ipdata tools to the existing provider-accounts MCP:
  private readiness, saved-token HTTP identity and one official risk query.
  Expired account access tokens do not establish API-key failure. No automatic
  signup/login/refresh, paid plan or new daemon. Added account/session/schema,
  credential loading, route, failure and report regressions; removed temporary
  onboarding code, duplicate key/state and verification-message copies after
  saving the formal credentials and one-submit receipts.
- v48: replaced obsolete ipdata demo-key discovery with one same-route free
  API lookup; preserved country, unknown risk and original relay failure in
  both terminal/JSON. Removed obsolete HTML fixtures. Regressions cover the
  reduced free response, wrong targets, stale values, transport/HTTP failures,
  IPv4/IPv6 routing and the default all-source report. Shared object validation
  and ipdata validators now reject concatenated JSON documents as malformed.
- v47: DB-IP quota wording identifies the upstream report, without asserting
  a personal allowance or next-day recovery. The regression covers cn/en table
  alignment and unknown risk. Updated MCP provenance to native hidden Chrome.
- 2026-10-26: MCPs use myutils native hidden Chrome; IPQS auth checks use HTTP.
  Only origin-scoped private-state restoration is shared in `mcp/common/`.
  Pending verification state stays separate; browsers close with their owner.
  Explicit visible Chrome remains a human recovery option. Retired the failed
  headless auth probe and unused fixed-CDP settings. DB-IP generic limit codes
  no longer imply a daily reset; added suspension/login and quota regressions.
- October 26 cleanup keeps only consolidated private verification, the latest
  offline-test log, bilingual drafts and a sanitized curl attachment; temporary
  probe scripts, duplicate outputs and owned temporary Chrome profiles removed.
- 2026-10-24: `common/` holds only helpers with two or more callers.
  `generate_googlemap_url` became `location_map_url` (`common/location.zsh`);
  table layout moved to `report/table.zsh`; `safe_snapshot.rb` and `text.rb`
  moved to `runner/`. `MCP_AUTH.md` became [MCP.md](MCP.md); mail, DNSBL and
  credential contracts moved to `providers/mail.md`, `providers/dnsbl.md` and
  [CREDENTIALS.md](CREDENTIALS.md). ENV-safe test suites run in parallel.
- v44 (2026-10-23): DNSBL reads the DNS header and answer count (SERVFAIL,
  REFUSED and truncated replies are `Unknown`); Ping0 reports transport, HTTP
  and schema failures instead of a bare `unknown`.
- v43: `reputation` no longer requires `bc`; missing commands are listed once.
- Tests: one shared base class (`test/support/reporter_test_case.rb`); the
  former zsh self-test and DB-IP suite were folded into Ruby suites.

## Latest saved live evidence

Private reports under `reports/` are ignored by Git; older runs are in Git
history. Live runs never changed the active Clash state.

| Date / scope | Result / private evidence |
| --- | --- |
| October 27, ipdata v49 | Official owned free key succeeded through direct and isolated ATT: `ProviderStatus.ipdata=ok`, `FactorMeta.ipdata.Source=official_api`; proxy/Tor/server/abuse supplied, VPN/robot null. Native headless account/Profile and browserless GetUser proved the account and matching key. `reports/provider-recheck-20261027/{direct-keyed,att-keyed,ipdata-mcp}.json`; offline log and unsent bilingual ipapi draft in the same private directory. |
| October 27, ipdata/ipapi v48 | Direct and isolated ATT: ipdata free country data with unknown risk, ipapi HTTP 403. Saved HTTP identity confirms ipapi `bot_login` suspension; fixed-target API probe returns `ERR_FORBIDDEN_NOT_ALLOWED`. Public ipdata browser checks did not complete verification. Private evidence: `reports/provider-recheck-20261027/`. |
| October 26, ipdata v48 | Focused direct and isolated ATT reports returned `ProviderStatus.ipdata=ok`, `Source=official_free_api`, country data and `FactorMeta.ipdata.Status=not_provided`; all six risk fields remain null. Check.Place returned `cloudflare_blocked` on both routes. Before/after reports and offline test output: `reports/ipdata-recheck-20261026/`. |
| October 23, direct all-source v43 | 14 of 15 sources returned usable observations, including IPQS, Cloudflare and Ping0. DB-IP returned `daily_quota_exhausted`. `reports/direct-20261023-codex-audit.{json,txt,stderr}` |
| October 27, direct all-source v50 | DB-IP page fallback returned `low` despite visitor daily quota; ipapi anonymous ASN/geography returned but keyed risk remained `account_restricted`. Check.Place/MaxMind was blocked and IPinfo supplied basic data. Other sources, including IPQS/Cloudflare/Ping0, succeeded. `reports/direct-source-recheck-20261027/all-after.{json,ansi,log}` |
| October 23, ATT all-source v43 and focused recheck | Cloudflare, IP2Location and the other table providers succeeded except DB-IP's daily quota and IPQS's initial timeout after direct fallback. A focused IPQS recheck succeeded through direct fallback after selected-route TLS failure, with the same discovered target preserved. Ping0 was unavailable. `reports/att-20261023-codex-audit.{json,txt,stderr}` and `reports/att-ipqs-20261023-codex-audit-recheck.{json,txt,stderr}` |
| October 23, Ping0 v44 | Focused direct check returned `verified`; isolated ATT returned `tls_error`. A separate bounded ATT HTTP probe confirmed curl exit 35, HTTP 000 and no response body. `reports/ping0-{direct,att}-20261023-codex-audit-fixed.{json,stderr}` |
| October 23, DNSBL v44 | A loopback DNS responder verified NOERROR/NXDOMAIN/SERVFAIL/REFUSED handling against the real system `dig`. `reports/dnsbl-local-20261023-codex-audit-fixed.json` |
| October 18, prefix sampling (one /24, three addresses) | All 12 usable target providers returned data; Check.Place MaxMind was blocked and DB-IP/Ping0 were inapplicable. `reports/prefix-samples-20261018-010049-20261018-26159-p9t2sj/`; earlier six-prefix comparison `reports/us-prefix-samples-20261018/summary.md` |
| October 11, route diagnostics | ATT IPQS failed TLS before HTTP on multiple host/TLS variants, while the same key/target succeeded through another route. DB-IP supplied no recovery timestamp. `reports/att-ipqs-20261011-route-diagnostics.json`, `reports/dbip-20261011-route-diagnostics.json` |
