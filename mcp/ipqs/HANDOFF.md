# IPQS handoff

Reviewed 2026-10-14. Use [AGENTS.md](AGENTS.md) for package tools and
[../../HANDOFF.md](../../HANDOFF.md) for current reporter behavior and validation.

## Maintained access

Official usage/lookups use the private API key over HTTP. Dashboard reads and
saved-login recovery use retained headed Chrome/CDP; background/hidden windows
are still headed Chrome. The September 24 audit restored login, enabled TOTP,
and verified a real challenge plus fresh-profile login. Independent HTTP and
headless trials did not establish dashboard authentication; that observation
is not proof that these methods can never work.

Modes, dates, recovery tools and 2FA evidence are centralized in
[../../MCP_AUTH.md](../../MCP_AUTH.md). A code/documentation audit does not repeat
login or enrollment. API credentials are shared with the reporter through the
private path indexed in [../../CREDENTIALS.md](../../CREDENTIALS.md).

## Open transport case

The October 10–11 ATT probes failed before HTTP at TLS while the same key/target
worked through other routes. The reporter now recovers eligible target lookups
through its direct IPv4 fallback and keeps the original TLS failure visible.
That reporter policy does not change this MCP's HTTP/browser route.

The user-authorized [TLS inquiry](SUPPORT-TLS-20261010.md) was sent October 10
and independently verified in Gmail Sent. The last mailbox check, October 11,
found no reply; no claim is made about today's mailbox state. A specific
provider-side cause remains unconfirmed. Exact messages/receipts are private.

The old September zero-credit case was superseded by successful account/API
checks from September 22 onward. Its obsolete public message copy was removed;
private sent-message receipts remain under `.state/support/20260916/`. No
follow-up, resend or new mail-watch task is implied by this maintenance.

The package has no old-path forwarding MCP. Shared HTTP/Chrome/TOTP primitives
come directly from the sibling myutils/mcps libraries; IPQS account, form,
identity and quota policy stay here. [../../TESTING.md](../../TESTING.md) owns
regression commands; [../../SERVICES.md](../../SERVICES.md) owns process lifetime.
