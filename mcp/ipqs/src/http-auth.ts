import path from "node:path";
import { request } from "playwright-core";
import { readPrivateSecretFile } from "@myutils/secret-file";
import { requestBinaryWithBrowserContext } from "@myutils/browser-session";
import { getBrowserProfileDir, dashboardUrl, getProxyServer } from "./config.js";

export const HTTP_STATE_FILE = path.join(getBrowserProfileDir(), "http-session.json");

export function httpAuthStatus(status: number, contentType: string, body: string) {
  if (status !== 200) return { authenticated: false, stage: status === 403 || status === 429 ? "access-blocked" : "login", backend: "http", httpStatus: status };
  if (!/^text\/html(?:;|$)/i.test(contentType)) return { authenticated: false, stage: "unknown", backend: "http", httpStatus: status };
  const html = body.replace(/<!--[\s\S]*?-->|<(script|style|template)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, "");
  const login = /<form\b[^>]*\baction=["'](?:https:\/\/www\.ipqualityscore\.com)?\/login\/submit["']/i.test(html);
  const challenge = /<input\b[^>]*\bname=["']2fa["']/i.test(html);
  const logout = /<a\b[^>]*\bhref=["'](?:https:\/\/www\.ipqualityscore\.com)?\/(?:user\/)?logout\/?["']/i.test(html);
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
