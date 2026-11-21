import { randomUUID } from "node:crypto";
import { access } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

import { settleBrowserOperation, waitForEnter } from "@myutils/browser-session";
import { reserveOneUseRecord, takeOneUseRecord } from "@myutils/one-use-token";
import { writePrivateSecretFile } from "@myutils/secret-file";
import { releaseDedicatedChromePages, withDedicatedChrome } from "@myutils/web-text/dedicated-chrome";
import { sharedChromeCdpPort, sharedChromeProfileDir, sharedChromeRuntime } from "@myutils/web-text/shared-chrome";
import { chromium, type Page } from "playwright-core";

import { validateIpqsApiCredential } from "./api.js";
import { inspectIpqsAuthPage, submitIpqsCredentialsOnce } from "./auth.js";
import {
  DASHBOARD_PAGES,
  ROOT,
  IPQS_API_KEY_POLICY,
  IPQS_ORIGIN,
  dashboardUrl,
  getApiKeyFile,
  getTimeoutMs,
  inspectApiCredential,
  loginUrl,
  summarizeIpqsUrl,
  type DashboardPageName,
} from "./config.js";
import { inspectIpqsCredentials, readIpqsCredentials } from "./credentials.js";
import { readDashboardText } from "./dashboard-text.js";
import {
  assertSafeSettingControl,
  dashboardContentReady,
  extractApiKeyCandidatesFromVisibleText,
  safeSubmitLabels,
  selectApiKeyCandidate,
  selectSafeSubmit,
  selectSettingControl,
  type ApiKeyCandidate,
  type DashboardControl,
  type DashboardSubmit,
} from "./frontend-policy.js";
import { redactText } from "@myutils/redaction";
import { boundedVisibleText } from "./redaction.js";
import { probeIpqsAccount } from "./account-probe.js";
import { enrollIpqsTotp, completeIpqsTotp } from "./totp.js";

const { prepareBrowserVerification } = await import(pathToFileURL(path.join(ROOT, "../common/verification.mjs")).href);

interface PendingSettingChange {
  field: string;
  value: string | boolean;
  submitLabel: string;
  signature: Pick<DashboardControl, "formIndex" | "controlIndex" | "tag" | "type" | "name" | "id" | "label">;
  expiresAt: number;
}

const pendingSettingChanges = new Map<string, PendingSettingChange>();
const SETTING_CHANGE_TTL_MS = 10 * 60 * 1000;
const MAX_PENDING_SETTING_CHANGES = 100;
let browserLease = Promise.resolve();

async function withBrowserLease<T>(operation: () => Promise<T>) {
  let release!: () => void;
  const previous = browserLease;
  browserLease = new Promise<void>((resolve) => {
    release = resolve;
  });
  await previous;
  try {
    return await operation();
  } finally {
    release();
  }
}

// The IPQS login lives only in the shared Chrome profile (the text browser's
// saved profile). Every page is a tab of the one dedicated Chrome on it: a
// hidden tab of its own, or with `retain` the tab this server keeps for the
// next call; `visible` opens a window of that Chrome for the owner.
async function withIpqsPage<T>(options: { visible?: boolean; page?: "own" | "retain" }, operation: (page: Page) => Promise<T>) {
  return withDedicatedChrome(sharedChromeRuntime({ chromium }), {
    locale: "en-US", window: options.visible ? "shown" : "hidden",
    deadline: Date.now() + 60_000, page: options.page ?? "own",
  }, (_session, page) => operation(page));
}

async function withDashboardSession<T>(pageName: DashboardPageName, operation: (page: Page) => Promise<T>) {
  return withBrowserLease(() => withIpqsPage({}, async (page) => {
    await page.goto(dashboardUrl(pageName), { waitUntil: "domcontentloaded", timeout: getTimeoutMs() });
    return operation(page);
  }));
}

async function waitForDashboardContent(page: Page, pageName: DashboardPageName) {
  const timeoutMs = Math.min(getTimeoutMs(), 10_000);
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    const visibleText = await page.locator("body").innerText().catch(() => "");
    if (dashboardContentReady(pageName, visibleText)) return true;
    const remaining = deadline - Date.now();
    if (remaining <= 0) return false;
    await page.waitForTimeout(Math.min(250, remaining));
  }
}

