extends Node

const Props = preload("res://props.gd")

var ws := WebSocketPeer.new()
var url := ""
var room := "GILLA-1"
var pname := "Ape"
var token := ""
var active := false
var open := false
var my_id := 0
var is_mod := false
var cur_mode := "lobby"
var peers := {}
var parent_node: Node3D
var model_scene: PackedScene
var arm_tex
var reconnect_t := 0.0
var send_t := 0.0
var on_hit: Callable
var on_kick: Callable
var status := "OFFLINE"


func start(u: String, r: String, n: String, tok: String, parent: Node3D, model: PackedScene, tex) -> void:
    url = u
    room = r
    pname = n
    token = tok
    parent_node = parent
    model_scene = model
    arm_tex = tex
    if url == "":
        status = "OFFLINE (no server set)"
        return
    active = true
    _connect()


func change_room(r: String) -> void:
    room = r
    _drop_peers()
    if active:
        ws.close()
        open = false
        reconnect_t = 0.2
    elif url != "":
        active = true
        _connect()


func stop() -> void:
    active = false
    open = false
    ws.close()
    _drop_peers()
    status = "OFFLINE"


func _connect() -> void:
    ws = WebSocketPeer.new()
    var err := ws.connect_to_url(url)
    status = "CONNECTING..." if err == OK else "BAD SERVER URL"
    open = false


func _drop_peers() -> void:
    for id in peers:
        if peers[id]["node"]:
            peers[id]["node"].queue_free()
    peers.clear()


func names() -> Array:
    var out: Array = []
    for id in peers:
        out.append({"id": id, "name": peers[id]["name"]})
    return out


func send(d: Dictionary) -> void:
    if open and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        ws.send_text(JSON.stringify(d))


func send_state(head: Vector3, yaw: float, l: Vector3, r: Vector3, fur: int) -> void:
    send({"t": "st", "p": [head.x, head.y, head.z, yaw], "l": [l.x, l.y, l.z], "r": [r.x, r.y, r.z], "m": cur_mode, "f": fur})


func send_hit(id: int, v: Vector3) -> void:
    send({"t": "hit", "to": id, "v": [v.x, v.y, v.z]})


func send_kick(id: int) -> void:
    send({"t": "kick", "to": id})


func peer_center(id: int) -> Vector3:
    if not peers.has(id):
        return Vector3(0, -999, 0)
    return peers[id]["head"] - Vector3(0, 0.45, 0)


func visible_ids() -> Array:
    var out: Array = []
    for id in peers:
        if peers[id]["mode"] == cur_mode:
            out.append(id)
    return out


func _process(dt: float) -> void:
    if not active:
        return
    ws.poll()
    var st := ws.get_ready_state()
    if st == WebSocketPeer.STATE_OPEN:
        if not open:
            open = true
            status = "ONLINE"
            send({"t": "join", "room": room, "name": pname, "tok": token})
        while ws.get_available_packet_count() > 0:
            _handle(ws.get_packet().get_string_from_utf8())
    elif st == WebSocketPeer.STATE_CLOSED:
        if open:
            open = false
            status = "DISCONNECTED"
            _drop_peers()
            reconnect_t = 4.0
        reconnect_t -= dt
        if reconnect_t <= 0.0:
            reconnect_t = 6.0
            _connect()
    _update_peers(dt)


func _handle(raw: String) -> void:
    var m = JSON.parse_string(raw)
    if typeof(m) != TYPE_DICTIONARY:
        return
    match str(m.get("t", "")):
        "welcome":
            my_id = int(m.get("id", 0))
            is_mod = bool(m.get("mod", false))
            status = "ONLINE  %s" % room
            for p in m.get("peers", []):
                _ensure(int(p["id"]), str(p["name"]))
        "joined":
            _ensure(int(m["id"]), str(m.get("name", "ape")))
        "left":
            var id := int(m.get("id", 0))
            if peers.has(id):
                if peers[id]["node"]:
                    peers[id]["node"].queue_free()
                peers.erase(id)
        "st":
            var id := int(m.get("id", 0))
            _ensure(id, "ape")
            var p: Array = m["p"]
            var l: Array = m["l"]
            var r: Array = m["r"]
            var d: Dictionary = peers[id]
            d["t_head"] = Vector3(p[0], p[1], p[2])
            d["t_yaw"] = float(p[3])
            d["t_l"] = Vector3(l[0], l[1], l[2])
            d["t_r"] = Vector3(r[0], r[1], r[2])
            d["mode"] = str(m.get("m", "lobby"))
            if d["first"]:
                d["first"] = false
                d["head"] = d["t_head"]
                d["l"] = d["t_l"]
                d["r"] = d["t_r"]
                d["yaw"] = d["t_yaw"]
        "hit":
            var v: Array = m["v"]
            if on_hit.is_valid():
                on_hit.call(Vector3(v[0], v[1], v[2]))
        "kicked":
            if on_kick.is_valid():
                on_kick.call()


