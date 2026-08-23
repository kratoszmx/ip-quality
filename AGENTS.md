# AGENTS.md

This directory owns a zsh-native, source-auditable IP reputation and quality
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

## Query policy

- Preserve per-source results; do not turn conflicting provider answers into an
  unexplained single truth value.
- Keep query scopes explicit: reputation, DNSBL, media/AI, mail, or full.
- Concurrency must be bounded and user-configurable. DNSBL may default to 50, but
  tests must prove that the configured cap is enforced.
- A provider failure, rate limit, schema change, or unavailable dependency is an
  `unknown` result, not a clean result.
- Default output masks the tested IP. Revealing it requires an explicit output
  option.
- The exact-leaf runner is restricted to `reputation`. Do not route DNSBL, mail,
  or other direct DNS/TCP tests through an HTTP-proxy environment and claim that
  they measured the leaf.

## Source map

- `ip-quality.zsh`: provider queries, aggregation, and report output.
- `bin/test-clash-leaf`: thin zsh exact-leaf entrypoint.
- `lib/safe_snapshot.rb`: the only subproject-common library; reusable verified
  local-file reads with no Clash or provider policy.
- `leaf_runner/`: cached-subscription catalog, exact-leaf extraction, CLI policy,
  loopback lifecycle, listener ownership proof, and cleanup.
- `providers/`: network-free, fixture-testable provider response parsers.
- `report/`: provider-aware terminal report rendering; provider scales must not be
  collapsed into one synthetic score.
- `ref/`: runtime reference data; `test/fixtures/`: sanitized test data.

## Development and validation

- This directory must not contain `.git/` or another nested repository.
- Preserve the upstream AGPL-3.0 license, commit identity, and modification notes
  in `UPSTREAM.md`.
- Tests are fixture-only and must not use external DNS, HTTP, mail, SSH, browser,
  proxy, or paid routes.
- Add new network providers with a saved, sanitized fixture and parser contract.
- Keep the root offline aggregate compatible with this directory.
- Focused offline validation runs through
  `scripts/offline-containment run ip-quality/test/ip_quality_test.rb` or
  `scripts/offline-containment run ip-quality/test/clash_leaf_runner_test.rb`
  from the repository root.
