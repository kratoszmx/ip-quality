# Current handoff

## 2026-09-24 visible provider coverage and permanent free DB-IP

Worktree: /Users/zmx/Projects/projects/ipquality, branch main, reporter
v2026-09-24-standalone.19. The raw reporter and all route-menu choices now use
reputation by default. Media/AI unlock probes and the Media JSON section were
removed. Optional raw-reporter mail, dnsbl, mail-dnsbl and full scopes remain;
full means reputation + mail + DNSBL. Exact-node requests still use an isolated
Mihomo and never change live Clash configuration.

A bare invocation remains a disclosure plan. The interactive live entrypoint is:

    /usr/bin/ruby --disable-gems bin/test-clash-leaf --confirm-network-lookup -4

The project-local common Ruby/zsh APIs remain in common/ and are documented in
[COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md). No old forwarding entrypoint remains.

## Real report evidence

A masked direct reputation report on 2026-09-24 completed in **19.9 seconds**,
exit 0, with **zero jq diagnostics**. All eleven entries in ProviderStatus returned
ok, including IPQS, ipapi, IPWhois, DBIP and Cloudflare. IPQS used official_api after
its credit preflight. ipapi used its new free key and returned **Mode=full**,
including the type, score and risk-factor data. Cloudflare supplied
ASN/organization/infrastructure context and no threat
categories, which remain null. This timing describes that direct run only.

The private, ignored local report is reports/providers-20260924-004804.json;
the matching .txt file contains the terminal output from the same lookup.
Its Mail fields are null compatibility fields; no SMTP/DNSBL probes ran.
The report has no Media section. No report was uploaded.

Section 3 now names Cloudflare with query status and threat categories, even
though its IP API has no numeric score. Missing categories remain "not supplied".
DB-IP also appears there with the free geography-only limitation. Section 4
contains ipwho.is with its country and unavailable security fields; the note and
JSON FactorMeta explain that missing free flags do not mean false. These are
visible capability distinctions, not locally synthesized risk ratings.

## Provider setup

- ipapi.is: free signup and email activation succeeded over explicitly verified
  direct Chrome access. The account uses the existing IPQS email and Hong Kong;
  its dashboard confirms the free 1,000/day plan. The key passed a complete API
  lookup and the real reporter returned Mode=full. The current account page has
  no native 2FA entry; none was created. Anonymous access remains 100/day per
  client route when no key is configured.
- ipwho.is: the no-key endpoint works and appears in the report. Its documented
  1,000/day allowance provides network/geography context, without free security
  fields. No account or 2FA is needed.
- DB-IP: official documentation and a live free 1.1.1.1 query confirm the
  permanent 500/day geography endpoint. The real report also returned DBIP=ok.
  No signup, key, 2FA or paid trial is needed. Threat levels and proxy detection
  belong to the paid Extended API, which remains excluded. Attribution is kept
  in terminal and JSON output; injected premium flags are ignored by fixtures.
- Cloudflare: the new free account and email verification succeeded. An
  account-scoped Intel Read token is saved privately and the official IP
  Intelligence API returned useful data. The documented free allowance is 100
  Threat Intelligence calls/month; the program does not invent remaining quota.
  API availability was established before starting TOTP setup. Current enrollment
  evidence is maintained in [the account MCP guide](mcp/provider-accounts/AGENTS.md).

Cloudflare TOTP enrollment, server-side enabled status, and a fresh independent
password/TOTP login all succeeded. Eight initial recovery codes and the seed are
stored privately. The fresh Chrome profile and both owned setup browsers were
closed after verification; the retained account profile remains on disk. No
ipapi 2FA was created. The new-login six-cell widget automatically submitted a
complete code, so a missing later Verify button was checked as a possible
successful navigation rather than triggering another authentication attempt.

The account browser's direct route needed a correction: clearing proxy environment
variables did not bypass macOS's enabled system proxy. Explicit DIRECT now passes
--no-proxy-server and verifies the bound Chrome process before reusing it. Prior
system-route/proxy and isolated ATT attempts were rejected; the corrected direct
attempt succeeded. The account parser also recognizes ipapi's activation notice
and icon-only logout, and binds its actual /app/home dashboard to the saved email
before importing a key. Regressions cover each of these cases.

A live Cloudflare response exposed a schema difference: belongs_to_ref.value was
an integer ASN while the documentation showed a string. The parser accepts a
bounded numeric ASN and renders AS<number>. Missing risk_types stays unknown,
including a null threat_summary; an explicitly empty risk array remains [].
The corresponding sanitized fixture and regression are in test/fixtures/cloudflare
and test/providers_test.rb. Category names containing commas remain whole JSON
strings. Context IP fields follow the same masking as Head.IP.

Anonymous ipapi responses cannot populate risk flags, even when unexpected
boolean fields are present. Mixed flat/nested schemas fail explicitly. All three
new sources have visible status lines and credential/tier explanations.

## MCP migration

The entire former mcps/security/ipqs-mcp package, including its private Chrome
profile and support receipts, now lives in mcp/ipqs. It reads the same flat
secrets/ipqs file as the reporter; the redundant old key and package directory
were removed. Shared JavaScript helpers remain direct dependencies on the sibling
mcps/common/shared packages. The mcps manifest, account probes and Supervisor
API/test paths now point to this owner. No live Codex configuration was edited.

The migrated official account probe returned authenticated, the relocated browser
auth check returned authenticated, and the real reporter completed its official
IPQS lookup. API credits and browser authentication remain separate evidence.
The provider-account MCP is in mcp/provider-accounts; it keeps account selectors,
free-plan policy, one-submit receipts and private credential handling local.

The 2026-09-24 mcps audit found no old IPQS package, duplicate credential,
private profile or temporary IPQS artifact in its current package/state/temp
locations. The remaining empty security/ directory was removed. Useful central
manifest, account-probe orchestration and documentation point directly here;
they contain no duplicate provider implementation. Current mcps manifest
validation passed; concurrent mcps edits were preserved, with no mcps commit.

The existing provider-account MCP now exposes public_provider_verify_free_api
for DB-IP/ipwho.is. It reuses shared HTTP reads, performs one fixed free lookup,
validates useful context, and reports that these APIs have no account/MFA or
free risk fields. Both live probes passed. No new provider account or factor
was created; Cloudflare's 2026-09-22 verified factor remains in place.

## Validation and Git

[TESTING.md](TESTING.md) owns complete/focused commands. The complete entrypoint
runs reporter fixtures plus both owned MCP packages without provider requests.
The complete check passed **88 reporter tests / 1,303 assertions**, **22 IPQS
tests**, and **25 provider-account tests**, with no failures. The reporter's
self-test covers the missing-threat JSON value as well as the 422 vendored DNSBL
entries. Parent mcps manifest validation passed again on 2026-09-24. The prior
2026-09-22 migration validation passed 13 parent authentication-probe cases and
40 Supervisor migration/IPQS cases; no parent/Supervisor source changed this turn.

The configured GitHub destinations are kratoszmx/ip-quality (the existing remote
name) and kratosbackup/ipquality. Fresh authenticated API reads confirmed access
to the former; kratoszmx/ipquality returned 404. The local worktree is correctly
named ipquality. No GitHub repository was renamed or created.
