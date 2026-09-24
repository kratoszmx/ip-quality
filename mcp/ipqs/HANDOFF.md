# IPQS handoff

Account and documentation checked 2026-09-24. Start with [AGENTS.md](AGENTS.md);
repository-wide status and validation live in [../../HANDOFF.md](../../HANDOFF.md).

## Current integration

IPQS moved from mcps to `ipquality/mcp/ipqs` on 2026-09-22, including its private
Chrome profile and support receipts. There is no forwarding package at the old
path. The MCP and reporter share `../../secrets/ipqs`; the byte-equal old key was
removed. Shared libraries still come directly from the sibling mcps repository.
External orchestration retained its existing check identities with updated paths.

On 2026-09-22 the sanitized account probe returned `authenticated`, and an
explicitly authorized reporter lookup returned official IPQS `ok`. This
supersedes the September 14–16 zero-allocation diagnosis as an active blocker.
It proves usability at that time; the cause of recovery and any support reply
are not established by the API result.

## Dashboard access

The September 24 v25 account audit verified usable API credits, restored login,
enabled TOTP after saving its bound seed/emergency code, and passed a real
challenge plus fresh-profile login. The proof profile was closed and removed;
the normal profile and API key remain. This documentation review did not repeat
those live actions.

The supported dashboard path remains retained headed Chrome; usage/lookups use
the official HTTP API. Independent HTTP/headless trials did not establish
dashboard authentication. Their exact outcomes and current recovery commands are
centralized in [../../MCP_AUTH.md](../../MCP_AUTH.md). Closing/restarting the
container lost usable authentication in an earlier experiment, so `auth:check`
retains it; this is observed behavior, not proof that other backends can never work.

The user authorized existing saved credentials on 2026-09-15. The continuing
IPQS account task may reuse that permission; a documentation/test task does not
itself call for login. Support messages and purchases need their own task intent.

Tool behavior is in [AGENTS.md](AGENTS.md); regression commands and coverage are
in [../../TESTING.md](../../TESTING.md).

## Historical support case

The earlier dashboard showed `0 / 0` and a duplicate-free-account restriction;
the account API accepted the key but reported no credits. This was the vendor's
classification, not proof of duplicate accounts or of its underlying cause.

One authorized support email was sent on 2026-09-16 at 19:36:24 +08:00 and
independently matched in Gmail Sent. [SUPPORT-REQUEST.md](SUPPORT-REQUEST.md)
preserves that exact message; private receipts remain under
`.state/support/20260916/`. Delivery/read and a human support reply were not
verified here. The external mail-watch identifier is `mail.ipqs-quota-20260916`;
its live status belongs to Supervisor, not this package. No follow-up is queued
by this handoff. The September 22 API recovery removes the old request to wait
for quota restoration.
