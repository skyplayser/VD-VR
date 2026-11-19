# Start screen of VD VR: a small lounge in the style of VD-Link's club (quilted walls, black
# marble bar with lit bottle shelf, petrol velvet booths, aquarium, LED edges, LED wall with
# visuals) and a little light show of eight moving heads on a truss ring. The choice
# (Live / Saved / Demo) stands on a pedestal in front of you (menu pinned in the room).
# Everything is procedural (own geometry and shaders, no third-party assets).
extends RefCounted

const SURFACE := preload("res://shaders/surface.gdshader")
const GLOW := preload("res://shaders/glow.gdshader")
const AQUA := preload("res://shaders/aquarium.gdshader")
const ADD := preload("res://shaders/additive.gdshader")

const W := 12.0
const D := 10.0
const H := 4.6
const RING := Vector3(0, 4.15, -0.8)
const RING_R := 2.4
const HEADS := 8
const START := Vector3(0, 0, 2.7)
## Where the choice panel stands (centre of the panel; it faces +z, towards START).
const KIOSK := Vector3(0, 1.42, 1.25)

## Location for walls.gd / the height map / the room clamp.
var loc := {
	"room": { "width": W, "depth": D, "height": H },
	"objects": [{ "type": "videowall", "name": "LED", "pos": [0, 1.35, -D / 2 + 0.08], "rot": [0, 0, 0], "size": [5.6, 3.15, 0.12] }],
}
var _body: StaticBody3D
var _cache := {}


