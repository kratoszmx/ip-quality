import type { Page } from "playwright-core";

import { dashboardUrl, getTimeoutMs, type DashboardPageName } from "./config.js";
import { boundedVisibleText, redactText } from "./redaction.js";

// Read an already visited dashboard URL inside its authenticated browser origin.
// The response stays in the page; only a value-free, bounded text projection leaves it.
export async function readDashboardText(page: Page, pageName: DashboardPageName, limit: number) {
  const url = dashboardUrl(pageName);
  const raw = await page.evaluate(async ({ url, timeoutMs, maximumBytes }) => {
    if (location.origin !== new URL(url).origin) throw new Error("IPQS text read requires the dedicated authenticated origin.");
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, {
        method: "GET", credentials: "same-origin", redirect: "error", cache: "no-store", signal: controller.signal,
        headers: { accept: "text/html" },
      });
      if (response.status !== 200) {
        await response.body?.cancel();
        return { httpStatus: response.status, authenticated: false, text: "", title: "", loginRequired: false };
      }
      if (!/^text\/html(?:;|$)/i.test(response.headers.get("content-type") || "")) {
        await response.body?.cancel();
        throw new Error("IPQS dashboard text read returned an unexpected content type.");
      }
      if (Number(response.headers.get("content-length")) > maximumBytes) {
        await response.body?.cancel();
        throw new Error("IPQS dashboard text response exceeded its byte limit.");
      }
      if (!response.body) throw new Error("IPQS dashboard text response was empty.");
      const reader = response.body.getReader();
      const decoder = new TextDecoder("utf-8", { fatal: true });
      let html = "", bytes = 0;
      try {
        for (;;) {
          const part = await reader.read();
          if (part.done) break;
          bytes += part.value.byteLength;
          if (bytes > maximumBytes) {
            await reader.cancel();
            throw new Error("IPQS dashboard text response exceeded its byte limit.");
          }
          html += decoder.decode(part.value, { stream: true });
        }
        html += decoder.decode();
      } finally { reader.releaseLock(); }

      // A template is inert: no scripts, frames, stylesheets or images execute/load.
      const template = document.createElement("template");
      template.innerHTML = html;
      const root = template.content;
      const totpRequired = !!root.querySelector('input[name="2fa"]') && /Finish Login/.test(root.textContent || "");
      const loginRequired = totpRequired || Array.from(root.querySelectorAll("form")).some(form => {
        const action = new URL(form.getAttribute("action") || "", url);
        return action.origin === location.origin && action.pathname === "/login/submit";
      });
      const logoutPresent = Array.from(root.querySelectorAll("a[href]")).some(anchor => {
        const target = new URL(anchor.getAttribute("href") || "", url);
        return target.origin === location.origin && /^\/(?:user\/)?logout\/?$/.test(target.pathname);
      });
      const title = root.querySelector("title")?.textContent || "";
      root.querySelectorAll("script,style,noscript,template,svg,iframe,object,embed,input,textarea,select,[hidden],[inert],[aria-hidden='true']")
        .forEach(element => element.remove());
      root.querySelectorAll("[style]").forEach(element => {
        const style = element.getAttribute("style") || "";
        if (/(?:display\s*:\s*none|visibility\s*:\s*(?:hidden|collapse)|opacity\s*:\s*0\s*(?:;|$))/i.test(style)) element.remove();
      });
      root.querySelectorAll("br,p,div,section,article,li,tr,h1,h2,h3,h4,h5,h6")
        .forEach(element => element.append(document.createTextNode("\n")));
      return { httpStatus: response.status, authenticated: logoutPresent && !loginRequired,
        loginRequired, title, text: root.textContent || "" };
    } finally { clearTimeout(timer); }
  }, { url, timeoutMs: getTimeoutMs(), maximumBytes: 1_048_576 });

  return {
    source: "ipqs-dashboard-fetch",
    page: pageName,
    path: new URL(url).pathname,
    httpStatus: raw.httpStatus,
    authenticated: raw.authenticated,
    loginRequired: raw.loginRequired,
    title: redactText(raw.title).slice(0, 200),
    text: boundedVisibleText(raw.text, limit),
    controls: [],
    buttons: [],
    controlsIncluded: false,
    note: "HTML text from one same-origin GET without dashboard navigation or script execution; use mode=controls for rendered DOM/control inspection.",
  };
}
