export function intelReadPolicy(payload, accountId, permissionId) {
  if (!/^[a-f0-9]{32}$/.test(accountId) || !/^[a-f0-9]{32}$/.test(permissionId)) return false;
  if (payload?.name !== 'IPQuality Intel Read' || !Array.isArray(payload.policies) || payload.policies.length !== 1) return false;
  const policy = payload.policies[0];
  return policy?.effect === 'allow' && Array.isArray(policy.permission_groups) &&
    policy.permission_groups.length === 1 && policy.permission_groups[0]?.id === permissionId &&
    policy.resources && Object.keys(policy.resources).length === 1 &&
    policy.resources[`com.cloudflare.api.account.${accountId}`] === '*' &&
    (payload.condition == null || (typeof payload.condition === 'object' && !Array.isArray(payload.condition) && Object.keys(payload.condition).length === 0)) &&
    payload.not_before == null && payload.expires_on == null;
}

export function cloudflareIdentity(status, body, expectedEmail) {
  const authenticated = status === 200 && body?.success === true &&
    typeof expectedEmail === 'string' && expectedEmail.includes('@') && body.result?.email === expectedEmail &&
    body.result?.suspended === false;
  return { authenticated, emailVerified: authenticated && body.result.email_verified === true,
    twoFactorEnabled: authenticated && body.result.two_factor_authentication_enabled === true,
    totpConfigured: authenticated && body.result.totp_configured === true };
}

export function cloudflareApiUsable(status, body, expectedIp) {
  if (status !== 200 || body?.success !== true || !Array.isArray(body.result) || body.result.length !== 1) return false;
  const result = body.result[0];
  return result?.ip === expectedIp && result.belongs_to_ref != null &&
    typeof result.belongs_to_ref === 'object' && !Array.isArray(result.belongs_to_ref) &&
    ((typeof result.belongs_to_ref.value === 'string' && result.belongs_to_ref.value.length > 0) ||
      (Number.isInteger(result.belongs_to_ref.value) && result.belongs_to_ref.value >= 1 && result.belongs_to_ref.value <= 4294967295)) &&
    (result.risk_types == null || (Array.isArray(result.risk_types) && result.risk_types.every(item => item && typeof item.name === 'string')));
}

export function usableBeforeMfa(proof, keyFingerprint, accountId, now = Date.now()) {
  const checked = Date.parse(proof?.checkedAt);
  return proof?.provider === 'cloudflare' && proof.usable === true &&
    proof.keyFingerprint === keyFingerprint && proof.accountId === accountId &&
    Number.isFinite(checked) && now >= checked && now - checked <= 30 * 60 * 1000;
}
