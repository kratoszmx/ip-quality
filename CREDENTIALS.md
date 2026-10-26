# Private credential locations

This index lists names, paths and formats only. Every file below is ignored by
Git and kept owner-only; never paste its contents into a report, tool argument
or log. Saved files prove neither a live login nor available quota.

## Reporter API keys

All keys are optional; a source without its key reports `not_configured` or uses
its documented keyless path. Two data-only locations are read, and a
project-local raw key overrides the global value of the same provider:

| Provider | Global assignment name | Project-local raw-key file |
| --- | --- | --- |
| Ipregistry | `IPREGISTRY_API_KEY` | `secrets/ipregistry` |
| ipapi.is (free plan) | `IPAPI_API_KEY` | `secrets/ipapi` |
| IPQS (shared with `mcp/ipqs`) | `IPQS_API_KEY` | `secrets/ipqs` |
| AbuseIPDB CHECK | `ABUSEIPDB_API_KEY` | `secrets/abuseipdb` |
| Cloudflare Intel Read token | `CLOUDFLARE_API_TOKEN` | `secrets/cloudflare_token` |
| Cloudflare account ID (32 hex) | `CLOUDFLARE_ACCOUNT_ID` | `secrets/cloudflare_account_id` |

The global file is `${XDG_CONFIG_HOME:-$HOME/.config}/ipquality/credentials`,
one `NAME=value` per line. These names are fields in that file, not reporter
environment overrides (only the IPQS MCP also honours an `IPQS_API_KEY`
environment variable; see [its guide](mcp/ipqs/AGENTS.md#api-experience)).
Each file must be regular, readable, owned by the current user and mode `600`
or stricter; links, group/other permission bits, unknown or duplicate names and
unsafe key characters are rejected without executing the file
(`providers/credentials.zsh`). Keys reach curl through standard-input
configuration, never process arguments, Git configuration or reports.

## Account MCP files

| Credential | Location / format |
| --- | --- |
| Existing IPQS login | Fixed private two-line bundle under `/Users/zmx/codexworkspace/secrets/infrastructure/network/ipqs/`; discovered by `mcp/ipqs/src/credentials.ts` |
| Registration identity | `secrets/accounts/registration-email`, the email confirmed by the user |
| Provider login | `secrets/accounts/{ipapi,cloudflare,abuseipdb}/credentials.json`, private email/password and any explicitly authorized registration fields |
| Cloudflare authenticator | `secrets/accounts/cloudflare/totp-uri`, private RFC 6238 provisioning URI |
| Cloudflare recovery codes | `secrets/accounts/cloudflare/recovery-codes.json`, private recovery data after enrollment |
| IPQS authenticator | `secrets/accounts/ipqs/totp-uri`, private exact-account provisioning URI; issuer provisions an 80-bit seed |
| IPQS emergency recovery | `secrets/accounts/ipqs/recovery-code`; `enrollment-attempt.json` prevents duplicate activation |
| Browserless account sessions | `mcp/provider-accounts/.state/{ipapi,cloudflare,abuseipdb}-http.json`, owner-only saved state; never emitted or committed |
| IPQS HTTP/browser session | `mcp/ipqs/.state/chrome-profile/http-session.json` (under `IPQS_BROWSER_PROFILE_DIR` when overridden); saved only after authentication |
| Pending provider login | `mcp/provider-accounts/.state/{provider}-pending-login.json`; terms/challenge continuation only, distinct from verified account state |
| Account action evidence | Provider-local registration/token/enrollment receipts and `availability.json` under `secrets/accounts/` |

A saved registration password does not establish that an account was created.
`cloudflare_verify_free_api` records a real useful lookup before its TOTP tool
can run, bound to the same account and key; existing factors and different
local keys are preserved. AbuseIPDB registration, privacy-setting and
key-creation receipts stay under its private account directory. Documents and
fixtures contain no real registration identity, key, session cookie or
email-verification URL.

Browser profiles live in each MCP's private `.state/` directory. Saved HTTP
state serves account checks only; the reporter uses no cookies or duplicate
keys. Textual provider setup seeds are imported directly into private storage;
QR images are not processed. Checked login state and recovery paths are in
[MCP.md](MCP.md).
