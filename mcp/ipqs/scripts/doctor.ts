import { resolveChromePath } from "@codex-mcp/shared-browser-session";

import { defaultStateSummary, localStatus } from "../src/browser.js";
import {
  ROOT,
  ensureBrowserProfileDirectory,
  env,
  getProxyServer,
} from "../src/config.js";

async function main() {
  await ensureBrowserProfileDirectory();
  const chrome = await resolveChromePath({
    configuredPath: env("IPQS_CHROME_PATH") || undefined,
    envName: "IPQS_CHROME_PATH",
  }).then(
    (resolvedPath) => ({ available: true, resolvedPath }),
    () => ({ available: false }),
  );
  const status = await localStatus();
  const report = {
    package: "codex-ipqs-mcp",
    root: ROOT,
    state: defaultStateSummary(),
    browser: {
      ...chrome,
      profilePresent: status.profilePresent,
      proxyConfigured: Boolean(getProxyServer()),
      liveAuthProbed: false,
    },
    savedCredentials: status.savedCredentials,
    apiCredential: status.apiCredential,
    supported: {
      realChromeLogin: true,
      boundedSavedCredentialLogin: true,
      redactedDashboardReads: true,
      privateApiKeyImport: true,
      twoStageLowRiskSettingChanges: true,
      accountUsageApi: true,
      ipEmailPhoneUrlLookups: true,
      automaticLookupRetries: false,
    },
    safety: {
      apiKeyPrinted: false,
      savedCredentialsPrinted: false,
      browserProfileExported: false,
      hiddenFormValuesReturned: false,
      liveCodexConfigChanged: false,
    },
    validation: {
      mode: "offline-static",
      browserOpened: false,
      networkUsed: false,
      creditsSpent: false,
    },
  };
  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
