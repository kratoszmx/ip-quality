# Services and process lifetime

This project runs no daemon, launchd job or cron entry. Both CLI entrypoints run
on demand and exit with the report; the account MCP servers are stdio processes
that live as long as their client. Supervisor owns the only scheduled job, the
weekly offline test, outside this repository.

## Processes a run can start

| Mode | Processes and lifetime |
| --- | --- |
| Reporter; direct or specific-IP runner route | Runs `bin/ip-quality` once; starts no Mihomo |
| DB-IP daily-limit recovery in an IPv4 egress report | One Node process imports myutils/web-text and reads the exact public IP page in fresh hidden Chrome; 30-second read budget, operation lease 19606 and dynamic loopback CDP; closes on completion/cancellation |
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

DB-IP's optional browser uses an owned temporary profile under the system
temporary directory, no saved login/cookies, no persistent cache and no GUI.
The shared worker owns browser/profile cleanup; the provider accepts the label
only when cleanup is confirmed. It removes only its empty temporary parent.
An unverified cleanup leaves the observation unknown. It preserves the HTTPS
proxy selected by the runner, or explicitly disables proxies for direct mode.
Unsupported interface/bypass settings and IPv6 targets skip this fallback.

## Account MCP start and stop

| Package | Prepare | Start for an MCP client | Offline check |
| --- | --- | --- | --- |
| IPQS | `npm --prefix mcp/ipqs run build` | `npm --prefix mcp/ipqs start` | `npm --prefix mcp/ipqs run check` |
| Provider accounts | None | `npm --prefix mcp/provider-accounts start` | `npm --prefix mcp/provider-accounts test` |

Every page is a hidden tab of the one dedicated Chrome on the shared profile,
the text browser's saved profile, which holds these accounts' logins (since
2026-11-21). myutils starts that Chrome hidden when none runs (macOS GUI session
only; elsewhere the launch is refused and reported as browser unavailable) and
closes it after 30 idle minutes; neither MCP launches or stops a Chrome of its own.

- IPQS `ipqs_close_browser` releases the tab this server kept and its attachment;
  `auth:check` opens no page. Dashboard control reads close their own tab.
- `provider_account_close_browsers` releases the provider server's kept tab.
  Multi-step setup tools continue on the tab the opening call kept, for the same
  provider, until it is released or closes after 30 idle minutes. Server
  shutdown releases it too.
- A window of the same Chrome opens only through an explicitly requested
  `visible=true` or the manual IPQS login script. No failed HTTP or hidden
  operation opens a window automatically.
- The former per-MCP profiles and session files (`mcp/ipqs/.state/`,
  `mcp/provider-accounts/.state/`) stay on disk untouched as rollback data until
  a separate deletion; nothing starts a browser on them.

An explicitly requested manual-account handoff may instead use myutils
`openRealChrome` with a dedicated persistent profile and no CDP. The user owns
that visible browser's remaining lifetime. The October 27 ipapi registration
profile is listed in [CREDENTIALS.md](CREDENTIALS.md#account-mcp-files); its GUI
process was closed after activation on October 28. Retaining a profile alone
proves neither signup nor authentication. Keep myutils'
`requireUserKeychainSession` protection enabled for any persistent-profile
recovery. See the [saved-login audit](MCP.md#saved-login-protection).

## External weekly check

| Supervisor ID | Runs |
| --- | --- |
| `test.ipquality.test-offline` | `/bin/zsh -f scripts/test-offline` from the project root: reporter, route runner and both account MCPs |

The schedule belongs to `/Users/zmx/Projects/supervisor`
(`supervisor/integrations/testing.py`); check it with `inventory` there. No IPQS
account probe or API-expiry check is scheduled for this project; the manual
probes in [MCP.md](MCP.md) are not monitoring.

The finite IPQS support-reply watch `mail.ipqs-tls-reply-20261026` ended: on
2026-11-19 `mail-watch status` reported `replied` (reply found 2026-11-02 09:00
HKT), so nothing project-related is still watched. See the
[IPQS support record](mcp/ipqs/SUPPORT-TLS-20261010.md).

## Health checks

There is no resident endpoint or restart command. Network-free checks:
`/usr/bin/ruby --disable-gems bin/ip-quality-route --direct` (prints a plan) and
`/bin/zsh -f scripts/test-offline`. They validate plans and fixtures, not
current provider availability or real-node health.