async function collectDashboardSnapshot(page: Page, pageName: DashboardPageName, limit: number) {
  const raw = await page.evaluate(() => {
    const labelFor = (element: HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement) => {
      const labels = Array.from(element.labels || []).map((label) => label.innerText.trim()).filter(Boolean);
      if (labels.length) return labels.join(" / ");
      return element.getAttribute("aria-label")?.trim()
        || element.closest("label")?.innerText.trim()
        || "";
    };
    const controls = Array.from(document.querySelectorAll<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>("input, select, textarea"))
      .filter((element) => element.type !== "hidden")
      .slice(0, 200)
      .map((element) => ({
        tag: element.tagName.toLocaleLowerCase("en-US"),
        type: element instanceof HTMLInputElement ? (element.type || "text") : element.tagName.toLocaleLowerCase("en-US"),
        name: element.name || "",
        id: element.id || "",
        label: labelFor(element),
        disabled: element.disabled,
        required: element.required,
        checked: element instanceof HTMLInputElement && ["checkbox", "radio"].includes(element.type) ? element.checked : undefined,
        valuePresent: element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement
          ? Boolean(element.value)
          : element instanceof HTMLSelectElement,
        optionLabels: element instanceof HTMLSelectElement
          ? Array.from(element.options).slice(0, 100).map((option) => option.text.trim()).filter(Boolean)
          : [],
      }));
    const buttons = Array.from(document.querySelectorAll<HTMLButtonElement | HTMLInputElement>('button, input[type="submit"], input[type="button"]'))
      .slice(0, 100)
      .map((button) => ({
        type: button instanceof HTMLInputElement ? button.type : (button.type || "button"),
        label: (button instanceof HTMLInputElement ? button.value : button.innerText).trim(),
        disabled: button.disabled,
      }));
    return {
      title: document.title,
      text: document.body?.innerText || "",
      controls,
      buttons,
    };
  });
  const auth = await inspectIpqsAuthPage(page);
  return {
    source: "ipqs-dashboard-dom",
    page: pageName,
    path: auth.path,
    title: redactText(raw.title).slice(0, 200),
    authenticated: auth.authenticated,
    authEvidence: auth.evidence,
    text: boundedVisibleText(raw.text, limit),
    controls: raw.controls.map((control) => ({
      ...control,
      name: redactText(control.name).slice(0, 160),
      id: redactText(control.id).slice(0, 160),
      label: redactText(control.label).slice(0, 240),
      optionLabels: control.optionLabels.map((option) => redactText(option).slice(0, 160)),
    })),
    buttons: raw.buttons.map((button) => ({
      ...button,
      label: redactText(button.label).slice(0, 160),
    })),
  };
}

export function defaultStateSummary() {
  return {
    profileDir: sharedChromeProfileDir(),
    loginState: "shared-chrome-profile",
    cdpPort: sharedChromeCdpPort(),
    loginUrl: loginUrl(),
    dashboardPages: DASHBOARD_PAGES,
    browserBackend: "shared-dedicated-chrome-hidden-tab",
  };
}

export async function localStatus() {
  const profilePresent = await access(sharedChromeProfileDir()).then(() => true, () => false);
  return {
    state: defaultStateSummary(),
    profilePresent,
    savedCredentials: await inspectIpqsCredentials(),
    apiCredential: await inspectApiCredential(),
  };
}

export async function startInteractiveLogin(visible = false) {
  return withBrowserLease(() => withIpqsPage({ visible, page: "retain" }, async (page) => {
    await page.goto(loginUrl(), { waitUntil: "domcontentloaded", timeout: getTimeoutMs() });
    const verification = await prepareBrowserVerification(page, IPQS_ORIGIN);
    return {
      opened: true,
      backend: visible ? "shared-chrome-window" : "shared-chrome-hidden-tab",
      path: summarizeIpqsUrl(page.url()).path,
      verification,
      note: "Reviewed checkbox verification uses myutils native input. Use the confirmed saved-login tool to authenticate.",
    };
  }));
}

