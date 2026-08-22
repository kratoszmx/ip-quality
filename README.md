# IP Quality for M4

This directory contains a source-auditable, zsh-native fork of
[`xykt/IPQuality`](https://github.com/xykt/IPQuality). It keeps the useful part
of the upstream design—one report assembled from many independent IP reputation,
accessibility, mail, and DNSBL observations—while fitting the safety boundaries
of `network-manager`.

The current fork has been validated offline. No live provider query was run as
part of the import and porting work.

## Test one exact Clash leaf without changing the live subscription

`bin/test-clash-leaf` reads the currently selected Clash Verge profile through
a verified, read-only snapshot. It lists only concrete inline `proxies` (not
proxy groups or `DIRECT`/`REJECT`), copies the exact selected leaf and any
concrete `dialer-proxy` dependencies into a private temporary configuration,
and starts a separate Mihomo bound only to `127.0.0.1` on a random port. It does
not switch, import, rewrite, reload, or restart the live Clash profile.

List the available leaf names without starting Mihomo or using the network:

```zsh
/bin/zsh -f ./bin/test-clash-leaf --list-leaves
```

Interactively choose a leaf and run the multi-source reputation report through
that isolated leaf:

```zsh
/bin/zsh -f ./bin/test-clash-leaf \
  --select \
  --confirm-network-lookup \
  -4 \
  -f
```

For a repeatable non-interactive run, replace `--select` with
`--leaf 'exact node name'`. Before a live run, the minimal extracted profile can
be checked without opening a listener or querying the network:

```zsh
/bin/zsh -f ./bin/test-clash-leaf \
  --leaf 'exact node name' \
  --config-test-only
```

An explicit `--profile PATH` may be used instead of the active Clash Verge
profile. Profile files must be regular, current-user-owned, non-symlinked,
single-link files with mode `0600` or `0644`. The live leaf runner deliberately
fixes the reporter scope to `reputation`: those HTTP(S) observations can be
forced through its local proxy, while the reporter's mail, DNSBL, and some
media checks contain direct DNS/TCP flows that would not prove the selected
leaf's egress.

## Safety model

Running the command with no arguments only prints a disclosure plan. It performs
no DNS or network access:

```zsh
/bin/zsh -f ./ip-quality.zsh
```

Offline source and vendored-data checks are available separately:

```zsh
/bin/zsh -f ./ip-quality.zsh --self-test
```

A live lookup requires the exact confirmation flag:

```zsh
/bin/zsh -f ./ip-quality.zsh --confirm-network-lookup --scope reputation -4
```

The confirmation means that every selected third party may observe the tested
egress IP and the time of the query. When passed directly to `ip-quality.zsh`,
it does not authorize starting a proxy. When passed to `test-clash-leaf`, it
also authorizes only the temporary loopback Mihomo process described above. It
never authorizes changing live Clash state, uploading a report, installing
software, or creating a paid resource.

This fork deliberately has:

- no Bash dependency or Bash upgrade path;
- no package-manager or one-click installer;
- no telemetry, advertisements, sponsor fetches, or report upload;
- no remote script, menu, or executable-reference download;
- no command-line proxy credential option;
- no implicit `~/.curlrc` options (every HTTP request starts with curl's
  configuration-disable flag);
- no nested Git repository;
- no bundled account cookies or session state.

## Query scopes

| Scope | What it queries |
| --- | --- |
| `reputation` | Multiple reputation, geolocation, network-type, proxy/VPN/Tor, abuse, bot, and risk-score sources, plus Ping0 public geo/ASN/organization |
| `dnsbl` | The vendored DNSBL zone set, for IPv4 only |
| `media-ai` | TikTok, Netflix, YouTube Premium, Prime Video, Reddit, and OpenAI public accessibility endpoints |
| `mail` | Public MX records and bounded SMTP greeting probes on port 25 |
| `full` | All of the above; this is the planning default |

DNSBL concurrency defaults to 50 because that is the useful upstream behavior,
but the fork enforces a hard range of 1 through 50:

```zsh
/bin/zsh -f ./ip-quality.zsh \
  --confirm-network-lookup \
  --scope dnsbl \
  --dnsbl-concurrency 20 \
  -4
```

The reporter preserves each provider's result. Conflicting results are not
collapsed into an unexplained “clean” verdict. Missing, malformed, rate-limited,
or failed responses remain blank/null/unknown rather than being interpreted as
clean. See [PROVIDERS.md](PROVIDERS.md) for the source and disclosure inventory.

Ping0's official free `/geo` response contributes the returned location, ASN,
and organization only after its returned IP exactly matches the already-tested
egress address. The public endpoint does not expose Ping0's numeric risk score,
so the report records that score as `Unknown`/`null`; it does not scrape the
interactive verification page or present missing data as clean.

## Supported compatibility options

The retained short options are:

- `-4` or `-6`: query only that IP family;
- `-f`: reveal the full tested IP in local output (masked by default);
- `-i en0` or another strictly validated interface/address: bind HTTP queries to
  that egress interface or source address;
- `-j`: write the report as JSON to stdout;
- `-l cn|en|jp|es|de|fr|ru|pt` or `-E`: choose report language;
- `-o PATH`: create a new local report file; existing paths are rejected;
- `-p`: retained as a no-op compatibility flag because uploads are always off.

The upstream `-x`, `-y`, and `-M` behaviors are rejected. Proxy routing belongs
to the supervised `network-manager` egress workflow, dependency installation
belongs to the shared environment workflow, and no menu may download and execute
remote code.

Use the ignored `reports/` directory, with `*.ansi`, `*.report.json`, or
`*.report.txt`, for local results that must not enter Git history.

## Dependencies

The script checks commands and exits with a list of anything missing. It never
installs them. Depending on scope, it uses the system `/bin/zsh` plus `curl`,
`jq`, `bc`, `dig`, `nslookup`, `nc`, `xargs`, `gunzip`, and ordinary macOS text
tools.

The exact-leaf runner additionally uses the system `/usr/bin/ruby` standard
library for safe YAML parsing and process ownership, the Mihomo executable
bundled with Clash Verge, and `/usr/sbin/lsof` to prove that the random listener
belongs to the isolated child process. It does not install any of them.

## Source layout

| Path | Responsibility |
| --- | --- |
| `ip-quality.zsh` | zsh-native provider aggregation, report rendering, and explicit live-query gate |
| `bin/test-clash-leaf` | thin zsh entrypoint for exact-leaf selection |
| `lib/safe_snapshot.rb` | reusable race-resistant local-file snapshot contract |
| `lib/clash_leaf_profile.rb` | active-profile resolution and minimal exact-leaf rendering |
| `lib/isolated_mihomo_session.rb` | random loopback port, listener ownership, cleanup, and proxy environment |
| `lib/clash_leaf_command.rb` | CLI policy and reporter orchestration |
| `lib/ping0.zsh` | pure parser for the official public Ping0 `/geo` response |
| `ref/` | vendored runtime data |
| `test/fixtures/` | sanitized provider/parser fixtures only |
| `test/` | offline contracts; no external network or live Mihomo |

## Result caveats

This is an observation aggregator, not a certificate that an IP is universally
“clean.” Provider coverage, definitions, rate limits, page schemas, and data age
differ. Some retained upstream checks use public web pages or the upstream
Check.Place relay rather than a customer-owned formal API account; those rows
must be interpreted as named observations and can become unavailable.

Mail and DNSBL checks use direct DNS/TCP traffic and are not carried by an HTTP
proxy environment. For that reason, the exact-leaf runner limits itself to the
reputation scope and refuses to imply that direct flows measured the leaf.

## Provenance and license

The exact upstream commit, imported hashes, exclusions, and local changes are in
[UPSTREAM.md](UPSTREAM.md). The derived program remains licensed under
AGPL-3.0; the upstream license is retained verbatim in [LICENSE](LICENSE).
