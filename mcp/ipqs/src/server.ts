#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { buildToolDescription, textResult } from "@codex-mcp/shared-mcp-server";
import { z } from "zod/v4";

import { getIpqsAccountUsage, lookupIpqs, type ApiParameterValue } from "./api.js";
import {
  applySettingChange,
  closeBrowser,
  enableIpqsTotp,
  finishIpqsTotp,
  finishInteractiveLogin,
  importApiKeyFromDashboard,
  loginWithSavedCredentials,
  localStatus,
  openInteractiveDashboard,
  prepareSettingChange,
  probeBrowserAuth,
  readDashboard,
  startInteractiveLogin,
} from "./browser.js";
import { getTimeoutMs } from "./config.js";
import { sanitizedError } from "./redaction.js";
import { SERVER_INSTRUCTIONS as IPQS_SERVER_INSTRUCTIONS } from "./tool-policy.js";

const SERVER_INSTRUCTIONS = IPQS_SERVER_INSTRUCTIONS;
const server = new McpServer({
  name: "codex-ipqs-mcp",
  version: "0.1.0",
}, {
  instructions: SERVER_INSTRUCTIONS,
});


const dashboardPageSchema = z.enum(["home", "settings", "api_keys"]);
server.registerTool("ipqs_enable_totp", {
  description: buildToolDescription("Enable the existing IPQS account authenticator once after usable API proof. Saves the textual setup URI and emergency backup code privately before submission. Existing factors and enrollment attempts are preserved.", SERVER_INSTRUCTIONS),
  inputSchema: { confirm: z.literal("ENABLE_IPQS_TOTP") },
}, () => safeResult(enableIpqsTotp));
server.registerTool("ipqs_complete_totp", {
  description: buildToolDescription("Complete one reviewed IPQS authenticator challenge using its private saved seed. Requires task authorization; never returns or logs codes and never retries automatically.", SERVER_INSTRUCTIONS),
  inputSchema: { confirm: z.literal("USE_SAVED_IPQS_TOTP") },
}, () => safeResult(finishIpqsTotp));
const parameterScalarSchema = z.union([z.string().max(1000), z.number().finite(), z.boolean()]);
const parameterValueSchema = z.union([parameterScalarSchema, z.array(parameterScalarSchema).max(20)]);
const parametersSchema = z.record(z.string(), parameterValueSchema).default({});

async function safeResult(operation: () => Promise<unknown>) {
  try {
    return textResult({ ok: true, result: await operation() });
  } catch (error) {
    return textResult({ ok: false, error: sanitizedError(error) });
  }
}

server.registerTool(
  "ipqs_status",
  {
    title: "IPQS Status",
    description: buildToolDescription("Report sanitized local profile and API credential readiness; live browser probing is explicit.", SERVER_INSTRUCTIONS),
    inputSchema: {
      probeBrowser: z.boolean().default(false),
    },
  },
  async ({ probeBrowser }) => safeResult(async () => ({
    ...(await localStatus()),
    browser: probeBrowser
      ? await probeBrowserAuth()
      : { probed: false, note: "Set probeBrowser=true to open the dedicated profile and verify the current dashboard session." },
    safety: {
      apiKeyReturned: false,
      browserProfileExported: false,
      lookupRetries: false,
      liveCodexRegistrationChanged: false,
    },
  })),
);

server.registerTool(
  "ipqs_open_login",
  {
    title: "Open IPQS Login",
    description: buildToolDescription("Keep the dedicated real Chrome/CDP session open for human IPQS authentication.", SERVER_INSTRUCTIONS),
    inputSchema: {},
  },
  async () => safeResult(startInteractiveLogin),
);

server.registerTool(
  "ipqs_finish_login",
  {
    title: "Finish IPQS Login",
    description: buildToolDescription("Verify the current dashboard session after human authentication and optionally keep Chrome open.", SERVER_INSTRUCTIONS),
    inputSchema: {
      keepBrowser: z.boolean().default(false),
    },
  },
  async ({ keepBrowser }) => safeResult(() => finishInteractiveLogin(keepBrowser)),
);

server.registerTool(
  "ipqs_login_with_saved_credentials",
  {
    title: "Login To IPQS With Saved Credentials",
    description: buildToolDescription("Use the fixed owner-only two-line IPQS credential bundle for one bounded login attempt after explicit task authorization; never accepts or returns credential values.", SERVER_INSTRUCTIONS),
    inputSchema: {
      confirm: z.literal("USE_SAVED_IPQS_CREDENTIALS"),
      keepBrowser: z.boolean().default(true),
    },
  },
  async ({ keepBrowser }) => safeResult(() => loginWithSavedCredentials({
    confirmedUseSavedCredentials: true,
    keepBrowser,
  })),
);

