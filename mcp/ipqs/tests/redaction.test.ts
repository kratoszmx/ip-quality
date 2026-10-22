import assert from "node:assert/strict";
import test from "node:test";

import { redactStructured, redactText } from "@myutils/redaction";
import { boundedVisibleText, sanitizedError } from "../src/redaction.js";

test("redacts dashboard credentials and account identifiers", () => {
  const key = "syntheticApiKey1234567890";
  const text = redactText(`Email owner@example.test API Key ${key} Authorization Bearer private-token`, { secrets: [key] });
  assert.equal(text.includes("owner@example.test"), false);
  assert.equal(text.includes(key), false);
  assert.equal(text.includes("private-token"), false);
  assert.match(text, /\[redacted email\]/);
  assert.match(text, /\[redacted\]/);

  const structured = redactStructured({ api_key: key, request_id: "request-123", nested: { token: key } }) as any;
  assert.equal(structured.api_key, "[redacted]");
  assert.equal(structured.nested.token, "[redacted]");
  assert.equal(structured.request_id, "request-123");
  assert.equal(boundedVisibleText(`  line one  \n\n ${key} `, 200).includes(key), false);
  assert.equal(boundedVisibleText("a  \t b\n\n\n c", 200), "a b\n\nc");
  assert.equal(sanitizedError(new Error(`failed for owner@example.test`)), "failed for [redacted email]");
  assert.equal(sanitizedError(new Error("")), "IPQS operation failed.");
});
