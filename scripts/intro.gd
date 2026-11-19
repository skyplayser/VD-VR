# Link-Suite start animation in the headset – the Suite's shared intro (VD-Link's
# src/ui/intro/program-intro.js) told in 3D around you:
#   0.0 s  darkness, stars, a line of light in the five suite colours draws itself around you
#   0.5 s  the suite sign builds itself in front of you: fader tracks grow, knobs glide up,
#          the five tiles light up, five beams shoot up from the knobs and sweep
#   2.0 s  the eight programs burst out of the sign and circle once around you (360°),
#          each with a column of light; the sign becomes the Link-Suite logo
#   4.6 s  the programs fly back into the sign, the logo dissolves – VD stays in front of you
#          and turns into VR (VD VR's icon)
#   6.0 s  the lounge appears, VR flies onto the sign of the start screen, the name wipes in
#          and the tiles fade in one after another (like on the computer)
# Pulling the trigger (or A/B/X/Y) skips it. No strobe, nothing moves you.
# Sound (tools/intro-sound.mjs, synthesised, no samples): a bed with braams, a club pulse and a
# warm chord for the reveal; the rest plays in 3D where it happens – knobs click, beams fire,
# the programs whoosh around you, the logo shings, VD chimes when it lands.
extends Node3D

signal reveal_room
signal panel_alpha(a: float)
signal landed
signal finished

const ART := preload("res://scripts/art.gd")
const GLOW := preload("res://shaders/intro_glow.gdshader")
const BEAM := preload("res://shaders/intro_beam.gdshader")
const RING := preload("res://shaders/intro_ring.gdshader")
const SPRITE := preload("res://shaders/intro_sprite.gdshader")
const SOUND := "res://intro/sound/%s.wav"

const T_REVEAL := 6.0
const T_LAND := 6.75
const T_END := 7.6

## Suite sign (suite-symbol.svg, viewBox −4 −4 116 98): fader tracks, knobs, tiles.
const TRACK_X := [7.85, 29.95, 52.04, 74.13, 96.22]
const KNOBS := [Vector2(0.79, 32.32), Vector2(22.88, 14.6), Vector2(44.97, 40.66), Vector2(67.06, 23.46), Vector2(89.15, 8.34)]
const KNOB := 18.07
const PADS := [
	[10.78, 75.6, 26.37, 75.6, 20.3, 90.0, 1.3, 90.0],
	[28.49, 75.6, 44.08, 75.6, 41.9, 90.0, 22.9, 90.0],
	[46.21, 75.6, 61.79, 75.6, 63.5, 90.0, 44.5, 90.0],
	[63.92, 75.6, 79.51, 75.6, 85.1, 90.0, 66.1, 90.0],
	[81.63, 75.6, 97.22, 75.6, 106.7, 90.0, 87.7, 90.0],
]
## Metres per sign unit: big in front of you, then as part of the logo.
const S_BIG := 0.016
const S_LOGO := 0.0072
## Suite logo (suite-logo-dark.svg, viewBox −8 −6.5 591.54 106); text starts at x ≈ 125.
const LOGO_W := 591.54
const LOGO_H := 106.0
const LOGO_TEXT_U := 0.225
const SIGN_A := Vector3(0, 0.05, -3.4)
const LOGO_POS := Vector3(0, 0.5, -3.7)
const RING_R := 3.0
const ICON_H := -0.25
const ICON_SIZE := 0.78
## VD icon: sign 596 of 1024 wide, its middle at y = 725 (program-intro.js BRANDS.vd).
const VD_SIGN_W := 596.0
const VD_SIGN_CY := 725.0

var _cam: Node3D
var _left: XRController3D
var _right: XRController3D
var _menu: Node3D
var _t := 0.0
var _hold := -1.0
var _wait := 0.5
var _floor := -1.6
var _k := 1.0
var _skip_at := -1.0
var _vd_from := -1.0
var _revealed := false
var _landed := false
var _done := false
var _me := ART.ORDER.find("vd")

