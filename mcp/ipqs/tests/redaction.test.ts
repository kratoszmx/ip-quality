import assert from "node:assert/strict";
import test from "node:test";

import { boundedVisibleText, sanitizedError } from "../src/redaction.js";

// Shared redaction rules are tested in @myutils/redaction; this covers the
// IPQS presentation layer on top of them.
test("dashboard text and errors stay redacted, normalized and bounded", () => {
  const key = "syntheticApiKey1234567890";
  assert.equal(boundedVisibleText(`  line one  \n\n ${key} `, 200).includes(key), false);
  assert.equal(boundedVisibleText("a  \t b\n\n\n c", 200), "a b\n\nc");
  assert.equal(boundedVisibleText("abcdef", 3), "abc");
  assert.equal(sanitizedError(new Error("failed for owner@example.test")), "failed for [redacted email]");
  assert.equal(sanitizedError("word ".repeat(150)).length, 500);
  assert.equal(sanitizedError(new Error("")), "IPQS operation failed.");
});
