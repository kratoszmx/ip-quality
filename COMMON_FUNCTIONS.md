# Project common functions

`common/` holds generic implementations used by two or more modules; code with
one consumer lives in that module. Load the file
directly; there are no forwarding copies. Loading performs no network access,
credential read or environment mutation. zsh functions preserve caller options
(including `KSH_ARRAYS`); predicates answer through exit status and value
functions print without a trailing newline.

| File | Production callers | Responsibility |
| --- | --- | --- |
| `common/provider_values.zsh` | Provider parsers/adapters (each imports it for standalone fixture runs) and `bin/ip-quality` | Validate/normalize provider values and HTTP envelopes, no source schemas |
| `common/http_request.zsh` | Credential-bearing adapters, Check.Place/IPWHOIS public reads, `providers/query_route.zsh`, `bin/ip-quality` | Secret URL/header options over curl stdin, bounded public JSON GETs and proxy-route detection |
| `common/json_values.jq` | Check.Place/MaxMind, ipapi, Cloudflare, IPWHOIS, DB-IP, IP2Location, ipdata, Ipregistry, IPQS, AbuseIPDB, Shodan parsers | Nullable boolean and bounded text/integer predicates |
| `common/terminal.zsh` | All provider adapters (progress), `report/`, `bin/ip-quality` | ANSI cleanup and stderr progress lines |
| `common/location.zsh` | Check.Place/MaxMind and IPinfo adapters | Coordinate DMS text and Check.Place map links |
| `common/network_environment.rb` | Direct route command, isolated Mihomo session | Child-process overrides removing inherited proxies |

## zsh provider values (`provider_values.zsh`)

| Function | Result |
| --- | --- |
| `provider_json_is_object JSON` | Exit 0 only for a JSON object accepted by `jq`; parser output suppressed |
| `provider_integer_in_range VALUE MIN MAX` | Exit 0 for three nonnegative integer strings with `MIN <= VALUE <= MAX` |
| `provider_merge_boolean_signals SIGNAL...` | `true` if any signal is `true`; `false` only for a nonempty all-`false` list; otherwise empty (unknown) |
| `provider_has_observation VALUE...` | Exit 0 if any value is not empty, `null` or `unknown` (case-insensitive); `false` counts |
| `provider_http_failure_status CODE BODY` | `cloudflare_blocked` (403 block page), `rate_limited` (429), `http_NNN`, or `network_error`; never echoes the body |
| `provider_decode_http_response WIRE CURL_EXIT` | Resets `provider_http_response` (`status`, `http_code`, `body`); exit 0 only for curl success plus a 2xx envelope. Curl 28/35/60 keep timeout/TLS/certificate statuses; failure clears the body |
| `is_nonnegative_decimal VALUE`, `is_signed_decimal VALUE` | Exit 0 for a plain (signed) decimal string such as `0.25` or `-97.8`; no arithmetic |
| `provider_json_fields JSON PROGRAM NAME...` | One `jq` pass over comma-separated scalar expressions; fills `provider_fields[NAME]` with `jq -r` spellings (`null` kept, NULs dropped); 1 with empty fields on a jq error or count mismatch |

```zsh
source common/provider_values.zsh
provider_merge_boolean_signals false unknown  # empty: missing evidence stays unknown
provider_decode_http_response $'{"example":true}\n200' 0
print -r -- "${provider_http_response[status]}"
```

The HTTP decoder also serves Ping0's plain-text adapter; it is independent of
JSON syntax. The provider's own parser validates the body only after transport
and HTTP success, so an HTTP error with plausible data cannot become evidence.

## zsh HTTP requests (`http_request.zsh`)

| Function | Result |
| --- | --- |
| `curl_with_secret_url URL [CURL_ARG...]` | Sends the URL through curl's stdin configuration; forwards other arguments intact; keeps curl's output and exit status |
| `curl_with_secret_header NAME VALUE URL [CURL_ARG...]` | Same, also sending one header through stdin |
| `provider_fetch_public_json FAMILY URL [MAX_BYTES] [CURL_ARG...]` | One bounded GET over the reporter's `$CurlARG` interface; sets `PROVIDER_RESPONSE_STATUS`/`BODY`, exit 0 only for a 2xx JSON object |
| `http_route_is_proxied` | Exit 0 when an inherited proxy variable or the runner's `IPQUALITY_ISOLATED_EGRESS` is set (not the plain system route); used by the CLI, IPQS DNS choice and query-route fallback |

Both put `-q` first to ignore user curl configuration. Callers validate the
endpoint and credential format (no quotes, backslashes or line breaks), choose
the route, and bound timeouts and body sizes. Secrets go only in the named
URL/header parameters, never in `CURL_ARG`.

```zsh
wire=$(curl_with_secret_header Authorization "Bearer $api_key" "$endpoint" \
  -sS --max-time 10 --max-filesize 131072 --write-out $'\n%{http_code}')
provider_decode_http_response "$wire" "$?"
```

