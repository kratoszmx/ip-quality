import assert from "node:assert/strict";
import test from "node:test";

import { classifyIpqsAuthSignals } from "../src/auth.js";

test("HTTP 200 dashboard URL containing the exact login form is expired authentication", () => {
  const signals = { trustedOrigin: true, path: "/user/dashboard", authenticatedMarkerCount: 0,
    loginFormPresent: true, secondaryVerification: false, credentialError: false };
  assert.equal(classifyIpqsAuthSignals(signals), "login");
  assert.equal(classifyIpqsAuthSignals({ ...signals, authenticatedMarkerCount: 3 }), "login");
  assert.equal(classifyIpqsAuthSignals({ ...signals, trustedOrigin: false }), "unknown");
  assert.equal(classifyIpqsAuthSignals({ ...signals, secondaryVerification: true }), "secondary-verification");
});

test("IPQS authentication classification distinguishes login forms from password settings", () => {
  assert.equal(classifyIpqsAuthSignals({
    trustedOrigin: true,
    path: "/login",
    authenticatedMarkerCount: 0,
    loginFormPresent: true,
    secondaryVerification: false,
    credentialError: false,
  }), "login");

  assert.equal(classifyIpqsAuthSignals({
    trustedOrigin: true,
    path: "/user/settings",
    authenticatedMarkerCount: 6,
    loginFormPresent: false,
    secondaryVerification: false,
    credentialError: false,
  }), "authenticated");

  assert.equal(classifyIpqsAuthSignals({
    trustedOrigin: false,
    path: "/user/settings",
    authenticatedMarkerCount: 6,
    loginFormPresent: false,
    secondaryVerification: false,
    credentialError: false,
  }), "unknown");
});

test("IPQS authentication classification surfaces human verification and credential errors", () => {
  assert.equal(classifyIpqsAuthSignals({
    trustedOrigin: true,
    path: "/login",
    authenticatedMarkerCount: 0,
    loginFormPresent: false,
    secondaryVerification: true,
    credentialError: false,
  }), "secondary-verification");
  assert.equal(classifyIpqsAuthSignals({
    trustedOrigin: true,
    path: "/login",
    authenticatedMarkerCount: 0,
    loginFormPresent: true,
    secondaryVerification: false,
    credentialError: true,
  }), "credential-error");
});
