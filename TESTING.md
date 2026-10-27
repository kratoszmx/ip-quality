# Offline tests

## Run everything

```text
cd /Users/zmx/Projects/projects/ipquality
/bin/zsh -f scripts/test-offline
```

Prerequisites: macOS `/bin/zsh`, `/usr/bin/ruby` with its bundled Minitest,
`jq` on `PATH` and `/usr/sbin/lsof`. The two account MCP suites also need Node
24.5+ and the dependencies restored once with `npm ci --offline --ignore-scripts`
in `mcp/` (the lockfile references sibling `/Users/zmx/Projects/myutils`
packages through `file:` paths). No API key, Clash cache or Mihomo is needed.

The runner pins `LC_ALL=en_US.UTF-8`, loads every `test/*_test.rb` into one
Minitest run, then runs `npm --prefix mcp/ipqs run check` (TypeScript build,
tests, static doctor) and `npm --prefix mcp/provider-accounts test`. Every suite
runs even after a failure; the last line is `OFFLINE TESTS OK` or
`OFFLINE TESTS FAILED: <suites>`, with exit status 0 only on success. The whole
run takes about 10–20 seconds.

Nothing contacts external HTTP, DNS, SMTP, SSH or paid providers. Runner
lifecycle tests open a fake listener on `127.0.0.1` and check its owner with
`lsof`; an environment that forbids local listeners cannot prove lifecycle
coverage, so report that instead of claiming a complete pass. A fixture pass
proves neither a live account session nor current provider availability.

## Focused runs

Minitest options pass through the complete runner to the Ruby suites only.

```text
/usr/bin/ruby test/providers_test.rb
/usr/bin/ruby test/report_test.rb --name test_report_writer_rejects_existing_files_links_and_missing_parents
/bin/zsh -f scripts/test-offline --seed 12345
npm --prefix mcp/ipqs run check
npm --prefix mcp/provider-accounts test
```

Reporter suites only:

```text
/usr/bin/ruby -e 'Dir.glob("test/*_test.rb").sort.each { |file| require File.expand_path(file) }'
```

The IPQS browser-text suite is separate and manual: it needs installed Chrome,
uses a synthetic profile and intercepts every request locally. Run it whenever
`mcp/ipqs/src/dashboard-text.ts` changes:

```text
npm --prefix mcp/ipqs run test:browser-text
```

Supervisor's weekly `test.ipquality.test-offline` runs the complete runner
([SERVICES.md](SERVICES.md#external-weekly-check)).

## Find the right test

Each suite maps to one area of the code; check it before adding coverage.

| File | Covers |
| --- | --- |
| `test/common_test.rb` | `common/`: secret curl stdin, HTTP envelopes, batched jq fields, jq predicates, proxy overrides, ANSI cleanup, DMS and map links |
| `test/ip_quality_test.rb` | `bin/ip-quality`: plans, option parsing and gates, `--help`/`--version`, validators, per-scope required commands, fixture DNSBL and mail runs |
| `test/providers_test.rb` | Provider parsers and adapters: literal JSON, ipapi and Ping0 outcomes, Cloudflare/Ipregistry/IPQS/Shodan/RIPEstat, credentials, IPQS preflight |
| `test/check_place_test.rb` | Check.Place relay pauses and MaxMind validation with IPinfo fallback |
| `test/scamalytics_test.rb` | Scamalytics page parsing and its single same-route fallback |
| `test/public_fallbacks_test.rb` | IP2Location public fallback; ipdata owned-key risk, relay versus keyless geography, target binding, unknown risk, key redaction and route/failure preservation; official AbuseIPDB key use |
| `test/public_demo_test.rb` | DB-IP visitor and IPWHOIS demos; explicit-target request suppression |
| `test/source_selection_test.rb` | Source presets/IDs, IPQS AliDNS policy, deselected versus failed sources |
| `test/query_route_test.rb` | IPQS/Cloudflare direct-IPv4 fallback, target preservation, provenance |
| `test/report_test.rb` | `report/`: matrices, layout widths, JSON typing/masking, report files |
| `test/repository_test.rb` | Runtime-source bans, vendored references, file safety, AGPL provenance |
| `test/route_runner_test.rb` | `bin/ip-quality-route` and `runner/`: menus, listings, option rules, leaf rendering, Mihomo lifecycle, snapshots, printable text |
| `test/prefix_sample_test.rb` | Prefix input rules, batch files, failure/interrupt evidence |
| `mcp/ipqs/tests/` | IPQS API, HTTP/session auth classification, TOTP policy, secrets, default-windowless stdio contract |
| `mcp/provider-accounts/tests/` | HTTP identity versus account suspension, reviewed login/terms/challenge outcomes, ipapi automatic-login stop, signup/TOTP, public-provider probes, ipdata Cognito identity/expired tokens/official risk projection, private origin-scoped restoration and default-windowless stdio contract |

All reporter suites inherit `test/support/reporter_test_case.rb`:

| Helper | Use |
| --- | --- |
| `zsh(probe, *args)` / `zsh!(probe, *args)` | Run a zsh snippet; `zsh!` also asserts success and empty stderr and returns stdout |
| `reporter_functions(*names)` | Source text of named reporter functions, for probes that need only a few |
| `run_script(*args, env:)` | Run a copy of the reporter in a private workspace whose `curl`/`dig`/`nc`/`ssh` are tripwires unless replaced by `write_fake_command` |
| `run_route(args, stdin:, **options)` | Run the route command in-process; the Clash cache defaults to an absent directory |
| `fixture_path`, `fixture_json`, `provider_library`, `write_ipqs_key`, `with_environment`, `NO_PROXY_ENV` | Fixture paths, provider sources, a workspace IPQS key, temporary `ENV` overrides and a proxy-free environment |

Suites that neither change `ENV` nor send signals call `parallelize_me!` and run
concurrently after the serial ones (`route_runner_test.rb` and
`prefix_sample_test.rb`), which halves the reporter run time. A new suite that
uses `with_environment` or process signals must stay serial.

## Writing tests that last

- Assert observable outcomes: unknown versus false/zero, the original route
  failure versus the fallback result, selected versus disabled sources, request
  counts and target binding, and that secrets never reach arguments or output.
- Prefer one table-driven test over several near-identical methods, and keep a
  provider's schema cases in its own suite. Every new provider gets a sanitized
  fixture in `test/fixtures/<provider>/`.
- Shared myutils behavior (redaction, TOTP, secret files) is tested in myutils;
  here, test only how this project applies it.
- Fake network commands match on the request and append to a calls file, so a
  test can prove both what was sent and that nothing else was. The tripwires
  cover command lookups, not new socket APIs or absolute-path executables, so
  review any new transport.
- Lifecycle tests inject `temp_parent` into the real `IsolatedMihomoSession`
  (setting `TMPDIR` cannot redirect the production workspace) and stop their
  own fixture children in `ensure`. Keep success, failure, signal and
  abandoned-workspace cases.
- Source-text checks are for provenance and prohibited runtime constructs only;
  internal names, helper filenames and section numbers are not contracts.

Before committing, run the complete suite and `git diff --check`, and update the
status line in [HANDOFF.md](HANDOFF.md).
