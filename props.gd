extends RefCounted

var mats


func _init(m = null) -> void:
    mats = m


static func fit(inst: Node3D, h: float) -> void:
    var best := 0.0
    for mi in inst.find_children("*", "MeshInstance3D", true, false):
        best = maxf(best, (mi as MeshInstance3D).get_aabb().size.y)
    if best > 0.001:
        inst.scale = Vector3.ONE * (h / best)


func _p(col: Color, metal: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
    return mats.paint(col, metal, rough)


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.rotation_degrees = rot
    mi.scale = scl
    parent.add_child(mi)
    return mi


func _cyl(parent: Node3D, pos: Vector3, rt: float, rb: float, h: float, mat: Material, rot: Vector3 = Vector3.ZERO, seg: int = 14) -> MeshInstance3D:
    var m := CylinderMesh.new()
    m.top_radius = rt
    m.bottom_radius = rb
    m.height = h
    m.radial_segments = seg
    m.rings = 1
    return _add(parent, m, pos, mat, rot)


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var m := BoxMesh.new()
    m.size = size
    return _add(parent, m, pos, mat, rot)


func _sph(parent: Node3D, pos: Vector3, r: float, mat: Material, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var m := SphereMesh.new()
    m.radius = r
    m.height = r * 2.0
    m.radial_segments = 16
    m.rings = 8
    return _add(parent, m, pos, mat, Vector3.ZERO, scl)


func _cap(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var m := CapsuleMesh.new()
    m.radius = r
    m.height = maxf(h, r * 2.0 + 0.001)
    m.radial_segments = 12
    m.rings = 4
    return _add(parent, m, pos, mat, rot)


func _torus(parent: Node3D, pos: Vector3, inner: float, outer: float, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var m := TorusMesh.new()
    m.inner_radius = inner
    m.outer_radius = outer
    m.rings = 16
    m.ring_segments = 8
    return _add(parent, m, pos, mat, rot)


func _marker(parent: Node3D, pos: Vector3, nm: String) -> void:
    var t := Marker3D.new()
    t.name = nm
    t.position = pos
    parent.add_child(t)


func _blood(parent: Node3D, pos: Vector3, size: Vector3) -> void:
    _box(parent, pos, size, _p(Color(0.45, 0.02, 0.02), 0.0, 0.25))


# ------------------------------------------------------------------ weapons
# Every weapon: grip point at the node origin, "Tip" marker at the hitting part,
# meta kind / hold_rot (degrees) / dmg.
func hammer() -> Node3D:
    var n := Node3D.new()
    var wood := _p(Color(0.45, 0.28, 0.12), 0.0, 0.75)
    var steel := _p(Color(0.55, 0.57, 0.6), 0.9, 0.3)
    var red := _p(Color(0.75, 0.05, 0.05), 0.6, 0.35)
    var leather := _p(Color(0.08, 0.06, 0.05), 0.0, 0.9)
    _cyl(n, Vector3(0, 0.3, 0), 0.022, 0.026, 0.72, wood)
    _cyl(n, Vector3(0, 0.08, 0), 0.03, 0.03, 0.2, leather)
    for i in 4:
        _torus(n, Vector3(0, 0.0 + i * 0.045, 0), 0.026, 0.033, leather, Vector3(90, 0, 0))
    _cyl(n, Vector3(0, 0.67, 0), 0.034, 0.034, 0.05, steel)
    _box(n, Vector3(0, 0.74, 0), Vector3(0.34, 0.15, 0.15), red)
    for sx in [-1, 1]:
        _cyl(n, Vector3(sx * 0.18, 0.74, 0), 0.085, 0.085, 0.03, steel, Vector3(0, 0, 90))
        _cyl(n, Vector3(sx * 0.1, 0.74, 0), 0.08, 0.08, 0.02, steel, Vector3(0, 0, 90))
    var l := Label3D.new()
    l.text = "KICK"
    l.font_size = 40
    l.pixel_size = 0.0018
    l.modulate = Color(1, 1, 1)
    l.position = Vector3(0, 0.74, 0.077)
    n.add_child(l)
    _marker(n, Vector3(0, 0.74, 0), "Tip")
    n.set_meta("kind", "hammer")
    n.set_meta("hold_rot", Vector3(-55, 0, 0))
    n.set_meta("dmg", 1.0)
    return n


func axe() -> Node3D:
    var n := Node3D.new()
    var wood := _p(Color(0.5, 0.33, 0.16), 0.0, 0.8)
    var steel := _p(Color(0.6, 0.62, 0.66), 0.95, 0.25)
    _cyl(n, Vector3(0, 0.34, 0), 0.02, 0.026, 0.82, wood)
    _sph(n, Vector3(0, -0.07, 0), 0.032, wood, Vector3(1, 0.6, 1))
    _box(n, Vector3(0, 0.72, 0), Vector3(0.07, 0.14, 0.055), steel)
    var pm := PrismMesh.new()
    pm.size = Vector3(0.24, 0.2, 0.035)
    _add(n, pm, Vector3(0.12, 0.72, 0), steel, Vector3(0, 0, 90))
    _box(n, Vector3(-0.08, 0.72, 0), Vector3(0.1, 0.07, 0.05), steel)
    _blood(n, Vector3(0.16, 0.76, 0.02), Vector3(0.06, 0.05, 0.01))
    _blood(n, Vector3(0.22, 0.69, 0.02), Vector3(0.04, 0.07, 0.01))
    _blood(n, Vector3(0, 0.45, 0.02), Vector3(0.04, 0.12, 0.045))
    _marker(n, Vector3(0.22, 0.72, 0), "Tip")
    n.set_meta("kind", "axe")
    n.set_meta("hold_rot", Vector3(-60, 0, 0))
    n.set_meta("dmg", 2.0)
    return n


func pickaxe() -> Node3D:
    var n := Node3D.new()
    var wood := _p(Color(0.4, 0.26, 0.12), 0.0, 0.8)
    var iron := _p(Color(0.35, 0.37, 0.4), 0.9, 0.4)
    _cyl(n, Vector3(0, 0.36, 0), 0.02, 0.025, 0.88, wood)
    _box(n, Vector3(0, 0.8, 0), Vector3(0.06, 0.06, 0.06), iron)
    for sx in [-1, 1]:
        _cyl(n, Vector3(sx * 0.17, 0.8, 0), 0.0, 0.028, 0.3, iron, Vector3(0, 0, -sx * 90))
        _cyl(n, Vector3(sx * 0.2, 0.775, 0), 0.0, 0.026, 0.14, iron, Vector3(0, 0, -sx * 90 + sx * 25))
    _blood(n, Vector3(0.22, 0.79, 0.0), Vector3(0.05, 0.03, 0.04))
    _marker(n, Vector3(0.33, 0.8, 0), "Tip")
    n.set_meta("kind", "pickaxe")
    n.set_meta("hold_rot", Vector3(-60, 0, 0))
    n.set_meta("dmg", 1.5)
    return n


func chainsaw() -> Node3D:
    var n := Node3D.new()
    var orange := _p(Color(0.95, 0.4, 0.05), 0.2, 0.45)
    var black := _p(Color(0.05, 0.05, 0.05), 0.3, 0.5)
    var steel := _p(Color(0.7, 0.72, 0.75), 0.95, 0.2)
    _box(n, Vector3(0, 0.02, -0.05), Vector3(0.13, 0.16, 0.3), orange)
    _box(n, Vector3(0, 0.1, -0.02), Vector3(0.1, 0.05, 0.2), black)
    _torus(n, Vector3(0, 0.1, 0.17), 0.03, 0.065, black, Vector3(0, 90, 0))
    _cyl(n, Vector3(0, 0.1, -0.15), 0.014, 0.014, 0.16, black, Vector3(0, 0, 90))
    _cyl(n, Vector3(0, -0.01, 0.1), 0.012, 0.012, 0.07, steel, Vector3(90, 0, 0))
    _box(n, Vector3(0, 0.0, -0.46), Vector3(0.03, 0.1, 0.52), steel)
    _box(n, Vector3(0, 0.0, -0.46), Vector3(0.036, 0.112, 0.54), black)
    for i in 12:
        _box(n, Vector3(0, 0.058, -0.22 - i * 0.043), Vector3(0.012, 0.012, 0.02), steel)
        _box(n, Vector3(0, -0.058, -0.22 - i * 0.043), Vector3(0.012, 0.012, 0.02), steel)
    _blood(n, Vector3(0.019, 0.0, -0.5), Vector3(0.004, 0.07, 0.2))
    _blood(n, Vector3(-0.019, 0.02, -0.38), Vector3(0.004, 0.06, 0.12))
    _marker(n, Vector3(0, 0, -0.65), "Tip")
    n.set_meta("kind", "chainsaw")
    n.set_meta("hold_rot", Vector3(0, 0, 0))
    n.set_meta("dmg", 0.9)
    return n


func make_weapon(kind: String) -> Node3D:
    match kind:
        "hammer":
            return hammer()
        "axe":
            return axe()
        "pickaxe":
            return pickaxe()
    return chainsaw()


# ------------------------------------------------------------------ scenery
func barrel(col: Color = Color(0.2, 0.35, 0.2)) -> Node3D:
    var n := Node3D.new()
    var body := _p(col, 0.5, 0.55)
    var band := _p(col.darkened(0.4), 0.7, 0.4)
    _cyl(n, Vector3(0, 0.45, 0), 0.29, 0.29, 0.9, body, Vector3.ZERO, 18)
    for y in [0.1, 0.45, 0.8]:
        _cyl(n, Vector3(0, y, 0), 0.305, 0.305, 0.04, band, Vector3.ZERO, 18)
    _cyl(n, Vector3(0, 0.91, 0), 0.25, 0.25, 0.02, band, Vector3.ZERO, 18)
    return n


func crate_stack() -> Node3D:
    var n := Node3D.new()
    var wood := _p(Color(0.5, 0.34, 0.17), 0.0, 0.85)
    var dark := _p(Color(0.28, 0.18, 0.08), 0.0, 0.9)
    var offs := [Vector3(0, 0, 0), Vector3(1.22, 0, 0.1), Vector3(0.5, 1.0, 0.05)]
    for o in offs:
        _box(n, o + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), wood)
        for sx in [-1, 1]:
            for sz in [-1, 1]:
                _box(n, o + Vector3(sx * 0.47, 0.5, sz * 0.47), Vector3(0.07, 1.02, 0.07), dark)
        _box(n, o + Vector3(0, 0.5, 0.505), Vector3(0.9, 0.08, 0.01), dark)
    return n


func shelf_rack() -> Node3D:
    var n := Node3D.new()
    var dark := _p(Color(0.15, 0.2, 0.28), 0.8, 0.45)
    var wood := _p(Color(0.5, 0.34, 0.17), 0.0, 0.85)
    for ix in [-1, 1]:
        for iz in [-1, 1]:
            _box(n, Vector3(ix * 0.9, 1.1, iz * 0.4), Vector3(0.07, 2.2, 0.07), dark)
    for y in [0.15, 0.85, 1.55, 2.2]:
        _box(n, Vector3(0, y, 0), Vector3(1.8, 0.05, 0.8), dark)
    for y in [0.15, 0.85, 1.55]:
        _box(n, Vector3(-0.4, y + 0.3, 0), Vector3(0.6, 0.5, 0.6), wood)
        _box(n, Vector3(0.4, y + 0.28, 0), Vector3(0.55, 0.45, 0.6), wood)
    return n


func lamp_post() -> Node3D:
    var n := Node3D.new()
    var dark := _p(Color(0.1, 0.1, 0.12), 0.8, 0.4)
    _cyl(n, Vector3(0, 1.4, 0), 0.04, 0.05, 2.8, dark)
    _cyl(n, Vector3(0, 0.05, 0), 0.2, 0.22, 0.1, dark)
    _box(n, Vector3(0, 2.85, 0), Vector3(0.5, 0.08, 0.2), mats.glow(Color(1, 0.95, 0.8), 3.0))
    return n


func vending() -> Node3D:
    var n := Node3D.new()
    var body := _p(Color(0.7, 0.08, 0.08), 0.5, 0.4)
    _box(n, Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.75), body)
    _box(n, Vector3(0, 1.15, 0.385), Vector3(0.7, 1.0, 0.02), mats.glow(Color(0.8, 0.95, 1.0), 1.5))
    for i in 6:
        _box(n, Vector3(-0.25 + (i % 3) * 0.25, 1.35 - (i / 3) * 0.45, 0.4), Vector3(0.14, 0.3, 0.02), _p(Color.from_hsv(i / 6.0, 0.8, 0.9), 0.0, 0.4))
    _box(n, Vector3(0, 0.3, 0.385), Vector3(0.5, 0.2, 0.02), _p(Color(0.05, 0.05, 0.05)))
    return n


func terminal() -> Node3D:
    var n := Node3D.new()
    var wood := _p(Color(0.5, 0.33, 0.17), 0.0, 0.8)
    var beige := _p(Color(0.85, 0.78, 0.65), 0.0, 0.6)
    _box(n, Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 0.8), wood)
    _box(n, Vector3(-0.35, 1.0, -0.05), Vector3(0.55, 0.45, 0.45), beige)
    _box(n, Vector3(-0.35, 1.03, 0.19), Vector3(0.45, 0.33, 0.03), mats.glow(Color(0.1, 0.45, 0.15), 1.2))
    _box(n, Vector3(0.3, 0.82, 0.1), Vector3(0.6, 0.04, 0.22), _p(Color(0.2, 0.2, 0.22)))
    for i in 6:
        _box(n, Vector3(0.1 + i * 0.1, 0.85, 0.1), Vector3(0.07, 0.03, 0.07), _p(Color(0.8, 0.8, 0.82)))
    return n


# ------------------------------------------------------------------ creatures
func _limb(parent: Node3D, pos: Vector3, r: float, length: float, mat: Material, nm: String) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = nm
    pivot.position = pos
    parent.add_child(pivot)
    _cap(pivot, Vector3(0, -length * 0.5, 0), r, length, mat)
    return pivot


func gold_suit() -> Node3D:
    var n := Node3D.new()
    var gold := _p(Color(0.95, 0.72, 0.1), 0.85, 0.22)
    var orange := _p(Color(0.95, 0.45, 0.05), 0.1, 0.5)
    var red := _p(Color(0.8, 0.05, 0.05), 0.2, 0.4)
    var white := _p(Color(1, 1, 1), 0.0, 0.3)
    var black := _p(Color(0.02, 0.02, 0.02))
    _cap(n, Vector3(0, 1.0, 0), 0.24, 0.9, gold)
    _box(n, Vector3(0, 1.1, 0.23), Vector3(0.08, 0.5, 0.03), red)
    _box(n, Vector3(0, 1.38, 0.22), Vector3(0.14, 0.06, 0.04), red)
    _sph(n, Vector3(0, 1.62, 0), 0.22, orange)
    for sx in [-1, 1]:
        _sph(n, Vector3(sx * 0.09, 1.66, 0.17), 0.065, white)
        _sph(n, Vector3(sx * 0.09, 1.66, 0.225), 0.03, black)
    _box(n, Vector3(0, 1.54, 0.2), Vector3(0.2, 0.04, 0.03), black)
    _cyl(n, Vector3(0, 1.88, 0), 0.0, 0.07, 0.16, red)
    var armL := _limb(n, Vector3(-0.3, 1.3, 0), 0.06, 0.65, gold, "ArmL")
    var armR := _limb(n, Vector3(0.3, 1.3, 0), 0.06, 0.65, gold, "ArmR")
    _sph(armL, Vector3(0, -0.7, 0), 0.09, orange)
    _sph(armR, Vector3(0, -0.7, 0), 0.09, orange)
    _limb(n, Vector3(-0.12, 0.6, 0), 0.07, 0.6, gold, "LegL")
    _limb(n, Vector3(0.12, 0.6, 0), 0.07, 0.6, gold, "LegR")
    _blood(n, Vector3(0.0, 1.25, 0.235), Vector3(0.18, 0.16, 0.01))
    var l := OmniLight3D.new()
    l.light_color = Color(1.0, 0.8, 0.3)
    l.light_energy = 0.8
    l.omni_range = 4.0
    l.position = Vector3(0, 1.4, 0.3)
    n.add_child(l)
    return n


func white_monster() -> Node3D:
    var n := Node3D.new()
    var skin := _p(Color(0.88, 0.88, 0.86), 0.0, 0.8)
    var eye := mats.glow(Color(1.0, 0.1, 0.05), 3.0)
    var body := Node3D.new()
    body.name = "Body"
    body.rotation_degrees = Vector3(14, 0, 0)
    n.add_child(body)
    _cap(body, Vector3(0, 1.15, 0), 0.13, 1.0, skin)
    _sph(body, Vector3(0, 1.8, 0.04), 0.1, skin, Vector3(0.85, 1.35, 0.95))
    for sx in [-1, 1]:
        _sph(body, Vector3(sx * 0.045, 1.83, 0.12), 0.022, eye)
    _limb(body, Vector3(-0.17, 1.55, 0), 0.04, 1.3, skin, "ArmL")
    _limb(body, Vector3(0.17, 1.55, 0), 0.04, 1.3, skin, "ArmR")
    _limb(n, Vector3(-0.08, 0.75, 0), 0.05, 0.75, skin, "LegL")
    _limb(n, Vector3(0.08, 0.75, 0), 0.05, 0.75, skin, "LegR")
    var l := OmniLight3D.new()
    l.light_color = Color(1.0, 0.1, 0.05)
    l.light_energy = 0.9
    l.omni_range = 5.0
    l.position = Vector3(0, 1.8, 0.4)
    n.add_child(l)
    return n


func animate(creature: Node3D, t: float, moving: bool, speed: float = 6.0) -> void:
    var s := sin(t * speed) * (0.7 if moving else 0.08)
    var body: Node3D = creature.get_node_or_null("Body")
    var root: Node3D = body if body else creature
    for nm in ["ArmL", "ArmR"]:
        var a: Node3D = root.get_node_or_null(nm)
        if a:
            a.rotation.x = s * (1.0 if nm == "ArmL" else -1.0) * 0.8
    for nm in ["LegL", "LegR"]:
        var l: Node3D = creature.get_node_or_null(nm)
        if l:
            l.rotation.x = s * (1.0 if nm == "LegL" else -1.0)
