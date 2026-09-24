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
runs the IPQS build/tests/static doctor and provider-account MCP tests. Success
means exit status 0 with every suite passing. The reporter count and random seed
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
| `test/common_test.rb` | Printable text, jq value types/bounds/controls, proxy overrides, verified-file snapshots |
| `test/ip_quality_test.rb` | CLI plans and rejection gates, dependency failure, fixture DNSBL/SMTP execution |
| `test/providers_test.rb` | Provider parsing, unknown/failure semantics, credentials, zero-credit preflight |
| `test/dbip_test.rb` | Demo exact-IP/geography validation, no invented score and one-request runtime |
| `test/public_demo_test.rb` | DB-IP labels/IPWHOIS boolean flags, HTTP 200 quota errors, partial/malformed data, target binding and state reset |
| `test/report_test.rb` | Provider tables, ANSI/layout, JSON/file bytes, exclusive report creation |
| `test/repository_test.rb` | Source/data safety, vendored references, provenance, removed runtime paths |
| `test/clash_leaf_runner_test.rb` | Cached selection, YAML safety, exact leaf/dependencies, proxy isolation, process cleanup |
| `test/support/reporter_test_case.rb` | Shared paths, named zsh function probes, isolated reporter copies and fake commands |
| `test/fixtures/` | Sanitized provider responses; data only |
| `mcp/ipqs/tests/` | Official account/API, saved-login, secret and MCP contracts |
| `mcp/provider-accounts/tests/` | Free-account policy, one-submit form handling, private output and provider MCP contracts |

Each suite can run directly. Minitest options also pass through the complete
runner; replace the example seed with the one from a failing run:

```text
/usr/bin/ruby test/providers_test.rb
/usr/bin/ruby test/report_test.rb --name test_report_writer_rejects_existing_files_links_and_missing_parents
/bin/zsh -f scripts/test-offline --seed 12345
npm --prefix mcp/ipqs run check
npm --prefix mcp/provider-accounts test
```

`bin/test-clash-leaf` is the product's route command, not a test suite. Do not
execute every file whose name contains `test`. The canonical runner includes
the reporter's `--self-test` once; it need not be run separately for a full pass.

For a reporter-only aggregate, run from the root:

```text
/usr/bin/ruby -e 'Dir.glob("test/*_test.rb").sort.each { |file| require File.expand_path(file) }'
```

MCP dependencies reference the existing sibling `mcps/common/shared` packages;
restore from the local npm cache with `npm install --offline --ignore-scripts`
inside each package when needed. No install runs as part of the test entrypoint.

To include every test, also run the separate IPQS browser-text suite below. It
needs an installed Chrome, opens an isolated temporary browser context, and
intercepts all requests locally. It uses neither the account profile nor the
live IPQS service. Also run it whenever `dashboard-text.ts` changes; see the
[IPQS guide](mcp/ipqs/AGENTS.md) and
[provider-account guide](mcp/provider-accounts/AGENTS.md) for package details.

```text
npm --prefix mcp/ipqs run test:browser-text
```

## Maintain the boundary

The DB-IP regression tests cover the two-step visitor request, route/family
preservation, target mismatch, bounded guest-token parsing, and stopping after
page/transport/quota failures. IPWHOIS tests require its website request headers.
Report tests retain ipapi.is for anonymous, limited and failed lookups in both
languages, with missing values distinct from false. Query statuses stay aligned
inside the factor matrix, including long TLS-error labels. Cloudflare's ASN
context is visible in section 3 even when categories are missing; failed or empty
context queries create no context table. Categories keep null and empty-array
meanings, numeric scores remain absent, and routine provider footers stay removed.
MCP tests separately cover
request_egress metadata, visitor-token redaction and no-retry behavior.

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
  recorded by fake Mihomo. Preserve success, failure, signal, abandoned-workspace,
  route, link, and malformed-input coverage.
- New suites belong at `test/*_test.rb`; helpers and data belong under
  `test/support/` and `test/fixtures/`. Add a sanitized parser fixture with each
  provider. Prefer observable results over exact implementation strings; keep
  source checks for explicit provenance and prohibited-runtime constraints.

Before committing, also run `git diff --check`. Record the current aggregate
result in [HANDOFF.md](HANDOFF.md). A passing suite proves the local code against
fixtures; provider availability and real-node connectivity require a separate
authorized measurement under [AGENTS.md](AGENTS.md) and [PROVIDERS.md](PROVIDERS.md).
