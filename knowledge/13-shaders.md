# Shaders — Godot Shading Language (4.7)

Godot's shading language (GLSL-like, not raw GLSL). Files are `.gdshader`.
godot-mcp-x: `create_shader`, `read_shader`, `edit_shader`, `assign_shader`,
`set_shader_param`, `list_shader_uniforms`.

## Shader types (first line, required)

```glsl
shader_type spatial;       // 3D materials (BaseMaterial3D-style)
shader_type canvas_item;   // 2D
shader_type particles;     // GPUParticles process
shader_type sky;           // Sky / Environment
shader_type fog;           // FogVolume
```

## Processor functions

`vertex()`, `fragment()`, `light()` (spatial/canvas_item), `start()`/`process()`
(particles), `sky()` (sky). Optional `global`/`instance` uniforms.

```glsl
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color;
uniform float speed = 1.0;

void fragment() {
    vec2 uv = UV + vec2(TIME * speed, 0.0);
    ALBEDO = texture(albedo_tex, uv).rgb * tint.rgb;
    ROUGHNESS = 0.4;
}
```

## Key built-ins

- **spatial** in: `UV`, `NORMAL`, `VERTEX`, `TIME`, `VIEW`, `CAMERA_POSITION_WORLD`,
  `SCREEN_UV`; out: `ALBEDO`, `ALPHA`, `METALLIC`, `ROUGHNESS`, `EMISSION`,
  `NORMAL_MAP`, `RIM`, `AO`. Matrices: `MODEL_MATRIX`, `VIEW_MATRIX`, `PROJECTION_MATRIX`.
- **canvas_item**: `UV`, `COLOR`, `TEXTURE`, `SCREEN_UV`, `TIME`; out `COLOR`.
- **particles**: `TRANSFORM`, `VELOCITY`, `COLOR`, `LIFETIME`, `DELTA`, `RESTART`.

## Uniform hints (drive the inspector + correctness)

```glsl
uniform vec4 col : source_color;            // treat as sRGB color (color picker)
uniform float amount : hint_range(0,1,0.01);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise : hint_default_white;
group_uniforms Glow;                         // inspector grouping
```
Set from code/tools: `material.set_shader_parameter("amount", 0.5)` (godot-mcp-x
`set_shader_param`). Discover a shader's uniforms with `list_shader_uniforms`
(uses `Shader.get_shader_uniform_list()`).

## Common recipes

```glsl
// Fresnel rim (spatial fragment)
float fres = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), 3.0);
EMISSION = vec3(fres);

// Dissolve (spatial)
uniform sampler2D noise; uniform float threshold : hint_range(0,1) = 0.0;
if (texture(noise, UV).r < threshold) discard;

// Scrolling UV (canvas_item)
COLOR = texture(TEXTURE, UV + vec2(TIME * 0.1, 0.0));
```

## ShaderMaterial vs ShaderInclude

- Wrap a `Shader` in a `ShaderMaterial` and assign to a mesh/Control
  (godot-mcp-x `assign_shader`). Reuse code via `.gdshaderinc` + `#include`.
- For node-graph authoring use `VisualShader` (e.g. `VisualShaderNodeSDFRaymarch`,
  `VisualShaderNodeParticleAccelerator`).

## 4.7 notes

- **Inline shader previews** in the script/text editor (live effect while editing).
- Shader **preprocessor** condition parsing was tightened (some previously-loose
  `#if` expressions now error).
- Renderer matters: `forward_plus` exposes the full feature set; `mobile` /
  `gl_compatibility` lack some (SDFGI/SSIL/volumetric — see
  [07-rendering-materials-lighting.md](07-rendering-materials-lighting.md)).

## Gotchas

- First line MUST be `shader_type …`.
- Mark color uniforms/textures `: source_color` or they render too dark/bright
  (sRGB vs linear).
- `TIME` is seconds since start; multiply for speed.
- `discard` for alpha-cutout; for blending set `render_mode blend_mix` + write `ALPHA`.
