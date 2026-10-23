# AbuseIPDB

Owned official APIv2 key or the named relay. Adapter and parser: [`abuseipdb.zsh`](abuseipdb.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

AbuseIPDB: a configured private key selects its official
[APIv2 CHECK endpoint](https://docs.abuseipdb.com/#check-endpoint) directly,
with `maxAgeInDays=90`, a private `Key` header and target-bound response
validation. The [free individual account](https://www.abuseipdb.com/register)
advertises 1,000 checks/day. No abuse report is submitted. Without a key the
existing named relay remains; an official failure does not switch to it.
