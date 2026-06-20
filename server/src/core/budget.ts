import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";

/**
 * Token-budget & pagination helpers — the heart of godot-mcp-x's efficiency.
 *
 * The biggest failure mode of the original godot-mcp-pro was dumping enormous,
 * unpaginated payloads (a mid-size scene tree serialized to 73K chars and blew
 * past the model's token limit). Two defenses:
 *
 *  1. SOURCE-SIDE paging: tools pass offset/limit/max_depth down to Godot so the
 *     huge payload is never even serialized or sent over the wire. (Per-tool.)
 *  2. THIS module: a final TS-side safety clamp so no single tool response can
 *     blow the context window, plus shared pagination helpers.
 */

/** ~7K tokens. A safe default ceiling for one tool response. */
export const DEFAULT_MAX_CHARS = 24000;

/** Rough token estimate. Code/English ≈ 4 chars/token; we use 3.5 to stay conservative. */
export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 3.5);
}

export interface Page<T> {
  items: T[];
  total: number;
  offset: number;
  limit: number;
  has_more: boolean;
  /** Pass this back as `offset` to fetch the next page, or null when exhausted. */
  next_offset: number | null;
}

/** Generic offset/limit pagination over an in-memory array. */
export function paginate<T>(arr: T[], offset = 0, limit = 100): Page<T> {
  const total = arr.length;
  const start = Math.min(Math.max(0, offset), total);
  const safeLimit = Math.max(0, limit);
  const items = arr.slice(start, start + safeLimit);
  const end = start + items.length;
  const has_more = end < total;
  return { items, total, offset: start, limit: safeLimit, has_more, next_offset: has_more ? end : null };
}

/**
 * Serialize a tool result to compact JSON and clamp it to a char budget,
 * returning an MCP text-content result. If clamped, the appended note tells the
 * model exactly how to retrieve the rest (narrow the query / use offset+limit).
 */
export function clampJson(value: unknown, maxChars = DEFAULT_MAX_CHARS): CallToolResult {
  const text = typeof value === "string" ? value : safeStringify(value);
  if (text.length <= maxChars) {
    return { content: [{ type: "text", text }] };
  }
  const note =
    `\n\n…[OUTPUT TRUNCATED — ${text.length} chars exceeded the ${maxChars}-char budget. ` +
    `The leading slice above may be invalid JSON. This means the query was too broad: ` +
    `narrow it with a path/type filter, lower max_depth, or use offset/limit to page results.]`;
  // Reserve exactly the note's length so head + note never exceeds the budget.
  const keep = Math.max(0, maxChars - note.length);
  return { content: [{ type: "text", text: text.slice(0, keep) + note }] };
}

function safeStringify(value: unknown): string {
  try {
    return JSON.stringify(value);
  } catch {
    // Circular / non-serializable — fall back to a best-effort string.
    return String(value);
  }
}
