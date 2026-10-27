# ipdata

Owned developer-key risk API, relay risk results and keyless geography fallback.
Adapter and parsers: [`ipdata.zsh`](ipdata.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

## Owned developer key

With `IPDATA_API_KEY` in the private credentials file or a project-local
`secrets/ipdata`, query `https://api.ipdata.co/{IP}?api-key=…` directly. The
secret URL reaches curl through stdin configuration, never process arguments.
One request stays on the selected route/address family, with a ten-second
deadline, 262144-byte bound and no redirect. A configured key selects this
source exclusively: a key, quota or transport failure stays visible rather
than spending another request through the relay or geography API.

Require one JSON object, the exact requested IP, a valid country code and a
threat object containing explicit boolean or null fields. Preserve false;
missing VPN or other flags stay unknown. Successful risk results use
`Source=official_api` and `FactorMeta.ipdata.Status=ok`. No numerical score is
inferred from these flags. The sanitized live response shape is in
[`official-response.json`](../test/fixtures/ipdata/official-response.json).

Verified October 27, 2026: after the user approved the registration disclosures,
one free signup and email verification produced an account showing
**Free Tier, $0, 1,500 daily queries**. Its official key returned proxy, Tor,
datacenter and abuse flags through direct and isolated ATT routes; VPN was
absent. The reporter uses that private key. No paid plan or billing trial was
enabled. Account maintenance belongs to the existing provider-accounts MCP;
see [MCP.md](../MCP.md). This developer-account tier is distinct from the
new keyless geography tier described on the public pricing page.

## Without a developer key

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

According to [ipdata's keyless API documentation](https://ipdata.co/free), the
first 1000 daily lookups per calling IP include city-level data; later lookups
retain country and ASN. Both shapes are accepted. The [pricing page](https://ipdata.co/pricing.html)
places threat/VPN data outside that keyless tier. This fallback restores usable
geography without claiming to restore full risk coverage. Data attribution:
[ipdata](https://ipdata.co/).

The public IP detail page still required verification during the October 27
Chrome checks. That page is unnecessary for the verified owned-key path.
The [official FAQ](https://docs.ipdata.co/docs/frequently-asked-questions) and
[signup page](https://dashboard.ipdata.co/sign-up.html) led to the separate
developer account; its useful fields were established by live API responses,
not inferred from a successful webpage load or geography response.
