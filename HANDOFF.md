# Current handoff

## Interactive IPv4 prefix sampling — 2026-10-18

Version `v2026-10-18-standalone.34` adds menu **3** to the same normal all-source
command. Paste three-octet prefixes or `.0/24` networks and finish with a blank
line. The runner validates all input, deduplicates up to 20 public /24s, then
queries `.23`, `.127`, `.231` sequentially over the system IPv4 route. It saves
full sample addresses and per-target JSON/text/logs plus comparison summaries in
a new private `reports/prefix-samples-*` directory. These are database samples,
not node/whole-network quality verdicts. Failed providers remain unknown;
malformed/mismatched reports cannot supply scores. Interrupt/TERM stops the owned
reporter and retains completed/partial evidence. The direct/target menu now also
works without a usable Clash cache; cached-subscription entries start at 4.

DB-IP now matches Ping0's explicit-target behavior: `not_applicable_target`, no
visitor-egress requests, and a visible table status. This avoids wasting demo
quota or assigning the caller's data to a sample. `leaf_runner/prefix_sample.rb`
owns the sampling policy; it reuses the existing snapshot/proxy helpers and the
runner's process-group cleanup. No account, live Clash or `human_docs` changes.

Live evidence: the new menu checked three addresses in one /24 with all sources.
All 12 usable target providers returned data (including RIPEstat/Shodan);
Check.Place MaxMind was blocked, and DB-IP/Ping0 were inapplicable. Private data:
`reports/prefix-samples-20261018-010049-20261018-26159-p9t2sj/`. The saved Markdown
was re-rendered after the percent-format correction without new queries. The
earlier six-prefix / 18-address comparison, including two successful focused
timeout retries, is in `reports/us-prefix-samples-20261018/summary.md`.

Validation: **155 Ruby tests / 3,684 assertions**, **26 IPQS tests** and
**36 provider-account tests**, all passed with no failures/errors/skips.
Evidence: `reports/offline-20261018-prefix-sampling-complete.txt`. New coverage
includes no-consent/no-cache selection, bounded public input, zero/unknown/percent
scores, unchanged explicit targets, private files, partial failures and real TERM
child cleanup. Provider results above are dated observations, not future access
guarantees. Start with [AGENTS.md](AGENTS.md) for the unchanged user command.

## Optimization review and provider repairs — 2026-10-18

Reviewed Claude's changes from `979d6dd` through `a428b79` on `main`, including
the reporter split, locale changes, account-MCP utility imports and npm workspace.
Reporter is now `v2026-10-18-standalone.33`. The maintained offline behavior and
real direct/ATT report paths were exercised; this was not a fresh account-login
or 2FA enrollment audit.

- MaxMind relay: malformed nested fields previously emitted jq errors while
  retaining `ok` and preventing IPinfo fallback. Validate the single observation
  object before reads, preserve transport failures, clear stale fields and use
  IPinfo on malformed data. A failed English supplement leaves valid primary
  observations intact. Valid partial responses and zero coordinates still work.
- Literal JSON: legacy `echo` calls interpreted backslashes before jq in
  MaxMind and six other source adapters. Use `print -rn --` so valid responses
  retain their bytes; regressions cover a literal text field and unaffected
  scores/flags despite escaped text in an unrelated field. These parser defects
  predated Claude's module split.
- ipdata: the public homepage now uses `fetch` rather than the older `$.get`
  spelling. The former parser could not find its demo key, causing ATT fallback
  to report `invalid_response`. Recognize both exact-origin forms, still require
  one safe key and keep it out of arguments/reports. The actual ATT fallback
  returned `ok` after the repair.

Final validation: **145 Ruby tests / 3,529 assertions**, **26 IPQS tests** and
**36 provider-account tests**, no failures/errors/skips. The separate synthetic
Chrome suite passed all **10 cases**, with zero live requests and no real profile.
Evidence: `reports/offline-20261018-codex-audit-complete.txt` and
`reports/browser-text-20261017-codex-audit.txt` (private/ignored). Reports and
credentials stay out of Git; no `human_docs` or live Clash state was changed.
After the ATT runs, no isolated Mihomo processes or leaf workspaces remained.

