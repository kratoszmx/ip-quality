# Current handoff

## Shared-library boundary and doc cleanup — 2026-10-24

Reporter `v2026-10-24-standalone.45`; query behavior is unchanged. `common/` now
holds only helpers used by two or more modules: `show_progress`, the decimal
predicates and `provider_fetch_public_json` moved in from `bin/ip-quality`, and
the coordinate helpers became `common/location.zsh` (`generate_googlemap_url` is
now `location_map_url`; it builds a Check.Place link). Report-only table layout
moved to `report/table.zsh`, and the runner-only `safe_snapshot.rb`/`text.rb` to
`runner/`; their tests moved with them. Obsolete docs removed: superseded live
evidence rows, the abandoned October 12 IP2Location note and the dated
NodeQuality comparison. MCPs: the `test:offline:raw` and provider-accounts
`check` script aliases are gone, and IPQS now rejects unused TypeScript locals
and parameters like myutils. Validation is in the commit message.

## Independent regression review — 2026-10-23

Reporter `v2026-10-23-standalone.44`. Reviewed the 14 commits after `214f0f4`;
the worktree was clean at the start. The baseline complete suite passed, and the
review found two additional failure-handling gaps:

- DNSBL: system `dig` returns exit 0 and empty `+short` output even for SERVFAIL
  and REFUSED. Preserve the DNS header and answer count; these errors, truncated
  or inconsistent replies and malformed records now remain `Unknown`, never
  `Clean`. A loopback DNS responder verified all four NOERROR/NXDOMAIN/SERVFAIL/
  REFUSED outcomes against the real system `dig`; fixtures cover mixed records.
- Ping0: its adapter discarded curl/HTTP failures and exposed only `unknown`.
  Reuse the common HTTP decoder and show the specific failure in JSON and the
  terminal unavailable-source summary. An HTTP error cannot validate a plausible
  four-line body. Keep the visitor request on its original route.
- Removed IPinfo's duplicate registration-country read; the batched parser had
  already populated that field.

Validation: 143 reporter cases / 3,932 assertions, 21 IPQS MCP tests and 34
provider-account MCP tests, all passing. The separate synthetic browser-text
suite passed its 10 cases with zero live requests and no real profile. Direct
and ATT live evidence is recorded below; provider availability is separate from
offline correctness. Private receipts are `reports/offline-20261023-codex-audit-fixed-final.txt`,
`reports/browser-text-20261023-codex-audit.txt` and
`reports/dnsbl-local-20261023-codex-audit-fixed.json`.

## Recent maintenance — 2026-10-17 to 2026-10-23

Changes through `v2026-10-23-standalone.43`. Query policy, sources and fallbacks are as
documented in [PROVIDERS.md](PROVIDERS.md); per-change detail is in `git log`.

- Structure: `bin/ip-quality` is about 800 lines. Each `providers/*.zsh` holds its
  parser and `db_*` adapter, `report/` owns labels, sections and JSON, and
  sourcing the reporter loads definitions only (used by the test probes). One
  parser handles long options and short clusters such as `-4fj`; the no-op
  `-p`/`--select` flags are gone.
- Shared catalogs: `providers/sources.tsv` (IDs, labels, independent preset,
  plan disclosures) and `ref/non_public_ipv4.txt` (public-IPv4 boundary) are
  read by both entrypoints. Plans list only selected sources and mark DB-IP and
  Ping0 as not applicable for explicit targets.
- Prefix sampling (menu 3, `runner/prefix_sample.rb`): up to 20 public /24s
  sampled at `.23`, `.127`, `.231` over the system IPv4 route, saved under a
  private `reports/prefix-samples-*` directory. These are database samples, not
  whole-network or node verdicts.
