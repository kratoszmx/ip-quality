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

The imported `ip.sh` was renamed to `ip-quality.zsh` and substantially modified:

- ported from Bash 4+ assumptions to the system `/bin/zsh`;
- removed the Bash version check and remote Bash upgrade instruction;
- removed every dependency installer and package-manager mutation;
- added a default no-network plan and the exact
  `--confirm-network-lookup` live-query gate;
- added explicit scopes and a validated DNSBL concurrency range of 1–50;
- removed telemetry, run counters, advertisements, sponsor downloads, remote
  menu execution, report upload, and dynamically downloaded reference files;
- removed the ipregistry web-key scraping flow and its embedded fallback key;
- removed background spinner processes and Bash-specific runtime constructs;
- replaced remote reference reads with fixed local regular files;
- changed DNSBL child workers to `/bin/zsh`, bounded DNS attempts, and an
  explicit `Unknown` failure class;
- retained masked-IP output by default and disabled command-line proxy secrets;
- added offline self-tests, provider disclosure documentation, and repository
  safety rules;
- added a strict parser for Ping0's official free `/geo` response; it preserves
  location/ASN/organization only after an exact IP match and leaves the
  unavailable public risk score null;
- added a zsh entrypoint backed by source-auditable system-Ruby libraries that
  read the current Clash profile without mutation, extract one exact inline
  leaf, and own a temporary loopback-only Mihomo lifecycle;
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

`ip-quality.zsh` is a modified version of the upstream AGPL-3.0 program. The
upstream `LICENSE` is preserved verbatim. Redistribution or network service use
must continue to satisfy the AGPL-3.0 source-availability obligations.
