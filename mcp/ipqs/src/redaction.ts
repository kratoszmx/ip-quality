const EMAIL_PATTERN = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi;
const LONG_CREDENTIAL_PATTERN = /\b(?=[A-Za-z0-9_-]{20,128}\b)(?=[A-Za-z0-9_-]*[A-Za-z])(?=[A-Za-z0-9_-]*\d)[A-Za-z0-9_-]+\b/g;
const BEARER_PATTERN = /\b(Bearer\s+)[^\s,;]+/gi;

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function redactText(value: unknown, knownSecrets: readonly string[] = []) {
  let text = typeof value === "string" ? value : String(value ?? "");
  for (const secret of knownSecrets.filter(Boolean)) {
    text = text.replace(new RegExp(escapeRegExp(secret), "g"), "<redacted-secret>");
  }
  return text
    .replace(BEARER_PATTERN, "$1<redacted-secret>")
    .replace(EMAIL_PATTERN, "<redacted-email>")
    .replace(LONG_CREDENTIAL_PATTERN, "<redacted-secret>");
}

export function boundedVisibleText(value: unknown, limit: number) {
  const normalized = redactText(value)
    .replace(/\r/g, "")
    .split("\n")
    .map((line) => line.replace(/[\t ]+/g, " ").trim())
    .filter((line, index, lines) => line || (index > 0 && lines[index - 1]))
    .join("\n")
    .trim();
  return normalized.slice(0, limit);
}

const SECRET_FIELD_PATTERN = /^(?:api[_-]?key|key|secret|token|access[_-]?token|password|passwd|authorization)$/i;

export function redactStructured(value: unknown, depth = 0): unknown {
  if (depth > 10) return "<truncated-depth>";
  if (typeof value === "string") return redactText(value);
  if (Array.isArray(value)) return value.slice(0, 1000).map((entry) => redactStructured(entry, depth + 1));
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(Object.entries(value as Record<string, unknown>).slice(0, 1000).map(([key, entry]) => [
    key,
    SECRET_FIELD_PATTERN.test(key) ? "<redacted-secret>" : redactStructured(entry, depth + 1),
  ]));
}

export function sanitizedError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  return redactText(message).slice(0, 500) || "IPQS operation failed.";
}
