# Account MCP servers

Two optional stdio MCP servers maintain the provider accounts and keys that the
reporter can use. The reporter itself needs neither server running and never
uses their browser sessions. Both are workspaces of `mcp/package.json`, sharing
one reviewed lockfile and the sibling `/Users/zmx/Projects/myutils` packages
(see [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md#account-mcp-shared-packages)).

| Server | Package guide | Start (from the project root) | Use it for |
| --- | --- | --- | --- |
| `codex-ipqs-mcp` | [mcp/ipqs/AGENTS.md](mcp/ipqs/AGENTS.md) | `npm --prefix mcp/ipqs run build`, then `npm --prefix mcp/ipqs start` | Official IPQS API usage/lookups, dashboard reads, saved login and private TOTP |
| `ipquality-provider-accounts` | [mcp/provider-accounts/AGENTS.md](mcp/provider-accounts/AGENTS.md) | `npm --prefix mcp/provider-accounts start` (no build) | ipapi/Cloudflare/AbuseIPDB account maintenance; account-free DB-IP/IPWHOIS probes |

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
| IPQS account/API acceptance | `ipqs_account_usage` | `{}` | One live account read; no lookup credit |
| ipapi saved-session identity | `provider_account_read` | `{"provider":"ipapi","mode":"http"}` | Live HTTP, no Chrome; inspect `authenticated` and `state` |
| Cloudflare identity and 2FA state | `cloudflare_account_check` | `{}` | Live HTTP, no Chrome or Intel lookup |
| AbuseIPDB identity and privacy settings | `abuseipdb_account_check` | `{}` | Live HTTP; exact saved account, email-verification and public-profile booleans |
| AbuseIPDB free API proof | `abuseipdb_verify_free_api` | `{"confirmation":"VERIFY_FREE_API"}` | One official `1.1.1.1` CHECK; no browser or abuse report |
| DB-IP free geography probe | `public_provider_verify_free_api` | `{"provider":"dbip","surface":"free_api","confirmation":"VERIFY_FREE_API"}` | One live `1.1.1.1` lookup; context, not a risk verdict |

For website risk observations choose `surface: "public_demo"`: IPWHOIS tests
`1.1.1.1`, while DB-IP reads a page and the requesting egress. Field availability
and quotas differ from `free_api`; see [providers/dbip.md](providers/dbip.md).

## Access methods

HTTP with saved cookies reuses an earlier login; it is not a fresh password login.
Playwright's `request.newContext` is an HTTP client and starts no browser; a
hidden headed Chrome still counts as a GUI browser.

| Platform | Routine access | Fresh login or recovery | 2FA |
| --- | --- | --- | --- |
| IPQS | API key over native HTTP; dashboard reads are same-origin fetches inside retained headed Chrome | GUI Chrome/CDP; saved credentials and TOTP only after explicit recovery intent | TOTP enabled |
| ipapi.is | Saved-state HTTP dashboard read; API key over HTTP | Headless Chrome by default; `visible=true` for GUI | No enrollment entry offered |
| Cloudflare | Saved-state HTTP identity read; Intel token over HTTP | Headed Chrome for login, token setup and TOTP recovery | TOTP enabled, recovery codes saved |
| AbuseIPDB | Saved-state HTTP account read; APIv2 key over HTTP | Headed Chrome in its dedicated profile | No enrollment entry offered |
| Ipregistry | API key in the reporter only | No account MCP | Not audited |
| DB-IP, IPWHOIS | Account-free HTTP free API and website demo | None | Not applicable |
| IPinfo, Scamalytics, IP2Location, ipdata, Check.Place, Ping0, RIPEstat, Shodan | Public HTTP pages/demos/relays used by the reporter | None | Not applicable |

A failed HTTP identity read returns its failure; it never silently opens a
browser, submits credentials, retries or treats a saved file as success.

## Lessons from setup and recovery

- Clearing proxy environment variables leaves Chrome on the macOS system proxy;
  use `PROVIDER_ACCOUNTS_PROXY=DIRECT` (Chrome gets `--no-proxy-server`).
- Cloudflare's and IPQS's isolated headless dashboards returned 403, so their
  recovery browsers stay headed; ipapi's headless dashboard works.
- IPQS saved HTTP state returned login HTML even after a 302 from its one
  password submission; dashboard work therefore keeps the retained Chrome.
- Signups through proxy routes were rejected: ipapi succeeded only on explicit
  DIRECT, and AbuseIPDB's fresh ATT headless signup needed its dedicated headed
  profile.
- Cloudflare's login widget auto-submits a complete six-digit code; inspect
  navigation/identity before clicking a Verify button that may have vanished.
- AbuseIPDB's new account defaulted public profile and domain visibility to on;
  both were turned off and read back.
- Prove API usefulness before enrolling 2FA, save seeds and recovery codes
  before activation, and keep one-submit receipts so timeouts never cause a
  duplicate signup, token or enrollment.

## Latest live account evidence

Dated observations, not availability guarantees; private receipts stay under
`secrets/accounts/` and each MCP's `.state/`.

| Date | Evidence |
| --- | --- |
| 2026-10-23 | Reporter direct and ATT runs returned official IPQS and Cloudflare results with the saved keys (see [HANDOFF.md](HANDOFF.md#latest-saved-live-evidence)) |
| 2026-10-10 to 10-12 | IPQS account API passed over direct IPv6 and `awshk` while ATT failed TLS before HTTP; Cloudflare Intel passed, including through ATT |
| 2026-10-11 | AbuseIPDB free signup, email verification and one owned key; HTTP identity, privacy booleans and API proof passed with Chrome closed |
| 2026-09-24 | IPQS TOTP enrollment, real challenge and fresh-profile login; ipapi and Cloudflare HTTP identity with Chrome closed; Cloudflare TOTP and recovery codes server-confirmed |
| 2026-09-22 | ipapi free signup on DIRECT (1,000/day plan, full-response key); Cloudflare free signup and an account-scoped, non-expiring Intel Read token returning useful data |

## Routine verification and recovery

- IPQS: `npm --prefix mcp/ipqs run probe:sanitized` performs one non-lookup
  account read; `npm --prefix mcp/ipqs run auth:check` checks the retained
  browser. Authorized login recovery uses `ipqs_login_with_saved_credentials`
  (`confirm=USE_SAVED_IPQS_CREDENTIALS`), completing one reviewed TOTP challenge;
  `ipqs_complete_totp` (`confirm=USE_SAVED_IPQS_TOTP`) handles a pending one.
- Provider accounts: `provider_account_open` opens one allowlisted page and
  `provider_account_read` with `mode=browser` inspects it. A verified ipapi
  dashboard visit refreshes its HTTP state; Cloudflare and AbuseIPDB need the
  steps in [HTTP state recovery](mcp/provider-accounts/AGENTS.md#http-state-recovery).
  Close the owned browser before changing its route or visibility.
- Enrollment: `ipqs_enable_totp` (`confirm=ENABLE_IPQS_TOTP`) verifies usable
  credits, binds issuer/account from the textual QR URL, saves seed/recovery data
  and reserves the one submission; Cloudflare keeps its API-before-2FA rule.

A past audit's authorization for recovery or 2FA is not a standing instruction;
documentation and test work never repeats enrollment.
