import { redactText } from "@myutils/redaction";

// IPQS-specific presentation on top of @myutils/redaction: dashboard text is
// whitespace-normalized and bounded, and errors get a stable fallback.
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

export function sanitizedError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  return redactText(message).slice(0, 500) || "IPQS operation failed.";
}
