# Common Godot 4.7 GDScript gameplay patterns

Copy-paste-correct snippets for the things AI writes most. All 4.x/4.7-correct
(verified against the live ClassDB where noted).

## CharacterBody3D movement (✅ API verified)

`velocity` is a property; `move_and_slide()` takes **no arguments** in 4.x.

```gdscript
extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta          # get_gravity() since 4.3
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
    velocity.x = dir.x * speed
    velocity.z = dir.z * speed
    move_and_slide()
```

## CharacterBody2D movement

```gdscript
extends CharacterBody2D
@export var speed := 200.0
func _physics_process(delta: float) -> void:
    velocity = Input.get_vector("ui_left","ui_right","ui_up","ui_down") * speed
    move_and_slide()
```

## Signals

```gdscript
signal health_changed(current: int, max: int)
signal died

func take_damage(n: int) -> void:
    hp -= n
    health_changed.emit(hp, max_hp)
    if hp <= 0:
        died.emit()

# elsewhere:
enemy.died.connect(_on_enemy_died)
enemy.health_changed.connect(func(cur, mx): bar.value = float(cur) / mx)
```

## Autoload singleton (global state)

Register via project settings (autoload/), then access by name anywhere:

```gdscript
# res://game_state.gd  (autoload name "GameState")
extends Node
var score: int = 0
signal score_changed(value: int)
func add_score(n: int) -> void:
    score += n
    score_changed.emit(score)

# anywhere:
GameState.add_score(10)
```

## Timers & await

```gdscript
await get_tree().create_timer(1.5).timeout      # one-off delay
await get_tree().process_frame                   # wait a frame

# repeating Timer node:
$Timer.wait_time = 2.0
$Timer.timeout.connect(_spawn)
$Timer.start()
```

## Spawn / instance a scene

```gdscript
@export var bullet_scene: PackedScene
func shoot() -> void:
    var b := bullet_scene.instantiate()
    b.global_position = $Muzzle.global_position
    get_tree().current_scene.add_child(b)
```

## Groups (tag & query many nodes)

```gdscript
add_to_group("enemies")
for e in get_tree().get_nodes_in_group("enemies"):
    e.alert(player.global_position)
get_tree().call_group("enemies", "reset")
```

## Driving an AnimationTree state machine

```gdscript
@onready var sm: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
func _process(_d):
    if velocity.length() > 0.1:
        sm.travel("run")
    else:
        sm.travel("idle")
# blend params: $AnimationTree.set("parameters/Move/blend_position", input_vec)
```

## Area3D detection

```gdscript
func _ready() -> void:
    $Hitbox.body_entered.connect(_on_body_entered)   # Area3D signal
func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("enemies"):
        body.take_damage(10)
```

## Gotchas

- `move_and_slide()` — no args (4.x); set `velocity` first.
- `@onready var n := $Path` resolves at ready; bare `$Path` at top level is too early.
- Connect with a `Callable` (`node.sig.connect(_method)`), never the old string form.
- Typed loop vars when iterating typed arrays: `for e: Node in arr:`.
