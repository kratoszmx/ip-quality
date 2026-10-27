# ipapi.is

Anonymous and keyed response tiers, quotas and status handling. Adapter and parser: [`ipapi.zsh`](ipapi.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

The ipapi.is adapter validates the returned IP and accepts both documented
response tiers: the flat anonymous response and the keyed nested response.
Anonymous data is shown as context only; it supplies no proxy, VPN, Tor,
hosting, abuse, type, or score evidence. Error bodies, quota responses, and
malformed nested sections become an explicit unavailable status, with the
upstream body and jq diagnostics kept out of the terminal report.
Section 4 keeps the ipapi.is column on failures or anonymous responses. Its
query-status row distinguishes missing risk from request failure. Credential
mode and response tier remain in `FactorMeta.ipapi`; no routine prose footer
repeats them below the matrix. The same status row covers the other sources.
The adapter recognizes only documented JSON 403 errors: `ERR_FORBIDDEN_NOT_ALLOWED`
becomes `account_restricted`, and `ERR_FORBIDDEN_INVALID_API_KEY` becomes
`invalid_api_key`. A generic firewall/HTTP 403 is not evidence of either.
After either recognized keyed denial it makes one keyless lookup on the same
route, family, interface and target. Only a valid anonymous response can supply
context; its success never clears the primary type/score/factor failure.
`FactorMeta.ipapi` retains `PrimaryStatus`, `ErrorCode`, `FallbackStatus` and
`CredentialMode=anonymous_fallback`; `ScoreMeta.ipapi` retains the risk status
and error code. Generic 403, 429 and transport failures do not get this retry.
The normal command and its consent gate are unchanged.

The current documented `is_crawler` can be false or a nonempty crawler-name
string. The full-tier parser accepts the bounded name as a positive detection
while retaining legacy booleans; anonymous responses still discard detection
flags. Empty/control-bearing names and containers remain invalid responses.

Curl timeout, TLS-handshake and certificate-verification failures have separate
statuses; none implies an exhausted API allowance. A 2026-09-24 comparison
returned a full keyed response over direct access and curl 35 before HTTP
over isolated ATT, including a TLS 1.2 and official diagnostic-host check.
This establishes a route-specific transport failure, not its remote cause.
Runtime keeps certificate checks and the chosen route; it does not secretly
fetch the observation through direct access or pin a diagnostic hostname.

The anonymous `ipapi.is` path requires no key and returns a minimal response.
The [official developer documentation](https://ipapi.is/developers.html), checked
October 27, specifies 30 anonymous lookups per IP per UTC day (IPv6 uses
a /64 budget). It supplies ownership/location, not detection flags. Treat
HTTP 429/Retry-After as authoritative for an actual request, without retrying
into a firewall ban. A free
ipapi.is account key raises the documented allowance to 1,000 lookups per day
and unlocks the complete response used by the type, score, and factor tables.
The reporter reads that optional key from the file assignment `IPAPI_API_KEY`
or the raw-key file `secrets/ipapi`.

October 26 recovery check: the dashboard reported `bot_login` account suspension.
With explicit user authorization, its normal `Generate new API key` action
produced a different key and the reporter's owner-only key file was updated.
One lookup with the new key still returned HTTP 403 (`ERR_FORBIDDEN_INVALID_API_KEY`);
the authenticated dashboard still reported suspension. Key rotation is not proof
of restored API access; the previous key and one-submit receipt remain private.
The current upstream `xykt/IPQuality` script instead reads
`https://ipinfo.check.place/{IP}?db=ipapi`. A fixed public-target check of that
relay returned HTTP 403 over the default proxy, direct IPv4 and isolated ATT.
No working relay recovery was established, so the reporter does not silently
substitute an unverified relay response or label it as an official API result.
The official error contract distinguishes `ERR_FORBIDDEN_NOT_ALLOWED` (account
may not query; contact support), `ERR_FORBIDDEN_INVALID_API_KEY` (unknown or
disabled key), and `ERR_QUOTA_EXCEEDED` (account quota). Purchasing credits is
not evidence of an account unlock. Anonymous context and other named providers
can preserve report coverage, but cannot replace ipapi risk fields under its name.

October 27 recheck: the reporter returned HTTP 403 on both direct and isolated
ATT. The exact saved-account HTTP check still returned `authenticated=true`,
`state=account_suspended`, `restriction=bot_login`, `apiUsable=false`. A separate
bounded keyed request for 1.1.1.1 returned `ERR_FORBIDDEN_NOT_ALLOWED`, which the
current official documentation explicitly identifies as an account denied
permission to query. This is stronger evidence than the earlier invalid-key
code; connection troubleshooting or another key rotation cannot clear an
account restriction. The next recovery step is an account review through the
[official support contact](https://ipapi.is/contact.html). The user has not
authorized the ipapi appeal to be sent; no message or automatic login was made.

The later October 27 direct reproduction again returned that exact account
error. With the new fallback, focused and all-source direct runs obtained
anonymous ASN/organization/geography, while all three matrices correctly kept
`账户受限` and null risk fields. This confirms partial context recovery, not an
account unlock. Evidence: `reports/direct-source-recheck-20261027/`.

The similarly named `ipapi.co` is a different product with a contact-gated free
trial. This project uses `ipapi.is`, with a free key when configured; the two
providers must not be silently combined.
