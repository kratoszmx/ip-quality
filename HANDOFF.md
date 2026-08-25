# IP quality standalone handoff

Last validated: 2026-08-26, Asia/Shanghai.

## Repository identity

- Worktree: `/Users/zmx/Projects/projects/ipquality`
- Branch: `main` only
- Online primary: `https://github.com/kratoszmx/ip-quality.git` (public; empty
  before the 2026-08-24 synchronization)
- Online backup: `https://github.com/kratosbackup/ipquality.git` (private;
  backup-specific authenticated access confirmed on 2026-08-25)
- Branch upstream: `github-kratoszmx/main`

The corrected `kratoszmx/ip-quality` target is accessible to the owner's current
credential. GitHub reports it as public; do not change repository visibility
without an explicit owner decision. The backup-specific token authenticates as
`kratosbackup`, can access the private backup repository, and is passed only by a
temporary askpass environment. macOS's default credential helper can otherwise
pre-fill the primary GitHub identity and produce a misleading `Repository not
found`; one-shot backup operations disable that helper without changing local or
global Git configuration. Both online remotes were brought to the current `main`
after the 2026-08-25 validation. Never place a token in a remote URL or Git
configuration.

The obsolete `origin` and `usb` remotes were disconnected. Their exact bare
repositories, `/Users/zmx/gitrepos/ipquality.git` and
`/Volumes/USB/gitreposbak/ipquality.git`, were moved to the macOS Trash rather
than deleted irreversibly. The USB receive wrapper was removed with those
remotes. This worktree now uses online remotes only.

## Extracted history

The complete former `network-manager/ip-quality/` path was extracted with
`git subtree split --prefix=ip-quality main`. The standalone history is:

- `7d9d1f8c20e04f99277664426482f73890ecc379` — original parent commit
  `c45a4c22a1296443d41b8bec30807698cad1c56e`
- `835621c3852338669993992f80cdc0f38a6e0a8f` — original parent commit
  `69acba677c662ce21ba3f5c756312dc0d3a6dc36`
- `2879887b17f41d29ab253efdd179129cf5ea8fe7` — original parent commit
  `b16a9fbb96159e4a04a72c1a05a2a725cb99cd2f`

The extraction preserves authorship, timestamps, messages, and file history
without retaining parent-repository files or nested Git metadata.

## Standalone structure and decisions

- The reporter moved from the root to `bin/ip-quality`; no compatibility wrapper
  remains.
- Exact-leaf runtime code is under `leaf_runner/`; provider parsers, terminal
  rendering, references, fixtures, and tests have their own directories.
- The default route selector places direct connection beside cached remote
  subscriptions. Direct mode removes inherited proxy environment variables and
  runs no Mihomo process; subscription mode retains exact-leaf isolation.
- Report stdout goes through `report/output.zsh`, which uses raw zsh `print` so
  JSON escapes such as `\n` and `\t` survive unchanged until the consumer parses
  them.
- Optional official Ipregistry and IPQualityScore adapters live
  beside their fixture-testable parsers in `providers/`. Their strict local
  credential file is data-only, mode `600`, and never enters Git, reports, or
  process arguments. IPQS falls back to the named Check.Place relay and always
  keeps a compact source/status score column; an unavailable optional
  Ipregistry source does not create an empty table column.
- A positional public target address is now a working reporter input rather
  than stale help text. It is limited to reputation or DNSBL lookups. Ping0 is
  skipped with an explanation because its public `/geo` endpoint can only
  verify the caller's current egress.
- DB-IP is intentionally absent: its free location endpoint duplicates existing
  observations, while its useful proxy/crawler/threat fields require the paid
  Extended plan. The retired scraper, parser, fixture, JSON keys, and credential
  entry were removed together.
- The former generic-looking `lib/safe_snapshot.rb` is now the project-specific
  `leaf_runner/safe_snapshot.rb`.
- The obsolete README is removed under the local AI-native documentation policy.
  Operational truth is in `AGENTS.md`, provider contracts in `PROVIDERS.md`, and
  provenance in `UPSTREAM.md`.
- `/Users/zmx/Projects/myutils` was inspected. Its public APIs are Python APIs;
  this source-auditable zsh/system-Ruby runtime has no valid reusable dependency.
  Project-specific process, cache, provider, and terminal-table policy remains
  here instead of being forced into `myutils`.

## Safety and output behavior

- Default execution prints a disclosure plan and performs no network lookup.
- Live provider access requires the exact `--confirm-network-lookup` gate.
- Reputation sources are described in two tiers: official-contract core sources
  and clearly attributed supplementary demo/relay sources. Browser leak pages
  remain separate from this non-browser reputation report.
- Terminal reputation sections are compact, data-driven matrices: providers with
  usable results are across the top and dimensions are down the left. Safe boolean
  factors are green and risk factors are red. A field omitted from an otherwise
  usable response is shown as `-`; wholly unavailable sources are named once in a
  compact summary and never presented as clean. JSON retains every provider and
  represents unavailable values as `null`.
- Each of the type, score, and factor matrices stays on one uninterrupted
  provider row. ANSI background padding from inherited labels is normalized
  before table padding. Missing cells use an ASCII hyphen and the score-band
  label uses an ASCII slash, avoiding ambiguous-width punctuation that otherwise
  shifts every later separator in some terminals. Ping0, RIPEstat, and Shodan
  share one compact official-network observation section.
- IPQS exposes connection type in the type matrix when supplied, score and
  source/status in the score matrix on every attempted query, and returned
  booleans in the factor matrix. Relay failure, quota, and rate-limit states no
  longer make the provider disappear. Shodan's parsed hostname count is now
  retained in terminal and JSON output.
