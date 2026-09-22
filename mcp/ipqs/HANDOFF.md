# IPQS handoff

## 2026-09-22 migration into IPQuality

This package, its private Chrome profile and support receipts moved from mcps
to `/Users/zmx/Projects/projects/ipquality/mcp/ipqs`. It directly reuses the sibling
mcps shared libraries and the reporter's flat `../../secrets/ipqs` key. There is
no forwarding package at the old path. The relocated account probe and browser
authentication check both passed, and a direct reputation report completed its
official IPQS lookup. The old duplicated key was byte-equal and removed.
The offline build, 22 tests and static doctor passed after relocation. Supervisor
and mcps discovery retain their existing check identities with updated paths.

## 2026-09-22 dashboard auth and saved-credential recovery

The dashboard returned HTTP 200 with the real login form at /user/dashboard; the old path-only classifier incorrectly called this unknown. The regression now identifies it as login-required. One explicitly authorized saved-credential submission restored the dashboard; no human verification or account setting change was needed. Fresh same-origin HTTP (cache: no-store) through the retained headed/background container and the official API both passed. A later closed-container experiment lost usable browser authentication and was recovered with one saved-credential submission; the query now retains/reuses the proven container. The headless dashboard experiment returned 403 even after login, so it was not adopted: auth:check retains/reuses a background headed container, and --headless is an explicit experiment without automatic replay. Task-scoped HTTPS_PROXY/HTTP_PROXY are accepted after the existing credential-free proxy validation.

## Current live recheck — 2026-09-22

The earlier `0 / 0` and `authenticated_without_credits` evidence remains a
historical snapshot. A fresh bounded recheck now succeeds: the sanitized
account probe returned `authenticated`, and `/Users/zmx/Projects/projects/ipquality`
returned IPQS `ok` from the official API with a fraud score of **100** for the
current IPv4 route. The reporter therefore completed its IPQS quota preflight
and lookup; this is current API usability evidence, not a claim that the old
dashboard restriction never existed.

The IPQS MCP `npm run check` passed its 20 offline tests and static doctor. The
`ipquality` fixture suite passed 71 runs / 1,074 assertions and its worktree
remained clean. No key, browser profile, dashboard setting, or live Codex
configuration was changed. The reputation lookup was the one explicitly
confirmed live lookup in this recheck; automatic retries remain disabled.

Updated: 2026-09-16, Asia/Shanghai. Continuing the former `ipqs-mcp-old` work.

## Current account diagnosis

- The user explicitly gave standing permission to use the existing account credentials on 2026-09-15: `永遠允許使用帳密`. This continuing IPQS task may reuse that permission; do not request it again for ordinary saved login. External support messages and purchases still need their own task intent.
- One saved-credential submission succeeded. The dedicated Chrome profile retained login, with no secondary-verification blocker. Credential values and session material were neither printed nor exported.
- Live dashboard evidence at 2026-09-14 17:43 UTC showed `0 / 0`, the explicit duplicate-free-account restriction, and a support-review route for a possible error. This establishes the vendor's classification; it does not prove that the user actually created duplicate accounts or establish which signal caused the classification.
- The official account API returned HTTP 200 and `authenticated_without_credits`. The current fixed classifier verifies HTTP status before accepting success/quota messages.
- `ipquality` and this MCP read the same usable credential; comparison was performed in memory, without displaying the key. No key replacement was needed.
- A live `/bin/zsh -f bin/ip-quality --confirm-network-lookup --scope reputation -4 -j` in `/Users/zmx/Projects/projects/ipquality` returned IPQS `official_insufficient_credits`, `Source=official_api`, and no IPQS score. Its quota preflight skipped the IPQS reputation lookup. Check.Place relay sources independently returned `cloudflare_blocked`; Ipregistry returned `ok`. No code in that repository was changed.

## Resolution

Published normal Free allocation was rechecked: 1,000 monthly lookups and 35 daily lookups. Current references:

- https://www.ipqualityscore.com/plans
- https://www.ipqualityscore.com/terms-of-service (free account limitations, section 17)
- https://www.ipqualityscore.com/documentation/account-management/usage

The old `/documentation/usage/overview` URL returned 404; use the current usage reference above.

Ask IPQS to review the duplicate classification, identify the permitted primary-account recovery route if one exists, and restore one eligible free allocation if the classification is erroneous. Changing the key or browser method does not change the provider's allocation. No evidence supports treating an ordinary daily/monthly reset as a fix for this restricted `0 / 0` account.

