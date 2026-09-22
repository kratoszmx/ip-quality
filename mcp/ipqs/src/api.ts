import { isIP } from "node:net";

import { fingerprintSecret } from "@codex-mcp/shared-secret-file";

import { classifyIpqsAccountUsage } from "./account-policy.js";
import { IPQS_API_BASE, isLikelyIpqsApiKey, resolveApiCredential } from "./config.js";
import { redactStructured, sanitizedError } from "./redaction.js";

export type LookupKind = "ip" | "email" | "phone" | "url";
export type ApiParameterScalar = string | number | boolean;
export type ApiParameterValue = ApiParameterScalar | ApiParameterScalar[];

const PRIMARY_PARAMETER: Record<LookupKind, string> = {
  ip: "ip",
  email: "email",
  phone: "phone",
  url: "url",
};

export const IPQS_API_MAX_BODY_BYTES = 1_048_576;
const PARAMETER_NAME_PATTERN = /^[A-Za-z][A-Za-z0-9_\[\]-]{0,63}$/;
const RESERVED_PARAMETER_NAMES = new Set(["key", "api_key", "api-key", "ipqs-key"]);

type ResolvedApiCredential = Awaited<ReturnType<typeof resolveApiCredential>>;

interface IpqsGetOptions {
  credential?: ResolvedApiCredential;
  credentialPlacement?: "header" | "path";
}

function normalizeLookup(kind: LookupKind, raw: string) {
  const value = raw.trim();
  if (!value || value.length > 4096 || /[\u0000-\u001f\u007f]/.test(value)) {
    throw new Error("IPQS lookup value is empty, invalid, or too long.");
  }
  if (kind === "ip" && isIP(value) === 0) throw new Error("IPQS IP lookup requires a valid IPv4 or IPv6 address.");
  if (kind === "email" && (value.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value))) {
    throw new Error("IPQS email lookup requires a valid email address shape.");
  }
  if (kind === "phone" && (value.length > 32 || !/^[+0-9 ().-]{7,32}$/.test(value))) {
    throw new Error("IPQS phone lookup requires a 7-32 character phone number.");
  }
  if (kind === "url") {
    let target: URL;
    try {
      target = new URL(value);
    } catch {
      throw new Error("IPQS URL lookup requires an absolute HTTP or HTTPS URL.");
    }
    if (!["http:", "https:"].includes(target.protocol) || target.username || target.password || value.length > 2048) {
      throw new Error("IPQS URL lookup requires a credential-free HTTP or HTTPS URL under 2048 characters.");
    }
  }
  return value;
}

function appendParameter(url: URL, name: string, raw: ApiParameterScalar) {
  const value = typeof raw === "string" ? raw : String(raw);
  if (value.length > 1000 || /[\u0000-\u001f\u007f]/.test(value)) {
    throw new Error("IPQS API parameter value is invalid or too long.");
  }
  url.searchParams.append(name, value);
}

export function buildLookupUrl(
  kind: LookupKind,
  lookup: string,
  parameters: Record<string, ApiParameterValue> = {},
) {
  const url = new URL(`${IPQS_API_BASE}/${kind}`);
  const primary = PRIMARY_PARAMETER[kind];
  url.searchParams.set(primary, normalizeLookup(kind, lookup));
  const entries = Object.entries(parameters);
  if (entries.length > 20) throw new Error("IPQS API calls accept at most 20 optional parameters.");
  for (const [name, raw] of entries) {
    if (!PARAMETER_NAME_PATTERN.test(name)
      || RESERVED_PARAMETER_NAMES.has(name.toLocaleLowerCase("en-US"))
      || name === primary) {
      throw new Error("IPQS API parameter name is invalid or reserved.");
    }
    const values = Array.isArray(raw) ? raw : [raw];
    if (values.length > 20) throw new Error("One IPQS API parameter has too many values.");
    for (const value of values) appendParameter(url, name, value);
  }
  return url;
}

