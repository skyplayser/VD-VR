# Builds the room of a VD-Link location (project.venue.location.objects) with simple meshes.
# Conventions as in src/shared/location.ts: metres, rotation in degrees (Euler XYZ like
# three.js), most objects pivot at their bottom centre; video walls too (centre = pos + R·(0,h/2,0)).
extends RefCounted

const SURFACE := preload("res://shaders/surface.gdshader")

# Material presets: albedo, roughness, metallic, receive (how strongly spots show).
const MATS := {
	"black": [Color("0b0b0d"), 0.7, 0.0, 1.0],
	"darkgrey": [Color("2a2a2e"), 0.75, 0.0, 1.0],
	"grey": [Color("6b6b70"), 0.75, 0.0, 0.9],
	"white": [Color("e8e8e8"), 0.6, 0.0, 0.7],
	"marble": [Color("d8d4cc"), 0.3, 0.0, 0.8],
	"velvet-petrol": [Color("0e4a52"), 0.95, 0.0, 0.9],
	"velvet-violet": [Color("4a1e5a"), 0.95, 0.0, 0.9],
	"metal": [Color("8a8d92"), 0.35, 0.8, 0.6],
	"wood": [Color("6b4a2e"), 0.7, 0.0, 0.9],
	"glass": [Color("1b2328"), 0.1, 0.0, 0.3],
	"concrete": [Color("55565a"), 0.9, 0.0, 1.0],
	"grass": [Color("2f4a22"), 0.95, 0.0, 1.0],
	"led": [Color("101010"), 0.5, 0.0, 0.5],
}

var _mat_cache := {}


func build(loc: Dictionary, parent: Node3D) -> Dictionary:
	var room: Dictionary = loc.get("room", {})
	var spots: Array = []
	# Floor, walls and ceiling of the room rectangle.
	var w := float(room.get("width", 20.0))
	var d := float(room.get("depth", 14.0))
	var h := float(room.get("height", 6.0))
	if loc.get("kind", "indoor") == "indoor":
		_box(parent, Vector3(0, -0.05, 0), Vector3(w, 0.1, d), Basis(), _mat("darkgrey", ""))
		_box(parent, Vector3(0, h + 0.05, 0), Vector3(w, 0.1, d), Basis(), _mat("black", ""), false)
		_box(parent, Vector3(0, h / 2, -d / 2 - 0.1), Vector3(w, h, 0.2), Basis(), _mat("black", ""), false)
		_box(parent, Vector3(0, h / 2, d / 2 + 0.1), Vector3(w, h, 0.2), Basis(), _mat("black", ""), false)
		_box(parent, Vector3(-w / 2 - 0.1, h / 2, 0), Vector3(0.2, h, d), Basis(), _mat("black", ""), false)
		_box(parent, Vector3(w / 2 + 0.1, h / 2, 0), Vector3(0.2, h, d), Basis(), _mat("black", ""), false)
	for o in loc.get("objects", []):
		var t := String(o.get("type", "box"))
		var pos := _v3(o.get("pos", [0, 0, 0]))
		var rot := _v3(o.get("rot", [0, 0, 0]))
		var size := _v3(o.get("size", [1, 1, 1]))
		var basis := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)), EULER_ORDER_XYZ)
		var mat := _mat(String(o.get("material", "darkgrey")), String(o.get("color", "")))
		match t:
			"crowd":
				spots.append({ "name": o.get("name", ""), "pos": pos, "size": size })
			"fixture":
				_box(parent, pos + Vector3(0, -0.2 if o.get("fixture", {}).get("mount", "hang") == "hang" else 0.2, 0), Vector3(0.3, 0.4, 0.3), basis, _mat("black", ""), false)
			"videowall":
				# Picture surface follows later (live pictures); a dark LED panel for now.
				var c := pos + basis * Vector3(0, size.y / 2, 0)
				_box(parent, c, Vector3(size.x, size.y, 0.08), basis, _mat("led", "#151820"), false)
			"arc":
				_arc(parent, pos, size, basis, o.get("arc", {}), mat)
			"pillar", "cylinder":
				var m := CylinderMesh.new()
				m.top_radius = size.x / 2
				m.bottom_radius = size.x / 2
				m.height = size.y
				m.radial_segments = 16
				_mesh(parent, m, pos + basis * Vector3(0, size.y / 2, 0), basis.scaled(Vector3(1, 1, size.z / max(size.x, 0.001))), mat)
			"truss":
				_box(parent, pos, size, basis, mat, false)
			_:
				_box(parent, pos + basis * Vector3(0, size.y / 2, 0), size, basis, mat)
	return { "spots": spots }


