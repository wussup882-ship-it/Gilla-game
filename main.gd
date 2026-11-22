extends Node3D

const PlayerScript = preload("res://gorilla_player.gd")
const MatsScript = preload("res://mats.gd")
const PropsScript = preload("res://props.gd")
const NetScript = preload("res://net.gd")

var player
var mats
var props
var net
var world: Node3D
var env: Environment
var hud: Label3D
var msg: Label3D
var board: Label3D
var fur_label: Label3D
var room_label: Label3D
var punch_label: Label3D
var mod_label: Label3D
var friends_label: Label3D
var lamp: OmniLight3D
var mode := "lobby"
var inter: Array = []
var items: Array = []
var mons: Array = []
var floor_pts: Array = []
var held := {"l": null, "r": null}
var grip_prev := {"l": false, "r": false}
var tip_prev := {}
var hit_cd := {}
var mod_btns := {}
var mods := {"speed": false, "jump": false, "lowgrav": false, "fly": false, "plat": false, "noclip": false}
var punch_mode := 1
var inter_cd := 0.0
var carried := 0
var recycled := 0
var quota := 5
var item_val := 40
var round_t := 0.0
var end_t := 0.0
var msg_t := 0.0
var round_over := false
var exit_open := false
var exit_node: Node3D
var exit_pos := Vector3.ZERO
var spawn_pt := Vector3.ZERO
var model_scene: PackedScene
var send_t := 0.0
var board_t := 0.0
var cam_vp: SubViewport
var cam_cam: Camera3D
var cam_screen: MeshInstance3D
var t_anim := 0.0
var pname := "Gilla"


func _ready() -> void:
    randomize()
    pname = "Gilla%d" % (randi() % 900 + 100)
    mats = MatsScript.new()
    props = PropsScript.new(mats)
    env = Environment.new()
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    _start_xr()
    player = PlayerScript.new()
    player.mats = mats
    add_child(player)
    hud = _make_label(40, 0.0011)
    player.cam.add_child(hud)
    hud.position = Vector3(0, -0.33, -1.0)
    msg = _make_label(64, 0.0011)
    player.cam.add_child(msg)
    msg.position = Vector3(0, 0.12, -1.1)
    msg.modulate = Color(1, 0.9, 0.3)
    player.set_tint(Game.FUR[Game.equipped]["color"])
    if ResourceLoader.exists("res://gilla.glb"):
        model_scene = load("res://gilla.glb")
    net = NetScript.new()
    add_child(net)
    net.on_hit = Callable(self, "_on_net_hit")
    net.on_kick = Callable(self, "_on_net_kick")
    var tex = null
    if ResourceLoader.exists("res://gilla_img0.png"):
        tex = load("res://gilla_img0.png")
    net.start(Game.server_url(), Game.ROOMS[Game.room_idx], pname, Game.mod_token(), self, model_scene, tex)
    _enter_lobby()


func _start_xr() -> void:
    var xr := XRServer.find_interface("OpenXR")
    if xr and (xr.is_initialized() or xr.initialize()):
        get_viewport().use_xr = true
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _make_label(size: int, px: float) -> Label3D:
    var l := Label3D.new()
    l.font_size = size
    l.pixel_size = px
    l.no_depth_test = true
    l.shaded = false
    l.outline_size = 10
    l.render_priority = 10
    l.outline_render_priority = 9
    l.modulate = Color(1, 1, 0.75)
    return l


# ---------------------------------------------------------------- build helpers
func _set_env(bg: Color, amb: Color, energy: float, fog: float) -> void:
    env.background_mode = Environment.BG_COLOR
    env.background_color = bg
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = amb
    env.ambient_light_energy = energy
    env.fog_enabled = fog > 0.0
    env.fog_light_color = bg
    env.fog_density = fog


func _clear() -> void:
    for s in ["l", "r"]:
        if held[s] != null:
            held[s].reparent(self, false)
            held[s].queue_free()
            held[s] = null
    if world:
        world.queue_free()
    world = Node3D.new()
    add_child(world)
    if lamp:
        lamp.queue_free()
        lamp = null
    if cam_vp:
        cam_vp.queue_free()
        cam_vp = null
    inter.clear()
    items.clear()
    mons.clear()
    floor_pts.clear()
    mod_btns.clear()
    tip_prev.clear()
    carried = 0
    recycled = 0
    exit_open = false
    exit_node = null
    round_over = false


func _box(pos: Vector3, size: Vector3, kind: String, tint: Color = Color.WHITE, solid: bool = true) -> Node3D:
    var b: Node3D = StaticBody3D.new() if solid else Node3D.new()
    b.position = pos
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mats.get_mat(kind, tint)
    b.add_child(mi)
    if solid:
        var cs := CollisionShape3D.new()
        var sh := BoxShape3D.new()
        sh.size = size
        cs.shape = sh
        b.add_child(cs)
    world.add_child(b)
    return b


func _glow_box(pos: Vector3, size: Vector3, col: Color, energy: float = 1.5) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mats.glow(col, energy)
    mi.position = pos
    world.add_child(mi)
    return mi


func _light(pos: Vector3, col: Color, energy: float, rng: float) -> void:
    var l := OmniLight3D.new()
    l.position = pos
    l.light_color = col
    l.light_energy = energy
    l.omni_range = rng
    world.add_child(l)


func _panel(pos: Vector3, with_light: bool = false) -> void:
    _glow_box(pos, Vector3(1.4, 0.08, 1.4), Color(1, 1, 0.95), 2.5)
    _box(pos + Vector3(0, 0.05, 0), Vector3(1.6, 0.04, 1.6), "metal", Color(0.1, 0.1, 0.1), false)
    if with_light:
        _light(pos - Vector3(0, 0.8, 0), Color(1, 0.97, 0.9), 1.3, 18.0)


