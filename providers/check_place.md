# Check.Place relays and MaxMind basic data

Shared relay policy, MaxMind-labeled basic data and per-relay statuses. Adapter and parser: [`check_place.zsh`](check_place.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

Check.Place relays share one upstream host. After that host returns the known
Cloudflare block page or HTTP 429, the remaining relay calls for the same target
and address family pause for this reporter process. Their columns remain visible
with `skipped_relay_cloudflare_blocked` or `skipped_relay_rate_limited`; those are
unqueried/unknown results, not additional observed failures or clean results.
The first actual failure retains its original status. Other official APIs,
targets and address families proceed normally; no persistent cache, retry,
browser fallback or route change is created. Ordinary HTTP 403, transport and
schema failures do not trigger this source-specific pause.

Check.Place rows are explicitly labeled `Upstream relay`; they are not treated
as owner-controlled official accounts. Its MaxMind-shaped payload does not
prove that this machine owns a `.mmdb`, a MaxMind subscription, or a known
edition/build.

Each Check.Place-backed request keeps an independent HTTP status. The parser
distinguishes its known Cloudflare block page from an ordinary HTTP 403, and
one relay failure cannot erase a successful sibling. JSON exposes these states
in `ProviderStatus`.

The MaxMind-labeled basic response must contain one valid observation object.
Wrong nested types, error-only bodies and empty observations become
`invalid_response`; basic information then uses the existing IPinfo fallback.
Missing optional fields and zero coordinates remain valid. An English
supplement fills only missing fields after the same validation, so a failed
translation cannot erase valid primary data. JSON text is passed unchanged
to jq, including literal backslashes. The other provider adapters use the same
literal-input rule so unrelated escaped text cannot corrupt their JSON reads.

## October 26 recovery evidence

The exact ipapi relay URL for a fixed public target returned HTTP 403 with the
Cloudflare block page over both the explicit configured proxy and direct HTTP.
A newly started text-browser MCP 0.5.17 also returned 403/`BROWSER_CHALLENGE`
on a fresh direct Chrome read, with no target data. This verifies the current
failure independently of the older 0.5.16 MCP connection retained by the chat.
The text-browser development chat additionally records the user's confirmation
that Safari was blocked at this exact relay too. Browser reachability of a
different site or an anonymous API is not relay recovery. Keep the existing
source-specific pause and independent-source fallbacks; no valid response was
available to justify a new automatic relay retry or browser dependency.

A later bounded recheck used the same public target and URL over the configured
proxy, direct IPv4, isolated ATT and isolated `awshk`. All returned HTTP 403;
three distinct exits were verified without changing live Clash state. The first
three had the branded Cloudflare block page. `awshk` first supplied plain-text
403, then the branded page on one follow-up; neither response contained target
data. Fresh Chrome via direct routing, both windowless and visible, also
returned 403/`BROWSER_CHALLENGE`. Text-browser MCP was 0.5.18. Private sanitized
HTTP and browser receipts are in `reports/access-recheck-20261026/`.

Cloudflare's [403 documentation](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/4xx-client-error/error-403/)
lists managed/custom WAF rules and other security settings as possible causes
of branded blocks. The generic page does not identify the matching rule or
prove that the visitor attacked the site. The site owner can look up the
[Ray ID in Security Events](https://developers.cloudflare.com/fundamentals/reference/cloudflare-ray-id/),
subject to its sampling and retention. Our separate Cloudflare account cannot
change Check.Place's policy. These observations establish a site-access refusal,
not a transport outage, an account-key failure or a cause fixed by more retries.
