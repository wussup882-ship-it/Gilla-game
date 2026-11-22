extends CharacterBody3D

const SHOULDER := Vector3(0.19, -0.24, 0.0)

var origin: XROrigin3D
var cam: XRCamera3D
var ctrl := {}
var arm_mesh := {}
var last := {}
var hand_speed := {"l": 0.0, "r": 0.0}
var hand_dir := {"l": Vector3.ZERO, "r": Vector3.ZERO}
var vel := Vector3.ZERO
var hist: Array = []
var was_touching := false
var turn_latched := false
var shape_node: CollisionShape3D
var sphere := SphereShape3D.new()
var arm_mat: ShaderMaterial
var spawn_pos := Vector3(0, 0.2, 0)
var plats := {}

# mod settings (changed by the mod menu)
var speed_mult := 1.0
var jump_mult := 1.1
var gravity_scale := 1.0
var fly := false
var noclip := false
var platforms := false
var max_speed := 6.5
var mats


func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    sphere.radius = 0.1
    origin = XROrigin3D.new()
    add_child(origin)
    cam = XRCamera3D.new()
    origin.add_child(cam)
    var cap := CapsuleShape3D.new()
    cap.radius = 0.15
    cap.height = 0.5
    shape_node = CollisionShape3D.new()
    shape_node.shape = cap
    add_child(shape_node)
    # arms use the ORIGINAL gorilla fur texture from the model, plus blood splatter
    var tex = null
    if ResourceLoader.exists("res://gilla_img0.png"):
        tex = load("res://gilla_img0.png")
    arm_mat = mats.arm_material(tex)
    for s in ["l", "r"]:
        var c := XRController3D.new()
        c.tracker = "left_hand" if s == "l" else "right_hand"
        origin.add_child(c)
        ctrl[s] = c
        var h := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.055
        sm.height = 0.11
        h.mesh = sm
        h.material_override = arm_mat
        c.add_child(h)
        for i in 4:
            var f := MeshInstance3D.new()
            var fm := CapsuleMesh.new()
            fm.radius = 0.014
            fm.height = 0.09
            f.mesh = fm
            f.material_override = arm_mat
            f.position = Vector3((i - 1.5) * 0.024, 0.0, -0.075)
            f.rotation_degrees = Vector3(-90, 0, 0)
            c.add_child(f)
        var a := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.03
        cm.bottom_radius = 0.06
        cm.height = 1.0
        cm.radial_segments = 10
        cm.rings = 1
        a.mesh = cm
        a.material_override = arm_mat
        a.top_level = true
        add_child(a)
        arm_mesh[s] = a


func set_tint(c: Color) -> void:
    arm_mat.set_shader_parameter("tint", c)


func launch(v: Vector3) -> void:
    vel = v
    was_touching = false
    hist.clear()


func respawn() -> void:
    global_position = spawn_pos
    vel = Vector3.ZERO
    last.clear()
    hist.clear()
    was_touching = false


func _physics_process(dt: float) -> void:
    if dt <= 0.0:
        return
    collision_mask = 0 if noclip else 1
    shape_node.global_position = cam.global_position + Vector3(0, -0.35, 0)
    _snap_turn()
    var space := get_world_3d().direct_space_state
    var move := Vector3.ZERO
    var hand_vel := Vector3.ZERO
    var n := 0
    for s in ctrl:
        var c: XRController3D = ctrl[s]
        var lp: Vector3 = to_local(c.global_position)
        if not last.has(s):
            last[s] = lp
        var d: Vector3 = global_transform.basis * (lp - last[s])
        last[s] = lp
        hand_speed[s] = d.length() / dt
        hand_dir[s] = d.normalized() if d.length() > 0.0001 else Vector3.ZERO
        _platform(s, c)
        if noclip:
            continue
        var q := PhysicsShapeQueryParameters3D.new()
        q.shape = sphere
        q.transform = Transform3D(Basis(), c.global_position)
        q.collision_mask = 1
        q.exclude = [get_rid()]
        if not space.intersect_shape(q, 1).is_empty():
            n += 1
            move -= d * speed_mult
            hand_vel -= d * speed_mult / dt
    if fly or noclip:
        var thrust := maxf(ctrl["l"].get_float("trigger"), ctrl["r"].get_float("trigger"))
        if thrust > 0.4:
            vel = -cam.global_transform.basis.z * 7.0 * speed_mult
        else:
            vel *= 0.9
        if noclip:
            global_position += vel * dt
        else:
            move_and_collide(vel * dt)
        was_touching = false
        return
    if n > 0:
        move /= float(n)
        hand_vel /= float(n)
        hist.append(hand_vel)
        if hist.size() > 6:
            hist.pop_front()
        vel = Vector3.ZERO
        move_and_collide(move)
        was_touching = true
    else:
        if was_touching:
            var avg := Vector3.ZERO
            for v in hist:
                avg += v
            if hist.size() > 0:
                avg /= float(hist.size())
            vel = avg * jump_mult
            var cap_speed := max_speed * speed_mult * (1.0 + (jump_mult - 1.1) * 0.5)
            if vel.length() > cap_speed:
                vel = vel.normalized() * cap_speed
            hist.clear()
            was_touching = false
        vel.y -= 9.8 * gravity_scale * dt
        vel *= 0.998
        var col := move_and_collide(vel * dt)
        if col:
            var nrm := col.get_normal()
            vel = vel.slide(nrm)
            if nrm.y > 0.6:
                vel.x *= 0.85
                vel.z *= 0.85
    if global_position.y < -400.0:
        respawn()


func _platform(s: String, c: XRController3D) -> void:
    var want: bool = platforms and c.is_button_pressed("ax_button")
    if want and not plats.has(s):
        var b := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        var sh := BoxShape3D.new()
        sh.size = Vector3(0.8, 0.06, 0.8)
        cs.shape = sh
        b.add_child(cs)
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = sh.size
        mi.mesh = bm
        mi.material_override = mats.glow(Color(0.3, 0.9, 1.0), 1.2)
        b.add_child(mi)
        b.top_level = true
        add_child(b)
        b.global_position = c.global_position - Vector3(0, 0.1, 0)
        plats[s] = b
    elif not want and plats.has(s):
        plats[s].queue_free()
        plats.erase(s)


func _snap_turn() -> void:
    var c: XRController3D = ctrl["r"]
    var x: float = c.get_vector2("primary").x
    if absf(x) > 0.7 and not turn_latched:
        turn_latched = true
        var before := cam.global_position
        rotate_y(deg_to_rad(-30.0 * signf(x)))
        global_position += before - cam.global_position
        last.clear()
    elif absf(x) < 0.3:
        turn_latched = false


func _process(_dt: float) -> void:
    var yaw := Basis(Vector3.UP, cam.global_rotation.y)
    for s in ctrl:
        var side := -1.0 if s == "l" else 1.0
        var sh: Vector3 = cam.global_position + yaw * Vector3(SHOULDER.x * side, SHOULDER.y, SHOULDER.z)
        _place(arm_mesh[s], sh, ctrl[s].global_position)


func _place(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
    var d := b - a
    var l := d.length()
    if l < 0.02:
        return
    var y := d / l
    var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
    var x := ref.cross(y).normalized()
    var z := x.cross(y)
    mi.global_transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)