func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _mat(preset: String, color: String) -> ShaderMaterial:
	var key := preset + "|" + color
	if _mat_cache.has(key):
		return _mat_cache[key]
	var p: Array = MATS.get(preset, MATS["darkgrey"])
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	var c: Color = p[0]
	if color != "" and preset in ["velvet-violet", "velvet-petrol", "led"]:
		c = Color(color)
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("roughness_value", p[1])
	m.set_shader_parameter("metallic_value", p[2])
	m.set_shader_parameter("receive", p[3])
	if preset == "led" and color != "":
		m.set_shader_parameter("emission_color", Color(color) * 0.6)
	_mat_cache[key] = m
	return m


func _box(parent: Node3D, center: Vector3, size: Vector3, basis: Basis, mat: Material, solid := true) -> void:
	var m := BoxMesh.new()
	m.size = size.max(Vector3(0.01, 0.01, 0.01))
	_mesh(parent, m, center, basis, mat, solid)


## `solid`: surfaces you can stand on (height map of the spot light map, later teleport).
func _mesh(parent: Node3D, mesh: Mesh, center: Vector3, basis: Basis, mat: Material, solid := true) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(basis, center)
	parent.add_child(mi)
	if solid:
		mi.create_trimesh_collision()


## Part of an ellipse (D-stage, ring podium, curved wall, bench …), centred on local +z.
func _arc(parent: Node3D, pos: Vector3, size: Vector3, basis: Basis, arc: Dictionary, mat: Material) -> void:
	var a := size.x / 2
	var b := size.z / 2
	var h := maxf(size.y, 0.01)
	var ang := deg_to_rad(clampf(float(arc.get("angle", 360)), 1, 360))
	var thick := float(arc.get("thickness", 0))
	var full := ang >= TAU - 0.001
	var n := maxi(8, int(48 * ang / TAU))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer: PackedVector2Array = []
	var inner: PackedVector2Array = []
	for i in n + 1:
		var phi := (TAU * i / n) if full else (-ang / 2 + ang * i / n)
		outer.append(Vector2(a * sin(phi), b * cos(phi)))
		if thick > 0:
			inner.append(Vector2(maxf(a - thick, 0.01) * sin(phi), maxf(b - thick, 0.01) * cos(phi)))
	for i in n:
		var o0 := outer[i]
		var o1 := outer[i + 1]
		if thick > 0:
			var i0 := inner[i]
			var i1 := inner[i + 1]
			_quad(st, Vector3(i0.x, h, i0.y), Vector3(o0.x, h, o0.y), Vector3(o1.x, h, o1.y), Vector3(i1.x, h, i1.y))
			_quad(st, Vector3(i1.x, 0, i1.y), Vector3(i1.x, h, i1.y), Vector3(i0.x, h, i0.y), Vector3(i0.x, 0, i0.y))
		else:
			_tri(st, Vector3(0, h, 0), Vector3(o0.x, h, o0.y), Vector3(o1.x, h, o1.y))
		_quad(st, Vector3(o0.x, 0, o0.y), Vector3(o0.x, h, o0.y), Vector3(o1.x, h, o1.y), Vector3(o1.x, 0, o1.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(basis, pos)
	parent.add_child(mi)
	mi.create_trimesh_collision()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Both windings, each with the normal of the side it is seen from (Godot: clockwise =
	# front), so podiums and curved walls look right from everywhere.
	var n := (b - a).cross(c - a).normalized()
	for tri in [[a, b, c, -n], [a, c, b, n]]:
		st.set_normal(tri[3])
		st.add_vertex(tri[0])
		st.set_normal(tri[3])
		st.add_vertex(tri[1])
		st.set_normal(tri[3])
		st.add_vertex(tri[2])


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)
