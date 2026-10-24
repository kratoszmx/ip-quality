# IPWHOIS

Website-demo request, security flags and rate-limit semantics. Adapter and parser: [`ipwhois.zsh`](ipwhois.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

IPWHOIS uses its current homepage demo, `https://ipwhois.io/demo?ip={IP}`.
The old upstream used `/widget`; its current JavaScript uses `/demo`.
Requests include its website Origin/Referer and browser request headers. On
2026-09-24 a paired direct-route check returned a rate-limit body without
those headers and valid security fields with them. A limit message alone
therefore does not prove the user's own daily allowance was exhausted.
Section 4 accepts only actual boolean proxy/VPN/Tor/hosting fields in
`security`, bound to the exact returned target. Missing fields stay null,
including abuse/bot fields that the demo does not supply. HTTP 200 with
`success:false` and a rate-limit message means `rate_limited`, not usable.
`FactorMeta.IPWhois` records `public_demo` and the risk-query status.

The permanent free `ipwho.is` endpoint needs no key and documents 1,000
requests per client IP per day, but its response has no security data. The
reporter's one bounded demo request is a different surface with an unspecified
quota, and no geography-only fallback hides a failed risk lookup behind an
"available" status. The account MCP probes `free_api` and `public_demo`
separately.
