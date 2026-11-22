# IPQS MCP

Private local MCP for IPQualityScore dashboard access, low-risk account preference management, API-key acquisition from the logged-in frontend, and secret-backed read-only official API calls.

## Start here

This optional package needs Node 22+ and the sibling `myutils`
dependencies. Browser tools also need installed Chrome. From the project root:

```text
npm --prefix mcp/ipqs run check
npm --prefix mcp/ipqs start
```

`check` builds before offline tests and the static doctor; `start` runs the built
stdio server for an MCP client, not an interactive CLI. For build-only setup use
`npm --prefix mcp/ipqs run build`. Stop the server through its client or Ctrl-C.
See [../../MCP.md](../../MCP.md) for current authentication/backend and dated
account evidence, [../../TESTING.md](../../TESTING.md) for dependency restoration
and all test commands, [../../SERVICES.md](../../SERVICES.md) for retained-browser
lifetime, and the [ATT TLS support record](SUPPORT-TLS-20261010.md). The commands
below use this package as the working directory.

## Authentication check

Since 2026-11-21 the IPQS login lives only in the shared Chrome profile, the
text browser's saved profile (`~/.local/state/myutils/text-browser-kernel/chrome-profile`
or `chromeProfileDir` of its `saved-profile.json`), and is used only through
the one dedicated Chrome on it (myutils `@myutils/web-text/shared-chrome`).
`npm run auth:check` verifies that session with one bounded HTTP dashboard
read using the profile's IPQS cookies and exits nonzero without positive
proof; it opens no page. API status remains `npm run probe:sanitized`. A 200
login/TOTP page remains unauthenticated. A Chrome that cannot start (outside
the owner's GUI session) is `unavailable`, never a logout. HTTP reads use
IPQS_PROXY_SERVER, HTTPS_PROXY or HTTP_PROXY, else the system proxy
(`127.0.0.1:7897`) the shared Chrome uses, so the session and its reads leave
through one exit. No failure opens a GUI automatically.

## Access Strategy

1. For account usage and reputation lookups, use the official API directly without Chrome. Dashboard login is independent of API credential readiness.
2. Dashboard actions and saved login run in hidden tabs of the shared dedicated
   Chrome (`withDedicatedChrome` with `sharedChromeRuntime`); the package never
   launches Chrome on a profile of its own. A call that opens the login or a
   dashboard keeps its tab for the next call; `ipqs_close_browser` releases it.
   An authorized task may submit the fixed owner-only email/password bundle once
   and complete its reviewed TOTP; the cookies stay in the shared profile.
3. Read dashboard text with one HTTP GET carrying the shared profile's IPQS cookies (`readSharedChromeCookies`) and static HTML extraction, directly reusing myutils transport, form parsing and text projection. Cookies the response sets or removes go back to the profile (`writeSharedChromeCookies`). Use a hidden tab's rendered DOM only when control metadata or dynamic content is required; a failed HTTP read does not trigger a browser or login retry.
4. Import an existing visible dashboard API key directly into the ignored parent secret file without returning the key to the agent.
5. Official JSON API authentication uses headers for explicit fraud-intelligence lookups, and the documented path-auth form for account usage.

The package keeps no profile, cookie or session file. The former
`.state/chrome-profile/` (with its `http-session.json`) stays on disk untouched
as rollback data until a separate deletion; no code reads it. Account API
requests use the key independently. Credentials never enter MCP output and are
not read when the shared profile is already authenticated. Normal checkbox
verification uses myutils native input on the same tab before login readiness
is classified. Remaining checks retain their observed state; email/passkey
recovery uses its own flow. An explicitly requested `visible=true` or the
manual login script opens a window of the same Chrome; there is no automatic GUI fallback.

## Directory Map

- `src/server.ts`: MCP stdio entrypoint and tool schemas.
- `src/browser.ts`: shared-Chrome tabs, authentication evidence, redacted dashboard reads, API-key import, and two-stage setting changes.
- `src/dashboard-text.ts`: redacted, bounded static HTML text with hidden/inert content and form values excluded; no browser launch or script execution.
- `src/http-auth.ts`: HTTP reads for authentication and dashboard text with the shared profile's IPQS cookies (`../common/shared-cookies.mjs`); one GET, zero redirects/retries, 15-second request timeout and 1 MiB accepted body limit. The shared APIRequestContext transport buffers before validating the body limit. A 200 login/TOTP page never authenticates.
- `src/auth.ts`: exact IPQS login-form recognition, authenticated-page classification, and one-submit credential policy.
- `src/totp.ts`: issuer/account-bound textual enrollment, private emergency recovery, and one-submit authenticator challenge. Uses the shared TOTP library's explicit legacy-80-bit option for this issuer.
- `src/api.ts`: bounded read-only IPQS JSON API client.
- `src/account-probe.ts`: fixed-outcome, secret-free account/API authentication probe over the non-lookup account endpoint.
- `src/account-policy.ts`: IPQS-specific HTTP, authentication and quota interpretation, used by the probe and API-key validation.
- `src/config.ts`: IPQS URLs, the HTTP proxy, and credential discovery.
- `src/credentials.ts`: fixed central owner-only two-line email/password bundle discovery and validation.
- `src/frontend-policy.ts`: pure exact-match control, safe-submit, blocked-sensitive-field, and API-key candidate policy.
- `src/redaction.ts`: IPQS bounds and error wording on top of `@myutils/redaction`, which owns the redaction rules.
- `src/tool-policy.ts`: server instructions copied into every tool description through `@myutils/mcp-server`.
- `scripts/login.ts`: interactive login in a window of the shared Chrome and current-session verification.
- `scripts/login-saved.ts`: explicitly confirmed bounded login from the fixed private credential bundle.
- `scripts/doctor.ts`: offline readiness and secret metadata summary.
- `scripts/probe.ts`: noninteractive sanitized account probe; never opens Chrome or performs a reputation lookup.
- `tests/`: offline policy, API transport, secret hygiene, and MCP stdio contracts.
- `.state/`: ignored; the former dedicated profile, kept only as rollback data.
- `../../secrets/ipqs`: ignored owner-only default API key file.
- `~/codexworkspace/secrets/infrastructure/network/ipqs/`: fixed central owner-only directory containing exactly one two-line email/password bundle.

## MCP Tools

- `ipqs_status`: report sanitized package, shared-profile, and API credential readiness; the HTTP authentication probe is opt-in.
- `ipqs_open_login`: open the reviewed login in a kept hidden tab of the shared Chrome; `visible=true` explicitly requests human interaction.
- `ipqs_finish_login`: verify the shared profile's authenticated dashboard and optionally keep the tab.
- `ipqs_login_with_saved_credentials`: reuse the shared profile's session first, then after explicit confirmation read the fixed owner-only bundle and submit the reviewed IPQS login form at most once.
- `ipqs_enable_totp`: after `ENABLE_IPQS_TOTP`, prove usable API credits, save the bound seed and emergency backup code privately, reserve and submit one enrollment. Existing factors/attempts are preserved.
- `ipqs_complete_totp`: after `USE_SAVED_IPQS_TOTP`, submit one reviewed challenge from the private seed; no code is returned.
- `ipqs_open_dashboard`: keep a hidden tab on the dashboard home, settings, or API-key page.
- `ipqs_read_dashboard`: default `mode=text` returns redacted HTML text from one HTTP GET with the shared profile's cookies; `mode=controls` uses a hidden tab for rendered text, value-free controls and buttons. Both accept only the three named dashboard pages; neither logs in automatically.
- `ipqs_import_api_key`: reveal when necessary, select one visible dashboard API key, and write it directly to the private local secret file; returns metadata and a fingerprint only.
- `ipqs_prepare_setting_change`: exact-match a low-risk setting field and safe submit button, then create a short-lived in-memory change id without editing the page.
- `ipqs_apply_setting_change`: revalidate and apply one prepared low-risk setting after literal confirmation, then return sanitized success evidence.
- `ipqs_account_usage`: read current credits and usage through the official account API.
- `ipqs_lookup`: perform one explicit IP, email, phone, or URL reputation lookup through the official API.
- `ipqs_close_browser`: release this server's kept tab and attachment to the shared Chrome (`releaseDedicatedChromePages`); the Chrome and the login stay. A confirmed release returns `{released:true}`; failed or timed-out cleanup returns `released:false` and the fixed cleanup uncertainty marker.

## Frontend Experience

- Normal saved login and dashboard work use hidden tabs. For explicitly approved
  human recovery use `ipqs_open_login(visible=true)`, then `ipqs_finish_login`.
- For an explicitly authorized saved login, use `ipqs_login_with_saved_credentials` with the literal confirmation. It keeps its tab by default for a remaining check; a successful existing session does not read the bundle, and a failed submission is never retried automatically.
- The current dashboard home is `/user/dashboard`. API-key reads wait for the page's asynchronous metrics and rows to settle; adjacent key-like text is only a candidate until the non-lookup account endpoint accepts it.
- Use `ipqs_read_dashboard` with `mode=controls` before changing a preference; control values are deliberately omitted, while exact names, labels, types, select option labels, and safe buttons remain searchable.
- Default dashboard text reads use HTTP with the shared profile's cookies and static HTML parsing. Explicit `mode=controls` reads open and close a hidden tab of their own. An HTTP 200 login page is not authenticated evidence. The HTTP text projection strips scripts, hidden/form values and inline-hidden nodes, but does not claim external-CSS rendered visibility. The Svelte dashboard renders its content with JavaScript, so its HTTP text is nearly empty; use the official usage API or explicit `mode=controls` for page content.
- Setting changes are two-stage and expire after ten minutes, with at most 100 pending records. The shared one-use helper claims an execution after the browser queue and before any awaited work; failures consume the claim and require a fresh preparation. The generic path is optimized for preferences such as names, URLs, numeric thresholds, select choices, and notification checkboxes.
- Password, email, phone, MFA, billing, subscription, deletion, and API-key lifecycle fields are routed out of the generic preference tool because those flows require task-specific recovery and verification.
- API-key import is confirmation-gated. A visible candidate must pass the non-lookup account endpoint before any local secret is written. If more than one key is visible, provide a unique label fragment. Replacing a different local key also requires `replaceExisting=true` in the confirmed call.

## API Experience

- `IPQS_API_KEY` is a task-scoped environment override. Normal persistent use reads `../../secrets/ipqs` or `IPQS_API_KEY_FILE`.
- Requests are GET-only. Reputation lookups use the official `ipqs-key` header; the account-usage endpoint uses IPQS's documented path-auth form because that endpoint rejected header authentication during live verification. Neither request URL nor credential is returned by the MCP.
- `ipqs_lookup` supports the official `ip`, `email`, `phone`, and `url` JSON endpoints and optional bounded query parameters. It does not retry automatically because a retry can consume another credit.
- `ipqs_account_usage` uses the official account endpoint and returns a sanitized JSON response plus a fixed `outcome`. HTTP 401/403, 429 and 5xx take precedence over misleading success/quota text. A successful response with zero available credits remains `authenticated_without_credits`.
- Quota failure does not itself identify its cause. Distinguish an ordinary daily/monthly limit from a zero allocation or an explicit dashboard restriction; only current account evidence supports that distinction. The current usage reference is `https://www.ipqualityscore.com/documentation/account-management/usage`.
- `npm run probe:sanitized` checks local credential readiness and calls the same non-lookup account endpoint at most once. Its output is limited to a schema version and fixed outcome; `authenticated_without_credits` proves credential acceptance while preserving quota failure as a distinct state.

## Browser Environment

- Pages are tabs of the dedicated Chrome on the shared profile (CDP port 19551,
  or 19553 for a profile the owner chose), on the system proxy; it starts hidden
  when none runs (Aqua session only) and closes after 30 idle minutes.
- `IPQS_PROXY_SERVER`: optional credential-free HTTP, HTTPS, or SOCKS5 proxy URL for HTTP reads only.
- `IPQS_TIMEOUT_MS`: bounded browser/API timeout from 1 to 60 seconds.

## Safety Evidence

- Shared `settleBrowserOperation` bounds temporary cleanup and preserves useful results with a fixed cleanup warning. A combined failure retains the original error as its cause, without exposing raw cleanup diagnostics.
- Explicit close uses the same bounded cleanup contract; account actions and settings keep their existing policies.

- The HTTP status reads active form controls with `parseActiveHtmlDocument(html, {formEvidence:true})` from `@myutils/web-text/http-text`. Positive evidence is a real IPQS logout link or, on the Svelte dashboard (seen 2026-11-21, which has no logout link in its HTML), an executable inline script assigning `globalThis.staticUser` a numeric `id` and an `email`; text, comments, templates and JSON blocks do not count. The package also reuses myutils' `browser-session`, `mcp-server`, `secret-file`, `one-use-token`, `redaction` and `totp`.
- `@myutils/totp` supplies RFC 6238 validation/generation. The website's QR URL is read as text; no image processing occurs. Seed and recovery code are saved before activation, and a changed/foreign form stops before secret use.
- The saved account directory must be an owned ordinary `0700` directory containing exactly one owned, singly linked, `0600` ordinary file with email and password as two positional lines.
- Authentication checks recognize the reviewed visible `/login/submit` form rather than treating password-change fields on `/user/settings` as a login page.
- Dashboard tools accept only the three named IPQS pages; callers cannot supply a foreign URL or arbitrary selector.
- Reads never return input values, cookies, localStorage, response headers, or raw session state; cookie values stay in process memory. API-key candidate collection filters hidden/inert ancestors before reading values.
- Secret-file inspection returns only usability and a short SHA-256 fingerprint. API-key content is never returned by MCP tools.
- Form submission requires a prepared change id, field-policy revalidation, a safe exact submit button, ten-minute expiry, and literal confirmation.
- API calls reject redirects, unsupported charsets, non-JSON or oversized bodies, and unbounded parameter keys or values.
- The sanitized account probe (`probe:sanitized`, not scheduled) never returns API bodies, status messages, account fields, credential metadata, paths, fingerprints, or error text, and never spends a reputation-lookup credit.
- Live Codex config remains unchanged unless a separate task explicitly requests registration or enablement.

## Validation

Run from this package:

```sh
npm run check
```

This builds TypeScript, runs offline tests (including a stdio MCP contract test whose server runs in a temporary directory), and runs a static doctor. It does not open Chrome, log in, or spend IPQS credits. Use `npm run login` for interactive login or `npm run login:saved -- --confirm` only after the current task explicitly authorizes use of the fixed saved bundle.

Browser entrypoints build and run compiled JavaScript: direct `tsx` execution can inject `__name` helpers into serialized Playwright callbacks and fail inside the page. Use the compiled `dist/src/browser.js` for task-scoped browser scripts too.

The offline `tests/dashboard-text.test.ts` exercises the public default read with a synthetic shared profile and an intercepted HTTP client: exact target/proxy, one request, cookie write-back only for changed or removed cookies, hidden content, redaction, login/TOTP rejection, HTTP/encoding/body limits and cleanup failures. No browser or live account is used. Also run `npm run test:browser-text` after dashboard-read changes; its synthetic Chrome fixture checks visible API-key candidates and hidden/CSS/inert exclusions with every request blocked.

`tests/browser-close.test.ts` resolves the shared Chrome modules to synthetic
ones, then tests the actual public login/close entries and queue: hidden kept
tabs, the shown window, release failure, deadline and late rejection, without
starting Chrome. To validate source while an existing
server uses `dist`, run `../node_modules/.bin/tsc --noEmit -p tsconfig.json` and
`../node_modules/.bin/tsx --test tests/*.test.ts` from this package. The stdio
fixture then checks the existing compiled entry separately; it does not prove
that a running server has adopted the changed source.

Run `npm run probe:sanitized` only when current account/API evidence is required. It performs one bounded official account read without browser fallback or automatic retry and does not consume a lookup credit.
