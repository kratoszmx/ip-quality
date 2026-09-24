# Project common functions

`common/` contains implementations used by multiple production callers in this
repository. Load the needed file directly; there is no forwarding layer or
compatibility copy at the former paths. Loading these modules performs no
network access, credential read, or environment mutation.

The reporter runs in zsh and the route runner in system Ruby.
`provider_json_is_object` uses `jq`; terminal text cleanup uses system `sed`.
The optional Node account MCPs reuse the mcps JavaScript library described below.

## File and caller map

| Definition | Production callers | Responsibility |
| --- | --- | --- |
| `common/provider_values.zsh` | Provider parsers and `bin/ip-quality` | Validate/normalize provider values without source-specific schemas |
| `common/json_values.jq` | ipapi, Cloudflare, IPWHOIS, DB-IP and Shodan parsers | Optional bounded text/integer predicates; source schemas stay in each parser |
| `common/terminal.zsh` | `bin/ip-quality`; type, score and factor renderers in `report/reputation.zsh` | ANSI cleanup, display-cell measurement and aligned table layout with independent column widths |
| `common/text.rb` | `leaf_runner/profile.rb`, `leaf_runner/subscription_catalog.rb` | Validate bounded printable metadata |
| `common/safe_snapshot.rb` | Profile, catalog, and isolated Mihomo session | Read or verify owner-controlled local files and compare snapshots |
| `common/network_environment.rb` | Direct route command and isolated Mihomo session | Produce child-process overrides removing inherited proxies |

## zsh provider values

Source `common/provider_values.zsh` before the provider adapters. Each function
uses local zsh option scope. Predicates communicate through the exit status;
value functions print without a trailing newline.

| Function and input | Output / result |
| --- | --- |
| `provider_json_is_object JSON` | Exit 0 only for JSON accepted by `jq` as an object; suppresses parser output/errors |
| `provider_integer_in_range VALUE MIN MAX` | Exit 0 for three nonnegative integer strings when `MIN <= VALUE <= MAX` |
| `provider_merge_boolean_signals SIGNAL...` | `true` if any signal is exactly `true`; `false` only for a nonempty all-`false` list; otherwise empty (unknown) |
| `provider_has_observation VALUE...` | Exit 0 if any value is not empty, `null`, or `unknown` (case-insensitive); `false` is an observation |
| `provider_http_failure_status CODE BODY` | `cloudflare_blocked` for the known 403/block-page signature, `rate_limited` for HTTP 429; otherwise `http_NNN` for a three-digit nonzero status, or `network_error`; never echoes the body |

```zsh
source common/provider_values.zsh
provider_integer_in_range 99 0 99
provider_merge_boolean_signals false unknown  # empty: missing evidence stays unknown
```

Provider schemas, request endpoints, optional credential files, source-specific
status decisions, and report labels remain in `providers/`, `bin/ip-quality`,
and `report/`. A similar `jq` expression alone is not a shared schema contract.
The score and factor tables share `report_query_status` inside `report/`;
its localized display labels are presentation policy, not a runtime provider API.

## jq value predicates

Use `jq -L /absolute/path/to/ipquality/common` with `include "json_values";`.
Provider functions resolve this path from their own source file, so standalone
fixture calls also work from another current directory. The reporter verifies
the module exists as a readable regular file before any lookup.

| Predicate | Contract |
| --- | --- |
| `text_or_null($value; $max)` | True for null or a string of at most `$max` Unicode codepoints with no C0/DEL controls; empty string is allowed |
| `integer_or_null($value; $min; $max)` | True for null or an integer JSON number within the inclusive numeric bounds; rejects numeric strings and booleans |

```sh
jq -n -L common 'include "json_values"; text_or_null("香港"; 2)'
```

These predicates unify repeated value validation in five providers. They
do not interpret absence as false or validate IP/ASN/source schemas. Text control
characters are rejected before they reach the terminal. String-form ASNs are
still accepted only by providers whose contracts explicitly allow them.
Shodan requires non-null elements before applying the optional predicates;
fractional/out-of-range ports and control characters in text arrays are rejected.

IPQS connection-type classification belongs to
`providers/ipqualityscore.zsh::ipqualityscore_connection_type_server_flag`.
Its official and relay callers share IPQS vocabulary, not a general classifier.

## zsh terminal text

Source `common/terminal.zsh` before the reporter or report renderers. The shared
functions do not depend on report colors, language, or provider state.

