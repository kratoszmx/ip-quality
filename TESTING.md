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
`OFFLINE TESTS FAILED: <suites>`, with exit status 0 only on success. On the M4
the whole run takes about 10–15 seconds: reporter 5–8 s depending on load, IPQS
~3 s, provider accounts ~1 s.

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

After IPQS dashboard-read changes, also run the manual Chrome fixture. It checks
visible API-key candidates and hidden/CSS/inert exclusions with every request
blocked:

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
| `test/ip_quality_test.rb` | `bin/ip-quality`: plans, option parsing, live gates, failed egress discovery and its TLS-handshake rounds, the same-route TLS-handshake retry, `--help`/`--version`, validators and IPv4 range boundaries, per-scope required commands, fixture DNSBL and mail runs |
| `test/providers_test.rb` | Provider parsers and adapters: literal JSON, ipapi and Ping0 outcomes, Cloudflare/Ipregistry/IPQS/Shodan/RIPEstat, credential loading and rejection, IPQS preflight |
| `test/check_place_test.rb` | Check.Place relay pauses and MaxMind validation with IPinfo fallback |
| `test/scamalytics_test.rb` | Scamalytics page parsing and its single same-route fallback |
| `test/public_fallbacks_test.rb` | IP2Location public fallback; ipdata owned-key risk, relay versus keyless geography, target binding, key redaction and route/failure preservation; official AbuseIPDB key use |
| `test/public_demo_test.rb` | DB-IP visitor/page fallback and IPWHOIS demos; explicit-target suppression, quota distinctions, target binding and preserved failure metadata |
| `test/source_selection_test.rb` | Source presets/IDs, IPQS AliDNS policy, deselected versus failed sources |
| `test/query_route_test.rb` | IPQS/Cloudflare direct-IPv4 fallback end to end, plus the whole retry/no-retry matrix of `query_route_request` in one probe |
| `test/report_test.rb` | `report/`: matrices, terminal cell widths, fallback labels, JSON typing, full addresses and routed prefixes, report files |
| `test/repository_test.rb` | Runtime-source bans, vendored references, file safety, AGPL provenance |
| `test/route_runner_test.rb` | `bin/ip-quality-route` and `runner/`: menus, listings, option rules, one-target reporting, leaf rendering, Mihomo lifecycle, snapshots, printable text |
| `mcp/ipqs/tests/` | IPQS API, HTTP auth (concealed logout links, lookalike attributes), dashboard text over an intercepted HTTP client with a synthetic shared profile and cookie write-back, TOTP independent of a completed CAPTCHA field, shared-Chrome tabs and release, secrets, default-windowless stdio contract |
| `mcp/provider-accounts/tests/` | HTTP identity versus account status, with the shared profile's cookies and `browser_unavailable` when its Chrome cannot start; login/terms/challenge outcomes, including a resolved initial 403 reaching form validation; ipapi session reuse and normal expired-session login; signup/TOTP; public-provider probes; ipdata identity from the dashboard's shared-profile token, expired tokens and risk projection; shared-Chrome tabs (own reads, kept flows per provider, release) in `browser-read.test.mjs`; the cookie diff and write-back of `mcp/common/shared-cookies.mjs` (`shared-cookies.test.mjs`); shared checkbox verification (`verification.test.mjs`); DB-IP page reads from a sanitized fixture and injected reader (`dbip-page.test.mjs`); stdio contract |

The MCP suites resolve the shared Chrome modules (`@myutils/web-text/shared-chrome`,
`/dedicated-chrome`) to synthetic ones and intercept HTTP; no real profile,
credential, Chrome process or provider request is involved.

All reporter suites inherit `test/support/reporter_test_case.rb`:

| Helper | Use |
| --- | --- |
| `zsh(probe, *args)` / `zsh!(probe, *args)` | Run a zsh snippet; `zsh!` also asserts success and empty stderr and returns stdout |
| `reporter_functions(*names)` | Source text of named reporter functions, for probes that need only a few |
| `run_script(*args, env:)` | Run a copy of the reporter in a private workspace whose `curl`/`dig`/`nc`/`ssh` are tripwires unless replaced by `write_fake_command` |
| `run_route(args, stdin:, **options)` | Run the route command in-process; the Clash cache defaults to an absent directory |
| `fixture_path`, `fixture_json`, `provider_library`, `write_ipqs_key`, `with_environment`, `NO_PROXY_ENV` | Fixture paths, provider sources, a workspace IPQS key, temporary `ENV` overrides and a proxy-free environment |

Suites that neither change `ENV` nor send signals call `parallelize_me!` and run
concurrently after the serial `route_runner_test.rb`. The base class sizes Minitest's pool to one thread per
core (system Ruby's Minitest 5.11 otherwise uses two); set `N` to override. A new
suite that uses `with_environment` or process signals must stay serial.

## Writing tests that last

- Assert observable outcomes: unknown versus false/zero, the original route
  failure versus the fallback result, selected versus disabled sources, request
  counts and target binding, and that secrets never reach arguments or output.
- Process count is the suite's cost. Run a decision matrix (a parser's invalid
  bodies, a status mapping, the retry policy) in one zsh probe that loops over
  its cases, and keep full `run_script` reporter runs for a few representative
  end-to-end cases. Moving the 14-case query-route matrix into one probe cut
  that suite from about 7.7 s to 0.5 s.
- Prefer one table-driven test over several near-identical methods, and keep a
  provider's schema cases in its own suite. Every new provider gets a sanitized
  fixture in `test/fixtures/<provider>/`.
- Shared myutils behavior (redaction, TOTP, secret files) is tested in myutils;
  here, test only how this project applies it.
- Fake network commands match on the request and append to a calls file, so a
  test can prove both what was sent and that nothing else was. Functions stubbed
  inside a probe often run in a `$(...)` subshell, so record calls in a file, not
  a shell variable. Requests that read an HTTP code pass
  `--write-out $'\n%{http_code}'`, so a fake that logs `"$*"` writes two lines
  per call; log `"${*//$'\n'/ }"` or a request label when counting lines. The
  reporter's retry pause is the `sleep` command, which a fake can record. The
  tripwires cover command lookups, not new socket APIs or absolute-path
  executables, so review any new transport.
- Fixtures spell control and combining characters as escapes (`\u0301`,
  `\0`, `\e`). Some editing tools write the decoded character instead, which
  still passes but hides the case; check `git diff` for raw bytes.
- Lifecycle tests inject `temp_parent` into the real `IsolatedMihomoSession`
  (setting `TMPDIR` cannot redirect the production workspace) and stop their
  own fixture children in `ensure`. Keep success, failure, signal and
  abandoned-workspace cases.
- Source-text checks are for provenance and prohibited runtime constructs only;
  internal names, helper filenames and section numbers are not contracts.

Before committing, run the complete suite and `git diff --check`, and update
your lane's entry in [HANDOFF.md](HANDOFF.md).
