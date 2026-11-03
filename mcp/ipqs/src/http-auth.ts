import path from "node:path";
import { request } from "playwright-core";
import { readPrivateSecretFile } from "@myutils/secret-file";
import { requestBinaryWithBrowserContext } from "@myutils/browser-session";
import { parseActiveHtmlDocument } from "@myutils/web-text/http-text";
import { DomUtils } from "htmlparser2";
import { getBrowserProfileDir, dashboardUrl, getProxyServer } from "./config.js";

export const HTTP_STATE_FILE = path.join(getBrowserProfileDir(), "http-session.json");

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

export async function probeHttpAuth() {
  let context;
  try {
    const saved = await readPrivateSecretFile(HTTP_STATE_FILE, { minBytes: 2, maxBytes: 2_097_152 });
    const state = JSON.parse(saved.secret);
    if (!Array.isArray(state.cookies) || !Array.isArray(state.origins)) throw new Error("Invalid private browser state.");
    const proxy = getProxyServer();
    context = await request.newContext({ storageState: state, ...(proxy ? { proxy: { server: proxy } } : {}) });
    const response = await requestBinaryWithBrowserContext({ request: context }, {
      url: dashboardUrl("home"), headers: { "Cache-Control": "no-cache" }, timeoutMs: 15000,
      maxRedirects: 0, maxResponseBytes: 1_048_576, readBodyForStatuses: [200],
    });
    return httpAuthStatus(response.status, response.contentType || "", response.body.toString("utf8"));
  } catch { return { authenticated: false, stage: "unavailable", backend: "http" }; }
  finally { await context?.dispose(); }
}
