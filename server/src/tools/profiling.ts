import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const profilingTools: ToolDef[] = [
  tool({
    name: "get_performance_monitors",
    description:
      "Live performance snapshot: fps, process/physics ms, object/node/resource counts, " +
      "draw calls, primitives, video & static memory (MB).",
    handler: passthrough("get_performance_monitors"),
  }),
];
