import { constants as fsConstants, existsSync } from "node:fs";
import { lstat, open } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

import { ensurePrivateDirectoryStrict } from "@codex-mcp/shared-browser-session";
import { fingerprintSecret, inspectPrivateSecretFile, readPrivateSecretFile } from "@codex-mcp/shared-secret-file";

function findPackageRoot(startDir: string) {
  let directory = startDir;
  for (;;) {
    if (existsSync(path.join(directory, "package.json"))) return directory;
    const parent = path.dirname(directory);
    if (parent === directory) return startDir;
    directory = parent;
  }
}

export const ROOT = findPackageRoot(path.dirname(fileURLToPath(import.meta.url)));
export const REPO_ROOT = path.resolve(ROOT, "../..");
export const IPQS_ORIGIN = "https://www.ipqualityscore.com";
export const IPQS_API_BASE = `${IPQS_ORIGIN}/api/json`;
export const DEFAULT_BROWSER_PROFILE_DIR = path.join(ROOT, ".state", "chrome-profile");
export const DEFAULT_API_KEY_FILE = path.join(REPO_ROOT, "secrets", "ipqs");

export const DASHBOARD_PAGES = {
  home: "/user/dashboard",
  settings: "/user/settings",
  api_keys: "/user/api-keys",
} as const;

export type DashboardPageName = keyof typeof DASHBOARD_PAGES;

export const IPQS_API_KEY_POLICY = {
  minBytes: 20,
  maxBytes: 128,
  validate: isLikelyIpqsApiKey,
} as const;

export function env(name: string, fallback = "") {
  return process.env[name]?.trim() || fallback;
}

function integerEnv(name: string, fallback: number, minimum: number, maximum: number) {
  const raw = env(name);
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error(`${name} must be an integer from ${minimum} through ${maximum}.`);
  }
  return value;
}

export function getBrowserProfileDir() {
  return env("IPQS_BROWSER_PROFILE_DIR", DEFAULT_BROWSER_PROFILE_DIR);
}

export function getApiKeyFile() {
  return env("IPQS_API_KEY_FILE", DEFAULT_API_KEY_FILE);
}

export function getCdpPort() {
  return integerEnv("IPQS_CDP_PORT", 19453, 1024, 65535);
}

export function getTimeoutMs() {
  return integerEnv("IPQS_TIMEOUT_MS", 20_000, 1_000, 60_000);
}

export function getLocale() {
  return env("IPQS_LOCALE", "en-US");
}

export function getProxyServer() {
  const value = env("IPQS_PROXY_SERVER") || env("HTTPS_PROXY") || env("HTTP_PROXY");
  if (!value) return undefined;
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error("IPQS_PROXY_SERVER must be an absolute credential-free HTTP, HTTPS, or SOCKS5 URL.");
  }
  if (!["http:", "https:", "socks5:"].includes(url.protocol)
    || url.username
    || url.password
    || url.pathname !== "/"
    || url.search
    || url.hash) {
    throw new Error("IPQS_PROXY_SERVER must be an absolute credential-free HTTP, HTTPS, or SOCKS5 URL.");
  }
  return value;
}

export function dashboardUrl(page: DashboardPageName) {
  return new URL(DASHBOARD_PAGES[page], IPQS_ORIGIN).href;
}

export function loginUrl() {
  return `${IPQS_ORIGIN}/login`;
}

export function summarizeIpqsUrl(value: string) {
  try {
    const url = new URL(value);
    if (url.origin !== IPQS_ORIGIN) return { trustedOrigin: false };
    return { trustedOrigin: true, path: url.pathname };
  } catch {
    return { trustedOrigin: false };
  }
}

export function isLikelyIpqsApiKey(value: string) {
  return typeof value === "string"
    && value.length >= 20
    && value.length <= 128
    && /^[A-Za-z0-9_-]+$/.test(value)
    && /[A-Za-z]/.test(value)
    && /\d/.test(value);
}

function assertNormalizedAbsolutePath(target: string, label: string) {
  if (!path.isAbsolute(target) || path.resolve(target) !== target) {
    throw new Error(`${label} must be a normalized absolute path.`);
  }
}

async function assertNoSymlinkComponents(target: string, allowMissingTail: boolean) {
  const parsed = path.parse(target);
  let current = parsed.root;
  for (const component of target.slice(parsed.root.length).split(path.sep).filter(Boolean)) {
    current = path.join(current, component);
    try {
      const state = await lstat(current);
      if (state.isSymbolicLink()) throw new Error("IPQS browser profile paths may not contain symbolic links.");
    } catch (error) {
      if (allowMissingTail && (error as NodeJS.ErrnoException).code === "ENOENT") return;
      throw error;
    }
  }
}

export async function ensureBrowserProfileDirectory() {
  const directory = getBrowserProfileDir();
  assertNormalizedAbsolutePath(directory, "IPQS_BROWSER_PROFILE_DIR");
  await assertNoSymlinkComponents(directory, true);
  await ensurePrivateDirectoryStrict(directory);
  await assertNoSymlinkComponents(directory, false);
  const handle = await open(
    directory,
    fsConstants.O_RDONLY | fsConstants.O_DIRECTORY | (fsConstants.O_NOFOLLOW || 0),
  );
  try {
    const state = await handle.stat();
    if (!state.isDirectory()
      || (typeof process.getuid === "function" && state.uid !== process.getuid())
      || (state.mode & 0o777) !== 0o700) {
      throw new Error("IPQS browser profile directory must be an owned directory at mode 0700.");
    }
  } finally {
    await handle.close();
  }
  return directory;
}

export async function inspectApiCredential() {
  const direct = env("IPQS_API_KEY");
  if (direct) {
    return isLikelyIpqsApiKey(direct)
      ? { configured: true, usable: true, source: "environment" as const, fingerprint: fingerprintSecret(direct) }
      : { configured: true, usable: false, source: "environment" as const, reason: "invalid" };
  }
  const file = getApiKeyFile();
  const state = await inspectPrivateSecretFile(file, IPQS_API_KEY_POLICY);
  return {
    configured: state.exists,
    usable: state.usable,
    source: "file" as const,
    file,
    ...(state.fingerprint ? { fingerprint: state.fingerprint } : {}),
    ...(state.reason ? { reason: state.reason } : {}),
  };
}

export async function resolveApiCredential() {
  const direct = env("IPQS_API_KEY");
  if (direct) {
    if (!isLikelyIpqsApiKey(direct)) throw new Error("Configured IPQS API credential is invalid.");
    return { key: direct, source: "environment" as const, fingerprint: fingerprintSecret(direct) };
  }
  const value = await readPrivateSecretFile(getApiKeyFile(), IPQS_API_KEY_POLICY).catch(() => null);
  if (!value) throw new Error("No usable local IPQS API credential is configured.");
  return { key: value.secret, source: "file" as const, fingerprint: value.fingerprint };
}
