import assert from "node:assert/strict";
import test from "node:test";

import { classifyIpqsAuthSignals } from "../src/auth.js";

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
