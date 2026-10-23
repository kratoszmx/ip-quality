# IPQualityScore (IPQS)

Relay without a key; official API with an account-usage preflight. Adapter and parser: [`ipqualityscore.zsh`](ipqualityscore.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

Without an IPQS
key, the reporter uses the named Check.Place relay and records that source. With an
IPQS key, it first calls the account-usage endpoint. A confirmed zero balance,
insufficient-credit response, transport/HTTP failure or malformed account body
stops before the reputation request. Both account and lookup stages retain
timeout, TLS-handshake, certificate, HTTP and response-schema statuses; an error
body cannot override a failing HTTP status. Failures remain attributed to the
official path rather than being described as a clean IP.
When the account preflight and the official lookup both succeed, the report marks
IPQS as `官方/可用`; the current terminal and JSON reports do not expose the
account's remaining credit balance. The preflight value is used only to gate the
paid lookup.
