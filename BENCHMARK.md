# Benchmarks — godot-mcp-x efficiency

Measured on a **real scene** (the `demo` project's `main.tscn`, **137 nodes**) in
the live Godot 4.7-stable editor. Apples-to-apples: same scene, same node set —
only the serialization strategy differs.

## 1. Scene tree — node paths (headline win)

| Approach | chars | per-node path sample |
|---|--:|---|
| Full editor paths (original) | **58,897** | `/root/@EditorNode@19513/@Panel@14/…/@SubViewport@9904/Main/WeatherSystem/Rain` (446 chars) |
| Scene-relative (godot-mcp-x) | **11,771** | `WeatherSystem/Rain` (18 chars) |
| **Reduction** | **80%** | ~25× shorter paths |

For reference, the original godot-mcp-pro's actual `get_scene_tree` on this scene
returned **73,186 chars** — past the model's per-result token budget (it errored
out). godot-mcp-x also collapses instanced sub-scenes, omits default properties,
and honors `max_depth`, so the real-world gap is larger still.

## 2. Node properties — changed-only vs full dump

`get_node_properties` on `Player` (a heavily-customized `CharacterBody3D`):

| Mode | props | chars |
|---|--:|--:|
| All storage properties | 113 | 3,389 |
| Changed-only (godot-mcp-x default) | 73 | 2,310 |
| **Reduction** | | **31%** |

This is close to a worst case — the node is heavily configured. For near-default
nodes the saving approaches 100% (a freshly-added node returns `{}`).

## 3. Source-side pagination

`read_script` / `get_scene_file_content` return a line window
(`offset`/`limit`, default 400) plus `total_lines`, instead of the whole file —
a 2,000-line script is read in slices on demand, never as one 60K-char dump.

## 4. Runtime inspection — zero disk churn

Runtime tools reach the running game over a **direct WebSocket**, eliminating the
original's per-frame `user://` request/response **file polling** (disk I/O every
frame + a debugger crash-recovery handshake). Lower latency, no disk wear, fewer
failure modes.

## 5. Property serialization — cached class defaults

`changed_properties` (the "only non-default props" path behind
`get_node_properties`, `batch_get_properties`, scene trees with
`include_properties`, `read_resource`, …) used to instantiate a throwaway
reference node **per node** to learn the class defaults. Now the default snapshot
is cached **per class** (engine defaults are constant), so each class is
instantiated at most once.

Measured on the 137-node demo scene (25 distinct classes):

| | time |
|---|--:|
| Reference per node (old) | 15,277 µs |
| Cached per class (new) | 3,864 µs |
| **Speedup** | **~4×** — and effectively free once the cache is warm across calls |

## Method

The path & property numbers were produced by running both strategies
side-by-side via `execute_editor_script` in one editor on one scene — rerun any
time against your own scene. End-to-end correctness is covered by
`server/test/{handshake,smoke,runtime_test}.js` (**45/45 round-trip calls green**
against a live 4.7 build).