var _stars_mat := ShaderMaterial.new()
var _ring := Node3D.new()
var _ring_mat := ShaderMaterial.new()
var _ring_glow_mat := ShaderMaterial.new()
var _wave := MeshInstance3D.new()
var _wave_mat := ShaderMaterial.new()
var _sign := Node3D.new()
var _tracks: Array = []
var _track_mat := StandardMaterial3D.new()
var _knobs: Array = []
var _knob_mats: Array = []
var _halos: Array = []
var _pad_mats: Array = []
var _sign_beams: Array = []
var _logo := MeshInstance3D.new()
var _logo_mat := ShaderMaterial.new()
var _logo_halo := MeshInstance3D.new()
var _logo_halo_mat := ShaderMaterial.new()
var _icons: Array = []
var _icon_mats: Array = []
var _icon_halo_mats: Array = []
var _icon_beams: Array = []
var _vr_mat := ShaderMaterial.new()
var _hint := Label3D.new()
var _cover := MeshInstance3D.new()
var _cover_mat := StandardMaterial3D.new()
## Sound on/off (settings); never while holding one moment.
var sound := true
var _cues: Array = []
var _cue_i := 0
var _voices: Array = []
var _heads: Array = []
var _wipe_mark := Node3D.new()


## `at` ≥ 0: hold that moment (desktop screenshots).
func start(cam: Node3D, left: XRController3D, right: XRController3D, menu: Node3D, at := -1.0) -> void:
	_cam = cam
	_left = left
	_right = right
	_menu = menu
	_hold = at
	if at >= 0:
		_wait = 0.0
		_t = at
	_build()
	if sound and at < 0.0:
		_build_sound()
	visible = false


