import path from "node:path";
import { pathToFileURL } from "node:url";
import { requestBinaryWithBrowserContext } from "@myutils/browser-session";
import { parseActiveHtmlDocument } from "@myutils/web-text/http-text";
import { DomUtils } from "htmlparser2";
import { ROOT, dashboardUrl, getProxyServer, type DashboardPageName } from "./config.js";

const { withSharedCookies } = await import(pathToFileURL(path.join(ROOT, "../common/shared-cookies.mjs")).href);

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

// One allowlisted GET with the shared Chrome profile's IPQS cookies; cookies the
// response refreshes go back to that profile. No page, redirect, retry or credential submission.
export async function readDashboardHtml(pageName: DashboardPageName): Promise<Awaited<ReturnType<typeof requestBinaryWithBrowserContext>>> {
  const url = dashboardUrl(pageName);
  return withSharedCookies(url, getProxyServer(), (context: unknown) => requestBinaryWithBrowserContext({ request: context }, {
    url, headers: { "Accept": "text/html", "Cache-Control": "no-store" }, timeoutMs: 15000,
    maxRedirects: 0, maxResponseBytes: 1_048_576, readBodyForStatuses: [200],
  }));
}

export async function probeHttpAuth() {
  try {
    const response = await readDashboardHtml("home");
    return httpAuthStatus(response.status, response.contentType || "", new TextDecoder("utf-8", { fatal: true }).decode(response.body));
  } catch { return { authenticated: false, stage: "unavailable", backend: "http" }; }
}
