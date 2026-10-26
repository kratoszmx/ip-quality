import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { buildToolDescription, textResult } from '@myutils/mcp-server';
import { accountStatus, openAccount, readAccount, createFreeAccount, importIpapiKey, closeAccountBrowsers } from './accounts.mjs';
import { abuseipdbStatus, verifyAbuseipdb, openAbuseipdb } from './abuseipdb.mjs';
import { prepareCloudflareToken, createCloudflareToken, verifyCloudflareApi } from './cloudflare.mjs';
import { enableCloudflareTotp, saveCloudflareRecoveryCodes } from './cloudflare-totp.mjs';
import { verifyPublicProvider } from './public-api.mjs';
import { loginAccount } from './login.mjs';

const instructions = 'IPQuality provider accounts. Dedicated ipapi/Cloudflare/AbuseIPDB profiles only. Free accounts only; no billing or plan upgrade tools. Account creation needs task authorization and CREATE_FREE_ACCOUNT. Stop for human verification; never solve CAPTCHA. Store secrets privately and never return keys, passwords, OTPs, recovery codes or cookies. A saved file is not live authentication. No automatic signup or lookup retries.';
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
  description: buildToolDescription('Open one reviewed page in native hidden Chrome with no OS window. Routine reads use HTTP. visible=true requires explicit human-recovery intent; never open a GUI automatically.', instructions), inputSchema: { provider, surface: z.enum(['signup', 'login', 'dashboard', 'security']), visible: z.boolean().default(false) },
}, ({ provider, surface, visible }) => result(() => openAccount(provider, surface, visible)));
server.registerTool('provider_account_read', {
  description: buildToolDescription('Check the saved account identity over bounded HTTP without Chrome. mode=browser explicitly inspects the existing dedicated page for setup or login recovery.', instructions), inputSchema: { provider, mode: z.enum(['http', 'browser']).default('http') },
}, ({ provider, mode }) => result(() => readAccount(provider, mode)));
server.registerTool('provider_account_login', {
  description: buildToolDescription('Cloudflare/AbuseIPDB: one authorized saved-credential login without a window, reusing HTTP state first. Stops for verification; no automatic GUI or password retry. ipapi automated login is disabled after its bot_login suspension; use read for existing HTTP state. Saves state only after exact account proof.', instructions),
  inputSchema: { provider: z.enum(['ipapi', 'cloudflare', 'abuseipdb']), confirmation: z.literal('USE_SAVED_ACCOUNT_CREDENTIALS') },
}, ({ provider, confirmation }) => result(() => loginAccount(provider, confirmation)));
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
}, () => result(() => readAccount('cloudflare')));
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

server.registerTool('abuseipdb_account_status', {
  description: buildToolDescription('Inspect private AbuseIPDB account/key presence without network access. Saved files do not prove a live account or quota.', instructions), inputSchema: {},
}, () => result(abuseipdbStatus));
server.registerTool('abuseipdb_account_check', {
  description: buildToolDescription('Read the exact saved AbuseIPDB account over HTTP, without Chrome. Returns authentication, email-verification and public-profile setting booleans only. Does not change settings or submit abuse reports.', instructions), inputSchema: {},
}, () => result(() => readAccount('abuseipdb')));
server.registerTool('abuseipdb_verify_free_api', {
  description: buildToolDescription('Read the official AbuseIPDB APIv2 CHECK endpoint for 1.1.1.1 once. Uses the private owned key and native HTTP. Returns only validated public observations; no abuse report, key, account identity or browser state.', instructions), inputSchema: { confirmation: z.literal('VERIFY_FREE_API') },
}, ({ confirmation }) => result(() => verifyAbuseipdb(confirmation)));
server.registerTool('abuseipdb_account_open', {
  description: buildToolDescription('Open the reviewed AbuseIPDB page in windowless native Chrome, without submission. visible=true explicitly requests human recovery. Routine queries use HTTP.', instructions), inputSchema: { surface: z.enum(['signup', 'login']), visible: z.boolean().default(false) },
}, ({ surface, visible }) => result(() => openAbuseipdb(surface, visible)));

server.registerTool('provider_account_close_browsers', {
  description: buildToolDescription('Close only the temporary browsers owned by this MCP; preserve the private saved login state.', instructions), inputSchema: {},
}, () => result(closeAccountBrowsers));

server.server.onclose = () => { void closeAccountBrowsers().catch(() => {}); };
await server.connect(new StdioServerTransport());
