# Current handoff

## Direct/ATT follow-up — 2026-10-10

Current reporter: `v2026-10-10-standalone.27` on `main`. The preceding v26 fix
preserved errors; it did not restore either blocked upstream path.

Fresh complete v26 runs confirmed the user's updated observation: direct IPv4
and isolated `vps+sub5` / `ATT` both received Check.Place Cloudflare blocks for
five relay sources. Cloudflare's separate official Intel API succeeded on both.
IPQS timed out on direct IPv4 and failed TLS on ATT.

- Check.Place also returned the same 403 block in ATT headless Chrome and direct
  headed Chrome. The upstream project's [issue 79](https://github.com/xykt/IPQuality/issues/79)
  records another user's similar block, but establishes neither our trigger nor
  a recovery deadline. No client change has restored Check.Place access.
- Direct IPv4 IPQS reached HTTP 200 with valid TLS after resolving to an address
  independently verified through encrypted DNS; the account endpoint accepted
  the unchanged key (credits 5020, usage 2). Default system resolution timed
  out. The resolver/address path therefore contributes to the direct failure.
  No production DNS or hosts pin was added.
- ATT still failed with HTTP CONNECT, SOCKS remote DNS, LibreSSL, SecureTransport,
  verified IPv4/IPv6 destination addresses, and Chrome (`ERR_CONNECTION_CLOSED`).
  Restoring the source subscription's DNS in a temporary instance, without its
  listener or geodata downloads, also did not restore IPQS. The failing remote
  component remains unconfirmed; the already-sent IPQS support inquiry stands.
- v27 pauses subsequent Check.Place requests for the same target/family after
  its first confirmed block or HTTP 429. The source-specific policy lives in
  `providers/check_place.zsh`; skipped columns keep unknown values and explicit
  statuses. This reduces unnecessary blocked requests; it does not unblock the
  website. Other sources continue on their selected route.

Private evidence: `reports/{direct,att}-20261010-followup.*`,
`reports/providers-20261010-{browser,endpoint}-followup.json`,
`reports/ipqs-20261010-{tls,source-dns}-followup.json`, and
`reports/ipqs-20261010-direct-dns-account-proof.json`. Temporary browser and
Mihomo processes were closed; no active Clash or account state was changed.

Validation: **109 Ruby cases / 2,310 assertions**, **26 IPQS tests** and **31
provider-account tests** passed through the complete offline entry. The live
acceptance report `reports/att-20261010-v27-sub6.json` shows the first relay
block, four explicitly skipped relays, Cloudflare Intel `ok` and IPQS
`tls_error`. The externally maintained subscription advanced to `vps+sub6`
during this investigation; its ATT leaf fields match the frozen `vps+sub5`
release exactly, and the cached leaf matches the corresponding new release. The reporter
did not perform that subscription update.

## Earlier ATT provider investigation — 2026-10-10, v26

The earlier `v2026-10-10-standalone.26` authorized live reruns used
the current cached `vps+sub5` / `ATT` leaf and left live Clash unchanged.

- Cloudflare IP Intelligence succeeded, with the expected AS7018/US context.
  Check.Place's separate Cloudflare protection blocked its MaxMind, Scamalytics,
  AbuseIPDB, IP2Location and ipdata relay requests. Direct and `awshk` controls
  also returned HTTP 403 from Check.Place; their bodies did not carry the same
  Cloudflare block signature. This is not proof that ATT is unclean or that the
  Cloudflare Intel token failed.
- IPQS on ATT failed before HTTP, with curl 35 / HTTP 000. Its account API
  succeeded over direct IPv6 and `awshk`, initially reporting credits=5020 and
  usage=1. The same ATT target queried through `awshk` returned a valid official
  fraud score. No account/key/quota failure was established. A separate native
  HTTP client, header authentication, verified-DNS pinning and TLS 1.2 did not
  establish the ATT path. The exact failing network/edge component is unknown.
- Fixed a reporter bug that discarded IPQS curl/HTTP errors and continued from
  a failed account preflight into another lookup. Both stages now use the shared
  decoder; account failures stop before lookup, malformed bodies remain unknown,
  and table/JSON status correctly reports `tls_error`. No alternate route, DNS
  address or weaker certificate policy was added to production.
- Private evidence: `reports/att-20261010-investigation.*`,
  `reports/att-20261010-v26.*`, `reports/*20261010*diagnostics.json`,
  `reports/ipqs-20261010-dns-proof.json`,
  `reports/providers-20261010-route-comparison.json`, and
  `reports/ipqs-20261010-lookup-control.json`.

