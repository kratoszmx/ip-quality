# Current handoff

Last documentation and offline validation: 2026-09-17, Asia/Shanghai.

## Current state

- Worktree: `/Users/zmx/Projects/projects/ipquality`; branch: `main`.
- Reporter version: `v2026-09-16-standalone.14`.
- Primary/upstream: `github-kratoszmx/main` at `https://github.com/kratoszmx/ip-quality.git`.
- Backup: `github-kratosbackup` at `https://github.com/kratosbackup/ipquality.git`.

These are the only configured remotes. Authenticated reads reached both on
2026-09-16 using their account-specific private credential files and the existing
HTTP proxy at `127.0.0.1:7897` through command-scoped Git settings. Local tracking
refs alone do not establish remote synchronization.

The shared-library refactor is complete: production helpers live in `common/`,
and `bin/test-clash-leaf` is now the Ruby command itself. Execute it directly or
with `/usr/bin/ruby --disable-gems`; older zsh runner commands are obsolete.
The reporter and test-suite entrypoints remain zsh. Former forwarding files and
shared-library paths have been removed; no compatibility layer remains.

The test-maintenance pass split the reporter tests into CLI, provider, report,
and repository suites with a small shared fixture helper. The canonical runner
discovers top-level suites and reports one aggregate result. Reporter CLI tests
use temporary source copies, isolated credential paths, and network-command
tripwires; source checks exclude private/user-generated directories. Behavioral
checks now cover report-file safety/formats, DNSBL resolver-policy errors,
missing dependencies, zero-credit lookup prevention, exact-leaf proxy forwarding,
and malformed YAML. Existing route/signal cleanup checks remain.

The follow-up audit fixed a lifecycle-test isolation gap: success and signal
cases share a child-process launcher that supplies an explicit private
`temp_parent`. Both check the workspace path actually received by fake Mihomo,
so an empty but unused fixture directory cannot produce a false cleanup pass.

[TESTING.md](TESTING.md) owns prerequisites, focused commands, and test boundaries.
API contracts remain in [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md), process
ownership in [SERVICES.md](SERVICES.md), and usage in [AGENTS.md](AGENTS.md).
There is no project-specific skill or nested project documentation. No production
code, credentials, or live Clash state changed in this test-maintenance pass.

## Validation evidence

The complete fixture-only suite passed 68 runs / 1,043 assertions, with zero
failures, errors, or skips (seed 26917). All 14 Ruby and 11 zsh source/test files
passed syntax checks; local documentation file links and `git diff --check`
also passed. The included self-test validated all 422 vendored DNSBL entries.
A child-only mutation disabling workspace removal failed the actual-workspace
assertion as expected, confirming the cleanup check detects that regression.

Canonical checks from the worktree root:

```text
/bin/zsh -f scripts/test-offline
git diff --check
```

Focused suites are in [TESTING.md](TESTING.md); plan/help commands are in
[AGENTS.md](AGENTS.md). Coverage
includes provider failure independence, private credentials, typed/masked
output, DNSBL bounds/results, SMTP behavior, shared text and snapshot contracts,
proxy removal, exact-leaf dependencies, listener ownership, and signal cleanup.
Tests use fixtures and fake processes; no live provider, external DNS, mail,
paid-route, or real-node measurement was performed. Git remote checks are
separate from those measurement boundaries.