export async function loginWithSavedCredentials(options: {
  confirmedUseSavedCredentials: boolean;
  keepBrowser?: boolean;
}) {
  if (options.confirmedUseSavedCredentials !== true) {
    throw new Error("IPQS saved-credential login requires explicit task-level authorization.");
  }
  const keep = options.keepBrowser !== false;
  return withBrowserLease(() => withIpqsPage({ page: keep ? "retain" : "own" }, async (page) => {
    await page.goto(dashboardUrl("home"), { waitUntil: "domcontentloaded", timeout: getTimeoutMs() });
    let status = await inspectIpqsAuthPage(page);
    let credentialsRead = false;
    let totpSubmitted = false;
    let submissions = { email: 0, password: 0 };

    if (!status.authenticated) {
      await page.goto(loginUrl(), { waitUntil: "domcontentloaded", timeout: getTimeoutMs() });
      await prepareBrowserVerification(page, IPQS_ORIGIN);
      status = await inspectIpqsAuthPage(page);
      if (status.stage === "login") {
        const credentials = await readIpqsCredentials();
        credentialsRead = true;
        const outcome = await submitIpqsCredentialsOnce(page, credentials, getTimeoutMs());
        status = outcome;
        submissions = outcome.credentialSubmissions;
      }
    }

    if (status.stage === "secondary-verification" && await page.locator('input[name="2fa"]').count() === 1) {
      totpSubmitted = true;
      await completeIpqsTotp(page);
      status = await inspectIpqsAuthPage(page);
    }
    const secondary = status.stage === "secondary-verification";
    return {
      ok: status.authenticated,
      loginCompleted: status.authenticated,
      credentialsRead,
      credentialsSubmitted: submissions.password > 0,
      totpSubmitted,
      credentialSubmissions: submissions,
      state: status.stage,
      page: status,
      tabKept: keep,
      retryAutomatically: false,
      secretReturned: false,
      ...(status.authenticated
        ? {
          note: credentialsRead
            ? "IPQS returned an authenticated dashboard after one bounded windowless login; the shared Chrome profile keeps the session."
            : "The shared Chrome profile already had an authenticated IPQS dashboard session; saved credentials were not read.",
        }
        : secondary
          ? { nextStep: "Continue verification on the kept page with myutils; the remaining check is not authentication proof." }
          : { note: "The bounded IPQS login stopped without an automatic retry or visible browser fallback." }),
    };
  }));
}

export async function finishInteractiveLogin(keepBrowser = false) {
  return withBrowserLease(() => withIpqsPage({ page: keepBrowser ? "retain" : "own" }, async (page) => {
    await page.goto(dashboardUrl("home"), { waitUntil: "domcontentloaded", timeout: getTimeoutMs() });
    await prepareBrowserVerification(page, IPQS_ORIGIN);
    const status = await inspectIpqsAuthPage(page);
    return {
      ...status,
      tabKept: keepBrowser,
      note: status.authenticated
        ? "The shared Chrome profile currently reaches an authenticated IPQS dashboard."
        : "Authentication is not yet proven. A human window requires an explicit visible=true request.",
    };
  }));
}

export async function manualLogin() {
  await startInteractiveLogin(true);
  await waitForEnter("Finish IPQS login in the visible Chrome window, then press Enter here to verify the dashboard.");
  const result = await finishInteractiveLogin(false);
  if (!result.authenticated) throw new Error("IPQS login could not be verified from the current dashboard page.");
  return result;
}

export async function openInteractiveDashboard(pageName: DashboardPageName, visible = false) {
  return withBrowserLease(() => withIpqsPage({ visible, page: "retain" }, async (page) => {
    await page.goto(dashboardUrl(pageName), { waitUntil: "domcontentloaded", timeout: getTimeoutMs() });
    await prepareBrowserVerification(page, IPQS_ORIGIN);
    const auth = await inspectIpqsAuthPage(page);
    return {
      opened: true,
      page: pageName,
      path: auth.path,
      authenticated: auth.authenticated,
      tabKept: true,
    };
  }));
}

export async function readDashboard(pageName: DashboardPageName, limit = 12_000, mode: "text" | "controls" = "text") {
  if (mode === "text") return readDashboardText(pageName, limit);
  return withDashboardSession(pageName, async (page) => {
    await waitForDashboardContent(page, pageName);
    return collectDashboardSnapshot(page, pageName, limit);
  });
}

export async function enableIpqsTotp() {
  if ((await probeIpqsAccount()).outcome !== "authenticated") throw new Error("Verify usable IPQS API credits before authenticator enrollment.");
  return withDashboardSession("settings", async (page) => {
    if (!(await inspectIpqsAuthPage(page)).authenticated) throw new Error("Authenticate the IPQS account before enrollment.");
    return enrollIpqsTotp(page);
  });
}

