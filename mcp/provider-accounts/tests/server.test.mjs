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
    assert.equal(tools.length, 11);
    for (const tool of tools) assert.match(tool.description, /Free accounts only/);
    const response = await client.callTool({ name: 'provider_account_status', arguments: { provider: 'foreign.invalid' } });
    assert.equal(response.isError, true);
  } finally { await client.close(); await transport.close(); }
});
