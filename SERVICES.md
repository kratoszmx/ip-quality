# Services and process lifetime

This project owns no persistent service, daemon, scheduled job, or service
installation. Both CLI entrypoints run on demand and finish with the report.

| Mode | Processes and lifetime |
| --- | --- |
| Reporter; direct or specific-IP runner route | Runs the reporter; starts no Mihomo |
| Exact-leaf plan or name listing | Reads local inputs; starts no Mihomo |
| `--config-test-only` | Runs an existing Mihomo with `-t`, then exits; no report lookup or persistent proxy listener |
| Confirmed exact-leaf report | Starts a private Mihomo on a random `127.0.0.1` port, verifies listener ownership, then runs the reporter through it |

Use the route commands in [AGENTS.md](AGENTS.md#choose-a-route). During a live
run, Ctrl-C stops the runner; handled HUP/TERM signals also stop its reporter
and owned Mihomo children. Success, ordinary failure, and handled interruption
remove the private workspace. A later run can scavenge a dead-owner workspace
left by an unhandled process/host failure; live-owner workspaces and `-o` reports
are retained. Lifecycle code is in `bin/test-clash-leaf` and
`leaf_runner/isolated_mihomo_session.rb`.

The installed Clash Verge service, active profile, and subscription cache are
external dependencies. This project does not start, stop, restart, or rewrite
them; its temporary proxy is separate.

There is no resident health endpoint or restart command. For a network-free
check, run `/usr/bin/ruby --disable-gems bin/test-clash-leaf --direct` and
`/bin/zsh -f scripts/test-offline` from the worktree root. These validate plans
and fixture behavior, not current provider availability or real-node health.
