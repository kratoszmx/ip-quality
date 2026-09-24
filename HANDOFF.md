# Current handoff

Updated 2026-09-24. Worktree: `/Users/zmx/Projects/projects/ipquality`, branch
`main`, reporter `v2026-09-24-standalone.25`. Start with [AGENTS.md](AGENTS.md)
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

## Remaining issue

The September 24 keyed ipapi diagnostic returned HTTP 200/full data directly,
but isolated ATT returned curl 35 / `SSL_ERROR_SYSCALL` before HTTP. TLS 1.2
and the official US diagnostic host also failed on ATT. This supports a
route-specific TLS failure, not an invalid key, exhausted quota, or a proven
remote cause. It remains unresolved and was not remeasured by the later
Cloudflare-only check. Runtime preserves the canonical endpoint, certificate
verification and chosen route without a silent direct fallback.

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

- `/bin/zsh -f scripts/test-offline`: **105 Ruby tests / 2,030 assertions**,
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

[TESTING.md](TESTING.md) owns complete/focused commands and their limits.
Configured remotes are `github-kratoszmx` (`kratoszmx/ip-quality`) and
`github-kratosbackup` (`kratosbackup/ipquality`); final synchronization receipts
belong to the completing task's report.
