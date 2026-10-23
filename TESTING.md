# Offline tests

## Run from a fresh session

Use macOS `/bin/zsh`, `/usr/bin/ruby` with its bundled `minitest`, `jq` on PATH,
and `/usr/sbin/lsof`. The owned account MCP suites additionally need Node 24.5+
and their lockfile dependencies. Normal system utilities are also used. No API
key, Clash cache, or installed Mihomo is needed. Keep Ruby gems enabled for
tests; `--disable-gems` is for the production route runner, not Minitest.

```text
cd /Users/zmx/Projects/projects/ipquality
/bin/zsh -f scripts/test-offline
```

The command loads every top-level `test/*_test.rb` into one Minitest run, then
runs the IPQS build/tests/static doctor and provider-account MCP tests. It pins
`LC_ALL=en_US.UTF-8` (direct Ruby suite runs do the same through
`test/support/utf8_locale.rb`), runs every suite even after a failure and ends
with `OFFLINE TESTS OK` or the failed suite names. Success means exit status 0. The reporter count and random seed
appear separately from the Node package counts. A failure names its test and line;
fix the cause and rerun the affected test, then the complete suite.

These tests make no external HTTP, DNS, SMTP, SSH, or paid-provider requests.
Runner lifecycle tests briefly open a fake listener on `127.0.0.1` and inspect
its ownership with `lsof`. A restricted environment that forbids local listeners
cannot establish lifecycle coverage; report that limitation instead of skipping
the tests and claiming a complete pass.

## Find the right test

| File | Responsibility |
| --- | --- |
| `test/common_test.rb` | Secret curl stdin/argument boundaries and exit status, HTTP envelopes/transport errors/state reset, printable text, nullable jq predicates, table widths/shape, proxy overrides and snapshot link/mode/size boundaries |
| `test/ip_quality_test.rb` | CLI plans, option parsing and rejection gates, `--help`/`--version`, address/prefix/decimal validators, per-scope required commands and dependency failure, fixture DNSBL (DNS status, complete answers and unknown errors) and mail (egress discovery, MX, SMTP) execution |
| `test/providers_test.rb` | Provider parsing, literal JSON escaping across legacy adapters, ipapi runtime outcomes, Ping0 transport/HTTP/schema failures and visible status, unknown/failure semantics, credentials, zero-credit preflight |
| `test/check_place_test.rb` | Relay block/429 pauses and target/family/run isolation; MaxMind schema validation, stale-field clearing, translation failure, literal text/zero coordinates, and actual JSON/terminal IPinfo fallback |
| `test/source_selection_test.rb` | Source presets/IDs, no-network validation, runner forwarding, failed columns, default full-run DNS/Scamalytics repair, unchanged IPv6/proxy routes and private auth/target binding |
| `test/query_route_test.rb` | Target-preserving IPQS/Cloudflare direct fallback; sticky IPQS account/lookup route, IPv6 targets, bounded failures, no retry on response/certificate/quota errors, credential privacy and terminal/JSON provenance |
| `test/scamalytics_test.rb` | Target/heading/badge agreement, bounded schema, nullable/conflicting factors, one same-route page fallback and preserved relay success |
| `test/public_fallbacks_test.rb` | IP2Location target-bound page JSON, old/current ipdata demo-key syntax and booleans, full-flow fallback recovery, route/failure retention and official AbuseIPDB key privacy |
| `test/public_demo_test.rb` | DB-IP visitor and IPWHOIS demo parsers: labels/boolean flags, quota errors, partial/malformed data, target binding, state reset, DB-IP two-request flow and bounded guest token, IPWHOIS one-request headers, and DB-IP/Ping0 explicit-target request suppression |
| `test/report_test.rb` | Provider tables, ANSI/layout, JSON typing/escaping/masking, file bytes, exclusive report creation |
| `test/repository_test.rb` | Runtime-source bans (zsh and the Ruby runner), vendored references, file safety and AGPL provenance |
| `test/route_runner_test.rb` | Menu and non-interactive listing/plan paths, option-combination rules, cached selection, YAML safety, exact leaf/dependencies, `--config-test-only`, proxy isolation, process cleanup |
| `test/prefix_sample_test.rb` | Multiline /24 sampling and deduplication, bounded/public input parity, no-consent/no-cache menu, proxy isolation, private result files, provider failures/percent scores, malformed/mismatched reports, interruption/TERM cleanup |
| `test/support/reporter_test_case.rb` | Shared base class: paths, `zsh`/`zsh!` probe runners, `fixture_path`/`provider_library`, named zsh function extraction, isolated reporter copies with network tripwires, `run_route`, `with_environment` |
| `test/fixtures/` | Sanitized provider responses; data only |
| `mcp/ipqs/tests/` | Official account/API, saved login, TOTP issuer/account/form policy, secrets and MCP contracts |
| `mcp/provider-accounts/tests/` | HTTP identity/state, signup/TOTP/recovery policy, public-provider probes, private output and MCP contracts |

