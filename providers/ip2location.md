# IP2Location

Relay result and its public target-page fallback. Adapter and parser: [`ip2location.zsh`](ip2location.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

IP2Location: after an unavailable or malformed relay response, read
`https://www.ip2location.com/{IP}` once. The heading and embedded `code2` JSON
must both match the target; scores remain within the provider's 0–99 range.
Missing flags stay unknown. This is a public website example, not a promise
that its paid Security API has a free risk tier.
