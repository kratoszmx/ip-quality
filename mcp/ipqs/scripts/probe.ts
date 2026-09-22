import { probeIpqsAccount } from "../src/account-probe.js";

const report = await probeIpqsAccount();
process.stdout.write(`${JSON.stringify(report)}\n`);
