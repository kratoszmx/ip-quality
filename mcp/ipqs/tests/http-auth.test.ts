import assert from "node:assert/strict";
import test from "node:test";
import { httpAuthStatus } from "../src/http-auth.js";

test("HTTP login proof requires a real logout link without login or TOTP form", () => {
  const logout = '<a href="/user/logout">Logout</a>';
  assert.equal(httpAuthStatus(200, "text/html; charset=utf-8", logout).authenticated, true);
  for (const body of [
    `<script>${logout}</script>`, `<!-- ${logout} -->`, `<template>${logout}</template>`,
    '<a href="https://foreign.invalid/logout">Logout</a>',
    `${logout}<form action="/login/submit"></form>`,
    `${logout}<input name="2fa">`, 'Account Dashboard Credits',
  ]) assert.equal(httpAuthStatus(200, "text/html", body).authenticated, false);
  for (const status of [302, 401, 403, 429, 500]) assert.equal(httpAuthStatus(status, "text/html", logout).authenticated, false);
  assert.equal(httpAuthStatus(200, "application/json", logout).authenticated, false);
});