func _text(txt: String, pos: Vector3, size: int = 48, col: Color = Color.WHITE, billboard: bool = false) -> Label3D:
    var l := Label3D.new()
    l.text = txt
    l.font_size = size
    l.pixel_size = 0.004
    l.outline_size = 8
    l.modulate = col
    if billboard:
        l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.position = pos
    world.add_child(l)
    return l


func _room(w: float, d: float, h: float, floor_kind: String, wall_kind: String) -> void:
    _box(Vector3(0, -0.25, 0), Vector3(w, 0.5, d), floor_kind)
    _box(Vector3(0, h + 0.25, 0), Vector3(w + 1, 0.5, d + 1), wall_kind)
    _box(Vector3(0, h * 0.5, -d * 0.5 - 0.25), Vector3(w + 1, h, 0.5), wall_kind)
    _box(Vector3(0, h * 0.5, d * 0.5 + 0.25), Vector3(w + 1, h, 0.5), wall_kind)
    _box(Vector3(-w * 0.5 - 0.25, h * 0.5, 0), Vector3(0.5, h, d), wall_kind)
    _box(Vector3(w * 0.5 + 0.25, h * 0.5, 0), Vector3(0.5, h, d), wall_kind)
    if wall_kind == "wall":
        var dark := Color(0.12, 0.11, 0.1)
        _box(Vector3(0, 0.1, -d * 0.5 + 0.05), Vector3(w, 0.2, 0.1), "metal", dark, false)
        _box(Vector3(0, 0.1, d * 0.5 - 0.05), Vector3(w, 0.2, 0.1), "metal", dark, false)
        _box(Vector3(-w * 0.5 + 0.05, 0.1, 0), Vector3(0.1, 0.2, d), "metal", dark, false)
        _box(Vector3(w * 0.5 - 0.05, 0.1, 0), Vector3(0.1, 0.2, d), "metal", dark, false)


func _place_prop(n: Node3D, pos: Vector3, yaw: float = 0.0) -> Node3D:
    n.position = pos
    n.rotation.y = yaw
    world.add_child(n)
    return n


func _lantern(pos: Vector3) -> void:
    _glow_box(pos, Vector3(0.14, 0.3, 0.14), Color(1.0, 0.8, 0.4), 3.0)
    _light(pos, Color(1.0, 0.75, 0.4), 1.2, 6.0)


func _hazard(pos: Vector3, size: Vector3) -> void:
    _box(pos, size, "hazard", Color.WHITE, false)


func _recycler(pos: Vector3) -> void:
    _box(pos + Vector3(0, 1.1, 0), Vector3(2.0, 2.2, 1.4), "metal", Color(0.15, 0.5, 0.2))
    _box(pos + Vector3(0, 0.2, 0.1), Vector3(2.3, 0.4, 1.7), "hazard")
    _glow_box(pos + Vector3(0, 1.5, 0.72), Vector3(1.2, 0.6, 0.05), Color(0.2, 1.0, 0.3), 1.2)
    _text("RECYCLER", pos + Vector3(0, 2.6, 0), 64, Color(0.3, 1, 0.4), true)
    _light(pos + Vector3(0, 2.0, 1.0), Color(0.3, 1.0, 0.4), 1.0, 6.0)
    inter.append({"pos": pos + Vector3(0, 1.1, 1.0), "r": 1.3, "a": "recycle"})


func _exit_portal(pos: Vector3) -> void:
    exit_pos = pos
    var holder := Node3D.new()
    holder.position = pos
    world.add_child(holder)
    var torus := TorusMesh.new()
    torus.inner_radius = 0.9
    torus.outer_radius = 1.15
    var mi := MeshInstance3D.new()
    mi.mesh = torus
    mi.material_override = mats.glow(Color(1.0, 0.15, 0.1), 2.0)
    mi.rotation_degrees = Vector3(90, 0, 0)
    mi.position = Vector3(0, 1.4, 0)
    holder.add_child(mi)
    exit_node = holder
    var l := Label3D.new()
    l.text = "EXIT"
    l.font_size = 72
    l.pixel_size = 0.004
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.position = Vector3(0, 3.0, 0)
    holder.add_child(l)
    inter.append({"pos": pos + Vector3(0, 1.4, 0), "r": 1.3, "a": "exit"})


func _pad(pos: Vector3, label: String, col: Color, action: String, arg: String = "") -> Label3D:
    _box(pos + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5), "metal", Color(0.3, 0.3, 0.32))
    _glow_box(pos + Vector3(0, 1.06, 0), Vector3(0.4, 0.12, 0.4), col, 2.0)
    var t := _text(label, pos + Vector3(0, 1.9, 0), 56, col, true)
    inter.append({"pos": pos + Vector3(0, 1.1, 0), "r": 0.3, "a": action, "arg": arg})
    return t


func _wall_button(pos: Vector3, label: String, action: String, arg: String, yaw: float = 0.0) -> void:
    var holder := Node3D.new()
    holder.position = pos
    holder.rotation.y = yaw
    world.add_child(holder)
    var bm := BoxMesh.new()
    bm.size = Vector3(1.7, 0.34, 0.06)
    var mi := MeshInstance3D.new()
    mi.mesh = bm
    mi.material_override = mats.glow(Color(0.8, 0.1, 0.1), 1.5)
    holder.add_child(mi)
    var l := Label3D.new()
    l.text = label
    l.font_size = 30
    l.pixel_size = 0.0035
    l.position = Vector3(0, 0, 0.04)
    l.modulate = Color(1, 1, 1)
    holder.add_child(l)
    mod_btns[arg] = {"mi": mi, "label": l, "text": label}
    inter.append({"pos": pos + Vector3(0, 0, 0.1).rotated(Vector3.UP, yaw), "r": 0.4, "a": action, "arg": arg})


