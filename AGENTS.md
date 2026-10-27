# AGENTS.md

A source-auditable IP reputation and quality reporter derived from
`xykt/IPQuality`. It asks up to 15 named sources about one IP address (the
current egress, a given public IP, /24 prefix samples or one proxy-subscription
node) and reports each source separately — no combined quality score, and a
failed or missing answer is `unknown`, never clean. Shell code runs with
`/bin/zsh`; the route runner uses only the system Ruby standard library.

## Start here

Give the user only the normal interactive, all-source command:

```text
cd /Users/zmx/Projects/projects/ipquality && /usr/bin/ruby --disable-gems bin/ip-quality-route --confirm-network-lookup -4
```

It asks for direct, a public IP, IPv4 prefix samples, or a subscription leaf.
DNS repair and source fallback are automatic; do not ask the user to choose
presets or diagnostic flags. Everything below is for agents. These commands are
network-free:

```text
cd /Users/zmx/Projects/projects/ipquality
/bin/zsh -f bin/ip-quality --help
/usr/bin/ruby --disable-gems bin/ip-quality-route --direct
/usr/bin/ruby --disable-gems bin/ip-quality-route --help
/bin/zsh -f scripts/test-offline
```

Without `--confirm-network-lookup`, both entrypoints only validate options and
print a disclosure plan; a plan is not a measurement. A live run is a separate
action after the user accepts the disclosure.

| Document | Read it for |
| --- | --- |
| [HANDOFF.md](HANDOFF.md) | Current status, open issues, recent changes and live evidence |
| [PROVIDERS.md](PROVIDERS.md) | Consent and routes, scopes, prefix sampling, source selection, fallbacks, display mapping; links each `providers/<source>.md` contract |
| [TESTING.md](TESTING.md) | Running the offline suites, which suite covers what, test helpers |
| [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md) | Shared helpers in `common/`, their callers and boundaries |
| [SERVICES.md](SERVICES.md) | Processes a run starts (no daemon) and the external weekly test |
| [MCP.md](MCP.md) | The two account MCP servers: first calls, access methods, lessons, evidence |
| [CREDENTIALS.md](CREDENTIALS.md) | API-key names and precedence, private account/TOTP file locations |
| [UPSTREAM.md](UPSTREAM.md) | AGPL provenance and material modifications |

`README.md` is intentionally absent, and there is no project-specific skill.

## Architecture

A live run flows through four layers:

1. **Route runner** — `bin/ip-quality-route` (Ruby) shows the menu or parses
   flags, then prepares the route: it clears proxy variables for direct and
   specific-IP runs, or starts a private loopback Mihomo for one exact
   subscription leaf (`runner/`). Prefix sampling runs the reporter once per
   sample and saves a comparison (`runner/prefix_sample.rb`).
2. **Reporter** — `bin/ip-quality` (zsh) enforces the consent gate and required
   commands, discovers the public egress unless a target was given, and calls
   each selected source's `db_<source>` adapter. `providers/sources.tsv` is the
   source catalog both entrypoints read.
3. **Providers** — `providers/<source>.zsh` fetches through the credential-safe
   helpers in `common/`, validates the response with `jq` and fills one
   associative array per source; `providers/<source>.md` is its contract.
   Relay pauses, query-route fallback and credentials also live here.
4. **Report** — `report/` renders cn/en terminal sections and tables and
   assembles JSON. The tested IP and routed prefix are masked unless `-f`.

Directory map: `common/` (helpers used by two or more modules; see
COMMON_FUNCTIONS.md), `ref/` (vendored DNSBL zones, ISO countries, non-public
IPv4 ranges), `mcp/` (optional account MCPs; `.state/`, `node_modules/`, `dist/`
are private), `test/` (offline suites on one base class in `test/support/`,
sanitized `test/fixtures/`), `secrets/` and `reports/` (private, ignored).

## Choose a route

