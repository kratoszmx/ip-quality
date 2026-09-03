# AGENTS.md

This repository contains a source-auditable IP reputation and quality reporter
derived from `xykt/IPQuality`. The user-facing shell is `/bin/zsh`; a small
exact-leaf runner uses only the system Ruby standard library.

## Start here

Use these network-free commands to understand the project before changing it:

```text
/bin/zsh -f bin/ip-quality
/bin/zsh -f bin/ip-quality --help
/bin/zsh -f bin/test-clash-leaf --direct
/bin/zsh -f scripts/test-offline
```

The first and third commands print disclosure plans. They do not perform DNS or
network access. A live run is intentionally a separate action and requires the
exact `--confirm-network-lookup` flag.

Documentation has four distinct jobs:

- `AGENTS.md`: operational and safety guidance;
- `PROVIDERS.md`: query scopes, provider contracts, and disclosure details;
- `UPSTREAM.md`: AGPL provenance and local modification notice;
- `HANDOFF.md`: current repository state and last validated commands.

`README.md` is intentionally absent. There is currently no project-specific
skill; the project guidance is short enough to keep here without duplicating it
under `.agents/skills/`.

## Safety invariants

These constraints protect credentials, live proxy state, and the meaning of the
report. Other implementation details may be chosen pragmatically.

- Run shell code with `/bin/zsh`; do not install or invoke a newer Bash. The
  exact-leaf runner may use `/usr/bin/ruby --disable-gems` and the bundled
  standard library, but no gems or language installer.
- Do not run third-party installers, package managers, downloaded shell
  fragments, or dynamically downloaded code from this repository.
- Keep the default reporter and route-runner invocations network-free. Only the
  exact `--confirm-network-lookup` flag authorizes live provider, DNS, or TCP
  queries. Each live source can observe the tested egress IP and request
  metadata; keep the source named and the disclosure visible.
- Never activate, reload, restart, or rewrite live Clash/Mihomo state. An
  exact-leaf run reads one cached remote subscription independently of the active
  profile, copies one selected inline leaf into a private temporary workspace,
  binds a separate Mihomo process to a random `127.0.0.1` port, and verifies
  listener ownership before querying.
- Do not upload reports, emit telemetry, show advertisements, or fetch executable
  configuration. Runtime reference data stays vendored with provenance recorded.
- Keep reports, API keys, cookies, proxy credentials, and account data out of
  Git. Credentials are data-only private files, never command arguments or Git
  configuration.
- The application creates no persistent cache. Clash Verge caches are external
  read-only inputs and must not be deleted. Owned Mihomo workspaces are removed
  on success, ordinary failure, and interrupt; a user-requested `-o` report is an
  output and remains in place.

## Measurement model

- Keep every provider's result and scale identifiable. Conflicts stay visible;
  they are not collapsed into one unexplained score or truth value.
- Supported reporter scopes are `reputation`, `dnsbl`, `media-ai`, `mail`,
  `mail-dnsbl`, and `full`. Provider failure, rate limiting, and schema drift are
  `unknown`, never clean. A missing required command stops the run with an
  explicit dependency error and likewise provides no clean evidence.
- Output masks the tested IP and routed prefix by default. `-f` is the explicit
  reveal option.
- DNSBL concurrency is user-configurable from 1 through 50 and remains bounded
  by tests.
- Exact-leaf selection is reputation-only because its HTTP(S) traffic can be
  forced through the isolated proxy. DNS, SMTP, and other direct sockets would
  still measure the host route and must not be presented as leaf measurements.
- The route runner's comprehensive direct mode is IPv4-only, removes inherited
  proxy variables, starts no Mihomo process, and combines reputation, media/AI,
  mail, and DNSBL observations over the current system route.

See `PROVIDERS.md` before adding or reinterpreting a source.

## Source map

- `bin/ip-quality`: CLI policy, live queries, aggregation, and JSON assembly.
- `bin/test-clash-leaf`: thin zsh entrypoint for the route runner.
- `leaf_runner/`: verified cached-subscription snapshots, exact-leaf extraction,
  route selection, loopback Mihomo ownership, and cleanup.
- `providers/`: fixture-testable response parsers, credential loading, and shared
  provider normalization.
- `report/`: provider-aware terminal output without a synthetic combined score.
- `ref/`: vendored runtime data.
- `test/fixtures/`: sanitized provider responses.
- `scripts/test-offline`: complete fixture-only validation entrypoint.

## Development guidance

- Tests remain offline: no external DNS, HTTP, mail, SSH, browser, proxy, or paid
  route. Add a sanitized fixture and parser contract with every new provider.
- Run the complete suite from the worktree root with
  `/bin/zsh -f scripts/test-offline`. Focused tests use
  `/usr/bin/ruby test/ip_quality_test.rb` and
  `/usr/bin/ruby test/clash_leaf_runner_test.rb`; system-bundled `minitest` is the
  only test-time default gem.
- Preserve the upstream AGPL-3.0 license, source identity, and material
  modification notice in `UPSTREAM.md`. This directory is the worktree root; do
  not introduce nested Git metadata.
- `/Users/zmx/Projects/myutils` currently exposes Python APIs. Importing them or
  adding a Conda subprocess would cross this repository's zsh/system-Ruby runtime
  boundary. Provider schemas, report layout, Clash cache selection, and process
  cleanup remain project-specific unless a genuinely compatible shared API is
  introduced later.
