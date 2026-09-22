# Services and process lifetime

This project owns no persistent service, daemon, scheduled job, or service
installation. Both CLI entrypoints run on demand and finish with the report.
Account MCP servers use stdio and run only while their client is connected.

| Mode | Processes and lifetime |
| --- | --- |
| Reporter; direct or specific-IP runner route | Runs the reporter; starts no Mihomo |
| Exact-leaf plan or name listing | Reads local inputs; starts no Mihomo |
| `--config-test-only` | Runs an existing Mihomo with `-t`, then exits; no report lookup or persistent proxy listener |
| Confirmed exact-leaf report | Starts a private Mihomo on a random `127.0.0.1` port, verifies listener ownership, then runs the reporter through it |
| `mcp/ipqs` | Stdio account/API tools; dashboard work may retain its own Chrome on CDP 19453 |
| `mcp/provider-accounts` | Stdio free-account tools; dedicated ipapi/Cloudflare Chrome profiles use CDP 19503/19504 |

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

Account browsers retain private login state under their package's ignored
`.state/` directory. A client disconnect detaches from a retained Chrome rather
than deleting account state. Closing a browser first verifies its profile binding;
only the owned browser receives `Browser.close`. Registration through a temporary
ATT proxy closes the owned signup browser before the temporary Mihomo exits, so
it cannot retain a dead proxy route. Loopback CDP traffic must remain direct;
`PROVIDER_ACCOUNTS_PROXY` configures the account browser's external route.

There is no resident health endpoint or restart command. For a network-free
check, run `/usr/bin/ruby --disable-gems bin/test-clash-leaf --direct` and
`/bin/zsh -f scripts/test-offline` from the worktree root. These validate plans
and fixture behavior, not current provider availability or real-node health.