## Structure and reliability maintenance — 2026-10-17

Reviewed 2026-10-17. Worktree: `/Users/zmx/Projects/projects/ipquality`, branch
`main`. Commit `a428b79` shipped `v2026-10-17-standalone.32`; query policy, sources
and fallbacks were unchanged. Start with [AGENTS.md](AGENTS.md) and give users its one
normal interactive command.

- Locale: from a C/POSIX shell (empty `LANG`, as in agent shells and launchd) the
  offline suite failed with 3 failures and 28 errors, and the runner could not
  match non-ASCII `--subscription`/`--leaf` names. Reporter, runner and test
  suites now pin UTF-8; `scripts/test-offline` runs every suite before reporting
  failures.
- Reporter split: `bin/ip-quality` went from 2,933 to about 800 lines. Each
  `providers/*.zsh` holds its parser and live `db_*` adapter; mail/DNSBL probes,
  labels, report sections and JSON assembly have their own modules. Sourcing the
  reporter loads definitions only, which `test/support/self_test.zsh` uses
  (`--self-test` left the CLI). Short options are validated before the plan;
  the unused random user agent and progress-width state are gone; `mode_lite`
  became `basic_source`.
- MCPs: one npm workspace (`mcp/package.json`, `mcp/package-lock.json`). The
  merged lock contains only versions from the two earlier reviewed locks: IPQS
  moved to the provider-accounts SDK transitive versions, playwright-core 1.63.0
  and zod 4.6.2. Both MCPs use myutils `generateFreshTotp`.
- Supervisor's weekly check is `test.ipquality.test-offline` (complete suite),
  replacing the IPQS-only check.
- AGENTS.md (14 KB to 7.6 KB) and COMMON_FUNCTIONS.md (23 KB to 8.4 KB) were
  condensed; provider-account module APIs moved to their own guide.

The validation result is in the commit message that adds this section. No live
provider, account or node lookup was performed.

## Current behavior and ownership

- The runner uses `reputation` and all sources by default. Direct and isolated
  subscription routes share the report; media/AI probes were removed. Every
  attempted source remains visible on failure, with unknown risk rather than a
  clean result. Cloudflare network context belongs only in section 1.
- Official direct IPv4 IPQS uses verified AliDNS HTTPS resolution automatically.
  Official IPQS/Cloudflare target queries can recover from pre-HTTP connection
  failures through one direct IPv4 fallback, preserving the discovered target,
  original failure and effective query route. IPQS retains its credit preflight.
  This does not establish that the failed node-to-provider path works.
- Check.Place block/429 handling suppresses repeated relay calls for the same
  target/family. Scamalytics, IP2Location and ipdata can use their target-bound
  public examples on the selected route; owned AbuseIPDB credentials choose its
  official API. Basic data has a named IPinfo fallback. DB-IP's visitor demo stays
  on the tested egress and reports quota exhaustion without a fabricated score.
  Full contracts and fallback limits live in [PROVIDERS.md](PROVIDERS.md).
- `common/` holds provider values, nullable jq predicates, credential-safe curl
  configuration, terminal layout and Ruby file/text/proxy primitives. Provider
  schemas, query-route policy, display labels and Mihomo lifecycle remain with
  their owners. APIs/callers are in [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md).
- Two optional MCPs live under `mcp/`. The IPQS API uses HTTP; its dashboard uses
  retained headed Chrome. ipapi/Cloudflare/AbuseIPDB routine account reads reuse
  saved HTTP state. Recovery modes and dated 2FA proofs are in
  [MCP_AUTH.md](MCP_AUTH.md); private formats are in [CREDENTIALS.md](CREDENTIALS.md).
