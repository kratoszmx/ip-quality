#!/usr/bin/env tsx
import { loginWithSavedCredentials } from "../src/browser.js";

const confirmedUseSavedCredentials = process.argv.includes("--confirm");
const keepBrowser = process.argv.includes("--keep-open");

try {
  const result = await loginWithSavedCredentials({ confirmedUseSavedCredentials, keepBrowser });
  console.log(JSON.stringify(result, null, 2));
  if (!result.ok) process.exitCode = 2;
} catch (error) {
  console.error(JSON.stringify({
    ok: false,
    error: error instanceof Error ? error.message : "IPQS saved-credential login failed safely.",
    secretReturned: false,
  }, null, 2));
  process.exitCode = 1;
}
