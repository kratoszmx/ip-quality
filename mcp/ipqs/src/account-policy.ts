export type IpqsAccountOutcome =
  | "authenticated"
  | "authenticated_without_credits"
  | "login_required"
  | "rate_limited"
  | "verification_required"
  | "inconclusive"
  | "unavailable";

export interface AccountUsageResult {
  httpStatus?: unknown;
  data?: unknown;
}

// IPQS account semantics belong here, not in the platform-neutral shared helpers.
export function classifyIpqsAccountUsage(value: AccountUsageResult): IpqsAccountOutcome {
  const data = value.data && typeof value.data === "object" && !Array.isArray(value.data)
    ? value.data as Record<string, unknown>
    : {};
  const message = typeof data.message === "string" ? data.message : "";
  const status = typeof value.httpStatus === "number" ? value.httpStatus : 0;

  // An HTTP failure cannot prove credential acceptance, whatever its body says.
  if (status === 429) return "rate_limited";
  if (status >= 500 && status <= 599) return "unavailable";
  if ((status === 403 || status === 200) && /verification|required.*verify|captcha/i.test(message)) {
    return "verification_required";
  }
  if (status === 401 || status === 403) return "login_required";
  if (status !== 200) return "inconclusive";
  if (/rate[ -]?limit|too many requests/i.test(message)) return "rate_limited";
  if (/invalid|unauthori[sz]ed/i.test(message)) return "login_required";
  if (data.success === true) {
    return data.credits === 0 ? "authenticated_without_credits" : "authenticated";
  }
  if (data.success === false && /insufficient\s+credits/i.test(message)) {
    return "authenticated_without_credits";
  }
  return "inconclusive";
}
