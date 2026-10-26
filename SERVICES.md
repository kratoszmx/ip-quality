# Services and process lifetime

This project runs no daemon, launchd job or cron entry. Both CLI entrypoints run
on demand and exit with the report; the account MCP servers are stdio processes
that live as long as their client. The only scheduled work is Supervisor's
weekly offline test, owned outside this repository.

## Processes a run can start

| Mode | Processes and lifetime |
| --- | --- |
| Reporter; direct, specific-IP or prefix-sample runner route | Runs `bin/ip-quality` (one at a time for prefix samples); starts no Mihomo |
| Exact-leaf plan or name listing | Reads local inputs only |
| `--config-test-only` | Runs Mihomo with `-t` on a rendered private profile, then exits; no listener or lookup |
| Confirmed exact-leaf report | Starts a private Mihomo on a random `127.0.0.1` port, verifies it owns the listener, runs the reporter through it, then stops it |
| `mcp/ipqs` | Stdio server; auth checks use HTTP. Dashboard/login tools use owned native hidden Chrome on a dynamic loopback CDP port |
| `mcp/provider-accounts` | Stdio server; account reads use HTTP. Explicit login/setup tools retain owned native hidden Chrome on dynamic loopback ports; operation leases remain 19603/19604/19605 |

Ctrl-C, HUP or TERM stops the runner, its reporter and its owned Mihomo; success,
failure and handled interruption remove the private workspace. A later run
scavenges a workspace left by a dead owner and keeps live-owner workspaces and
`-o` reports. Lifecycle code: `bin/ip-quality-route` and
`runner/isolated_mihomo_session.rb`. The installed Clash Verge service, active
profile and subscription cache are external; this project never starts, stops,
reloads or rewrites them.

## Account MCP start and stop

| Package | Prepare | Start for an MCP client | Offline check |
| --- | --- | --- | --- |
| IPQS | `npm --prefix mcp/ipqs run build` | `npm --prefix mcp/ipqs start` | `npm --prefix mcp/ipqs run check` |
| Provider accounts | None | `npm --prefix mcp/provider-accounts start` | `npm --prefix mcp/provider-accounts test` |

Browsers are owned by myutils' native Chrome lifecycle worker, with a 30-minute
maximum lifetime and cleanup on controller exit. Their fresh profiles are
removed on shutdown; owner-only HTTP/pending login files persist separately:

- IPQS `ipqs_close_browser` stops its active owned browser; `auth:check` opens
  none. Temporary dashboard reads close their browser after completion.
- `provider_account_close_browsers` closes the provider server's owned browser
  sessions. Multi-step setup tools reuse the same session until closed, expired,
  or explicitly switched between routes/display modes.
- A GUI is available only through an explicitly requested `visible=true` or
  the manual IPQS login script. No failed HTTP/headless/hidden operation opens
  a window automatically. Old persistent profiles are retained as private
  recovery data and are not the default runtime browser.
- Close a browser started through a temporary proxy before stopping that proxy,
  and close it before changing its route. Routing details:
  [provider-accounts guide](mcp/provider-accounts/AGENTS.md#private-files-and-lifetime).

## External weekly check

| Supervisor ID | Runs |
| --- | --- |
| `test.ipquality.test-offline` | `/bin/zsh -f scripts/test-offline` from the project root: reporter, route runner and both account MCPs |

The schedule belongs to `/Users/zmx/Projects/supervisor`
(`supervisor/integrations/testing.py`). As of 2026-10-23 it registers no IPQS
account probe or API-expiry check for this project; manual probes in
[MCP.md](MCP.md) are not scheduled monitoring.

## Health checks

There is no resident endpoint or restart command. Network-free checks:
`/usr/bin/ruby --disable-gems bin/ip-quality-route --direct` (prints a plan) and
`/bin/zsh -f scripts/test-offline`. They validate plans and fixtures, not
current provider availability or real-node health.
