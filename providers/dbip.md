# DB-IP

Visitor-demo token flow, egress binding and quota semantics. Adapter and parser: [`dbip.zsh`](dbip.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

DB-IP reads `https://db-ip.com/api/core/`, extracts its bounded public visitor
token into memory, then reads `https://api.db-ip.com/v2/{token}/self?convertCurrencies`
with the website headers. This visitor endpoint returned a risk label when
the old `/demo/home.php` target lookup reported its query limit. Both requests
preserve the selected route and IP family. The token URL is sent through curl
stdin, never saved or printed. No remote script is executed. The returned
`ipAddress` must equal the tested IP; an explicit unrelated target or changed
egress becomes `ip_mismatch`, never another IP's risk. It validates bounded
geography and a `threatLevel` of low/medium/high. A missing label remains unknown. The original
label is in section 3 and `ScoreMeta.DBIP.Band`; `Score.DBIP` remains null.
HTTP 200 with `OVER_QUERY_LIMIT` or an explicit daily quota message means
`daily_quota_exhausted`; other query-limit messages remain `rate_limited`. No label is
converted to a 0/50/100 score. The public visitor token is used only in memory;
no account key is obtained or saved.
The [official FAQ](https://db-ip.com/faq.php) documents daily API-key allowance
resets at midnight CET. That is 07:00 in Asia/Shanghai when interpreted as
CET (UTC+1); the public visitor demo supplies no reset timestamp or guaranteed
recovery schedule. On October 11, both direct and ATT returned the daily-limit
body without `Retry-After`, so changing routes was not a recovery for this demo.
The no-key free geography contract is retained only for the MCP's optional
`free_api` probe; unexpected premium fields there still cannot supply risk.

## Free API versus website demo

The permanent free endpoint `https://api.db-ip.com/v2/free/{IP}` documents 500
requests per day and needs no account, key, billing or 2FA, but returns only
country/state/city; threat, crawler and proxy fields are paid Extended data,
which this project does not use. That quota says nothing about the website demo
the reporter uses (one page plus one visitor lookup per report), whose allowance
is unspecified. The account MCP probes `free_api` and `public_demo` separately.

Lesson from 2026-09-24: the limit errors came from the old target demo, while
the current visitor flow returned a `low` label. When a demo is throttled, stop
and respect any Retry-After/reset time; repeating requests or rotating accounts
is not a fix.
