# Cloudflare IP Intelligence

Validation, display placement, retired Threat Score and plan quota. Adapter and parser: [`cloudflare.zsh`](cloudflare.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

Cloudflare IP Intelligence validates the target IP, ASN reference, and bounded
threat-category objects. Its categories remain source-specific observations;
they are not converted into the project's other boolean factors or a score.
A live response on 2026-09-22 supplied a numeric ASN despite the documentation's
string example; valid 32-bit numeric ASNs are normalized to `AS<number>`.
Missing `risk_types` stays `null` in JSON, while an explicitly empty array stays
`[]`. A null `threat_summary` supplies no clean-IP evidence.
Section 1 includes the named Cloudflare query status, ASN, ASN country,
ASN type and organization after either the relay or fallback basic data.
Actual threat categories appear there when supplied; missing categories
create no extra line, while an explicit empty array says "none listed".
Section 3 has no Cloudflare column or context rows. JSON fields remain
compatible: Score.Cloudflare is null, and ProviderContext.Cloudflare retains
all observations. These are `belongs_to_ref` attributes: the country belongs to
the ASN context and the type classifies the ASN, not whether the tested IP
itself is residential, a VPN or clean. Failed queries show their status without
displaying stale context; absent fields are omitted.
Cloudflare's current WAF documentation says legacy Threat Score is always 0
and no longer populated. The old upstream fetched `.ip.riskScore` from the
third-party `ip.nodeget.com` and assigned local risk bands. That old zero is
not restored as a low-risk result. JSON marks LegacyThreatScore as
`retired_constant_zero`. Interpretation details remain here and in JSON;
the terminal omits the repeated Cloudflare, DB-IP, ipapi and IPWHOIS prose.

Cloudflare
Security Center's IP Intelligence endpoint requires an account ID and an API
token with Intel Read (or Intel Write) permission. Cloudflare documents 100
Threat Intelligence API calls per month on Free, Pro, and Business plans; calls
made by other Security Center features also consume that monthly quota. The
reporter does not attempt to estimate remaining provider quota.
