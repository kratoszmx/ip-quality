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