| Function and input | Output / result |
| --- | --- |
| `clean_ansi TEXT [preserve]` | Decodes literal `\033`, removes ANSI sequences ending in `m`, `G`, `K`, `H`, or `F`, and trims each line's surrounding whitespace by default; `preserve` retains layout whitespace; adds no newline |
| `display_width TEXT` | Decimal cell count for a single-line label after ANSI cleanup, including visible leading/trailing spaces; ASCII characters count as one cell and other characters as two |
| `terminal_table_widths MIN COLUMNS CELL...` | Space-separated widths, one per column, computed from complete rows supplied in row order; each width is at least nonnegative `MIN`. Returns 2 for invalid dimensions or an incomplete row |
| `terminal_table_cell TEXT WIDTH` | Prints the original text and padding to a nonnegative width; longer text is preserved without truncation |
| `terminal_table_row "WIDTH..." CELL...` | Prints one row with ` | ` separators and a newline. Requires one nonnegative width per cell; invalid shape returns 2 before printing |
| `terminal_table_rule "WIDTH..."` | Prints the matching `-+-` rule; invalid widths return 2 before printing |

```zsh
source common/terminal.zsh
widths=$(terminal_table_widths 4 2 Name Region 'Example network' HK)
terminal_table_row "$widths" Name Region
terminal_table_rule "$widths"
terminal_table_row "$widths" 'Example network' HK
```

Render values before measuring them. Each renderer prepends its label-column
width and uses the same resulting width list for its header, rule and data rows.
One long organization or error label expands only its own provider column.
These functions preserve the caller's zsh options, including `KSH_ARRAYS`.
The former `report_table_*` definitions are removed; callers use the common
implementations directly, with no forwarding aliases.

The width rule is the existing report-table approximation, now also used by
headers. It is not a full Unicode `wcwidth` implementation: combining marks,
emoji sequences, and ambiguous-width characters can differ between terminals.
Source labels, status colors, missing-value policy and provider-row selection
stay in `report/`; the common table code knows none of them.

The September 24 audit retained all existing common modules: provider values,
jq value predicates, terminal text, metadata, file snapshots and proxy overrides
have reusable contracts. No existing common implementation needed relocation.
Provider schemas and IPQS connection-type mapping remain provider-owned;
Mihomo lifecycle remains runner-owned. Its redundant clock forwarding method
was removed in favor of direct Ruby standard-library calls. The inspected
myutils public APIs are Python modules and do not supply this zsh table contract;
no Python subprocess or adapter was added to the reporter.

## Ruby metadata

```ruby
require_relative "../common/text"
IpQuality::Text.printable?(name, max_bytes: 512)
```

`printable?` returns a boolean. A valid value is a nonempty, validly encoded
String within the byte limit and without control characters. The default limit
is 512 bytes; this is a byte limit, not a character limit. Profile names,
subscription names, and subscription IDs share this rule. Filename confinement,
uniqueness, and YAML structure remain the callers' responsibility.

## Ruby verified snapshots

```ruby
require_relative "../common/safe_snapshot"
snapshot = IpQuality::SafeSnapshot.read(path, max_bytes: 1024)
executable = IpQuality::SafeSnapshot.read(
  binary_path, allowed_modes: [0o700, 0o750, 0o755], max_bytes: nil
)
```

| API | Input / output |
| --- | --- |
| `SafeSnapshot.read(path, allowed_modes: [0o600, 0o644], max_bytes: 16 * 1024 * 1024)` | Returns `Snapshot(path, bytes, stat)`; `path` is expanded, read bytes are frozen, and `stat` comes from the opened descriptor. `max_bytes: nil` verifies metadata without reading contents and returns `bytes == nil` |
| `SafeSnapshot.verify_directory(path)` | Returns the expanded path for a real directory owned by the effective user and not writable by group/others |
| `SafeSnapshot.same?(left, right)` | Compares captured bytes, device, inode, and owner; no new filesystem read |
| `SafeSnapshot::Error#reason` | Symbol identifying the rejected condition; the error message also contains the path |

File reads check ownership, regular-file type, single link, allowed mode, and
descriptor/path identity before and after reading. They reject oversized
contents and final-component symlinks, using `NOFOLLOW` where available. The
snapshot is point-in-time evidence; callers separately enforce trusted parent
directories and revalidate at their own state transitions. The catalog compares
two content snapshots to detect registry replacement while selecting a leaf.
Metadata-only snapshots are not a content-integrity check.

Current reasons: `symlink`, `not_regular`, `wrong_owner`, `hard_link`,
`unsafe_mode`, `changed_while_reading`, `too_large`, `missing_or_replaced`,
`unreadable`, `not_directory`, `writable_by_other_users`.

## Ruby child-process proxy overrides

```ruby
require_relative "../common/network_environment"
overrides = IpQuality::NetworkEnvironment.without_proxy_variables(ENV)
Process.spawn(overrides, "/bin/zsh", "-f", reporter_path, *arguments)
```

