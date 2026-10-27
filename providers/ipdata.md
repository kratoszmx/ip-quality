# ipdata

Relay risk results and official free-geography fallback. Adapter and parsers: [`ipdata.zsh`](ipdata.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

After an unavailable or malformed Check.Place relay response, make one request
to `https://ipdata.free/{IP}` on the selected route and address family. This
official API needs no account or key. Reuse `provider_fetch_public_json` for the
ten-second deadline, 262144-byte bound and HTTP/transport classification; reject
redirects. A successful relay does not make the additional request.

The free API must return a JSON object with the exact requested `ip`, a
two-letter uppercase `country`, and no error/message. It supplies geography,
not proxy/VPN/Tor/datacenter/abuse judgments. Country remains visible in section
4; every risk cell stays unknown, even if an unexpected `threat` field appears.
The table status is `官方/未提供风险` / `official/risk not supplied`.
JSON distinguishes lookup success (`ProviderStatus.ipdata=ok`) from missing
risk (`FactorMeta.ipdata.Status=not_provided`), with
`Source=official_free_api`, `Reason=free_geolocation_only` and the original
`RelayStatus`. Failures retain their transport/HTTP/schema status and clear all
earlier observations. Successful relay risk flags retain their original values.

Verified October 26, 2026: the redesigned `ipdata.co` root returned free
geography JSON; the old page no longer published the demo key used by this
reporter. HTML now directs fuller lookups through browser verification. The
obsolete key scraper and its fixtures have been removed. A minimal successful
free response is preserved as a sanitized fixture in
[`test/fixtures/ipdata/free-response.json`](../test/fixtures/ipdata/free-response.json).

According to [ipdata's free API documentation](https://ipdata.co/free), the
first 1000 daily lookups per calling IP include city-level data; later lookups
retain country and ASN. Both shapes are accepted. The [pricing page](https://ipdata.co/pricing.html)
places threat/VPN data outside that free tier. This fallback restores usable
geography without claiming to restore full risk coverage. Data attribution:
[ipdata](https://ipdata.co/).

October 27 follow-up: direct and isolated ATT runs still returned country only.
Chrome over the default proxy and direct route, including visible Chrome,
loaded the public IP page but did not complete its verification or return risk
fields. Do not label a successful geography lookup as restored risk coverage.

A separate free-account possibility is unresolved: the [official FAQ](https://docs.ipdata.co/docs/frequently-asked-questions)
still describes a 1500/day free API key, and the live signup bundle lists a $0
Free Tier. These older account materials differ from the new keyless pricing
page; neither proves a newly created account would include risk fields.
The [signup page](https://dashboard.ipdata.co/sign-up.html) submits email,
browser fingerprint and referrer to its configured backend. Under the user's
privacy requirement, account creation awaits explicit consent to those fields.
No developer account, paid plan, trial or account MCP was created in this check.
