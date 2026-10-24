# DNSBL scope

DNS blocklist queries and outcome rules. Implementation: [`dnsbl.zsh`](dnsbl.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

The reporter reverses one IPv4 address and queries every unique zone in the
vendored [`ref/dnsbl.list`](../ref/dnsbl.list) (420 zones; `test/repository_test.rb` checks their
format and uniqueness). Concurrency is configurable from 1 through the hard
maximum of 50.

The reader keeps `dig`'s DNS header as well as its answer records: an exit
status of zero alone does not distinguish NXDOMAIN from SERVFAIL or REFUSED.
Outcomes follow the DNS status and complete answer, not just empty stdout:

- `Clean`: a complete NXDOMAIN or NOERROR response with zero answers;
- `Blacklisted`: a complete NOERROR response has only valid listing A records,
  including `127.0.0.2`;
- `Marked`: a complete NOERROR response has only other `127.0.0.0/8` listing codes;
- `Unknown`: `dig` fails or times out, DNS returns an error such as SERVFAIL or
  REFUSED, the header/record count is missing or inconsistent, a response is
  truncated, or an answer is malformed, an alias, a `127.255.255.*` policy error,
  or an address outside `127.0.0.0/8` (possible NXDOMAIN hijacking).

Terminal output names every `Blacklisted` and `Marked` zone. JSON retains a
per-zone `Results` object as well as totals. Spamhaus codes such as
`127.255.255.252`, `.254`, and `.255` are therefore errors, not listing or clean
evidence. Resolver policy and each zone operator's terms still determine whether
a DNSBL answer is authoritative.

UCEPROTECT Level 2 and Level 3 are netblock/allocation and ASN/provider-level
signals; they are not proof that the individual address sent spam. DNSBL, MX,
and SMTP checks always remain system-route observations and are never attributed
to an isolated HTTP proxy leaf.