# ------------------------------------------------------------------ building
func _glow_mat(c: Color, sharp := 2.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("sharp", sharp)
	m.set_shader_parameter("intensity", 0.0)
	return m


func _quad(size: Vector2, mat: Material, parent: Node3D) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _beam(c: Color, length: float, r0: float, r1: float) -> Node3D:
	var n := Node3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r0
	cm.bottom_radius = r1
	cm.height = length
	cm.radial_segments = 16
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = Vector3(0, -length / 2.0, 0)
	var m := ShaderMaterial.new()
	m.shader = BEAM
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("intensity", 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	n.set_meta("mat", m)
	add_child(n)
	return n


## Line of light on the floor around you, in five colour bands with small gaps.
func _ring_mesh(r: float, w: float) -> ArrayMesh:
	var seg := 240
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for k in seg + 1:
		var a := TAU * k / seg
		var d := Vector3(sin(a), 0, -cos(a))
		var u := minf(a, TAU - a) / PI
		var band := fposmod(a / (TAU / 5.0) + 0.5, 5.0)
		var f := band - floorf(band)
		var c: Color = ART.SUITE[int(band) % 5]
		c = c.srgb_to_linear()
		c.a = smoothstep(0.0, 0.05, f) * smoothstep(1.0, 0.95, f)
		v.append(d * (r - w / 2.0))
		v.append(d * (r + w / 2.0))
		uv.append(Vector2(u, 0))
		uv.append(Vector2(u, 1))
		col.append(c)
		col.append(c)
		if k < seg:
			var i := k * 2
			idx.append_array([i, i + 1, i + 2, i + 1, i + 3, i + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _ring_instance(r: float, w: float, mat: ShaderMaterial, soft: float, parent: Node3D) -> MeshInstance3D:
	mat.shader = RING
	mat.set_shader_parameter("soft", soft)
	mat.set_shader_parameter("intensity", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh(r, w)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Sign units (x right, y down, middle 54 / 45) → metres in the sign's node.
func _sv(x: float, y: float) -> Vector3:
	return Vector3((x - 54.0) * S_BIG, (45.0 - y) * S_BIG, 0)


func _build() -> void:
	# ---- stars all around
	var rng := RandomNumberGenerator.new()
	rng.seed = 7512
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = 520
	for i in mm.instance_count:
		var d := Vector3(rng.randfn(), rng.randfn() * 0.8 + 0.25, rng.randfn()).normalized()
		var r := rng.randf_range(8.0, 15.0)
		var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD
		var s := rng.randf_range(0.04, 0.12) * r / 10.0
		mm.set_instance_transform(i, Transform3D(Basis.looking_at(d, up).scaled(Vector3(s, s, s)), d * r))
		var tint: Color = Color(0.85, 0.9, 1.0) if rng.randf() < 0.75 else ART.SUITE[rng.randi() % 5]
		mm.set_instance_color(i, tint.srgb_to_linear())
		mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = mm
	_stars_mat.shader = GLOW
	_stars_mat.set_shader_parameter("stars", true)
	_stars_mat.set_shader_parameter("sharp", 2.5)
	_stars_mat.set_shader_parameter("intensity", 0.0)
	stars.material_override = _stars_mat
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)

	# ---- floor: line of light around you, its glow, a wave
	add_child(_ring)
	_ring_instance(2.4, 0.05, _ring_mat, 1.2, _ring)
	_ring_instance(2.4, 0.7, _ring_glow_mat, 2.5, _ring)
	_wave_mat.shader = RING
	_wave_mat.set_shader_parameter("soft", 2.0)
	_wave_mat.set_shader_parameter("intensity", 0.0)
	_wave.mesh = _ring_mesh(1.0, 0.08)
	_wave.material_override = _wave_mat
	add_child(_wave)

	# ---- suite sign
	add_child(_sign)
	_track_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_track_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_track_mat.albedo_color = Color(0.54, 0.58, 0.65, 0.0)
	for x in TRACK_X:
		var n := Node3D.new()
		n.position = _sv(x + 1.965, 70.2)
		var b := BoxMesh.new()
		b.size = Vector3(3.93 * S_BIG, 70.2 * S_BIG, 0.02)
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.position = Vector3(0, 70.2 * S_BIG / 2.0, -0.03)
		mi.material_override = _track_mat
		n.add_child(mi)
		_sign.add_child(n)
		_tracks.append(n)
	for i in 5:
		var c: Color = ART.SUITE[i]
		var halo := _quad(Vector2(1.1, 1.1), _glow_mat(c, 2.2), _sign)
		_halos.append(halo)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(c, 0.0)
		var b := BoxMesh.new()
		b.size = Vector3(KNOB * S_BIG, KNOB * S_BIG, 0.08)
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = m
		_sign.add_child(mi)
		_knobs.append(mi)
		_knob_mats.append(m)
		# tile below
		var p: Array = PADS[i]
		var pv := PackedVector3Array([_sv(p[0], p[1]), _sv(p[2], p[3]), _sv(p[4], p[5]), _sv(p[6], p[7])])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pv
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.cull_mode = BaseMaterial3D.CULL_DISABLED
		pm.albedo_color = Color(c, 0.0)
		var pmi := MeshInstance3D.new()
		pmi.mesh = am
		pmi.material_override = pm
		_sign.add_child(pmi)
		_pad_mats.append(pm)
		_sign_beams.append(_beam(c, 22.0, 0.05, 1.6))

	# ---- suite logo (the text part wipes in next to the sign)
	_logo_mat.shader = SPRITE
	_logo_mat.set_shader_parameter("tex", ART.suite("suite-logo-dark", 2048))
	_logo_mat.set_shader_parameter("alpha", 0.0)
	_logo_mat.set_shader_parameter("clip_lo", LOGO_TEXT_U)
	_logo_mat.set_shader_parameter("clip_hi", LOGO_TEXT_U)
	_logo_mat.render_priority = 2
	_logo = _quad(Vector2(LOGO_W, LOGO_H) * S_LOGO, _logo_mat, self)
	_logo.position = LOGO_POS
	_logo_halo_mat = _glow_mat(Color(1.0, 0.75, 0.9), 1.6)
	_logo_halo = _quad(Vector2(7.0, 2.6), _logo_halo_mat, self)
	_logo_halo.position = LOGO_POS + Vector3(0, 0, -0.2)

	# ---- the eight programs
	for i in ART.ORDER.size():
		var id: String = ART.ORDER[i]
		var c: Color = ART.SUITE[i % 5]
		var n := Node3D.new()
		add_child(n)
		_icon_halo_mats.append(_glow_mat(c, 2.0))
		var h := _quad(Vector2(1.9, 1.9), _icon_halo_mats[i], n)
		h.position = Vector3(0, 0, -0.05)
		var m := ShaderMaterial.new()
		m.shader = SPRITE
		m.set_shader_parameter("tex", ART.suite(id + "-icon", 512))
		m.set_shader_parameter("alpha", 0.0)
		m.render_priority = 4
		_quad(Vector2(ICON_SIZE, ICON_SIZE), m, n)
		_icon_mats.append(m)
		_icons.append(n)
		_icon_beams.append(_beam(c, 9.0, 0.06, 0.9))
	# VD lands over the lounge: drawn after the cover that hides the room.
	_icon_mats[_me].render_priority = 60
	# VD turns into VR – same tile and sign, only the letters change.
	_vr_mat.shader = SPRITE
	_vr_mat.set_shader_parameter("tex", ART.suite("vr-icon", 512))
	_vr_mat.set_shader_parameter("alpha", 0.0)
	_vr_mat.render_priority = 61
	_quad(Vector2(ICON_SIZE, ICON_SIZE), _vr_mat, _icons[_me])

	# ---- hint
	_hint.text = "Überspringen: Trigger"
	_hint.font_size = 28
	_hint.pixel_size = 0.0012
	_hint.modulate = Color(ART.DIM, 0.0)
	_hint.outline_size = 0
	_hint.no_depth_test = true
	_hint.position = Vector3(0, -0.62, -1.7)
	add_child(_hint)

	# ---- black cover around the head: hides the lounge and fades it in
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sm.radial_segments = 16
	sm.rings = 8
	_cover.mesh = sm
	_cover_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cover_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cover_mat.no_depth_test = true
	_cover_mat.render_priority = 50
	_cover_mat.albedo_color = Color(0.008, 0.008, 0.012, 0.0)
	_cover.material_override = _cover_mat
	_cover.visible = false
	_cam.add_child(_cover)


# ------------------------------------------------------------------ sound
func _cue(at: float, f: Callable) -> void:
	_cues.append([at, f])


## What sounds when and where: head-locked beds, the rest on the objects in 3D.
func _build_sound() -> void:
	for j in 2:
		var m := Node3D.new()
		_ring.add_child(m)
		_heads.append(m)
	_logo.add_child(_wipe_mark)
	_cue(0.0, func(): _snd("bed-main", null, -5.0))
	_cue(0.25, func():
		_snd("ring", _heads[0], -13.0)
		_snd("ring", _heads[1], -13.0, 1.04))
	for i in 5:
		_cue(0.8 + i * 0.09, func(): _snd("fader-%d" % i, _knobs[i], -10.0))
		_cue(1.45 + i * 0.06, func(): _snd("beam", _sign_beams[i], -13.0, 0.9 + i * 0.05))
	for i in _icons.size():
		_cue(2.0 + i * 0.05, func(): _snd("orbit", _icons[i], -20.0, 0.93 + 0.14 * fposmod(i * 0.618, 1.0)))
		if i != _me:
			_cue(4.65 + absi(i - _me) * 0.035, func(): _snd("suck", _icons[i], -18.0, 0.95 + 0.1 * fposmod(i * 0.382, 1.0)))
	_cue(3.45, func(): _snd("shing", _wipe_mark, -9.0))
	_cue(5.25, func(): _snd("sparkle", _logo, -11.0))
	# From here on it also plays after skipping.
	_cue(T_REVEAL - 0.25, func(): _snd("bed-reveal", null, -7.0))
	_cue(T_REVEAL, func(): _snd("fly", _icons[_me], -13.0))
	_cue(T_LAND, func(): _snd("land", _icons[_me], -12.0))
	_cues.sort_custom(func(a, b): return a[0] < b[0])


func _snd(name: String, at: Node3D, db: float, pitch := 1.0) -> void:
	var s: AudioStream = load(SOUND % name)
	if s == null:
		return
	var p
	if at == null:
		p = AudioStreamPlayer.new()
		add_child(p)
	else:
		p = AudioStreamPlayer3D.new()
		p.unit_size = 3.0
		p.max_db = 6.0
		p.attenuation_filter_cutoff_hz = 20500.0
		at.add_child(p)
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	p.play()
	_voices.append([p, db])


func _run_cues() -> void:
	# While skipping, everything fades out with the picture and nothing new starts.
	if _skip_at >= 0.0 and _vd_from < 0.0:
		for v in _voices:
			if is_instance_valid(v[0]):
				v[0].volume_db = v[1] + linear_to_db(maxf(_k, 0.0001))
		return
	while _cue_i < _cues.size() and _cues[_cue_i][0] <= _t:
		_cues[_cue_i][1].call()
		_cue_i += 1


## Skipped: stop what was playing, go on with the cues of the reveal.
func _cut_sound() -> void:
	for v in _voices:
		if is_instance_valid(v[0]):
			v[0].queue_free()
	_voices.clear()
	while _cue_i < _cues.size() and _cues[_cue_i][0] < _t:
		_cue_i += 1


# ------------------------------------------------------------------ timeline
static func _c(x: float) -> float:
	return clampf(x, 0.0, 1.0)


static func _out(x: float) -> float:
	x = _c(x)
	return 1.0 - pow(1.0 - x, 3.0)


static func _in(x: float) -> float:
	x = _c(x)
	return x * x * x


static func _io(x: float) -> float:
	x = _c(x)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


static func _back(x: float) -> float:
	x = _c(x)
	var c1 := 1.4
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


## 0 → 1 between a and a + fi, 1 → 0 between b − fo and b.
static func _win(t: float, a: float, fi: float, b: float, fo: float) -> float:
	return _c((t - a) / fi) * (1.0 - _c((t - (b - fo)) / fo))


static func _polar(phi: float, r: float, h: float) -> Vector3:
	return Vector3(sin(phi) * r, h, -cos(phi) * r)


func _face(n: Node3D, p: Vector3, s: float) -> void:
	var flat := Vector3(p.x, 0, p.z)
	var d := flat.normalized() if flat.length() > 0.01 else Vector3(0, 0, -1)
	n.transform = Transform3D(Basis.looking_at(d, Vector3.UP).scaled(Vector3(s, s, s)), p)


func _aim(beam: Node3D, origin: Vector3, dir: Vector3, length_k: float) -> void:
	var y := -dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	beam.position = origin
	beam.basis = Basis(x, y * maxf(length_k, 0.001), z)


func _process(dt: float) -> void:
	if _done:
		return
	if _wait > 0.0:
		# First frames: tracking settles, then the animation starts where you look.
		_wait -= dt
		if _wait <= 0.0:
			_place()
		return
	if not visible:
		_place()
	if _hold < 0.0:
		_t += dt
		_check_skip(dt)
		_run_cues()
	_apply(_t)


func _place() -> void:
	var p := _cam.global_position
	var f := -_cam.global_transform.basis.z
	var yaw := atan2(-f.x, -f.z)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
	_floor = -maxf(p.y, 1.0)
	_ring.position = Vector3(0, _floor + 0.01, 0)
	_wave.position = Vector3(0, _floor + 0.012, 0)
	visible = true


func _pressed(c: XRController3D) -> bool:
	return c != null and c.get_is_active() and (c.get_float("trigger") > 0.6 or c.is_button_pressed("ax_button") or c.is_button_pressed("by_button"))


func _check_skip(dt: float) -> void:
	if _skip_at < 0.0 and _t > 0.3 and _t < T_REVEAL - 0.3:
		# Desktop check `-- --intro-skip`: skips at 2.5 s.
		if _pressed(_left) or _pressed(_right) or Input.is_key_pressed(KEY_SPACE) or (_t > 2.5 and OS.get_cmdline_user_args().has("--intro-skip")):
			_skip_at = _t
	if _skip_at >= 0.0 and _vd_from < 0.0:
		_k = maxf(0.0, _k - dt / 0.25)
		if _k <= 0.0:
			_t = T_REVEAL - 0.25
			_vd_from = _t
			_k = 1.0
			_cut_sound()


func _apply(t: float) -> void:
	var k := _k
	var vd_k := 1.0 if _vd_from < 0.0 else _c((t - _vd_from) / 0.2)
	if _skip_at >= 0.0 and _vd_from < 0.0:
		vd_k = k

	# ---- stars, floor line, waves
	_stars_mat.set_shader_parameter("intensity", 1.1 * _win(t, 0.0, 1.2, 6.0, 0.6) * k)
	var draw := _io((t - 0.25) / 1.3)
	var ring_k := _win(t, 0.2, 0.3, 5.9, 0.7) * k
	_ring_mat.set_shader_parameter("draw", draw)
	_ring_mat.set_shader_parameter("intensity", 1.6 * ring_k)
	_ring_glow_mat.set_shader_parameter("draw", draw)
	_ring_glow_mat.set_shader_parameter("intensity", 0.35 * ring_k)
	_ring.rotation.y = 0.22 * maxf(0.0, t - 1.6)
	for j in _heads.size():
		var ha := draw * PI * (1 if j == 0 else -1)
		_heads[j].position = Vector3(sin(ha), 0, -cos(ha)) * 2.4
	var wave_k := 0.0
	var wave_r := 1.0
	for w in [1.65, 3.95]:
		var p := _c((t - w) / 1.1)
		if p > 0.0 and p < 1.0:
			wave_r = lerpf(2.0, 16.0, _out(p))
			wave_k = 1.4 * pow(1.0 - p, 1.5)
	_wave.scale = Vector3(wave_r, 1, wave_r)
	_wave_mat.set_shader_parameter("intensity", wave_k * k)

	# ---- suite sign: tracks grow, knobs glide up, tiles light up
	var to_logo := _io((t - 3.0) / 0.5)
	var gone := _c((t - 5.25) / 0.35)
	var sign_s := lerpf(1.0, S_LOGO / S_BIG, to_logo) * (1.0 + 0.05 * gone)
	var sign_pos := SIGN_A.lerp(LOGO_POS + Vector3((54.0 - (-8.0 + LOGO_W / 2.0)) * S_LOGO, 0, 0), to_logo)
	_sign.transform = Transform3D(Basis().scaled(Vector3(sign_s, sign_s, sign_s)), sign_pos)
	var sign_a := (1.0 - gone) * k
	_track_mat.albedo_color.a = 0.4 * _c((t - 0.45) / 0.3) * sign_a
	# Flash when the programs fly back in (soft, no strobe).
	var back_in := _win(t, 4.95, 0.25, 5.6, 0.35)
	for i in 5:
		_tracks[i].scale = Vector3(1, maxf(_out((t - (0.45 + i * 0.06)) / 0.45), 0.001), 1)
		var kp := _back((t - (0.8 + i * 0.09)) / 0.55)
		var ky: float = lerpf(70.2 - KNOB, KNOBS[i].y, kp)
		var kc := _sv(KNOBS[i].x + KNOB / 2.0, ky + KNOB / 2.0)
		_knobs[i].position = kc
		_knob_mats[i].albedo_color.a = _c((t - (0.8 + i * 0.09)) / 0.2) * sign_a
		_halos[i].position = kc + Vector3(0, 0, -0.08)
		_halos[i].material_override.set_shader_parameter("intensity", (0.55 * _c((t - (0.9 + i * 0.09)) / 0.4) + 0.5 * back_in) * sign_a)
		_pad_mats[i].albedo_color.a = _out((t - (1.15 + i * 0.07)) / 0.3) * sign_a
		# Beams from the knobs: shoot up, fan out and sweep like moving heads.
		var b: Node3D = _sign_beams[i]
		var grow := _out((t - (1.45 + i * 0.06)) / 0.5)
		var sweep := _c((t - 1.9) / 0.6) * 0.38 * sin(1.7 * (t - 1.9) + i * 0.8)
		var pan := (i - 2) * 0.3 + sweep
		var tilt := 0.22 + 0.1 * sin(1.3 * t + i)
		var dir := Vector3(sin(pan), cos(pan) * cos(tilt), -cos(pan) * sin(tilt))
		_aim(b, _sign.transform * kc, dir, grow)
		b.get_meta("mat").set_shader_parameter("intensity", 0.9 * grow * (1.0 - _c((t - 4.5) / 0.7)) * k)

	# ---- logo: text wipes in next to the sign, glows once, dissolves
	var wipe := _io((t - 3.45) / 0.5)
	_logo_mat.set_shader_parameter("clip_hi", lerpf(LOGO_TEXT_U, 1.0, wipe))
	_wipe_mark.position = Vector3((lerpf(LOGO_TEXT_U, 1.0, wipe) - 0.5) * LOGO_W * S_LOGO, 0, 0)
	_logo_mat.set_shader_parameter("edge", 0.9 * _win(t, 3.45, 0.05, 3.95, 0.1))
	_logo_mat.set_shader_parameter("alpha", _c((t - 3.4) / 0.1) * sign_a)
	_logo.scale = Vector3.ONE * (1.0 + 0.05 * gone)
	_logo_halo_mat.set_shader_parameter("intensity", (0.32 * _win(t, 3.8, 0.35, 4.9, 0.7) + 0.25 * back_in) * sign_a)

	# ---- the programs: burst out, one circle around you, back into the sign; VD stays
	var rot := TAU * _io((t - 2.5) / 2.1)
	var sign_world := _sign.position
	var sp_phi := atan2(sign_world.x, -sign_world.z)
	var sp_r := Vector2(sign_world.x, sign_world.z).length()
	var front := _polar(0.0, 2.6, -0.15)
	for i in _icons.size():
		var phi_i := (i - _me) * TAU / 8.0
		var tb := 2.0 + i * 0.05
		var p := _out((t - tb) / 0.9)
		var phi := phi_i * p + rot
		var r := lerpf(SIGN_A.length(), RING_R, p)
		var h := lerpf(SIGN_A.y, ICON_H, p) + 0.07 * sin(2.0 * t + i) * p
		var s := lerpf(0.2, 1.0, p)
		var a := _c((t - tb) / 0.25)
		var tr := 4.65 + absi(i - _me) * 0.035
		var q := _in((t - tr) / 0.7)
		var pos := _polar(phi, r, h)
		var beam_k := _win(t, 2.6 + i * 0.05, 0.4, 4.95, 0.4)
		if i == _me:
			var qv := _io((t - 4.65) / 0.8)
			pos = pos.lerp(front, qv)
			s = lerpf(s, 1.25, qv)
			_face(_icons[i], pos, s)
			var land := _io((t - T_REVEAL) / (T_LAND - T_REVEAL))
			if land > 0.0:
				_land(_icons[i], pos, s, land)
			var la := a * vd_k * (1.0 - _c((t - (T_LAND + 0.06)) / 0.2))
			var morph := smoothstep(5.05, 5.6, t)
			_icon_mats[i].set_shader_parameter("alpha", la * (1.0 - morph))
			_vr_mat.set_shader_parameter("alpha", la * morph)
			var pulse := 0.45 + 0.35 * _win(t, 5.2, 0.3, 6.2, 0.4)
			_icon_halo_mats[i].set_shader_parameter("intensity", pulse * a * vd_k * (1.0 - _c((t - T_REVEAL) / 0.35)))
		else:
			if q > 0.0:
				pos = _polar(lerp_angle(phi, sp_phi, q), lerpf(r, sp_r, q), lerpf(h, sign_world.y, q))
				s = lerpf(s, 0.15, q)
			_face(_icons[i], pos, s)
			var oa := a * (1.0 - smoothstep(0.75, 1.0, q)) * k
			_icon_mats[i].set_shader_parameter("alpha", oa)
			_icon_halo_mats[i].set_shader_parameter("intensity", 0.38 * oa)
		var bp := Vector3(pos.x, _floor, pos.z)
		_aim(_icon_beams[i], bp, Vector3.UP, beam_k)
		_icon_beams[i].get_meta("mat").set_shader_parameter("intensity", 0.55 * beam_k * k)

	_hint.modulate.a = 0.75 * _win(t, 0.6, 0.6, 5.6, 0.3) * k

	# ---- the lounge appears, VD lands on the start screen
	if t >= T_REVEAL and not _revealed:
		_revealed = true
		_cover.visible = true
		reveal_room.emit()
	if _revealed:
		_cover_mat.albedo_color.a = 1.0 - smoothstep(T_REVEAL + 0.05, T_REVEAL + 0.9, t)
		panel_alpha.emit(smoothstep(T_REVEAL + 0.25, T_LAND, t))
	if t >= T_LAND and not _landed:
		_landed = true
		landed.emit()
	if t >= T_END and _hold < 0.0:
		_finish()


## VD flies from in front of you onto the sign of the start screen (sign on sign, like on the computer).
func _land(n: Node3D, from: Vector3, from_s: float, p: float) -> void:
	var at: Array = _menu.sign_in_world() if _menu.has_method("sign_in_world") else []
	if at.is_empty():
		return
	var mb: Basis = _menu.global_transform.basis.orthonormalized()
	var size: float = at[1] * 1024.0 / VD_SIGN_W
	var target: Vector3 = at[0] + mb.y * size * (VD_SIGN_CY - 512.0) / 1024.0
	var to_local := global_transform.affine_inverse()
	var tl: Vector3 = to_local * target
	var lb := (global_transform.basis.inverse() * mb).orthonormalized()
	var pos := from.lerp(tl, p) + Vector3(0, 0.3 * sin(PI * p), 0)
	var q0 := n.transform.basis.orthonormalized().get_rotation_quaternion()
	var rq := q0.slerp(lb.get_rotation_quaternion(), p)
	var s := lerpf(from_s * ICON_SIZE, size, p) / ICON_SIZE
	n.transform = Transform3D(Basis(rq).scaled(Vector3(s, s, s)), pos)


func _finish() -> void:
	_done = true
	# The chord and the chime ring out over the start screen.
	for v in _voices:
		if is_instance_valid(v[0]) and v[0].playing:
			v[0].reparent(get_parent())
	if is_instance_valid(_cover):
		_cover.queue_free()
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	if _wipe_mark.get_parent() == null:
		_wipe_mark.free()
	if is_instance_valid(_cover) and not _cover.is_queued_for_deletion():
		_cover.queue_free()
