import assert from "node:assert/strict";
import { mkdtemp, realpath, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { writePrivateSecretFile } from "@codex-mcp/shared-secret-file";

import {
  inspectIpqsCredentials,
  parseIpqsCredentialBundle,
  readIpqsCredentials,
} from "../src/credentials.js";

test("IPQS credentials use one owner-only positional bundle without exposing its filename or fingerprint", async () => {
  const root = await realpath(await mkdtemp(path.join(tmpdir(), "ipqs-credentials-")));
  const directory = path.join(root, "ipqs");
  try {
    await writePrivateSecretFile(
      path.join(directory, "synthetic-account-record"),
      "agent@example.test\nfixture-password",
      { minBytes: 3, maxBytes: 2048 },
    );
    const inspection = await inspectIpqsCredentials(directory);
    assert.equal(inspection.ready, true);
    assert.deepEqual(inspection.bundle, { exists: true, usable: true });
    assert.equal(JSON.stringify(inspection).includes("sha256:"), false);
    assert.equal(JSON.stringify(inspection).includes("synthetic-account-record"), false);
    assert.deepEqual(await readIpqsCredentials(directory), {
      email: "agent@example.test",
      password: "fixture-password",
    });
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("IPQS credential parser accepts one terminal newline and rejects ambiguous content", () => {
  assert.deepEqual(parseIpqsCredentialBundle("agent@example.test\nfixture-password\n"), {
    email: "agent@example.test",
    password: "fixture-password",
  });
  assert.equal(parseIpqsCredentialBundle("only-one-line"), null);
  assert.equal(parseIpqsCredentialBundle("not-an-email\nfixture-password"), null);
  assert.equal(parseIpqsCredentialBundle("agent@example.test\npassword\nthird-line"), null);
});