- Allowlisted unavailability is reported with a reason instead of repeated
  unknown cells. IPQualityScore relay credit exhaustion is attributed in its
  score source/status row, while a direct-key quota error is attributed to the
  official API. Shodan InternetDB's no-public-record response is shown as
  context rather than cleanliness; arbitrary upstream error messages are never
  echoed.
- Risk-score labels appear only when the provider explicitly returns one. Numeric
  relay scores are never converted into locally invented low/medium/high bands.
- IPinfo is identified as a public demo widget, ipapi.is as a direct public API,
  and Check.Place-backed vendor rows as upstream relays.
- JSON is built with `jq --arg` bindings rather than source interpolation, and
  keeps booleans, numbers, and null values typed. The basic-information source
  follows the actual MaxMind-shaped relay/IPinfo fallback, and display labels
  such as `未知` normalize to JSON `null`.
- DNSBL terminal output names every marked or blacklisted zone. JSON retains a
  per-zone `Results` map in addition to totals, so aggregate counts never erase
  which source produced a finding.
- User-selected output paths use an exclusive, no-follow file descriptor; existing
  paths and symlinks are rejected.
- Default terminal and JSON reports mask both the tested IP and a RIPEstat routed
  prefix derived from it. `-f` is required to reveal either value.
- The runner deletes its private Mihomo workspace on success, error, and interrupt;
  TERM/HUP also terminate and reap the reporter process group. A later run securely
  scavenges a dead-owner workspace left by unavoidable SIGKILL or host failure.
- Clash Verge subscription caches are external read-only inputs and are never
  deleted. User-requested report files are outputs, not caches.
- The basic-information section is labeled as a Check.Place upstream relay whose
  payload is labeled MaxMind. This repository does not claim to own a local `.mmdb`
  or an official MaxMind subscription.
- Only the implemented `cn` and `en` report languages are advertised.

## Validated commands

The normal user-facing entrypoint is intentionally one command. It opens the
route menu, keeps the live-network consent explicit, selects IPv4, and reveals
the exact tested IP only because `-f` is present:

```text
/bin/zsh -f /Users/zmx/Projects/projects/ipquality/bin/test-clash-leaf --confirm-network-lookup -4 -f
```

Agent-only validation from the repository root:

```text
/bin/zsh -n bin/ip-quality bin/test-clash-leaf scripts/test-offline providers/*.zsh report/*.zsh
for file in leaf_runner/*.rb; do /usr/bin/ruby -c "$file"; done
/bin/zsh -f scripts/test-offline
/bin/zsh -f bin/ip-quality --self-test
print -r -- 1 | /bin/zsh -f bin/test-clash-leaf
```

The full offline suite currently has 48 runs and 697 assertions. It covers raw
JSON stdout with embedded tab/newline/ANSI data, real green safe-factor and red
risk-factor bytes, single-matrix CJK/ANSI table separator positions, strict
official provider fixtures and private data-only credential loading, direct-route
proxy-environment removal, explicit-target scope/family validation, per-zone
DNSBL JSON retention, exact-leaf isolation, and cleanup on success, failure, and
signal.

A live direct IPv4 menu run on 2026-08-25 displayed the exact IP under the
explicit `-f` choice, produced aligned type/score/factor tables with real green
and red highlighting, returned an IPQS relay score of 20, and merged Ping0,
RIPEstat, and Shodan into one compact section. An immediate masked JSON rerun
parsed cleanly through `jq` and reached a Check.Place relay account whose IPQS
credits were exhausted, confirming that the two allowlisted states can vary by
relay request. No internal reporter command was printed. The preferred private
temporary parent and `/tmp` both stayed at zero owned workspaces afterward. A
prior read-only probe of the real Clash Verge cache
also selected an exact inline leaf and passed Mihomo `-t` without starting a
listener or making an IP-provider lookup.

A separate masked live direct lookup on 2026-08-25 loaded the owner-provided
Ipregistry key from the private data-only credential file. The official endpoint
returned `ok`; the strict parser retained its usage/company, country, proxy, VPN,
Tor, hosting, and abuse fields, and the resulting JSON passed typed assertions.
The secret itself never appeared in output, process arguments, or Git.

Three owner-supplied public IPv4 targets were compared live on 2026-08-26 with
reputation and all 422 vendored DNSBL zones. The direct Ipregistry, IPinfo,
ipapi.is, RIPEstat, and Shodan paths returned usable observations; Ping0 was
correctly skipped for explicit targets. The Check.Place vendor relays returned
no usable JSON during this run, and IPQS stayed visible as relay/query-failed.
One target had a single ASN-level DNSBL listing plus a Shodan `proxy` tag, one
had the Shodan tag without a DNSBL listing, and one had neither. Raw full-IP
JSON/ANSI reports stayed in a private directory under `/Users/zmx/tmp` and were
not added to Git.

## Completed parent extraction

The original `network-manager/ip-quality/` subtree and its explicit root routing
entries were removed in parent commit
`e88a5c48ebd3dadea065a2d361f39fc9d5bdf793` (`refactor: extract IP quality
project`). That commit passed the complete parent offline aggregate in a clean,
detached worktree and was pushed to both:

- `/Users/zmx/gitrepos/network-manager.git`
- `/Volumes/USB/gitreposbak/network-manager.git`

Both parent remotes resolve `refs/heads/main` to the same extraction commit. The
current parent tree has no `ip-quality/` directory and no active `ip-quality`,
`test-clash-leaf`, or `ip_quality` routing reference. Historical parent commits
remain ordinary Git recovery evidence; all maintained code now lives here.
