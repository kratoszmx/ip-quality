# AGENTS.md

This repository contains a source-auditable IP reputation and quality reporter
derived from `xykt/IPQuality`. It reports each source separately, without a
combined quality score. Shell code runs with `/bin/zsh`; the route runner is a
direct executable using the system Ruby standard library.

## Start here

Start at the worktree root. These commands are network-free:

```text
cd /Users/zmx/Projects/projects/ipquality
/bin/zsh -f bin/ip-quality
/bin/zsh -f bin/ip-quality --help
/usr/bin/ruby --disable-gems bin/test-clash-leaf --direct
/usr/bin/ruby --disable-gems bin/test-clash-leaf --help
/bin/zsh -f scripts/test-offline
```

The reporter and direct-route commands print disclosure plans. A live run is a
separate action requiring `--confirm-network-lookup` after the user accepts the
disclosure. A plan is not a measurement.

| Document | Read it for |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Usage, safety, source map, and test entrypoints |
| [HANDOFF.md](HANDOFF.md) | Current version, validation evidence, and pending work |
| [TESTING.md](TESTING.md) | Offline prerequisites, complete/focused commands, suite ownership, and result interpretation |
| [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md) | Shared APIs, definitions, callers, inputs/outputs, and examples |
| [SERVICES.md](SERVICES.md) | No resident service; temporary process startup, shutdown, and checks |
| [PROVIDERS.md](PROVIDERS.md) | Query scopes, source contracts, and disclosure |
| [CREDENTIALS.md](CREDENTIALS.md) | Private account/API/TOTP path and format index |
| [UPSTREAM.md](UPSTREAM.md) | AGPL provenance and material modifications |

`README.md` is intentionally absent. There is currently no project-specific
skill; the project guidance is short enough to keep here without duplicating it
under `.agents/skills/`.

## Choose a route