func _spawn_item(pos: Vector3, kind: String) -> void:
    var n := MeshInstance3D.new()
    if kind == "gold":
        var bm := BoxMesh.new()
        bm.size = Vector3(0.3, 0.12, 0.15)
        n.mesh = bm
        n.material_override = mats.glow(Color(1.0, 0.78, 0.15), 0.9)
    else:
        var sm := SphereMesh.new()
        sm.radius = 0.12
        sm.height = 0.3
        sm.radial_segments = 6
        sm.rings = 3
        n.mesh = sm
        n.material_override = mats.glow(Color(0.3, 0.95, 1.0), 1.6)
    n.position = pos
    world.add_child(n)
    items.append({"n": n, "kind": kind})


func _spawn_weapon(kind: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
    var w: Node3D = props.make_weapon(kind)
    w.position = pos
    w.rotation_degrees = Vector3(0, rad_to_deg(yaw), 0)
    if kind != "chainsaw":
        w.rotation_degrees = Vector3(-80, rad_to_deg(yaw), 0)
    w.add_to_group("pickup")
    world.add_child(w)
    return w


func _spawn_creature(kind: String, pos: Vector3) -> void:
    var body := CharacterBody3D.new()
    body.collision_layer = 0
    body.collision_mask = 1
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.35
    cap.height = 1.6
    cs.shape = cap
    cs.position = Vector3(0, 0.85, 0)
    body.add_child(cs)
    var model: Node3D = props.gold_suit() if kind == "gold" else props.white_monster()
    body.add_child(model)
    body.position = pos
    world.add_child(body)
    mons.append({"node": body, "model": model, "kind": kind, "hp": 4.0 if kind == "gold" else 3.0, "dead_t": 0.0, "target": pos, "tt": 0.0, "stuck": 0.0, "start": pos, "speed": 3.1 if kind == "gold" else 3.7})


func _blood_burst(pos: Vector3) -> void:
    var p := CPUParticles3D.new()
    p.position = pos
    p.amount = 24
    p.lifetime = 0.7
    p.one_shot = true
    p.explosiveness = 1.0
    p.direction = Vector3.UP
    p.spread = 180.0
    p.initial_velocity_min = 1.5
    p.initial_velocity_max = 4.0
    p.gravity = Vector3(0, -9.8, 0)
    var sm := SphereMesh.new()
    sm.radius = 0.025
    sm.height = 0.05
    sm.radial_segments = 6
    sm.rings = 3
    p.mesh = sm
    p.material_override = mats.paint(Color(0.55, 0.02, 0.02), 0.0, 0.2)
    world.add_child(p)
    p.emitting = true
    get_tree().create_timer(1.5).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- lobby
func _enter_lobby() -> void:
    mode = "lobby"
    net.cur_mode = mode
    _clear()
    _set_env(Color(0.62, 0.65, 0.68), Color(0.9, 0.92, 0.96), 1.35, 0.0)
    _room(26.0, 26.0, 5.0, "floor", "wall")
    for p in [Vector3(-6, 4.95, -6), Vector3(6, 4.95, -6), Vector3(-6, 4.95, 6), Vector3(6, 4.95, 6)]:
        _panel(p, false)
    _place_prop(props.crate_stack(), Vector3(-11.5, 0, -10.5), 0.2)
    _place_prop(props.barrel(), Vector3(-12.2, 0, -7.5))
    _place_prop(props.barrel(Color(0.5, 0.2, 0.12)), Vector3(-12.2, 0, -6.6))
    _place_prop(props.vending(), Vector3(12.3, 0, 8.0), -PI * 0.5)
    _place_prop(props.shelf_rack(), Vector3(11.8, 0, 3.5), PI * 0.5)
    _place_prop(props.shelf_rack(), Vector3(11.8, 0, 6.0), PI * 0.5)
    _recycler(Vector3(10.5, 0, -10.5))
    _box(Vector3(0, 2.6, -12.7), Vector3(9.0, 2.8, 0.1), "metal", Color(0.08, 0.08, 0.1), false)
    _text("WELCOME TO GILLA", Vector3(0, 3.6, -12.6), 90, Color(1, 1, 1))
    board = _text("", Vector3(0, 2.4, -12.6), 44, Color(0.6, 1.0, 0.6))
    _pad(Vector3(-8, 0, -8), "LETHAL APE MAP\nloot, recycle, escape", Color(1.0, 0.6, 0.1), "ape")
    mod_label = _pad(Vector3(-4, 0, -8), "", Color(1.0, 0.15, 0.35), "mod")
    fur_label = _pad(Vector3(0, 0, -8), "", Color(0.9, 0.3, 0.9), "fur")
    room_label = _pad(Vector3(4, 0, -8), "", Color(0.3, 0.9, 1.0), "room")
    punch_label = _pad(Vector3(8, 0, -8), "", Color(1.0, 1.0, 0.3), "punch")
    # friends list terminal (west wall)
    _box(Vector3(-12.9, 2.2, 0), Vector3(0.1, 2.6, 4.2), "metal", Color(0.05, 0.05, 0.07), false)
    friends_label = _text("FRIENDS", Vector3(-12.8, 2.2, 0), 40, Color(0.7, 1.0, 0.7))
    friends_label.rotation_degrees = Vector3(0, 90, 0)
    # GillaCAM screen (east wall)
    _make_gillacam(Vector3(12.85, 2.4, -2.0), -90.0)
    for p in [Vector3(-12.8, 2.6, -3), Vector3(-12.8, 2.6, 4), Vector3(12.8, 2.6, 2), Vector3(-3, 2.6, -12.8), Vector3(3, 2.6, -12.8)]:
        _lantern(p)
    _hazard(Vector3(0, 0.011, -5.5), Vector3(18, 0.02, 0.4))
    # tiled terminal corner with display tank and GillaOS desk
    _box(Vector3(-9, 0.011, 8), Vector3(8, 0.02, 8), "yellowtile", Color.WHITE, false)
    _box(Vector3(-12.95, 1.5, 8), Vector3(0.05, 3.0, 8), "tealtile", Color.WHITE, false)
    _box(Vector3(-9, 1.5, 12.95), Vector3(8, 3.0, 0.05), "tealtile", Color.WHITE, false)
    _box(Vector3(-9, 0.3, 7.0), Vector3(1.4, 0.6, 1.4), "metal", Color(0.3, 0.32, 0.35))
    _light(Vector3(-9, 2.2, 7.0), Color(0.3, 1.0, 0.4), 1.3, 5.0)
    if model_scene:
        var disp: Node3D = model_scene.instantiate()
        world.add_child(disp)
        disp.position = Vector3(-9, 0.6, 7.0)
        PropsScript.fit(disp, 1.4)
    _place_prop(props.terminal(), Vector3(-10.5, 0, 11.7), PI)
    _text("GillaOS", Vector3(-10.85, 1.1, 11.2), 36, Color(0.5, 1.0, 0.5))
    _refresh_labels()
    player.spawn_pos = Vector3(0, 0.2, 6.0)
    player.respawn()
    _apply_mods()


func _refresh_labels() -> void:
    var nxt: int = (Game.equipped + 1) % Game.FUR.size()
    var f: Dictionary = Game.FUR[nxt]
    var price := "OWNED" if Game.owned.has(nxt) else "$%d" % f["cost"]
    if fur_label:
        fur_label.text = "FUR: %s\n%s" % [f["name"], price]
    if mod_label:
        mod_label.text = "MOD ROOM\nhammer + mod menu" if _is_mod() else "MOD ROOM\nMODS ONLY (locked)"
    if room_label:
        room_label.text = "ROOM: %s\ntouch to change" % Game.ROOMS[Game.room_idx]
    if punch_label:
        punch_label.text = "PUNCH MENU\n%s" % ["OFF", "PUNCH", "LAUNCH"][punch_mode]
    if board:
        board.text = "LEVEL %d     $%d\nXP %d / %d" % [Game.level(), Game.money, Game.xp, Game.xp_next()]
    if friends_label:
        var t := "FRIENDS  (%s)\nYOU: %s\n" % [net.status, pname]
        for p in net.names():
            t += "%s\n" % p["name"]
        friends_label.text = t


func _make_gillacam(pos: Vector3, yaw_deg: float) -> void:
    cam_vp = SubViewport.new()
    cam_vp.size = Vector2i(320, 200)
    cam_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
    cam_vp.world_3d = get_world_3d()
    add_child(cam_vp)
    cam_cam = Camera3D.new()
    cam_vp.add_child(cam_cam)
    var holder := Node3D.new()
    holder.position = pos
    holder.rotation_degrees = Vector3(0, yaw_deg, 0)
    world.add_child(holder)
    var frame := MeshInstance3D.new()
    var fm := BoxMesh.new()
    fm.size = Vector3(2.6, 1.7, 0.08)
    frame.mesh = fm
    frame.material_override = mats.paint(Color(0.05, 0.05, 0.06), 0.5, 0.4)
    holder.add_child(frame)
    cam_screen = MeshInstance3D.new()
    var qm := QuadMesh.new()
    qm.size = Vector2(2.4, 1.5)
    cam_screen.mesh = qm
    var sm := StandardMaterial3D.new()
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.albedo_texture = cam_vp.get_texture()
    cam_screen.material_override = sm
    cam_screen.position = Vector3(0, 0, 0.05)
    holder.add_child(cam_screen)
    var l := Label3D.new()
    l.text = "GillaCAM"
    l.font_size = 40
    l.pixel_size = 0.004
    l.position = Vector3(0, 1.0, 0.06)
    holder.add_child(l)


# ---------------------------------------------------------------- mod room
func _enter_mod() -> void:
    mode = "mod"
    net.cur_mode = mode
    _clear()
    _set_env(Color(0.03, 0.02, 0.06), Color(0.45, 0.4, 0.6), 0.9, 0.0)
    _room(30.0, 30.0, 6.0, "metal", "metal")
    var neon := [Color(1, 0.1, 0.4), Color(0.1, 0.9, 1.0), Color(0.7, 0.2, 1.0), Color(1.0, 0.8, 0.1)]
    for i in 4:
        _glow_box(Vector3(0, 0.1 + i * 1.4, -14.9), Vector3(28, 0.08, 0.05), neon[i], 2.5)
        _glow_box(Vector3(14.9, 0.1 + i * 1.4, 0), Vector3(0.05, 0.08, 28), neon[(i + 1) % 4], 2.5)
        _glow_box(Vector3(-14.9, 0.1 + i * 1.4, 0), Vector3(0.05, 0.08, 28), neon[(i + 2) % 4], 2.5)
    for i in 6:
        _light(Vector3(-10 + (i % 3) * 10, 4.5, -8 + (i / 3) * 14), neon[i % 4], 1.4, 14.0)
    _text("MOD ROOM", Vector3(0, 5.0, -14.8), 120, Color(1, 0.2, 0.4))
    # mod menu (north wall)
    _box(Vector3(0, 2.3, -14.8), Vector3(7.4, 3.4, 0.1), "metal", Color(0.04, 0.04, 0.06), false)
    _text("MOD MENU", Vector3(0, 3.7, -14.7), 70, Color(0.5, 1, 1))
    var defs := [["SPEED BOOST", "speed"], ["SUPER JUMP", "jump"], ["LOW GRAVITY", "lowgrav"], ["FLY (trigger)", "fly"], ["PLATFORMS (A/X)", "plat"], ["NOCLIP", "noclip"]]
    for i in defs.size():
        _wall_button(Vector3(-1.8 + (i % 2) * 3.6, 3.0 - (i / 2) * 0.6, -14.7), defs[i][0], "mod_toggle", defs[i][1])
    _wall_button(Vector3(-2.0, 1.0, -14.7), "RESET MODS", "mod_reset", "reset")
    _wall_button(Vector3(2.0, 1.0, -14.7), "RESPAWN WEAPONS", "weapons_reset", "wr")
    # kick / yeet panel (west wall)
    _box(Vector3(-14.8, 2.3, 0), Vector3(0.1, 3.4, 6.0), "metal", Color(0.04, 0.04, 0.06), false)
    _text("PLAYERS", Vector3(-14.7, 3.7, 0), 60, Color(1, 0.8, 0.3)).rotation_degrees = Vector3(0, 90, 0)
    for i in 6:
        _wall_button(Vector3(-14.7, 3.1 - i * 0.42, 0), "-", "kick", "k%d" % i, PI * 0.5)
    # weapons on pedestals (east side)
    var wk := ["hammer", "axe", "pickaxe", "chainsaw"]
    for i in 4:
        var pz := -6.0 + i * 3.2
        _box(Vector3(13.0, 0.45, pz), Vector3(0.8, 0.9, 0.8), "metal", Color(0.2, 0.2, 0.24))
        _spawn_weapon(wk[i], Vector3(13.0, 1.0, pz), 0.0)
        _text(wk[i].to_upper() if wk[i] != "hammer" else "KICK HAMMER", Vector3(13.0, 2.0, pz), 44, Color(1, 0.8, 0.8), true)
    # targets to test weapons on
    _spawn_creature("white", Vector3(-5, 0, 2))
    _spawn_creature("gold", Vector3(5, 0, 2))
    for m in mons:
        m["dummy"] = true
        m["speed"] = 0.0
    _pad(Vector3(0, 0, 12), "BACK TO LOBBY", Color(0.9, 0.9, 0.9), "lobby")
    player.spawn_pos = Vector3(0, 0.2, 9.0)
    player.respawn()
    _apply_mods()
    _say("MOD ROOM  -  grab tools with GRIP")


# ---------------------------------------------------------------- the real map (Lethal Ape)
func _load_map() -> Node3D:
    var bytes := FileAccess.get_file_as_bytes("res://lethal_ape_map.glb")
    if bytes.is_empty():
        return null
    var doc := GLTFDocument.new()
    var st := GLTFState.new()
    if doc.append_from_buffer(bytes, "", st) != OK:
        return null
    return doc.generate_scene(st) as Node3D


func _pick_floor(from: Vector3, min_d: float, max_d: float) -> Vector3:
    for i in 300:
        var f: Dictionary = floor_pts[randi() % floor_pts.size()]
        var d: float = (f["p"] as Vector3).distance_to(from)
        if d >= min_d and d <= max_d:
            return f["p"]
    return (floor_pts[randi() % floor_pts.size()] as Dictionary)["p"]


func _enter_ape() -> void:
    mode = "ape"
    net.cur_mode = mode
    _clear()
    quota = 5
    item_val = 40
    round_t = 600.0
    _set_env(Color(0.1, 0.11, 0.13), Color(0.72, 0.74, 0.8), 1.0, 0.004)
    var map := _load_map()
    if map == null:
        _enter_lobby()
        _say("MAP FILE MISSING")
        return
    world.add_child(map)
    var best := 0.0
    for mi in map.find_children("*", "MeshInstance3D", true, false):
        var m := mi as MeshInstance3D
        if m.mesh == null:
            continue
        m.create_trimesh_collision()
        var f: PackedVector3Array = m.mesh.get_faces()
        var xf := m.global_transform
        for i in range(0, f.size() - 2, 3):
            var a: Vector3 = xf * f[i]
            var b: Vector3 = xf * f[i + 1]
            var c: Vector3 = xf * f[i + 2]
            var nrm := (b - a).cross(c - a)
            var area := nrm.length() * 0.5
            if area > 0.4 and nrm.normalized().y > 0.9:
                var ctr := (a + b + c) / 3.0
                floor_pts.append({"p": ctr, "a": area})
                if area > best:
                    best = area
                    spawn_pt = ctr
    if floor_pts.is_empty():
        _enter_lobby()
        _say("MAP HAS NO FLOORS")
        return
    var p0 := spawn_pt + Vector3(0, 0.3, 0)
    player.spawn_pos = p0
    player.respawn()
    lamp = OmniLight3D.new()
    lamp.light_color = Color(1.0, 0.95, 0.85)
    lamp.light_energy = 2.0
    lamp.omni_range = 14.0
    player.cam.add_child(lamp)
    _recycler(_pick_floor(spawn_pt, 3.0, 9.0))
    var far := spawn_pt
    for i in 60:
        var q: Vector3 = _pick_floor(spawn_pt, 40.0, 400.0)
        if q.distance_to(spawn_pt) > far.distance_to(spawn_pt):
            far = q
    _exit_portal(far)
    var placed: Array = []
    for i in 10:
        var q: Vector3 = _pick_floor(spawn_pt, 8.0, 400.0)
        var ok := true
        for o in placed:
            if (o as Vector3).distance_to(q) < 10.0:
                ok = false
        if ok:
            placed.append(q)
            _spawn_item(q + Vector3(0, 0.2, 0), "gold")
    var kinds := ["axe", "pickaxe", "chainsaw", "hammer"]
    for i in 4:
        var q: Vector3 = _pick_floor(spawn_pt, 1.5, 4.5)
        _spawn_weapon(kinds[i], q + Vector3(0, 0.15, 0), randf() * TAU)
    for i in 3:
        _spawn_creature("gold" if i == 2 else "white", _pick_floor(spawn_pt, 35.0, 400.0))
    for i in 45:
        var q: Vector3 = _pick_floor(spawn_pt, 4.0, 400.0)
        var which := randi() % 5
        var n: Node3D
        var sz := Vector3(0.6, 0.9, 0.6)
        var cy := 0.45
        match which:
            0:
                n = props.crate_stack()
                sz = Vector3(2.2, 2.0, 1.2)
                cy = 1.0
            1:
                n = props.barrel(Color.from_hsv(randf(), 0.4, 0.45))
            2:
                n = props.shelf_rack()
                sz = Vector3(1.8, 2.2, 0.8)
                cy = 1.1
            3:
                n = props.vending()
                sz = Vector3(0.9, 1.9, 0.75)
                cy = 0.95
            _:
                n = props.lamp_post()
                sz = Vector3(0.3, 2.8, 0.3)
                cy = 1.4
        _place_prop(n, q, randf() * TAU)
        var sb := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = sz
        cs.shape = bs
        cs.position = Vector3(sz.x * 0.5 - 0.5 if which == 0 else 0.0, cy, 0)
        sb.add_child(cs)
        n.add_child(sb)
    _say("LOOT %d BARS, RECYCLE %d, ESCAPE" % [placed.size(), quota])


# ---------------------------------------------------------------- loop
func _say(t: String) -> void:
    msg.text = t
    msg_t = 3.0


func _hands() -> Array:
    return [player.ctrl["l"].global_position, player.ctrl["r"].global_position]


func _near(p: Vector3, r: float) -> bool:
    for h in _hands():
        if h.distance_to(p) < r:
            return true
    return false


func _process(dt: float) -> void:
    t_anim += dt
    inter_cd = maxf(0.0, inter_cd - dt)
    msg_t -= dt
    if msg_t <= 0.0:
        msg.text = ""
    for it in items:
        it["n"].rotate_y(dt * 1.5)
    var modtxt := ""
    for k in mods:
        if mods[k]:
            modtxt += k + " "
    if mode == "ape":
        var t := maxi(0, int(round_t))
        hud.text = "LOOT %d   RECYCLED %d/%d   CARRY %d\n%d:%02d\n%s" % [items.size(), recycled, quota, carried, t / 60, t % 60, modtxt]
        if not round_over:
            round_t -= dt
            if round_t <= 0.0:
                _end_round(false)
    else:
        hud.text = "GILLA   LVL %d   $%d\n%s\n%s" % [Game.level(), Game.money, net.status, modtxt]
    if end_t > 0.0:
        end_t -= dt
        if end_t <= 0.0:
            _enter_lobby()
    _update_grab()
    _update_drops(dt)
    _weapon_and_punch(dt)
    _anim_mons()
    _net_tick(dt)
    _update_cam()
    board_t -= dt
    if board_t <= 0.0:
        board_t = 1.0
        _refresh_labels()
        _refresh_kick_rows()
    if round_over:
        return
    _check_items()
    _check_interact()


func _net_tick(dt: float) -> void:
    send_t += dt
    if send_t >= 0.066:
        send_t = 0.0
        net.send_state(player.cam.global_position, player.cam.global_rotation.y, player.ctrl["l"].global_position, player.ctrl["r"].global_position, Game.equipped)


func _update_cam() -> void:
    if cam_vp == null:
        return
    var head: Vector3 = player.cam.global_position
    var near: bool = head.distance_to(cam_screen.global_position) < 7.0
    cam_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if near else SubViewport.UPDATE_DISABLED
    if near:
        var yb := Basis(Vector3.UP, player.cam.global_rotation.y)
        cam_cam.global_position = head + yb * Vector3(0, 0.7, 2.6)
        cam_cam.look_at(head, Vector3.UP)


func _refresh_kick_rows() -> void:
    if mode != "mod":
        return
    var names: Array = net.names()
    for i in 6:
        var key := "k%d" % i
        if mod_btns.has(key):
            mod_btns[key]["label"].text = (names[i]["name"] if i < names.size() else "-")


# ---------------------------------------------------------------- grabbing weapons
func _update_grab() -> void:
    for s in ["l", "r"]:
        var c: XRController3D = player.ctrl[s]
        var grip: bool = c.get_float("grip") > 0.6
        if grip and held[s] == null and not grip_prev[s]:
            var best: Node3D = null
            var bd := 0.4
            for p in get_tree().get_nodes_in_group("pickup"):
                if p.has_meta("held"):
                    continue
                var d: float = (p as Node3D).global_position.distance_to(c.global_position)
                if d < bd:
                    bd = d
                    best = p
            if best:
                best.set_meta("held", true)
                if best.has_meta("falling"):
                    best.remove_meta("falling")
                best.reparent(c, false)
                var hr: Vector3 = best.get_meta("hold_rot")
                best.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(hr.x), deg_to_rad(hr.y), deg_to_rad(hr.z))), Vector3.ZERO)
                held[s] = best
                c.trigger_haptic_pulse("haptic", 0.0, 0.7, 0.1, 0.0)
        elif not grip and held[s] != null:
            var w: Node3D = held[s]
            w.reparent(world, true)
            w.remove_meta("held")
            w.set_meta("falling", true)
            held[s] = null
            tip_prev.erase(s)
        grip_prev[s] = grip