The user-authorized [IPQS support inquiry](mcp/ipqs/SUPPORT-TLS-20261010.md) was
sent at 17:36:37 Asia/Shanghai and independently verified in Gmail Sent.
No provider diagnosis is established yet; earlier September account/browser
evidence is historical.

Validation for v26: the complete offline entry passed **106 Ruby cases / 2,128
assertions**, **26 IPQS tests** and **31 provider-account tests**. Shell syntax,
diff whitespace and 82 local documentation links/anchors passed. The final ATT
rerun exited successfully, kept Cloudflare Intel available, and explicitly
reported the unresolved IPQS `tls_error` and Check.Place denials. A successful
report process does not mean every source succeeded.

## Shared HTTP/Chrome reuse — 2026-10-07

IPQS and provider-accounts now import `@myutils/browser-session` and/or
`@myutils/http-read` directly, with matching local dependencies/lockfiles and
documentation. MCP-specific helpers stay in mcps; IP/provider identity,
authentication, exact-leaf isolation and zsh/Ruby route policy stay here.
[Shared API](/Users/zmx/Projects/myutils/docs/NETWORK_API.md).

The full offline entry passes **105 Ruby cases / 2,043 assertions**, IPQS's
**26** tests and provider-accounts' **31** tests. IPQS's separate isolated
browser-text suite also passes. No live reputation lookup, provider login,
route/credential change or new third-party version was needed.

Worktree: `/Users/zmx/Projects/projects/ipquality`, branch
`main`. Start with [AGENTS.md](AGENTS.md)
for a network-free plan and route selection.

## Current behavior

- Reporter and every runner route default to `reputation`. Raw mail/DNSBL
  scopes remain optional; media/AI probes are removed.
- Cloudflare is in section 1 only: query status, ASN, ASN-country, ASN-type,
  organization and any supplied threat categories follow the relay or fallback
  basic data. Section 3 no longer has its column or ASN rows. Missing threat data
  is not a connection failure or a zero score; ASN type does not classify the individual
  IP as residential or VPN.
- Every attempted source stays in its applicable type/score/factor tables with
  aligned query statuses, including timeouts, TLS/certificate failures, rate
  limits and invalid responses. Unconfigured sources are also explicit. Repeated provider explanation
  footers are removed; credential mode, response tier and interpretation stay
  in JSON and [PROVIDERS.md](PROVIDERS.md). JSON now records every type source's
  status and adds IPinfo to `ProviderStatus`; unknown results never become clean.
- DB-IP uses a page plus one visitor lookup and accepts a label only for the
  tested egress. IPWHOIS uses its website request headers. Corrected requests
  returned risk data on September 24, superseding the earlier blanket
  unavailable-demo conclusion. Actual rate limits still remain unknown risk,
  without retries or route switching. Contracts and the historical NodeQuality
  comparison belong in [PROVIDERS.md](PROVIDERS.md).
- Shared helpers cover curl response envelopes, independent table-column widths
  and bounded jq values. IPinfo rejects changed nested objects; IPinfo/Ipregistry
  preserve transport failures; Shodan rejects fractional ports and control text.
  [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md) owns API/caller details, while
  [UPSTREAM.md](UPSTREAM.md) records removed wrappers and other modifications.
- [MCP_AUTH.md](MCP_AUTH.md) is the maintained MCP guide: server selection,
  first-call arguments, live/offline boundaries and dated login/2FA evidence.
  ipapi/Cloudflare routine account reads use saved-state HTTP without Chrome;
  recovery choices and the separate Cloudflare state-refresh step are documented
  there. IPQS TOTP enrollment and fresh-login proof belong to the earlier v25
  account audit; they are not repeated by documentation validation.

## Remaining issues

ATT-to-IPQS TLS access, direct IPv4 IPQS system DNS, and the Check.Place relay
denials remain unresolved in normal production runs as described above.
The earlier September ipapi failure is not a current blocker:
both October 10 ATT reports returned ipapi `ok`. Results describe those runs,
not a lasting provider-health guarantee.

## Recorded live evidence

These are earlier authorized reputation measurements. The earlier v25 account
audit performed the login checks recorded in MCP_AUTH.md without reputation
lookups. Reports remain private ignored outputs.

