@tool
extends Node

## WebSocket client that dials every MCP server instance on ports 6605-6609.
## Topology is reversed on purpose: each MCP/Claude session is a WS *server* on
## its own port, and this one editor connects out to all of them — so multiple
## sessions can drive the same editor concurrently.

signal command_completed(method: String, ok: bool, source_port: int)

var router: Node

const BASE_PORT := 6605
const MAX_PORT := 6609
const RECONNECT_INTERVAL := 3.0
const BUFFER_SIZE := 16 * 1024 * 1024 # 16 MB — large scene/script payloads
const PING_INTERVAL := 5.0
const INACTIVITY_TIMEOUT := 30.0

var _peers: Dictionary = {}        # port -> WebSocketPeer
var _connected: Dictionary = {}    # port -> bool
var _reconnect: Dictionary = {}    # port -> float countdown
var _idle: Dictionary = {}         # port -> seconds since last inbound
var _ping: Dictionary = {}         # port -> seconds since last ping
var _running := false


func start() -> void:
	_running = true
	for p in range(BASE_PORT, MAX_PORT + 1):
		_connected[p] = false
		_reconnect[p] = 0.0
		_try_connect(p)
	print("[MCP-X] WS client dialing ports %d-%d" % [BASE_PORT, MAX_PORT])


func stop() -> void:
	_running = false
	for p in _peers:
		var ws: WebSocketPeer = _peers[p]
		if ws:
			ws.close(1000, "Plugin shutting down")
	_peers.clear()
	_connected.clear()
	_reconnect.clear()
	_idle.clear()
	_ping.clear()


func connected_count() -> int:
	var n := 0
	for p in _connected:
		if _connected[p]:
			n += 1
	return n


func get_connected_ports() -> Array:
	var out: Array = []
	for p in range(BASE_PORT, MAX_PORT + 1):
		if _connected.get(p, false):
			out.append(p)
	return out


func _try_connect(p: int) -> void:
	var ws := WebSocketPeer.new()
	ws.outbound_buffer_size = BUFFER_SIZE
	ws.inbound_buffer_size = BUFFER_SIZE
	if ws.connect_to_url("ws://127.0.0.1:%d" % p) == OK:
		_peers[p] = ws
	else:
		_peers[p] = null


func _process(delta: float) -> void:
	if not _running:
		return

	for p in range(BASE_PORT, MAX_PORT + 1):
		var ws: WebSocketPeer = _peers.get(p)

		if ws == null:
			_reconnect[p] = _reconnect.get(p, 0.0) + delta
			if _reconnect[p] >= RECONNECT_INTERVAL:
				_reconnect[p] = 0.0
				_try_connect(p)
			continue

		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if not _connected.get(p, false):
					_connected[p] = true
					_idle[p] = 0.0
					_ping[p] = 0.0
					ws.send_text(JSON.stringify({"jsonrpc": "2.0", "method": "hello", "params": {"role": "editor"}}))
					print_verbose("[MCP-X] Connected on port %d" % p)
				else:
					_idle[p] = _idle.get(p, 0.0) + delta
					_ping[p] = _ping.get(p, 0.0) + delta

				var got := false
				while ws.get_available_packet_count() > 0:
					var text := ws.get_packet().get_string_from_utf8()
					got = true
					_dispatch(text, p)
				if got:
					_idle[p] = 0.0

				if _idle.get(p, 0.0) > INACTIVITY_TIMEOUT:
					push_warning("[MCP-X] Port %d silent %.0fs — reconnecting" % [p, _idle[p]])
					ws.close(4000, "Heartbeat timeout")
					_connected[p] = false
					_peers[p] = null
					_reconnect[p] = 0.0
					continue

				if _ping.get(p, 0.0) >= PING_INTERVAL:
					_ping[p] = 0.0
					ws.send_text(JSON.stringify({"jsonrpc": "2.0", "method": "ping", "params": {}}))

			WebSocketPeer.STATE_CLOSED:
				if _connected.get(p, false):
					_connected[p] = false
					print_verbose("[MCP-X] Disconnected from port %d" % p)
				_peers[p] = null
				_reconnect[p] = 0.0


func _send(p: int, text: String) -> void:
	var ws: WebSocketPeer = _peers.get(p)
	if ws and _connected.get(p, false):
		ws.send_text(text)


func _dispatch(text: String, port: int) -> void:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		_respond(port, null, null, {"code": -32700, "message": "Parse error"})
		return

	var msg: Dictionary = json.data
	var method: String = msg.get("method", "")

	if method == "ping":
		_send(port, JSON.stringify({"jsonrpc": "2.0", "method": "pong", "params": {}}))
		return
	if method == "pong":
		return

	var id: Variant = msg.get("id")
	var params: Dictionary = msg.get("params", {})

	if method == "":
		_respond(port, id, null, {"code": -32600, "message": "Missing method"})
		return
	if router == null:
		_respond(port, id, null, {"code": -32603, "message": "No router"})
		return

	_run.call_deferred(port, id, method, params)


func _run(port: int, id: Variant, method: String, params: Dictionary) -> void:
	var res: Dictionary = await router.execute(method, params)
	if res.has("error"):
		_respond(port, id, null, res["error"])
		command_completed.emit(method, false, port)
	else:
		_respond(port, id, res.get("result", {}), null)
		command_completed.emit(method, true, port)


func _respond(port: int, id: Variant, result: Variant, err: Variant) -> void:
	var r: Dictionary = {"jsonrpc": "2.0", "id": id}
	if err != null:
		r["error"] = err
	else:
		r["result"] = result if result != null else {}
	_send(port, JSON.stringify(r))
