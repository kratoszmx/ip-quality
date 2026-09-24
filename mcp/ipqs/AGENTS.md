# IPQS MCP

Private local MCP for IPQualityScore dashboard access, low-risk account preference management, API-key acquisition from the logged-in frontend, and secret-backed read-only official API calls.

## Start here

This optional package needs Node 22+ and the sibling `mcps/common/shared`
dependencies. Browser tools also need installed Chrome. From the project root:

```text
npm --prefix mcp/ipqs run check
npm --prefix mcp/ipqs start
```

`check` builds before offline tests and the static doctor; `start` runs the built
stdio server for an MCP client, not an interactive CLI. For build-only setup use
`npm --prefix mcp/ipqs run build`. Stop the server through its client or Ctrl-C.
See [../../TESTING.md](../../TESTING.md) for dependency restoration and all test
commands, [../../SERVICES.md](../../SERVICES.md) for retained-browser lifetime,
and [HANDOFF.md](HANDOFF.md) for dated account evidence. The commands below use
this package as the working directory.

## Authentication check

`npm run auth:check` verifies the browser dashboard and exits nonzero without positive proof; official API status remains `npm run probe:sanitized`. The verified default uses a no-store same-origin HTTP GET from a retained background headed Chrome container, so adjacent checks attach instead of repeatedly restarting a GUI. `--headless` is an explicit bounded experiment; on 2026-09-22 it returned 403 and was not adopted. HTTP rejection is distinct from a DOM verification challenge. Standard HTTPS_PROXY/HTTP_PROXY or IPQS_PROXY_SERVER may select the existing task-scoped proxy. A real login form under /user/dashboard is expired authentication even at HTTP 200.

## Access Strategy

1. For account usage and reputation lookups, use the official API directly without Chrome. Dashboard login is independent of API credential readiness.
2. When dashboard-only evidence or account actions are needed, establish or reuse login in a dedicated real Chrome/CDP profile under `.state/chrome-profile/`; an explicitly authorized task may use the fixed owner-only two-line email/password bundle for one bounded submission.
3. Read dashboard text with a same-origin browser `fetch` and inert HTML extraction. Use rendered DOM only when control metadata or dynamic content is required.
4. Import an existing visible dashboard API key directly into the ignored parent secret file without returning the key to the agent.
5. Official JSON API authentication uses headers for explicit fraud-intelligence lookups, and the documented path-auth form for account usage.

The dedicated profile is the login container. API requests use the local key file and do not depend on exported browser cookies. Saved credentials are read only after task-level confirmation, never enter MCP arguments or output, and are not read when the profile is already authenticated. CAPTCHA, email verification, passkeys, and 2FA stay in the visible browser as human-auth steps.

## Directory Map

- `src/server.ts`: MCP stdio entrypoint and tool schemas.
- `src/browser.ts`: Chrome/CDP lifecycle, authentication evidence, redacted dashboard reads, API-key import, and two-stage setting changes.
- `src/dashboard-text.ts`: bounded same-origin GET and inert HTML text projection; no page navigation, script execution, session export or input values.
- `src/auth.ts`: exact IPQS login-form recognition, authenticated-page classification, and one-submit credential policy.
- `src/api.ts`: bounded read-only IPQS JSON API client.
- `src/account-probe.ts`: fixed-outcome, secret-free account/API authentication probe over the non-lookup account endpoint.
- `src/account-policy.ts`: IPQS-specific HTTP, authentication and quota interpretation, used by the probe and API-key validation.
- `src/config.ts`: IPQS URLs, dedicated state paths, proxy settings, and credential discovery.
- `src/credentials.ts`: fixed central owner-only two-line email/password bundle discovery and validation.
- `src/frontend-policy.ts`: pure exact-match control, safe-submit, blocked-sensitive-field, and API-key candidate policy.
- `src/redaction.ts`: dashboard and API output redaction.
- `src/tool-policy.ts`: server instructions copied into every tool description through the parent shared helper.
- `scripts/login.ts`: interactive dedicated-profile login and current-session verification.
- `scripts/login-saved.ts`: explicitly confirmed bounded login from the fixed private credential bundle.
- `scripts/doctor.ts`: offline readiness and secret metadata summary.
- `scripts/probe.ts`: noninteractive sanitized account probe; never opens Chrome or performs a reputation lookup.
- `tests/`: offline policy, API transport, secret hygiene, and MCP stdio contracts.
- `.state/`: ignored dedicated Chrome profile.
- `../../secrets/ipqs`: ignored owner-only default API key file.
- `~/codexworkspace/secrets/infrastructure/network/ipqs/`: fixed central owner-only directory containing exactly one two-line email/password bundle.

## MCP Tools