- Provider repairs: MaxMind validates its single relay observation and falls
  back to IPinfo on malformed data; responses reach `jq` byte-exact; ipdata
  recognizes the homepage's `fetch` demo-key form. Related provider fields use
  batched `jq` reads (`provider_json_fields`); shared textual provider type
  label comes from `styled_provider_type` in `report/labels.zsh`; and DMS coordinates use
  exact integer arithmetic (fixing empty minutes, `60″` and integer inputs).
  IPv6 masking expands `::` properly (no more `fe80:::*` or empty groups), and
  report lines use `print -r`, so saved text reports carry no carriage returns
  and provider text is never reinterpreted as `echo -e` escapes. Terminal width
  and ANSI cleanup use parameter expansion instead of `sed` per cell (250 cells:
  4.85 s before, 0.005 s after).
- DNSBL/mail: multi-record answers are classified per record, non-127/8 answers
  (NXDOMAIN hijacking) are `Unknown`, four glued zones in `ref/dnsbl.list` were
  split (420 zones), and SMTP success needs a `220` greeting line.
- Docs: per-source contracts moved from `PROVIDERS.md` to `providers/<source>.md`.
- Structure: the route command is `bin/ip-quality-route` (formerly
  `bin/test-clash-leaf`; class `RouteCommand`, suite `test/route_runner_test.rb`);
  the runner library directory is `runner/` (it holds direct-route,
  prefix-sampling and catalog code, not only leaf handling); `mcp/ipqs/HANDOFF.md`
  was folded into this file; MCP wrappers `ipqsTotpCode`/`checkCloudflareAccount`
  and the `SOURCE_IDS` alias are gone. The proxy-route test that three callers
  repeated is `http_route_is_proxied` in `common/http_request.zsh`, and the
  Scamalytics/IP2Location relay adapters also read fields in one `jq` pass. Runtime helpers stay in `common/`: myutils
  has no zsh/Ruby, and the reporter must not depend on a private sibling checkout.
- Reliability: reporter, runner and suites pin UTF-8 (C-locale shells previously
  failed 31 tests and non-ASCII leaf names); `scripts/test-offline` runs every
  suite; supervisor's weekly `test.ipquality.test-offline` runs all of them.
- Dependencies (v43): `reputation` no longer requires `bc`, which nothing had
  used since the DMS rewrite, and a scope's missing-command list names each
  command once (`full` previously reported `dig` twice).
- Tests (2026-10-23, three passes): reporter suites 165 → 141 cases (3,812 →
  3,874 assertions) after removing duplicates and adding the gaps below; IPQS
  MCP 26 → 21; provider accounts 36 → 34. `test/support/self_test.zsh` repeated
  ~15 parser checks already in Ruby suites and was removed; its unique
  validator and JSON-typing checks moved to `ip_quality_test.rb` and
  `report_test.rb`. DB-IP tests merged into `public_demo_test.rb`; overlapping
  ipapi, Cloudflare, credential, CLI-option, report and route-runner cases became
  table-driven. All suites share one base class (`zsh!`, `fixture_path`,
  `run_route`, `with_environment`), and runner tests no longer read the real
  Clash cache. New coverage: mail-scope live path (egress discovery skipping
  private/invalid answers, lowest-preference MX, SMTP greeting); per-scope
  required commands; the runner's `--list-subscriptions`, `--list-leaves`,
  `--subscription … --leaf` plan and `--config-test-only` paths and its
  option-combination rules; reporter `--version`. Both MCP suites
  dropped re-tests of `@myutils/redaction`, which myutils covers; IPQS
  auth/account/credential classifiers are table-driven and its stdio contract
  test runs in an OS temporary directory instead of the package's `.state/`.
- MCPs: one npm workspace whose merged lock keeps only previously reviewed
  versions; both use myutils `generateFreshTotp` and `@myutils/redaction` (the
  union of the former IPQS, provider-account and web-text redactors, so page
  text now also loses long words, dates and 6+ digit numbers).

The October 23 regression review above also exercised the source-catalog,
CLI, jq and DMS changes through fresh direct and ATT reports.

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
- No project daemon is required. The only external registration is the weekly
  complete offline suite (`test.ipquality.test-offline`), with no resident project
  browser/listener, launchd job or cron job. Current process ownership and the
  external registration are documented in [SERVICES.md](SERVICES.md).

