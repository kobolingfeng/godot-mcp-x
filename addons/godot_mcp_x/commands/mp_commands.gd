@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## High-level multiplayer scaffolding (editor, undoable): MultiplayerSpawner and
## MultiplayerSynchronizer with a built SceneReplicationConfig — the fiddly setup
## people usually hand-write. Peer setup / authority / live state are RUNTIME
## tools (see runtime_bridge.gd).


func get_commands() -> Dictionary:
	return {
		"add_multiplayer_spawner": _add_spawner,
		"add_multiplayer_synchronizer": _add_synchronizer,
	}


func _add_spawner(params: Dictionary) -> Dictionary:
	var parent := resolve_node(opt_str(params, "parent_path", "."))
	if parent == null:
		return fail_no_node(opt_str(params, "parent_path", "."))
	var sp := MultiplayerSpawner.new()
	sp.name = opt_str(params, "name", "MultiplayerSpawner")
	var added: Array = []
	for scene in opt_array(params, "scenes"):
		var s := str(scene)
		if ResourceLoader.exists(s):
			sp.add_spawnable_scene(s)
			added.append(s)
	add_node_undoable(parent, sp, "Add MultiplayerSpawner")
	# spawn_path is relative to the spawner; default to its parent (the level root).
	var target := resolve_node(opt_str(params, "spawn_path", ""))
	sp.spawn_path = sp.get_path_to(target) if target != null else NodePath("..")
	return success({"path": rel_path(sp), "spawn_path": String(sp.spawn_path), "spawnable_scenes": added})


func _add_synchronizer(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	var sync := MultiplayerSynchronizer.new()
	sync.name = opt_str(params, "name", "MultiplayerSynchronizer")
	var spawn := opt_bool(params, "spawn", true)
	var cfg := SceneReplicationConfig.new()
	var props: Array = []
	for p in opt_array(params, "properties"):
		var ps := str(p)
		var np := NodePath(ps if (":" in ps) else ".:" + ps)
		cfg.add_property(np)
		cfg.property_set_spawn(np, spawn)
		cfg.property_set_replication_mode(np, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		props.append(String(np))
	sync.replication_config = cfg
	if has_key(params, "interval"):
		sync.replication_interval = float(params["interval"])
	add_node_undoable(node, sync, "Add MultiplayerSynchronizer")
	sync.root_path = NodePath("..")  # replicate the parent (target) node's listed properties
	return success({"path": rel_path(sync), "replicated": props})
