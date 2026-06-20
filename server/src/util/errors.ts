export class GodotConnectionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GodotConnectionError";
  }
}

export class GodotCommandError extends Error {
  public code: number;
  public data?: Record<string, unknown>;

  constructor(code: number, message: string, data?: Record<string, unknown>) {
    super(message);
    this.name = "GodotCommandError";
    this.code = code;
    this.data = data;
  }
}

export class TimeoutError extends Error {
  constructor(method: string, timeoutMs: number) {
    super(`Command '${method}' timed out after ${timeoutMs}ms`);
    this.name = "TimeoutError";
  }
}

/** Render any error into a single human+model-readable string for an MCP error result. */
export function formatErrorForMcp(error: unknown): string {
  if (error instanceof GodotCommandError) {
    let msg = `Godot error (${error.code}): ${error.message}`;
    if (error.data?.suggestion) msg += `\nSuggestion: ${error.data.suggestion}`;
    if (Array.isArray(error.data?.suggestions) && error.data.suggestions.length) {
      msg += `\nDid you mean: ${(error.data.suggestions as string[]).join(", ")}?`;
    }
    if (error.data?.available_methods && Array.isArray(error.data.available_methods)) {
      // Help the model recover from a typo'd method name without dumping all 170+.
      const list = (error.data.available_methods as string[]).slice(0, 12).join(", ");
      msg += `\nSome available methods: ${list}…`;
    }
    return msg;
  }
  if (error instanceof GodotConnectionError) {
    return (
      `Connection error: ${error.message}. ` +
      `Make sure the Godot editor is running with the "godot_mcp_x" plugin enabled.`
    );
  }
  if (error instanceof TimeoutError) return error.message;
  if (error instanceof Error) return error.message;
  return String(error);
}
