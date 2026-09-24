import path from "node:path";
import { inspectTotpUri, generateTotp } from "@codex-mcp/shared-totp";
import { readPrivateSecretFile, writePrivateSecretFile, inspectPrivateSecretFile } from "@codex-mcp/shared-secret-file";
import type { Page } from "playwright-core";
import { IPQS_ORIGIN, REPO_ROOT } from "./config.js";
import { readIpqsCredentials } from "./credentials.js";

// IPQS currently provisions an 80-bit seed. This is provider-owned policy.
const options = { allowLegacy80BitSecret: true };
export const totpDirectory = path.join(REPO_ROOT, "secrets/accounts/ipqs");

export function ipqsSetup(qrSource: string, text: string, email: string) {
  const qr = new URL(qrSource);
  if (qr.origin !== "https://api.qrserver.com" || qr.username || qr.password || qr.pathname !== "/v1/create-qr-code/" || qr.searchParams.getAll("data").length !== 1) throw new Error("Unrecognized IPQS authenticator setup.");
  const uri = qr.searchParams.get("data") || "";
  const parsed = new URL(uri);
  if (parsed.searchParams.get("issuer") !== "IPQualityScore" || decodeURIComponent(parsed.pathname.slice(1)) !== `IPQualityScore:${email}`) throw new Error("IPQS authenticator identity mismatch.");
  inspectTotpUri(uri, options);
  const backupSection = text.split("Emergency Backup Code");
  const codes = backupSection.length === 2 ? [...backupSection[1].matchAll(/\b\d{8}\b/g)] : [];
  if (codes.length !== 1) throw new Error("IPQS backup code was not uniquely identified.");
  return { uri, recoveryCode: codes[0][0] };
}

export async function ipqsTotpCode(uri: string) {
  let generated = generateTotp(uri, options);
  if (generated.remainingMs < 5000) {
    await new Promise(resolve => setTimeout(resolve, generated.remainingMs + 100));
    generated = generateTotp(uri, options);
  }
  return generated.code;
}

export async function enrollIpqsTotp(page: Page) {
  if (new URL(page.url()).origin !== IPQS_ORIGIN || new URL(page.url()).pathname !== "/user/settings") throw new Error("Expected authenticated IPQS settings.");
  const current = await page.evaluate(() => {
    const tab = document.getElementById("2fa");
    const form = tab?.querySelector("form.submit2fa");
    return { text: tab?.textContent || "", qrSource: tab?.querySelector("img")?.src || "",
      ready: !!form?.querySelector('input[name="2fa"][type="number"]') && !!form?.querySelector('button[type="submit"]') };
  });
  if (!current.ready) return { enabled: /(?:disable|deactivate)\s+(?:2fa|two.factor)/i.test(current.text), changed: false, state: "inspect_existing_factor" };
  const account = await readIpqsCredentials();
  const setup = ipqsSetup(current.qrSource, current.text, account.email);
  if ((await inspectPrivateSecretFile(path.join(totpDirectory, "enrollment-attempt.json"))).exists) throw new Error("IPQS enrollment was already attempted; inspect its result before repeating.");
  const saved = await writePrivateSecretFile(path.join(totpDirectory, "totp-uri"), setup.uri);
  const recovery = await writePrivateSecretFile(path.join(totpDirectory, "recovery-code"), setup.recoveryCode);
  if (saved.conflict || recovery.conflict) throw new Error("Preserving different saved IPQS authenticator data.");
  const receipt = await writePrivateSecretFile(path.join(totpDirectory, "enrollment-attempt.json"), JSON.stringify({ attemptedAt: new Date().toISOString() }));
  if (!receipt.changed || receipt.conflict) throw new Error("IPQS enrollment is already reserved.");
  const code = await ipqsTotpCode(setup.uri);
  // The observed Settings.js submits exactly this form field to this endpoint.
  const result = await page.evaluate(async code => {
    const response = await fetch("/user/2fa/enable", { method: "POST", credentials: "same-origin", redirect: "error",
      headers: { "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8", "X-Requested-With": "XMLHttpRequest" },
      body: new URLSearchParams({ "2fa": code }).toString(), signal: AbortSignal.timeout(15000) });
    const text = await response.text();
    let success = false;
    if (text.length <= 65536) { try { success = JSON.parse(text).success === true; } catch { /* unconfirmed */ } }
    return { httpStatus: response.status, enabled: response.status === 200 && success };
  }, code);
  return { ...result, seedSaved: true, recoverySaved: true, changed: result.enabled, state: result.enabled ? "enabled_challenge_verification_pending" : "enrollment_unconfirmed" };
}

export async function readIpqsTotpUri() {
  const uri = (await readPrivateSecretFile(path.join(totpDirectory, "totp-uri"), { maxBytes: 4096 })).secret;
  inspectTotpUri(uri, options);
  const parsed = new URL(uri);
  const account = await readIpqsCredentials();
  if (parsed.searchParams.get("issuer") !== "IPQualityScore" || decodeURIComponent(parsed.pathname.slice(1)) !== `IPQualityScore:${account.email}`) throw new Error("Saved IPQS authenticator identity mismatch.");
  return uri;
}

export function acceptsIpqsTotpChallenge(value: { url: string; action: string; method: string; fields: string[]; button: string }) {
  try {
    const url = new URL(value.url), action = new URL(value.action || value.url, value.url);
    return url.origin === IPQS_ORIGIN && action.origin === IPQS_ORIGIN && action.pathname === url.pathname &&
      /^\/user\/(?:dashboard|settings|api-keys)$/.test(url.pathname) && value.method.toLowerCase() === "post" &&
      value.fields.filter(name => name === "2fa").length === 1 && value.fields.every(name => ["2fa", "rememberme"].includes(name)) &&
      value.button.trim() === "Finish Login »";
  } catch { return false; }
}

export async function completeIpqsTotp(page: Page) {
  const form = page.locator('form').filter({ has: page.locator('input[name="2fa"][type="number"]') });
  if (await form.count() !== 1) throw new Error("Expected one IPQS authenticator challenge.");
  const metadata = await form.evaluate(form => ({ url: location.href, action: form.getAttribute("action") || "", method: form.getAttribute("method") || "get",
    fields: Array.from(form.querySelectorAll("input")).map(e => e.name), button: form.querySelector("button[type='submit']")?.textContent || "" }));
  if (!acceptsIpqsTotpChallenge(metadata)) throw new Error("Unrecognized IPQS authenticator challenge.");
  const code = await ipqsTotpCode(await readIpqsTotpUri());
  const field = form.locator('input[name="2fa"]');
  try {
    await field.fill(code, { timeout: 5000 });
    await form.getByRole("button", { name: "Finish Login »", exact: true }).click({ timeout: 10000 });
    await page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
    await page.waitForFunction(() => !document.querySelector('input[name="2fa"]') || !document.body.innerText.includes("Finish Login"), undefined, { timeout: 10000 }).catch(() => {});
  } catch { throw new Error("IPQS authenticator submission was unconfirmed; do not retry automatically."); }
  finally { if (await field.count() === 1) await field.fill("", { timeout: 500 }).catch(() => {}); }
}
