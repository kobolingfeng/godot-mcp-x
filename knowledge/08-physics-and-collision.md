# Physics & Collision (4.7)

Property names ✅ verified against the live 4.7 ClassDB.

## Body types — which to use

| Node | Use for | Moves by |
|---|---|---|
| `StaticBody3D` | level geometry, walls, floors | never (or `constant_linear_velocity`) |
| `CharacterBody3D` | players, NPCs | code: set `velocity`, call `move_and_slide()` |
| `RigidBody3D` | physics-driven props, debris | the physics engine (forces/impulses) |
| `Area3D` | triggers, detection, overrides | n/a (detects overlaps) |
| `AnimatableBody3D` | moving platforms (animation-driven) | animation/code, pushes bodies |

Every body needs a `CollisionShape3D` (or `CollisionPolygon3D`) child with a
`shape` (`BoxShape3D`/`SphereShape3D`/`CapsuleShape3D`/`CylinderShape3D`/
`ConvexPolygonShape3D`/`ConcavePolygonShape3D` for static meshes).
godot-mcp-x: `setup_collision_shape {path, shape}`.

## Collision layers & masks (the #1 confusion)

- `collision_layer` = "what layers am I **on**".
- `collision_mask` = "what layers do I **scan for**".
- A detects B only if `A.mask` includes a layer in `B.layer`. Both are 32-bit
  bitmasks (`1 << (n-1)` for layer n).
- Name layers in **Project Settings → Layer Names → 3D Physics**
  (`layer_names/3d_physics/layer_N`). godot-mcp-x: `set_physics_layer_name`,
  `set_collision_layers {path, layer, mask}`, `get_collision_info`.

## CharacterBody3D essentials ✅

`velocity: Vector3`, `motion_mode` (Grounded/Floating), `up_direction`,
`floor_max_angle`, `floor_snap_length`, `floor_stop_on_slope`,
`floor_block_on_wall`, `platform_on_leave`, `wall_min_slide_angle`, `safe_margin`.

```gdscript
func _physics_process(delta):
    if not is_on_floor(): velocity += get_gravity() * delta
    move_and_slide()                       # no args in 4.x
    # post-move queries:
    if is_on_wall(): ...
    for i in get_slide_collision_count():
        var c := get_slide_collision(i)    # KinematicCollision3D
```

## RigidBody3D essentials ✅

`mass`, `gravity_scale`, `physics_material_override` (`PhysicsMaterial`:
friction/bounce), `linear_velocity`, `angular_velocity`, `linear_damp`,
`angular_damp`, `lock_rotation`, `freeze` + `freeze_mode`, `continuous_cd`,
`contact_monitor` + `max_contacts_reported` (needed for `body_entered`),
`center_of_mass_mode`, `can_sleep`.

Apply forces in `_physics_process` / `_integrate_forces`:
`apply_central_impulse(v)`, `apply_force(f, pos)`, `apply_torque_impulse(t)`.

## Area3D — triggers & overrides ✅

`monitoring`, `monitorable`, `priority`, plus gravity/damp overrides
(`gravity_space_override`, `gravity`, `gravity_point`, `linear_damp`, …) and audio
reverb/bus routing. Signals: `body_entered(body)`, `body_exited`,
`area_entered(area)`, `area_exited`.

```gdscript
$Hitbox.body_entered.connect(func(b):
    if b.is_in_group("enemies"): b.take_damage(10))
```

## Raycasting

- Node: `RayCast3D` (`target_position`, `enabled`; query `is_colliding()`,
  `get_collider()`, `get_collision_point()`, `get_collision_normal()`).
- One-shot from code:
```gdscript
var space := get_world_3d().direct_space_state
var q := PhysicsRayQueryParameters3D.create(from, to)
q.collision_mask = 1
var hit := space.intersect_ray(q)   # {} if nothing; else {collider, position, normal, …}
```

## Tuning

`physics/common/physics_ticks_per_second` (default 60). Heavy scenes:
prefer fewer `contact_monitor` bodies, simple collision shapes (box/sphere/capsule
over concave), and `continuous_cd` only on fast small objects.