func _update_drops(dt: float) -> void:
    var space := get_world_3d().direct_space_state
    for p in get_tree().get_nodes_in_group("pickup"):
        if p.has_meta("held") or not p.has_meta("falling"):
            continue
        var pos: Vector3 = (p as Node3D).global_position
        var q := PhysicsRayQueryParameters3D.create(pos, pos - Vector3(0, 0.2, 0), 1)
        if space.intersect_ray(q).is_empty():
            (p as Node3D).global_position.y -= 4.0 * dt
        else:
            p.remove_meta("falling")


# ---------------------------------------------------------------- hitting things
func _weapon_and_punch(dt: float) -> void:
    for k in hit_cd.keys():
        hit_cd[k] -= dt
        if hit_cd[k] <= 0.0:
            hit_cd.erase(k)
    for s in ["l", "r"]:
        var w = held[s]
        if w == null:
            continue
        var tip: Node3D = w.get_node_or_null("Tip")
        if tip == null:
            continue
        var tp: Vector3 = tip.global_position
        var sp := 0.0
        var dir := Vector3.ZERO
        if tip_prev.has(s):
            var dd: Vector3 = tp - tip_prev[s]
            sp = dd.length() / maxf(dt, 0.001)
            if dd.length() > 0.0001:
                dir = dd.normalized()
        tip_prev[s] = tp
        var kind: String = w.get_meta("kind")
        var saw_on: bool = kind == "chainsaw" and player.ctrl[s].get_float("trigger") > 0.5
        if kind == "chainsaw":
            w.position = Vector3(randf_range(-0.004, 0.004), randf_range(-0.004, 0.004), 0.0) if saw_on else Vector3.ZERO
        if sp > 2.2 or saw_on:
            _strike(s, tp, dir, maxf(sp, 3.0 if saw_on else 0.0), float(w.get_meta("dmg")), kind, saw_on)
    if punch_mode > 0:
        for s in ["l", "r"]:
            if held[s] != null:
                continue
            var sp2: float = player.hand_speed[s]
            if sp2 > 3.2:
                _strike(s, player.ctrl[s].global_position, player.hand_dir[s], sp2, 0.3, "fist", false)


