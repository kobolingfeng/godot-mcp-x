# Godot 4.7 — Deep Dive (researched + ClassDB-verified)

Comprehensive developer-facing changelog for **4.7-stable** (309 contributors,
1,265 fixes since 4.6). Class names marked **✅** were confirmed to exist on this
live build. Use `describe_class {name}` for exact, current signatures.

## Flagship additions

- **`VirtualJoystick`** ✅ (extends `Control`) — official touchscreen joystick,
  no more community forks. Key props: `joystick_mode`
  (`JOYSTICK_FIXED` / `JOYSTICK_DYNAMIC` / `JOYSTICK_FOLLOWING`),
  `visibility_mode` (`VISIBILITY_ALWAYS` / `VISIBILITY_WHEN_TOUCHED`),
  `deadzone_ratio`, `clampzone_ratio`, `tip_size`, and **`action_left/right/up/down`**
  (wires straight to your input-map actions — set these and movement code that
  reads those actions "just works" on touch).
- **`AreaLight3D`** ✅ (extends `Light3D`) — rectangular real-time area light.
  Props: `area_size`, `area_range`, `area_attenuation`, `area_normalize_energy`,
  `area_texture`.
- **`DrawableTexture2D`** ✅ (extends `Texture2D`) — draw directly onto a texture
  from code: `setup(width, height, …)`, `blit_rect(...)`, `blit_rect_multi(...)`,
  `generate_mipmaps()`. A clean API over render-to-texture / image painting.
- **HDR output** — cross-platform: Windows (C++20 WinRT), macOS (Metal),
  Linux/BSD (Vulkan). Pair with AgX/Filmic tonemap (see
  [07-rendering-materials-lighting.md](07-rendering-materials-lighting.md)).
- **Vulkan ray-tracing groundwork** — low-level plumbing only:
  `RDAccelerationStructureGeometry` ✅ + `RDAccelerationStructureInstance` ✅ let
  you build acceleration structures and dispatch rays from `RenderingDevice`.
  NOT production RT shadows/reflections/path-tracer yet.

## Rendering

- Nearest-neighbor scaling for **3D** viewports (crisp pixel-art 3D; was bilinear).
- Inline shader previews in the script/text editor.
- `GradientTexture2D` gains **conic gradients**.
- Drawable textures (above).

## 2D / 3D editor tooling

- **Scene Paint** (2D): paint scene instances into a level with grid snapping +
  per-instance property config (scatter props/vegetation).
- **Vertex snapping**: hold **B**, move near vertices to snap selections (mesh and
  non-mesh nodes).
- **Path3D** point→collider snapping during editing.
- **One-way collisions (2D)**: `CollisionShape2D` supports a directional one-way
  normal (not just "up").
- CSG **auto-smoothing**; 3D ruler shows X/Y/Z components.

## Animation

- **AwaitTweener**: a tween step can `await` a signal before continuing.
- Animation **track group collapsing** in the editor.
- Optimizations across `Animation`, `AnimationLibrary`, `AnimationMixer`,
  `AnimationPlayer`, `AnimationTree`. BlendSpace point names/indices are now
  editable (minor breaking: names/indices shown).

## Physics (Jolt)

- `Area3D` now detects & influences **`SoftBody3D`** (Jolt).
- `SoftBody3D` default **mass = 1 kg** (was 0) — *breaking* if you relied on the old default.
- Particles **angular velocity** corrected to match docs (*breaking* visual change).

## GUI / Control

- **Control transform offsets** — `translate`/`rotate`/`scale` a Control
  *visually* without affecting container layout.
- `Control.custom_maximum_size` ✅ — max-size constraint (complements
  custom_minimum_size).
- `PopupMenu` search bar for long lists; `Tree` drag-and-drop parental-chain
  indicators.
- `RichTextLabel`: image sizing in **`em`** units (*breaking* vs px), better
  tables, triple-click paragraph selection.

## Input

- Joypad **motion sensors**; `DisplayServer` device-orientation change signals.
- Touch input on **Wayland**; **SDL3** joystick driver on iOS.
- Keyboard/mouse events now carry **device IDs** (*breaking* for code inspecting events).

## Editor

- **Asset Library redesign** (new API, metadata, changelog, version switching),
  partial export-template downloads.
- `MeshLibrary` grid editor redesign (grid/search/zoom/undo-redo).
- **GDExtension viewer** in Project Settings (with reload).
- Remote inspector shows real **class names** (not anonymous Object IDs); remote
  scene tree folding; code-like symbols in monospace; create-dialog type filters.

## GDScript / scripting

- Analyzer **excludes internal global classes** → far fewer false-positive
  warnings on big codebases.
- Non-exported **enums keep type info** in remote debugging.
- Constant-expression evaluation improved for arrays/dictionaries.
- `Object` signals hardened for **thread-safety**; `Object::ConnectFlags` is now a
  bitfield in GDExtension (*breaking* for extensions).

## Platforms

- **Android**: Picture-in-Picture; build & export **entirely on-device**; embedded
  game-window resize/reposition with aspect lock; implement Java interfaces from
  GDScript; native file picker; splash customization. **OBB support removed** (*breaking*).
- **Windows**: C++20 isolation for WinRT/HDR; OneCore/WinRT emoji picker.
- **Web**: WebAssembly **64-bit** support.
- Android **XR** and **Steam Frame** production-ready (OpenXR composition layers).

## Notable breaking changes (quick list)

`SoftBody3D` mass default 1kg · particles angular velocity · RichTextLabel image
`em` units · input events carry device IDs · Android OBB removed ·
`Object::ConnectFlags` bitfield (GDExtension) · shader preprocessor condition
parsing restricted · multi-viewport 3D audio volume recalculated.

---

Sources: [Dev snapshot: Godot 4.7 beta 1 (godotengine.org)](https://godotengine.org/article/dev-snapshot-godot-4-7-beta-1/),
[Godot 4.7 RC1 — what developers need to know (linuxcompatible)](https://www.linuxcompatible.org/story/godot-47-rc-1-released-what-developers-need-to-know-before-upgrading/),
[Godot 4.7 beta features (ziva.sh)](https://ziva.sh/blogs/godot-4-7).
Class/enum/property names verified against the running 4.7-stable build via ClassDB.
