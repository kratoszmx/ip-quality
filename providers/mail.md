# Mail scope

MX lookup and SMTP greeting probes. Implementation: [`mail.zsh`](mail.zsh).
Cross-source policy (consent, routes, fallbacks, display): [PROVIDERS.md](../PROVIDERS.md).

The reporter resolves public MX records for Gmail, Outlook, Yahoo, Apple, QQ,
Mail.ru, AOL, GMX, Mail.com, 163, Sohu, and Sina. For each service it selects one
MX host with the lowest numeric preference, makes a bounded TCP/25 connection,
requires a line starting `220 ` or `220-` (a `220` inside an `nc` error or
address is not a greeting), sends `QUIT`, and submits no message. It does
not retry alternate MX hosts. A separate Mailgun greeting probe describes local
outbound TCP/25 reachability. The operating system chooses the actual local
source address, so the check works on a directly addressed host or behind NAT.
