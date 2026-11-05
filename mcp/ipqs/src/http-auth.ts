import path from "node:path";
import { pathToFileURL } from "node:url";
import { request } from "playwright-core";
import { requestBinaryWithBrowserContext } from "@myutils/browser-session";
import { parseActiveHtmlDocument } from "@myutils/web-text/http-text";
import { DomUtils } from "htmlparser2";
import { ROOT, IPQS_ORIGIN, getBrowserProfileDir, dashboardUrl, getProxyServer, type DashboardPageName } from "./config.js";

export const HTTP_STATE_FILE = path.join(getBrowserProfileDir(), "http-session.json");
const { readBrowserState } = await import(pathToFileURL(path.join(ROOT, "../common/browser-state.mjs")).href);

export function httpAuthStatus(status: number, contentType: string, body: string) {
  if (status !== 200) return { authenticated: false, stage: status === 403 || status === 429 ? "access-blocked" : "login", backend: "http", httpStatus: status };
  if (!/^text\/html(?:;|$)/i.test(contentType)) return { authenticated: false, stage: "unknown", backend: "http", httpStatus: status };
  const { children } = parseActiveHtmlDocument(body, { formEvidence: true });
  const login = DomUtils.existsOne(el => el.name === "form"
    && /^(?:https:\/\/www\.ipqualityscore\.com)?\/login\/submit$/.test(el.attribs.action ?? ""), children);
  const challenge = DomUtils.existsOne(el => el.name === "input" && el.attribs.name === "2fa", children);
  const logout = DomUtils.existsOne(el => el.name === "a"
    && /^(?:https:\/\/www\.ipqualityscore\.com)?\/(?:user\/)?logout\/?$/.test(el.attribs.href ?? ""), children);
  const authenticated = logout && !login && !challenge;
  return { authenticated, stage: authenticated ? "authenticated" : challenge ? "secondary-verification" : login ? "login" : "unknown", backend: "http", httpStatus: status };
}

// One allowlisted GET using only this account's saved state. No browser,
// navigation, redirects, credential submission or persisted cookie changes.
export async function readSavedDashboardHtml(pageName: DashboardPageName) {
  const state = await readBrowserState(HTTP_STATE_FILE, IPQS_ORIGIN);
  if (!state) throw new Error("No saved IPQS session is available for a dashboard read.");
  const proxy = getProxyServer();
  const context = await request.newContext({ storageState: state, ...(proxy ? { proxy: { server: proxy } } : {}) });
  try {
    return await requestBinaryWithBrowserContext({ request: context }, {
      url: dashboardUrl(pageName), headers: { "Accept": "text/html", "Cache-Control": "no-store" }, timeoutMs: 15000,
      maxRedirects: 0, maxResponseBytes: 1_048_576, readBodyForStatuses: [200],
    });
  } finally { await context.dispose(); }
}

export async function probeHttpAuth() {
  try {
    const response = await readSavedDashboardHtml("home");
    return httpAuthStatus(response.status, response.contentType || "", new TextDecoder("utf-8", { fatal: true }).decode(response.body));
  } catch { return { authenticated: false, stage: "unavailable", backend: "http" }; }
}