func _strike(s: String, p: Vector3, dir: Vector3, sp: float, dmg: float, kind: String, sustained: bool) -> void:
    var key := s + kind
    if hit_cd.has(key):
        return
    for m in mons:
        if m["dead_t"] > 0.0:
            continue
        var n: CharacterBody3D = m["node"]
        var c := n.global_position + Vector3(0, 1.0, 0)
        if p.distance_to(c) < 0.85:
            hit_cd[key] = 0.12 if sustained else 0.45
            _blood_burst(p)
            player.ctrl[s].trigger_haptic_pulse("haptic", 0.0, 1.0, 0.12, 0.0)
            m["kb"] = dir * clampf(sp, 2.0, 9.0) * (1.4 if kind == "hammer" else 0.6)
            m["kb_t"] = 0.35
            if m.get("dummy", false):
                m["hp"] = 99.0
            else:
                m["hp"] -= dmg
                if m["hp"] <= 0.0:
                    m["dead_t"] = 12.0
                    Game.add_xp(15)
                    _say("KILLED IT!  +15 XP")
            return
    for id in net.visible_ids():
        if p.distance_to(net.peer_center(id)) < 0.8:
            hit_cd[key] = 0.5
            var mult := 1.6 if kind == "hammer" else (1.0 if punch_mode != 2 else 1.8)
            net.send_hit(id, dir * clampf(sp * 1.2, 3.0, 10.0) * mult + Vector3(0, 2.0, 0))
            player.ctrl[s].trigger_haptic_pulse("haptic", 0.0, 1.0, 0.12, 0.0)
            return


