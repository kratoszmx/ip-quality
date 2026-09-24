# Services and process lifetime

This project installs no daemon or scheduled job. Both CLI entrypoints run on
demand and finish with the report. Account MCP servers use stdio under their
client's process lifetime; dedicated Chrome containers can outlive those servers.
External Supervisor checks and mail watches are owned outside this repository.

| Mode | Processes and lifetime |
| --- | --- |
| Reporter; direct or specific-IP runner route | Runs the reporter; starts no Mihomo |
| Exact-leaf plan or name listing | Reads local inputs; starts no Mihomo |
| `--config-test-only` | Runs an existing Mihomo with `-t`, then exits; no report lookup or persistent proxy listener |
| Confirmed exact-leaf report | Starts a private Mihomo on a random `127.0.0.1` port, verifies listener ownership, then runs the reporter through it |
| `mcp/ipqs` | Stdio account/API tools; dashboard work may retain its own Chrome on CDP 19453 |
| `mcp/provider-accounts` | Stdio account reads use HTTP without Chrome. Explicit setup/recovery uses headless ipapi / headed Cloudflare on CDP 19503/19504 |

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

## Account MCP startup and shutdown

From the worktree root, with the dependencies described in
[TESTING.md](TESTING.md):

| Package | Prepare | Start for an MCP client | Offline check |
| --- | --- | --- | --- |
| IPQS | `npm --prefix mcp/ipqs run build` | `npm --prefix mcp/ipqs start` | `npm --prefix mcp/ipqs run check` |
| Provider accounts | No build step | `npm --prefix mcp/provider-accounts start` | `npm --prefix mcp/provider-accounts test` |

These are stdio servers, not interactive menus or HTTP endpoints. Closing the
client transport, or Ctrl-C when launched in a terminal, stops the server.
Browser lifetime is separate:

- IPQS `ipqs_close_browser` closes that server's active CDP session and stops
  Chrome only if the session launched it with shutdown ownership. An attached
  Chrome can remain open. `auth:check` deliberately retains its background
  headed container and is a live dashboard check.
- Provider-account HTTP reads start no browser. Explicit browser tools detach
  after each operation and retain their Chrome (headless ipapi by default).
  They expose no browser-shutdown tool. When authorized maintenance needs to
  close it, connect through the package's shared browser helper, verify the
  expected private profile with `verifyChromeProfileBinding`, then send
  `Browser.close` only to that owned container. Keep its `.state/` login files.

[MCP_AUTH.md](MCP_AUTH.md) records the tested fallback decisions. A failed HTTP
identity read never silently opens a browser or retries with credentials.

For a browser started through a temporary proxy, close the owned browser before
stopping that proxy so it cannot retain a dead route. Loopback CDP traffic stays
direct; `PROVIDER_ACCOUNTS_PROXY` configures the account browser's external route.
Use `PROVIDER_ACCOUNTS_PROXY=DIRECT` for explicit direct browser/API access;
clearing environment variables alone leaves Chrome's macOS system proxy active.
An existing browser with different routing arguments is rejected before account
actions, and only its verified owner should close it before changing routes.

## Network-free checks

There is no resident health endpoint or restart command. For a network-free
check, run `/usr/bin/ruby --disable-gems bin/test-clash-leaf --direct` and
`/bin/zsh -f scripts/test-offline` from the worktree root. These validate plans
and fixture behavior, not current provider availability or real-node health.
