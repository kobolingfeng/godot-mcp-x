# Recipes — common task → exact tool sequence

Practical "to do X, call these." Assumes the daemon is running (`godot-x daemon`)
and a project's editor/game is connected. CLI shown; MCP tool names are identical.

## Onboard a project
```
godot-x setup  --project D:/path/to/MyGame   # copy addon + autoload + enable plugin
godot-x doctor --project D:/path/to/MyGame   # verify install + connection
```

## Build a UI / subtree in ONE undoable call
Instead of many add_node/set_property round-trips:
```
godot-x build_tree --tree '{"type":"CanvasLayer","name":"HUD","children":[
  {"type":"Label","name":"Score","properties":{"text":"0","position":"Vector2(16,12)"}},
  {"type":"VBoxContainer","name":"Menu","children":[{"type":"Button","name":"Play"}]}
]}'
```
One `Ctrl+Z` removes the whole subtree. Property values can be inline resources,
and nodes can wire signals — enough to build a *functional* node in one call:
```
godot-x build_tree --tree '{"type":"CharacterBody2D","name":"Player","children":[
  {"type":"CollisionShape2D","properties":{"shape":{"_res":"CircleShape2D","properties":{"radius":16}}}},
  {"type":"Timer","name":"Tick","signals":[{"signal":"timeout","to":".","method":"_on_tick"}]}
]}'
```

## Iterate on game logic without restarting
```
# edit res://scripts/enemy.gd on disk, then:
godot-x reload_game_script --path res://scripts/enemy.gd
```

## Catch a transient one-shot effect in a screenshot
```
godot-x get_game_screenshot --run 'get_tree().get_first_node_in_group("player")._fire_nova()' --after 0.05 --save_path user://fx.png
godot-x get_game_screenshot --count 8 --interval 0.06 --save_path user://burst.png   # or a burst
```

## Drive / hold input in the live game
```
godot-x simulate_key --key D --mode press     # hold right (auto-releases after 10s safety)
godot-x simulate_key --key D --mode release   # let go
godot-x simulate_action --action jump          # tap (press+release)
```

## Hot-tweak live state
```
godot-x get_game_node_properties --path Player
godot-x set_game_node_property --path Player --property speed --value 400
godot-x call_game_method --path Player --method add_xp --args '[150]'
godot-x execute_game_script --code 'get_tree().get_first_node_in_group("player").hp = 999'
```

## Run + look loop
```
godot-x play_scene
godot-x get_game_info
godot-x get_game_screenshot --save_path user://shot.png   # then read the PNG
godot-x stop_scene
```

## Find things
```
godot-x find_nodes --type Light3D            # editor scene
godot-x find_game_nodes --group enemies       # running game
```

## Inspect the engine when unsure of an API
```
godot-x describe_class --name CharacterBody2D   # methods + signatures
godot-x list_classes --filter Light
```

## Health / multi-instance
```
godot-x status                  # daemon? editor/runtime? concurrent_replaces?
godot-x daemon --keep first     # lock to the first Godot; reject stray instances
```
