import type { Locator, Page } from "playwright-core";

import { IPQS_ORIGIN, summarizeIpqsUrl } from "./config.js";
import { redactText } from "./redaction.js";

const AUTHENTICATED_MARKERS = ["Dashboard", "API Keys", "Account Settings", "Logout", "Credits", "Usage"];
const SECONDARY_VERIFICATION_TEXT = /(?:verification code|two[- ]factor|\b2fa\b|multi[- ]factor|captcha|not a robot|passkey|security key)/i;
const CREDENTIAL_ERROR_TEXT = /(?:(?:incorrect|invalid|wrong|unrecognized|do not match).{0,80}(?:email|password|credential|login)|(?:email|password|credential|login).{0,80}(?:incorrect|invalid|wrong|unrecognized|do not match)|unable to (?:log|sign) in|login failed)/i;

export type IpqsAuthStage =
  | "authenticated"
  | "login"
  | "secondary-verification"
  | "credential-error"
  | "unknown";

export interface IpqsAuthSignals {
  trustedOrigin: boolean;
  path?: string;
  authenticatedMarkerCount: number;
  loginFormPresent: boolean;
  secondaryVerification: boolean;
  credentialError: boolean;
  totpChallengePresent?: boolean;
}

export function classifyIpqsAuthSignals(signals: IpqsAuthSignals): IpqsAuthStage {
  if (signals.trustedOrigin && signals.totpChallengePresent) return "secondary-verification";
  if (signals.trustedOrigin
    && signals.path?.startsWith("/user")
    && signals.authenticatedMarkerCount > 0
    && !signals.loginFormPresent) {
    return "authenticated";
  }
  if (signals.secondaryVerification) return "secondary-verification";
  if (signals.credentialError) return "credential-error";
  if (signals.trustedOrigin && (signals.path === "/login" || signals.path?.startsWith("/user/")) && signals.loginFormPresent) return "login";
  return "unknown";
}

export async function inspectIpqsAuthPage(page: Page) {
  const state = await page.evaluate(({ markers, secondaryPattern, credentialPattern }) => {
    const body = (document.body?.innerText || "").slice(0, 30_000);
    const authenticatedMarkerCount = markers
      .filter((marker) => body.toLocaleLowerCase("en-US").includes(marker.toLocaleLowerCase("en-US")))
      .length;
    const loginFormPresent = Array.from(document.forms).some((form) => {
      let action: URL;
      try {
        action = new URL(form.action, window.location.href);
      } catch {
        return false;
      }
      const visible = Boolean(form.offsetWidth || form.offsetHeight || form.getClientRects().length);
      return visible
        && action.origin === window.location.origin
        && action.pathname === "/login/submit"
        && form.method.toLocaleLowerCase("en-US") === "post"
        && Boolean(form.querySelector('input[name="email"]'))
        && Boolean(form.querySelector('input[name="password"][type="password"]'));
    });
    return {
      title: document.title,
      totpChallengePresent: !!document.querySelector('input[name="2fa"]') && /Finish Login/.test(body),
      authenticatedMarkerCount,
      loginFormPresent,
      secondaryVerification: new RegExp(secondaryPattern, "i").test(body),
      credentialError: new RegExp(credentialPattern, "i").test(body),
    };
  }, {
    markers: AUTHENTICATED_MARKERS,
    secondaryPattern: SECONDARY_VERIFICATION_TEXT.source,
    credentialPattern: CREDENTIAL_ERROR_TEXT.source,
  });
  const locationSummary = summarizeIpqsUrl(page.url());
  const dashboardCandidate = locationSummary.trustedOrigin
    && locationSummary.path?.startsWith("/user")
    && state.authenticatedMarkerCount > 0
    && !state.loginFormPresent && !state.totpChallengePresent;
  const signals: IpqsAuthSignals = {
    trustedOrigin: locationSummary.trustedOrigin,
    path: locationSummary.path,
    authenticatedMarkerCount: state.authenticatedMarkerCount,
    loginFormPresent: state.loginFormPresent,
    secondaryVerification: !dashboardCandidate && state.secondaryVerification,
    credentialError: !dashboardCandidate && state.credentialError,
    totpChallengePresent: state.totpChallengePresent,
  };
  const stage = classifyIpqsAuthSignals(signals);
  return {
    authenticated: stage === "authenticated",
    stage,
    trustedOrigin: signals.trustedOrigin,
    path: signals.path,
    title: redactText(state.title).slice(0, 200),
    evidence: {
      authenticatedMarkerCount: signals.authenticatedMarkerCount,
      loginFormPresent: signals.loginFormPresent,
      secondaryVerification: signals.secondaryVerification,
      credentialError: signals.credentialError,
    },
  };
}

