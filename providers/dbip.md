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
HTTP 200 with an explicit daily quota message means
`daily_quota_exhausted`; `OVER_QUERY_LIMIT` alone and other query-limit messages
remain `rate_limited`, since the code alone supplies no reset period. No label is
converted to a 0/50/100 score. The public visitor token is used only in memory;
no account key is obtained or saved.
The [official FAQ](https://db-ip.com/faq.php) documents daily API-key allowance
resets at midnight CET. That is 07:00 in Asia/Shanghai when interpreted as
CET (UTC+1); the public visitor demo supplies no reset timestamp or guaranteed
recovery schedule. On October 11, both direct and ATT returned the daily-limit
body without `Retry-After`, so changing routes was not a recovery for this demo.
On October 26, fresh page-plus-demo requests on the default proxy, direct and
isolated ATT each returned HTTP 200 with `OVER_QUERY_LIMIT` and
`maximum number of queries per day exceeded`, without `Retry-After`. The free
geography endpoint still returned valid data for `1.1.1.1`. This is a live
visitor-demo refusal, not a cached result or exhaustion of an owned account's
free allowance. A daily message does not establish when the public demo will
be usable again. Do not promise a next-day recovery or substitute free geography
for a missing threat label.
The terminal labels it `上游报日限额` / `upstream daily limit`: the provider's
error classification is observable, but its internal counter is not. A bounded
October 26 check using the current upstream script's POST/currency-conversion
request returned the same HTTP 200 daily-limit JSON as GET, so the observed
failure is not explained by our GET method. DB-IP's official JavaScript client
uses GET without conversion data and POST with it; neither variant supplied
a risk observation in these checks.
Two independent page reads over the default proxy and explicit direct route
returned the same visitor key (compared only in memory). This supports a shared
demo-credential explanation, not a measurement of its internal daily counter
or proof that every visitor shares the same quota.
The no-key free geography contract is retained only for the MCP's optional
`free_api` probe; unexpected premium fields there still cannot supply risk.

## Free API versus website demo

The permanent free endpoint `https://api.db-ip.com/v2/free/{IP}` documents 500
requests per day and needs no account, key, billing or 2FA, but returns only
country/state/city; threat, crawler and proxy fields are paid Extended data,
which this project does not use. That quota says nothing about the website demo
the reporter uses (one page plus one visitor lookup per report), whose allowance
is unspecified. The account MCP probes `free_api` and `public_demo` separately.

## Account and trial options

Official pages checked October 26 distinguish the
[permanent free geography API](https://db-ip.com/api/free.php) from the
[Extended API](https://db-ip.com/api/extended/), which includes threat data.
The [Starter 2K offer](https://db-ip.com/api/key/FULL2) has a seven-day trial,
then annual billing of EUR 197.88 (advertised as EUR 16.49/month); cancellation
before the trial ends avoids the charge. The
[Starter 10K offer](https://db-ip.com/api/key/FULL10) also offers monthly
billing at EUR 32.90 after its seven-day trial. These are subscription trials,
not permanent free threat-data allowances. No trial or subscription was activated.

Logging into an account alone does not change this adapter's public visitor
credential. An active, separately provisioned Extended key and an explicit
keyed-API integration would be needed to use personal quota. Such a paid/trial
integration is not currently enabled. The public IP detail page was also checked
as a possible alternative: proxy/direct HTTP returned 403, and hidden Chrome
stopped at an unresolved challenge; it supplied no risk observation.

Lesson from 2026-09-24: the limit errors came from the old target demo, while
the current visitor flow returned a `low` label. When a demo is throttled, stop
and respect any Retry-After/reset time; repeating requests or rotating accounts
is not a fix.