func build(parent: Node3D) -> void:
	_body = StaticBody3D.new()
	parent.add_child(_body)
	var floor_m := _lit("17171b", 0.32, 0.05, 0.6)
	var wall_m := _lit("1d1d22", 0.85, 0.0, 0.5, 1)
	var ceil_m := _lit("0c0c0e", 0.95, 0.0, 0.2)
	var marble := _lit("050506", 0.22, 0.1, 0.45, 2)
	var black_top := _lit("08080a", 0.18, 0.2, 0.4)
	var velvet := _lit("0f5d70", 0.95, 0.0, 0.45, 4, 0.5)
	var dark_metal := _lit("1b1c20", 0.45, 0.6, 0.35)
	var riser := _lit("141418", 0.6, 0.0, 0.5)
	var truss := _lit("b9bcc4", 0.35, 0.85, 0.35)
	var warm := _glow("ffd9a8", 3.2)
	var pink := _glow("ff3cc8", 4.0)
	var violet := _glow("b23cff", 4.0)
	var mint := _glow("6fcfb8", 0.42)

	# ---- room shell
	_box(parent, Vector3(0, -0.05, 0), Vector3(W, 0.1, D), floor_m)
	_box(parent, Vector3(0, H + 0.05, 0), Vector3(W, 0.1, D), ceil_m, false)
	_box(parent, Vector3(0, H / 2, -D / 2 - 0.1), Vector3(W, H, 0.2), wall_m)
	_box(parent, Vector3(0, H / 2, D / 2 + 0.1), Vector3(W, H, 0.2), wall_m)
	_box(parent, Vector3(-W / 2 - 0.1, H / 2, 0), Vector3(0.2, H, D), wall_m)
	_box(parent, Vector3(W / 2 + 0.1, H / 2, 0), Vector3(0.2, H, D), wall_m)

	# ---- DJ riser and booth in front of the LED wall
	_box(parent, Vector3(0, 0.175, -D / 2 + 1.0), Vector3(6.4, 0.35, 2.0), riser)
	_box(parent, Vector3(0, 0.33, -D / 2 + 2.01), Vector3(6.4, 0.025, 0.02), pink, false)
	_box(parent, Vector3(0, 0.015, -D / 2 + 2.04), Vector3(6.4, 0.02, 0.03), violet, false)
	_box(parent, Vector3(0, 0.35 + 0.53, -D / 2 + 1.25), Vector3(2.6, 1.06, 0.8), _lit("1c1c22", 0.4, 0.2, 0.45))
	_box(parent, Vector3(0, 0.35 + 1.09, -D / 2 + 1.2), Vector3(2.2, 0.05, 0.55), _glow("112244", 1.6), false)
	_neon(parent, "VD VR", Color("ff4fb4"), Vector3(0, 0.35 + 0.6, -D / 2 + 1.66), 0.0, 0.0032)
	# Frame around the LED wall.
	_box(parent, Vector3(0, 1.35 + 3.15 / 2, -D / 2 + 0.03), Vector3(5.8, 3.35, 0.06), _lit("0b0b0d", 0.6, 0.0, 0.5), false)

	# ---- bar (left wall): marble counter, black top, warm LED, lit bottle shelf, bulbs
	var bx := -W / 2 + 1.55
	var z0 := -1.8
	var z1 := 2.6
	var zc := (z0 + z1) / 2
	var bl := z1 - z0
	_box(parent, Vector3(bx - 0.38, 0.54, zc), Vector3(0.75, 1.08, bl), marble)
	_box(parent, Vector3(bx - 0.38, 1.11, zc), Vector3(0.95, 0.06, bl + 0.4), black_top)
	_box(parent, Vector3(bx + 0.02, 0.06, zc), Vector3(0.02, 0.03, bl), warm, false)
	var sx := -W / 2 + 0.3
	_box(parent, Vector3(sx - 0.2, 1.75, zc), Vector3(0.05, 1.5, bl - 0.4), mint, false)
	_box(parent, Vector3(sx, 1.05, zc), Vector3(0.45, 0.04, bl - 0.2), dark_metal, false)
	_box(parent, Vector3(sx, 1.62, zc), Vector3(0.45, 0.04, bl - 0.2), dark_metal, false)
	_box(parent, Vector3(sx + 0.18, 1.025, zc), Vector3(0.04, 0.015, bl - 0.3), warm, false)
	_box(parent, Vector3(sx + 0.18, 1.595, zc), Vector3(0.04, 0.015, bl - 0.3), warm, false)
	_box(parent, Vector3(sx, 0.5, zc), Vector3(0.5, 1.0, bl), dark_metal)
	_bottles(parent, sx, z0, bl)
	_bulbs(parent, bx + 0.9, z0, bl)
	_neon(parent, "Link-Suite", Color("7dffd8"), Vector3(-W / 2 + 0.06, 3.0, zc), PI / 2, 0.0026)
	# Marble soffit with glowing edges.
	_box(parent, Vector3(-W / 2 + 0.95, 3.85, zc), Vector3(1.9, 0.8, bl + 0.6), marble, false)
	_box(parent, Vector3(-W / 2 + 1.88, 3.44, zc), Vector3(0.04, 0.02, bl + 0.4), warm, false)

	# ---- lounge (right wall): riser, velvet booths with glowing tables, aquarium, lamellas
	var lx0 := W / 2 - 2.2
	var lz0 := -2.4
	var lz1 := 3.2
	var rh := 0.3
	_box(parent, Vector3((lx0 + W / 2) / 2, rh / 2, (lz0 + lz1) / 2), Vector3(W / 2 - lx0, rh, lz1 - lz0), riser)
	_box(parent, Vector3(lx0 - 0.01, rh - 0.02, (lz0 + lz1) / 2), Vector3(0.02, 0.025, lz1 - lz0), pink, false)
	_box(parent, Vector3(lx0 - 0.02, 0.02, (lz0 + lz1) / 2), Vector3(0.03, 0.02, lz1 - lz0), violet, false)
	for zb in [-1.0, 1.9]:
		_booth(parent, Vector3(W / 2 - 0.75, rh, zb), velvet, black_top, dark_metal, riser)
	var aq := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(lz1 - lz0 - 1.2, 1.9)
	aq.mesh = q
	var am := ShaderMaterial.new()
	am.shader = AQUA
	aq.material_override = am
	aq.transform = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(W / 2 - 0.02, rh + 1.15 + 0.95, (lz0 + lz1) / 2))
	parent.add_child(aq)
	_box(parent, Vector3(W / 2 - 0.08, rh + 1.09, (lz0 + lz1) / 2), Vector3(0.16, 0.12, lz1 - lz0 - 1.0), dark_metal, false)
	_box(parent, Vector3(W / 2 - 0.08, rh + 3.11, (lz0 + lz1) / 2), Vector3(0.16, 0.12, lz1 - lz0 - 1.0), dark_metal, false)
	for i in 6:
		_box(parent, Vector3(lx0 - 0.3, 1.7, lz1 - 0.3 - i * 0.45), Vector3(0.06, 3.4, 0.11), dark_metal)

	# ---- truss ring with the eight moving heads (their housings come with the beams)
	var segs := 24
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := RING + Vector3(cos(a0), 0, sin(a0)) * RING_R
		var p1 := RING + Vector3(cos(a1), 0, sin(a1)) * RING_R
		_truss_piece(parent, p0, p1, truss)
	for k in 3:
		var a := TAU * k / 3 + 0.5
		var p := RING + Vector3(cos(a), 0, sin(a)) * RING_R
		_cyl(parent, Vector3(p.x, (RING.y + H) / 2, p.z), 0.008, H - RING.y, dark_metal)
	# Downlights.
	for x in [-3.6, 3.6]:
		for z in [-2.5, 1.0, 3.8]:
			_cyl(parent, Vector3(x, H - 0.01, z), 0.09, 0.02, _glow("ffffff", 3.0))

	# ---- pedestal of the choice panel
	_box(parent, Vector3(KIOSK.x, 0.42, KIOSK.z - 0.12), Vector3(0.7, 0.84, 0.32), marble)
	_box(parent, Vector3(KIOSK.x, 0.86, KIOSK.z - 0.12), Vector3(0.8, 0.04, 0.4), black_top)
	_box(parent, Vector3(KIOSK.x, 0.02, KIOSK.z + 0.05), Vector3(0.72, 0.02, 0.02), pink, false)


