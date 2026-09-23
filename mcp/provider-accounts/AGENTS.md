# Provider accounts MCP

Owns free ipapi.is and Cloudflare account setup for the IPQuality reporter.
ipwho.is and DB-IP need no account or key for their free context APIs. This package
reuses mcps/common/shared browser-session, http-read, secret-file, totp and
mcp-server directly. Provider state, selectors, quotas and API contracts stay here.

Node 24.5+ supports the native HTTPS proxy agent. npm start starts stdio;
npm test runs offline policy, one-submit form, TOTP/recovery and MCP fixtures.
Dependency restoration uses npm install --offline --ignore-scripts.

## Tools and workflow

| Tool | Effect |
| --- | --- |
| provider_account_status | Local credential and submission metadata; no network |
| provider_account_open | Open one fixed signup/login/dashboard/security page in its dedicated profile |
| provider_account_read | Redacted existing-page text and value-free controls; DOM state alone may be inconclusive |
| provider_account_create_free | One free signup after CREATE_FREE_ACCOUNT; uses the confirmed private email/country |
| ipapi_import_free_key | Import a labelled key after one full-response free lookup and IMPORT_FREE_API_KEY |
| public_provider_verify_free_api | VERIFY_FREE_API performs one fixed 1.1.1.1 query; surface=free_api (default) checks DB-IP/ipwho.is free context, surface=public_demo checks DB-IP/IPWHOIS website risk data. No account/browser |
| cloudflare_account_check | Current server identity, email and 2FA state; no Intel credit |
| cloudflare_prepare_intel_token | Prepare an account-scoped Intel Read token and validate the dashboard's JSON review |
| cloudflare_create_intel_token | Revalidate and submit that exact policy once after CREATE_INTEL_READ_TOKEN; save its value privately |
| cloudflare_verify_free_api | One 1.1.1.1 lookup after VERIFY_FREE_API; records useful data, not merely a 200 status |
| cloudflare_enable_totp | ENABLE_TOTP requires successful API evidence within 30 minutes for the same account/key; saves the textual seed before one code/password submission |
| cloudflare_save_recovery_codes | SAVE_RECOVERY_CODES stores the initial eight numeric recovery codes privately and acknowledges the saved set |

The user requires API usability before 2FA. A missing key, unavailable API,
changed account/key or stale proof stops before authenticator enrollment. Existing
factors and different saved seeds/keys are preserved. Missing threat data remains
unknown even when the network-context API is useful.

`public-api.mjs` maintains separate permanent free API and public-demo contracts.
Its shared HTTP reader rejects redirects, bounds time/bytes and never retries.
Only the explicit demo surface can provide a DB-IP threat label or IPWHOIS
proxy/VPN/Tor/hosting booleans. Values are target-bound, source-projected and
nullable. Numeric risk scores are never invented. `observation` contains the
validated data; `riskLabelAvailable`/`riskFactorsAvailable` say what was actually
supplied. Missing demo security is distinct from a useful geography observation.
HTTP 200 quota-error bodies return `usable:false`, `status:rate_limited`.
Demo quotas are unspecified, distinct from 500/day DB-IP and 1,000/day ipwho.is
free geography. No demo account/key/2FA is required, no embedded key is scraped,
and no paid Extended integration/account/profile is created.

ipapi's observed dashboard is /app/home. Its logout is an icon, so the account
check uses the exact saved email, one visible labelled key and the same-origin
logout link, without relying on visible "Sign out" text. Its current account
page exposes no 2FA entry; the security surface therefore stops locally instead
of navigating to a guessed settings path. An activation notice remains pending
email verification even when a password form is present.

Cloudflare account reads use the shared active-browser-context HTTP helper:
one fixed GET to /api/v4/user, no redirects/retries, bounded body, exact saved-email
comparison and suspended-account rejection. Browser-side fetch sometimes timed out
on this surface; the context HTTP method passed and is now the direct path.
Intel lookups use native bounded HTTP with the saved token and no Chrome.

## Private files and lifetime

The path/format index is [../../CREDENTIALS.md](../../CREDENTIALS.md).
Registration identity is ../../secrets/accounts/registration-email. Passwords,
submission receipts, API proof, TOTP URI and recovery codes stay in private
../../secrets/accounts/provider directories; raw API keys use the reporter's
flat secrets/ipapi and secrets/cloudflare_token paths.

Profiles are .state/ipapi and .state/cloudflare, bound to CDP 19503/19504 with
exclusive operation leases at 19603/19604. PROVIDER_ACCOUNTS_PROXY chooses a
credential-free HTTP proxy only for this package. Set it to DIRECT for explicit
direct access: Chrome receives --no-proxy-server and bypasses macOS system proxy
preferences. The bound process's actual routing flags are verified before reuse;
changing the requested route requires closing that owned browser first.
Local CDP traffic stays direct;
when launching a child through an isolated ATT session, pass its proxy with that
variable and retain localhost in NO_PROXY. No live Clash setting changes.
Browser shutdown verifies profile binding before Browser.close. The temporary
ATT signup browser is closed before its private Mihomo exits.

Passwords are random and saved before signup. Durable receipts prevent automatic
duplicate registration/token/enrollment submissions after timeouts. Registration
may be retried on a different route only after explicit user direction and review
of the prior outcome; preserve the prior receipt. CAPTCHA is left for the user.
No billing, upgrade, email-send, generic arbitrary-selector or recovery-code
regeneration tool is exposed. Public results never include credentials, codes,
seeds, cookies, account IDs or verification URL tokens.

## Current evidence — 2026-09-22

The user selected the existing IPQS email and Hong Kong. ipapi signup and email
activation succeeded on verified explicit DIRECT. Earlier proxy/system-route and
isolated vps+yyssr18 / ATT attempts were rejected. Clearing proxy environment
variables alone had left Chrome using macOS system proxy preferences; the new
direct flag and retained-process route check fix that bug. The dashboard confirms
a 1,000/day free plan. The private key passed a full-response 1.1.1.1 API lookup
and the reporter returned ipapi=ok / Mode=full. No 2FA entry was present on the
account page, so no ipapi factor was created. ipwho.is worked without registration.

Cloudflare free signup and email verification succeeded. The saved account token
has only Intel Read for the configured account, with no expiration. The official
API returned useful ASN/organization/infrastructure data. Its current numeric ASN
and absent risk_types are covered by fixtures; absence is not a clean result.
The reporter also returned Cloudflare=ok with the saved token.

Only after that API proof, a generated TOTP code and saved password were accepted.
The server confirmed both two_factor_authentication_enabled and totp_configured.
The private seed and eight recovery codes were saved, and no paid plan was chosen.
An independent fresh Chrome profile then passed one saved-password login and the
new TOTP challenge; the authenticated account endpoint confirmed the exact saved
identity and enabled factor. The login widget automatically submits a complete
six-digit code. Inspect navigation/identity before clicking a Verify button that
may already have disappeared. Both owned setup browsers and the temporary proof
profile were closed/removed after validation; the normal account profile remains.

On 2026-09-24 both permanent free API probes returned usable context for 1.1.1.1.
The website-demo investigation then returned DB-IP OVER_QUERY_LIMIT and IPWHOIS
rate-limit errors. These are unavailable risk observations, not successful free
risk proof. No new account or 2FA enrollment was attempted. Existing Cloudflare
TOTP remains the previously verified factor; its legacy Threat Score is now
constant zero and is not a reason to recreate the account/factor.
The provider MCP passes 28 offline tests, including stdio, both demo success
contracts, HTTP 200 quota failures and no-retry checks. Repository-wide evidence
is maintained in ../../HANDOFF.md.
