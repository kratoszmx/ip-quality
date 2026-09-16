# Current handoff

Last shared-library maintenance: 2026-09-16, Asia/Shanghai.

## Repository state

- Worktree: `/Users/zmx/Projects/projects/ipquality`
- Maintained branch: `main`; upstream: `github-kratoszmx/main`
- Reporter version: `v2026-09-16-standalone.14`
- Primary remote: `https://github.com/kratoszmx/ip-quality.git`
- Backup remote: `https://github.com/kratosbackup/ipquality.git`

This is the standalone worktree. The two GitHub remotes are its only configured
remotes; the former local/parent-project routing is absent. Authenticated
`ls-remote --heads` reads reached both remotes on 2026-09-16 using account-specific
private credential files and the existing HTTP proxy at `127.0.0.1:7897` through
command-scoped Git settings. No remote configuration or live Clash setting was
changed. Local tracking refs alone are not remote synchronization evidence.

## Shared-library handoff

The `coding-old` history, current project rules, and clean starting worktree
were reviewed before this change. The production common library now lives in
`common/`; its APIs and callers are documented in
[COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md).

- Existing provider-value helpers, safe file snapshots, and proxy-environment
  overrides moved to the common library with direct imports.
- Profile/catalog metadata now uses one bounded printable-text predicate,
  including invalid-encoding rejection.
- Header/table display widths share the existing character-based approximation.
  ANSI cleanup is shared by value normalization and plain report output, with
  explicit whitespace preservation for layout.
- `bin/test-clash-leaf` now contains the Ruby command itself. Execute it directly
  or with `/usr/bin/ruby --disable-gems`; the former zsh forwarding file and
  `leaf_runner/command.rb` are gone. All route options remain available.
- The stdout forwarding helper and former shared-library paths were removed.
  File-output policy, provider schemas, and Mihomo lifecycle state remain with
  their owning components.
- `myutils` was checked through its current API documentation. It exposes Python
  imports, so this change adds no cross-runtime subprocess or dependency.

The five maintained documents have distinct jobs: [AGENTS.md](AGENTS.md) for
operation and source routing, [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md) for
shared APIs, [PROVIDERS.md](PROVIDERS.md) for source contracts/disclosure,
[UPSTREAM.md](UPSTREAM.md) for provenance, and this handoff for current evidence.
There is no project-specific skill or README.

## Validation evidence

The updated fixture-only suite passed 65 runs / 906 assertions on 2026-09-16,
with zero failures, errors, or skips: common helpers 3 / 29; reporter 40 / 703;
route runner 22 / 174. The starting baseline was 58 runs / 839 assertions.
Shell/Ruby syntax checks, disclosure/help commands, and `git diff --check` also
passed. The self-test validated all 422 vendored DNSBL entries.

Canonical commands from the worktree root:

```text
/bin/zsh -f scripts/test-offline
/bin/zsh -f bin/ip-quality --self-test
/bin/zsh -f bin/ip-quality
/bin/zsh -f bin/ip-quality --help
/usr/bin/ruby --disable-gems bin/test-clash-leaf --help
/usr/bin/ruby --disable-gems bin/test-clash-leaf --direct
git diff --check
```

Coverage retains provider failure independence, private credentials, typed and
masked output, DNSBL bounds/per-zone results, SMTP behavior, direct/specific-IP
proxy removal, exact-leaf dependencies, listener ownership, and cleanup after
failure/signals. New contracts cover shared text/metadata boundaries, verified
file reads, and execution of the direct Ruby entrypoint outside the worktree.

Tests use fixtures and fake child processes. No live provider, external DNS,
mail, paid-route, or real-node measurement was performed in this maintenance
pass. Git remote verification is separate from those measurement boundaries.
