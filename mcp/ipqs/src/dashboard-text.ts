import { DomUtils } from "htmlparser2";
import { extractHtmlTitle, htmlToReadableText, parseActiveHtmlDocument } from "@myutils/web-text/http-text";
import { redactText } from "@myutils/redaction";

import { dashboardUrl, type DashboardPageName } from "./config.js";
import { httpAuthStatus, readDashboardHtml } from "./http-auth.js";
import { boundedVisibleText } from "./redaction.js";

export async function readDashboardText(pageName: DashboardPageName, limit: number) {
  const response = await readDashboardHtml(pageName);
  let html = "";
  if (response.status === 200) {
    if (!/^text\/html(?:;|$)/i.test(response.contentType || "")) {
      throw new Error("IPQS dashboard text read returned an unexpected content type.");
    }
    const charset = /(?:^|;)\s*charset\s*=\s*["']?([^\s;"']+)/i.exec(response.contentType || "")?.[1];
    if (charset && !/^(?:utf-8|utf8|us-ascii)$/i.test(charset)) {
      throw new Error("IPQS dashboard text read returned an unsupported charset.");
    }
    html = new TextDecoder("utf-8", { fatal: true }).decode(response.body);
  }
  const auth = httpAuthStatus(response.status, response.contentType || "", html);
  const document = parseActiveHtmlDocument(html, { formEvidence: true });
  for (const element of DomUtils.findAll(({ name }) => name === "input" || name === "select", document.children)) {
    DomUtils.removeElement(element);
  }
  return {
    source: "ipqs-dashboard-http",
    page: pageName,
    path: new URL(dashboardUrl(pageName)).pathname,
    httpStatus: response.status,
    authenticated: auth.authenticated,
    loginRequired: auth.stage === "login" || auth.stage === "secondary-verification",
    title: redactText(extractHtmlTitle(html)).slice(0, 200),
    text: boundedVisibleText(htmlToReadableText(DomUtils.getOuterHTML(document), { bodyOnly: true }), limit),
    controls: [],
    buttons: [],
    controlsIncluded: false,
    note: "HTTP GET with the shared Chrome profile's IPQS cookies and static, value-free HTML extraction, without a page; use mode=controls for rendered DOM/control inspection.",
  };
}
