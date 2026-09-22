import assert from "node:assert/strict";
import test from "node:test";

import {
  assertSafeSettingControl,
  dashboardContentReady,
  extractApiKeyCandidatesFromVisibleText,
  selectApiKeyCandidate,
  selectSafeSubmit,
  selectSettingControl,
  type DashboardControl,
  type DashboardSubmit,
} from "../src/frontend-policy.js";

const safeControl: DashboardControl = {
  formIndex: 0,
  controlIndex: 0,
  tag: "select",
  type: "select",
  name: "timezone",
  id: "timezone",
  label: "Timezone",
  disabled: false,
  required: false,
  optionLabels: ["UTC", "Asia/Shanghai"],
};

test("setting policy requires exact unique low-risk fields and safe submits", () => {
  assert.equal(selectSettingControl([safeControl], "Timezone"), safeControl);
  assert.doesNotThrow(() => assertSafeSettingControl(safeControl, "Asia/Shanghai"));
  const blocked = { ...safeControl, name: "account_email", id: "account_email", label: "Email" };
  assert.throws(() => assertSafeSettingControl(blocked, "new@example.test"), /outside the low-risk/);
  assert.throws(() => selectSettingControl([safeControl, { ...safeControl }], "timezone"), /ambiguous/);

  const submits: DashboardSubmit[] = [
    { formIndex: 0, submitIndex: 0, label: "Save Changes", disabled: false },
    { formIndex: 0, submitIndex: 1, label: "Delete Account", disabled: false },
  ];
  assert.equal(selectSafeSubmit(submits, 0).label, "Save Changes");
  assert.throws(() => selectSafeSubmit([{ formIndex: 0, submitIndex: 0, label: "Disable", disabled: false }], 0), /No safe submit/);
});

test("API key selection requires one plausible exact dashboard candidate", () => {
  const first = "syntheticPrimaryKey1234567890";
  const second = "syntheticBackupKey0987654321";
  assert.equal(selectApiKeyCandidate([{ secret: first, label: "Primary API Key" }]).secret, first);
  assert.equal(selectApiKeyCandidate([
    { secret: first, label: "Primary API Key" },
    { secret: second, label: "Backup API Key" },
  ], "backup").secret, second);
  assert.throws(() => selectApiKeyCandidate([
    { secret: first, label: "API Key" },
    { secret: second, label: "API Key" },
  ]), /Multiple visible/);
  assert.throws(() => selectApiKeyCandidate([{ secret: "not-a-key", label: "Primary" }]), /No visible/);
});

test("dynamic API-key dashboard readiness and split-line key extraction stay bounded", () => {
  assert.equal(dashboardContentReady("api_keys", "Loading API Key Metrics..."), false);
  assert.equal(dashboardContentReady("api_keys", "Active: 1\nShowing 1 search result"), true);
  assert.equal(dashboardContentReady("api_keys", "Active: 0\nNo active API keys"), true);
  assert.equal(dashboardContentReady("home", ""), true);

  const key = "syntheticPrimaryKey1234567890";
  const visibleText = [
    "Showing 1 search result",
    "User API Key Starter Version 1 Expiration: Never",
    "Active",
    key,
    "Upgrade Edit Disable Delete",
  ].join("\n");
  const candidates = extractApiKeyCandidatesFromVisibleText(visibleText);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].secret, key);
  assert.match(candidates[0].label, /User API Key/i);
  assert.equal(candidates[0].label.includes(key), false);
  assert.deepEqual(extractApiKeyCandidatesFromVisibleText(`Unrelated account\n${key}`), []);
});
