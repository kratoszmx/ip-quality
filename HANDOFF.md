# Current handoff

## Recent maintenance — 2026-10-17 to 2026-10-22

Reporter `v2026-10-22-standalone.39`. Query policy, sources and fallbacks are as
documented in [PROVIDERS.md](PROVIDERS.md); per-change detail is in `git log`.

- Structure: `bin/ip-quality` is about 800 lines. Each `providers/*.zsh` holds its
  parser and `db_*` adapter, `report/` owns labels, sections and JSON, and
  sourcing the reporter loads definitions only (used by
  `test/support/self_test.zsh`). One parser handles long options and short
  clusters such as `-4fj`; the no-op `-p`/`--select` flags are gone.
- Shared catalogs: `providers/sources.tsv` (IDs, labels, independent preset,
  plan disclosures) and `ref/non_public_ipv4.txt` (public-IPv4 boundary) are
  read by both entrypoints. Plans list only selected sources and mark DB-IP and
  Ping0 as not applicable for explicit targets.
- Prefix sampling (menu 3, `leaf_runner/prefix_sample.rb`): up to 20 public /24s
  sampled at `.23`, `.127`, `.231` over the system IPv4 route, saved under a
  private `reports/prefix-samples-*` directory. These are database samples, not
  whole-network or node verdicts.
- Provider repairs: MaxMind validates its single relay observation and falls
  back to IPinfo on malformed data; responses reach `jq` byte-exact; ipdata
  recognizes the homepage's `fetch` demo-key form. Every provider parser reads its
  fields in one `jq` pass (`provider_json_fields`); every provider type
  label comes from `styled_provider_type` in `report/labels.zsh`; and DMS coordinates use
  exact integer arithmetic (fixing empty minutes, `60″` and integer inputs).
  IPv6 masking expands `::` properly (no more `fe80:::*` or empty groups), and
  report lines use `print -r`, so saved text reports carry no carriage returns
  and provider text is never reinterpreted as `echo -e` escapes.
- Reliability: reporter, runner and suites pin UTF-8 (C-locale shells previously
  failed 31 tests and non-ASCII leaf names); `scripts/test-offline` runs every
  suite; supervisor's weekly `test.ipquality.test-offline` runs all of them.
- MCPs: one npm workspace whose merged lock keeps only previously reviewed
  versions; both use myutils `generateFreshTotp` and `@myutils/redaction` (the
  union of the former IPQS, provider-account and web-text redactors, so page
  text now also loses long words, dates and 6+ digit numbers).

The latest commit message records its offline validation. The source-catalog,
CLI, jq and DMS changes were not followed by a new live lookup.

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
claim. Reports remain private/ignored and active Clash state was not changed.

| Date / scope | Result / private evidence |
| --- | --- |
| October 18, prefix sampling (one /24, three addresses) | All 12 usable target providers returned data; Check.Place MaxMind was blocked and DB-IP/Ping0 were inapplicable. `reports/prefix-samples-20261018-010049-20261018-26159-p9t2sj/`; earlier six-prefix comparison `reports/us-prefix-samples-20261018/summary.md` |
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