| Date / scope | Result and evidence |
| --- | --- |
| September 24, v22 Cloudflare only, isolated vps+yyssr22 / ATT | HTTP 200, exact target match; AS7018, US, isp, AT&T Enterprises, LLC. `risk_types` absent, `ip_lists`/`threat_summary` null. Sanitized receipt: `reports/cloudflare-v22-proof.json` |
| September 24, v22 display preview | `reports/cloudflare-v22-preview.txt` renders that single Cloudflare receipt; it is not a new multi-provider measurement |
| September 24, v21 ATT report | Exit 0 in 21.1 seconds, no jq errors; ten providers `ok`, including DB-IP, IPWHOIS, Cloudflare and IPQS. DB-IP supplied `low`; IPWHOIS supplied US and false proxy/VPN/Tor/hosting, with missing abuse/bot fields null. ipapi had a transport failure. Evidence: `reports/risk-v21-att-20260924-121527.json` and matching ANSI/text/stderr files |
| September 24, direct account-free MCP probes | Corrected DB-IP visitor and IPWHOIS requests supplied risk data; no account or 2FA was created |
| September 22, IPQS recovery | Account probe and authorized official lookup passed; the older zero-credit support case is historical. Details: [mcp/ipqs/HANDOFF.md](mcp/ipqs/HANDOFF.md) |

The v21 report predates the specific TLS-error labels; later diagnostics and
fixtures establish that distinction. Measurement owners stopped their temporary
Mihomo instances and left live Clash unchanged.

## Ownership and validation

IPQS lives in `mcp/ipqs` and shares `secrets/ipqs` with the reporter. Provider
HTTP/browser state, existing Cloudflare TOTP and the new IPQS TOTP remain private.
Both MCPs reuse the sibling mcps shared libraries. [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md)
maps APIs and owners; [SERVICES.md](SERVICES.md) explains stdio and browser lifetime.
There is no project-specific skill or duplicate README.

Validation on v25:

- `/bin/zsh -f scripts/test-offline`: **105 Ruby tests / 2,043 assertions**,
  **26 IPQS tests** plus build/static doctor, and **31 provider-account tests**;
  no failures or skips.
- Report cases verify Cloudflare appears only in section 1, in both languages
  and both relay/fallback basic-data paths. Failed queries cannot show stale
  context, and absent threat categories produce no extra line.
- `reports/basic-v24-layout-preview.txt` shows the new placement using fields
  supplied by the user (AS9808 / China Mobile); it is not a new network measurement.
- `npm --prefix mcp/ipqs run test:browser-text`: **10 synthetic cases** passed,
  including TOTP-challenge rejection and emergency-code redaction; no external
  requests or real profile used. Both rendered and inert text authentication
  checks reject a TOTP challenge even when dashboard navigation is present.
- Shell/Ruby syntax and `git diff --check` passed; maintained local documentation
  links and anchors were checked separately.

The subsequent documentation audit re-ran the full offline and synthetic suites,
reviewed all 13 maintained guides, and inspected both servers' actual
instructions/tool schemas over stdio without invoking account tools. It corrected
Ipregistry's unconfigured-column behavior, clarified HTTP-state recovery, and
consolidated repeated audit history. No new provider or account check was made.

The September 24 test/service audit retained all test cases, consolidated four
table-alignment checks into one independent Ruby assertion, and replaced exact
padding counts with score values plus alignment checks. The full offline and
ten-case synthetic browser suites passed again; tracked files stayed unchanged
during the final full run. Both MCP test guides remain current.

The service audit found no project launchd entry or user cron job, owned account
browser or listener on 19453/19503/19504. Node processes sharing this worktree were external
text-browser-kernel clients, not project daemons. Supervisor's three weekly
checks remain useful; its saved metadata confirms `mail.ipqs-quota-20260916`
was cancelled on September 22. No service needed removal or shutdown.
[SERVICES.md](SERVICES.md#external-checks) now distinguishes the weekly IPQS-only
test from complete project validation.

Follow-up test hardening bounds the TERM test's runner-exit wait to 15 seconds
and makes IPQS stdio shutdown errors fail the test. Fault injection confirmed
that an ignored TERM times out and both fixture children stop, and that a close
error is reported. The complete offline entrypoint passed again with the counts
above; no runtime or service behavior changed.

[TESTING.md](TESTING.md) owns complete/focused commands and their limits.
Configured remotes are `github-kratoszmx` (`kratoszmx/ip-quality`) and
`github-kratosbackup` (`kratosbackup/ipquality`); final synchronization receipts
belong to the completing task's report.
