# Current handoff

Last documentation and offline validation: 2026-09-16, Asia/Shanghai.

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

The documentation audit retains API contracts in
[COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md), adds the explicit absence of resident
services and temporary-process ownership in [SERVICES.md](SERVICES.md), and keeps
usage/document routing in [AGENTS.md](AGENTS.md). There is no project-specific
skill or nested project documentation. No pending code or documentation blocker
was identified; no runtime code, tests, credentials, or live Clash state changed
in this documentation pass.

## Validation evidence

The complete fixture-only suite passed 65 runs / 908 assertions, with zero
failures, errors, or skips: common helpers 3 / 29; reporter 40 / 705; route runner
22 / 174. Syntax, plan/help, local documentation links, and `git diff --check`
also passed. The self-test validated all 422 vendored DNSBL entries.

Canonical checks from the worktree root:

```text
/bin/zsh -f scripts/test-offline
/bin/zsh -f bin/ip-quality --self-test
git diff --check
```

Focused suites and plan/help commands are in [AGENTS.md](AGENTS.md). Coverage
includes provider failure independence, private credentials, typed/masked
output, DNSBL bounds/results, SMTP behavior, shared text and snapshot contracts,
proxy removal, exact-leaf dependencies, listener ownership, and signal cleanup.
Tests use fixtures and fake processes; no live provider, external DNS, mail,
paid-route, or real-node measurement was performed. Git remote checks are
separate from those measurement boundaries.
