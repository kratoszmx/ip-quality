import assert from "node:assert/strict";
import test from "node:test";

import { boundedVisibleText, redactStructured, redactText } from "../src/redaction.js";

test("redacts dashboard credentials and account identifiers", () => {
  const key = "syntheticApiKey1234567890";
  const text = redactText(`Email owner@example.test API Key ${key} Authorization Bearer private-token`, [key]);
  assert.equal(text.includes("owner@example.test"), false);
  assert.equal(text.includes(key), false);
  assert.equal(text.includes("private-token"), false);
  assert.match(text, /<redacted-email>/);
  assert.match(text, /<redacted-secret>/);

  const structured = redactStructured({ api_key: key, request_id: "request-123", nested: { token: key } }) as any;
  assert.equal(structured.api_key, "<redacted-secret>");
  assert.equal(structured.nested.token, "<redacted-secret>");
  assert.equal(structured.request_id, "request-123");
  assert.equal(boundedVisibleText(`  line one  \n\n ${key} `, 200).includes(key), false);
});
