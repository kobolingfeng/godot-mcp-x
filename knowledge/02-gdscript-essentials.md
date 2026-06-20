# GDScript 4.x Essentials (for correct codegen)

The patterns an AI most often gets wrong. All apply to 4.7.

## Typing

```gdscript
var hp: int = 100
var speed := 5.0                     # inferred float
@export var title: String = ""
@export var target: Node3D           # typed, shows a node picker in inspector

# Typed collections (typed Dictionary since 4.4)
var names: Array[String] = []
var scores: Dictionary[String, int] = {}

# Typed for-loops — ALWAYS annotate the loop var when the array is typed,
# otherwise you get inference warnings/errors:
for n: String in names:
    print(n)
```

## Callables are first-class

```gdscript
var cb := _on_pressed            # bare method name → Callable (no quotes!)
button.pressed.connect(cb)
button.pressed.connect(_on_pressed)
callable.call(arg1, arg2)
# Avoid the legacy string form connect("pressed", self, "_on_pressed") — removed in 4.x.
```

## await works on signals AND plain values

```gdscript
await get_tree().process_frame            # signal
await get_tree().create_timer(1.0).timeout
var result = await some_coroutine()        # coroutine
# Awaiting a NON-coroutine value just returns it immediately — so generic
# dispatch code can `await handler.call(p)` whether or not the handler yields.
```

## Lambdas (capture by value)

```gdscript
var add := func(a: int, b: int) -> int: return a + b
var n := 10
var f := func(): return n + 1            # captures n
arr.filter(func(x): return x > 0)
```

## Signals

```gdscript
signal died
signal damaged(amount: int)
died.emit()
damaged.emit(25)
node.damaged.connect(_on_damaged)
# For connections that must be SAVED with the scene, use CONNECT_PERSIST:
emitter.connect("some_signal", Callable(receiver, "method"), CONNECT_PERSIST)
```

## Variant <-> string round-trip (very useful for tooling/serialization)

```gdscript
var_to_str(Vector3(1, 2, 3))   # -> "Vector3(1, 2, 3)"
str_to_var("Vector3(1, 2, 3)") # -> Vector3(1, 2, 3)
str_to_var("true")             # -> true (bool)
str_to_var("42")               # -> 42 (int)
str_to_var("hello")            # -> null  ← plain text is NOT valid; handle null!
```
This is exactly how godot-mcp-x accepts string-encoded property values like
`"Color(1,0,0,1)"`. Always treat a `null` from `str_to_var` as "keep the string".

## @tool and editor execution

```gdscript
@tool                 # run this script in the EDITOR too (required for plugins
extends EditorPlugin  # and for code that should affect the edited scene)
```
- In `@tool` scripts, `EditorInterface` is a global (4.3+): call it directly.
- `ClassDB.instantiate("Node3D")` makes a node by class name; you MUST `free()`
  any throwaway instance you create (Nodes are not ref-counted).

## Common type errors to avoid

- Assigning a `void`-returning call to a variable (see
  [04-api-gotchas.md](04-api-gotchas.md): `save_scene_as` returns void).
- Forgetting `: Type` on typed for-loop vars.
- Using `.property` on a possibly-null Object — use `obj.get("property")` for
  safe dynamic access in generated/eval'd code.
- Nested `func` inside `func` — not allowed; use a lambda instead.