- `ipqs_status`: report sanitized package, browser-profile, and API credential readiness; browser probing is opt-in.
- `ipqs_open_login`: keep the dedicated real Chrome session open on the login page for human authentication.
- `ipqs_finish_login`: verify the current authenticated dashboard and optionally keep the browser open.
- `ipqs_login_with_saved_credentials`: reuse the profile first, then after explicit confirmation read the fixed owner-only bundle and submit the reviewed IPQS login form at most once.
- `ipqs_open_dashboard`: keep the browser open on the dashboard home, settings, or API-key page.
- `ipqs_read_dashboard`: default `mode=text` returns redacted HTML text from one same-origin GET; `mode=controls` returns rendered DOM text plus value-free controls and buttons from an allowlisted dashboard page.
- `ipqs_import_api_key`: reveal when necessary, select one visible dashboard API key, and write it directly to the private local secret file; returns metadata and a fingerprint only.
- `ipqs_prepare_setting_change`: exact-match a low-risk setting field and safe submit button, then create a short-lived in-memory change id without editing the page.
- `ipqs_apply_setting_change`: revalidate and apply one prepared low-risk setting after literal confirmation, then return sanitized success evidence.
- `ipqs_account_usage`: read current credits and usage through the official account API.
- `ipqs_lookup`: perform one explicit IP, email, phone, or URL reputation lookup through the official API.
- `ipqs_close_browser`: close this server's active Chrome/CDP session; it stops Chrome only when that session launched it with shutdown ownership. An attached retained container can remain open.

## Frontend Experience

- Use `ipqs_open_login`, complete login in the visible browser, then call `ipqs_finish_login`.
- For an explicitly authorized saved login, use `ipqs_login_with_saved_credentials` with the literal confirmation. It keeps Chrome open by default so the session can serve following dashboard tools; a successful existing session does not read the bundle, and a failed submission is never retried automatically.
- The current dashboard home is `/user/dashboard`. API-key reads wait for the page's asynchronous metrics and rows to settle; adjacent key-like text is only a candidate until the non-lookup account endpoint accepts it.
- Use `ipqs_read_dashboard` with `mode=controls` before changing a preference; control values are deliberately omitted, while exact names, labels, types, select option labels, and safe buttons remain searchable.
- Text reads reuse the authenticated origin without navigating the dashboard again. An initial Chrome launch may still establish that origin; Chrome remains the isolated login container. An HTTP 200 login page is not authenticated evidence. The text projection strips scripts, hidden/form values and inline-hidden nodes, but does not claim external-CSS rendered visibility. For dynamic metrics, use the official usage API or explicit `mode=controls`.
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

- `IPQS_BROWSER_PROFILE_DIR`: normalized absolute dedicated profile path.
- `IPQS_CDP_PORT`: local CDP port, default `19453`.
- `IPQS_CHROME_PATH`: optional Chrome executable override.
- `IPQS_PROXY_SERVER`: optional credential-free HTTP, HTTPS, or SOCKS5 proxy URL.
- `IPQS_LOCALE`: browser locale, default `en-US`.
- `IPQS_TIMEOUT_MS`: bounded browser/API timeout from 1 to 60 seconds.

## Safety Evidence

- The package reuses `@codex-mcp/shared-browser-session`, `@codex-mcp/shared-mcp-server`, `@codex-mcp/shared-secret-file`, and `@codex-mcp/shared-one-use-token` from the external mcps common library. IPQS URLs, quota messages, account state and selectors stay in this package.
- The saved account directory must be an owned ordinary `0700` directory containing exactly one owned, singly linked, `0600` ordinary file with email and password as two positional lines.
- Authentication checks recognize the reviewed visible `/login/submit` form rather than treating password-change fields on `/user/settings` as a login page.
- Dashboard tools accept only the three named IPQS pages; callers cannot supply a foreign URL or arbitrary selector.
- Reads never return input values, cookies, localStorage, response headers, or raw session state. API-key candidate collection filters hidden/inert ancestors before reading values.
- Secret-file inspection returns only usability and a short SHA-256 fingerprint. API-key content is never returned by MCP tools.
- Form submission requires a prepared change id, field-policy revalidation, a safe exact submit button, ten-minute expiry, and literal confirmation.
- API calls reject redirects, unsupported charsets, non-JSON or oversized bodies, and unbounded parameter keys or values.
- The scheduled-account probe never returns API bodies, status messages, account fields, credential metadata, paths, fingerprints, or error text, and never spends a reputation-lookup credit.
- Live Codex config remains unchanged unless a separate task explicitly requests registration or enablement.

## Validation

Run from this package:

```sh
npm run check
```

This builds TypeScript, runs offline tests, starts an isolated stdio MCP contract test, and runs a static doctor. It does not open Chrome, log in, or spend IPQS credits. Use `npm run login` for interactive login or `npm run login:saved -- --confirm` only after the current task explicitly authorizes use of the fixed saved bundle.

Browser entrypoints build and run compiled JavaScript: direct `tsx` execution can inject `__name` helpers into serialized Playwright callbacks and fail inside the page. Use the compiled `dist/src/browser.js` for task-scoped browser scripts too.

For `dashboard-text.ts` changes, also run `npm run test:browser-text`. This separate test opens an isolated headless Chrome with a synthetic profile, intercepts every request locally, and verifies inert parsing, no navigation/subresource loading, redaction, login-HTML rejection, HTTP failures and body limits. It never uses the account profile or the live IPQS service.

Run `npm run probe:sanitized` only when current account/API evidence is required. It performs one bounded official account read without browser fallback or automatic retry and does not consume a lookup credit.
