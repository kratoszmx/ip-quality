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

- ported from Bash 4+ assumptions to the system `/bin/zsh`;
- removed the Bash version check and remote Bash upgrade instruction;
- removed every dependency installer and package-manager mutation;
- added a default no-network plan and the exact
  `--confirm-network-lookup` live-query gate;
- added explicit scopes, a direct-only combined mail+DNSBL scope, and a validated
  DNSBL concurrency range of 1–50;
- removed telemetry, run counters, advertisements, sponsor downloads, remote
  menu execution, report upload, and dynamically downloaded reference files;
- removed the ipregistry web-key scraping flow and its embedded fallback key;
- replaced that flow with an optional, strict, fixture-tested Ipregistry
  official-API adapter using a user-owned key;
- removed background spinner processes and Bash-specific runtime constructs;
- replaced remote reference reads with fixed local regular files;
- changed DNSBL child workers to `/bin/zsh`, bounded DNS attempts, and an
  explicit `Unknown` failure class;
- removed the VPS-only SMTP source bind to the discovered public egress address,
  allowing the system route to select the real local source address behind NAT;
- retained masked-IP output by default and disabled command-line proxy secrets;
- added offline self-tests, provider disclosure documentation, and repository
  safety rules;
- added a strict parser for Ping0's official free `/geo` response; it preserves
  location/ASN/organization only after an exact IP match and leaves the
  unavailable public risk score null;
- added strict, fixture-tested parsers for the official RIPEstat Network Info
  and Shodan InternetDB endpoints, exposing routing and public-exposure context
  without mislabeling either as a cleanliness score;
- removed the brittle DB-IP HTML scraper and its invented 0/50/100 conversion
  of qualitative low/medium/high page text;
- added an optional official IPQualityScore adapter while retaining the named
  Check.Place relay as a keyless fallback, with separate quota attribution;
- added optional strict Ipregistry and IPQualityScore adapters plus a private
  data-only credential loader for both official adapters;
  values are validated and passed to curl over standard input rather than
  command arguments;
- evaluated and then removed the DB-IP Extended adapter because the unique
  threat/proxy fields require a paid subscription while its free location data
  duplicates existing sources;
- replaced the fragile proportional score-text bar with explicit per-provider
  matrices with providers across the top, dimensions down the left,
  provider-specific scales, per-field dashes, compact unavailable-source
  summaries, and green/red factor colors;
- normalized inherited ANSI label padding, kept each provider matrix on one
  uninterrupted row, replaced ambiguous-width missing markers with ASCII, and
  merged Ping0, RIPEstat, and Shodan into one official-network observation
  section;
- kept IPQS visible with an explicit source/query-status row, retained its
  documented connection type, and added Shodan hostname counts that were
  previously parsed but discarded by report output;
- repaired the advertised explicit-target IP path, restricted it to honest
  reputation/DNSBL scopes, and skipped current-egress-only Ping0 observations
  for those targets;
- added the explicit target as the second normal route-menu choice, forwarding
  one validated address to provider target parameters over the proxy-cleared
  system route without starting Mihomo;
- loaded ignored project-local raw Ipregistry/IPQS secrets under the same strict
  ownership/mode policy as the global assignment file, and retained independent
  HTTP status for every Check.Place-backed source so one provider failure cannot
  suppress another provider's result;
- distinguished Check.Place's explicit Cloudflare block page from an ordinary
  HTTP 403, and added an official IPQS account-usage preflight so a known empty
  balance does not spend another failed reputation lookup;
- retained every DNSBL zone result in JSON and named marked/blacklisted zones in
  terminal output instead of collapsing all provider answers into counts;
- removed locally synthesized risk bands from relay scores; only a provider's
  explicitly returned text label is displayed, while absent labels stay unknown;
- corrected the IP2Location/IP2Proxy fraud-score contract to its documented
  0–99 potential-risk scale instead of presenting it as 0–100;
- added a zsh entrypoint backed by source-auditable system-Ruby libraries that
  select one cached remote Clash Verge subscription independently of the active
  profile, extract one exact inline leaf, and own a temporary loopback-only
  Mihomo lifecycle;
- split Clash runner, provider parser, and report code by responsibility, then
  moved the verified-file snapshot helper into `leaf_runner/` because it has no
  consumer outside that runtime;
- extracted network-free provider JSON validation and conservative multi-signal
  boolean merging plus connection-type normalization into
  `providers/common.zsh` for reuse by provider adapters;
- extracted the complete `network-manager/ip-quality/` history into the standalone
  `ipquality` repository on 2026-08-23 and removed the obsolete parent-repository
  routing hooks instead of leaving compatibility wrappers;
- labeled the Check.Place basic-information response as an upstream,
  MaxMind-shaped relay rather than claiming a local official MaxMind database;
- normalized the malformed annotated DNSBL entry
  `hostkarma.junkemailfilter.com[brl]` to the queryable zone name
  `hostkarma.junkemailfilter.com`, then removed duplicate zone entries.

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
