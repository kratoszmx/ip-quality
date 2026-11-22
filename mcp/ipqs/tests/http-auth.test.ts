import assert from "node:assert/strict";
import test from "node:test";
import { httpAuthStatus } from "../src/http-auth.js";

test("HTTP login proof requires a real logout link without login or TOTP form", () => {
  const logout = '<a href="/user/logout">Logout</a>';
  assert.equal(httpAuthStatus(200, "text/html; charset=utf-8", logout).authenticated, true);
  for (const body of [
    `<script>${logout}</script>`, `<!-- ${logout} -->`, `<template>${logout}</template>`,
    `<div hidden>${logout}</div>`, `<div aria-hidden="true">${logout}</div>`,
    `<section inert>${logout}</section>`, `<div style="display:none">${logout}</div>`,
    '<a data-href="/user/logout">Logout</a>', '<p title=\'<a href="/logout">\'>Loading</p>',
    '<a href="https://foreign.invalid/logout">Logout</a>',
    `${logout}<form action="/login/submit"></form>`,
    `${logout}<input name="2fa">`, 'Account Dashboard Credits',
  ]) assert.equal(httpAuthStatus(200, "text/html", body).authenticated, false);
  for (const status of [302, 401, 403, 429, 500]) assert.equal(httpAuthStatus(status, "text/html", logout).authenticated, false);
  assert.equal(httpAuthStatus(200, "application/json", logout).authenticated, false);
  assert.equal(httpAuthStatus(200, "text/html", logout + '<div hidden><input name="2fa"></div>').stage, "authenticated");
});

test("the Svelte dashboard's inline account object proves login; look-alikes do not", () => {
  const account = 'globalThis.staticUser = { newsletters: true, id: 4242, isAdmin: 0 === 1, firstName: "A {b}", email: "owner@example.test", rank: userRank, settings: { id: 1 } };';
  const shell = (script: string) => `<title>Dashboard</title><script>globalThis.isSvelteApp = true;</script>${script}<div id="app"></div>`;
  assert.deepEqual(httpAuthStatus(200, "text/html; charset=UTF-8", shell(`<script>${account}</script>`)),
    { authenticated: true, stage: "authenticated", backend: "http", httpStatus: 200 });
  for (const body of [
    shell(""), shell(`<!-- <script>${account}</script> -->`), shell(`<template><script>${account}</script></template>`),
    shell(`<noscript><script>${account}</script></noscript>`), shell(`<script type="application/json">${account}</script>`),
    shell(`<script src="/app.js">${account}</script>`), shell(`<p>${account}</p>`),
    shell("<script>globalThis.staticUser = null;</script>"),
    shell('<script>globalThis.staticUser = { id: 0, email: "owner@example.test" };</script>'),
    shell('<script>globalThis.staticUser = { id: 4242, email: null };</script>'),
    shell('<script>globalThis.staticUser = { name: "x" }; globalThis.other = { id: 4242, email: "owner@example.test" };</script>'),
    shell(`<script>${account}</script><form action="/login/submit"></form>`),
    shell(`<script>${account}</script><input name="2fa">`),
  ]) assert.equal(httpAuthStatus(200, "text/html", body).authenticated, false, body);
  assert.equal(httpAuthStatus(302, "text/html", shell(`<script>${account}</script>`)).stage, "login");
});
