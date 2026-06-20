# Navigation & Pathfinding (Godot 4.7)

Server-based navmesh pathfinding + avoidance. All classes **✅ verified** on 4.7.
godot-mcp-x tools: `setup_navigation_region`, `setup_navigation_agent`,
`bake_navigation_mesh`, `get_navigation_info` (3D).

## Pieces

- **`NavigationRegion3D`** ✅ — holds a baked `NavigationMesh` (the walkable area).
  Bake from scene geometry: `bake_navigation_mesh()` (godot-mcp-x
  `bake_navigation_mesh`). Multiple regions auto-stitch if their edges touch.
- **`NavigationAgent3D`** ✅ — pathfinding + local avoidance for one mover. Child of
  the moving body.
- **`NavigationObstacle3D`** ✅ — dynamic obstacle (carve the map or push agents via
  avoidance).
- **`NavigationLink3D`** ✅ — connect disjoint areas (jumps, ladders, teleporters,
  doors) so paths can traverse non-walkable gaps.
- **`NavigationServer3D`** ✅ — low-level queries (e.g. one-off path:
  `NavigationServer3D.map_get_path(map, from, to, optimize)`).
- 2D mirrors: `NavigationRegion2D`/`NavigationAgent2D`/`NavigationServer2D` ✅.

## Agent movement pattern

```gdscript
@onready var agent: NavigationAgent3D = $NavigationAgent3D

func set_target(p: Vector3) -> void:
    agent.target_position = p

func _physics_process(delta: float) -> void:
    if agent.is_navigation_finished():
        return
    var next := agent.get_next_path_position()
    var dir := (next - global_position).normalized()
    velocity = dir * speed
    move_and_slide()
```
Key `NavigationAgent3D`: `target_position`, `get_next_path_position()`,
`is_navigation_finished()`, `path_desired_distance`, `target_desired_distance`,
`avoidance_enabled`, `radius`, `max_speed`, signals `velocity_computed`,
`target_reached`, `navigation_finished`.

## Local avoidance (RVO)

Enable `avoidance_enabled` and feed the agent a desired velocity; consume the
**safe** velocity from `velocity_computed`:
```gdscript
agent.velocity_computed.connect(func(safe): velocity = safe; move_and_slide())
func _physics_process(_d):
    agent.velocity = desired_dir * speed   # agent emits velocity_computed with a collision-avoided vector
```

## Tips & gotchas

- **Rebake** the region after changing level geometry, or paths ignore new walls.
- Agents need a valid map (a region present & baked) or `get_next_path_position`
  returns the current position (no movement).
- Tune navmesh bake **agent radius/height** to your character, or it hugs walls or
  fails to fit corridors.
- Watch `Performance.NAVIGATION_AGENT_COUNT` / `NAVIGATION_REGION_COUNT`.
- For huge crowds, drive agents off the `NavigationServer3D` directly rather than
  one node each.
