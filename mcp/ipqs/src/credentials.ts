import { readdir } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";

import {
  inspectPrivateTwoLineSecretBundle,
  parseTwoLineSecretBundle,
  readPrivateTwoLineSecretBundle,
} from "@codex-mcp/shared-secret-file";

export const IPQS_ACCOUNT_SECRET_DIR = path.resolve(
  homedir(),
  "codexworkspace",
  "secrets",
  "infrastructure",
  "network",
  "ipqs",
);

const EMAIL_POLICY = {
  minBytes: 3,
  maxBytes: 320,
  validate: (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/u.test(value),
};

const PASSWORD_POLICY = {
  minBytes: 1,
  maxBytes: 1_024,
  validate: (value: string) => !/[\u0000\r\n]/u.test(value),
};

const BUNDLE_POLICY = {
  first: EMAIL_POLICY,
  second: PASSWORD_POLICY,
};

export function parseIpqsCredentialBundle(value: string) {
  const parsed = parseTwoLineSecretBundle(value, BUNDLE_POLICY);
  return parsed ? { email: parsed.first, password: parsed.second } : null;
}

type BundleDiscovery =
  | { ok: true; file: string }
  | { ok: false; reason: "missing" | "directory-layout-invalid" | "unsafe-or-inaccessible" };

async function discoverCredentialBundle(directory: string): Promise<BundleDiscovery> {
  const normalized = path.resolve(directory);
  try {
    const entries = await readdir(normalized, { withFileTypes: true });
    if (entries.length !== 1 || !entries[0].isFile()) {
      return { ok: false, reason: "directory-layout-invalid" };
    }
    return { ok: true, file: path.join(normalized, entries[0].name) };
  } catch (error) {
    if ((error as NodeJS.ErrnoException)?.code === "ENOENT") return { ok: false, reason: "missing" };
    return { ok: false, reason: "unsafe-or-inaccessible" };
  }
}

export async function inspectIpqsCredentials(directory = IPQS_ACCOUNT_SECRET_DIR) {
  const discovered = await discoverCredentialBundle(directory);
  if (!discovered.ok) {
    return {
      ready: false,
      layout: "fixed central IPQS directory with exactly one owner-only email/password bundle",
      bundle: { exists: false, usable: false, reason: discovered.reason },
    };
  }
  const state = await inspectPrivateTwoLineSecretBundle(discovered.file, BUNDLE_POLICY);
  return {
    ready: state.usable,
    layout: "fixed central IPQS directory with exactly one owner-only email/password bundle",
    bundle: {
      exists: state.exists,
      usable: state.usable,
      ...(state.reason ? { reason: state.reason } : {}),
    },
  };
}

export async function readIpqsCredentials(directory = IPQS_ACCOUNT_SECRET_DIR) {
  const discovered = await discoverCredentialBundle(directory);
  if (!discovered.ok) {
    throw new Error("Saved IPQS credential bundle is missing or its fixed directory layout is invalid.");
  }
  try {
    const value = await readPrivateTwoLineSecretBundle(discovered.file, BUNDLE_POLICY);
    return { email: value.first, password: value.second };
  } catch {
    throw new Error(
      "Saved IPQS credential bundle is invalid or not owner-only. Expected one mode-0600 two-line file inside the mode-0700 central IPQS directory.",
    );
  }
}
