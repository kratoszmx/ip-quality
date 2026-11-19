import assert from "node:assert/strict";
import test from "node:test";
import { runInNewContext } from "node:vm";

import { classifyIpqsAuthSignals, inspectIpqsAuthPage } from "../src/auth.js";
import type { Page } from "playwright-core";

const base = { trustedOrigin: true, path: "/login", authenticatedMarkerCount: 0, loginFormPresent: false,
  secondaryVerification: false, credentialError: false, totpChallengePresent: false };

test("IPQS authentication needs trusted dashboard markers and never ignores login, MFA or errors", () => {
  const cases: [Partial<typeof base>, string][] = [
    [{ loginFormPresent: true }, "login"],
    [{ path: "/user/settings", authenticatedMarkerCount: 6 }, "authenticated"],
    [{ path: "/user/settings", authenticatedMarkerCount: 6, trustedOrigin: false }, "unknown"],
    // An HTTP 200 dashboard URL that renders the exact login form is expired authentication.
    [{ path: "/user/dashboard", loginFormPresent: true }, "login"],
    [{ path: "/user/dashboard", loginFormPresent: true, authenticatedMarkerCount: 3 }, "login"],
    [{ path: "/user/dashboard", loginFormPresent: true, trustedOrigin: false }, "unknown"],
    [{ path: "/user/dashboard", loginFormPresent: true, secondaryVerification: true }, "secondary-verification"],
    [{ secondaryVerification: true }, "secondary-verification"],
    [{ loginFormPresent: true, credentialError: true }, "credential-error"],
    // MFA challenges cannot become authenticated because dashboard navigation is present.
    [{ path: "/user/settings", authenticatedMarkerCount: 5, totpChallengePresent: true }, "secondary-verification"],
  ];
  for (const [change, expected] of cases) {
    assert.equal(classifyIpqsAuthSignals({ ...base, ...change }), expected, JSON.stringify(change));
  }
});

test("a completed browser check does not require human action while TOTP remains independently pending", async () => {
  for (const [body, value, expected] of [
    ['Protected by CAPTCHA', 'synthetic-response', 'unknown'],
    ['Verify you are not a robot', '', 'secondary-verification'],
    ['Protected by CAPTCHA. Enter your authenticator verification code.', 'synthetic-response', 'secondary-verification'],
  ]) {
    const page = { url: () => 'https://www.ipqualityscore.com/login',
      evaluate: async (project: (...args: any[]) => any, args: unknown) => runInNewContext(`(${project.toString()})(args)`, {
        args, document: { title: 'IPQS', body: { innerText: body }, forms: [], querySelector: () => null,
          querySelectorAll: () => [{ value }] },
      }),
    } as unknown as Page;
    const result = await inspectIpqsAuthPage(page);
    assert.equal(result.stage, expected);
    assert.equal(JSON.stringify(result).includes('synthetic-response'), false);
  }
});
