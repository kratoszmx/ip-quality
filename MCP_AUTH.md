# MCP inventory and authentication

Owner: `ipquality`. Checked 2026-09-24. This is the maintained inventory and
dated authentication evidence; file existence alone is never a login check.
Private paths/formats are in [CREDENTIALS.md](CREDENTIALS.md), process lifetime
in [SERVICES.md](SERVICES.md), and offline checks in [TESTING.md](TESTING.md).

## Maintained servers

| Server | Owner / start from repository root | Purpose and disposition |
| --- | --- | --- |
| `codex-ipqs-mcp` | `mcp/ipqs`; build with `npm --prefix mcp/ipqs run build`, start with `npm --prefix mcp/ipqs start` | Formal, maintained: official API, dashboard, saved login and private TOTP |
| `ipquality-provider-accounts` | `mcp/provider-accounts`; `npm --prefix mcp/provider-accounts start` | Formal, maintained: ipapi/Cloudflare identity and setup; DB-IP/IPWHOIS account-free probes |

Both are optional on-demand stdio servers. The reporter needs neither running.
The inventory checked repository entrypoints, package manifests, private profile
directory names, the sibling mcps source tree/manifest and global MCP entry names.
No temporary MCP or separate DB-IP/IPWHOIS MCP remains to promote or delete.
The old mcps IPQS package is absent; its external manifest entry points here.
The three owned account profiles and IPQS support receipts are useful recovery
and audit state. They are not obsolete MCPs or duplicate credentials.

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
  with `USE_SAVED_IPQS_CREDENTIALS`; the exact reviewed TOTP challenge is completed
  once with its private seed. `ipqs_complete_totp` with `USE_SAVED_IPQS_TOTP`
  handles a pending challenge. Failed or changed forms stop without retries.
- ipapi/Cloudflare: `provider_account_read` defaults to `mode=http` and returns
  exact-account identity metadata. `cloudflare_account_check` additionally checks
  email and factor state. Neither starts Chrome. `provider_account_status` is
  only an offline credential-readiness check.
- Explicit recovery/setup: `provider_account_open` opens one allowlisted page;
  `provider_account_read` with `mode=browser` inspects its redacted controls.
  Verified ipapi dashboard visits and Cloudflare server-identity reads refresh
  the corresponding private `.state/*-http.json`. Never copy these files into
  logs, tool arguments or Git. Close the verified owned browser before changing
  its route or switching an existing headless container to a visible one.
- Enrollment: `ipqs_enable_totp` with `ENABLE_IPQS_TOTP` verifies usable API
  credits, binds the issuer/account from the existing textual QR URL, saves
  seed/recovery data and reserves the one submission before activation. No image
  decoding is used. Existing factors and receipts stop duplicate enrollment.
  Cloudflare retains its API-before-2FA policy. Account-free platforms need no
  registration, paid plan or authenticator.

Account operations require task intent. The user authorized this audit, recovery,
backend changes and applicable 2FA setup; routine offline tests exercise fixtures
only. Live authentication receipts and any short-lived proof profile belong to
ignored private storage, never the repository's public source.