## jq value predicates (`json_values.jq`)

Use `jq -L /absolute/path/to/ipquality/common` with `include "json_values";`;
provider functions resolve the path from their own source file.

| Predicate | True for |
| --- | --- |
| `boolean_or_null($value)` | null or a JSON boolean; strings, numbers and containers are rejected, absence is never false |
| `text_or_null($value; $max)` | null or a string of at most `$max` codepoints without C0/DEL controls |
| `integer_or_null($value; $min; $max)` | null or an in-range integer JSON number; numeric strings and booleans rejected |

## zsh terminal text (`terminal.zsh`) and coordinates (`location.zsh`)

| Function | Result |
| --- | --- |
| `ansi_plain TEXT` | Sets `REPLY` to TEXT with literal `\033` decoded and ANSI `m/G/K/H/F` sequences removed |
| `clean_ansi TEXT [preserve]` | Decodes literal `\033`, strips ANSI `m/G/K/H/F` sequences and trims each line unless `preserve` |
| `show_progress MESSAGE` | Prints `[ip-quality] MESSAGE` to stderr so stdout stays the report |
| `generate_dms LAT LON` | `D°M′S″E, D°M′S″N` text from validated decimals, by exact integer arithmetic; empty for invalid input |
| `location_map_url LAT LON RADIUS` | Check.Place map link whose zoom follows the accuracy radius; empty for invalid input |

Table layout (`display_width`, `terminal_table_*`, `calc_padding`) is report-only
and lives in `report/table.zsh`; it needs a UTF-8 locale, which both entrypoints
and the test suites pin.

## Ruby helper (`network_environment.rb`)

`NetworkEnvironment.without_proxy_variables(env = ENV)` returns a new Hash mapping
each present `all/http/https/no_proxy` key (any case) to `nil` for
`Process.spawn`; it does not affect VPN/TUN routing. Callers: the direct route in
`bin/ip-quality-route` and the isolated Mihomo session.

## Deliberately not common

These are reporter or provider policy and stay with their owners:

| Owner | Policy |
| --- | --- |
| `providers/query_route.zsh` | IPQS/Cloudflare selected-route request with one pre-HTTP direct-IPv4 retry; see [PROVIDERS.md](PROVIDERS.md#automatic-query-route-fallback) |
| `providers/selection.zsh`, `providers/sources.tsv` | Source catalog (IDs, labels, independent preset, plan disclosures; also read by `runner/source_catalog.rb`), `reputation_choose_sources`, `reputation_source_selected`, `reputation_source_disclosure_lines` |
| `providers/check_place.zsh` | `check_place_fetch_json` relay URL and in-memory block/429 pauses; `maxmind_response_is_valid` guards primary/English basic responses before IPinfo fallback |
| `providers/<source>.zsh` | Each source's schema, endpoint, fallback and `db_*` adapter (for example Scamalytics page parsing, IPQS connection types) |
| `report/` | Localized labels, table layout (`report/table.zsh`), `report_query_status`, `report_source_visible`, missing-value display |
| `runner/` | Mihomo lifecycle, listener ownership and cleanup; `safe_snapshot.rb` (verified owner-controlled reads) and `text.rb` (printable metadata), used only by the runner |
| `runner/prefix_sample.rb` | /24 input policy, fixed sample expansion, target-bound batch results and private summaries; single product caller, not a general network utility |

A similar `jq` expression alone is not a shared schema contract.

## Account MCP shared packages

Both MCPs depend directly on sibling `/Users/zmx/Projects/myutils` packages:

| Package | Use |
| --- | --- |
| `browser-session` | Dedicated Chrome lifecycle and profile binding; provider accounts also save storage state and read bounded HTTP contexts |
| `secret-file` | Private data-only files; reporter and IPQS share `secrets/ipqs` |
| `mcp-server` | Tool descriptions and structured text results |
| `one-use-token` | IPQS prepared setting-change reservations |
| `http-read` | Provider accounts: bounded API reads without redirects or retries |
| `totp` | Provisioning URI validation and `generateFreshTotp` for Cloudflare and IPQS (IPQS opts into its 80-bit seed) |
| `redaction` | Both MCPs: one union redactor for account pages, API data and errors (secrets, TOTP/recovery codes, credential syntax, emails, 16+ character tokens, 6+ digit numbers) |

Provider origins, selectors, identities and API-before-2FA checks stay in the
owning MCP; provider-account module APIs are in
[its guide](mcp/provider-accounts/AGENTS.md#module-apis).

## Validation

Run `/bin/zsh -f scripts/test-offline`. `test/common_test.rb` covers the zsh/jq
helpers, the curl stdin stub and proxy overrides; table layout tests are in
`test/report_test.rb` and the runner's snapshot/text tests in
`test/route_runner_test.rb`; [TESTING.md](TESTING.md)
maps the other suites.
