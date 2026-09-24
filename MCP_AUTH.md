# MCP guide and authentication

Owner: `ipquality`. Inventory and tool schemas reviewed 2026-09-24. The account
evidence below records the earlier v25 authentication audit; documentation
validation does not repeat live logins. File existence alone is not a login check.
Private paths/formats are in [CREDENTIALS.md](CREDENTIALS.md), process lifetime
in [SERVICES.md](SERVICES.md), and offline checks in [TESTING.md](TESTING.md).

## Maintained servers

| Server | Owner / start from repository root | Use it for |
| --- | --- | --- |
| `codex-ipqs-mcp` | [IPQS guide](mcp/ipqs/AGENTS.md); build with `npm --prefix mcp/ipqs run build`, start with `npm --prefix mcp/ipqs start` | Official IPQS API usage/lookups, dashboard, saved login and private TOTP |
| `ipquality-provider-accounts` | [Provider-account guide](mcp/provider-accounts/AGENTS.md); `npm --prefix mcp/provider-accounts start` | ipapi/Cloudflare identity and setup; DB-IP/IPWHOIS account-free probes |

Both are optional on-demand stdio servers; the reporter needs neither running.
Runtime/dependency and shutdown details are in [SERVICES.md](SERVICES.md).
There is no separate DB-IP/IPWHOIS server. Account profiles and support receipts
are private recovery/audit state, not disposable temporary MCPs.

## Choose a first call

These are server-local tool names and JSON arguments; a client may add its own
prefix. The first two calls are offline. Live MCP reads run when called; the
reporter's `--confirm-network-lookup` flag does not apply to MCP tools.

| Need | Tool | Arguments | Network / meaning |
| --- | --- | --- | --- |
| IPQS local readiness | `ipqs_status` | `{"probeBrowser":false}` | None; saved files are not proof of login or credits |
| ipapi/Cloudflare local readiness | `provider_account_status` | `{"provider":"ipapi"}` | None; use `cloudflare` for that account |
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

| Platform | Account/API evidence on September 24 | Routine backend | Browser fallback | 2FA |
| --- | --- | --- | --- | --- |
| IPQS | Non-lookup account API accepted the key with credits; expired browser login restored once; enrollment, a real TOTP challenge and fresh-profile login passed | Official API is direct HTTP; dashboard text is one same-origin GET in the retained container | Retained headed Chrome/CDP. Independent HTTP state returned login HTML; a separate one-submit HTTP login did not establish auth; isolated headless returned 403 | Enabled; private seed and emergency backup code saved before activation |
| ipapi.is | HTTP dashboard matched the saved email, labelled key and logout; repeated check passed with Chrome closed. The earlier direct keyed API proof and ATT TLS issue are in HANDOFF | Saved private state + bounded HTTP GET | Headless Chrome dashboard passed; setup/recovery defaults to headless, `visible=true` is the explicit human-UI option | No enrollment entry was present on the current account page; not enabled |
| Cloudflare | HTTP account endpoint matched the saved identity, verified email, enabled 2FA and configured TOTP; passed with Chrome closed | Saved private state + bounded HTTP GET; Intel token uses native HTTP | Isolated headless dashboard returned 403; explicit setup/recovery keeps headed Chrome | Existing TOTP retained and server-confirmed; eight private recovery codes already saved |
| DB-IP / IPWHOIS | Existing September 24 public-demo evidence supplies risk observations; fixture contracts revalidated in this change | Bounded native HTTP | None | Account-free; not applicable |

These results establish the checked account/transport, not universal route or
future availability. No reputation lookup was needed for this authentication
audit. A failed HTTP identity check returns its failure without starting Chrome,
submitting credentials, repeating requests or treating a saved file as success.
The independent IPQS HTTP login received HTTP 302 after its one password
submission, but a later HTTP 200 settings response supplied no authenticated
proof. Its exact cause is unconfirmed. This is a failed current validation, not
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
