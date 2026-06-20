# Godot 4.7 — What's New & Migration Notes

Scoped to things that change how you **write code** or **automate the editor**.
Godot 4.7 is the "Director's Cut" release.

## Headline features (4.7)

- **HDR output** for 2D and 3D on Windows, macOS, iOS, visionOS, and Linux
  (Wayland). Surfaces as new viewport/rendering settings.
- **`AreaLight3D`** — a brand-new node: rectangular real-time area lights.
  ✅ verified: `AreaLight3D extends Light3D`; own properties:
  `area_size`, `area_range`, `area_attenuation`, `area_normalize_energy`,
  `area_texture`. Use it instead of faking soft rect lights with meshes/emission.
- **`VirtualJoystick`** ✅ — official touchscreen joystick (a `Control`); wires
  straight to input-map actions via `action_left/right/up/down`.
- **`DrawableTexture2D`** ✅ — draw onto a texture from code (`setup`/`blit_rect`).
- **Vulkan ray-tracing groundwork** ✅ — `RDAccelerationStructureGeometry` /
  `RDAccelerationStructureInstance` (low-level only; not production RT yet).
- **Full organized 4.7 changelog → [11-godot-4.7-deep-dive.md](11-godot-4.7-deep-dive.md).**
- **Nearest-neighbor viewport scaling** — crisp low-res upscaling without blur
  (viewport scaling mode option).
- **New Asset Store** (replaces the Asset Library) with background threading so
  downloads don't block the editor.
- **Inspector category copy/paste** — copy a whole category of properties between
  nodes/resources at once.
- **Inline shader previews** — preview text-based shader operations inline.
- **Scene Paint** (2D) — paint scene instances into a level to build environments
  / scatter props & vegetation.
- **Mobile**: built-in virtual joystick, gyro aiming, accelerometer input;
  building & exporting games **entirely on Android** via the Android Build
  Environment; production-ready **Android XR** and **Steam Frame** (OpenXR
  composition layers improved).

## API-level facts worth knowing (✅ verified on 4.7)

- `1549` classes in ClassDB, `41` global singletons. If you think a class exists,
  confirm with `ClassDB.class_exists("X")` before using it.
- **`TileMapLayer` is the modern tilemap API**; the old **`TileMap` still exists
  but is deprecated** (since 4.3). New code: one `TileMapLayer` node per layer.
  Both present: ✅ `TileMapLayer`=true, `TileMap`=true.
- Present and current: `Skeleton3D`, `GLTFDocument`, `NavigationServer3D`,
  `RenderingDevice`, `ZIPReader`/`ZIPPacker`, `ResourceUID`, `AnimationMixer`
  (shared base of `AnimationPlayer`/`AnimationTree`), `EditorUndoRedoManager`.

## Migration notes (4.3 → 4.7) relevant to writing code

- **Typed Dictionaries** (since 4.4): `var d: Dictionary[String, int] = {}`.
  Mirrors typed arrays. Prefer typed collections for inspector + perf.
- **`TileMap` → `TileMapLayer`**: per-layer nodes; there's an editor converter.
  Don't author new `TileMap`.
- **`AnimationMixer`**: callbacks/methods shared by `AnimationPlayer` and
  `AnimationTree` live on this common base — target it when writing generic code.
- **Renderer names**: `rendering/renderer/rendering_method` is one of
  `forward_plus`, `mobile`, `gl_compatibility`. ✅ this project: `forward_plus`.
- **`EditorInterface` is a global** (since 4.3): call `EditorInterface.foo()`
  directly in `@tool`/editor scripts — no `get_editor_interface()` needed.

## When in doubt

The engine is the source of truth. From godot-mcp-x:
`describe_class {name:"AreaLight3D"}` or
`list_classes {inherits:"Light3D"}`. Inside GDScript:
`ClassDB.class_get_property_list("AreaLight3D", true)`.

---

Sources: [Godot 4.7 Released (GameFromScratch)](https://gamefromscratch.com/godot-4-7-released/),
[Godot 4.7 Is Here (80.lv)](https://80.lv/articles/godot-4-7-has-been-released),
[Godot 4.7 Released With HDR Output (Phoronix)](https://www.phoronix.com/news/Godot-4.7-Released),
[What's New in Godot 4.7 (Godot Learning)](https://godotlearning.com/blog/godot-4-7-whats-new).
Class/property facts verified directly against the running 4.7-stable build via ClassDB.
