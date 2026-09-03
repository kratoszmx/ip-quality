# Current handoff

Last offline validation: 2026-09-03, Asia/Shanghai.

## Repository state

- Worktree: `/Users/zmx/Projects/projects/ipquality`
- Maintained branch: `main`
- Branch upstream: `github-kratoszmx/main`
- Primary remote: `https://github.com/kratoszmx/ip-quality.git`
- Backup remote: `https://github.com/kratosbackup/ipquality.git`

Only the two online remotes above are configured. The former parent-project
subtree and its routing hooks have already been removed; maintained code lives
only in this standalone repository. Historical extraction details remain in Git,
while upstream source identity and licensing remain in `UPSTREAM.md`.

There is no project-specific `.agents/skills/` directory. This is intentional:
`AGENTS.md` contains the compact operational rules, and no separate reusable
workflow currently justifies another skill entrypoint.

## Current product behavior

The reporter version is `v2026-08-27-standalone.13`.

- `/bin/zsh -f bin/ip-quality` is the safest first command. It prints the
  selected scope, provider disclosure, output policy, and network gate without
  making a lookup.
- `/bin/zsh -f bin/test-clash-leaf --direct` prints the comprehensive direct
  route plan without needing a Clash cache. Adding the confirmation flag runs
  `full` over the current system IPv4 route, removes inherited proxy variables,
  and starts no Mihomo process.
- Running `bin/test-clash-leaf` without `--direct` opens a route menu backed by
  the Clash Verge cached-subscription catalog. It offers the direct report,
  a specific-public-IP reputation lookup, then each cached remote subscription.
  This menu therefore needs a readable Clash Verge cache even if the user later
  selects a direct route.
- A specific-IP menu run forwards one validated address to reputation providers
  over the proxy-cleared system route. Ping0 is skipped because its public
  `/geo` endpoint describes only the caller's egress. No Mihomo process starts.
- A subscription run selects one exact inline leaf from one cached remote
  subscription, copies only that leaf and any concrete `dialer-proxy`
  dependencies, and runs `reputation` through a private loopback-only Mihomo.
  Live Clash selection and configuration remain unchanged.
- The raw reporter also supports `reputation`, `dnsbl`, `media-ai`, `mail`,
  `mail-dnsbl`, and `full`. Exact-leaf routing intentionally stays
  reputation-only; the route runner's normal direct report is IPv4-only and
  uses `full`.

After the user has explicitly accepted the disclosure, the simplest masked live
direct report is:

```text
/bin/zsh -f bin/test-clash-leaf --direct --confirm-network-lookup
```

For the interactive route/subscription menu, use this only after the same
authorization and only when the Clash Verge cache is available:

```text
/bin/zsh -f bin/test-clash-leaf --confirm-network-lookup -4
```

Terminal and JSON output mask the tested address and RIPEstat prefix by default;
`-f` reveals them. `-j` selects JSON stdout. `-o` exclusively creates a new
local file and rejects existing paths and symlinks. ANSI, JSON, and plain-text
file output are selected by the filename extension.

## Provider and credential state

Provider contracts, disclosure, score semantics, and route boundaries are kept
in `PROVIDERS.md`. Availability is deliberately a per-run result: a relay block,
rate limit, quota response, or schema change becomes an unknown/unavailable
status rather than a clean finding. A missing required command stops explicitly
before a report and also supplies no clean evidence.

Optional official Ipregistry and IPQualityScore keys can come from the private
global assignment file or ignored project-local raw key files. Project-local
values take precedence. The loader validates ownership, permissions, syntax,
and key characters before use; keys are passed to curl through standard-input
configuration rather than process arguments. No credential value is expected in
Git or reports.

The application owns no persistent cache. Clash Verge subscription caches are
external read-only inputs. Isolated Mihomo configuration and logs live in a
private temporary workspace and are removed on success, ordinary failure, and
handled interrupt; later runs can scavenge a dead-owner workspace left by an
unavoidable process or host failure.

## Validation evidence

The following commands passed from the repository root on 2026-09-03 without a
live provider, DNS, mail, or proxy lookup:

```text
/bin/zsh -n bin/ip-quality bin/test-clash-leaf scripts/test-offline providers/*.zsh report/*.zsh
for file in leaf_runner/*.rb; do /usr/bin/ruby -c "$file"; done
/bin/zsh -f scripts/test-offline
/bin/zsh -f bin/ip-quality --self-test
/bin/zsh -f bin/ip-quality --help
/bin/zsh -f bin/test-clash-leaf --direct
```

The complete fixture-only suite passed 58 runs and 839 assertions: reporter
tests contributed 38 runs/687 assertions and exact-leaf tests contributed
20 runs/152 assertions. The self-test also validated all 422 vendored DNSBL
entries.

Coverage includes the no-network gate, every scope plan, CLI validation,
provider parsing and failure independence, private credential loading, typed and
masked JSON, terminal alignment, DNSBL concurrency/results, SMTP route behavior,
direct/specific-IP proxy removal, exact-leaf dependency closure, listener
ownership, and cleanup on success, failure, and signal.

No live lookup was repeated during this documentation pass. Past provider or
relay availability is not treated as current state; run a newly authorized live
check when current network evidence is actually needed.

## Handoff status

There is no known code, documentation, migration, or test blocker. Future work
should start with the network-free plan and offline suite, then read
`PROVIDERS.md` before changing query semantics or adding a source.
