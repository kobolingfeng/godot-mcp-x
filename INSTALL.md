# Installing godot-mcp-x

## 1. Build the server

```bash
cd D:/GodotProjects/godot-mcp-x/server
npm install
npm run build      # compiles src/ -> build/
```

## 2. Install the editor addon into your game project

Copy the addon into the project you want to drive:

```bash
# from the repo root, replacing <YOUR_PROJECT> with your game's folder
cp -r addon/godot_mcp_x <YOUR_PROJECT>/addons/godot_mcp_x
```

Then in the Godot editor: **Project → Project Settings → Plugins** → enable
**Godot MCP X**. The Output panel should print:

```
[MCP-X] Plugin enabled — dialing ws://127.0.0.1:6605-6609
[MCP-X] Registered 142 commands
```

(It will retry the dial every 3s until the MCP server is running — that's normal.)

## 3. Register the MCP server with your client

Point your MCP client at the built entry. The included [.mcp.json](.mcp.json)
already does this:

```json
{
  "mcpServers": {
    "godot-mcp-x": {
      "command": "node",
      "args": ["D:/GodotProjects/godot-mcp-x/server/build/index.js"]
    }
  }
}
```

- For Claude Code: place this in the project's `.mcp.json` (or merge into your
  global MCP config), then restart the client so it spawns the server.
- Optional: set `GODOT_MCP_X_PORT=6605` to pin a fixed port instead of scanning.

## 4. Verify

With the editor open and the plugin enabled, ask the client to call
`get_project_info` — you should get your project's metadata back. If it reports
"Godot editor is not connected", confirm the plugin is enabled and the server is
running on a port in 6605-6609.

## Coexistence with godot-mcp-pro

godot-mcp-x uses ports **6605-6609**; godot-mcp-pro uses **6505-6514**. Both can
be installed and enabled at once without conflict.

## Rebuilding after changes

- Server (TypeScript): `npm run build` (or `npm run watch`).
- Addon (GDScript): use `reload_scripts`, or toggle the plugin off/on, or
  restart the editor.