| Need | Entrypoint |
| --- | --- |
| Current system route | `bin/ip-quality-route --direct` (IPv4 default, `-6` for IPv6); clears proxy variables, needs no Clash cache or Mihomo |
| One subscription node | `bin/ip-quality-route --subscription NAME --leaf NAME -4`; isolated private Mihomo, exact names |
| A chosen scope or public target IP | `bin/ip-quality --scope SCOPE [IP]`; see [route boundary](PROVIDERS.md#consent-and-route-boundary) |

Discover cached node names with `--list-subscriptions` and
`--subscription 'NAME' --list-leaves`. Only inline leaf proxies and their
`dialer-proxy` dependencies are supported, not groups or remote providers.
`--profile PATH` uses a local profile; `--config-test-only` runs Mihomo's local
check only. Without the Clash Verge cache the menu still offers direct, specific
IP and prefix sampling. A system VPN/TUN can still affect direct traffic.

Menu **3** samples up to 20 pasted public /24 prefixes at `.23`, `.127` and
`.231` and saves full sample IPs under a private `reports/prefix-samples-*`
directory; these are database samples, not whole-network verdicts. Contract:
[PROVIDERS.md](PROVIDERS.md#prefix-sampling).

Both entrypoints default to `--sources all` and accept `--sources independent`
or an explicit ID list; unselected providers make no request and report
`disabled`. IPQS DNS repair, direct-IPv4 recovery and public-page fallbacks are
automatic and disclosed in the plan
([PROVIDERS.md](PROVIDERS.md#automatic-query-route-fallback)). Report flags:
`-j` JSON, `-E`/`-l en` English (default `cn`), `-f` unmasked IP, and `-o FILE`
a new `.json`, `.ansi` or plain-text file (existing paths and links are rejected).

## Runtime requirements

The reporter needs `curl` and `jq`; `mail` adds `dig` and `nc`, `dnsbl` adds
`dig` and `xargs`. Exact-leaf runs also need `/usr/sbin/lsof` and Mihomo
(default `/Applications/Clash Verge.app/Contents/MacOS/verge-mihomo`, or
`--mihomo PATH`) and read the Clash Verge `profiles.yaml`/`profiles/` cache
read-only. Missing dependencies stop explicitly; the project installs nothing.
Both entrypoints pin a UTF-8 locale themselves. Optional API keys are listed in
[CREDENTIALS.md](CREDENTIALS.md#reporter-api-keys).

## Provider account MCPs

[mcp/ipqs/AGENTS.md](mcp/ipqs/AGENTS.md) owns the IPQS dashboard, account probe
and the API key shared with the reporter.
[mcp/provider-accounts/AGENTS.md](mcp/provider-accounts/AGENTS.md) owns the
ipapi/Cloudflare/AbuseIPDB/ipdata accounts and account-free DB-IP/IPWHOIS probes.
Both are optional for the reporter; start with [MCP.md](MCP.md). Account
mutations require explicit task intent.

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
never clean. Exact-leaf mode stays reputation-only; DNSBL and SMTP always use the
system route. DNSBL concurrency is 1–50.

## Development workflow

- Tests stay offline: no external DNS, HTTP, mail, SSH, browser, proxy or paid
  route. Every new provider gets a sanitized fixture and parser contract. See
  [TESTING.md](TESTING.md#writing-tests-that-last).
- Validate with `/bin/zsh -f scripts/test-offline`; a fixture pass does not
  establish provider availability or real-node connectivity.
- Reuse shared helpers only where caller semantics match; source schemas,
  labels and lifecycle state stay with their owners. A runtime change bumps
  `script_version` in `bin/ip-quality`.
- After validating, update the HANDOFF status, commit on `main`, push to both
  GitHub remotes and read them back.
- Preserve the AGPL-3.0 license and provenance in `UPSTREAM.md`. This directory
  is the worktree root; no nested Git metadata.
