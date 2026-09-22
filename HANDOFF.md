# Current handoff

## 2026-09-22 reputation-only default and provider ownership

Worktree: /Users/zmx/Projects/projects/ipquality, branch main, reporter
v2026-09-22-standalone.18. The raw reporter and all route-menu choices now use
reputation by default. Media/AI unlock probes and the Media JSON section were
removed. Optional raw-reporter mail, dnsbl, mail-dnsbl and full scopes remain;
full means reputation + mail + DNSBL. Exact-node requests still use an isolated
Mihomo and never change live Clash configuration.

A bare invocation remains a disclosure plan. The interactive live entrypoint is:

    /usr/bin/ruby --disable-gems bin/test-clash-leaf --confirm-network-lookup

The project-local common Ruby/zsh APIs remain in common/ and are documented in
[COMMON_FUNCTIONS.md](COMMON_FUNCTIONS.md). No old forwarding entrypoint remains.

## Real report evidence

A masked direct reputation report on 2026-09-22 completed in **19.5 seconds**,
exit 0, with **zero jq diagnostics**. All ten entries in ProviderStatus returned
ok, including IPQS, ipapi, IPWhois and Cloudflare. IPQS used official_api after
its credit preflight. ipapi was the anonymous context tier; it supplied no risk
flags. Cloudflare supplied ASN/organization/infrastructure context and no threat
categories, which remain null. This timing describes that direct run only.

The private, ignored local report is reports/validation-20260922-195035.json.
Its Mail fields are null compatibility fields; no SMTP/DNSBL probes ran.
The report has no Media section. No report was uploaded.

## Provider setup

- ipapi.is: free account registration was rejected on the existing proxy,
  direct route, and explicitly authorized isolated ATT route. All returned the
  same connection-policy message; no account/key is confirmed and no 2FA was
  created. Existing anonymous queries work. The documented free key would enable
  the full response and 1,000/day; anonymous access is 100/day per client route.
- ipwho.is: the no-key endpoint works and appears in the report. Its documented
  1,000/day allowance provides network/geography context, without free security
  fields. No account or 2FA is needed.
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

## Validation and Git

[TESTING.md](TESTING.md) owns complete/focused commands. The complete entrypoint
runs reporter fixtures plus both owned MCP packages without provider requests.
The complete check passed **84 reporter tests / 1,216 assertions**, **22 IPQS
tests**, and **18 provider-account tests**, with no failures. The reporter's
self-test covers the missing-threat JSON value as well as the 422 vendored DNSBL
entries. Parent mcps manifest validation and 13 authentication-probe tests passed;
Supervisor's focused migration/IPQS tests passed all 40 cases.

The configured GitHub destinations are kratoszmx/ip-quality (the existing remote
name) and kratosbackup/ipquality. Fresh authenticated API reads confirmed access
to the former; kratoszmx/ipquality returned 404. The local worktree is correctly
named ipquality. No GitHub repository was renamed or created.