## One frame of the light show in VD-Link's frame layout: [beams, spots, t, 0], 16 floats per
## beam (origin, tanHalf | dir, 0 | right, lens | rgb, soft), 16 per spot.
func frame(t: float) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(4 + HEADS * 32)
	f[0] = HEADS
	f[1] = HEADS
	f[2] = t
	var palette := [Color(1.0, 0.18, 0.62), Color(0.55, 0.2, 1.0), Color(0.25, 1.0, 0.78), Color(0.2, 0.5, 1.0)]
	var scene := int(t / 12.0)
	var mix_t := clampf(fmod(t, 12.0) - 10.5, 0.0, 1.5) / 1.5
	var beat := 0.85 + 0.15 * maxf(0.0, sin(t * TAU * 128.0 / 60.0))
	var tan_half := 0.085
	var lens := 0.07
	for i in HEADS:
		var a := TAU * (i + 0.5) / HEADS
		var org := RING + Vector3(cos(a) * RING_R, -0.42, sin(a) * RING_R)
		# Each head draws a slow figure on the floor; neighbours mirror each other.
		var side := 1.0 if i % 2 == 0 else -1.0
		var target := Vector3(
			sin(t * 0.37 + i * 0.9) * 3.2 * side,
			0.0,
			RING.z + cos(t * 0.29 + i * 1.3) * 2.6)
		if scene % 3 == 1:
			target = Vector3(cos(a + t * 0.4) * 1.6, 0.0, RING.z + sin(a + t * 0.4) * 1.6)
		var dir := (target - org).normalized()
		var right := dir.cross(Vector3.UP).normalized()
		if not right.is_finite() or right.length() < 0.5:
			right = Vector3.RIGHT
		var c1: Color = palette[(scene + i % 2) % palette.size()]
		var c2: Color = palette[(scene + 1 + i % 2) % palette.size()]
		var col := c1.lerp(c2, mix_t) * beat
		var o := 4 + i * 16
		_put(f, o, org, tan_half, dir, 0.0, right, lens, col * 0.55, 0.35)
		var apex := org - dir * (lens / tan_half)
		var half := atan(tan_half)
		var so := 4 + HEADS * 16 + i * 16
		_put(f, so, apex, cos(half), dir, cos(half * 0.82), right, 0.0, col * 1.6, 0.0)
	return f