func _on_net_hit(v: Vector3) -> void:
    player.launch(v)
    for s in ["l", "r"]:
        player.ctrl[s].trigger_haptic_pulse("haptic", 0.0, 1.0, 0.2, 0.0)


func _on_net_kick() -> void:
    _say("YOU WERE KICKED FROM THE ROOM")
    net.stop()


# ---------------------------------------------------------------- items / interaction
func _check_items() -> void:
    var head: Vector3 = player.cam.global_position
    for it in items.duplicate():
        var p: Vector3 = it["n"].global_position
        if _near(p, 0.3) or head.distance_to(p) < 0.5:
            carried += 1
            it["n"].queue_free()
            items.erase(it)
            _say("PICKED UP " + ("GOLD" if it["kind"] == "gold" else "DIAMOND"))


func _check_interact() -> void:
    if inter_cd > 0.0:
        return
    for it in inter:
        if _near(it["pos"], it["r"]):
            inter_cd = 0.6
            _activate(it["a"], str(it.get("arg", "")))
            return


func _is_mod() -> bool:
    # server-verified mod status; offline private builds with a token also count
    return net.is_mod or (Game.mod_token() != "" and Game.server_url() == "")


func _toggle_mod(k: String) -> void:
    mods[k] = not mods[k]
    _apply_mods()