export async function finishIpqsTotp() {
  return withDashboardSession("home", async (page) => {
    await completeIpqsTotp(page);
    const result = await inspectIpqsAuthPage(page);
    return { authenticated: result.authenticated, stage: result.stage, submittedOnce: true };
  });
}

async function clickApiKeyRevealControls(page: Page) {
  const candidates = page.locator("button, a");
  const count = Math.min(await candidates.count(), 150);
  let clicked = 0;
  for (let index = 0; index < count && clicked < 3; index += 1) {
    const control = candidates.nth(index);
    const label = ((await control.innerText().catch(() => "")) || (await control.getAttribute("aria-label")) || "").trim();
    if (!/(?:show|reveal|view).{0,20}(?:api\s*)?key/i.test(label) || /(?:delete|disable|revoke|remove)/i.test(label)) continue;
    await control.click({ timeout: 3000 }).catch(() => undefined);
    clicked += 1;
  }
  if (clicked) await page.waitForTimeout(300);
  return clicked;
}

export async function collectApiKeyCandidates(page: Page): Promise<ApiKeyCandidate[]> {
  const raw = await page.evaluate(() => {
    const results: Array<{ secret: string; label: string }> = [];
    const isRenderedVisible = (element: Element) => {
      for (let current: Element | null = element; current; current = current.parentElement) {
        if (current.hasAttribute("hidden") || current.hasAttribute("inert")) return false;
        const style = getComputedStyle(current);
        if (current.getClientRects().length === 0
          || style.display === "none"
          || style.visibility === "hidden"
          || style.visibility === "collapse"
          || style.opacity === "0") return false;
      }
      return true;
    };
    const labelFor = (element: Element) => {
      if (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement) {
        const labels = Array.from(element.labels || []).map((label) => label.innerText.trim()).filter(Boolean);
        if (labels.length) return labels.join(" / ");
      }
      return element.getAttribute("aria-label")?.trim()
        || element.closest("tr, section, article, fieldset, .card")?.textContent?.trim().slice(0, 400)
        || "API key";
    };
    for (const element of Array.from(document.querySelectorAll("input:not([type=hidden]), textarea, code, pre, [data-api-key]"))) {
      if (!isRenderedVisible(element)) continue;
      const value = element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement
        ? element.value
        : element.getAttribute("data-api-key") || element.textContent || "";
      if (value.trim()) results.push({ secret: value.trim(), label: labelFor(element) });
    }
    const visibleText: string[] = [];
    if (document.body) {
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      for (let node = walker.nextNode(); node; node = walker.nextNode()) {
        const parent = node.parentElement;
        if (parent && !parent.closest("script,style,noscript,template") && isRenderedVisible(parent)) {
          visibleText.push(node.textContent || "");
        }
      }
    }
    return { results, visibleText: visibleText.join("\n") };
  });
  return [...raw.results, ...extractApiKeyCandidatesFromVisibleText(raw.visibleText)];
}

export async function importApiKeyFromDashboard(options: {
  labelContains?: string;
  replaceExisting?: boolean;
  revealIfNeeded?: boolean;
} = {}) {
  return withDashboardSession("api_keys", async (page) => {
    const auth = await inspectIpqsAuthPage(page);
    if (!auth.authenticated) throw new Error("Authenticated IPQS API-key dashboard access is required.");
    if (!await waitForDashboardContent(page, "api_keys")) {
      throw new Error("IPQS API-key dashboard did not finish loading before the configured timeout.");
    }
    let candidates = await collectApiKeyCandidates(page);
    if (options.revealIfNeeded !== false) {
      await clickApiKeyRevealControls(page);
      candidates = await collectApiKeyCandidates(page);
    }
    const selected = selectApiKeyCandidate(candidates, options.labelContains);
    const validation = await validateIpqsApiCredential(selected.secret, getTimeoutMs());
    if (!validation.valid) {
      throw new Error("The visible IPQS dashboard token was not accepted as an API credential; no local secret was written.");
    }
    const result = await writePrivateSecretFile(getApiKeyFile(), selected.secret, {
      ...IPQS_API_KEY_POLICY,
      replace: options.replaceExisting === true,
    });
    return {
      imported: result.changed || !result.conflict,
      changed: result.changed,
      conflict: result.conflict,
      fingerprint: result.fingerprint,
      ...(result.previousFingerprint ? { previousFingerprint: result.previousFingerprint } : {}),
      label: redactText(selected.label).slice(0, 240),
      validation: validation.status,
      secretReturned: false,
      note: result.conflict
        ? "A different usable local key already exists. Repeat the confirmed import with replaceExisting=true only when replacement is intended."
        : "The selected dashboard key is available through the private local credential source.",
    };
  });
}

