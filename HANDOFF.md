# Current handoff

## Structure and reliability maintenance — 2026-10-17

Reviewed 2026-10-17. Worktree: `/Users/zmx/Projects/projects/ipquality`, branch
`main`. Reporter is `v2026-10-17-standalone.32`; query policy, sources and
fallbacks are unchanged. Start with [AGENTS.md](AGENTS.md) and give users its one
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
| October 12, ATT IP2Location-only check | `ok`; `reports/att-ip2location-20261012-baseline.{json,txt,stderr}` |
| October 12, ATT full v31 report | All 11 table providers returned `ok`, including IP2Location and DB-IP; Check.Place MaxMind remained blocked. `reports/att-20261012-v31-baseline.{json,txt,stderr}` |
| October 11, full direct/ATT reports | Ten table providers returned `ok`; DB-IP reported daily quota exhaustion. ATT IPQS recovered through direct fallback while retaining `tls_error`; Cloudflare succeeded on its selected route. `reports/{direct,att}-20261011-v31.{json,txt,stderr}` |
| October 11, route diagnostics | ATT IPQS failed TLS before HTTP on multiple host/TLS variants, while the same key/target succeeded through another route. DB-IP supplied no recovery timestamp. `reports/att-ipqs-20261011-route-diagnostics.json`, `reports/dbip-20261011-route-diagnostics.json` |

The user paused the proposed extra IP2Location route change on October 12 after
successful baseline checks, pending their own run. That change was not shipped;
the abandoned patch was removed during this cleanup. Existing selected-route
public-example fallback remains in place.

## Unresolved external observations

- ATT-to-IPQS TLS access and Check.Place relay denial were not repaired at their
  source. Reporter fallbacks recover other usable data; attribution to a specific
  remote edge is unconfirmed. The last support-mail check was October 11, with
  no reply then. Current inquiry/evidence: [IPQS TLS support](mcp/ipqs/SUPPORT-TLS-20261010.md).
- DB-IP returned `ok` on October 12 after October 11's quota failure. There is no
  guaranteed demo reset/recovery time. Failed or expired source sessions remain
  explicit; do not interpret saved account files as live authentication.
- Earlier direct Ping0 geography was verified; ATT's October 11 supplemental
  observation remained unknown. Other providers supplied location/ASN context.

[TESTING.md](TESTING.md) owns complete/focused validation commands and their
limits. Earlier change history remains in Git rather than duplicated handoff
sections. Enabled GitHub remotes are `github-kratoszmx` (`kratoszmx/ip-quality`)
and `github-kratosbackup` (`kratosbackup/ipquality`); synchronize and read back
both after validating owned changes.
