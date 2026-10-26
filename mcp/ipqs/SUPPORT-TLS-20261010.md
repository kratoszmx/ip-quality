# IPQS TLS support inquiry — 2026-10-10

Status: **SENT**, October 10 at 17:36:37 Asia/Shanghai. The current user explicitly
authorized contacting IPQS after investigating the failure. The message was
previewed, created as one Gmail draft, sent once, and independently matched in
Gmail Sent by message ID, sender, recipient and subject. Delivery/read and a
provider diagnosis are not established by that send proof.

Recipient: `support@ipqualityscore.com`, freshly checked against the
[official contact page](https://www.ipqualityscore.com/contact-us).

Subject: `Route-specific TLS failure to IPQS API from AT&T IPv4; account works via other routes`

The request describes the October 10 ATT TLS failure before any HTTP response,
successful account reads over direct IPv6/Hong Kong, and a successful lookup of
the same target through Hong Kong. It includes client version, time window and
the source IPv4 needed for edge-log investigation. No API key, password, cookie,
TOTP material or attachment was sent. It asks whether the source/edge is
restricted and requests supported corrective advice without claiming a proven
provider outage or requesting a paid service.

The exact message and private send/verification receipts are outside repositories
under `/Users/zmx/codexworkspace/secrets/mail/operations/ipqs-tls-20261010/`.
Sanitized network evidence is indexed in [../../HANDOFF.md](../../HANDOFF.md).
No automatic resend or new reply-monitor service was created.

Later the same day, the reporter's opt-in AliDNS/HTTPS resolution restored
direct IPv4 account and lookup access. A freshly discovered ATT IP also returned
a valid official score when explicitly queried through that direct route. ATT
transport itself still failed TLS. This narrows the support question to the
ATT-to-service path, without proving which remote component closes it; it is
not an account-wide, target-wide or demonstrated global IPQS outage. This
reporter DNS option does not change the MCP's HTTP/browser transport.

October 11, 17:25 Asia/Shanghai: the reporter now applies that DNS repair
automatically for direct IPv4, and its full default run returned a valid IPQS
score. ATT still failed TLS. A fresh exact-thread metadata read contained only
the original Sent message. A bounded search since October 9, including Spam and
Trash and both official sender domains/the inquiry subject, likewise matched
only the sent inquiry. An earlier bounded bounce search returned none. There is
no support reply or confirmed provider diagnosis in these checked surfaces.
The inquiry was sent Saturday and checked Sunday, less than 24 hours later;
no duplicate follow-up was sent. A normal business-day response window is more
useful than another immediate message; no automatic mail job was created.
The reporter DNS repair still does not change MCP transport.

October 26 follow-up preparation (not sent): the user reports that support asks
whether IPv4 website login works and requests sanitized curl failures. The
fresh test proved direct IPv4 password + TOTP login and account API acceptance.
ATT curl still failed TLS before HTTP on `/login` and the account endpoint;
pinned IPv4 plus HTTP/1.1/TLS 1.2 reproduced it. These observations do not
identify the component dropping the connection. Private Chinese/English drafts
and redacted traces are in `reports/ipqs-support-20261026-rerun/`. They exclude
keys, cookies, authorization headers and the user's exact source IP. No new
message or server-side mail draft was created. The original new support reply
was not independently reread because the mail connector's OAuth refresh was
unavailable on the preceding check; the draft addresses the user's quoted
questions without inventing other reply content.

Later October 26, a bounded Gmail API read through the default proxy succeeded.
It independently confirmed the October 11 acknowledgement and October 20 reply
asking whether IPv4 website/account access works and requesting full curl error
output. The drafts were revised against that actual reply. No email or server
draft was created. Private source IPs, mail routing/security tokens and account
credentials are omitted from the drafts and diagnostic attachment.
