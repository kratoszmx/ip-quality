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

Fresh dashboard reads share [myutils's account-read contract](/Users/zmx/Projects/myutils/docs/ACCOUNT_BROWSER_READS.md).
This does not apply GET-only policy to login/2FA/confirmed writes. Private state
belongs to its provider, and cleanup warnings remain distinct from authentication.

## Normal site verification

There is no blanket prohibition on agent-assisted CAPTCHA handling. Browser
login/setup flows prepare normal Cloudflare checkbox verification through
myutils's native input on the same owned page before deciding readiness. A
single activation and bounded settling replace the old immediate stop. Completed
verification response fields do not themselves establish account authentication;
the exact account still has to pass its original identity check. An unresolved
check remains explicit and preserves the retained page. The DB-IP reporter
fallback uses myutils's automatic public-page path for the same preparation. A
block page without a verification control (Check.Place) is a different outcome,
not a pending check.

## Choose a first call

Tool names are server-local; a client may add its own prefix. Readiness calls are
offline. Live MCP reads run when called; the reporter's
`--confirm-network-lookup` flag does not apply to MCP tools.

| Need | Tool | Arguments | Network / meaning |
| --- | --- | --- | --- |
| IPQS local readiness | `ipqs_status` | `{"probeBrowser":false}` | None; saved files are not proof of login or credits |
| ipapi/Cloudflare local readiness | `provider_account_status` | `{"provider":"ipapi"}` | None; use `cloudflare` for that account |
| AbuseIPDB local readiness | `abuseipdb_account_status` | `{}` | None; account/key presence only |
| ipdata local readiness | `ipdata_account_status` | `{}` | None; account/key presence only |
| IPQS account/API acceptance | `ipqs_account_usage` | `{}` | One live account read; no lookup credit |
| ipapi session identity | `provider_account_read` | `{"provider":"ipapi","mode":"http"}` | Live HTTP with the shared profile's cookies, no page; inspect `authenticated` and `state` |
| Cloudflare identity and 2FA state | `cloudflare_account_check` | `{}` | Live HTTP, no page or Intel lookup |
| AbuseIPDB identity and privacy settings | `abuseipdb_account_check` | `{}` | Live HTTP; exact saved account, email-verification and public-profile booleans |
| AbuseIPDB free API proof | `abuseipdb_verify_free_api` | `{"confirmation":"VERIFY_FREE_API"}` | One official `1.1.1.1` CHECK; no browser or abuse report |
| ipdata session identity | `ipdata_account_check` | `{}` | One read-only Cognito GetUser HTTP POST with the dashboard token from the shared profile; exact saved email and reporter-key comparison, no page or IP lookup |
| ipdata free API proof | `ipdata_verify_free_api` | `{"confirmation":"VERIFY_FREE_API"}` | One official `1.1.1.1` query; returns only supplied risk flags, no browser |
| DB-IP free geography probe | `public_provider_verify_free_api` | `{"provider":"dbip","surface":"free_api","confirmation":"VERIFY_FREE_API"}` | One live `1.1.1.1` lookup; context, not a risk verdict |

For website risk observations choose `surface: "public_demo"`: IPWHOIS tests
`1.1.1.1`, while DB-IP reads a page and the requesting egress. Field availability
and quotas differ from `free_api`; see [providers/dbip.md](providers/dbip.md).

## Access methods

Since 2026-11-21 (見微: "把我們的所有登入態挪到文字瀏覽器的chrome專屬設定檔裡,以後都放在那邊")
every login of both MCPs lives only in the shared Chrome profile, the text
browser's saved profile, and is used only through the one dedicated Chrome on
it (CDP port 19551). HTTP reads carry that profile's cookies for the request
(`readSharedChromeCookies`) and write back the cookies the site changed
(`writeSharedChromeCookies`); they reuse an earlier login and are not a fresh
password login. Playwright's `request.newContext` is an HTTP client and opens no
page. Browser operations are hidden background tabs of that Chrome
(`withDedicatedChrome` with `sharedChromeRuntime`), with no OS window; the
packages never launch Chrome on a profile of their own. Ordinary `headless` is
a different mode and received IPQS HTTP 403 on November 5. The HTTP text reader
imports shared bounded transport and static parsing directly; it does not fall
back to a browser. A Chrome that cannot start outside the owner's GUI session is
reported as browser unavailable, never as logged out.

| Platform | Routine access | Fresh login or recovery | 2FA |
| --- | --- | --- | --- |
| IPQS | API, auth and default dashboard text over HTTP with the shared profile's cookies; explicit controls in a hidden tab | Saved credentials + reviewed TOTP in a hidden tab of the shared Chrome | TOTP enabled |
| ipapi.is | Replacement free account: keyed HTTP risk API and HTTP dashboard with the shared profile's cookies, verified October 28 | HTTP identity first; an expired session uses the normal `/app/` Sign In form in a hidden tab of the shared Chrome, with checkbox preparation. Form verified November 19; account recovery is evaluated from the server response | No enrollment entry in the reviewed dashboard |
| Cloudflare | HTTP identity read with the shared profile's cookies; Intel token over HTTP | Hidden tab of the shared Chrome; October 26 password flow required human verification; Intel API still passed | TOTP enabled, recovery codes saved |
| AbuseIPDB | HTTP account read with the shared profile's cookies; APIv2 key over HTTP | Hidden tab of the shared Chrome; login and subsequent HTTP identity verified October 26 | No enrollment entry offered |
| ipdata | HTTP GetUser with the dashboard's Cognito token from the shared profile's localStorage; owned free developer key over HTTP | October 27 one authorized signup/login. No automatic password submission or token refresh; an expired token is renewed by opening the dashboard once in the shared Chrome | No enrollment control on the reviewed Profile page; GetUser returned no enrolled factor |
| Ipregistry | API key in the reporter only | No account MCP | Not audited |
| DB-IP | Account-free HTTP free API and visitor demo; reporter daily-limit fallback reads the exact public IP page in fresh hidden Chrome via myutils/web-text | None; no account state | Not applicable |
| IPWHOIS | Account-free HTTP free API and website demo | None | Not applicable |
| IPinfo, Scamalytics, IP2Location, Check.Place, Ping0, RIPEstat, Shodan | Public HTTP pages/demos/relays used by the reporter | None | Not applicable |

A failed HTTP identity read returns its failure; it never silently opens a
browser, submits credentials, retries or treats a saved file as success.
`PROVIDER_ACCOUNTS_PROXY=DIRECT` is refused with a fixed error (見微: the system
proxy only). The shared Chrome always uses web-text's `SYSTEM_PROXY_SERVER`; with
no proxy configured, HTTP reads use it too, so one session keeps one exit.
`PROVIDER_ACCOUNTS_PROXY` and `IPQS_PROXY_SERVER` select a different route for
HTTP/API reads only.
Default browser tools also open no window. `visible=true` opens a window of the
same Chrome as an explicit human-recovery exception; no failure automatically
switches to GUI. Cookies of an unfinished login (terms, verification) are the
profile's own and do not establish authentication.

## Saved-login protection

The November 10 Steam investigation established that launching a saved native
Chrome profile outside macOS's GUI login session can discard its encrypted
cookies when the login keychain is unavailable. The shared Chrome therefore
starts only in the GUI (Aqua) session: myutils refuses the launch elsewhere with
`CHROME_KEYCHAIN_SESSION_UNAVAILABLE`, which these MCPs report as
`browser_unavailable`/`unavailable`, not as a logout. Do not disable that guard
and never launch Chrome (or a Playwright persistent context) on the shared
profile directly. DB-IP has no saved login. The former per-MCP profiles and
session files stay on disk untouched as rollback data; nothing reads them.
Process details: [SERVICES.md](SERVICES.md#account-mcp-start-and-stop).

October 26 local inventory confirms that this project has no DB-IP account
credentials, owned API key or saved HTTP/browser login state. No DB-IP signup,
login or subscription trial has been performed. Reading its public offers or
website through a browser is not account authentication.

## Lessons from setup and recovery

- Clearing proxy environment variables leaves Chrome on the macOS system proxy.
  `PROVIDER_ACCOUNTS_PROXY=DIRECT` is refused since text browser 0.6.1.
- October 26 IPQS native-hidden password + TOTP login succeeded, and the fresh
  saved state passed an independent HTTP dashboard check. Older failed HTTP
  snapshots do not establish that HTTP is intrinsically unsupported.
- A loaded login page is not successful login. Cloudflare's hidden page loaded
  but its submitted flow required a challenge. No automatic credential retry.
- ipapi suspended the former account for `bot_login` (automated browser
  sign-in). Its API 403 was neither a stale key nor pending terms, and neither a
  visible password login nor a key regeneration made it usable; only a
  replacement account (October 28) restored keyed risk data.
- A signup that rejects automated browsers can be completed by the user in
  ordinary non-CDP Chrome. Prove the new key on direct and proxy routes before
  promoting it, then export the session once and maintain it over HTTP.
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
`secrets/accounts/` and `reports/`.

| Date | Evidence |
| --- | --- |
| 2026-11-21, shared Chrome profile | After the login move: AbuseIPDB and ipapi saved-credential logins in a hidden tab of the shared Chrome, then HTTP identity with the shared cookies passed (ipapi after accepting its new `#email-tf`/`#api-key` fields). ipdata's dashboard session was copied into the shared profile and refreshed by its own web app; GetUser passed (free plan, key matches). IPQS password + TOTP (new `type=text` challenge) reached the dashboard, which now requires accepting updated Terms/Privacy; the account API passed. Cloudflare login ended at `/login` with `/api/v4/user` 403. |
| 2026-11-19, normal verification | `https://db-ip.com/1.1.1.1` first returned HTTP 403; a fresh hidden native read then returned HTTP 200, the matching record and explicit LOW label with `nativeRecovery.verificationActivated=true` and confirmed cleanup. Check.Place still showed its block page with no verification control. Cloudflare's login form loaded in Firefox and native hidden Chrome; no credentials were submitted. ipapi's official `/app/` Sign In form returned HTTP 200. Private receipts: `reports/verification-20261119/`, `reports/ipapi-login-policy-20261119/`. |
| 2026-11-05, IPQS recovery | Authorized native-hidden saved-credential + TOTP login and independent HTTP auth passed. Default saved-session HTTP text and native-hidden controls both proved authentication with 3,000 characters; controls returned six value-free entries and confirmed cleanup. The incompatible isolated headless reader returned 403 and is no longer used for IPQS. No reputation lookup. Private receipts: `reports/browser-recovery-20261105-PqCmOh/`. |
| 2026-10-28, replacement ipapi account | User-completed signup, mail-manager activation and previously approved October 3 terms led to the exact new free account (1,000 daily queries). Labelled key and full-risk API passed direct and default-proxy checks. Reporter returned full keyed type/score/factors. Owned GUI closed; myutils headless recovery, native-hidden MCP dashboard and browser-closed HTTP identity/API passed. Canonical credentials/session promoted; former account archived. Evidence: `reports/ipapi-account-20261028/`. |
| 2026-10-27, candidate ipapi account | Direct visible CDP signup explicitly rejected automation; the parser distinguishes `automated_browser_blocked`. The manual alternative used myutils `openRealChrome`, a persistent private profile and native Accessibility text controls bound to the owned PID and signup URL. No CDP, screenshots or automatic Signup click. The handoff completed October 28 as recorded above. |
| 2026-10-27 | ipdata free developer account, email activation and API key verified; dashboard showed Free Tier/$0/1,500 daily queries. Direct and isolated ATT reporter runs returned official risk flags. Native headless dashboard/Profile and browserless GetUser proved the same account/key; no MFA control observed. ipapi HTTP account remained suspended, keyed API returned ERR_FORBIDDEN_NOT_ALLOWED, while the anonymous API root returned geography. Private evidence and unsent appeal draft: `reports/provider-recheck-20261027/`. |
| 2026-10-26 | IPQS direct IPv4 login + TOTP and API passed; ATT curl still failed pre-HTTP TLS, including a pinned IPv4/TLS 1.2 test. Native-hidden IPQS login and restored hidden dashboard passed; HTTP auth passed. AbuseIPDB native-hidden login and HTTP identity passed; public profile/domain still off. Cloudflare challenge remains, while Intel API passed. ipapi terms accepted with user permission; both hidden and explicit visible Chrome reached the account, but `bot_login` suspension/API 403 persists. Private evidence/drafts: `reports/ipqs-support-20261026-rerun/`; no follow-up sent. |
| 2026-10-23 | Reporter direct and ATT runs returned official IPQS and Cloudflare results with the saved keys (see [HANDOFF.md](HANDOFF.md#latest-saved-live-evidence)) |
| 2026-10-10 to 10-12 | IPQS account API passed over direct IPv6 and `awshk` while ATT failed TLS before HTTP; Cloudflare Intel passed, including through ATT |
| 2026-10-11 | AbuseIPDB free signup, email verification and one owned key; HTTP identity, privacy booleans and API proof passed with Chrome closed |
| 2026-09-24 | IPQS TOTP enrollment, real challenge and fresh-profile login; ipapi and Cloudflare HTTP identity with Chrome closed; Cloudflare TOTP and recovery codes server-confirmed |
| 2026-09-22 | ipapi free signup on DIRECT (1,000/day plan, full-response key); Cloudflare free signup and an account-scoped, non-expiring Intel Read token returning useful data |

## Routine verification and recovery

- IPQS: `npm --prefix mcp/ipqs run probe:sanitized` performs one non-lookup
  account read; `npm --prefix mcp/ipqs run auth:check` checks the shared
  profile's session over HTTP without a page. Authorized recovery uses `ipqs_login_with_saved_credentials`
  (`confirm=USE_SAVED_IPQS_CREDENTIALS`), completing one reviewed TOTP challenge;
  `ipqs_complete_totp` (`confirm=USE_SAVED_IPQS_TOTP`) handles a pending one.
- Provider accounts: `provider_account_login` with
  `confirmation=USE_SAVED_ACCOUNT_CREDENTIALS` checks existing HTTP identity
  then uses the official ipapi/Cloudflare/AbuseIPDB login form in a hidden tab of the shared Chrome when
  a new session is needed. An authenticated account response is reused with its
  actual service status, including suspension where reported. Updated terms,
  human verification, rejected credentials and unconfirmed outcomes remain
  distinct. `provider_account_close_browsers` releases this server's kept tab.
  `provider_account_open` opens one allowlisted page in a kept hidden tab and
  `provider_account_read` with `mode=browser` reads the dashboard in a tab of
  its own. The login lands in the shared profile itself; see
  [session recovery](mcp/provider-accounts/AGENTS.md#session-recovery).
- Enrollment: `ipqs_enable_totp` (`confirm=ENABLE_IPQS_TOTP`) verifies usable
  credits, binds issuer/account from the textual QR URL, saves seed/recovery data
  and reserves the one submission; Cloudflare keeps its API-before-2FA rule.
- ipdata: `ipdata_account_check` reads the dashboard's access token from the
  shared profile with no refresh or login retry. `login_required` can mean that
  short-lived token expired; it does not establish an invalid API key.
  `ipdata_verify_free_api` independently checks the reporter key. Opening
  https://dashboard.ipdata.co once in the shared Chrome lets its own web app
  refresh or sign in; then repeat the check. Do not repeat signup.

A past audit's authorization for recovery or 2FA is not a standing instruction;
documentation and test work never repeats enrollment.