func _put(f: PackedFloat32Array, o: int, a: Vector3, aw: float, b: Vector3, bw: float, c: Vector3, cw: float, col: Color, dw: float) -> void:
	f[o] = a.x
	f[o + 1] = a.y
	f[o + 2] = a.z
	f[o + 3] = aw
	f[o + 4] = b.x
	f[o + 5] = b.y
	f[o + 6] = b.z
	f[o + 7] = bw
	f[o + 8] = c.x
	f[o + 9] = c.y
	f[o + 10] = c.z
	f[o + 11] = cw
	f[o + 12] = col.r
	f[o + 13] = col.g
	f[o + 14] = col.b
	f[o + 15] = dw


# ------------------------------------------------------------------ pieces
func _lit(hex: String, rough: float, metal: float, recv: float, pattern := 0, sheen := 0.0) -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%d|%s" % [hex, rough, metal, recv, pattern, sheen]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("albedo", Color(hex))
	m.set_shader_parameter("roughness_value", rough)
	m.set_shader_parameter("metallic_value", metal)
	m.set_shader_parameter("receive", recv)
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("sheen_k", sheen)
	_cache[key] = m
	return m


func _glow(hex: String, intensity: float) -> ShaderMaterial:
	var key := "glow|%s|%s" % [hex, intensity]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("color", Color(hex))
	m.set_shader_parameter("intensity", intensity)
	_cache[key] = m
	return m


func _mesh(parent: Node3D, mesh: Mesh, xf: Transform3D, mat: Material, solid := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if solid:
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		cs.transform = xf
		_body.add_child(cs)
	return mi


func _box(parent: Node3D, c: Vector3, size: Vector3, mat: Material, solid := true) -> void:
	var b := BoxMesh.new()
	b.size = size
	_mesh(parent, b, Transform3D(Basis(), c), mat, solid)


func _cyl(parent: Node3D, c: Vector3, r: float, h: float, mat: Material, basis := Basis()) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 1
	_mesh(parent, m, Transform3D(basis, c), mat, false)


## 30 cm box truss between two points: four chords and one diagonal per face.
func _truss_piece(parent: Node3D, a: Vector3, b: Vector3, mat: Material) -> void:
	var d := b - a
	var len := d.length()
	var x := d / len
	var y := Vector3.UP
	var z := x.cross(y).normalized()
	var s := 0.145
	for o in [y * s + z * s, y * s - z * s, -y * s + z * s, -y * s - z * s]:
		_cyl(parent, (a + b) / 2 + o, 0.024, len, mat, _axis_basis(x))
	for side in [y * s, -y * s, z * s, -z * s]:
		var other: Vector3 = (side as Vector3).normalized().cross(x).normalized() * s
		var p0: Vector3 = a + side - other
		var p1: Vector3 = b + side + other
		_cyl(parent, (p0 + p1) / 2, 0.01, (p1 - p0).length(), mat, _axis_basis((p1 - p0).normalized()))


## Basis whose local y (the cylinder axis) points along `ax`.
func _axis_basis(ax: Vector3) -> Basis:
	var ref := Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT
	var bx := ref.cross(ax).normalized()
	return Basis(bx, ax, bx.cross(ax).normalized())


func _bottles(parent: Node3D, sx: float, z0: float, bl: float) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 0.035
	m.bottom_radius = 0.04
	m.height = 0.3
	m.radial_segments = 10
	m.rings = 1
	var pal := [Color("2a7a2a"), Color("7a1515"), Color("d8d8d8"), Color("111111"), Color("c8862a"), Color("1f3f7a"), Color("6a6a6a"), Color("a02060")]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = m
	var n := 64
	mm.instance_count = n
	for i in n:
		var row := i % 2
		var k := i / 2
		var h := 0.8 + ((i * 37) % 10) / 20.0
		var p := Vector3(sx + 0.05 - (k % 2) * 0.12, (1.64 if row else 1.07) + 0.15 * h, z0 + 0.3 + float(k) / (n / 2) * (bl - 0.6))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, h, 1)), p))
		mm.set_instance_color(i, pal[(i * 7) % pal.size()])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.15
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.25, 0.25)
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _bulbs(parent: Node3D, x: float, z0: float, bl: float) -> void:
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.12
	s.radial_segments = 10
	s.rings = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = s
	var n := 18
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var wires: Array[Vector3] = []
	for i in n:
		var p := Vector3(x + rng.randf() * 0.8, 2.4 + rng.randf() * 0.9, z0 + 0.3 + rng.randf() * (bl - 0.6))
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		wires.append(p)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _glow("fff1d6", 5.0)
	parent.add_child(mi)
	var wm := _lit("1b1c20", 0.45, 0.6, 0.0)
	for p in wires:
		_cyl(parent, Vector3(p.x, (p.y + H) / 2, p.z), 0.004, H - p.y, wm)


