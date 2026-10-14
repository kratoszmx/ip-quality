# MCP guide and authentication

Owner: `ipquality`. Implementation and access modes reviewed 2026-10-14.
This review reads code and runs offline tests; it does not establish fresh
authenticated sessions. Live evidence below keeps its original date. File
existence alone is not a login check.
Private paths/formats are in [CREDENTIALS.md](CREDENTIALS.md), process lifetime
in [SERVICES.md](SERVICES.md), and offline checks in [TESTING.md](TESTING.md).

## Maintained servers

| Server | Owner / start from repository root | Use it for |
| --- | --- | --- |
| `codex-ipqs-mcp` | [IPQS guide](mcp/ipqs/AGENTS.md); build with `npm --prefix mcp/ipqs run build`, start with `npm --prefix mcp/ipqs start` | Official IPQS API usage/lookups, dashboard, saved login and private TOTP |
| `ipquality-provider-accounts` | [Provider-account guide](mcp/provider-accounts/AGENTS.md); `npm --prefix mcp/provider-accounts start` | ipapi/Cloudflare/AbuseIPDB account maintenance; DB-IP/IPWHOIS account-free probes |

Both are optional on-demand stdio servers; the reporter needs neither running.
Runtime/dependency and shutdown details are in [SERVICES.md](SERVICES.md).
There is no separate DB-IP/IPWHOIS server. Account profiles and support receipts
are private recovery/audit state, not disposable temporary MCPs.

## Current access methods

Scope: accounts and data sources maintained by this repository. HTTP with saved
cookies reuses an earlier login; it does not mean a fresh password login was
implemented. Playwright's `request.newContext` is an HTTP client and starts no
browser. A hidden/background headed Chrome still belongs in the GUI category.

| Platform | Routine account/data access | Fresh login or recovery | 2FA / latest live account evidence |
| --- | --- | --- | --- |
| IPQS | API key over native HTTP; dashboard reads use same-origin fetch inside retained Chrome | GUI Chrome/CDP; saved credentials and TOTP after explicit recovery intent | TOTP enabled and fresh login proved September 24; account API passed October 10–12 |
| ipapi.is | Saved-state HTTP dashboard read; API key over native HTTP | Headless Chrome by default; `visible=true` requests GUI Chrome | No enrollment entry observed September 24; HTTP identity proved then |
| Cloudflare | Saved-state HTTP identity read; Intel token over native HTTP | GUI Chrome for login, token setup and TOTP recovery | TOTP and saved recovery codes server-confirmed September 24; Intel queries passed October 12 |
| AbuseIPDB | Saved-state HTTP account read; APIv2 key over native HTTP | GUI Chrome in its dedicated profile | No enrollment entry observed October 11; HTTP identity, verified email and API proved then |
| Ipregistry | API key over HTTP in the reporter | No account-login MCP maintained here; key-only integration | Account 2FA not audited by this project |
| DB-IP | Account-free HTTP geography API and website visitor demo | No login/browser | Not applicable |
| IPWHOIS / ipwho.is | Account-free HTTP geography API and website security demo | No login/browser | Not applicable |
| IPinfo, Scamalytics, IP2Location, ipdata | Public HTTP components/pages/demos and the documented relay paths; ipdata discovers a transient website demo key | No owned account-login flow | Not applicable |
| Check.Place, Ping0, RIPEstat, Shodan InternetDB | Public HTTP endpoints | No login/browser | Not applicable |

Implementation owners: IPQS `src/api.ts` and `src/browser.ts`; provider accounts
`accounts.mjs`, `http-account.mjs`, `cloudflare.mjs`, `abuseipdb.mjs` and
`public-api.mjs`; reporter `bin/ip-quality`. Source and quota contracts remain in
[PROVIDERS.md](PROVIDERS.md). All reporter queries use HTTP rather than account
Chrome sessions, including IPQS. No account/browser backend was changed in this
maintenance review.

## Choose a first call

These are server-local tool names and JSON arguments; a client may add its own
prefix. Local-readiness calls are offline. Live MCP reads run when called; the
reporter's `--confirm-network-lookup` flag does not apply to MCP tools.

| Need | Tool | Arguments | Network / meaning |
| --- | --- | --- | --- |
| IPQS local readiness | `ipqs_status` | `{"probeBrowser":false}` | None; saved files are not proof of login or credits |
| ipapi/Cloudflare local readiness | `provider_account_status` | `{"provider":"ipapi"}` | None; use `cloudflare` for that account |
| AbuseIPDB local readiness | `abuseipdb_account_status` | `{}` | None; account/key presence only |
| AbuseIPDB identity and privacy settings | `abuseipdb_account_check` | `{}` | Live HTTP; exact saved account, email-verification and public-profile booleans only |
| AbuseIPDB free API proof | `abuseipdb_verify_free_api` | `{"confirmation":"VERIFY_FREE_API"}` | One official `1.1.1.1` CHECK lookup; no browser or abuse-report submission |
| IPQS account/API acceptance | `ipqs_account_usage` | `{}` | One live account read; no reputation lookup credit |
| ipapi saved-session identity | `provider_account_read` | `{"provider":"ipapi","mode":"http"}` | Live HTTP, no Chrome; inspect `authenticated` and `state` |
| Cloudflare identity and 2FA state | `cloudflare_account_check` | `{}` | Live HTTP, no Chrome or Intel lookup |
| DB-IP free geography probe | `public_provider_verify_free_api` | `{"provider":"dbip","surface":"free_api","confirmation":"VERIFY_FREE_API"}` | One live `1.1.1.1` lookup; supplies context, not a risk verdict |

