# Project common functions

`common/` holds implementations with several production callers. Load the file
directly; there are no forwarding copies. Loading performs no network access,
credential read or environment mutation. zsh functions preserve caller options
(including `KSH_ARRAYS`); predicates answer through exit status and value
functions print without a trailing newline.

| File | Production callers | Responsibility |
| --- | --- | --- |
| `common/provider_values.zsh` | Provider parsers/adapters (each imports it for standalone fixture runs) and `bin/ip-quality` | Validate/normalize provider values and HTTP envelopes, no source schemas |
| `common/http_request.zsh` | Credential-bearing adapters in `providers/`, `providers/query_route.zsh` | Pass secret URL/header options to curl over stdin, never in process arguments |
| `common/json_values.jq` | Check.Place/MaxMind, ipapi, Cloudflare, IPWHOIS, DB-IP, IP2Location, ipdata, Ipregistry, IPQS, AbuseIPDB, Shodan parsers | Nullable boolean and bounded text/integer predicates |
| `common/terminal.zsh` | `report/` sections and tables, `bin/ip-quality` | ANSI cleanup, display width and aligned tables |
| `common/text.rb` | `runner/profile.rb`, `runner/subscription_catalog.rb` | Bounded printable metadata |
| `common/safe_snapshot.rb` | Profile, catalog, isolated Mihomo session, prefix batch evidence | Verified owner-controlled file reads and snapshot comparison |
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
| `provider_json_fields JSON PROGRAM NAME...` | One `jq` pass over comma-separated scalar expressions; fills `provider_fields[NAME]` with `jq -r` spellings (`null` kept, NULs dropped); 1 with empty fields on a jq error or count mismatch |

```zsh
source common/provider_values.zsh
provider_merge_boolean_signals false unknown  # empty: missing evidence stays unknown
provider_decode_http_response $'{"example":true}\n200' 0
print -r -- "${provider_http_response[status]}"
```

## zsh credential-bearing requests (`http_request.zsh`)

| Function | Result |
| --- | --- |
| `curl_with_secret_url URL [CURL_ARG...]` | Sends the URL through curl's stdin configuration; forwards other arguments intact; keeps curl's output and exit status |
| `curl_with_secret_header NAME VALUE URL [CURL_ARG...]` | Same, also sending one header through stdin |

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

## zsh terminal text (`terminal.zsh`)

| Function | Result |
| --- | --- |
| `ansi_plain TEXT` | Sets `REPLY` to TEXT with literal `\033` decoded and ANSI `m/G/K/H/F` sequences removed |
| `clean_ansi TEXT [preserve]` | Decodes literal `\033`, strips ANSI `m/G/K/H/F` sequences and trims each line unless `preserve` |
| `display_width TEXT` | Sets `REPLY` to the cells of one label after ANSI cleanup: ASCII one, other characters two (no subprocess) |
| `terminal_table_widths MIN COLUMNS CELL...` | One width per column from complete rows, each at least `MIN`; 2 for invalid shape |
| `terminal_table_cell TEXT WIDTH` | Text plus padding; longer text is never truncated |
| `terminal_table_row "WIDTH..." CELL...` | One ` \| `-separated row; 2 before printing on invalid shape |
| `terminal_table_rule "WIDTH..."` | Matching `-+-` rule |

Render values before measuring them; one long label widens only its own column.
The width rule is an approximation, not full `wcwidth` (combining marks, emoji
and ambiguous-width characters can differ). It needs a UTF-8 locale, which both
entrypoints and the test suites pin.

## Ruby helpers

| API | Contract |
| --- | --- |
| `Text.printable?(value, max_bytes: 512)` | Nonempty, validly encoded String within the byte limit and without control characters |
| `SafeSnapshot.read(path, allowed_modes: [0o600, 0o644], max_bytes: 16 MiB)` | `Snapshot(path, bytes, stat)` after owner, regular-file, single-link, mode and descriptor/path identity checks before and after reading; `max_bytes: nil` checks metadata only |
| `SafeSnapshot.verify_directory(path)` | Expanded path of a real directory owned by the effective user, not group/other-writable |
| `SafeSnapshot.same?(left, right)` | Compares captured bytes, device, inode and owner without a new read |
| `SafeSnapshot::Error#reason` | `symlink`, `not_regular`, `wrong_owner`, `hard_link`, `unsafe_mode`, `changed_while_reading`, `too_large`, `missing_or_replaced`, `unreadable`, `not_directory`, `writable_by_other_users` |
| `NetworkEnvironment.without_proxy_variables(env = ENV)` | New Hash mapping each present `all/http/https/no_proxy` key (any case) to `nil` for `Process.spawn`; does not affect VPN/TUN routing |

A snapshot is point-in-time evidence; callers enforce trusted parents and
revalidate at their own state transitions.

## Deliberately not common

These are reporter or provider policy and stay with their owners:

| Owner | Policy |
| --- | --- |
| `providers/query_route.zsh` | IPQS/Cloudflare selected-route request with one pre-HTTP direct-IPv4 retry; see [PROVIDERS.md](PROVIDERS.md#automatic-query-route-fallback) |
| `providers/selection.zsh`, `providers/sources.tsv` | Source catalog (IDs, labels, independent preset, plan disclosures; also read by `runner/source_catalog.rb`), `reputation_choose_sources`, `reputation_source_selected`, `reputation_source_disclosure_lines` |
| `providers/check_place.zsh` | `check_place_fetch_json` relay URL and in-memory block/429 pauses; `maxmind_response_is_valid` guards primary/English basic responses before IPinfo fallback |
| `providers/<source>.zsh` | Each source's schema, endpoint, fallback and `db_*` adapter (for example Scamalytics page parsing, IPQS connection types) |
| `report/` | Localized labels, `report_query_status`, `report_source_visible`, missing-value display |
| `runner/` | Mihomo lifecycle, listener ownership and cleanup |
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

Run `/bin/zsh -f scripts/test-offline`. `test/common_test.rb` covers encoding,
byte and control-character limits, jq predicates, terminal tables, the curl
stdin stub, proxy overrides and snapshot boundaries; [TESTING.md](TESTING.md)
maps the other suites.
