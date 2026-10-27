# Provider accounts MCP

Owns free ipapi.is, Cloudflare, AbuseIPDB and ipdata account maintenance for the IPQuality reporter.
ipwho.is and DB-IP need no account or key for their free context APIs. This package
reuses myutils' browser-session/http-read, secret-file, totp, redaction and
mcp-server directly. Provider state, selectors, quotas and API contracts stay here.

## Start here

Use Node 24.5+ for the native HTTPS proxy agent and installed Chrome for browser
tools. The sibling `myutils` dependencies must be present; restoration
and test coverage are in [../../TESTING.md](../../TESTING.md). From the project root:

```text
npm --prefix mcp/provider-accounts test
npm --prefix mcp/provider-accounts start
```

No build step is needed. `start` runs a stdio MCP server for a client, not an
interactive CLI. Start with the network-free `provider_account_status` tool;
opening pages or verifying APIs makes live requests. Browser retention and
shutdown are described in [../../SERVICES.md](../../SERVICES.md).
The formal inventory and current account/2FA evidence are in
[../../MCP.md](../../MCP.md).

## Tools and workflow

| Tool | Effect |
| --- | --- |
| provider_account_status | Local credential and submission metadata; no network |
| provider_account_open | Native hidden Chrome by default; `visible=true` explicitly requests a human window |
| provider_account_login | USE_SAVED_ACCOUNT_CREDENTIALS: Cloudflare/AbuseIPDB HTTP reuse first, otherwise one reviewed windowless submission; ipapi automatic login disabled after bot_login suspension |
| provider_account_close_browsers | Close only this MCP's owned temporary sessions; preserve saved HTTP and pending state |
| provider_account_read | Default `mode=http`: bounded exact-account identity read with saved state and no Chrome. Explicit `mode=browser`: redacted existing-page text/controls |
| provider_account_create_free | One free signup after CREATE_FREE_ACCOUNT; uses the confirmed private email/country |
| ipapi_import_free_key | Import a labelled key after one full-response free lookup and IMPORT_FREE_API_KEY |
| public_provider_verify_free_api | VERIFY_FREE_API with surface=free_api checks DB-IP/ipwho.is context for 1.1.1.1. public_demo checks IPWHOIS security for 1.1.1.1 or DB-IP's requesting egress via its page and one visitor lookup. No account/browser |
| cloudflare_account_check | Current server identity, email and 2FA state; no Intel credit |
| cloudflare_prepare_intel_token | Prepare an account-scoped Intel Read token and validate the dashboard's JSON review |
| cloudflare_create_intel_token | Revalidate and submit that exact policy once after CREATE_INTEL_READ_TOKEN; save its value privately |
| cloudflare_verify_free_api | One 1.1.1.1 lookup after VERIFY_FREE_API; records useful data, not merely a 200 status |
| cloudflare_enable_totp | ENABLE_TOTP requires successful API evidence within 30 minutes for the same account/key; saves the textual seed before one code/password submission |
| cloudflare_save_recovery_codes | SAVE_RECOVERY_CODES stores the initial eight numeric recovery codes privately and acknowledges the saved set |
| abuseipdb_account_status | Local private account/key presence only; no network or claim of current quota |
| abuseipdb_account_check | Bounded HTTP read of the exact saved account; returns authentication, email-verification and public-profile/domain-visibility booleans |
| abuseipdb_verify_free_api | VERIFY_FREE_API makes one official APIv2 CHECK for 1.1.1.1 using the reporter's private key; no browser or abuse-report submission |
| abuseipdb_account_open | Windowless native signup/login page; explicit visible=true for human recovery; no form submission |
| ipdata_account_status | Local private account/key/HTTP-state readiness only; no live authentication claim |
| ipdata_account_check | One read-only Cognito GetUser HTTP POST with the dedicated saved access token; exact email/key binding, no browser, password login, refresh or IP query |
| ipdata_verify_free_api | VERIFY_FREE_API makes one official 1.1.1.1 query using the reporter key; only supplied risk flags returned, missing VPN remains unknown |

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
HTTP 200 quota-error bodies return `usable:false`, with `status:rate_limited`
or `daily_quota_exhausted` for DB-IP's explicit daily-limit response.
Demo quotas are unspecified and separate from free geography allowances in
[../../PROVIDERS.md](../../PROVIDERS.md). Both demos use the websites' request
headers; requests per surface are in [Module APIs](#module-apis). DB-IP's guest
token and URLs are never returned or saved, and a page failure stops before
lookup without retries or route switches. No demo account/2FA or paid Extended
integration/profile is created.

ipapi's observed dashboard is /app/home. Its logout is an icon, so the account
check uses the exact saved email, one visible labelled key and the same-origin
logout link, without relying on visible "Sign out" text. Its current account
page exposes no 2FA entry; the security surface therefore stops locally instead
of navigating to a guessed settings path. An activation notice remains pending
email verification even when a password form is present.

Routine account reads use `http-account.mjs` and the shared bounded HTTP context
reader with private saved state, without launching Chrome. Cloudflare uses one
fixed GET to /api/v4/user; ipapi uses /app/home; AbuseIPDB uses /account.
All bind the saved identity and reject login/error bodies, redirects and retries. A failed HTTP check returns a
failure rather than automatically opening a browser. HTTP-state recovery is
described below; opening a browser alone does not refresh every provider's state.
Intel lookups use native bounded HTTP with the saved token and no Chrome.
ipdata uses `ipdata.mjs` for its fixed read-only Cognito GetUser POST and official
API lookup. The account parser binds the saved email, compares the reporter key
and projects only verification/plan/MFA booleans. Response bodies are accepted
only within 65536 bytes; Playwright buffers transport bytes before that check.
No password login, refresh-token exchange or lookup retry runs automatically.
AbuseIPDB uses the same shared HTTP context reader for account identity and the
native HTTP reader for APIv2. Its identity parser scopes the email to the
account-basics form: unrelated feedback email and password-change fields must
not imply a different account or a login page. API observations bind the public
test target and project only score/country; personal account fields stay private.

October 26 verification adopted the myutils text browser's native hidden engine,
`@myutils/browser-session/chrome`. It proves the target has no OS window, keeps
the browser sandbox and uses explicit routes; it is distinct from ordinary
headless Chrome. AbuseIPDB saved login and HTTP identity passed. Cloudflare
required human verification after submission. ipapi terms were accepted with
explicit user permission, but its authenticated dashboard reports `bot_login`
suspension and its API returns 403. One separately authorized visible Chrome
password login reached the same suspended account. Automatic ipapi password
submission is disabled; saved HTTP reads distinguish authentication from
`account_suspended`/`apiUsable:false`. Provider support must restore the account.
These gates do not trigger another password submission or an automatic GUI. A caller may explicitly
request `visible=true` for a human recovery step. Existing state is preserved.

## Reporter public-page recovery

The provider-owned `dbip-page.mjs` is also imported by offline tests and called
by the reporter after an explicit visitor-demo daily limit. It is a public-page
projection, not another MCP server or account login. It directly reuses
`@myutils/web-text/browser-text`, with a fresh native hidden Chrome profile,
lease 19606, bounded read, target binding and verified cleanup. It follows the
reporter's HTTPS proxy environment, not this MCP's default account route.
Only `--confirm-network-lookup` plus a single stdin `{ip: ...}` request enables
the CLI read. It saves no cookies, visitor keys or page cache. Dependencies are
restored from the shared reviewed workspace lockfile; there is no runtime install.

## HTTP state recovery

After an authorized login, `provider_account_open` on ipapi's `dashboard`
refreshes `.state/ipapi-http.json` only after exact account recognition.
`provider_account_read` with `mode=browser` only inspects the page.

Cloudflare's generic open/read tools do not refresh `.state/cloudflare-http.json`.
The package currently has no dedicated MCP tool for that step. Authorized
maintenance can use `withSession('cloudflare', identityOnPage)`, importing
`withSession` from `accounts.mjs` and `identityOnPage` from `cloudflare.mjs`.
This checks the authenticated browser's `/api/v4/user`, saves state only for the
expected identity, and returns boolean metadata. It does not create an API token
or change 2FA. Then `cloudflare_account_check` can validate the saved HTTP path.

For AbuseIPDB, open `surface=login` only when the HTTP check requires recovery.
After the authorized login, inspect `/account` with `withSession('abuseipdb', ...)`
and `httpAccountIdentity` against `privateAccount('abuseipdb').email`. Save the
context to `httpStatePath('abuseipdb')` with shared `saveStorageStateSafely` only
after that exact identity matches. Then check HTTP with Chrome closed.
Account creation and key import are separate reviewed maintenance operations:
preserve one-submit receipts, inspect the free individual plan and labelled key,
and privately write `secrets/abuseipdb` without replacing an existing different
key. Registration email, name and additional personal disclosures need the user's
authorization. Check public-profile/domain visibility after signup; the October
11 registration defaulted both to on, and both were disabled. Do not submit abuse
reports, subscribe to a paid plan or copy account HTML into Git.

## Private files and lifetime

The path/format index is [../../CREDENTIALS.md](../../CREDENTIALS.md).
Registration identity is ../../secrets/accounts/registration-email. Passwords,
submission receipts, API proof, TOTP URI and recovery codes stay in private
../../secrets/accounts/provider directories; raw API keys use the reporter's
flat secrets/ipapi, secrets/cloudflare_token and secrets/abuseipdb paths.

Temporary profiles are under `.state/sessions/{provider}/`, with dynamic
loopback CDP ports and operation leases at 19603/19604/19605. Native sessions
are retained within this server for multi-step flows; the shared worker cleans
them on close, controller exit or the 30-minute lifetime limit. Verified HTTP
state and pending terms/verification state are separate owner-only files. The
legacy `.state/{provider}` profiles remain private recovery data.
PROVIDER_ACCOUNTS_PROXY chooses a credential-free HTTP proxy only for this
package. Set it to DIRECT for explicit direct access: Chrome receives
--no-proxy-server and bypasses macOS system proxy preferences. The shared engine
verifies actual launch routing; an explicit route change closes and replaces
only this server's owned session. Local CDP traffic stays direct;
when launching a child through an isolated ATT session, pass its proxy with that
variable and retain localhost in NO_PROXY. No live Clash setting changes.
The shared worker verifies owned process shutdown and removes its temporary
profile. Close a temporary ATT browser before its private Mihomo exits.

Passwords are random and saved before signup. Durable receipts prevent automatic
duplicate registration/token/enrollment submissions after timeouts. Registration
may be retried on a different route only after explicit user direction and review
of the prior outcome; preserve the prior receipt. CAPTCHA is left for the user.
No billing, upgrade, email-send, generic arbitrary-selector or recovery-code
regeneration tool is exposed. Public results never include credentials, codes,
seeds, cookies, account IDs or verification URL tokens.

ipdata was registered once on October 27 after explicit disclosure approval,
verified by email and confirmed as Free Tier/$0/1,500 daily queries. The private
reporter key is `secrets/ipdata`; its saved Cognito state is
`.state/ipdata-http.json`. Both the native hidden login and restored native
headless dashboard/Profile were verified with shared myutils Chrome. Profile
offered name/email/password fields but no 2FA control; no enrollment was made.
The API returned proxy/Tor/datacenter/abuse flags on direct and ATT; VPN was
absent. Saved-token expiry requires authorized session recovery, not a new
account or API key. Preserve the private signup/activation/login receipts.

## Dated account evidence

Signup, key, 2FA and HTTP-identity proofs for these accounts, plus the lessons
learned from them, are summarized in [../../MCP.md](../../MCP.md#latest-live-account-evidence).
They are dated observations, not current session or route guarantees; private
receipts stay under `../../secrets/accounts/`.

## Module APIs

Inside `mcp/provider-accounts`, `accounts.mjs::withSession` owns the shared
provider profile binding and lease, `privateAccount` validates saved identities,
and `policy.mjs::accountNetworkOptions` validates a task-scoped browser/API route.
Its explicit `DIRECT` mode selects the shared native browser's verified direct
route. The shared lifecycle verifies process/profile/route ownership; the MCP
replaces only its own session when an explicit route/display mode changes.
`login.mjs` owns reviewed POST forms and distinct credential/terms/verification
outcomes and stops ipapi automated login locally after the observed suspension.
`../common/browser-state.mjs` restores only the selected site's state.
`cloudflare.mjs`
owns its fixed account paths, server identity check and token policy; its TOTP
consumer reuses these directly. `cloudflare-policy.mjs` contains fixture-testable
identity, token scope, response and API-before-MFA decisions. MCP action entrypoints
return metadata only; secrets stay inside their private-file and HTTP/form calls.

IPQS enrollment/challenge policy stays in `mcp/ipqs/src/totp.ts`. Provider-account
HTTP helpers live in `mcp/provider-accounts/http-account.mjs`:

| Function | Input / output |
| --- | --- |
| `httpStatePath(provider)` | Validates `ipapi`/`cloudflare`/`abuseipdb` and returns its absolute private HTTP-state path |
| `httpAccountIdentity(provider, status, contentType, body, expectedEmail)` | Pure provider-specific identity check; returns booleans/status metadata without email or response content |
| `readHttpAccount(provider, expectedEmail, dependencies = {})` | One bounded HTTP GET using private saved state; returns identity/status metadata, disposes its HTTP context, and starts no Chrome. Tests can inject secret/context/response readers |

Cloudflare's `identityOnPage(page)` verifies the active browser's server identity
before refreshing saved HTTP state. Ordinary HTTP checks only consume that state;
see [recovery guidance](#http-state-recovery).

AbuseIPDB's identity parsing (see [Tools and workflow](#tools-and-workflow))
also requires the logout action. Its API observation validation stays in
`abuseipdb.mjs`; it is not a generic reputation schema.

The same MCP owns `public-api.mjs::verifyPublicProvider(provider, confirmation,
request, surface)` for DB-IP/IPWHOIS. The MCP selects `free_api` (default) or
`public_demo`, with literal confirmation `VERIFY_FREE_API`; the optional
`request` function injects the offline transport in place of shared `http-read`.

| Surface | Requests and observation |
| --- | --- |
| Either provider's `free_api` | One lookup for `1.1.1.1`; geography/network context |
| IPWHOIS `public_demo` | One lookup for `1.1.1.1` with website headers; supplied security booleans |
| DB-IP `public_demo` | One page, then one visitor lookup using an in-memory guest token; `request_egress`, with an optional threat label |

`publicProviderObservation(provider, body, expected, surface)` returns a validated
projection or `null`. The caller validates DB-IP's returned IP before projecting
its egress observation; other lookups must match `1.1.1.1`. Results carry query
status, the observation and account/MFA/risk capabilities. Missing fields stay
null; HTTP 200 quota errors become `rate_limited` or DB-IP's explicit
`daily_quota_exhausted`, without retries or enrollment.