For website risk observations, explicitly choose `public_demo`: IPWHOIS tests
`1.1.1.1`, while DB-IP reads a page and the requesting egress. Field availability
and quotas differ from `free_api`; see [PROVIDERS.md](PROVIDERS.md).
IPQS uses the input name `confirm` for mutations; provider accounts uses
`confirmation`. Account operations follow task intent and the tool's own schema.

## Dated state and preferred access

October 12: the saved ATT full report returned DB-IP `ok`. This supersedes
October 11's direct/ATT `OVER_QUERY_LIMIT` observation as the latest saved demo
result, without promising availability today. The reporter still distinguishes
`daily_quota_exhausted`; the earlier error supplied no recovery timestamp.
This is demo availability, not a failed account login. Reporter IPQS/Cloudflare
target-query fallback is separate from these MCP account/probe routes and does
not alter saved sessions. See [HANDOFF.md](HANDOFF.md) for complete live reports.

October 11: the user-authorized AbuseIPDB individual signup, confirmation email
and one API-key creation completed. Native HTTP with saved private state matched
the exact account and confirmed email verification. Both public-profile and
domain-visibility checkboxes were disabled and read back as false. Its official
key returned useful data through the MCP probe and both complete direct/ATT
reports. The account settings exposed no 2FA enrollment entry, so no factor was
created. This records the inspected surface, not a guarantee that the provider
will never offer 2FA. No payment method or upgrade was used.

AbuseIPDB's routine account and API checks use HTTP with Chrome closed. Its fresh
ATT headless signup was blocked; the reviewed setup used a dedicated headed
container. The owned container was closed after saving the private HTTP state.
Use `abuseipdb_account_open` with `surface=login` only for explicit recovery;
signup, privacy settings and key creation are reviewed maintenance operations,
not automatic retries. See the package recovery guide before restoring state.

On October 10, official IPQS account reads passed over direct IPv6 and `awshk`;
the initial balance was 5020 credits / usage 1. A lookup of the ATT target through
`awshk` also passed. ATT itself failed before HTTP at TLS, while Cloudflare Intel
queries through ATT passed. These API diagnostics did not repeat dashboard login
or change credentials/2FA. See [HANDOFF.md](HANDOFF.md) for the report and support
investigation. The browser/session observations below remain dated September 24.

September 24: IPQS credits, restored browser login, TOTP enrollment, a real
challenge and fresh-profile login passed; its seed/emergency code were saved
before activation. ipapi's HTTP dashboard matched the saved account, labelled
key and logout with Chrome closed, and its headless dashboard also passed.
Cloudflare's HTTP account endpoint matched the saved identity, verified email
and existing TOTP with Chrome closed. Its isolated headless dashboard returned
403, so recovery retains headed Chrome. IPQS's independent saved HTTP state
returned login HTML and its isolated headless trial returned 403.

These results establish the checked account/transport, not universal route or
future availability. The September authentication audit needed no reputation
lookup. A failed HTTP identity check returns its failure without starting Chrome,
submitting credentials, repeating requests or treating a saved file as success.
The independent IPQS HTTP login received HTTP 302 after its one password
submission, but a later HTTP 200 settings response supplied no authenticated
proof. Its exact cause is unconfirmed. This is a failed September validation, not
a claim that HTTP login can never work. The fresh Chrome proof profile was
removed after its process exited; no temporary MCP was introduced.

## Routine verification and recovery

- IPQS API: `npm --prefix mcp/ipqs run probe:sanitized` performs one non-lookup
  account read. `npm --prefix mcp/ipqs run auth:check` checks the retained browser.
  For an authorized login recovery, use `ipqs_login_with_saved_credentials`
  with `confirm=USE_SAVED_IPQS_CREDENTIALS`; the reviewed TOTP challenge completes
  once with its private seed. `ipqs_complete_totp` with `confirm=USE_SAVED_IPQS_TOTP`
  handles a pending challenge. Failed or changed forms stop without retries.
- Explicit recovery/setup: `provider_account_open` opens one allowlisted page;
  `provider_account_read` with `mode=browser` inspects its redacted controls.
  A verified ipapi dashboard visit refreshes its private HTTP state. Cloudflare
  requires its separate server-identity helper; generic open/read tools do not
  refresh its state. Follow [HTTP state recovery](mcp/provider-accounts/AGENTS.md#http-state-recovery).
  Private state stays out of logs, tool arguments and Git. Close the owned browser
  before changing its route or switching an existing headless container to a visible one.
- Enrollment: `ipqs_enable_totp` with `confirm=ENABLE_IPQS_TOTP` verifies usable API
  credits, binds the issuer/account from the existing textual QR URL, saves
  seed/recovery data and reserves the one submission before activation. No image
  decoding is used. Existing factors and receipts stop duplicate enrollment.
  Cloudflare retains its API-before-2FA policy. Account-free platforms need no
  registration, paid plan or authenticator.

The dated authentication audit had its own authorization for recovery and 2FA;
it is not a standing instruction to repeat enrollment during documentation work.
Routine offline tests exercise fixtures. Live authentication receipts remain in
ignored private storage.
