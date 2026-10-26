const PROVIDERS = Object.freeze({
  ipapi: { origin: 'https://ipapi.is', signup: '/app/signup', login: '/app/', dashboard: '/app/home', security: null, port: 19503, passwordField: 'pass', signupButton: 'Create Free Account' },
  cloudflare: { origin: 'https://dash.cloudflare.com', signup: '/sign-up', login: '/login', dashboard: '/', security: '/profile/authentication', port: 19504, passwordField: 'password', signupButton: 'Sign up' },
  abuseipdb: { origin: 'https://www.abuseipdb.com', signup: '/register', login: '/login', dashboard: '/account', security: null, port: 19505, passwordField: 'password', signupButton: 'REGISTER' },
});

export function providerConfig(provider) {
  if (!Object.hasOwn(PROVIDERS, provider)) throw new Error('Unknown provider.');
  return PROVIDERS[provider];
}

export function accountNetworkOptions(environment = process.env) {
  const value = environment.PROVIDER_ACCOUNTS_PROXY || environment.HTTPS_PROXY || environment.https_proxy;
  if (value === 'DIRECT' || !value) return { proxyServer: undefined };
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.pathname !== '/' || url.search || url.hash) throw new Error('Invalid credential-free proxy URL.');
  return { proxyServer: value };
}

export function accountUrl(provider, surface) {
  const config = providerConfig(provider);
  if (!['signup', 'login', 'dashboard', 'security'].includes(surface)) throw new Error('Unknown account surface.');
  if (!config[surface]) throw new Error('This provider has no verified account surface for that action.');
  return new URL(config[surface], config.origin).href;
}

export function assertAccountOrigin(provider, value) {
  const url = new URL(value);
  if (url.origin !== providerConfig(provider).origin || url.username || url.password) throw new Error('Untrusted account origin.');
}


export function accountPagePath(provider, value) {
  assertAccountOrigin(provider, value);
  return new URL(value).pathname.replace(/\b[a-f0-9]{32}\b/gi, '[private account]');
}

export function classifyAccountPage({ text, hasPassword, challenge, termsRequired = false, authenticatedAccount = false, allowTextAuthentication = true, submitted = false }) {
  if (challenge) return 'human_verification_required';
  if (termsRequired) return 'terms_acceptance_required';
  if (/your account has been banned|your account was suspended/i.test(text)) return 'account_suspended';
  if (/could not complete your registration from this connection/i.test(text)) return 'registration_connection_blocked';
  if (/verify (?:your )?email|verification (?:email|link)|confirm (?:your )?email|check your inbox|account is not activated|activation link|activate your account/i.test(text)) return 'email_verification_required';
  if (/already (?:registered|exists)|email.*(?:taken|in use)/i.test(text)) return 'existing_account';
  if (/invalid|incorrect|error|could not|unable to/i.test(text)) return 'unconfirmed';
  if (hasPassword) return submitted ? 'submission_unconfirmed' : 'login_or_signup';
  if (authenticatedAccount) return 'authenticated';
  if (allowTextAuthentication && /log\s*out|sign\s*out/i.test(text) && /dashboard|API key|account/i.test(text)) return 'authenticated';
  return 'unconfirmed';
}

export function ipapiDashboardAccepted(value, expectedEmail) {
  try {
    assertAccountOrigin('ipapi', value.url);
    assertAccountOrigin('ipapi', value.logoutUrl);
    return new URL(value.url).pathname === PROVIDERS.ipapi.dashboard &&
      new URL(value.logoutUrl).pathname === '/app/logout' &&
      typeof expectedEmail === 'string' && expectedEmail.length > 0 &&
      value.email === expectedEmail && value.keyCount === 1 && !value.hasPassword;
  } catch { return false; }
}

export function validApiKey(value) {
  return typeof value === 'string' && /^[A-Za-z0-9_.-]{8,256}$/.test(value);
}

export function ipapiKeyAccepted(status, value, ip) {
  return status === 200 && value?.ip === ip && value.error == null && value.error_code == null && value.docs == null &&
    typeof value.company === 'object' && value.company !== null && !Array.isArray(value.company) && typeof value.is_proxy === 'boolean';
}
