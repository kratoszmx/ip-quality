import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { buildToolDescription, textResult } from '@codex-mcp/shared-mcp-server';
import { accountStatus, openAccount, readAccount, createFreeAccount, importIpapiKey } from './accounts.mjs';
import { checkCloudflareAccount, prepareCloudflareToken, createCloudflareToken, verifyCloudflareApi } from './cloudflare.mjs';
import { enableCloudflareTotp, saveCloudflareRecoveryCodes } from './cloudflare-totp.mjs';
import { verifyPublicProvider } from './public-api.mjs';

const instructions = 'IPQuality provider accounts. Dedicated ipapi/Cloudflare profiles only. Free accounts only; no billing or plan upgrade tools. Account creation needs task authorization and CREATE_FREE_ACCOUNT. Stop for human verification; never solve CAPTCHA. Store secrets privately and never return keys, passwords, OTPs, recovery codes or cookies. A saved file is not live authentication. No automatic signup or lookup retries.';
const server = new McpServer({ name: 'ipquality-provider-accounts', version: '0.1.0' }, { instructions });
const provider = z.enum(['ipapi', 'cloudflare']);
async function result(operation) {
  try { return textResult(await operation()); }
  catch { return { ...textResult({ state: 'operation_unconfirmed', nextStep: 'Inspect the reviewed account page and local configuration. Do not repeat a signup or key lookup automatically.' }), isError: true }; }
}

server.registerTool('provider_account_status', {
  description: buildToolDescription('Read local credential and one-submit registration state without network access.', instructions), inputSchema: { provider },
}, ({ provider }) => result(() => accountStatus(provider)));
server.registerTool('provider_account_open', {
  description: buildToolDescription('Open one reviewed setup/recovery page. ipapi uses headless Chrome by default; visible=true requests its human recovery UI. Cloudflare retains headed Chrome because its headless dashboard returned HTTP 403. Routine account reads use HTTP instead.', instructions), inputSchema: { provider, surface: z.enum(['signup', 'login', 'dashboard', 'security']), visible: z.boolean().default(false) },
}, ({ provider, surface, visible }) => result(() => openAccount(provider, surface, visible)));
server.registerTool('provider_account_read', {
  description: buildToolDescription('Check the saved account identity over bounded HTTP without Chrome. mode=browser explicitly inspects the existing dedicated page for setup or login recovery.', instructions), inputSchema: { provider, mode: z.enum(['http', 'browser']).default('http') },
}, ({ provider, mode }) => result(() => readAccount(provider, mode)));
server.registerTool('provider_account_create_free', {
  description: buildToolDescription('Submit one reviewed free signup with privately generated credentials. Uses the configured private registration email. Human verification blocks submission.', instructions), inputSchema: { provider, country: z.enum(['Hong Kong', 'China']).optional(), confirmation: z.literal('CREATE_FREE_ACCOUNT') },
}, ({ provider, country, confirmation }) => result(() => createFreeAccount(provider, country, confirmation)));
server.registerTool('ipapi_import_free_key', {
  description: buildToolDescription('Import the one visible labelled ipapi API key directly to the reporter. Verifies the complete response with one free 1.1.1.1 lookup.', instructions), inputSchema: { confirmation: z.literal('IMPORT_FREE_API_KEY') },
}, ({ confirmation }) => result(() => importIpapiKey(confirmation)));

server.registerTool('public_provider_verify_free_api', {
  description: buildToolDescription('Verify DB-IP or IPWHOIS free geography with one fixed 1.1.1.1 lookup. public_demo checks IPWHOIS security for 1.1.1.1, or DB-IP risk for the requesting egress using its public page then one visitor lookup. The DB-IP public guest token stays in memory. Demos use website request headers; quotas are unspecified. No account, 2FA, paid trial or retries.', instructions), inputSchema: { provider: z.enum(['dbip', 'ipwhois']), surface: z.enum(['free_api', 'public_demo']).default('free_api'), confirmation: z.literal('VERIFY_FREE_API') },
}, ({ provider, surface, confirmation }) => result(() => verifyPublicProvider(provider, confirmation, undefined, surface)));

server.registerTool('cloudflare_account_check', {
  description: buildToolDescription('Verify the saved Cloudflare identity, email and 2FA state with one HTTP account read and private saved state. No Chrome and no Intel lookup; expired state requires explicit browser recovery.', instructions), inputSchema: {},
}, () => result(checkCloudflareAccount));
server.registerTool('cloudflare_prepare_intel_token', {
  description: buildToolDescription('Prepare and validate an account-scoped Intel Read token on the official dashboard without submitting it.', instructions), inputSchema: {},
}, () => result(prepareCloudflareToken));
server.registerTool('cloudflare_create_intel_token', {
  description: buildToolDescription('Submit the reviewed Intel Read token once and save it privately. Revalidates the exact account and permission; no broad token or retry.', instructions), inputSchema: { confirmation: z.literal('CREATE_INTEL_READ_TOKEN') },
}, ({ confirmation }) => result(() => createCloudflareToken(confirmation)));
server.registerTool('cloudflare_verify_free_api', {
  description: buildToolDescription('Use one free 1.1.1.1 Intel lookup to verify the saved token provides useful context. API usability must be established before 2FA.', instructions), inputSchema: { confirmation: z.literal('VERIFY_FREE_API') },
}, ({ confirmation }) => result(() => verifyCloudflareApi(confirmation)));
server.registerTool('cloudflare_enable_totp', {
  description: buildToolDescription('Enable Cloudflare TOTP only after fresh useful free API proof for the same account/token. Save the textual provisioning seed before one code/password submission; preserve any existing factor.', instructions), inputSchema: { confirmation: z.literal('ENABLE_TOTP') },
}, ({ confirmation }) => result(() => enableCloudflareTotp(confirmation)));
server.registerTool('cloudflare_save_recovery_codes', {
  description: buildToolDescription('Store the initial eight Cloudflare recovery codes privately after enabled TOTP proof, then acknowledge the saved codes. No download, printing, clipboard copy or recovery-code regeneration.', instructions), inputSchema: { confirmation: z.literal('SAVE_RECOVERY_CODES') },
}, ({ confirmation }) => result(() => saveCloudflareRecoveryCodes(confirmation)));

await server.connect(new StdioServerTransport());
