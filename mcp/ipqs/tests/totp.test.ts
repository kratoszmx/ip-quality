import assert from "node:assert/strict";
import test from "node:test";
import { ipqsSetup, enrollIpqsTotp, totpDirectory, acceptsIpqsTotpChallenge } from "../src/totp.js";
import { REPO_ROOT } from "../src/config.js";
import { redactText } from "../src/redaction.js";
import type { Page } from "playwright-core";
import { classifyIpqsAuthSignals } from "../src/auth.js";

const email = "fixture@example.test";
const uri = `otpauth://totp/IPQualityScore:${email}?secret=JBSWY3DPEHPK3PXP&issuer=IPQualityScore`;
const qr = (value = uri) => `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(value)}`;
const recovery = "Emergency Backup Code\nSave the code below somewhere secure.\n12345678";

test("IPQS textual setup binds the provider and saved identity before any enrollment", () => {
  assert.deepEqual(ipqsSetup(qr(), recovery, email), { uri, recoveryCode: "12345678" });
  for (const [source, text, account] of [
    [qr().replace("api.qrserver.com", "foreign.invalid"), recovery, email],
    [qr(uri.replace("issuer=IPQualityScore", "issuer=Foreign")), recovery, email],
    [qr(), recovery, "different@example.test"],
    [qr(), recovery + " 87654321", email],
    [qr(), "no backup supplied", email],
    [qr() + "&data=duplicate", recovery, email],
  ]) assert.throws(() => ipqsSetup(source, text, account));
  assert.equal(totpDirectory, `${REPO_ROOT}/secrets/accounts/ipqs`);
});

test("untrusted or changed MFA pages stop before reading private account files", async () => {
  const foreign = { url: () => "https://foreign.invalid/user/settings" } as Page;
  await assert.rejects(enrollIpqsTotp(foreign), /Expected authenticated/);
  const changed = { url: () => "https://www.ipqualityscore.com/user/settings", evaluate: async () => ({ ready: false, text: "Account settings changed" }) } as unknown as Page;
  assert.deepEqual(await enrollIpqsTotp(changed), { enabled: false, changed: false, state: "inspect_existing_factor" });
});

test("security text never emits the provisioning URI or emergency backup code", () => {
  const output = redactText(`${uri}\n${recovery}`);
  assert.ok(!output.includes("JBSWY3DPEHPK3PXP"));
  assert.ok(!output.includes("12345678"));
  assert.match(output, /redacted-totp/);
  assert.match(output, /redacted-recovery/);
});

test("MFA challenges cannot become authenticated because dashboard navigation is present", () => {
  assert.equal(classifyIpqsAuthSignals({ trustedOrigin: true, path: "/user/settings", authenticatedMarkerCount: 5,
    loginFormPresent: false, credentialError: false, secondaryVerification: true, totpChallengePresent: true }), "secondary-verification");
  const value = { url: "https://www.ipqualityscore.com/user/dashboard", action: "", method: "post", fields: ["2fa", "rememberme", "rememberme"], button: "Finish Login »" };
  assert.equal(acceptsIpqsTotpChallenge(value), true);
  for (const changed of [{ action: "https://foreign.invalid" }, { method: "get" }, { fields: ["password", "2fa"] },
    { fields: ["2fa", "2fa"] }, { button: "Activate 2FA »" }, { url: "https://foreign.invalid/user/dashboard" }]) {
    assert.equal(acceptsIpqsTotpChallenge({ ...value, ...changed }), false);
  }
});