The user authorized sending from the saved Gmail account on September 16. [SUPPORT-REQUEST.md](SUPPORT-REQUEST.md) records the exact message sent at **19:36:24 +08:00** to the official support address. Gmail Sent independently matched sender, recipient, subject and body; recipient delivery/read remains unverified. No plan was purchased. Recovery is complete only after fresh account usage shows available credits and one explicitly requested IP lookup succeeds; successful login alone is insufficient.

Private receipts are in ignored `.state/support/20260916/`. Direct Google API access timed out; the existing local HTTP proxy worked. Before creating a draft through that proxy, a verified, complete Gmail search established that the timed-out attempt left no matching draft or sent message. Only one send was executed. The finite Supervisor watch is `mail.ipqs-quota-20260916`; its live `mail-watch status` controls completion. The user will relay the official reply for further discussion; do not send follow-ups automatically.

The watch is registered and the updated resident service is loaded. The first scheduled check is **2026-09-16 21:00 +08:00**, then 09/12/15/18/21 while active. A real metadata-only probe returned `waiting / NO_REPLY`; all **822 Supervisor offline tests** passed. A detected automatic acknowledgement keeps the watch open, and a matching non-automatic reply closes it permanently. The service uses its existing WhatsApp group `工作` reporting path. This is reply tracking, not evidence that IPQS restored credits.

## Text access evidence and implementation

| Method | Current evidence | Use |
| --- | --- | --- |
| Official JSON API | Credential accepted, no available credits; Chrome not needed | Default for usage and reputation queries |
| Plain HTTP login-page GET | HTTP 200 in about 633 ms; expected form, no observed challenge marker | Public-page access only; not proof of authenticated HTTP access |
| Chrome context's standalone HTTP client | HTTP 200 containing the login form, both default headers and the current browser User-Agent/referrer | Not usable for this authenticated dashboard in this test; no inferred reason |
| Same-origin browser `fetch` | Authenticated HTML, logout link and duplicate restriction; about 511 ms | Default dashboard text path |
| Rendered DOM | Authenticated dashboard and same restriction | Explicit `mode=controls` for forms and dynamic content |

`ipqs_read_dashboard` now defaults to `mode=text`: one same-origin GET, a byte limit, inert HTML parsing, redaction, and no dashboard navigation or script/subresource execution. Chrome remains the login container; an initial launch may still load the origin. The text mode does not claim full external-CSS visibility or fully browserless authenticated access. Failed authentication or HTTP errors do not trigger login/retry automatically.

The September 16 comparison with `text_browser_kernel` supports retaining this split. Its public `text_fetch` has no authenticated session authority, and its browser tools own a separate fixed profile/CDP port. Routing through them would lose IPQS login isolation or require a new credential/profile injection interface. IPQS already directly reuses the same shared browser-session lifecycle helper. Production uses ordinary Chrome as the login container, not headless Chrome; the headless browser in the test command below is isolated synthetic validation only.

Browser commands now use compiled JavaScript because direct `tsx` live evaluation reproduced `ReferenceError: __name is not defined` inside Playwright's serialized page callback.

## Shared logic and verification

The package continues to reuse browser-session, mcp-server and secret-file, and now directly uses one-use-token for bounded, expiring setting confirmations. IPQS-specific HTTP/quota classification stays in `src/account-policy.ts`. Redundant session-close forwarding and authentication aliases were removed. The setting token is synchronously claimed after the browser queue, consumed on failure, and checked for expiry again before fill/submission. Hidden/inert API-key candidates are filtered before their values are collected.

Validated commands for these changes:

- `npm run check` in this package: TypeScript, offline policy/API/stdio tests and static doctor.
- `npm run test:browser-text`: isolated synthetic headless Chrome; every request locally intercepted, no account profile. Covers same-origin GET, inert/no-subresource parsing, no navigation, redaction, login HTML, HTTP failures and body limits.
- `npm run check` in `common/shared/one-use-token`: shared lifetime/capacity/one-use contracts.
- `node scripts/check-agent-manifest.mjs` at the parent root.
- Live default text-read and official account read after the implementation change; only sanitized evidence was returned.

Only `mcp/ipqs/` source, tests and documentation belong to this change. Preserve concurrent root/WeChat/Overleaf/media-text work. Live MCP registration remains opt-in and unchanged. Per-remote synchronization receipts belong to the completing task's final response, not to an inferred whole-disk health claim.
