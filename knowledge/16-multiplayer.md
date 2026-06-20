# Multiplayer & Networking (Godot 4.7)

High-level networking on `MultiplayerAPI` (default impl `SceneMultiplayer`). All
classes below are **✅ verified** on 4.7.

## Peers & setup

`MultiplayerPeer` ✅ implementations:
- `ENetMultiplayerPeer` ✅ — UDP, the default for desktop/most games.
- `WebSocketMultiplayerPeer` ✅ — web builds / firewalls.
- `WebRTCMultiplayerPeer` ✅ — browser P2P.
- `OfflineMultiplayerPeer` ✅ — single-player stand-in.

```gdscript
# Host
var peer := ENetMultiplayerPeer.new()
peer.create_server(7777, 32)            # port, max clients
multiplayer.multiplayer_peer = peer

# Client
var peer := ENetMultiplayerPeer.new()
peer.create_client("127.0.0.1", 7777)
multiplayer.multiplayer_peer = peer

# Useful signals on `multiplayer` (SceneMultiplayer):
multiplayer.peer_connected.connect(func(id): print("joined ", id))
multiplayer.peer_disconnected.connect(func(id): ...)
# IDs: 1 = server; multiplayer.get_unique_id(); multiplayer.is_server()
```

## RPCs (`@rpc`)

```gdscript
@rpc("any_peer", "call_local", "reliable")
func say(msg: String) -> void:
    print(msg)

# call on all peers:
say.rpc("hello")
# call on one peer:
say.rpc_id(target_id, "hi")
```
`@rpc(mode, sync, transfer, channel)`:
- mode: `authority` (only the node's authority may call) | `any_peer`
- sync: `call_local` (also run on the caller) | `call_remote` (default)
- transfer: `reliable` | `unreliable` | `unreliable_ordered`

## Authority

Each node has a **multiplayer authority** (default = server, peer 1):
```gdscript
$Player.set_multiplayer_authority(peer_id)   # e.g. the owning client
if is_multiplayer_authority():               # only the owner runs input
    velocity = read_input()
```

## Scene replication (no manual RPCs)

- **`MultiplayerSpawner`** ✅ — auto-spawns/despawns instances on clients when the
  server adds/removes them under a watched path. Set `spawn_path` + the spawnable
  scenes.
- **`MultiplayerSynchronizer`** ✅ — auto-syncs a configured set of properties
  (position, health, …) from the authority to everyone, via a
  **`SceneReplicationConfig`** ✅ (the property list + sync/spawn flags).

Typical player scene: `CharacterBody3D` + a child `MultiplayerSynchronizer`
replicating `position`/`rotation`; the server-side `MultiplayerSpawner` spawns one
per joined peer; the owning client has authority and sends input.

## Gotchas

- Set `multiplayer_peer` on **both** ends before any RPC; RPCs to unconnected peers
  silently drop.
- An RPC method name + signature must exist **identically** on every peer.
- Don't trust clients: validate authority server-side for anything important
  (movement, damage) — `@rpc("authority")` + server checks.
- `multiplayer.get_remote_sender_id()` inside an RPC tells you who called.
- Synchronizer replicates from authority → others; set authority correctly or
  values won't propagate.
