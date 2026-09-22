export const PROVIDERS = Object.freeze({
  ipapi: { origin: 'https://ipapi.is', signup: '/app/signup', login: '/app/', dashboard: '/app/dashboard', security: '/app/settings', port: 19503, passwordField: 'pass', signupButton: 'Create Free Account' },
  cloudflare: { origin: 'https://dash.cloudflare.com', signup: '/sign-up', login: '/login', dashboard: '/', security: '/profile/authentication', port: 19504, passwordField: 'password', signupButton: 'Sign up' },
});

export function providerConfig(provider) {
  if (!Object.hasOwn(PROVIDERS, provider)) throw new Error('Unknown provider.');
  return PROVIDERS[provider];
}

export function accountUrl(provider, surface) {
  const config = providerConfig(provider);
  if (!['signup', 'login', 'dashboard', 'security'].includes(surface)) throw new Error('Unknown account surface.');
  return new URL(config[surface], config.origin).href;
}

export function assertAccountOrigin(provider, value) {
  const url = new URL(value);
  if (url.origin !== providerConfig(provider).origin || url.username || url.password) throw new Error('Untrusted account origin.');
}

export function redactAccountText(text, secrets = []) {
  let value = String(text);
  for (const secret of secrets.filter(Boolean).sort((a, b) => b.length - a.length)) value = value.split(secret).join('[private]');
  return value.replace(/otpauth:\/\/\S+/gi, '[private TOTP]')
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[private email]')
    .replace(/\b[A-Za-z0-9_-]{16,}\b/g, '[private value]')
    .replace(/\b(?:\d[ -]?){6,}\b/g, '[private number]')
    .slice(0, 6000);
}

export function accountPagePath(provider, value) {
  assertAccountOrigin(provider, value);
  return new URL(value).pathname.replace(/\b[a-f0-9]{32}\b/gi, '[private account]');
}

export function classifyAccountPage({ text, hasPassword, challenge, submitted = false }) {
  if (challenge) return 'human_verification_required';
  if (/could not complete your registration from this connection/i.test(text)) return 'registration_connection_blocked';
  if (/verify (?:your )?email|verification (?:email|link)|confirm (?:your )?email|check your inbox/i.test(text)) return 'email_verification_required';
  if (/already (?:registered|exists)|email.*(?:taken|in use)/i.test(text)) return 'existing_account';
  if (/invalid|incorrect|error|could not|unable to/i.test(text)) return 'unconfirmed';
  if (hasPassword) return submitted ? 'submission_unconfirmed' : 'login_or_signup';
  if (/log\s*out|sign\s*out/i.test(text) && /dashboard|API key|account/i.test(text)) return 'authenticated';
  return 'unconfirmed';
}

export function validApiKey(value) {
  return typeof value === 'string' && /^[A-Za-z0-9_.-]{8,256}$/.test(value);
}

export function ipapiKeyAccepted(status, value, ip) {
  return status === 200 && value?.ip === ip && !value.error && !value.docs &&
    typeof value.company === 'object' && value.company !== null && typeof value.is_proxy === 'boolean';
}
