import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { CallToolResultSchema } from "@modelcontextprotocol/sdk/types.js";

const PACKAGE_ROOT = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const SERVER_ENTRY = path.join(PACKAGE_ROOT, "dist", "src", "server.js");

test("compiled stdio MCP lists the complete tool surface and returns a secret-free static status", async () => {
  const temporary = path.join(PACKAGE_ROOT, ".state", "stdio-test");
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [SERVER_ENTRY],
    env: {
      PATH: process.env.PATH || "/usr/bin:/bin",
      HOME: path.join(temporary, "home"),
      IPQS_BROWSER_PROFILE_DIR: path.join(temporary, "profile"),
      IPQS_API_KEY_FILE: path.join(temporary, "secrets", "api_key"),
    },
    stderr: "pipe",
  });
  const client = new Client({ name: "ipqs-offline-test", version: "0.1.0" });
  try {
    await client.connect(transport);
    const tools = await client.listTools();
    assert.deepEqual(tools.tools.map((tool) => tool.name).sort(), [
      "ipqs_account_usage",
      "ipqs_apply_setting_change",
      "ipqs_close_browser",
      "ipqs_complete_totp",
      "ipqs_enable_totp",
      "ipqs_finish_login",
      "ipqs_import_api_key",
      "ipqs_login_with_saved_credentials",
      "ipqs_lookup",
      "ipqs_open_dashboard",
      "ipqs_open_login",
      "ipqs_prepare_setting_change",
      "ipqs_read_dashboard",
      "ipqs_status",
    ]);
    for (const tool of tools.tools) {
      assert.match(tool.description || "", /MCP server usage instructions/);
    }
    const raw = await client.callTool({ name: "ipqs_status", arguments: { probeBrowser: false } });
    const parsed = CallToolResultSchema.parse(raw);
    assert.notEqual(parsed.isError, true);
    const block = parsed.content.find((entry) => entry.type === "text");
    assert.ok(block && block.type === "text");
    const statusText = block.text;
    assert.equal(statusText.includes("IPQS_API_KEY"), false);
    const status = JSON.parse(statusText);
    assert.equal(status.ok, true);
    assert.equal(status.result.browser.probed, false);
    assert.equal(status.result.savedCredentials.ready, false);
    assert.equal(status.result.apiCredential.usable, false);
  } finally {
    await client.close();
  }
});
