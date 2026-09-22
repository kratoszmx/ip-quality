import { getIpqsAccountUsage } from "./api.js";
import { classifyIpqsAccountUsage, type AccountUsageResult, type IpqsAccountOutcome } from "./account-policy.js";
import { inspectApiCredential } from "./config.js";

export type IpqsAccountProbeOutcome =
  | IpqsAccountOutcome
  | "missing_credentials"
  | "credential_unusable";

export interface IpqsAccountProbeResult {
  schema_version: 1;
  outcome: IpqsAccountProbeOutcome;
}

interface CredentialReadiness {
  configured?: unknown;
  usable?: unknown;
}

interface IpqsAccountProbeDependencies {
  inspectCredential: () => Promise<CredentialReadiness>;
  readAccountUsage: () => Promise<AccountUsageResult>;
}

const DEFAULT_DEPENDENCIES: IpqsAccountProbeDependencies = {
  inspectCredential: inspectApiCredential,
  readAccountUsage: getIpqsAccountUsage,
};

function result(outcome: IpqsAccountProbeOutcome): IpqsAccountProbeResult {
  return { schema_version: 1, outcome };
}

export async function probeIpqsAccount(
  dependencies: IpqsAccountProbeDependencies = DEFAULT_DEPENDENCIES,
): Promise<IpqsAccountProbeResult> {
  let credential: CredentialReadiness;
  try {
    credential = await dependencies.inspectCredential();
  } catch {
    return result("unavailable");
  }
  if (credential.configured !== true) return result("missing_credentials");
  if (credential.usable !== true) return result("credential_unusable");

  try {
    return result(classifyIpqsAccountUsage(await dependencies.readAccountUsage()));
  } catch {
    return result("unavailable");
  }
}