async function readBoundedBody(response: Response, maximumBytes: number) {
  const declared = Number(response.headers.get("content-length") || "0");
  if (Number.isFinite(declared) && declared > maximumBytes) {
    await response.body?.cancel().catch(() => undefined);
    throw new Error("IPQS API response exceeded the configured body limit.");
  }
  if (!response.body) return Buffer.alloc(0);
  const reader = response.body.getReader();
  const chunks: Buffer[] = [];
  let total = 0;
  try {
    for (;;) {
      const part = await reader.read();
      if (part.done) break;
      total += part.value.byteLength;
      if (total > maximumBytes) {
        await reader.cancel().catch(() => undefined);
        throw new Error("IPQS API response exceeded the configured body limit.");
      }
      chunks.push(Buffer.from(part.value));
    }
  } finally {
    reader.releaseLock();
  }
  return Buffer.concat(chunks, total);
}

function assertJsonContentType(response: Response) {
  const contentType = response.headers.get("content-type") || "";
  const [mediaType] = contentType.split(";", 1);
  const charset = /charset\s*=\s*([^;]+)/i.exec(contentType)?.[1]?.trim().replace(/^['"]|['"]$/g, "");
  if (!/^(?:application|text)\/(?:[a-z0-9.+-]*\+)?json$/i.test(mediaType.trim())) {
    throw new Error("IPQS API returned a non-JSON response.");
  }
  if (charset && !/^(?:utf-?8|us-ascii)$/i.test(charset)) {
    throw new Error("IPQS API returned an unsupported response charset.");
  }
}

async function ipqsGet(
  url: URL,
  timeoutMs: number,
  fetchImpl: typeof fetch = fetch,
  options: IpqsGetOptions = {},
) {
  const credential = options.credential || await resolveApiCredential();
  const requestUrl = new URL(url);
  const credentialPlacement = options.credentialPlacement || "header";
  if (credentialPlacement === "path") {
    requestUrl.pathname = `${requestUrl.pathname.replace(/\/$/, "")}/${encodeURIComponent(credential.key)}`;
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(requestUrl, {
      method: "GET",
      redirect: "error",
      signal: controller.signal,
      headers: {
        accept: "application/json",
        ...(credentialPlacement === "header" ? { "ipqs-key": credential.key } : {}),
      },
    });
    assertJsonContentType(response);
    const body = await readBoundedBody(response, IPQS_API_MAX_BODY_BYTES);
    let parsed: unknown;
    try {
      parsed = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(body));
    } catch {
      throw new Error("IPQS API returned malformed UTF-8 JSON.");
    }
    return {
      ok: response.ok,
      httpStatus: response.status,
      credentialSource: credential.source,
      credentialFingerprint: credential.fingerprint,
      data: redactStructured(parsed),
    };
  } catch (error) {
    if (controller.signal.aborted) throw new Error("IPQS API request reached its time limit.");
    throw new Error(sanitizedError(error));
  } finally {
    clearTimeout(timer);
  }
}

export async function lookupIpqs(
  kind: LookupKind,
  lookup: string,
  parameters: Record<string, ApiParameterValue> = {},
  timeoutMs = 20_000,
  fetchImpl: typeof fetch = fetch,
) {
  const url = buildLookupUrl(kind, lookup, parameters);
  const result = await ipqsGet(url, timeoutMs, fetchImpl);
  return { source: "ipqs-api", endpoint: kind, ...result };
}

export async function getIpqsAccountUsage(timeoutMs = 20_000, fetchImpl: typeof fetch = fetch) {
  const result = await ipqsGet(new URL(`${IPQS_API_BASE}/account`), timeoutMs, fetchImpl, {
    credentialPlacement: "path",
  });
  return { source: "ipqs-api", endpoint: "account", ...result, outcome: classifyIpqsAccountUsage(result) };
}

export async function validateIpqsApiCredential(
  apiKey: string,
  timeoutMs = 20_000,
  fetchImpl: typeof fetch = fetch,
) {
  if (!isLikelyIpqsApiKey(apiKey)) return { valid: false, status: "invalid-shape" as const };
  const result = await ipqsGet(new URL(`${IPQS_API_BASE}/account`), timeoutMs, fetchImpl, {
    credential: {
      key: apiKey,
      source: "environment",
      fingerprint: fingerprintSecret(apiKey),
    },
    credentialPlacement: "path",
  });
  const outcome = classifyIpqsAccountUsage(result);
  if (outcome === "authenticated") return { valid: true, status: "accepted" as const };
  if (outcome === "authenticated_without_credits") {
    return { valid: true, status: "accepted-without-credits" as const };
  }
  if (outcome === "login_required") {
    return { valid: false, status: "invalid-or-unauthorized" as const };
  }
  return { valid: false, status: "unverified" as const };
}
