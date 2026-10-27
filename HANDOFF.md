# Current handoff

## Status — 2026-10-26

- Reporter `v2026-10-26-standalone.47` (`script_version` in `bin/ip-quality`).
- Offline: `/bin/zsh -f scripts/test-offline` passes — reporter 144 Minitest
  cases, IPQS MCP 22, provider accounts 40. The separate synthetic IPQS
  browser-text suite last passed 10/10 at commit `782bce3`, with no live requests.
- Live: focused IPQS/DB-IP and MCP login checks on October 26; the latest
  complete direct/ATT reports remain October 23 (table below). Offline
  success is not a provider-availability claim.
- DB-IP recovered in the later October 26 recheck: the unmodified reporter's
  focused direct and isolated ATT runs both returned `Status=ok`, `Band=low`,
  with its existing target-IP validation. No personal account or manual token
  rotation was used. Public detail-page browser reading also succeeded. This
  establishes current availability, not a guaranteed quota or recovery cause.
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
  Scamalytics, IP2Location and ipdata fall back to their target-bound public
  pages on the same route; an owned AbuseIPDB key selects its official API;
  basic data falls back to IPinfo. DB-IP's visitor demo stays on the tested
  egress, returns the provider's original risk label when available, and leaves
  risk unknown on quota errors. Contracts:
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
- **Cloudflare account:** Native hidden Chrome loaded the login form, but one
  password submission required human verification. Existing saved HTTP identity
  returned 403 on proxy/direct. Official Intel API still succeeded; no GUI
  fallback or challenge automation was performed.
- **Ping0 on ATT:** `tls_error` (curl 35) on 2026-10-23 while direct verified.
  Ping0 observes the caller, so a direct fallback would not measure ATT.

## Recent changes worth knowing

Full detail is in `git log`; these are the ones a new session could trip over.

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
| October 23, direct all-source v43 | 14 of 15 sources returned usable observations, including IPQS, Cloudflare and Ping0. DB-IP returned `daily_quota_exhausted`. `reports/direct-20261023-codex-audit.{json,txt,stderr}` |
| October 23, ATT all-source v43 and focused recheck | Cloudflare, IP2Location and the other table providers succeeded except DB-IP's daily quota and IPQS's initial timeout after direct fallback. A focused IPQS recheck succeeded through direct fallback after selected-route TLS failure, with the same discovered target preserved. Ping0 was unavailable. `reports/att-20261023-codex-audit.{json,txt,stderr}` and `reports/att-ipqs-20261023-codex-audit-recheck.{json,txt,stderr}` |
| October 23, Ping0 v44 | Focused direct check returned `verified`; isolated ATT returned `tls_error`. A separate bounded ATT HTTP probe confirmed curl exit 35, HTTP 000 and no response body. `reports/ping0-{direct,att}-20261023-codex-audit-fixed.{json,stderr}` |
| October 23, DNSBL v44 | A loopback DNS responder verified NOERROR/NXDOMAIN/SERVFAIL/REFUSED handling against the real system `dig`. `reports/dnsbl-local-20261023-codex-audit-fixed.json` |
| October 18, prefix sampling (one /24, three addresses) | All 12 usable target providers returned data; Check.Place MaxMind was blocked and DB-IP/Ping0 were inapplicable. `reports/prefix-samples-20261018-010049-20261018-26159-p9t2sj/`; earlier six-prefix comparison `reports/us-prefix-samples-20261018/summary.md` |
| October 11, route diagnostics | ATT IPQS failed TLS before HTTP on multiple host/TLS variants, while the same key/target succeeded through another route. DB-IP supplied no recovery timestamp. `reports/att-ipqs-20261011-route-diagnostics.json`, `reports/dbip-20261011-route-diagnostics.json` |
