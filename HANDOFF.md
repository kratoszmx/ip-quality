# Current handoff

## Shared utility consumers — 2026-10-14

IPQS and provider-accounts import private-file, TOTP and one-use records
directly from myutils. Local file dependencies and locks match the new owner,
without forwarding packages or third-party version upgrades. IPQS offline
26 tests, provider-accounts 36 tests and isolated browser-text validation
passed. These checks do not establish live provider or account readiness.

Reviewed 2026-10-14. Worktree: `/Users/zmx/Projects/projects/ipquality`, branch
`main`. Reporter remains `v2026-10-11-standalone.31`; this maintenance changes
shared-code placement and documentation, not query policy or account backends.
Start with [AGENTS.md](AGENTS.md); give users its one normal interactive command.

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

## October 14 maintenance

- Moved the actual URL/header stdin-configuration functions from the reporter
  into `common/http_request.zsh`, used by reporter adapters and query-route
  policy directly. No forwarding copy remains. Added an offline curl stub that
  checks credential privacy, intact arguments, exit status and option scope.
- Unified nullable-boolean validation in six provider parsers through
  `common/json_values.jq`. Source-specific field lists, required observations
  and missing/false distinctions stay in those parsers.
- Reviewed every existing common module. Each has multiple production callers;
  no provider-specific implementation needed moving out. Existing provider,
  report and lifecycle boundaries remain appropriate.
- Updated the account-method inventory, including key-only Ipregistry and
  account-free sources. No live login, enrollment, account mutation or reputation
  measurement was performed for this maintenance.
- Removed the resolved September zero-credit support-message copy, obsolete
  version-by-version handoff prose, 36 abandoned patch/preview/research artifacts
  and the empty project `tmp/` directory. Actual reports, current TLS
  evidence, credentials, browser state and private support receipts are retained.
  No `human_docs` content was edited.

Validation: `/bin/zsh -f scripts/test-offline` passed **136 Ruby cases / 3,159
assertions**, **26 IPQS tests** plus build/static doctor, and **36 provider-account
tests**, with no failures/errors/skips. Evidence:
`reports/offline-20261014-maintenance-final.txt`. Shell/Ruby syntax, maintained
local documentation links and `git diff --check` also passed. The separate
synthetic browser-text suite was unchanged; its last 10-case pass remains dated
October 12. No live provider availability is inferred from these checks.

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
