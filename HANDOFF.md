# IP quality standalone handoff

Last validated: 2026-08-23, Asia/Shanghai.

## Repository identity

- Worktree: `/Users/zmx/Projects/projects/ipquality`
- Branch: `main` only
- Local origin: `/Users/zmx/gitrepos/ipquality.git`
- USB mirror: `/Volumes/USB/gitreposbak/ipquality.git`
- Online primary target: `https://github.com/kratoszmx/ipquality.git`
- Online backup: `https://github.com/kratosbackup/ipquality.git` (private)

The `kratosbackup/ipquality` private repository was created successfully. The
configured `kratoszmx/ipquality` target does not yet exist: GitHub rejected both
REST and GraphQL creation with `Resource not accessible by personal access
token`. The stored main-account token can authenticate as `kratoszmx`, but it
does not have repository-creation authority. Never replace the target silently
or place a token in this repository's remote URLs or Git configuration.
The `usb` remote uses `scripts/git-receive-pack-usb-clean`, an exact-target
receive wrapper that runs macOS `dot_clean` after each receive attempt so
AppleDouble sidecars cannot remain as invalid Git refs or object names.

## Extracted history

The complete former `network-manager/ip-quality/` path was extracted with
`git subtree split --prefix=ip-quality main`. The standalone history is:

- `7d9d1f8c20e04f99277664426482f73890ecc379` — original parent commit
  `c45a4c22a1296443d41b8bec30807698cad1c56e`
- `835621c3852338669993992f80cdc0f38a6e0a8f` — original parent commit
  `69acba677c662ce21ba3f5c756312dc0d3a6dc36`
- `2879887b17f41d29ab253efdd179129cf5ea8fe7` — original parent commit
  `b16a9fbb96159e4a04a72c1a05a2a725cb99cd2f`

The extraction preserves authorship, timestamps, messages, and file history
without retaining parent-repository files or nested Git metadata.

## Standalone structure and decisions

- The reporter moved from the root to `bin/ip-quality`; no compatibility wrapper
  remains.
- Exact-leaf runtime code is under `leaf_runner/`; provider parsers, terminal
  rendering, references, fixtures, and tests have their own directories.
- The former generic-looking `lib/safe_snapshot.rb` is now the project-specific
  `leaf_runner/safe_snapshot.rb`.
- The obsolete README is removed under the local AI-native documentation policy.
  Operational truth is in `AGENTS.md`, provider contracts in `PROVIDERS.md`, and
  provenance in `UPSTREAM.md`.
- `/Users/zmx/Projects/myutils` was inspected. Its public APIs are Python APIs;
  this source-auditable zsh/system-Ruby runtime has no valid reusable dependency.
  Project-specific process, cache, provider, and terminal-table policy remains
  here instead of being forced into `myutils`.

## Safety and output behavior

- Default execution prints a disclosure plan and performs no network lookup.
- Live provider access requires the exact `--confirm-network-lookup` gate.
- Terminal reputation sections are matrices: providers across the top and
  dimensions down the left. Safe boolean factors are green, risk factors are red,
  and unknown values are purple. Unknown never means low risk.
- JSON is built with `jq --arg` bindings rather than source interpolation, and
  keeps booleans, numbers, and null values typed.
- User-selected output paths use an exclusive, no-follow file descriptor; existing
  paths and symlinks are rejected.
- The runner deletes its private Mihomo workspace on success, error, and interrupt;
  TERM/HUP also terminate and reap the reporter process group. A later run securely
  scavenges a dead-owner workspace left by unavoidable SIGKILL or host failure.
- Clash Verge subscription caches are external read-only inputs and are never
  deleted. User-requested report files are outputs, not caches.
- The basic-information section is labeled as a Check.Place upstream relay whose
  payload is labeled MaxMind. This repository does not claim to own a local `.mmdb`
  or an official MaxMind subscription.
- Only the implemented `cn` and `en` report languages are advertised.

## Validated commands

Run from the repository root:

```text
/bin/zsh -n bin/ip-quality bin/test-clash-leaf scripts/test-offline providers/*.zsh report/*.zsh
/bin/sh -n scripts/git-receive-pack-usb-clean
/usr/bin/ruby -c leaf_runner/command.rb
/usr/bin/ruby -c leaf_runner/isolated_mihomo_session.rb
/usr/bin/ruby -c leaf_runner/safe_snapshot.rb
/bin/zsh -f scripts/test-offline
/bin/zsh -f bin/ip-quality --self-test
```

The full offline suite currently has 33 runs and 412 assertions. A read-only
probe of the real Clash Verge cache also resolved a remote subscription and an
exact inline leaf, then passed Mihomo `-t` without starting a listener or making
an IP-provider lookup. Afterward, the project workspace residue count was zero in
the preferred private temporary parent, macOS `TMPDIR`, and `/tmp`.

## Completed parent extraction

The original `network-manager/ip-quality/` subtree and its explicit root routing
entries were removed in parent commit
`e88a5c48ebd3dadea065a2d361f39fc9d5bdf793` (`refactor: extract IP quality
project`). That commit passed the complete parent offline aggregate in a clean,
detached worktree and was pushed to both:

- `/Users/zmx/gitrepos/network-manager.git`
- `/Volumes/USB/gitreposbak/network-manager.git`

Both parent remotes resolve `refs/heads/main` to the same extraction commit. The
current parent tree has no `ip-quality/` directory and no active `ip-quality`,
`test-clash-leaf`, or `ip_quality` routing reference. Historical parent commits
remain ordinary Git recovery evidence; all maintained code now lives here.