func _ensure(id: int, nm: String) -> void:
    if id == my_id or peers.has(id):
        return
    var root := Node3D.new()
    parent_node.add_child(root)
    var body := Node3D.new()
    root.add_child(body)
    if model_scene:
        var inst: Node3D = model_scene.instantiate()
        body.add_child(inst)
        Props.fit(inst, 1.2)
    else:
        var mi := MeshInstance3D.new()
        var cm := CapsuleMesh.new()
        cm.radius = 0.25
        cm.height = 1.0
        mi.mesh = cm
        mi.position = Vector3(0, 0.5, 0)
        body.add_child(mi)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.1, 0.75, 0.1)
    if arm_tex:
        mat.albedo_texture = arm_tex
    mat.uv1_triplanar = true
    var arms := {}
    for s in ["l", "r"]:
        var a := MeshInstance3D.new()
        var cy := CylinderMesh.new()
        cy.top_radius = 0.03
        cy.bottom_radius = 0.06
        cy.height = 1.0
        cy.radial_segments = 8
        a.mesh = cy
        a.material_override = mat
        a.top_level = true
        root.add_child(a)
        arms[s] = a
        var h := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.06
        sm.height = 0.12
        h.mesh = sm
        h.material_override = mat
        h.top_level = true
        root.add_child(h)
        arms[s + "h"] = h
    var lab := Label3D.new()
    lab.text = nm
    lab.font_size = 48
    lab.pixel_size = 0.003
    lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    lab.no_depth_test = true
    lab.modulate = Color(1, 1, 1)
    root.add_child(lab)
    peers[id] = {"name": nm, "node": root, "body": body, "arms": arms, "label": lab,
        "head": Vector3.ZERO, "l": Vector3.ZERO, "r": Vector3.ZERO, "yaw": 0.0,
        "t_head": Vector3.ZERO, "t_l": Vector3.ZERO, "t_r": Vector3.ZERO, "t_yaw": 0.0,
        "mode": "lobby", "first": true}


func _update_peers(dt: float) -> void:
    var k := minf(1.0, dt * 14.0)
    for id in peers:
        var d: Dictionary = peers[id]
        var root: Node3D = d["node"]
        root.visible = (d["mode"] == cur_mode) and not d["first"]
        d["head"] = d["head"].lerp(d["t_head"], k)
        d["l"] = d["l"].lerp(d["t_l"], k)
        d["r"] = d["r"].lerp(d["t_r"], k)
        d["yaw"] = lerp_angle(d["yaw"], d["t_yaw"], k)
        var body: Node3D = d["body"]
        body.global_position = d["head"] - Vector3(0, 0.75, 0)
        body.rotation.y = d["yaw"] + PI
        var lab: Label3D = d["label"]
        lab.global_position = d["head"] + Vector3(0, 0.4, 0)
        var yawb := Basis(Vector3.UP, d["yaw"])
        for s in ["l", "r"]:
            var side := -1.0 if s == "l" else 1.0
            var sh: Vector3 = d["head"] + yawb * Vector3(0.19 * side, -0.24, 0.0)
            var hp: Vector3 = d[s]
            var arm: MeshInstance3D = d["arms"][s]
            var dd := hp - sh
            var ln := dd.length()
            if ln > 0.02:
                var y := dd / ln
                var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
                var x := ref.cross(y).normalized()
                var z := x.cross(y)
                arm.global_transform = Transform3D(Basis(x, y * ln, z), (sh + hp) * 0.5)
            d["arms"][s + "h"].global_position = hp