server.registerTool(
  "ipqs_open_dashboard",
  {
    title: "Open IPQS Dashboard",
    description: buildToolDescription("Keep the dedicated browser open on one allowlisted IPQS dashboard page for visible review.", SERVER_INSTRUCTIONS),
    inputSchema: {
      page: dashboardPageSchema.default("home"),
    },
  },
  async ({ page }) => safeResult(() => openInteractiveDashboard(page)),
);

server.registerTool(
  "ipqs_read_dashboard",
  {
    title: "Read IPQS Dashboard",
    description: buildToolDescription("Read one allowlisted dashboard through same-origin HTTP text by default, without navigating/rendering the dashboard. Use mode=controls for rendered DOM text and value-free controls.", SERVER_INSTRUCTIONS),
    inputSchema: {
      page: dashboardPageSchema.default("home"),
      textLimit: z.number().int().min(500).max(50_000).default(12_000),
      mode: z.enum(["text", "controls"]).default("text"),
    },
  },
  async ({ page, textLimit, mode }) => safeResult(() => readDashboard(page, textLimit, mode)),
);

server.registerTool(
  "ipqs_import_api_key",
  {
    title: "Import IPQS API Key",
    description: buildToolDescription("Select one visible dashboard API key and write it directly to the private local secret file without returning it.", SERVER_INSTRUCTIONS),
    inputSchema: {
      labelContains: z.string().max(160).optional(),
      revealIfNeeded: z.boolean().default(true),
      replaceExisting: z.boolean().default(false),
      confirm: z.literal("IMPORT_IPQS_API_KEY"),
    },
  },
  async ({ labelContains, revealIfNeeded, replaceExisting }) => safeResult(() => importApiKeyFromDashboard({
    labelContains,
    revealIfNeeded,
    replaceExisting,
  })),
);

server.registerTool(
  "ipqs_prepare_setting_change",
  {
    title: "Prepare IPQS Setting Change",
    description: buildToolDescription("Prepare but do not apply one exact low-risk account preference change with a safe submit button.", SERVER_INSTRUCTIONS),
    inputSchema: {
      field: z.string().min(1).max(240),
      value: z.union([z.string().max(512), z.boolean()]),
      submitLabel: z.string().min(1).max(160).optional(),
    },
  },
  async ({ field, value, submitLabel }) => safeResult(() => prepareSettingChange({ field, value, submitLabel })),
);

server.registerTool(
  "ipqs_apply_setting_change",
  {
    title: "Apply IPQS Setting Change",
    description: buildToolDescription("Revalidate and submit one unexpired prepared low-risk account preference change exactly once.", SERVER_INSTRUCTIONS),
    inputSchema: {
      changeId: z.string().uuid(),
      confirm: z.literal("APPLY_IPQS_ACCOUNT_SETTING"),
    },
  },
  async ({ changeId }) => safeResult(() => applySettingChange(changeId)),
);

server.registerTool(
  "ipqs_account_usage",
  {
    title: "IPQS Account Usage",
    description: buildToolDescription("Read IPQS credits and current billing-period usage through the official read-only account API.", SERVER_INSTRUCTIONS),
    inputSchema: {
      timeoutMs: z.number().int().min(1000).max(60_000).default(getTimeoutMs()),
    },
  },
  async ({ timeoutMs }) => safeResult(() => getIpqsAccountUsage(timeoutMs)),
);

server.registerTool(
  "ipqs_lookup",
  {
    title: "IPQS Reputation Lookup",
    description: buildToolDescription("Perform one explicit official IP, email, phone, or URL reputation lookup without automatic retries.", SERVER_INSTRUCTIONS),
    inputSchema: {
      kind: z.enum(["ip", "email", "phone", "url"]),
      lookup: z.string().min(1).max(4096),
      parameters: parametersSchema,
      timeoutMs: z.number().int().min(1000).max(60_000).default(getTimeoutMs()),
    },
  },
  async ({ kind, lookup, parameters, timeoutMs }) => safeResult(() => lookupIpqs(
    kind,
    lookup,
    parameters as Record<string, ApiParameterValue>,
    timeoutMs,
  )),
);

server.registerTool(
  "ipqs_close_browser",
  {
    title: "Close IPQS Browser",
    description: buildToolDescription("Close the package-managed Chrome/CDP connection after login or dashboard review.", SERVER_INSTRUCTIONS),
    inputSchema: {},
  },
  async () => safeResult(closeBrowser),
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("codex-ipqs-mcp running on stdio");
}

main().catch((error) => {
  console.error(sanitizedError(error));
  process.exit(1);
});
