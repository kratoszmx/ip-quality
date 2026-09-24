# Upstream provenance and modification notice

## Source snapshot

- Repository: <https://github.com/xykt/IPQuality>
- Upstream commit: `b59787d9832ab163cdf93c10759000ed4ba76cb0`
- Commit time: `2026-08-08T23:09:14+08:00`
- Commit subject: `Update ip.sh`
- License: GNU Affero General Public License v3.0
- Imported on: `2026-08-09`

The upstream repository was cloned into a temporary directory for inspection.
Its `origin` remote was removed before import. Only ordinary files were copied
into the top-level `network-manager/ip-quality/` directory; no upstream `.git/`
metadata, executable binary, submodule, or symlink was imported.

## Upstream file hashes

The hashes below identify the exact upstream inputs before local modification:

| Upstream path | SHA-256 |
| --- | --- |
| `ip.sh` | `760c1d7c44da4c904662ab37591c409ac58371fa2439a77e091f2c23c83251c8` |
| `LICENSE` | `8486a10c4393cee1c25392769ddd3b2d6c242d6ec7928e1414efff7dfb2f07ef` |
| `ref/dnsbl.list` | `a92ca482843310167309c82f05cb7e208d7decc7f8bb7eada0f96af42f1143ad` |
| `ref/iso3166.json` | `e1434e42786484b1841082a0a16cf27208691443dc6440d125ad81d49007ea42` |

## Local modifications

The imported `ip.sh` was renamed to `bin/ip-quality` and substantially modified:

- Ported Bash 4+ constructs and DNSBL workers to system `/bin/zsh`; removed
  background spinners, Bash upgrades, dependency installers, and package-manager
  mutations. Added offline self-tests, fixtures, safety guidance, and disclosure.
- Added default no-network plans, the exact `--confirm-network-lookup` gate,
  explicit scopes, and DNSBL concurrency bounded to 1–50.
- Removed telemetry, counters, advertisements, sponsor downloads, remote menus,
  report uploads, command-line proxy secrets, and runtime reference downloads.
  Reference data is now vendored as regular local files.
- Made direct and leaf routes reputation-only by default; retained opt-in
  mail/DNSBL scopes and removed media/AI unlock probes and their JSON section. Removed
  the SMTP bind to the discovered public address so NAT hosts use the actual
  system-selected source address.
- Repaired explicit-target validation and limited it to reputation/DNSBL;
  skipped egress-only Ping0 for those targets. Added a reputation-only target
  menu route that clears proxy variables and starts no Mihomo.
- Replaced Ipregistry web-key scraping and its embedded fallback key with
  optional, fixture-tested official Ipregistry and IPQualityScore adapters.
  Their data-only credential loader validates private global assignments and
  overriding project-local raw keys, passing secrets to curl through stdin.
- Kept the named Check.Place IPQS relay for keyless runs, distinguished official
  and relay quota failures, and added an official usage preflight that skips
  reputation lookup when an empty balance is confirmed.
- Preserved independent HTTP status for every Check.Place source, distinguished
  its Cloudflare block page from ordinary HTTP 403, and labeled its basic data
  as a MaxMind-shaped relay response rather than a local official database.
- Added strict Ping0 `/geo`, RIPEstat Network Info, and Shodan InternetDB parsers
  for location, routing, and exposure context. Ping0 requires an exact returned
  IP match and exposes no public risk score; Shodan retains hostname counts.
- Removed DB-IP's invented 0/50/100 scores and the paid Extended adapter.
  On 2026-09-24, compared historical upstream commit
  `b3ad433931db9882673e070f59edaf17d56e05ac` (v2025-03-13) with today's provider
  websites. The old DB-IP target demo returned quota errors; the current
  `/api/core/` visitor demo returned original threat labels. Its public guest
  token stays in memory, both requests preserve the route, and the returned
  IP must match the target. IPWHOIS's current `/demo` needs website request
  headers to return security booleans on the tested route. The explicit
  permanent free API contracts remain MCP context probes. Actual quota errors
  stay unavailable; no account or paid plan is required.
  DB-IP's numeric score remains null. Cloudflare/IPWHOIS/DB-IP now appear in
  sections 3/4 and are removed from terminal section 5. Cloudflare's retired,
  now constant-zero Threat Score is explicitly excluded from clean-IP evidence;
  its current IP Intelligence threat categories remain identifiable. Section 3
  also displays its successful ASN country/type/organization observations as
  rows in the same matrix, within the Cloudflare column.
- Replaced score bars with aligned per-provider type/score/factor matrices,
  provider-specific scales, ASCII missing-field markers, colored risk factors,
  and compact unavailable-source summaries. IPQS keeps a source/status row;
  Ping0, RIPEstat, and Shodan share one context section. Reports mask IP/prefix
  by default; JSON preserves types and report files are created exclusively.
  Section 4 retains ipapi.is after a failed or anonymous lookup, with a compact
  query-status row across the factor matrix. Credential mode and response tier
  remain in JSON. Repeated provider prose below the matrices was removed.
- Removed locally synthesized risk bands, retaining only provider-supplied
  labels, and corrected IP2Location/IP2Proxy potential risk to a 0–99 scale.
- Bounded DNS attempts, added `Unknown` outcomes, retained every zone in JSON,
  and named marked/blacklisted zones in terminal output. Normalized
  `hostkarma.junkemailfilter.com[brl]` to `hostkarma.junkemailfilter.com` and
  removed duplicate DNSBL entries.
- Added a system-Ruby runner that reads one cached remote subscription
  independently of the active Clash profile, extracts an exact inline leaf and
  concrete dependencies, and owns temporary loopback-only Mihomo startup,
  listener verification, and cleanup.
- Split runner, provider, and report responsibilities. Consolidated verified
  file snapshots, proxy-environment overrides, printable metadata validation,
  provider value normalization, and terminal text helpers under `common/`.
  Shared bounded text/integer jq predicates now serve five provider parsers,
  including Shodan's integer-port and control-text validation;
  IPQS-only connection-type classification lives back in its provider module.
  The route command now lives directly in `bin/test-clash-leaf`; removed the
  shell forwarding entrypoint and report-output forwarding helper. Header and
  table width calculations share one character-based implementation. Generic
  table measurement, cell padding, rows and rules now live in common/terminal.zsh;
  type/score/factor matrices use independent column widths. Removed the runner's
  clock forwarding method and unused media/AI progress labels.
- Extracted the complete `network-manager/ip-quality/` history into standalone
  `ipquality` on 2026-08-23 and removed obsolete parent routing hooks.
- Added optional Node account MCPs under `mcp/`: IPQS moved from mcps on
  2026-09-22; provider accounts owns free ipapi/Cloudflare setup and account-free
  public API/demo probes. They directly reuse the sibling mcps shared libraries;
  private browser state, credentials and account receipts are excluded from Git.

## Deliberate exclusions

The upstream installer, advertisement/sponsor assets, example screenshots,
remote-reference fallback files, and unused IATA/ICAO dataset were not retained.

Most importantly, upstream `ref/cookies.txt` was removed immediately after
inspection because it mixed request templates with apparent historical account
cookies, sessions, identity data, and credentials. The Disney+ probe that
depended on that bundle was removed with it. None of that material is included
in this directory or intended for Git history.

## License continuity

`bin/ip-quality` is a modified version of the upstream AGPL-3.0 program. The
upstream `LICENSE` is preserved verbatim. Redistribution or network service use
must continue to satisfy the AGPL-3.0 source-availability obligations.
