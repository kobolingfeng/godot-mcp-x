# Rendering, Materials & Lighting (4.7)

Property names ✅ verified against the live 4.7 ClassDB.

## Materials: `StandardMaterial3D` (props live on `BaseMaterial3D`)

> ⚠️ `ClassDB.class_get_property_list("StandardMaterial3D", true)` is **empty** —
> every material property is defined on the parent **`BaseMaterial3D`**. Query
> that class (or with inheritance) to see them.

Key `BaseMaterial3D` properties:
- **Albedo**: `albedo_color: Color`, `albedo_texture: Texture2D`
- **PBR**: `metallic: float` (0–1), `metallic_specular`, `roughness: float`,
  `metallic_texture`, `roughness_texture`
- **Emission**: `emission_enabled: bool`, `emission: Color`,
  `emission_energy_multiplier: float`, `emission_texture`
- **Normal map**: `normal_enabled: bool`, `normal_texture`, `normal_scale`
- **Transparency**: `transparency` (enum: Disabled/Alpha/AlphaScissor/AlphaHash/Depth),
  `alpha_scissor_threshold`
- **Misc**: `cull_mode` (Back/Front/Disabled), `shading_mode`
  (PerPixel/PerVertex/Unshaded), `rim_enabled`, `clearcoat_enabled`,
  `texture_filter`, `uv1_scale: Vector3`
- ORM workflow: use `ORMMaterial3D` (ao/roughness/metallic packed in one texture).

In godot-mcp-x: `set_material {path, albedo, metallic, roughness, emission}`
builds a StandardMaterial3D override; for shaders use `assign_shader` +
`set_shader_param`.

## Lights — `Light3D` base (inherited by all)

`light_color: Color`, `light_energy: float`, `light_indirect_energy`,
`light_specular`, `shadow_enabled: bool`, `light_bake_mode`, `light_cull_mask`.

- **`DirectionalLight3D`** ✅: `directional_shadow_mode`,
  `directional_shadow_max_distance`, `directional_shadow_split_1..3`,
  `directional_shadow_blend_splits`, `sky_mode`. (Sun; rotation = direction.)
- **`OmniLight3D`** ✅: `omni_range`, `omni_attenuation`, `omni_shadow_mode`. (Point light.)
- **`SpotLight3D`** ✅: `spot_range`, `spot_angle`, `spot_angle_attenuation`,
  `spot_attenuation`. (Cone.)
- **`AreaLight3D`** ✅ (**NEW in 4.7**): rectangular real-time area light.
  `area_size: Vector2`, `area_range`, `area_attenuation`,
  `area_normalize_energy`, `area_texture`. Use instead of faking soft rect lights.

godot-mcp-x: `setup_light {kind: directional|omni|spot, energy, color}`.

## Environment & sky — `WorldEnvironment` holds an `Environment`

Key `Environment` properties ✅ (grouped):
- **Background**: `background_mode` (ClearColor/Color/Sky/Canvas/Keep),
  `background_color`, `background_energy_multiplier`, `sky`, `sky_rotation`
- **Ambient**: `ambient_light_source`, `ambient_light_color`,
  `ambient_light_energy`, `ambient_light_sky_contribution`
- **Tonemap** (matters for HDR look): `tonemap_mode`
  (Linear/Reinhard/Filmic/ACES/AgX), `tonemap_exposure`, `tonemap_white`,
  `tonemap_agx_white`, `tonemap_agx_contrast`
- **Post FX**: `glow_enabled` + `glow_intensity`/`glow_bloom`/`glow_hdr_threshold`,
  `ssao_enabled` + `ssao_radius`/`ssao_intensity`, `ssil_enabled`, `ssr_enabled`
- **GI**: `sdfgi_enabled` + `sdfgi_cascades`/`sdfgi_max_distance`/`sdfgi_energy`
- **Fog**: `fog_enabled` + `fog_density`/`fog_light_color`/`fog_mode`;
  `volumetric_fog_enabled` + `volumetric_fog_density`/`volumetric_fog_albedo`
- **Adjustments**: `adjustment_enabled` + brightness/contrast/saturation/color_correction

For a procedural sky: `Environment.background_mode = BG_SKY`, `env.sky = Sky.new()`,
`sky.sky_material = ProceduralSkyMaterial.new()`. (godot-mcp-x: `setup_environment`.)

## 4.7 rendering features

- **HDR output** (2D & 3D) on Windows/macOS/iOS/visionOS/Linux-Wayland — pairs
  with the AgX/Filmic tonemappers above for proper highlight rolloff.
- **Nearest-neighbor viewport scaling** — crisp pixel-art upscaling without blur
  (viewport scaling mode), distinct from the bilinear default.
- Renderers: `rendering/renderer/rendering_method` ∈ `forward_plus` (desktop),
  `mobile`, `gl_compatibility`. `forward_plus` supports the full feature set above;
  `mobile`/`gl_compatibility` drop some (no SDFGI/SSIL/volumetric fog).
