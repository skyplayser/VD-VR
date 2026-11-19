# The room exactly as VD-Link draws it: meshes baked and merged by VD-Link
# (src/render/vr-export.ts, GET api/venue.bin, format "VDV1"). Materials follow VD-Link's
# looks (quilted walls, marble, velvet sheen, LED glow, neon, aquarium); point lights of the
# room arrive baked into the vertex colours. The crowd bobs to 128 BPM like on the desktop.
extends RefCounted

const SURFACE := preload("res://shaders/surface.gdshader")
const GLOW := preload("res://shaders/glow.gdshader")
const ADD := preload("res://shaders/additive.gdshader")
const AQUA := preload("res://shaders/aquarium.gdshader")
const GLASS := preload("res://shaders/glass.gdshader")
const CROWD := preload("res://shaders/crowd.gdshader")
const PATTERNS := { "quilt": 1, "marble": 2, "duct": 3, "sheen": 4 }

var triangles := 0
var crowd_count := 0


## Checks the header; returns {} if the bytes are no venue.
static func header(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 8 or bytes.slice(0, 4).get_string_from_ascii() != "VDV1":
		return {}
	var n := bytes.decode_u32(4)
	if 8 + n > bytes.size():
		return {}
	var h = JSON.parse_string(bytes.slice(8, 8 + n).get_string_from_utf8())
	return h if typeof(h) == TYPE_DICTIONARY else {}


## Builds the room under `parent`. Returns false if the data cannot be read.
func build(bytes: PackedByteArray, parent: Node3D) -> bool:
	var h := header(bytes)
	if h.is_empty():
		return false
	var base := 8 + bytes.decode_u32(4)
	var textures: Array = []
	for t in h.get("textures", []):
		var img := Image.new()
		var off := base + int(t.off)
		if img.load_png_from_buffer(bytes.slice(off, off + int(t.len))) == OK:
			img.generate_mipmaps()
			textures.append(ImageTexture.create_from_image(img))
		else:
			textures.append(null)
	var mats: Array = []
	for m in h.get("mats", []):
		mats.append(_material(m, textures))
	var body := StaticBody3D.new()
	parent.add_child(body)
	for e in h.get("meshes", []):
		var md: Dictionary = h.mats[int(e.mat)]
		var nv := int(e.verts)
		var ni := int(e.tris) * 3
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		var pos := bytes.slice(base + int(e.pos), base + int(e.pos) + nv * 12).to_vector3_array()
		var nrm := bytes.slice(base + int(e.nrm), base + int(e.nrm) + nv * 12).to_vector3_array()
		var uv := bytes.slice(base + int(e.uv), base + int(e.uv) + nv * 8).to_vector2_array()
		var idx := bytes.slice(base + int(e.idx), base + int(e.idx) + ni * 4).to_int32_array()
		var col := PackedColorArray()
		if e.has("col"):
			col = bytes.slice(base + int(e.col), base + int(e.col) + nv * 16).to_color_array()
		if md.get("double", false):
			# Both sides: the back faces again with flipped normals and winding.
			var back_n := PackedVector3Array()
			back_n.resize(nv)
			for i in nv:
				back_n[i] = -nrm[i]
			var back_i := PackedInt32Array()
			back_i.resize(ni)
			for i in range(0, ni, 3):
				back_i[i] = idx[i] + nv
				back_i[i + 1] = idx[i + 2] + nv
				back_i[i + 2] = idx[i + 1] + nv
			pos.append_array(pos.duplicate())
			nrm.append_array(back_n)
			uv.append_array(uv.duplicate())
			if not col.is_empty():
				col.append_array(col.duplicate())
			idx.append_array(back_i)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_TEX_UV] = uv
		if not col.is_empty():
			arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mats[int(e.mat)]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.add_to_group("vdm_" + String(md.kind))
		triangles += idx.size() / 3
		# Things you can stand on and walk against: everything that takes the light.
		if String(md.kind) == "lit" and float(md.get("recv", 0)) > 0.0:
			var cs := CollisionShape3D.new()
			cs.shape = mesh.create_trimesh_shape()
			body.add_child(cs)
	_build_crowd(bytes, base, h.get("crowd", {}), parent)
	return true


func _material(m: Dictionary, textures: Array) -> Material:
	var mat := ShaderMaterial.new()
	var color := Color(String(m.get("color", "#808080")))
	match String(m.get("kind", "lit")):
		"glow":
			mat.shader = GLOW
			mat.set_shader_parameter("color", color)
			mat.set_shader_parameter("intensity", float(m.get("intensity", 1.0)))
		"add":
			mat.shader = ADD
			mat.set_shader_parameter("color", color)
			mat.set_shader_parameter("intensity", float(m.get("intensity", 1.0)))
			var t = textures[int(m.tex)] if m.has("tex") and int(m.tex) < textures.size() else null
			if t:
				mat.set_shader_parameter("tex", t)
				mat.set_shader_parameter("use_tex", true)
			mat.set_shader_parameter("fade", String(m.get("pattern", "")) == "fade")
		"aqua":
			mat.shader = AQUA
		"glass":
			mat.shader = GLASS
			mat.set_shader_parameter("color", color)
			mat.set_shader_parameter("opacity", float(m.get("opacity", 0.15)))
		_:
			mat.shader = SURFACE
			mat.set_shader_parameter("albedo", color)
			mat.set_shader_parameter("roughness_value", float(m.get("rough", 0.7)))
			mat.set_shader_parameter("metallic_value", float(m.get("metal", 0.0)))
			mat.set_shader_parameter("receive", float(m.get("recv", 0.35)))
			mat.set_shader_parameter("pattern", int(PATTERNS.get(String(m.get("pattern", "")), 0)))
			mat.set_shader_parameter("sheen_k", float(m.get("sheen", 0.0)))
			mat.set_shader_parameter("baked", true)
			if m.has("emissive"):
				mat.set_shader_parameter("emission_color", Color(String(m.emissive)))
	return mat


## People as capsules (same places, heights and phases as on the desktop), bobbing in the shader.
func _build_crowd(bytes: PackedByteArray, base: int, c: Dictionary, parent: Node3D) -> void:
	var n := int(c.get("count", 0))
	if n <= 0:
		return
	var f := bytes.slice(base + int(c.off), base + int(c.off) + n * 16).to_float32_array()
	var cap := CapsuleMesh.new()
	cap.radius = 0.21
	cap.height = 1.05 + 0.42
	cap.radial_segments = 8
	cap.rings = 2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = cap
	mm.instance_count = n
	for i in n:
		var x := f[i * 4]
		var z := f[i * 4 + 1]
		var hh := f[i * 4 + 2]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, hh, 1)), Vector3(x, 0.735 * hh, z)))
		mm.set_instance_custom_data(i, Color(f[i * 4 + 3], hh, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = CROWD
	mat.set_shader_parameter("albedo", Color("55555f"))
	mat.set_shader_parameter("receive", 0.45)
	mmi.material_override = mat
	parent.add_child(mmi)
	mmi.add_to_group("vdm_crowd")
	crowd_count = n
