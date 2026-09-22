import { isLikelyIpqsApiKey } from "./config.js";

export interface DashboardControl {
  formIndex: number;
  controlIndex: number;
  tag: "input" | "select" | "textarea";
  type: string;
  name: string;
  id: string;
  label: string;
  disabled: boolean;
  required: boolean;
  optionLabels: string[];
}

export interface DashboardSubmit {
  formIndex: number;
  submitIndex: number;
  label: string;
  disabled: boolean;
}

export interface ApiKeyCandidate {
  secret: string;
  label: string;
}

const BLOCKED_FIELD_PATTERN = /(?:pass(?:word|code)?|e-?mail|mailbox|phone|mobile|mfa|2fa|two.?factor|authenticator|billing|payment|credit|card|plan|subscription|invoice|delete|remove|close|cancel|api.?key|token|secret)/i;
const BLOCKED_SUBMIT_PATTERN = /(?:delete|remove|close|cancel|disable|revoke|billing|payment|purchase|upgrade|downgrade|subscribe|password|e-?mail|mfa|2fa|api.?key|token|secret)/i;
const SUPPORTED_INPUT_TYPES = new Set(["text", "number", "url", "search", "checkbox"]);

export function normalizeReference(value: string) {
  return value.trim().replace(/\s+/g, " ").toLocaleLowerCase("en-US");
}

export function controlReferences(control: DashboardControl) {
  return [control.name, control.id, control.label].map(normalizeReference).filter(Boolean);
}

export function assertSafeSettingControl(control: DashboardControl, value: string | boolean) {
  const identity = [control.name, control.id, control.label].join(" ");
  if (control.disabled || BLOCKED_FIELD_PATTERN.test(identity)) {
    throw new Error("This account field is outside the low-risk preference-change policy.");
  }
  if (control.tag === "input" && !SUPPORTED_INPUT_TYPES.has(control.type || "text")) {
    throw new Error("This account field type is outside the low-risk preference-change policy.");
  }
  if (control.type === "checkbox") {
    if (typeof value !== "boolean") throw new Error("Checkbox preference values must be boolean.");
    return;
  }
  if (typeof value !== "string" || value.length > 512 || /[\u0000-\u001f\u007f]/.test(value)) {
    throw new Error("Preference value is invalid or too long.");
  }
}

export function selectSettingControl(controls: DashboardControl[], field: string) {
  const reference = normalizeReference(field);
  if (!reference) throw new Error("An exact setting field name, id, or label is required.");
  const matches = controls.filter((control) => controlReferences(control).includes(reference));
  if (matches.length !== 1) {
    throw new Error(matches.length === 0
      ? "No exact safe account setting field matched."
      : "The account setting field reference is ambiguous.");
  }
  return matches[0];
}

export function selectSafeSubmit(submits: DashboardSubmit[], formIndex: number, requestedLabel = "") {
  const candidates = submits.filter((submit) => submit.formIndex === formIndex
    && !submit.disabled
    && submit.label
    && !BLOCKED_SUBMIT_PATTERN.test(submit.label));
  if (requestedLabel) {
    const reference = normalizeReference(requestedLabel);
    const matches = candidates.filter((submit) => normalizeReference(submit.label) === reference);
    if (matches.length !== 1) throw new Error("No unique safe submit button matched the exact label.");
    return matches[0];
  }
  if (candidates.length !== 1) {
    throw new Error(candidates.length === 0
      ? "No safe submit button is available for this setting form."
      : "Multiple safe submit buttons exist; provide one exact submit label.");
  }
  return candidates[0];
}

export function safeSubmitLabels(submits: DashboardSubmit[], formIndex: number) {
  return submits
    .filter((submit) => submit.formIndex === formIndex && !submit.disabled && !BLOCKED_SUBMIT_PATTERN.test(submit.label))
    .map((submit) => submit.label);
}

export function dashboardContentReady(page: "home" | "settings" | "api_keys", visibleText: string) {
  if (page !== "api_keys") return true;
  const text = visibleText.replace(/\r/g, "");
  if (!text.trim() || /loading\s+api\s+key\s+metrics/i.test(text)) return false;
  return /\bactive\s*:\s*\d+\b/i.test(text)
    || /\bshowing\s+\d+\s+search\s+results?\b/i.test(text)
    || /\bno\s+(?:active\s+)?api\s+keys?\b/i.test(text);
}

export function extractApiKeyCandidatesFromVisibleText(visibleText: string) {
  const lines = visibleText
    .replace(/\r/g, "")
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, 2_000);
  const candidates: ApiKeyCandidate[] = [];
  for (let index = 0; index < lines.length; index += 1) {
    const tokens = lines[index].match(/[A-Za-z0-9_-]{20,128}/g) || [];
    for (const token of tokens) {
      if (!isLikelyIpqsApiKey(token)) continue;
      const context = lines.slice(Math.max(0, index - 4), index + 1);
      if (!context.some((line) => /\bapi\s*key\b/i.test(line))) continue;
      candidates.push({
        secret: token,
        label: context
          .map((line) => line.replaceAll(token, "<api-key>"))
          .join(" | ")
          .slice(0, 400),
      });
    }
  }
  return candidates;
}

export function selectApiKeyCandidate(candidates: ApiKeyCandidate[], labelContains = "") {
  const unique = new Map<string, ApiKeyCandidate>();
  for (const candidate of candidates) {
    const secret = candidate.secret.trim();
    if (isLikelyIpqsApiKey(secret) && !unique.has(secret)) unique.set(secret, { ...candidate, secret });
  }
  let selected = [...unique.values()];
  const label = normalizeReference(labelContains);
  if (label) selected = selected.filter((candidate) => normalizeReference(candidate.label).includes(label));
  if (selected.length !== 1) {
    throw new Error(selected.length === 0
      ? "No visible IPQS API key matched the requested dashboard label."
      : "Multiple visible IPQS API keys matched; provide a more specific label.");
  }
  return selected[0];
}