## Latest saved live evidence

These observations are dated; offline success is not a current availability
claim. Older runs superseded by these are in Git history and `reports/`. Reports remain private/ignored and active Clash state was not changed.

| Date / scope | Result / private evidence |
| --- | --- |
| October 23, direct all-source v43 | 14 of 15 sources returned usable observations, including IPQS, Cloudflare and Ping0. DB-IP returned `daily_quota_exhausted`. `reports/direct-20261023-codex-audit.{json,txt,stderr}` |
| October 23, ATT all-source v43 and focused recheck | Cloudflare, IP2Location and the other table providers succeeded except DB-IP's daily quota and IPQS's initial timeout after direct fallback. A focused IPQS recheck succeeded through direct fallback after selected-route TLS failure, with the same discovered target preserved. Ping0 was unavailable. `reports/att-20261023-codex-audit.{json,txt,stderr}` and `reports/att-ipqs-20261023-codex-audit-recheck.{json,txt,stderr}` |
| October 23, Ping0 v44 | Focused direct check returned `verified`; isolated ATT returned `tls_error`. A separate bounded ATT HTTP probe confirmed curl exit 35, HTTP 000 and no response body. This endpoint observes the caller, so a direct fallback would not measure ATT. `reports/ping0-{direct,att}-20261023-codex-audit-fixed.{json,stderr}` |
| October 18, prefix sampling (one /24, three addresses) | All 12 usable target providers returned data; Check.Place MaxMind was blocked and DB-IP/Ping0 were inapplicable. `reports/prefix-samples-20261018-010049-20261018-26159-p9t2sj/`; earlier six-prefix comparison `reports/us-prefix-samples-20261018/summary.md` |
| October 11, route diagnostics | ATT IPQS failed TLS before HTTP on multiple host/TLS variants, while the same key/target succeeded through another route. DB-IP supplied no recovery timestamp. `reports/att-ipqs-20261011-route-diagnostics.json`, `reports/dbip-20261011-route-diagnostics.json` |

## Unresolved external observations

- ATT-to-IPQS TLS access still needed direct fallback on October 23; the first
  full run timed out on that fallback, while a focused recheck succeeded.
  Cloudflare and Check.Place MaxMind both succeeded on direct and ATT this time,
  superseding their older blocked/timeout observations. Attribution of ATT's
  remaining TLS failures to a specific remote edge is unconfirmed.
  The last support-mail check was October 11, with
  no reply then. Current inquiry/evidence: [IPQS TLS support](mcp/ipqs/SUPPORT-TLS-20261010.md)
  (sent October 10, confirmed in Gmail Sent; exact messages stay private). The
  September zero-credit case was superseded by successful account/API checks
  from September 22; its private receipts are in `mcp/ipqs/.state/support/20260916/`.
- DB-IP returned `ok` on October 12, then daily quota exhaustion on both direct
  and ATT on October 23. There is no
  guaranteed demo reset/recovery time. Failed or expired source sessions remain
  explicit; do not interpret saved account files as live authentication.
- Direct Ping0 geography was verified again on October 23; ATT failed before
  HTTP with curl exit 35 (`tls_error`). Its visitor-only semantics preclude a
  direct fallback. Other providers supplied location/ASN context for ATT.

## Pending outside this repository

- The supervisor skill's `inventory.md` (owned by the skill-maintenance session)
  still lists the retired IPQS-only weekly command. The registered job,
  `test.ipquality.test-offline` in `supervisor/integrations/testing.py`, already
  runs `/bin/zsh -f scripts/test-offline`; only that table row needs updating.

[TESTING.md](TESTING.md) owns complete/focused validation commands and their
limits. Earlier change history remains in Git rather than duplicated handoff
sections. Enabled GitHub remotes are `github-kratoszmx` (`kratoszmx/ip-quality`)
and `github-kratosbackup` (`kratosbackup/ipquality`); synchronize and read back
both after validating owned changes.
