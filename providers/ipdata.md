# ipdata

Relay result and its website demo-key fallback. Adapter and parser: [`ipdata.zsh`](ipdata.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

ipdata: after an unavailable or malformed Check.Place relay response, read `https://ipdata.co/` and extract
its one published demo key from the legacy `$.get` or current `fetch` call
to the exact official API origin; ambiguous keys are rejected. Make one
`https://api.ipdata.co/{IP}` lookup with
the website Origin/Referer. The key stays in memory and curl's stdin config;
it is never hard-coded, cached, put in process arguments or reported. This is
shared website-demo access with an unspecified allowance, not an owned key.
