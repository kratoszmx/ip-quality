# Current handoff

Last offline documentation audit: 2026-09-16, Asia/Shanghai.

## Repository state

- Worktree: `/Users/zmx/Projects/projects/ipquality`
- Maintained branch: `main`; upstream: `github-kratoszmx/main`
- Reporter version: `v2026-08-27-standalone.13`
- Configured primary remote: `https://github.com/kratoszmx/ip-quality.git`
- Configured backup remote: `https://github.com/kratosbackup/ipquality.git`

This is the standalone worktree; the former parent-project routing hooks are
absent. These are the only configured remotes. Configuration and local tracking
refs do not establish current remote availability or synchronization.

Authenticated access to both remotes was verified on 2026-09-16 using each
account's private credential file. Direct GitHub access timed out; the existing
local HTTP proxy at `127.0.0.1:7897` worked with command-scoped Git settings.
No remote configuration or live Clash setting was changed.

## Documentation handoff

The `文檔維護-old` task was reviewed alongside the current code and tests.
The maintained documentation remains four files, with no project-specific
skill, nested project documentation, or README:

- [AGENTS.md](AGENTS.md) now owns stable usage, route selection, dependencies,
  output options, safety guidance, and test entrypoints.
- [PROVIDERS.md](PROVIDERS.md) owns provider contracts and result interpretation.
- [UPSTREAM.md](UPSTREAM.md) preserves source identity, input hashes, license
  continuity, and the consolidated material modification notice.
- This file records current validation and outstanding handoff information.

Repeated usage/provider descriptions have been removed from this handoff.
No runtime code, tests, credentials, or live Clash state changed in this pass.

## Validation evidence

The following passed from the repository root on 2026-09-16 without external
provider, DNS, mail, or proxy queries:

```text
/bin/zsh -f -c 'for file in bin/ip-quality bin/test-clash-leaf scripts/test-offline providers/*.zsh report/*.zsh; do /bin/zsh -n "$file" || exit $?; done'
/bin/zsh -f -c 'for file in leaf_runner/*.rb; do /usr/bin/ruby --disable-gems -c "$file" || exit $?; done'
/bin/zsh -f scripts/test-offline
/bin/zsh -f bin/ip-quality --self-test
/bin/zsh -f bin/ip-quality
/bin/zsh -f bin/ip-quality --help
/bin/zsh -f bin/test-clash-leaf --help
/bin/zsh -f bin/test-clash-leaf --direct
git diff --check
```

The fixture-only suite passed 58 runs / 839 assertions, with zero failures,
errors, or skips: reporter 38 / 687; route runner 20 / 152. The self-test validated
422 vendored DNSBL entries. `LICENSE` and `ref/iso3166.json` still match the
upstream SHA-256 hashes recorded in [UPSTREAM.md](UPSTREAM.md).

Coverage includes network gating, all scope plans, CLI validation, provider
failure independence, private credentials, typed/masked output, DNSBL bounds
and per-zone results, SMTP behavior, direct/specific-IP proxy removal,
exact-leaf dependencies, listener ownership, and cleanup after failure/signals.
The tests use fixtures and fake processes; they do not establish current
third-party availability, real-node connectivity, or remote Git synchronization.
Remote access was checked separately as described above.

No code, documentation, or offline-test blocker was found. Start future work
with [AGENTS.md](AGENTS.md); use a newly authorized live check only when current
network evidence is needed.
