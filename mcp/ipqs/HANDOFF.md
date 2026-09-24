# IPQS handoff

Documentation reviewed 2026-09-24. The latest account checks below are dated
snapshots, not a new login or quota check. Start with [AGENTS.md](AGENTS.md);
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

The September 22 recovery identified an HTTP 200 login form at `/user/dashboard`
and restored authentication with one authorized saved-credential submission.
Fresh same-origin GETs then passed through a retained background headed Chrome.
Closing/restarting that container lost usable authentication in one experiment;
the default `auth:check` now retains and reuses it. The explicit `--headless`
experiment returned 403 and was not adopted.

The user authorized existing saved credentials on 2026-09-15. The continuing
IPQS account task may reuse that permission; a documentation/test task does not
itself call for login. Support messages and purchases need their own task intent.

Use the official API for usage/lookups, `mode=text` for redacted dashboard HTML,
and `mode=controls` for dynamic values or form controls. Text mode does not prove
external-CSS visibility or browserless login. Browser commands run compiled
JavaScript because direct `tsx` execution injected `__name` helpers into
Playwright callbacks. Commands and regression coverage are in
[../../TESTING.md](../../TESTING.md).

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