## Half-round velvet booth (open towards the room, -x) with a small table that glows violet.
func _booth(parent: Node3D, c: Vector3, velvet: Material, top: Material, metal: Material, riser: Material) -> void:
	var a0 := PI / 2
	var a1 := PI * 1.5
	_mesh(parent, _arc(1.3, 1.0, a0, a1, false, true), Transform3D(Basis(), c), velvet, false)
	_mesh(parent, _arc(1.25, 0.42, a0, a1, true, false), Transform3D(Basis(), c), velvet)
	_mesh(parent, _arc(0.8, 0.44, a0, a1, true, false), Transform3D(Basis(), c + Vector3(-0.02, 0, 0)), riser, false)
	var table := CylinderMesh.new()
	table.top_radius = 0.42
	table.bottom_radius = 0.42
	table.height = 0.04
	table.radial_segments = 24
	table.rings = 1
	_mesh(parent, table, Transform3D(Basis(), c + Vector3(-0.75, 0.62, 0)), top)
	_cyl(parent, c + Vector3(-0.75, 0.3, 0), 0.05, 0.6, metal)
	_cyl(parent, c + Vector3(-0.75, 0.645, 0), 0.36, 0.005, _glow("9b3cff", 1.4))


## Part of a cylinder from angle a0 to a1 (around y, 0 = +x), standing on y = 0.
## `cap`: closed top; `both`: walls visible from inside and outside.
func _arc(r: float, h: float, a0: float, a1: float, cap: bool, both: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 20
	for i in n:
		var t0 := a0 + (a1 - a0) * i / n
		var t1 := a0 + (a1 - a0) * (i + 1) / n
		var p0 := Vector3(cos(t0) * r, 0, sin(t0) * r)
		var p1 := Vector3(cos(t1) * r, 0, sin(t1) * r)
		var nrm := Vector3(cos((t0 + t1) / 2), 0, sin((t0 + t1) / 2))
		var quad := [p0, p1, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0)]
		# Godot: clockwise = front. Outside face (normal outwards), then inside.
		_tri(st, quad[0], quad[2], quad[1], nrm)
		_tri(st, quad[0], quad[3], quad[2], nrm)
		if both:
			_tri(st, quad[0], quad[1], quad[2], -nrm)
			_tri(st, quad[0], quad[2], quad[3], -nrm)
		if cap:
			_tri(st, Vector3(0, h, 0), p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), Vector3.UP)
	return st.commit()


## Triangle with a given normal; flips the winding if it does not face that way.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# Godot front faces are clockwise seen from the front: (b - a) × (c - a) points away from the viewer.
	if (b - a).cross(c - a).dot(n) > 0:
		var t := b
		b = c
		c = t
	for p in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)


## Neon script: bright text with a soft glow outline (Label3D, unshaded).
func _neon(parent: Node3D, text: String, color: Color, pos: Vector3, yaw: float, px: float) -> void:
	for pass_i in 2:
		var l := Label3D.new()
		l.text = text
		l.font_size = 160
		l.pixel_size = px
		l.shaded = false
		l.double_sided = false
		l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
		if pass_i == 0:
			l.modulate = Color(color.r, color.g, color.b, 0.55)
			l.outline_size = 48
			l.outline_modulate = Color(color.r, color.g, color.b, 0.25)
		else:
			l.modulate = Color(1, 1, 1).lerp(color, 0.35)
			l.outline_size = 12
			l.outline_modulate = color
		l.transform = Transform3D(Basis(Vector3.UP, yaw), pos + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.005 * pass_i))
		parent.add_child(l)