async function uniqueVisible(locator: Locator, label: string) {
  const matches: Locator[] = [];
  const count = Math.min(await locator.count().catch(() => 0), 8);
  for (let index = 0; index < count; index += 1) {
    const candidate = locator.nth(index);
    if (await candidate.isVisible().catch(() => false)) matches.push(candidate);
  }
  if (matches.length !== 1) {
    throw new Error(`IPQS saved login stopped because ${label} was not uniquely visible.`);
  }
  return matches[0];
}

async function waitUntilEnabled(locator: Locator, timeoutMs: number) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await locator.isEnabled().catch(() => false)) return;
    await locator.page().waitForTimeout(250).catch(() => undefined);
  }
  throw new Error("IPQS saved login stopped because the reviewed login button did not become enabled.");
}

async function clearReviewedLoginFields(page: Page) {
  const form = page.locator('form[action="/login/submit"]');
  await form.locator('input[name="email"]').fill("").catch(() => undefined);
  await form.locator('input[name="password"][type="password"]').fill("").catch(() => undefined);
}

async function waitForLoginOutcome(page: Page, timeoutMs: number) {
  const deadline = Date.now() + timeoutMs;
  let current = await inspectIpqsAuthPage(page);
  while (current.stage === "login" && Date.now() < deadline) {
    await page.waitForTimeout(250).catch(() => undefined);
    current = await inspectIpqsAuthPage(page);
  }
  return current;
}

export async function submitIpqsCredentialsOnce(
  page: Page,
  credentials: { email: string; password: string },
  timeoutMs: number,
) {
  const before = await inspectIpqsAuthPage(page);
  if (!before.trustedOrigin || before.path !== "/login" || before.stage !== "login") {
    throw new Error("IPQS saved login requires the reviewed official login page.");
  }
  const form = await uniqueVisible(page.locator("form.login"), "the reviewed login form");
  const action = new URL(await form.getAttribute("action") || "", page.url());
  const method = (await form.getAttribute("method") || "").toLocaleLowerCase("en-US");
  if (action.origin !== IPQS_ORIGIN || action.pathname !== "/login/submit" || method !== "post") {
    throw new Error("IPQS saved login stopped because the visible form action was not reviewed.");
  }
  const email = await uniqueVisible(form.locator('input[name="email"]'), "the email field");
  const password = await uniqueVisible(
    form.locator('input[name="password"][type="password"]'),
    "the password field",
  );
  const submit = await uniqueVisible(
    form.locator('button[type="submit"]').filter({ hasText: /^\s*Login\s*$/i }),
    "the Login button",
  );
  try {
    await email.fill(credentials.email, { timeout: timeoutMs });
    await password.fill(credentials.password, { timeout: timeoutMs });
    await waitUntilEnabled(submit, timeoutMs);
    await submit.click({ timeout: timeoutMs });
    await page.waitForLoadState("domcontentloaded", { timeout: timeoutMs }).catch(() => undefined);
    const outcome = await waitForLoginOutcome(page, timeoutMs);
    if (!outcome.authenticated) await clearReviewedLoginFields(page);
    return {
      ...outcome,
      credentialSubmissions: { email: 1, password: 1 },
      retryAutomatically: false,
    };
  } catch {
    await clearReviewedLoginFields(page);
    throw new Error("IPQS saved login stopped safely after at most one reviewed credential submission.");
  }
}
