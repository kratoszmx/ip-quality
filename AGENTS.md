# AGENTS.md

This repository contains a source-auditable IP reputation and quality reporter
derived from `xykt/IPQuality`. It reports each source separately, without a
combined quality score. Shell code runs with `/bin/zsh`; the route runner is a
direct executable using the system Ruby standard library.

## Start here

Give the user only the normal interactive, all-source command:

```text
cd /Users/zmx/Projects/projects/ipquality && /usr/bin/ruby --disable-gems bin/test-clash-leaf --confirm-network-lookup -4
```

It asks for direct, a public IP, IPv4 prefix samples, or a subscription leaf. DNS repair and source fallback are
automatic; do not ask the user to choose presets or diagnostic flags. Everything
below is for agents. These commands are network-free:

```text
cd /Users/zmx/Projects/projects/ipquality
/bin/zsh -f bin/ip-quality --help
/usr/bin/ruby --disable-gems bin/test-clash-leaf --direct
/usr/bin/ruby --disable-gems bin/test-clash-leaf --help
/bin/zsh -f scripts/test-offline
```

Without `--confirm-network-lookup`, the reporter and runner only validate
options and print a disclosure plan; a plan is not a measurement. A live run is
a separate action after the user accepts the disclosure.

| Document | Read it for |
| --- | --- |
| [HANDOFF.md](HANDOFF.md) | Current version, validation evidence and pending work |
| [PROVIDERS.md](PROVIDERS.md) | Scopes, source selection, route fallback, per-source contracts and disclosure |
| [TESTING.md](TESTING.md) | Offline prerequisites, complete/focused commands and suite ownership |
| [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md) | Shared helpers, their callers and boundaries |
| [SERVICES.md](SERVICES.md) | No resident service; temporary processes and the external weekly test |
| [CREDENTIALS.md](CREDENTIALS.md) | Private account/API/TOTP paths and formats |
| [MCP_AUTH.md](MCP_AUTH.md) | Account MCP purposes, first calls, login/2FA evidence and recovery |
| [UPSTREAM.md](UPSTREAM.md) | AGPL provenance and material modifications |

`README.md` is intentionally absent, and there is no project-specific skill.

## Choose a route

