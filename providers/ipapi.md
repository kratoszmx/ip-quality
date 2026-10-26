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
Curl timeout, TLS-handshake and certificate-verification failures have separate
statuses; none implies an exhausted API allowance. A 2026-09-24 comparison
returned a full keyed response over direct access and curl 35 before HTTP
over isolated ATT, including a TLS 1.2 and official diagnostic-host check.
This establishes a route-specific transport failure, not its remote cause.
Runtime keeps certificate checks and the chosen route; it does not secretly
fetch the observation through direct access or pin a diagnostic hostname.

The anonymous `ipapi.is` path requires no key and returns a minimal response.
On 2026-09-24 its official pages disagree on the anonymous daily limit (30 on
the free-tier page; 100 on the developer page). Treat HTTP 429/Retry-After as
authoritative for an actual request, without retrying into a firewall ban. A free
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

The similarly named `ipapi.co` is a different product with a contact-gated free
trial. This project uses `ipapi.is`, with a free key when configured; the two
providers must not be silently combined.
