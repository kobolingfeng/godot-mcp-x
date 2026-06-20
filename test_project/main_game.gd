extends Node3D

## Tiny driver scene for runtime-bridge end-to-end tests: a property that changes
## every frame so get/set_game_node_property are observable.
var ticks: int = 0


func _process(_delta: float) -> void:
	ticks += 1
