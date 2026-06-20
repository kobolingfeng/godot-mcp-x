# Godot 4.7 AI Knowledge Base

A reusable, AI-oriented reference for writing **correct** Godot 4.7 code and
automating the editor. Built and verified against the live engine, not from
memory — facts marked **✅ verified** were checked on this exact build:

| | |
|---|---|
| Version | **4.7-stable (official)** |
| Version hex | `0x40700` (263936) |
| Build hash | `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` |
| ClassDB classes | **1549** |
| Global singletons | **41** |
| Default renderer | `forward_plus` |

## How to use this KB

- Treat **✅ verified** facts as ground truth for 4.7. The engine moved fast
  across 4.4→4.7 (much of it past common training cutoffs), so prefer these over
  half-remembered APIs.
- When an API is uncertain, **don't guess** — introspect the live engine:
  `describe_class` / `list_classes` (godot-mcp-x) or `ClassDB.*` inside
  `execute_editor_script`. Recipes in [03-editor-automation.md](03-editor-automation.md).
- Each file is self-contained; skim the headers.

## Index

1. [01-godot-4.7-whats-new.md](01-godot-4.7-whats-new.md) — version facts, new
   nodes/features (AreaLight3D, HDR, TileMapLayer…), migration notes.
2. [02-gdscript-essentials.md](02-gdscript-essentials.md) — GDScript 4.x patterns
   for correct codegen: typing, `await`, lambdas, Callables, `str_to_var`,
   signals, `@tool`/`@export`.
3. [03-editor-automation.md](03-editor-automation.md) — `EditorInterface` /
   `ClassDB` / `EditorPlugin` recipes; scene-relative paths; saving scenes; the
   patterns godot-mcp-x is built on.
4. [04-api-gotchas.md](04-api-gotchas.md) — concrete pitfalls discovered while
   building the tooling (each one cost a real bug).
5. [05-tooling-and-workflows.md](05-tooling-and-workflows.md) — how an AI should
   drive Godot via godot-mcp-x: editor vs runtime, scene-relative paths, and
   end-to-end build / inspect / test / hot-tweak workflows.
6. [06-gameplay-patterns.md](06-gameplay-patterns.md) — copy-paste-correct 4.7
   GDScript: CharacterBody movement, signals, autoloads, timers, spawning,
   groups, AnimationTree state machines.
7. [07-rendering-materials-lighting.md](07-rendering-materials-lighting.md) —
   BaseMaterial3D, lights (incl. 4.7 AreaLight3D), Environment, HDR/tonemap.
8. [08-physics-and-collision.md](08-physics-and-collision.md) — body types,
   layers/masks, shapes, CharacterBody/RigidBody/Area, raycasts.
9. [09-resources-export-saving.md](09-resources-export-saving.md) — custom
   resources, the full @export annotation set, PackedScene, loading, UIDs.
10. [10-skeleton-ik-and-modifiers.md](10-skeleton-ik-and-modifiers.md) — the 4.3+
    SkeletonModifier3D/IK system (TwoBoneIK3D, FABRIK3D, LookAtModifier3D, …).
11. [11-godot-4.7-deep-dive.md](11-godot-4.7-deep-dive.md) — comprehensive 4.7
    changelog: VirtualJoystick, DrawableTexture2D, ray-tracing groundwork, HDR,
    Scene Paint, Jolt SoftBody, GUI/input/editor/Android changes, breaking changes.
12. [12-ui-and-control.md](12-ui-and-control.md) — Control layout (anchors/presets),
    containers & size flags, common nodes, theming, VirtualJoystick, 4.7 GUI changes.
13. [13-shaders.md](13-shaders.md) — Godot Shading Language: shader types, built-ins,
    uniform hints, recipes (fresnel/dissolve/scroll), ShaderMaterial, 4.7 notes.
14. [14-xr.md](14-xr.md) — OpenXR setup (XROrigin3D/XRCamera3D/XRController3D),
    controllers, body/hand/face modifiers, Android XR / Steam Frame.
15. [15-performance-and-optimization.md](15-performance-and-optimization.md) —
    Performance monitors, rendering/physics/scripting optimization checklist,
    profiling workflow with godot-mcp-x.
16. [16-multiplayer.md](16-multiplayer.md) — high-level networking: peers (ENet/
    WebSocket/WebRTC), RPCs, authority, MultiplayerSpawner/Synchronizer replication.
17. [17-audio.md](17-audio.md) — players (2D/3D), stream types (polyphonic/
    interactive/synchronized), buses & effects, dB-vs-linear, latency.
18. [18-navigation.md](18-navigation.md) — NavigationRegion/Agent/Obstacle/Link,
    baking, agent movement + RVO avoidance, NavigationServer queries.
19. [19-recipes.md](19-recipes.md) — common task → exact tool/CLI sequence
    (build_tree, reload_game_script, transient-VFX capture, input, hot-tweak, setup).

> Maintained alongside **godot-mcp-x**. When a tool hits an API surprise, the
> fix and the fact both land here so the next agent doesn't repeat it.
