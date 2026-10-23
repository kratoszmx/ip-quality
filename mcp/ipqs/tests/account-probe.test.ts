import assert from "node:assert/strict";
import test from "node:test";

import { classifyIpqsAccountUsage } from "../src/account-policy.js";
import { probeIpqsAccount } from "../src/account-probe.js";

test("account classification needs HTTP 200 evidence; failures never prove authentication or credits", () => {
  const cases: [number, Record<string, unknown>, string][] = [
    [200, { success: true, requests: 10 }, "authenticated"],
    [200, { success: false, message: "You have insufficient credits to make this query." }, "authenticated_without_credits"],
    [200, { success: true, credits: 0, usage: 0 }, "authenticated_without_credits"],
    [200, { message: "insufficient credits" }, "inconclusive"],
    [200, {}, "inconclusive"],
    [401, { success: false, message: "Invalid or unauthorized key." }, "login_required"],
    [403, { success: false, message: "Account verification required." }, "verification_required"],
    [429, { success: false, message: "Too many requests." }, "rate_limited"],
    [503, {}, "unavailable"],
  ];
  // Error statuses win over misleading success or credit bodies.
  for (const data of [{ success: true, credits: 1000 }, { success: false, message: "You have insufficient credits to make this query." }]) {
    for (const [httpStatus, expected] of [[401, "login_required"], [403, "login_required"], [429, "rate_limited"],
      [503, "unavailable"], [302, "inconclusive"], [0, "inconclusive"]] as const) {
      cases.push([httpStatus, data, expected]);
    }
  }
  for (const [httpStatus, data, expected] of cases) {
    assert.equal(classifyIpqsAccountUsage({ httpStatus, data }), expected, `${httpStatus} ${JSON.stringify(data)}`);
  }
});

test("returns fixed secret-free readiness outcomes and performs at most one account read", async () => {
  let reads = 0;
  const missing = await probeIpqsAccount({
    inspectCredential: async () => ({ configured: false, usable: false }),
    readAccountUsage: async () => {
      reads += 1;
      throw new Error("must not run");
    },
  });
  assert.deepEqual(missing, { schema_version: 1, outcome: "missing_credentials" });
  assert.equal(reads, 0);

  const accepted = await probeIpqsAccount({
    inspectCredential: async () => ({ configured: true, usable: true }),
    readAccountUsage: async () => {
      reads += 1;
      return {
        httpStatus: 200,
        data: {
          success: false,
          message: "You have insufficient credits to make this query.",
          api_key: "syntheticApiKey1234567890",
          email: "owner@example.test",
        },
      };
    },
  });
  assert.deepEqual(accepted, { schema_version: 1, outcome: "authenticated_without_credits" });
  assert.equal(reads, 1);
  assert.equal(JSON.stringify(accepted).includes("syntheticApiKey"), false);
  assert.equal(JSON.stringify(accepted).includes("owner@example.test"), false);
});

test("collapses local and network failures without exposing error text", async () => {
  const localFailure = await probeIpqsAccount({
    inspectCredential: async () => {
      throw new Error("private local path");
    },
    readAccountUsage: async () => ({ httpStatus: 200, data: { success: true } }),
  });
  assert.deepEqual(localFailure, { schema_version: 1, outcome: "unavailable" });

  const networkFailure = await probeIpqsAccount({
    inspectCredential: async () => ({ configured: true, usable: true }),
    readAccountUsage: async () => {
      throw new Error("private upstream response");
    },
  });
  assert.deepEqual(networkFailure, { schema_version: 1, outcome: "unavailable" });
});