| Need | Entrypoint |
| --- | --- |
| Current system route | `bin/test-clash-leaf --direct` (IPv4 default, `-6` for IPv6); clears proxy variables, needs no Clash cache or Mihomo |
| One subscription node | `bin/test-clash-leaf --subscription NAME --leaf NAME -4`; isolated private Mihomo, exact names |
| A chosen scope or public target IP | `bin/ip-quality --scope SCOPE [IP]`; see [route boundary](PROVIDERS.md#consent-and-route-boundary) |

Discover cached node names with `--list-subscriptions` and
`--subscription 'NAME' --list-leaves`. Only inline leaf proxies and their
`dialer-proxy` dependencies are supported, not groups or remote providers.
`--profile PATH` uses a local profile; `--config-test-only` runs Mihomo's local
check only. When the Clash Verge cache is unavailable, the menu still offers
direct, specific IP and prefix sampling; only subscriptions need that cache. A system VPN/TUN can still
affect direct traffic.

Menu **3** accepts pasted three-octet prefixes (`128.241.47`) or explicit
`128.241.47.0/24` networks, separated by newlines, whitespace or commas; a blank
line finishes input. Up to 20 distinct public /24s are checked sequentially at
`.23`, `.127`, `.231`. These are database samples, not whole-network verdicts,
assigned-IP validation, scans or tests through those IPs. The runner saves full
sample addresses, individual JSON/text/logs and a comparison under a new private
`reports/prefix-samples-*` directory. Failure and interruption keep partial
evidence. DB-IP/Ping0 are visibly inapplicable to explicit targets and make no
visitor requests. This mode saves its own files, so `-o`/`-j` are single-report
options only. Source/DNS policy and provider fallback remain unchanged.

Both entrypoints default to `--sources all` and accept `--sources independent`
or an explicit ID list; unselected providers make no request and report
`disabled`. IPQS DNS, direct-IPv4 recovery and public-page fallbacks are
automatic and disclosed in the plan; their contracts are in
[PROVIDERS.md](PROVIDERS.md#automatic-query-route-fallback).

Reports mask the tested IP and routed prefix (`-f` reveals them). `-j` prints
JSON, `-E`/`-l en` selects English (default `cn`), and `-o FILE` creates a new
`.json`, `.ansi` or plain-text report; existing files and symlinks are rejected.
The specific-IP menu's plan and progress messages include the entered target;
prefix sampling deliberately saves full sample IPs for per-address comparison.

## Runtime requirements

The reporter needs `curl` and `jq`; `reputation` adds `bc`, `mail` adds `dig`
and `nc`, `dnsbl` adds `dig` and `xargs`. Exact-leaf runs also need
`/usr/sbin/lsof` and Mihomo (default
`/Applications/Clash Verge.app/Contents/MacOS/verge-mihomo`, or `--mihomo PATH`)
and read the Clash Verge `profiles.yaml`/`profiles/` cache read-only. Missing
dependencies stop explicitly; the project installs nothing. Both entrypoints pin
a UTF-8 locale themselves.

## Provider account MCPs

[mcp/ipqs/AGENTS.md](mcp/ipqs/AGENTS.md) owns the IPQS dashboard, account probe
and API key shared with the reporter.
[mcp/provider-accounts/AGENTS.md](mcp/provider-accounts/AGENTS.md) owns
ipapi/Cloudflare/AbuseIPDB accounts and account-free DB-IP/IPWHOIS probes.
Both are workspaces of `mcp/package.json` and use sibling
`/Users/zmx/Projects/myutils` packages; they are optional for the reporter.
Start with [MCP_AUTH.md](MCP_AUTH.md). Account mutations require explicit task
intent.

## Safety invariants

- Run shell code with `/bin/zsh`; never install or invoke a newer Bash. The
  runner uses `/usr/bin/ruby --disable-gems` and the bundled standard library.
- Runtime installs nothing and executes no downloaded code. MCP dependencies
  come only from the reviewed `mcp/package-lock.json`, restored with
  `npm ci --offline --ignore-scripts` in `mcp/`.
- Default invocations stay network-free. Only the exact
  `--confirm-network-lookup` flag authorizes provider, DNS or TCP queries; each
  source sees the tested egress IP, so keep sources named and disclosed.
- Never activate, reload, restart or rewrite live Clash/Mihomo state. An exact
  leaf runs in a private temporary Mihomo; see [SERVICES.md](SERVICES.md).
- No report upload, telemetry, advertisements or fetched executable
  configuration. Runtime reference data stays vendored with provenance.
- Reports, keys, cookies, proxy credentials and account data stay out of Git.
  Credentials are data-only private files, never command arguments.
- The reporter keeps no persistent cache. Clash Verge caches are read-only
  inputs; only owned temporary workspaces are cleaned up.

## Measurement model

Provider results and scales stay separately identifiable, including conflicts.
Failure, rate limiting, schema drift and missing dependencies are `unknown`,
never clean. Exact-leaf mode stays reputation-only. DNSBL concurrency is 1–50.

## Source map

- `bin/ip-quality`: CLI policy, module load order, egress discovery and run
  orchestration; sourcing it loads definitions without running the CLI.
- `bin/test-clash-leaf`: Ruby route runner, CLI policy and route selection.
- `common/`: credential-safe HTTP, provider values, jq predicates, terminal
  layout, printable metadata, verified snapshots, proxy overrides.
- `providers/`: one file per source (fixture-testable parser plus its live
  `db_*` adapter), mail/DNSBL probes, credentials and source/relay policy;
  `sources.tsv` is the source catalog both entrypoints read for IDs and plans.
- `report/`: cn/en labels, terminal sections and JSON assembly.
- `leaf_runner/`: cached-subscription selection, exact-leaf extraction,
  loopback Mihomo ownership/cleanup, prefix sampling, local batch evidence and
  the Ruby reader of the source catalog.
- `mcp/`: account MCP workspaces; `.state/`, `node_modules/`, `dist/` are private.
- `ref/`: vendored runtime data, including the shared non-public IPv4 ranges. `test/`: offline suites, `test/support/`
  helpers (including the zsh self-test) and sanitized `test/fixtures/`.

## Development guidance

- Tests stay offline: no external DNS, HTTP, mail, SSH, browser, proxy or paid
  route. Every new provider gets a sanitized fixture and parser contract.
- Validate with `/bin/zsh -f scripts/test-offline`; a fixture pass does not
  establish provider availability or real-node connectivity.
- Reuse shared helpers only where caller semantics match; source schemas,
  labels and lifecycle state stay with their owners.
- Preserve the AGPL-3.0 license and provenance in `UPSTREAM.md`. This directory
  is the worktree root; no nested Git metadata.