| Need | Entrypoint | Measurement |
| --- | --- | --- |
| Current system route | `bin/test-clash-leaf --direct` | `reputation`, default IPv4 (`-6` selects IPv6); clears proxy variables and needs no Clash cache or Mihomo |
| One subscription node | `bin/test-clash-leaf --subscription NAME --leaf NAME -4` | `reputation` through an isolated Mihomo; names must match exactly |
| A chosen scope or public target IP | `bin/ip-quality --scope SCOPE` | Raw reporter; see route restrictions in [PROVIDERS.md](PROVIDERS.md#consent-and-route-boundary) |

For a cached node, discover its names and review the plan without a lookup:

```text
/usr/bin/ruby --disable-gems bin/test-clash-leaf --list-subscriptions
/usr/bin/ruby --disable-gems bin/test-clash-leaf --subscription 'SUBSCRIPTION_NAME' --list-leaves
/usr/bin/ruby --disable-gems bin/test-clash-leaf --subscription 'SUBSCRIPTION_NAME' --leaf 'LEAF_NAME' -4
```

Replace the quoted placeholders with listed names. Only inline leaf proxies
and their concrete `dialer-proxy` dependencies are supported, not proxy groups
or remotely fetched provider definitions. `--profile PATH` can use an existing
local profile instead of the subscription cache. `--config-test-only` runs
Mihomo's local configuration check without a provider lookup.

Without route options, the runner opens a menu for direct, specific-public-IP,
or subscription selection. The menu needs a readable Clash Verge cache even
when choosing direct or specific-IP lookup; use `--direct` to avoid that
dependency. The specific-IP menu uses `reputation`, clears inherited proxy
variables, and starts no Mihomo. A system VPN or TUN can still affect direct
traffic.

After authorization, a masked direct IP reputation report is:

```text
/usr/bin/ruby --disable-gems bin/test-clash-leaf --direct --confirm-network-lookup
```

For an exact leaf, add the same confirmation flag to its reviewed plan command.
The raw reporter accepts one positional public IP only with `reputation` or
`dnsbl`; for example, this remains a plan until confirmation is added:

```text
/bin/zsh -f bin/ip-quality --scope reputation -4 8.8.8.8
```

Reports mask the tested IP and routed prefix by default; `-f` reveals them.
`-j` writes JSON to stdout; `-E` or `-l en` selects English labels (default: `cn`).
`-o reports/run.json` creates a new file: `.json` selects JSON, `.ansi` preserves
terminal colors, and other extensions select plain text. Create the parent
directory first and choose an unused filename; existing files and symlinks are
rejected. User-requested reports remain after cleanup. The specific-IP menu's
plan and progress messages include the entered target, so report masking does
not make those messages private.

## Runtime requirements

Plan/help paths use zsh and, for the runner, `/usr/bin/ruby --disable-gems`.
`bin/test-clash-leaf` can also be executed directly; its shebang selects that
Ruby runtime. It contains the command implementation, so do not pass it to zsh.
Live reporter dependencies are checked before querying:

| Scope | Commands beyond normal system utilities |
| --- | --- |
| All scopes | `curl`, `jq` |
| `reputation` | Also `bc` |
| `mail` | Also `dig`, `nc` |
| `dnsbl` | Also `dig`, `xargs` |
| `mail-dnsbl`, `full` | Union of their component requirements |

Exact-leaf live runs also need `/usr/sbin/lsof` and an existing Mihomo binary
(default: `/Applications/Clash Verge.app/Contents/MacOS/verge-mihomo`; override
with `--mihomo PATH`). Cached subscription selection reads `profiles.yaml` and
`profiles/` under
`~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/`.
Missing dependencies stop explicitly; the project installs nothing. Official
API keys are optional; private file formats and precedence are in
[PROVIDERS.md](PROVIDERS.md#optional-official-credentials).

## Provider account MCPs

- [mcp/ipqs/AGENTS.md](mcp/ipqs/AGENTS.md) owns the IPQS dashboard,
  account probe, API integration and private browser profile. Reporter and MCP
  share the same private `secrets/ipqs` key.
- [mcp/provider-accounts/AGENTS.md](mcp/provider-accounts/AGENTS.md) owns free
  ipapi/Cloudflare account setup and account-free DB-IP/IPWHOIS probes. Free
  geography APIs and website risk demos have separate contracts; see
  [PROVIDERS.md](PROVIDERS.md).

MCPs are optional for running the reporter. Both use local dependencies from
the sibling `/Users/zmx/Projects/mcps/common/shared` repository; this checkout
alone does not contain those packages. IPQS needs Node 22+, provider accounts
needs Node 24.5+, and browser tools need Chrome. Build/start/stop commands are in
[SERVICES.md](SERVICES.md#account-mcp-startup-and-shutdown); offline dependency
setup is in [TESTING.md](TESTING.md). Account mutations require explicit task intent.

The default reporter and every route-runner choice use `reputation`. Media/AI
unlock tests were removed because accessibility does not establish IP reputation.
The raw reporter retains optional `mail`, `dnsbl`, `mail-dnsbl`, and `full`
(reputation + mail + DNSBL) scopes for system-route investigations.

## Safety invariants

These constraints protect credentials, live proxy state, and the meaning of the
report. Other implementation details may be chosen pragmatically.

- Run shell code with `/bin/zsh`; do not install or invoke a newer Bash. The
  exact-leaf runner may use `/usr/bin/ruby --disable-gems` and the bundled
  standard library, but no gems or language installer.
- Reporter and route-runner runtime installs nothing and executes no downloaded
  code. MCP development uses its reviewed lockfiles; local dependency restoration
  can use `npm install --offline --ignore-scripts` without third-party installers.
- Keep the default reporter and route-runner invocations network-free. Only the
  exact `--confirm-network-lookup` flag authorizes live provider, DNS, or TCP
  queries. Each live source can observe the tested egress IP and request
  metadata; keep the source named and the disclosure visible.
- Never activate, reload, restart, or rewrite live Clash/Mihomo state. An
  exact-leaf run reads one cached remote subscription independently of the active
  profile and uses a private temporary Mihomo. Listener ownership, shutdown,
  and cleanup are described in [SERVICES.md](SERVICES.md).
- Do not upload reports, emit telemetry, show advertisements, or fetch executable
  configuration. Runtime reference data stays vendored with provenance recorded.
- Keep reports, API keys, cookies, proxy credentials, and account data out of
  Git. Credentials are data-only private files, never command arguments or Git
  configuration.
- The reporter creates no persistent cache. Account MCPs retain only their
  private account/browser state. Clash Verge caches are external
  read-only inputs and must not be deleted. Only owned temporary workspaces are
  eligible for runner cleanup; user-requested reports remain in place.

## Measurement model

Keep provider results and scales identifiable, including conflicts. Provider
failure, rate limiting, and schema drift are `unknown`, never clean. Missing
dependencies likewise supply no clean evidence. Exact-leaf mode stays
reputation-only: direct DNS/SMTP sockets cannot measure that HTTP proxy leaf.
DNSBL concurrency stays bounded to 1–50. Scope definitions and interpretation
live in [PROVIDERS.md](PROVIDERS.md); consult it when changing a source.

## Source map

- `bin/ip-quality`: CLI policy, live queries, aggregation, and JSON assembly.
- `bin/test-clash-leaf`: direct Ruby entrypoint, CLI policy, and route selection.
- `common/`: shared provider values, jq value predicates, terminal text/table layout, printable metadata,
  verified-file snapshots, and child-process proxy overrides; see
  [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md).
- `leaf_runner/`: cached-subscription selection, exact-leaf extraction,
  loopback Mihomo ownership, and cleanup.
- `providers/`: fixture-testable response parsers and credential loading.
- `report/`: provider-aware terminal output without a synthetic combined score.
- `mcp/`: IPQS and free provider-account integrations; private `.state/`,
  `node_modules/` and `dist/` stay out of Git.
- `ref/`: vendored runtime data.
- `test/fixtures/`: sanitized provider responses.
- `test/*_test.rb`, `test/support/`: focused suites and test-only helpers; see
  [TESTING.md](TESTING.md).
- `scripts/test-offline`: complete fixture-only validation entrypoint.

## Development guidance

- Tests remain offline: no external DNS, HTTP, mail, SSH, browser, proxy, or paid
  route. Add a sanitized fixture and parser contract with every new provider.
- Run the complete suite from the worktree root with
  `/bin/zsh -f scripts/test-offline`. [TESTING.md](TESTING.md) is the canonical
  guide to prerequisites, suite responsibilities, focused runs, and failure
  interpretation. Keep gems enabled for Minitest. A fixture pass does not
  establish current provider availability or real-node connectivity.
- Shared helpers and their zsh/system-Ruby boundary are documented in
  [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md). Reuse follows matching caller
  semantics; source schemas, display labels, and lifecycle state stay with
  their owning components.
- Preserve the upstream AGPL-3.0 license, source identity, and material
  modification notice in `UPSTREAM.md`. This directory is the worktree root; do
  not introduce nested Git metadata.
