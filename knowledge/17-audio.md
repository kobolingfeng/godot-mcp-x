# Audio (Godot 4.7)

All classes/methods below are **✅ verified** on 4.7. godot-mcp-x tools:
`add_audio_player`, `list_audio_buses`, `add_audio_bus`, `set_bus_volume`,
`add_bus_effect`.

## Players (nodes)

- `AudioStreamPlayer` ✅ — non-positional (music, UI).
- `AudioStreamPlayer2D` ✅ — positional in 2D (attenuates by distance/pan).
- `AudioStreamPlayer3D` ✅ — positional in 3D (needs an `AudioListener3D` ✅, else
  the current `Camera3D` is the listener).

Key API (`AudioStreamPlayer`): `stream`, `play(from_pos)`, `stop()`, `seek()`,
`is_playing()`, `playing`, `autoplay`, `bus`, `volume_db`, **`volume_linear`**
(4.4+, 0–1), `pitch_scale`, `max_polyphony` (overlapping plays), `stream_paused`,
`playback_type`. 3D adds `unit_size`, `max_distance`, `attenuation_model`,
`panning_strength`.

```gdscript
$Sfx.stream = preload("res://hit.ogg")
$Sfx.bus = "SFX"
$Sfx.play()
# overlap multiple shots from one node:
$Sfx.max_polyphony = 8
```

## Stream types

- Imported assets: `.ogg` (AudioStreamOggVorbis), `.wav`, `.mp3`.
- `AudioStreamPolyphonic` ✅ — fire many one-shots from a single player via its
  playback object (great for SFX without spawning nodes).
- `AudioStreamInteractive` ✅ — adaptive music: named clips + transitions.
- `AudioStreamSynchronized` ✅ — play several streams locked in sync (stems/layers).
- `AudioStreamRandomizer` — randomize clip/pitch/volume per play (variation).

## Buses, mixing, effects

Buses route audio (Master + your own like Music/SFX/UI). Manage via `AudioServer`:
`add_bus`, `set_bus_name`, `set_bus_volume_db(idx, db)`, `set_bus_send`,
`add_bus_effect(idx, effect)`, `set_bus_mute/solo`. Persist by saving the bus
layout (`AudioServer.generate_bus_layout()` → the project's
`audio/buses/default_bus_layout` path) — godot-mcp-x's bus tools do this for you.

Effects: `AudioEffectReverb` ✅, Delay, Distortion, EQ6/10/21, Compressor,
Limiter, Chorus, Phaser, `AudioEffectCapture` ✅ (read the bus's audio buffer for
visualizers / voice), SpectrumAnalyzer (note: fixed in 4.7 — output may differ).

```gdscript
var i := AudioServer.get_bus_index("Master")
AudioServer.set_bus_volume_db(i, linear_to_db(0.5))   # -6 dB ≈ half volume
```

## Gotchas

- **dB vs linear**: `volume_db` is logarithmic (0 = unchanged, −80 ≈ silent).
  Use `volume_linear` (4.4+) or `linear_to_db()` / `db_to_linear()` for 0–1 math.
- 3D audio needs a listener (camera or `AudioListener3D`); 4.7 corrected
  multi-viewport 3D volume calc (*possible behavior change*).
- One `AudioStreamPlayer` plays one stream at a time unless `max_polyphony` > 1.
- Latency: query `AudioServer.get_output_latency()` /
  `Performance.AUDIO_OUTPUT_LATENCY` for rhythm games; schedule with
  `AudioServer.get_time_to_next_mix()` + `get_output_latency()`.
