# Scamalytics

Relay result and its one public target-page fallback. Adapter and parser: [`scamalytics.zsh`](scamalytics.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

If the Scamalytics relay is unavailable or malformed, one same-route request
to `https://scamalytics.com/ip/TARGET` can restore that provider's observations.
The page heading and embedded example must identify the exact target; its
score badge must agree with the example's 0–100 score. The sample's original
risk/blacklist values and unambiguous labeled Yes/No cells are retained.
Missing or conflicting cells remain unknown. Public/Web/Residential Proxy
flags use any-true/all-false semantics; robot combines the displayed search
engine and X4Bnet spambot flags. This public page is distinct from the paid
JSON API and from the relay's dataset: JSON `ScoreMeta.SCAMALYTICS` records
`Source`, final `Status`, and the failed `RelayStatus`; `FactorMeta` records
the same source. No other provider's score is substituted. The page has no
guaranteed automation quota; one failure stops without a browser, route
change, account or retry. See the [official example](https://scamalytics.com/ip/8.8.8.8).
