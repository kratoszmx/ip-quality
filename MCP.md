# Account MCP servers

Two optional stdio MCP servers maintain the provider accounts and keys that the
reporter can use. The reporter itself needs neither server running and never
uses their browser sessions. Both are workspaces of `mcp/package.json`, sharing
one reviewed lockfile and the sibling `/Users/zmx/Projects/myutils` packages
(see [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md#account-mcp-shared-packages)).

| Server | Package guide | Start (from the project root) | Use it for |
| --- | --- | --- | --- |
| `codex-ipqs-mcp` | [mcp/ipqs/AGENTS.md](mcp/ipqs/AGENTS.md) | `npm --prefix mcp/ipqs run build`, then `npm --prefix mcp/ipqs start` | Official IPQS API usage/lookups, dashboard reads, saved login and private TOTP |
| `ipquality-provider-accounts` | [mcp/provider-accounts/AGENTS.md](mcp/provider-accounts/AGENTS.md) | `npm --prefix mcp/provider-accounts start` (no build) | ipapi/Cloudflare/AbuseIPDB/ipdata account maintenance; account-free DB-IP/IPWHOIS probes |

Offline checks are in [TESTING.md](TESTING.md); process and browser lifetime in
[SERVICES.md](SERVICES.md); private file formats in [CREDENTIALS.md](CREDENTIALS.md).
Account mutations (signup, key import, setting changes, 2FA enrollment) need
explicit task intent; each tool also demands a literal confirmation argument
(`confirm` for IPQS, `confirmation` for provider accounts).

## Choose a first call

Tool names are server-local; a client may add its own prefix. Readiness calls are
offline. Live MCP reads run when called; the reporter's
`--confirm-network-lookup` flag does not apply to MCP tools.

| Need | Tool | Arguments | Network / meaning |
| --- | --- | --- | --- |
| IPQS local readiness | `ipqs_status` | `{"probeBrowser":false}` | None; saved files are not proof of login or credits |
| ipapi/Cloudflare local readiness | `provider_account_status` | `{"provider":"ipapi"}` | None; use `cloudflare` for that account |
| AbuseIPDB local readiness | `abuseipdb_account_status` | `{}` | None; account/key presence only |
| ipdata local readiness | `ipdata_account_status` | `{}` | None; account/key/session presence only |
| IPQS account/API acceptance | `ipqs_account_usage` | `{}` | One live account read; no lookup credit |
| ipapi saved-session identity | `provider_account_read` | `{"provider":"ipapi","mode":"http"}` | Live HTTP, no Chrome; inspect `authenticated` and `state` |
| Cloudflare identity and 2FA state | `cloudflare_account_check` | `{}` | Live HTTP, no Chrome or Intel lookup |
| AbuseIPDB identity and privacy settings | `abuseipdb_account_check` | `{}` | Live HTTP; exact saved account, email-verification and public-profile booleans |
| AbuseIPDB free API proof | `abuseipdb_verify_free_api` | `{"confirmation":"VERIFY_FREE_API"}` | One official `1.1.1.1` CHECK; no browser or abuse report |
| ipdata saved-session identity | `ipdata_account_check` | `{}` | One read-only Cognito GetUser HTTP POST; exact saved email and reporter-key comparison, no browser or IP lookup |
| ipdata free API proof | `ipdata_verify_free_api` | `{"confirmation":"VERIFY_FREE_API"}` | One official `1.1.1.1` query; returns only supplied risk flags, no browser |
| DB-IP free geography probe | `public_provider_verify_free_api` | `{"provider":"dbip","surface":"free_api","confirmation":"VERIFY_FREE_API"}` | One live `1.1.1.1` lookup; context, not a risk verdict |

For website risk observations choose `surface: "public_demo"`: IPWHOIS tests
`1.1.1.1`, while DB-IP reads a page and the requesting egress. Field availability
and quotas differ from `free_api`; see [providers/dbip.md](providers/dbip.md).

## Access methods

HTTP with saved cookies reuses an earlier login; it is not a fresh password login.
Playwright's `request.newContext` is an HTTP client and starts no browser.
Browser operations reuse the same `@myutils/browser-session/chrome` native
`hidden` engine as myutils' text browser: Chrome has a verified hidden CDP
target with no OS window, rather than a minimized GUI. Ordinary `headless`
is a different mode and still received IPQS HTTP 403 on October 26.

| Platform | Routine access | Fresh login or recovery | 2FA |
| --- | --- | --- | --- |
| IPQS | API and saved-session auth check over HTTP; dashboard content/controls through native hidden Chrome | Windowless saved credentials + reviewed TOTP; verified October 26 | TOTP enabled |
| ipapi.is | Saved-state HTTP dashboard read; API currently HTTP 403 | Automated login disabled after `bot_login` account suspension. October 26 authorized visible Chrome login also succeeded but did not remove the suspension | No enrollment entry offered |
| Cloudflare | Saved-state HTTP identity read; Intel token over HTTP | Native hidden Chrome; October 26 password flow required human verification; Intel API still passed | TOTP enabled, recovery codes saved |
| AbuseIPDB | Saved-state HTTP account read; APIv2 key over HTTP | Native hidden Chrome; login and subsequent HTTP identity verified October 26 | No enrollment entry offered |
| ipdata | Saved-token HTTP account check; owned free developer key over HTTP | October 27 one authorized native-hidden signup/login; saved state also verified in native headless Chrome. No automatic password submission or token refresh | No enrollment control on the reviewed Profile page; GetUser returned no enrolled factor |
| Ipregistry | API key in the reporter only | No account MCP | Not audited |
| DB-IP | Account-free HTTP free API and visitor demo; reporter daily-limit fallback reads the exact public IP page in fresh hidden Chrome via myutils/web-text | None; no account state | Not applicable |
| IPWHOIS | Account-free HTTP free API and website demo | None | Not applicable |
| IPinfo, Scamalytics, IP2Location, Check.Place, Ping0, RIPEstat, Shodan | Public HTTP pages/demos/relays used by the reporter | None | Not applicable |

A failed HTTP identity read returns its failure; it never silently opens a
browser, submits credentials, retries or treats a saved file as success.
Default browser tools also open no window. `visible=true` is an explicit
human-recovery exception; no failure automatically switches to GUI. Pending
terms/verification cookies are stored separately from verified HTTP state and
do not establish authentication. Existing manual tools remain available.

October 26 local inventory confirms that this project has no DB-IP account
credentials, owned API key or saved HTTP/browser login state. No DB-IP signup,
login or subscription trial has been performed. Reading its public offers or
website through a browser is not account authentication.

## Lessons from setup and recovery

- Clearing proxy environment variables leaves Chrome on the macOS system proxy;
  use `PROVIDER_ACCOUNTS_PROXY=DIRECT` (Chrome gets `--no-proxy-server`).
- October 26 IPQS native-hidden password + TOTP login succeeded, and the fresh
  saved state passed an independent HTTP dashboard check. Older failed HTTP
  snapshots do not establish that HTTP is intrinsically unsupported.
- A loaded login page is not successful login. Cloudflare's hidden page loaded
  but its submitted flow required a challenge. No automatic credential retry.
- After explicit user approval, ipapi's October 3 terms were accepted on
  October 26. Exact-account HTTP identity passed, but the dashboard explicitly
  reported `bot_login` suspension for automated browser sign-in. The stored key
  matches the dashboard; API HTTP 403 is not a stale-key or pending-terms result.
  One subsequently authorized real visible Chrome password login reached the
  same suspended account. Automatic ipapi password submission is now disabled;
  a later authorized normal key regeneration produced a new key but its first
  lookup still returned HTTP 403/INVALID_API_KEY. The reporter key was updated
  privately; the suspended account did not become usable through rotation.
- Signups through proxy routes were rejected: ipapi succeeded only on explicit
  DIRECT, and AbuseIPDB's fresh ATT headless signup needed its dedicated headed
  profile.
- Cloudflare's login widget auto-submits a complete six-digit code; inspect
  navigation/identity before clicking a Verify button that may have vanished.
- AbuseIPDB's new account defaulted public profile and domain visibility to on;
  both were turned off and read back.
- ipdata's keyless geography API and $0 developer account have different
  capabilities. October 27 user-approved signup and email activation yielded
  1,500 daily queries with risk flags. A native headless Chrome session restored
  only this account's saved state through myutils, following the shared approach
  used by RedNote. Its account check now uses a fixed HTTP GetUser request.
  The missing VPN field stays unknown; no value is inferred from other flags.
- Prove API usefulness before enrolling 2FA, save seeds and recovery codes
  before activation, and keep one-submit receipts so timeouts never cause a
  duplicate signup, token or enrollment.

## Latest live account evidence

Dated observations, not availability guarantees; private receipts stay under
`secrets/accounts/` and each MCP's `.state/`.

| Date | Evidence |
| --- | --- |
| 2026-10-27 | ipdata free developer account, email activation and API key verified; dashboard showed Free Tier/$0/1,500 daily queries. Direct and isolated ATT reporter runs returned official risk flags. Native headless dashboard/Profile and browserless GetUser proved the same account/key; no MFA control observed. ipapi HTTP account remained suspended, keyed API returned ERR_FORBIDDEN_NOT_ALLOWED, while the anonymous API root returned geography. Private evidence and unsent appeal draft: `reports/provider-recheck-20261027/`. |
| 2026-10-26 | IPQS direct IPv4 login + TOTP and API passed; ATT curl still failed pre-HTTP TLS, including a pinned IPv4/TLS 1.2 test. Native-hidden IPQS login and restored hidden dashboard passed; HTTP auth passed. AbuseIPDB native-hidden login and HTTP identity passed; public profile/domain still off. Cloudflare challenge remains, while Intel API passed. ipapi terms accepted with user permission; both hidden and explicit visible Chrome reached the account, but `bot_login` suspension/API 403 persists. Private evidence/drafts: `reports/ipqs-support-20261026-rerun/`; no follow-up sent. |
| 2026-10-23 | Reporter direct and ATT runs returned official IPQS and Cloudflare results with the saved keys (see [HANDOFF.md](HANDOFF.md#latest-saved-live-evidence)) |
| 2026-10-10 to 10-12 | IPQS account API passed over direct IPv6 and `awshk` while ATT failed TLS before HTTP; Cloudflare Intel passed, including through ATT |
| 2026-10-11 | AbuseIPDB free signup, email verification and one owned key; HTTP identity, privacy booleans and API proof passed with Chrome closed |
| 2026-09-24 | IPQS TOTP enrollment, real challenge and fresh-profile login; ipapi and Cloudflare HTTP identity with Chrome closed; Cloudflare TOTP and recovery codes server-confirmed |
| 2026-09-22 | ipapi free signup on DIRECT (1,000/day plan, full-response key); Cloudflare free signup and an account-scoped, non-expiring Intel Read token returning useful data |

## Routine verification and recovery

- IPQS: `npm --prefix mcp/ipqs run probe:sanitized` performs one non-lookup
  account read; `npm --prefix mcp/ipqs run auth:check` checks private saved
  HTTP state without Chrome. Authorized recovery uses `ipqs_login_with_saved_credentials`
  (`confirm=USE_SAVED_IPQS_CREDENTIALS`), completing one reviewed TOTP challenge;
  `ipqs_complete_totp` (`confirm=USE_SAVED_IPQS_TOTP`) handles a pending one.
- Provider accounts: `provider_account_login` with
  `confirmation=USE_SAVED_ACCOUNT_CREDENTIALS` checks existing HTTP identity
  then permits one reviewed windowless Cloudflare/AbuseIPDB password submission.
  ipapi returns a local manual-recovery requirement without reading credentials
  or launching Chrome. Updated terms,
  human verification, rejected credentials and unconfirmed outcomes remain
  distinct. `provider_account_close_browsers` closes this server's owned
  browsers. `provider_account_open` opens one allowlisted page and
  `provider_account_read` with `mode=browser` inspects it. A verified ipapi
  dashboard visit refreshes its HTTP state; Cloudflare and AbuseIPDB need the
  steps in [HTTP state recovery](mcp/provider-accounts/AGENTS.md#http-state-recovery).
  Close the owned browser before changing its route or visibility.
- Enrollment: `ipqs_enable_totp` (`confirm=ENABLE_IPQS_TOTP`) verifies usable
  credits, binds issuer/account from the textual QR URL, saves seed/recovery data
  and reserves the one submission; Cloudflare keeps its API-before-2FA rule.
- ipdata: `ipdata_account_check` reads its saved access token with no refresh or
  login retry. `login_required` can mean that short-lived token expired; it does
  not establish an invalid API key. `ipdata_verify_free_api` independently
  checks the reporter key. Authorized session recovery restores only ipdata's
  dedicated state with shared myutils Chrome, verifies the exact email and
  labelled key, then saves `.state/ipdata-http.json`. Do not repeat signup.

A past audit's authorization for recovery or 2FA is not a standing instruction;
documentation and test work never repeats enrollment.
