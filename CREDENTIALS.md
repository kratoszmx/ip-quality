# Private credential locations

This index lists paths and formats only. Every file below is ignored by Git and
kept owner-only; never paste its contents into a report, tool argument or log.
The reporter's accepted names and precedence are documented in
[PROVIDERS.md](PROVIDERS.md#optional-official-credentials).

| Credential | Location / format |
| --- | --- |
| Shared IPQS API key | `secrets/ipqs`, one raw key shared by reporter and `mcp/ipqs` |
| Existing IPQS login | Fixed private two-line bundle under `/Users/zmx/codexworkspace/secrets/infrastructure/network/ipqs/`; discovered by `mcp/ipqs/src/credentials.ts` |
| ipapi full API key | `secrets/ipapi`, optional raw key; currently not acquired |
| Cloudflare Intel token | `secrets/cloudflare_token`, one account-scoped Intel Read token |
| Cloudflare account ID | `secrets/cloudflare_account_id`, 32 lowercase hexadecimal characters |
| Registration identity | `secrets/accounts/registration-email`, the email confirmed by the user |
| Provider login | `secrets/accounts/{ipapi,cloudflare}/credentials.json`, private email/password |
| Cloudflare authenticator | `secrets/accounts/cloudflare/totp-uri`, private RFC 6238 provisioning URI |
| Cloudflare recovery codes | `secrets/accounts/cloudflare/recovery-codes.json`, private recovery data after enrollment |
| Account action evidence | Provider-local registration/token/enrollment receipts and `availability.json` under `secrets/accounts/` |

A saved registration password does not establish that an account was created.
A saved API key does not establish available quota. `cloudflare_verify_free_api`
records a real useful lookup before its TOTP tool can run, bound to the same
account and key. Existing factors and different local keys are preserved.

Browser profiles belong to their MCP's private `.state/` directories. No cookie
export or duplicate key is required for the reporter. Textual provider setup
seeds are imported directly into private storage; QR images are not processed.