func _apply_mods() -> void:
    player.speed_mult = 1.6 if mods["speed"] else 1.0
    player.jump_mult = 1.9 if mods["jump"] else 1.1
    player.gravity_scale = 0.35 if mods["lowgrav"] else 1.0
    player.fly = mods["fly"]
    player.platforms = mods["plat"]
    player.noclip = mods["noclip"]
    for k in mod_btns:
        if mods.has(k):
            var on: bool = mods[k]
            mod_btns[k]["mi"].material_override = mats.glow(Color(0.1, 0.9, 0.2) if on else Color(0.8, 0.1, 0.1), 1.5)
            mod_btns[k]["label"].text = "%s  %s" % [mod_btns[k]["text"], "ON" if on else "OFF"]


func _activate(a: String, arg: String) -> void:
    match a:
        "ape":
            _enter_ape()
        "mod":
            if _is_mod():
                _enter_mod()
            else:
                _say("MOD ROOM IS FOR MODS ONLY")
        "lobby":
            _enter_lobby()
        "fur":
            var nxt: int = (Game.equipped + 1) % Game.FUR.size()
            var f: Dictionary = Game.FUR[nxt]
            if Game.owned.has(nxt):
                Game.equipped = nxt
            elif Game.money >= int(f["cost"]):
                Game.money -= int(f["cost"])
                Game.owned.append(nxt)
                Game.equipped = nxt
                _say("BOUGHT " + str(f["name"]))
            else:
                _say("NOT ENOUGH MONEY")
                return
            Game.save_game()
            player.set_tint(Game.FUR[Game.equipped]["color"])
            _refresh_labels()
        "room":
            Game.room_idx = (Game.room_idx + 1) % Game.ROOMS.size()
            Game.save_game()
            net.change_room(Game.ROOMS[Game.room_idx])
            _say("ROOM: " + str(Game.ROOMS[Game.room_idx]))
            _refresh_labels()
        "punch":
            punch_mode = (punch_mode + 1) % 3
            _refresh_labels()
        "mod_toggle":
            _toggle_mod(arg)
        "mod_reset":
            for k in mods:
                mods[k] = false
            _apply_mods()
        "weapons_reset":
            _enter_mod()
        "kick":
            var idx := int(arg.substr(1))
            var names: Array = net.names()
            if idx < names.size():
                if net.is_mod:
                    net.send_kick(int(names[idx]["id"]))
                    _say("KICKED " + str(names[idx]["name"]))
                else:
                    net.send_hit(int(names[idx]["id"]), Vector3(0, 12, 0))
                    _say("YEETED " + str(names[idx]["name"]))
        "recycle":
            if carried <= 0:
                _say("BRING LOOT HERE")
                return
            recycled += carried
            Game.add_money(carried * item_val)
            Game.add_xp(carried * 5)
            _say("RECYCLED  +$%d" % (carried * item_val))
            carried = 0
            if recycled >= quota and not exit_open:
                exit_open = true
                if exit_node:
                    for ch in exit_node.get_children():
                        if ch is MeshInstance3D:
                            (ch as MeshInstance3D).material_override = mats.glow(Color(0.2, 1.0, 0.3), 2.0)
                _say("EXIT OPEN!  GET OUT!")
        "exit":
            if exit_open:
                _end_round(true)
            else:
                _say("RECYCLE %d MORE" % maxi(0, quota - recycled))


