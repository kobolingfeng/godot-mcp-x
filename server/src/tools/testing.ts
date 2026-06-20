import { z } from "zod";
import { tool, runtimePassthrough, type ToolDef } from "../core/registry.js";

/**
 * Automated gameplay testing — all RUNTIME tools (require play_scene first).
 * Assertions accumulate into a report retrievable via get_test_report.
 */
export const testingTools: ToolDef[] = [
  tool({
    name: "assert_property",
    description:
      "Assert a live node property against an expected value. op ∈ eq|ne|gt|lt|ge|le|near|contains " +
      "(default eq). String values like 'Vector3(0,1,0)' are parsed. Records to the test report.",
    schema: {
      path: z.string().describe("Scene-relative node path in the running game"),
      property: z.string(),
      expected: z.any(),
      op: z.enum(["eq", "ne", "gt", "lt", "ge", "le", "near", "contains"]).optional(),
    },
    handler: runtimePassthrough("assert_property"),
  }),
  tool({
    name: "assert_node_exists",
    description: "Assert a node exists in the running game. Records to the test report.",
    schema: { path: z.string().describe("Scene-relative node path") },
    handler: runtimePassthrough("assert_node_exists"),
  }),
  tool({
    name: "assert_screen_text",
    description: "Assert some visible Control (Label/Button/…) currently shows the given text. Records to the report.",
    schema: { text: z.string().describe("Substring to look for in any node's `text`") },
    handler: runtimePassthrough("assert_screen_text"),
  }),
  tool({
    name: "wait_for_node",
    description: "Poll until a node appears in the running game (or timeout). Returns found + elapsed seconds.",
    schema: {
      path: z.string().describe("Scene-relative node path"),
      timeout: z.number().optional().describe("Seconds (default 5)"),
    },
    handler: runtimePassthrough("wait_for_node"),
  }),
  tool({
    name: "monitor_property",
    description: "Sample a live property over a duration and return the time series (e.g. watch a health bar decay).",
    schema: {
      path: z.string().describe("Scene-relative node path"),
      property: z.string(),
      duration: z.number().optional().describe("Seconds (default 1)"),
      samples: z.number().int().optional().describe("Sample count (default 10)"),
    },
    handler: runtimePassthrough("monitor_property"),
  }),
  tool({
    name: "record_frames",
    description: "Capture N screenshots of the running game over time; returns the saved PNG paths (read them to view).",
    schema: {
      count: z.number().int().optional().describe("Default 3"),
      interval: z.number().optional().describe("Seconds between frames (default 0.2)"),
      save_dir: z.string().optional().describe("res:// or user:// dir (default user://mcp_x/frames)"),
    },
    handler: runtimePassthrough("record_frames"),
  }),
  tool({
    name: "run_test_scenario",
    description:
      "Run a scripted gameplay test in the live game and return a pass/fail report. Steps run in order; " +
      "each is {type, …}: key{key,duration?}, action{action,duration?}, wait{seconds}, wait_node{path,timeout?}, " +
      "assert_property{path,property,expected,op?}, assert_node{path}, assert_text{text}.",
    schema: {
      name: z.string().optional(),
      steps: z.array(z.record(z.any())).describe("Ordered list of step objects"),
    },
    handler: runtimePassthrough("run_test_scenario"),
  }),
  tool({
    name: "get_test_report",
    description: "Return all accumulated assertion results (total/passed/failed/log). Pass clear=true to reset.",
    schema: { clear: z.boolean().optional() },
    handler: runtimePassthrough("get_test_report"),
  }),
];
