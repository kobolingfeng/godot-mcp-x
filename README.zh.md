# godot-mcp-x

[English](README.md) · **简体中文**

> **❤️ 赞赏支持 / Support** — 如果这个项目帮你省了时间,欢迎赞赏支持,非常感谢!🙏
> **PayPal**: [paypal.me/koboling](https://paypal.me/koboling) · **微信赞赏** ↓
>
> <img src="docs/wechat-reward.jpg" alt="微信赞赏码" width="220">

面向 AI 驱动 **Godot 4.7** 开发的新一代、**Token 高效** MCP 服务器。纯净内核 + 经实战
检验的命令逻辑,从第一天就围绕 AI agent 真正在意的两件事来设计:**又快又小又正确的
响应**,以及**全面的编辑器 + 运行时控制**。

> 状态:**功能完整、端到端验证** —— **163 个工具 / 27 组**:project、scene、node、
> script、editor、analysis、resource、filesystem、ui、input map、animation、
> animation tree、physics、navigation、3D 构建、gridmap、skeleton、shader、particle、
> audio、tilemap、theme、batch、profiling、export,以及完整的 **runtime**(游戏内
> 实时)通道和**自动化玩法测试**(断言、场景、监视)。已在真实 4.7-stable 上验证
> (**167/167 次往返调用通过**,外加 **23 个单元测试**(含 MCP stdio 冒烟测试))。

## 为什么要做它(对比 godot-mcp-pro)

它最初是对成熟的 `godot-mcp-pro`(172 工具)的研究。那个工具能用,但有两点严重拖累
AI 使用,这里从设计上修掉了:

| 原版的问题 | godot-mcp-x 的修法 |
|---|---|
| 场景树打印**完整编辑器路径**(`/root/@EditorNode@…/SubViewport/Main/…`)→ 一个中等场景 = **7.3 万字符**,直接撑爆 token | 从**被编辑场景根**遍历,输出**场景相对路径**(`Player/Camera3D`)。同一场景 → 几百字符。 |
| 无分页/限制 —— `read_script` 一次吐 6 万字符 | 全面**源头侧分页**:脚本与场景文件 `offset`/`limit`、树 `max_depth`、列表分页,外加 TS 侧预算夹断 |
| `get_node_properties` 返回所有属性 | 默认只返回**改动过(非默认)**的属性;可选 `include_defaults` 或指定 `names[]` |
| 170+ 工具重复同一套 try/catch + JSON.stringify | **声明式工具注册**:统一的错误/预算封装,工具就是纯 数据→数据 处理器 |
| 截图走 base64 传输 | 存成 PNG,返回宿主可直接读取的**绝对路径** |
|(新能力)| **实时 ClassDB 自省**(`list_classes`/`describe_class`,含完整方法签名)—— 4.7 API 真值,保证生成代码正确 |
|(新能力)| **"你是不是想…?"** —— 拼错的类型/属性/方法名**和节点路径**(编辑器**和**运行时)返回相似度建议,减少 agent 重试往返 |
|(新能力)| **编辑器状态面板** + `get_status` 工具 —— 实时显示连接端口、命令数、播放状态 |
|(新能力)| **可撤销编辑** —— 节点 增/删/改名/移动/复制 与属性设置都接入 `EditorUndoRedoManager`,人可以 **Ctrl+Z** 撤销 AI 的改动(另有 `undo`/`redo` 工具) |

MCP 服务器只是个轻量 JSON-RPC 代理;真正的性能在于**载荷大小**和**编辑器侧序列化**
—— 功夫正下在这里。

## 架构

```
 Claude / MCP 客户端 ──stdio──> godot-mcp-x 服务器 (Node/TS)
                                     │  WebSocket 服务器,监听 127.0.0.1:6605-6609
                                     │  JSON-RPC 2.0 · 心跳 · 多会话
                                     │  双角色路由(hello → editor | runtime)
                       ┌─────────────┴──────────────┐
              editor 连接 │                          │ runtime 连接(仅游戏运行时)
                          ▼                          ▼
        Godot 编辑器 + godot_mcp_x 插件       运行中的游戏 + runtime_bridge autoload
        ws_client → router → commands/*.gd    直连 WS → 实时 get_tree()
        EditorInterface · ClassDB · 场景      场景树 · 属性 · 输入 · 帧
```
反转拓扑(服务器监听、编辑器拨入)让多个会话能驱动同一个编辑器。**端口 6605-6609**
刻意与 godot-mcp-pro 的 6505-6514 区分,两者可并存。

## 安装

1. **构建服务器**
   ```bash
   cd server
   npm install
   npm run build
   ```
2. **安装插件** —— 把 `addon/godot_mcp_x/` 复制到你项目的
   `res://addons/godot_mcp_x/`,然后在 **项目 → 项目设置 → 插件 → Godot MCP X** 启用。
   (见 [INSTALL.md](INSTALL.md)。)
3. 在客户端**注册 MCP 服务器**。已附带可直接改的 [.mcp.json](.mcp.json):
   ```json
   { "mcpServers": { "godot-mcp-x": { "command": "node",
       "args": ["D:/GodotProjects/godot-mcp-x/server/build/index.js"] } } }
   ```
4. 打开编辑器。插件会拨号服务器;工具调用即作用于你的实时编辑器。可选
   `GODOT_MCP_X_PORT` 环境变量固定端口。

## CLI(无需 MCP 客户端)

`npm run build` 后,可直接从 shell 驱动编辑器 —— 适合脚本或省 token。与 MCP 服务器
共用同一套处理器 + 传输(可通过包 bin 安装为 `godot-x`)。

```bash
node build/cli.js list [filter]            # 列出工具(可过滤)
node build/cli.js <tool> --help            # 查看某工具的参数
node build/cli.js get_project_info
node build/cli.js add_node --type Sprite2D --name Hero --parent_path .
node build/cli.js set_node_property --path Hero --property position --value "Vector2(100,200)"
node build/cli.js get_scene_tree --max_depth 2
node build/cli.js batch_add_nodes --nodes '[{"type":"Node3D","name":"Lights"}]'
```

参数自动定型(数字/布尔与 JSON `{...}`/`[...]` 会被解析,其余按字符串),并用每个工具
的 Zod schema 校验,拼错/缺必填参数会立刻清晰报错。需要编辑器开着且插件已启用。

### Daemon —— 热连接(推荐)

一次性 CLI 调用每次都要重新绑定 WebSocket 并等 Godot 重连(~1–2 秒)。启动一个
**daemon** 把连接保温;之后命令走本地 HTTP 路由给它,~150 毫秒返回(快约 5–10 倍):

```bash
node build/cli.js daemon        # 长驻:WS 6605-6609 + IPC 6610。让它一直开着。
node build/cli.js status        # { daemon: true, ws_port, editor, runtime }
node build/cli.js get_game_info # 自动路由到 daemon
node build/cli.js stop-daemon
```

`godot-x <tool>` 会自动探测运行中的 daemon;没有就回退到一次性模式,脚本两种都能跑。
用 `GODOT_MCP_X_DAEMON_PORT` 改 IPC 端口。`status` 还会报 `concurrent_replaces` ——
非零说明有两个 Godot 实例在抢端口(只留一个)。完整"做一局游戏"流程见
**[WALKTHROUGH.md](WALKTHROUGH.md)**。

### 无编辑器也能用运行时工具

运行时工具(`get_game_screenshot`、`get_game_info`、`simulate_key`、
`execute_game_script` 等)可对**独立运行的游戏**生效 —— 不需要编辑器。游戏的
`McpXRuntime` autoload 会拨入,CLI/daemon 接受 editor **或** runtime 连接。所以你可以
`godot --path .` 跑游戏并直接截图/驱动。一条命令抓瞬时特效:
`get_game_screenshot --run 'player._fire_nova()' --after 0.1`(或 `--count 8` 连拍)。

### 无头导入资源

不开 GUI 导入新加的资源(新 `.png` 等):
`godot --headless --import path/to/project.godot`。**坑**:`--editor --quit` **不**可靠
生成 `.import`,运行时 `load()` 会返回 null —— 用 `--import`。

## 工具模式(压缩上下文)

完整服务器注册 163 个工具,工具列表本身也耗上下文。聚焦会话时,用 `--mode`(或环境
变量 `GODOT_MCP_X_MODE`)只加载需要的组,另有 `--tools` / `--exclude`:

| 模式 | 工具数 | 组 |
|---|--:|---|
| `full`(默认) | 163 | 全部 |
| `minimal` | 48 | project、scene、node、script、editor |
| `3d` | 146 | common + physics、navigation、node3d、shader、particle、audio、animation_tree、gridmap、skeleton |
| `2d` | 116 | common + physics、tilemap、theme |
| `ui` | 78 | minimal + resource、theme、batch、runtime、ui |
| `test` | 72 | minimal + runtime、testing、profiling |

(common = minimal + analysis、resource、filesystem、ui、input、animation、batch、runtime、testing)

```jsonc
// .mcp.json —— 只加载 3D 工具
{ "mcpServers": { "godot-mcp-x": { "command": "node",
    "args": ["D:/GodotProjects/godot-mcp-x/server/build/index.js", "--mode", "3d"] } } }
```

或显式选组:`--tools project,scene,node,shader` / `--exclude export,profiling`。
预览任意模式:`node build/cli.js list --mode 3d`。

## 工具一览(当前 163;工具名为代码标识,保持英文)

- **project**(9):`get_project_info`、`get_project_settings`、`set_project_setting`、`get_filesystem_tree`、`list_autoloads`、`add_autoload`、`remove_autoload`、`uid_to_path`、`path_to_uid`
- **scene**(7):`get_scene_tree`、`get_current_scene`、`open_scene`、`save_scene`、`create_scene`、`get_scene_file_content`、`instance_scene`
- **node**(14):`add_node`、`delete_node`、`rename_node`、`move_node`、`duplicate_node`、`get_node_properties`、`set_node_property`、`set_node_properties`、`get_node_signals`、`connect_signal`、`set_node_groups`、`find_nodes`、`call_node_method`、`build_tree`(一次可撤销地建整棵子树,支持内联资源 `{"_res":...}` 与信号)
- **script**(7):`read_script`、`create_script`、`write_script`、`edit_script`、`attach_script`、`validate_script`、`list_scripts`
- **editor**(11):`execute_editor_script`、`get_editor_errors`、`get_output_log`、`clear_output`、`get_editor_screenshot`、`reload_scripts`、`list_classes`、`describe_class`、`undo`、`redo`、`get_status`
- **analysis**(5):`search_files`、`search_in_files`、`find_script_references`、`get_scene_dependencies`、`analyze_scene_complexity`
- **resource**(3):`create_resource`、`read_resource`、`edit_resource`
- **filesystem**(4):`create_folder`、`rename_path`、`delete_path`、`duplicate_path`
- **ui**(2):`add_virtual_joystick`(4.7 触屏摇杆 → 输入动作)、`set_anchor_preset`
- **input map**(4):`list_input_actions`、`add_input_action`、`remove_input_action`、`add_input_event`
- **animation**(5):`list_animations`、`get_animation_info`、`create_animation`、`add_animation_track`、`set_animation_keyframe`
- **physics**(5):`get_physics_layers`、`set_physics_layer_name`、`set_collision_layers`、`get_collision_info`、`setup_collision_shape`
- **3D**(5):`add_mesh_instance`、`setup_light`(directional/omni/spot/**area** = 4.7 AreaLight3D)、`setup_camera`、`set_material`、`setup_environment`
- **runtime**(15):`play_scene`、`stop_scene`、`is_game_running`、`get_game_info`、`get_game_scene_tree`、`get_game_node_properties`、`set_game_node_property`、`execute_game_script`、`get_game_screenshot`(支持 `run`/`after`/`count` 连拍以捕捉瞬时特效)、`reload_game_script`(运行时热重载)、`simulate_action`、`simulate_key`(tap/press/release 模式)、`get_autoload`、`find_game_nodes`、`call_game_method`
  —— 游戏内工具通过**直连 WebSocket** 拨入(无文件轮询);先调 `play_scene`。
- **shader**(6):`create_shader`、`read_shader`、`edit_shader`、`assign_shader`、`set_shader_param`、`list_shader_uniforms`
- **audio**(5):`add_audio_player`、`list_audio_buses`、`add_audio_bus`、`set_bus_volume`、`add_bus_effect`
- **particle**(3):`create_particles`、`set_particle_process`、`get_particle_info`
- **navigation**(4):`setup_navigation_region`、`setup_navigation_agent`、`bake_navigation_mesh`、`get_navigation_info`
- **tilemap**(7,基于 TileMapLayer):`tilemap_get_info`、`tilemap_set_cell`、`tilemap_get_cell`、`tilemap_erase_cell`、`tilemap_fill_rect`、`tilemap_clear`、`tilemap_get_used_cells`
- **theme**(7):`create_theme`、`set_theme_color`、`set_theme_constant`、`set_theme_font_size`、`set_theme_stylebox`、`get_theme_info`、`apply_theme`
- **animation tree**(6):`create_animation_tree`、`setup_state_machine`、`add_state`、`add_transition`、`get_animation_tree_info`、`set_tree_param`
- **batch**(3):`batch_add_nodes`、`batch_set_properties`、`batch_get_properties`
- **profiling**(1):`get_performance_monitors`
- **export**(2):`list_export_presets`、`get_export_info`
- **testing**(8,运行时):`assert_property`、`assert_node_exists`、`assert_screen_text`、`wait_for_node`、`monitor_property`、`record_frames`、`run_test_scenario`、`get_test_report` —— 在运行中的游戏里做自动化玩法回归(通过/失败报告;故意失败已验证)
- **gridmap**(6):`add_gridmap`、`gridmap_set_cell`、`gridmap_get_cell`、`gridmap_clear`、`gridmap_get_used_cells`、`gridmap_get_info`
- **skeleton**(9):`get_skeleton_info`、`list_bones`、`add_bone`、`set_bone_pose`、`reset_bone_poses`、`add_bone_attachment`、`add_skeleton_modifier`、`setup_look_at_modifier`、`list_skeleton_modifiers` —— 通过 SkeletonModifier3D 系统实现 IK 与骨骼约束(TwoBoneIK3D、FABRIK3D、CCDIK3D、LookAtModifier3D、SpringBoneSimulator3D…)

> 另有 `doctor` / `setup`(项目自检 + 一键装插件/autoload)、`daemon` / `status` /
> `stop-daemon` 等 CLI 子命令,见上文与 [WALKTHROUGH.md](WALKTHROUGH.md)、
> [recipes](knowledge/19-recipes.md)。

## 知识库

[knowledge/](knowledge/) —— 一份可复用、面向 AI 的 Godot 4.7 参考(**20 篇**),在开发
本工具时**对照实时引擎逐条验证**:4.7 新特性、GDScript 要点、编辑器自动化配方、API
陷阱、godot-mcp-x 工作流、玩法范式、渲染/材质/光照、物理/碰撞、资源与 @export、
SkeletonModifier3D IK 系统,以及一篇**深度 4.7 变更**(VirtualJoystick、
DrawableTexture2D、光线追踪铺垫、HDR、Jolt SoftBody、GUI/输入/编辑器/Android 变更);
再加 UI/Control、着色器(Godot Shading Language)、XR/OpenXR、性能优化、多人/网络、
音频、导航 —— 覆盖每个主要引擎子系统。

## 开发 / 验证

`test_project/` 是用来对插件做解析检查的一次性 Godot 项目:
```bash
# 解析每个插件脚本(经 plugin.gd 传递性覆盖整张依赖图)
"D:/Godot/Godot_v4.7-stable_win64.exe" --headless --path test_project --check-only \
  --script res://addons/godot_mcp_x/plugin.gd
# 完整端到端往返(服务器 + 实时编辑器 + 命令)
cd server && node test/handshake.js   # 需先开着无头编辑器
```
TypeScript 侧:`cd server && npm test`(构建 + vitest:效率内核、setup、注册表、
MCP stdio 冒烟测试)。CI 见 `.github/workflows/ci.yml`。

## 许可

MIT。部分逻辑改编自 godot-mcp-pro(MIT)。见 [LICENSE](LICENSE)。