func _end_round(win: bool) -> void:
    round_over = true
    end_t = 3.5
    if win:
        Game.add_money(150)
        Game.add_xp(60)
        _say("YOU ESCAPED!   +$150  +60 XP")
    else:
        _say("TIME UP")


# ---------------------------------------------------------------- creatures
func _los(a: Vector3, b: Vector3) -> bool:
    var q := PhysicsRayQueryParameters3D.create(a, b, 1)
    return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _anim_mons() -> void:
    for m in mons:
        props.animate(m["model"], t_anim + float(m["speed"]), m.get("moving", false), 7.0)


func _physics_process(dt: float) -> void:
    if mons.is_empty() or round_over or dt <= 0.0:
        return
    var head: Vector3 = player.cam.global_position
    for m in mons:
        var n: CharacterBody3D = m["node"]
        var model: Node3D = m["model"]
        if m["dead_t"] > 0.0:
            m["dead_t"] -= dt
            model.rotation.x = lerpf(model.rotation.x, -1.4, minf(1.0, dt * 6.0))
            m["moving"] = false
            if m["dead_t"] <= 0.0:
                model.rotation.x = 0.0
                m["hp"] = 4.0 if m["kind"] == "gold" else 3.0
                n.global_position = m["start"]
            continue
        var mp := n.global_position
        var d := Vector3.ZERO
        var spd: float = m["speed"]
        var chase := false
        if m.get("kb_t", 0.0) > 0.0:
            m["kb_t"] -= dt
            n.velocity.x = m["kb"].x
            n.velocity.z = m["kb"].z
            m["moving"] = false
        elif spd > 0.0:
            var flat := head - mp
            flat.y = 0.0
            chase = flat.length() < 22.0 and _los(mp + Vector3(0, 1.2, 0), head)
            m["tt"] -= dt
            if m["tt"] <= 0.0 or Vector2(mp.x - m["target"].x, mp.z - m["target"].z).length() < 1.5:
                m["tt"] = 8.0
                m["target"] = _pick_floor(mp, 5.0, 60.0) if mode == "ape" else mp
            var target: Vector3 = head if chase else m["target"]
            if chase:
                spd *= 1.15
            d = target - mp
            d.y = 0.0
            d = d.normalized() if d.length() > 0.01 else Vector3.ZERO
            n.velocity.x = d.x * spd
            n.velocity.z = d.z * spd
            m["moving"] = d != Vector3.ZERO
        else:
            n.velocity.x = 0.0
            n.velocity.z = 0.0
            m["moving"] = false
        if n.is_on_floor():
            n.velocity.y = -0.5
        else:
            n.velocity.y -= 9.8 * dt
        n.move_and_slide()
        if d != Vector3.ZERO:
            n.rotation.y = lerp_angle(n.rotation.y, atan2(-d.x, -d.z), minf(1.0, dt * 8.0))
        if spd > 0.0 and not chase and n.get_real_velocity().length() < 0.4:
            m["stuck"] += dt
            if m["stuck"] > 1.5:
                m["tt"] = 0.0
                m["stuck"] = 0.0
        else:
            m["stuck"] = 0.0
        if mode == "ape" and not m.get("dummy", false):
            var fl := head - n.global_position
            fl.y = 0.0
            if fl.length() < 1.0 and absf(head.y - n.global_position.y) < 2.6:
                carried = 0
                _say("IT GOT YOU!  LOST YOUR LOOT")
                player.respawn()
                n.global_position = m["start"]
                m["tt"] = 0.0
