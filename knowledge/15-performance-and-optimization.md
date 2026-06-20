# Performance & Optimization (Godot 4.7)

Measure first, then optimize the bottleneck. godot-mcp-x: `get_performance_monitors`
(live snapshot), `analyze_scene_complexity`, `get_editor_performance`.

## Performance monitors (✅ full `Performance.Monitor` enum)

- **Time**: `TIME_FPS`, `TIME_PROCESS`, `TIME_PHYSICS_PROCESS`,
  `TIME_NAVIGATION_PROCESS` (seconds; ×1000 for ms).
- **Memory**: `MEMORY_STATIC`, `MEMORY_STATIC_MAX`.
- **Objects**: `OBJECT_COUNT`, `OBJECT_NODE_COUNT`, `OBJECT_RESOURCE_COUNT`,
  `OBJECT_ORPHAN_NODE_COUNT` (orphans = a leak smell).
- **Render**: `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`,
  `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`,
  `RENDER_VIDEO_MEM_USED`, `RENDER_TEXTURE_MEM_USED`, `RENDER_BUFFER_MEM_USED`.
- **Physics**: `PHYSICS_3D_ACTIVE_OBJECTS`, `PHYSICS_3D_COLLISION_PAIRS`,
  `PHYSICS_3D_ISLAND_COUNT` (+ 2D variants).
- **Navigation**: `NAVIGATION_AGENT_COUNT`, `NAVIGATION_REGION_COUNT`, … (2D/3D).
- **Pipeline (4.x)**: `PIPELINE_COMPILATIONS_*` — non-zero spikes mid-game = shader
  compilation **stutter**; pre-warm materials at load.
- `Performance.get_custom_monitor(...)` for your own metrics.

Read in code: `Performance.get_monitor(Performance.TIME_FPS)`.

## Rendering (usually the first bottleneck)

- **Cut draw calls**: merge meshes, share materials, use **`MultiMeshInstance3D`**
  for many identical meshes (grass, crowds), `GPUParticles` for fx.
- **Culling**: `OccluderInstance3D` (bake occlusion); set `VisibleOnScreen
  Notifier`/`visibility_range_*` for LOD; keep camera `far` reasonable.
- **Lighting**: prefer **baked** `LightmapGI` for static scenes; limit real-time
  shadow-casting lights; `AreaLight3D`/`SpotLight3D` shadows are costly.
- **Textures**: compress (VRAM-compressed import), mind `RENDER_TEXTURE_MEM_USED`.
- Renderer choice: `forward_plus` (desktop) vs `mobile` vs `gl_compatibility`
  (low-end/web) — pick the lightest that has the features you use.

## Physics

- Cheap shapes (Box/Sphere/Capsule) over `ConcavePolygonShape3D`; use convex for
  dynamic bodies. Put things on the **right collision layers** so the broadphase
  skips irrelevant pairs (watch `PHYSICS_3D_COLLISION_PAIRS`).
- `contact_monitor` + `max_contacts_reported` only where you need contact signals.
- `continuous_cd` only on small fast bodies. Lower
  `physics/common/physics_ticks_per_second` if 60 is overkill.

## Scripting / nodes

- Do per-frame movement in **`_physics_process`**, not `_process`; avoid heavy work
  every frame. Cache lookups (`@onready`), don't `get_node` in loops.
- Avoid per-frame **allocations** (new arrays/dicts/strings) — they cause GC-like
  churn. Reuse buffers; prefer typed arrays.
- **Object pooling** for bullets/enemies instead of instance/free churn.
- Use **groups**/signals over scanning the whole tree each frame.
- Fewer nodes = less overhead; collapse trivial nodes, prefer servers
  (`RenderingServer`/`PhysicsServer3D`) for thousands of items.

## Loading

- `preload` constants; `ResourceLoader.load_threaded_request/get` for big assets to
  avoid hitches; pre-instantiate/pre-warm shaders & particles before gameplay.

## Workflow with godot-mcp-x

1. `play_scene`, reproduce the slow moment.
2. `get_performance_monitors` → find the spiking metric (draw calls? physics pairs?
   process ms? pipeline compilations?).
3. Target that subsystem with the fixes above; re-measure.
4. `analyze_scene_complexity` to spot node-count / per-type hotspots statically.
