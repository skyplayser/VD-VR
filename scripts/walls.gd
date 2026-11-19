# Video walls in VD VR, the same screens as in VD-Link (src/viz.ts): one screen per output that
# feeds several walls, then one per wall of its own. Screen i gets its picture from
# api/wall/<i>.jpg and its state (live / test / black, fit, brightness) from the SSE event `walls`.
extends Node3D

signal picture_received(i: int, jpeg: PackedByteArray)

const WALL_SHADER := preload("res://shaders/wall.gdshader")
## Pictures per second per screen (JPEG decoding runs on a worker thread).
const FPS := 12.0

var net: Node
## Pictures come from a saved scenario (show_jpeg) instead of VD-Link.
var offline := false
var screens: Array[Dictionary] = []
var _states: Array = []


func build(loc: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	screens.clear()
	var outputs: Array = loc.get("outputs", [])
	var walls: Array = loc.get("objects", []).filter(func(o): return o.get("type", "") == "videowall")
	var out_ids := outputs.map(func(o): return String(o.get("id", "")))
	for out in outputs:
		var members := walls.filter(func(w): return _out_id(w) == out.get("id", "") and _rect(w).size() == 4)
		if members.size():
			_add_screen(_px(out.get("pixels", [1920, 1080])), members)
	for w in walls:
		if not out_ids.has(_out_id(w)) or _rect(w).size() != 4:
			_add_screen(Vector2(1, 1), [w])
	apply_states(_states)


func _out_id(w: Dictionary) -> String:
	var o = w.get("output")
	return String(o.get("id", "")) if typeof(o) == TYPE_DICTIONARY else ""


func _rect(w: Dictionary) -> Array:
	var o = w.get("output")
	return o.get("rect", []) if typeof(o) == TYPE_DICTIONARY and _out_id(w) != "" else []


func _px(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if typeof(a) == TYPE_ARRAY and a.size() == 2 else Vector2(1920, 1080)


func _add_screen(pixels: Vector2, members: Array) -> void:
	var tex := ImageTexture.new()
	var mats: Array[ShaderMaterial] = []
	for w in members:
		var size := Vector3(w.size[0], w.size[1], w.size[2])
		var rot := Vector3(w.rot[0], w.rot[1], w.rot[2])
		var basis := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)), EULER_ORDER_XYZ)
		var centre := Vector3(w.pos[0], w.pos[1], w.pos[2]) + basis * Vector3(0, size.y / 2, 0)
		var q := QuadMesh.new()
		q.size = Vector2(size.x, size.y)
		var m := ShaderMaterial.new()
		m.shader = WALL_SHADER
		var r := _rect(w)
		if r.size() == 4 and pixels != Vector2(1, 1):
			m.set_shader_parameter("rect", Vector4(r[0] / pixels.x, r[1] / pixels.y, r[2] / pixels.x, r[3] / pixels.y))
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		# In front of the LED panel (venue.gd: 8 cm deep; VD-Link: 12 cm frame), centred.
		mi.transform = Transform3D(basis, centre + basis * Vector3(0, 0, 0.075))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mats.append(m)
	screens.append({ "pixels": pixels, "mats": mats, "tex": tex, "state": "test", "fit": "fit", "offset": [0, 0],
		"src": Vector2.ZERO, "busy": false, "last": 0, "req": null })


## Event `walls`: [{name, state, fit, offset, brightness}] in screen order.
func apply_states(states: Array) -> void:
	_states = states
	for i in screens.size():
		var s: Dictionary = screens[i]
		var st: Dictionary = states[i] if i < states.size() and typeof(states[i]) == TYPE_DICTIONARY else {}
		s.state = String(st.get("state", "test"))
		s.fit = String(st.get("fit", "fit"))
		s.offset = st.get("offset", [0, 0])
		var mode := 1 if s.state == "live" and s.src != Vector2.ZERO else (0 if s.state == "black" else (3 if s.state == "demo" else 2))
		if s.state == "live" and s.src == Vector2.ZERO:
			mode = 0  # live, first picture still on its way
		for m in s.mats:
			m.set_shader_parameter("mode", mode)
			m.set_shader_parameter("brightness", clampf(float(st.get("brightness", 1.0)), 0.0, 2.0))
			m.set_shader_parameter("map", _map(s))
			m.set_shader_parameter("tex", s.tex)


## Output → source mapping, as VideoWall.updateMap in VD-Link.
func _map(s: Dictionary) -> Vector4:
	var out: Vector2 = s.pixels
	var src: Vector2 = s.src
	if src.x <= 0 or src.y <= 0 or s.fit == "stretch" or out == Vector2(1, 1):
		return Vector4(1, 1, 0, 0)
	if s.fit == "pixel":
		return Vector4(out.x / src.x, out.y / src.y, float(s.offset[0]) / src.x, float(s.offset[1]) / src.y)
	var a_src := src.x / src.y
	var a_out := out.x / out.y
	var bw := 1.0 if a_src > a_out else a_src / a_out
	var bh := a_out / a_src if a_src > a_out else 1.0
	return Vector4(1.0 / bw, 1.0 / bh, -(1.0 - bw) / (2.0 * bw), -(1.0 - bh) / (2.0 * bh))


func _process(_dt: float) -> void:
	if offline or not net or not net.connected:
		return
	var now := Time.get_ticks_msec()
	for i in screens.size():
		var s: Dictionary = screens[i]
		if s.state != "live" or s.busy or now - int(s.last) < int(1000.0 / FPS):
			continue
		s.busy = true
		s.last = now
		if s.req == null:
			var r := HTTPRequest.new()
			r.use_threads = true
			add_child(r)
			if net._tls:
				r.set_tls_options(net._tls)
			r.request_completed.connect(_on_picture.bind(i))
			s.req = r
		if (s.req as HTTPRequest).request(net.base + "api/wall/%d.jpg" % i) != OK:
			s.busy = false


func _on_picture(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, i: int) -> void:
	if i >= screens.size():
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		screens[i].busy = false
		return
	picture_received.emit(i, body)
	WorkerThreadPool.add_task(_decode.bind(body, i))


## Picture from a saved scenario.
func show_jpeg(i: int, body: PackedByteArray) -> void:
	if i >= screens.size() or screens[i].busy:
		return
	screens[i].busy = true
	WorkerThreadPool.add_task(_decode.bind(body, i))


func _decode(body: PackedByteArray, i: int) -> void:
	var img := Image.new()
	if img.load_jpg_from_buffer(body) != OK:
		img = null
	_show.call_deferred(img, i)


func _show(img: Image, i: int) -> void:
	if i >= screens.size():
		return
	var s: Dictionary = screens[i]
	s.busy = false
	if img == null:
		return
	var size := Vector2(img.get_width(), img.get_height())
	if s.src != size:
		s.tex.set_image(img)
		s.src = size
		apply_states(_states)
	else:
		s.tex.update(img)