Each suite can run directly. Minitest options pass through the complete runner
to the Ruby aggregate only; both Node suites still run in full. Replace the
example seed with the one from a failing run:

```text
/usr/bin/ruby test/providers_test.rb
/usr/bin/ruby test/report_test.rb --name test_report_writer_rejects_existing_files_links_and_missing_parents
/bin/zsh -f scripts/test-offline --seed 12345
npm --prefix mcp/ipqs run check
npm --prefix mcp/provider-accounts test
```

For a reporter-only aggregate, run from the root:

```text
/usr/bin/ruby -e 'Dir.glob("test/*_test.rb").sort.each { |file| require File.expand_path(file) }'
```

MCP dependencies reference `/Users/zmx/Projects/myutils` and the HTTP/Chrome
libraries in `/Users/zmx/Projects/myutils/net_utils/node` through local
`file:` paths. Both sibling checkouts and cached registry packages must be present
before restoring dependencies with `npm ci --offline --ignore-scripts` in `mcp/`.
Both packages are npm workspaces of `mcp/package.json`, sharing one reviewed
`mcp/package-lock.json` and one `mcp/node_modules`. The complete runner needs both packages; reporter-only
validation does not. No install runs as part of the test entrypoint.

To include every test, also run the separate IPQS browser-text suite below. It
needs an installed Chrome, opens an isolated temporary browser context, and
intercepts all requests locally. It uses neither the account profile nor the
live IPQS service. Also run it whenever `dashboard-text.ts` changes; see the
[IPQS guide](mcp/ipqs/AGENTS.md) and
[provider-account guide](mcp/provider-accounts/AGENTS.md) for package details.

```text
npm --prefix mcp/ipqs run test:browser-text
```

The external Supervisor weekly test entry runs the complete offline runner;
the separate browser-text check remains manual.
See [SERVICES.md](SERVICES.md#external-checks) for scheduling ownership.

## Maintain the boundary

Use the ownership table above to find existing coverage before adding tests.
Preserve distinct outcomes: unknown versus false/zero, original route failures
versus fallback results, selected versus disabled sources, and HTTP success
versus authenticated account identity. Request counts, target/route binding,
credential redaction, consent gates and owned-process cleanup are behavior
contracts, even when several providers need similar cases. These fixture passes
do not prove a live account session or current provider availability.

- Reporter CLI tests copy only runtime source/data into an owned temporary
  directory, use an empty credentials configuration directory, and replace
  network commands with fixtures or rejecting tripwires. They do not copy real
  project secrets. The tripwires cover command lookups, not arbitrary new socket
  APIs or absolute-path executables; review any newly introduced transport.
- Provider and rendering probes load local libraries or named reporter
  functions. Keep source schemas, expected fields, and fixtures in their owning
  suite; share only setup with matching semantics. The source audit reads
  maintained source/data directories, not user reports, secrets, or caches.
- Route tests use private profiles, fake reporters/Mihomo, and owned temporary
  workspaces. The lifecycle launcher injects the session's existing `temp_parent`
  argument in its test child; setting `TMPDIR` alone cannot override the
  production preferred directory. Cleanup checks use the configuration path
  recorded by fake Mihomo. The TERM test allows 15 seconds for runner shutdown;
  timeout fails the test and its ensure block stops the owned fixture children.
  Preserve success, failure, signal, abandoned-workspace,
  route, link, and malformed-input coverage.
- Shared myutils behavior (redaction rules, TOTP, secret files) is tested in
  myutils; project suites cover only how this project applies it.
- Probes source the reporter in definition-only mode or extract named
  functions; use the base-class helpers instead of raw `Open3` calls, and
  table-driven cases instead of near-identical test methods.
- New suites belong at `test/*_test.rb`; helpers and data belong under
  `test/support/` and `test/fixtures/`. Add a sanitized parser fixture with each
  provider. Prefer observable results over exact implementation strings; keep
  source checks for explicit provenance and prohibited-runtime constraints.
  Internal variable names, retired helper filenames and optional-section
  numbering are not contracts. Keep ANSI byte checks in the table-rendering
  case instead of repeating the same fixture in a separate color-output test.

Before committing, also run `git diff --check`. Record the current aggregate
result in [HANDOFF.md](HANDOFF.md). A passing suite proves the local code against
fixtures; provider availability and real-node connectivity require a separate
authorized measurement under [AGENTS.md](AGENTS.md) and [PROVIDERS.md](PROVIDERS.md).
