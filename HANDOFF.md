# Current handoff

Updated 2026-09-24. Worktree: `/Users/zmx/Projects/projects/ipquality`, branch
`main`, reporter `v2026-09-24-standalone.22`. Start with [AGENTS.md](AGENTS.md)
for a network-free plan and route selection.

## Current behavior

- Reporter and every runner route default to `reputation`. Raw mail/DNSBL
  scopes remain optional; media/AI probes are removed.
- Section 3 shows Cloudflare's actual threat categories and a compact ASN,
  ASN-country, ASN-type and organization table. Missing threat data is not a
  connection failure or a zero score; ASN type does not classify the individual
  IP as residential or VPN.
- Section 4 keeps attempted ipapi/IPWHOIS columns and aligned query statuses,
  including missing risk and TLS failures. Repeated provider explanation
  footers are removed; credential mode, response tier and interpretation stay
  in JSON and [PROVIDERS.md](PROVIDERS.md). The v22 display change altered no
  provider requests or JSON fields.
- DB-IP uses a page plus one visitor lookup and accepts a label only for the
  tested egress. IPWHOIS uses its website request headers. Corrected requests
  returned risk data on September 24, superseding the earlier blanket
  unavailable-demo conclusion. Actual rate limits still remain unknown risk,
  without retries or route switching. Contracts and the historical NodeQuality
  comparison belong in [PROVIDERS.md](PROVIDERS.md).

## Remaining issue

The September 24 keyed ipapi diagnostic returned HTTP 200/full data directly,
but isolated ATT returned curl 35 / `SSL_ERROR_SYSCALL` before HTTP. TLS 1.2
and the official US diagnostic host also failed on ATT. This supports a
route-specific TLS failure, not an invalid key, exhausted quota, or a proven
remote cause. It remains unresolved and was not remeasured by the later
Cloudflare-only check. Runtime preserves the canonical endpoint, certificate
verification and chosen route without a silent direct fallback.

## Recorded live evidence

These are earlier authorized measurements, not live checks performed by the
documentation audit. Reports remain private ignored outputs.

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
account state and the previously verified Cloudflare TOTP remain private.
Both MCPs reuse the sibling mcps shared libraries. [COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md)
maps APIs and owners; [SERVICES.md](SERVICES.md) explains stdio and browser lifetime.
There is no project-specific skill or duplicate README.

The September 24 documentation audit rechecked all 12 maintained Markdown files,
corrected stale MCP status and request counts, shortened the handoffs, and
clarified startup/dependencies/shutdown. No provider or account request was made
for this audit.

Validation on v22:

- `/bin/zsh -f scripts/test-offline`: **98 Ruby tests / 1,730 assertions**,
  **22 IPQS tests** plus build/static doctor, and **29 provider-account tests**;
  no failures or skips.
- `npm --prefix mcp/ipqs run test:browser-text`: passed all eight synthetic
  cases, with zero live requests and no real account profile.
- CLI plan/help, both MCP startup/EOF shutdown examples, 53 local documentation
  links/anchors, the five repository checks and `git diff --check` passed.

[TESTING.md](TESTING.md) owns complete/focused commands and their limits.
Configured remotes are `github-kratoszmx` (`kratoszmx/ip-quality`) and
`github-kratosbackup` (`kratosbackup/ipquality`); final synchronization receipts
belong to the completing task's report.
