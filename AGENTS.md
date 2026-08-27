# AGENTS.md

This repository owns a zsh-native, source-auditable IP reputation and quality
reporter derived from `xykt/IPQuality`.

## Runtime boundary

- `/bin/zsh` is the only supported shell. Do not install or invoke a newer Bash.
  The exact-leaf runner may use the system `/usr/bin/ruby` standard library for
  safe YAML parsing and process ownership; it must not add gems or an installer.
- Never run third-party installers, package managers, remote shell fragments, or
  dynamically downloaded code from this directory.
- The default invocation is read-only planning and performs no DNS or network
  access. Live lookups require the exact `--confirm-network-lookup` flag.
- Live checks may query third-party services and disclose the tested egress IP to
  them. Keep each provider named in the report and document the disclosure.
- Do not activate, reload, restart, or rewrite live Clash/Mihomo state. Exact-leaf
  proxy validation must read one cached remote subscription selected independently
  of the active profile, then copy only the selected inline leaf into a private,
  temporary, loopback-only Mihomo process with a random port and verified listener
  ownership.
- Do not upload reports, emit telemetry, show advertisements, or fetch executable
  configuration. Reference datasets used by the program must be vendored and
  provenance-recorded.
- Keep raw reports, API keys, cookies, proxy credentials, and account data out of
  Git. Credentials must not be placed in command arguments or persisted in Git
  configuration.
- The reporter creates no persistent application cache. Clash Verge subscription
  caches are external read-only inputs and must never be deleted by this project.
  Owned Mihomo configuration/log workspaces are private temporary directories and
  must be removed on success, ordinary failure, and interrupt. User-requested
  `-o` report files are outputs, not caches, and must not be removed automatically.

## Query policy

- Preserve per-source results; do not turn conflicting provider answers into an
  unexplained single truth value.
- Keep query scopes explicit: reputation, DNSBL, media/AI, mail,
  direct mail+DNSBL, or full.
- Concurrency must be bounded and user-configurable. DNSBL may default to 50, but
  tests must prove that the configured cap is enforced.
- A provider failure, rate limit, schema change, or unavailable dependency is an
  `unknown` result, not a clean result.
- Default output masks the tested IP. Revealing it requires an explicit output
  option.
- An exact-leaf selection is restricted to `reputation`. The same menu may expose
  a separately labeled direct mail+DNSBL route that removes proxy environment
  variables and measures the current system IPv4 route. Do not route DNSBL,
  mail, or other direct DNS/TCP tests through an HTTP-proxy environment and
  claim that they measured the leaf.

## Source map

- `bin/ip-quality`: provider queries, aggregation, and report output.
- `bin/test-clash-leaf`: thin zsh exact-leaf entrypoint.
- `leaf_runner/`: cached-subscription catalog, verified local-file snapshots,
  exact-leaf extraction, CLI policy, loopback lifecycle, listener ownership proof,
  and cleanup.
- `providers/`: network-free, fixture-testable provider response parsers and
  project-wide provider normalization helpers.
- `report/`: provider-aware terminal report rendering; provider scales must not be
  collapsed into one synthetic score.
- `ref/`: runtime reference data; `test/fixtures/`: sanitized test data.
- `scripts/test-offline`: complete fixture-only validation entrypoint.
- `HANDOFF.md`: current state, validated commands, Git identities, and migration
  status for the next agent.

## Shared-library boundary

- `/Users/zmx/Projects/myutils` exposes Python utilities. This runtime is restricted
  to `/bin/zsh` and source-auditable system Ruby, so importing Python utilities or
  adding a Conda subprocess would increase coupling and weaken the exact-leaf
  lifecycle. No current public `myutils` API is a valid runtime dependency.
- Project policy, provider schemas, terminal tables, Clash cache selection, and
  process cleanup remain project-specific. Do not move them into `myutils`.
- The former root `lib/` held a Ruby snapshot helper used only by the exact-leaf
  runtime; it now lives in `leaf_runner/` so the repository has no misleading
  machine-global utility surface.

## Development and validation

- This directory is the Git worktree root and may contain its own `.git/`; no
  subdirectory may contain nested Git metadata.
- Preserve the upstream AGPL-3.0 license, commit identity, and modification notes
  in `UPSTREAM.md`.
- Tests are fixture-only and must not use external DNS, HTTP, mail, SSH, browser,
  proxy, or paid routes.
- Add new network providers with a saved, sanitized fixture and parser contract.
- Run the complete offline suite from the repository root with
  `/bin/zsh -f scripts/test-offline`.
- Focused validation uses `/usr/bin/ruby test/ip_quality_test.rb` or
  `/usr/bin/ruby test/clash_leaf_runner_test.rb`. The runtime entrypoint still
  uses `--disable-gems`; tests use the system-bundled `minitest` default gem.
- `README.md` is intentionally absent. Keep agent-operational rules here, provider
  contracts in `PROVIDERS.md`, provenance in `UPSTREAM.md`, and current state in
  `HANDOFF.md`.