- No project daemon is required. The October 12 service audit found only the
  external weekly IPQS offline-test registration, with no resident project
  browser/listener, launchd job or cron job. Current process ownership and the
  external registration are documented in [SERVICES.md](SERVICES.md).

## Latest saved live evidence

These observations are dated; offline success is not a current availability
claim. Reports remain private/ignored and active Clash state was not changed.

| Date / scope | Result / private evidence |
| --- | --- |
| October 18, ATT full v33 after repairs | Ten of 11 table providers returned `ok`, including ipdata's public fallback, IP2Location and IPQS. DB-IP reported daily quota exhaustion. Cloudflare succeeded; IPQS used direct fallback after selected-route TLS failure. MaxMind was blocked, with IPinfo supplying basic information; Ping0 remained unknown. `reports/att-20261018-codex-audit-fixed.{json,txt,stderr}` |
| October 18, direct v33 focused verification | MaxMind and IPinfo returned `ok`, verifying the new schema against a real response. Cloudflare intelligence timed out again; unauthenticated `/client/v4/ips` on the same host returned HTTP 200 with both system DNS and AliDNS, so the exact intelligence-timeout cause is unconfirmed. `reports/{maxmind,cloudflare}-direct-20261018-codex-audit.{json,txt,stderr}` |
| October 17, direct full v32 baseline | Nine of 11 table providers returned `ok`; DB-IP reported daily quota exhaustion, Cloudflare timed out, MaxMind was available and Ping0 verified. `reports/direct-20261017-codex-audit.{json,txt,stderr}` |
| October 12, ATT IP2Location-only check | `ok`; `reports/att-ip2location-20261012-baseline.{json,txt,stderr}` |
| October 12, ATT full v31 report | All 11 table providers returned `ok`, including IP2Location and DB-IP; Check.Place MaxMind remained blocked. `reports/att-20261012-v31-baseline.{json,txt,stderr}` |
| October 11, full direct/ATT reports | Ten table providers returned `ok`; DB-IP reported daily quota exhaustion. ATT IPQS recovered through direct fallback while retaining `tls_error`; Cloudflare succeeded on its selected route. `reports/{direct,att}-20261011-v31.{json,txt,stderr}` |
| October 11, route diagnostics | ATT IPQS failed TLS before HTTP on multiple host/TLS variants, while the same key/target succeeded through another route. DB-IP supplied no recovery timestamp. `reports/att-ipqs-20261011-route-diagnostics.json`, `reports/dbip-20261011-route-diagnostics.json` |

The user paused the proposed extra IP2Location route change on October 12 after
successful baseline checks, pending their own run. That change was not shipped;
the abandoned patch was removed during this cleanup. Existing selected-route
public-example fallback remains in place.

## Unresolved external observations

- ATT-to-IPQS TLS access still needed direct fallback on October 18. Check.Place
  denied ATT while the direct MaxMind query succeeded. Cloudflare intelligence
  succeeded on ATT but timed out on direct; its public API endpoint was reachable
  directly. Reporter fallbacks recover other usable data; attribution to a
  specific remote edge is unconfirmed. The last support-mail check was October 11, with
  no reply then. Current inquiry/evidence: [IPQS TLS support](mcp/ipqs/SUPPORT-TLS-20261010.md).
- DB-IP returned `ok` on October 12, then daily quota exhaustion on both direct
  and ATT during this audit. There is no
  guaranteed demo reset/recovery time. Failed or expired source sessions remain
  explicit; do not interpret saved account files as live authentication.
- Direct Ping0 geography was verified on October 17; ATT's October 18 supplemental
  observation remained unknown. Other providers supplied location/ASN context.

[TESTING.md](TESTING.md) owns complete/focused validation commands and their
limits. Earlier change history remains in Git rather than duplicated handoff
sections. Enabled GitHub remotes are `github-kratoszmx` (`kratoszmx/ip-quality`)
and `github-kratosbackup` (`kratosbackup/ipquality`); synchronize and read back
both after validating owned changes.