async function collectSettingForms(page: Page) {
  return page.evaluate(() => {
    const forms = Array.from(document.forms);
    const controls: DashboardControl[] = [];
    const submits: DashboardSubmit[] = [];
    const labelFor = (element: HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement) => {
      const labels = Array.from(element.labels || []).map((label) => label.innerText.trim()).filter(Boolean);
      if (labels.length) return labels.join(" / ");
      return element.getAttribute("aria-label")?.trim()
        || element.closest("label")?.innerText.trim()
        || "";
    };
    forms.forEach((form, formIndex) => {
      Array.from(form.querySelectorAll<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>("input:not([type=hidden]), select, textarea"))
        .forEach((element, controlIndex) => controls.push({
          formIndex,
          controlIndex,
          tag: element.tagName.toLocaleLowerCase("en-US") as DashboardControl["tag"],
          type: element instanceof HTMLInputElement ? (element.type || "text") : element.tagName.toLocaleLowerCase("en-US"),
          name: element.name || "",
          id: element.id || "",
          label: labelFor(element),
          disabled: element.disabled,
          required: element.required,
          optionLabels: element instanceof HTMLSelectElement
            ? Array.from(element.options).slice(0, 100).map((option) => option.text.trim()).filter(Boolean)
            : [],
        }));
      Array.from(form.querySelectorAll<HTMLButtonElement | HTMLInputElement>('button:not([type]), button[type="submit"], input[type="submit"]'))
        .forEach((element, submitIndex) => submits.push({
          formIndex,
          submitIndex,
          label: (element instanceof HTMLInputElement ? element.value : element.innerText).trim(),
          disabled: element.disabled,
        }));
    });
    return { controls, submits };
  });
}

function publicControl(control: DashboardControl) {
  return {
    tag: control.tag,
    type: control.type,
    name: redactText(control.name).slice(0, 160),
    id: redactText(control.id).slice(0, 160),
    label: redactText(control.label).slice(0, 240),
    required: control.required,
    optionLabels: control.optionLabels.map((label) => redactText(label).slice(0, 160)),
  };
}

export async function prepareSettingChange(options: {
  field: string;
  value: string | boolean;
  submitLabel?: string;
}) {
  return withDashboardSession("settings", async (page) => {
    const auth = await inspectIpqsAuthPage(page);
    if (!auth.authenticated) throw new Error("Authenticated IPQS settings dashboard access is required.");
    const forms = await collectSettingForms(page);
    const control = selectSettingControl(forms.controls, options.field);
    assertSafeSettingControl(control, options.value);
    let submit: DashboardSubmit;
    try {
      submit = selectSafeSubmit(forms.submits, control.formIndex, options.submitLabel);
    } catch (error) {
      const labels = safeSubmitLabels(forms.submits, control.formIndex).map((label) => redactText(label).slice(0, 160));
      if (labels.length > 1 && !options.submitLabel) {
        return {
          prepared: false,
          reason: "multiple-safe-submit-buttons",
          safeSubmitLabels: labels,
          note: "Repeat with one exact submitLabel.",
        };
      }
      throw error;
    }
    const now = Date.now();
    const reservation = reserveOneUseRecord(pendingSettingChanges, {
      now,
      ttlMs: SETTING_CHANGE_TTL_MS,
      capacity: MAX_PENDING_SETTING_CHANGES,
      attempts: 8,
      createToken: randomUUID,
      createRecord: (expiresAt) => ({
        field: options.field,
        value: options.value,
        submitLabel: submit.label,
        signature: {
          formIndex: control.formIndex,
          controlIndex: control.controlIndex,
          tag: control.tag,
          type: control.type,
          name: control.name,
          id: control.id,
          label: control.label,
        },
        expiresAt,
      }),
    });
    if (reservation.kind !== "reserved") {
      throw new Error(reservation.kind === "capacity"
        ? "Too many pending IPQS setting changes; apply or let an existing change expire first."
        : "Could not allocate a unique IPQS setting change id.");
    }
    const id = reservation.token;
    const expiresAt = reservation.expiresAt;
    return {
      prepared: true,
      changeId: id,
      expiresAt: new Date(expiresAt).toISOString(),
      field: publicControl(control),
      submitLabel: redactText(submit.label).slice(0, 160),
      valueStoredInMemoryOnly: true,
      confirmation: "APPLY_IPQS_ACCOUNT_SETTING",
    };
  });
}

