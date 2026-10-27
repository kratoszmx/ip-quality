import assert from 'node:assert/strict';
import test from 'node:test';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'node:url';

test('stdio exposes bounded provider actions and rejects unknown providers before effects', async () => {
  const client = new Client({ name: 'offline-fixture', version: '1' });
  const transport = new StdioClientTransport({ command: process.execPath, args: [fileURLToPath(new URL('../server.mjs', import.meta.url))], stderr: 'pipe' });
  try {
    await client.connect(transport);
    const { tools } = await client.listTools();
    assert.equal(tools.length, 21);
    for (const name of ['abuseipdb_account_status', 'abuseipdb_account_check', 'abuseipdb_verify_free_api', 'abuseipdb_account_open', 'ipdata_account_status', 'ipdata_account_check', 'ipdata_verify_free_api', 'provider_account_login', 'provider_account_close_browsers']) {
      assert.ok(tools.some(tool => tool.name === name));
    }
    for (const name of ['provider_account_open', 'abuseipdb_account_open']) {
      assert.equal(tools.find(tool => tool.name === name).inputSchema.properties.visible.default, false);
    }
    for (const tool of tools) assert.match(tool.description, /Free accounts only/);
    const response = await client.callTool({ name: 'provider_account_status', arguments: { provider: 'foreign.invalid' } });
    assert.equal(response.isError, true);
    const invalid = await client.callTool({ name: 'public_provider_verify_free_api', arguments: { provider: 'foreign.invalid', confirmation: 'VERIFY_FREE_API' } });
    assert.equal(invalid.isError, true);
    const unconfirmed = await client.callTool({ name: 'provider_account_login', arguments: { provider: 'ipapi', confirmation: 'WRONG' } });
    assert.equal(unconfirmed.isError, true);
    const unconfirmedIpdata = await client.callTool({ name: 'ipdata_verify_free_api', arguments: { confirmation: 'WRONG' } });
    assert.equal(unconfirmedIpdata.isError, true);
  } finally { await client.close(); await transport.close(); }
});