`without_proxy_variables(environment = ENV)` returns a new Hash mapping every
present `all_proxy`, `http_proxy`, `https_proxy`, or `no_proxy` key to `nil`,
case-insensitively. Ruby's process APIs interpret those values as removals.
Other variables are omitted from the override Hash; the input and parent
environment are unchanged. Isolated routes add their verified loopback proxy
values to this Hash. This helper does not change system VPN/TUN routing.

## Account MCP shared APIs

`mcp/ipqs` and `mcp/provider-accounts` reference the sibling repository
`/Users/zmx/Projects/mcps/common/shared` through direct local package dependencies.
They do not copy those implementations or leave forwarding packages in mcps.

| Shared package | Callers and use |
| --- | --- |
| `browser-session` | Both MCPs: dedicated Chrome lifecycle, verified profile binding, operation leases |
| `secret-file` | Both MCPs: inspect/read/write private data-only files; reporter and IPQS share `secrets/ipqs` |
| `mcp-server` | Both MCPs: tool descriptions and structured text results |
| `one-use-token` | IPQS: prepared setting-change reservation and expiry |
| `http-read` | Provider accounts: bounded API reads with no redirects or automatic retries |
| `totp` | Cloudflare account setup: validate a textual provisioning URI and generate a short-lived RFC 6238 code |

Provider origins, form selectors, account identity, API contracts and registration
receipts remain inside their owning MCP. Shared helpers do not decide whether an
account is usable; the Cloudflare workflow owns its API-before-2FA check.

Inside `mcp/provider-accounts`, `accounts.mjs::withSession` owns the shared
provider profile binding and lease, `privateAccount` validates saved identities,
and `policy.mjs::accountNetworkOptions` validates a task-scoped browser/API route.
Its explicit `DIRECT` mode emits Chrome's `--no-proxy-server`, overriding macOS
system proxy preferences; `accountRouteMatches` checks the actual bound process
before reusing it for an explicitly chosen route. `cloudflare.mjs`
owns its fixed account paths, server identity check and token policy; its TOTP
consumer reuses these directly. `cloudflare-policy.mjs` contains fixture-testable
identity, token scope, response and API-before-MFA decisions. MCP action entrypoints
return metadata only; secrets stay inside their private-file and HTTP/form calls.

The same MCP owns `public-api.mjs::verifyPublicProvider(provider, confirmation,
request, surface)` for DB-IP/IPWHOIS. The MCP selects `free_api` (default) or
`public_demo`, with literal confirmation `VERIFY_FREE_API`; the optional
`request` function injects the offline transport in place of shared `http-read`.

| Surface | Requests and observation |
| --- | --- |
| Either provider's `free_api` | One lookup for `1.1.1.1`; geography/network context |
| IPWHOIS `public_demo` | One lookup for `1.1.1.1` with website headers; supplied security booleans |
| DB-IP `public_demo` | One page, then one visitor lookup using an in-memory guest token; `request_egress`, with an optional threat label |

`publicProviderObservation(provider, body, expected, surface)` returns a validated
projection or `null`. The caller validates DB-IP's returned IP before projecting
its egress observation; other lookups must match `1.1.1.1`. Results carry query
status, the observation and account/MFA/risk capabilities. Missing fields stay
null; HTTP 200 quota errors become `rate_limited`, without retries or enrollment.
Provider-specific workflow details belong in
[the account guide](mcp/provider-accounts/AGENTS.md).
Reporter and Node fixture suites share sanitized JSON inputs; their language-
specific parsers remain local and do not invoke one another through wrappers.

## Validation and maintenance

Run `/bin/zsh -f scripts/test-offline` from the worktree root; focused commands
and test-only helpers are in [TESTING.md](TESTING.md). The suite includes the
Ruby common contracts, provider/terminal fixtures, and route integration tests.
`test/common_test.rb` checks encoding/byte/control-character boundaries, proxy
overrides, file-size/mode limits, verification-only symlink rejection, and
snapshot replacement. Runner tests retain cleanup, signal, link rejection, and
route-isolation coverage. `test/providers_test.rb` exercises shared provider
values; `test/common_test.rb` also checks jq value types, bounds and controls.
`test/public_demo_test.rb` checks source contracts rather than promoting their
schema/quotas into the common library. `test/report_test.rb` checks terminal functions and real file/ANSI bytes.
The CLI self-test retains typed JSON checks.

Mihomo process lifecycle and cleanup remain in `leaf_runner/`; they carry
session state, listener ownership, and recovery policy. Shared modules contain
the reusable operations, while their callers retain those state transitions.