function sameControlSignature(control: DashboardControl, signature: PendingSettingChange["signature"]) {
  return control.formIndex === signature.formIndex
    && control.controlIndex === signature.controlIndex
    && control.tag === signature.tag
    && control.type === signature.type
    && control.name === signature.name
    && control.id === signature.id
    && control.label === signature.label;
}

async function fillSettingControl(page: Page, control: DashboardControl, value: string | boolean) {
  const form = page.locator("form").nth(control.formIndex);
  const locator = form.locator("input:not([type=hidden]), select, textarea").nth(control.controlIndex);
  if (await locator.count() !== 1) throw new Error("Prepared IPQS setting field is no longer uniquely available.");
  if (control.type === "checkbox") {
    if (value === true) await locator.check();
    else await locator.uncheck();
    return;
  }
  if (typeof value !== "string") throw new Error("Prepared IPQS setting value no longer matches its field type.");
  if (control.tag === "select") {
    const selectedByLabel = await locator.selectOption({ label: value }).catch(() => []);
    if (!selectedByLabel.length) {
      const selectedByValue = await locator.selectOption(value).catch(() => []);
      if (!selectedByValue.length) throw new Error("Prepared IPQS select option is no longer available.");
    }
    return;
  }
  await locator.fill(value);
}

export async function applySettingChange(changeId: string) {
  return withBrowserLease(async () => {
    const claim = takeOneUseRecord(pendingSettingChanges, changeId, Date.now());
    if (claim.kind !== "taken") throw new Error("Prepared IPQS setting change is missing or expired.");
    const pending = claim.record;
    return withIpqsPage({}, async (page) => {
      await page.goto(dashboardUrl("settings"), {
        waitUntil: "domcontentloaded",
        timeout: getTimeoutMs(),
      });
      const authBefore = await inspectIpqsAuthPage(page);
      if (!authBefore.authenticated) throw new Error("Authenticated IPQS settings dashboard access is required.");
      const forms = await collectSettingForms(page);
      const control = selectSettingControl(forms.controls, pending.field);
      assertSafeSettingControl(control, pending.value);
      if (!sameControlSignature(control, pending.signature)) {
        throw new Error("The IPQS settings form changed after preparation; prepare the change again.");
      }
      const submit = selectSafeSubmit(forms.submits, control.formIndex, pending.submitLabel);
      const form = page.locator("form").nth(control.formIndex);
      const button = form.locator('button:not([type]), button[type="submit"], input[type="submit"]').nth(submit.submitIndex);
      if (await button.count() !== 1) throw new Error("Prepared IPQS submit button is no longer available.");
      if (Date.now() >= pending.expiresAt) throw new Error("Prepared IPQS setting change expired before the field could be filled.");
      await fillSettingControl(page, control, pending.value);
      if (Date.now() >= pending.expiresAt) throw new Error("Prepared IPQS setting change expired before submission.");
      await button.click({ timeout: getTimeoutMs() });
      await page.waitForLoadState("domcontentloaded", { timeout: 5000 }).catch(() => undefined);
      await page.waitForTimeout(500);
      const authAfter = await inspectIpqsAuthPage(page);
      const body: string = await page.locator("body").innerText().catch(() => "");
      const evidence = body.split("\n")
        .map((line: string) => line.trim())
        .find((line: string) => /(?:saved|updated|success|changes? applied)/i.test(line));
      return {
        submitted: true,
        authenticatedAfter: authAfter.authenticated,
        path: authAfter.path,
        outcome: evidence ? "success-evidence-visible" : "submitted-outcome-unverified",
        evidence: evidence ? redactText(evidence).slice(0, 300) : undefined,
        note: evidence
          ? "The page displayed sanitized success evidence after submission."
          : "The form was submitted once, but the current DOM did not expose a clear success marker; inspect the setting before retrying.",
      };
    });
  });
}

// Release this server's kept tab and its attachment to the shared Chrome. The
// Chrome itself stays under its own 30-minute idle close.
export async function closeBrowser() {
  return withBrowserLease(async () => {
    const result = await settleBrowserOperation(async () => ({ released: true }), () => releaseDedicatedChromePages());
    if ("cleanup" in result) return { ...result, released: false };
    return result;
  });
}
