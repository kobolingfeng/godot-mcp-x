@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"setup_navigation_region": _setup_region,
		"setup_navigation_agent": _setup_agent,
		"bake_navigation_mesh": _bake,
		"get_navigation_info": _info,
	}


func _setup_region(params: Dictionary) -> Dictionary:
	var parent := resolve_node(opt_str(params, "parent_path", "."))
	if parent == null:
		return fail("Parent not found")
	var region := NavigationRegion3D.new()
	region.name = opt_str(params, "name", "NavigationRegion3D")
	region.navigation_mesh = NavigationMesh.new()
	add_node_undoable(parent, region, "Add NavigationRegion3D")
	return success({"path": rel_path(region)})


func _setup_agent(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail("Node not found: %s" % req_str(params, "path"))
	var agent := NavigationAgent3D.new()
	agent.name = "NavigationAgent3D"
	if has_key(params, "radius"):
		agent.radius = float(params["radius"])
	add_node_undoable(node, agent, "Add NavigationAgent3D")
	return success({"path": rel_path(agent)})


func _bake(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null or not (node is NavigationRegion3D):
		return fail("NavigationRegion3D not found at: %s" % req_str(params, "path"))
	var region := node as NavigationRegion3D
	if region.navigation_mesh == null:
		region.navigation_mesh = NavigationMesh.new()
	region.bake_navigation_mesh()
	return success({"path": rel_path(region), "baking": true})


func _info(_params: Dictionary) -> Dictionary:
	var root := edited_root()
	if root == null:
		return fail("No scene is currently open")
	var regions: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is NavigationRegion3D:
			regions.append({"path": rel_path(n), "has_mesh": (n as NavigationRegion3D).navigation_mesh != null})
		for c in n.get_children():
			stack.append(c)
	return success({"regions": regions, "count": regions.size()})
