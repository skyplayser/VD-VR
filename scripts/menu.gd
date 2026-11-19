# Menu in VD VR: a panel in front of you (B / Y or menu button), operated by pointing with a
# controller and pulling the trigger. Same content as the browser viewer's menu.
# The panel is a 2D UI (Controls) in a SubViewport, shown on a quad; controller rays become
# mouse events in that viewport.
extends Node3D

signal action(id: String)

const ART := preload("res://scripts/art.gd")
## Panel sizes: the normal menu (portrait) and the start screen (landscape card like VD-Link's).
const PX_MENU := Vector2i(1280, 1500)
const PX_START := Vector2i(2000, 1150)
const WIDTH_MENU := 0.9
const WIDTH_START := 1.4
## Toolbox over the left controller (club scan): small and close.
const PX_TOOLS := Vector2i(1000, 1240)
const WIDTH_TOOLS := 0.36

var PX := PX_MENU

var left: XRController3D
var right: XRController3D
var model: Dictionary = {}

var _vp := SubViewport.new()
var _root := PanelContainer.new()
var _quad := MeshInstance3D.new()
var _hover_ctrl: XRController3D = null
var _trigger_prev := { "left": false, "right": false }
var _dot := MeshInstance3D.new()
## Standing in the room (start screen) instead of floating in front of the head.
var pinned := false
## Off while the start animation plays (the panel is still invisible).
var input_enabled := true
## The panel is only redrawn while something changes or a ray points at it (saves GPU time
## on the start screen, where it stands open all the time).
var _awake_until := 0
var _mat: StandardMaterial3D
var _style_menu: StyleBoxFlat
## Start screen: the name next to the sign and the parts that fade in one after another.
var _logo_sign: Control = null
var _logo_name: Label = null
var _reveal: Array = []


func _ready() -> void:
	_vp.size = PX
	_vp.transparent_bg = true
	_vp.gui_disable_input = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	style.set_corner_radius_all(36)
	style.set_content_margin_all(40)
	_style_menu = style
	_root.add_theme_stylebox_override("panel", style)
	_root.size = PX
	_root.theme = _make_theme()
	_vp.add_child(_root)
	var q := QuadMesh.new()
	q.size = Vector2(WIDTH_MENU, WIDTH_MENU * PX.y / PX.x)
	_quad.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 10
	m.albedo_texture = _vp.get_texture()
	_quad.material_override = m
	_mat = m
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)
	var s := SphereMesh.new()
	s.radius = 0.008
	s.height = 0.016
	_dot.mesh = s
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.no_depth_test = true
	dm.render_priority = 11
	_dot.material_override = dm
	_dot.top_level = true
	add_child(_dot)
	visible = false


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 34
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("1d1d27")
	normal.set_corner_radius_all(18)
	normal.set_content_margin_all(18)
	var hover := normal.duplicate()
	hover.bg_color = Color("2c2c3c")
	var on := normal.duplicate()
	on.bg_color = Color("ff4f8b")
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", on)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_color", "Label", Color("d8d8e0"))
	t.set_stylebox("pressed_hover", "Button", on)
	t.set_type_variation("OnButton", "Button")
	t.set_stylebox("normal", "OnButton", on)
	t.set_stylebox("hover", "OnButton", on)
	return t


func is_open() -> bool:
	return visible


## Model: {title, status, ok, sections: [{title, buttons: [{id, label, on}]}], footer: [...]}
func set_model(m: Dictionary) -> void:
	model = m
	_wake()
	for c in _root.get_children():
		_root.remove_child(c)
		c.queue_free()
	_logo_sign = null
	_logo_name = null
	_reveal = []
	if String(m.get("layout", "")) == "start":
		_resize(PX_START, WIDTH_START)
		_build_start(m)
		return
	var tools := String(m.get("layout", "")) == "tools"
	if tools:
		_resize(PX_TOOLS, WIDTH_TOOLS)
	else:
		_resize(PX_MENU, WIDTH_MENU)
	_root.add_theme_stylebox_override("panel", _style_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_root.add_child(box)
	var title := Label.new()
	title.text = String(m.get("title", "VD VR"))
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)
	var status := Label.new()
	status.text = String(m.get("status", ""))
	status.add_theme_color_override("font_color", Color("7ee08a") if m.get("ok", true) else Color("ff7a8f"))
	status.add_theme_font_size_override("font_size", 28)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	for sec in m.get("sections", []):
		if String(sec.get("title", "")) != "":
			var l := Label.new()
			l.text = String(sec.title)
			l.add_theme_font_size_override("font_size", 28)
			l.add_theme_color_override("font_color", Color("9a9aa8"))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 100
			box.add_child(l)
		if not sec.get("buttons", []).is_empty():
			box.add_child(_grid(sec.buttons, int(sec.get("cols", 4))) if tools else _row(sec.buttons))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_row(m.get("footer", [])))


## Buttons in columns (toolbox).
func _grid(buttons: Array, cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	for b in buttons:
		var btn := Button.new()
		btn.text = String(b.label)
		btn.custom_minimum_size = Vector2(0, 86)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_text = true
		if b.get("on", false):
			btn.theme_type_variation = "OnButton"
		btn.pressed.connect(func(): action.emit(String(b.id)))
		g.add_child(btn)
	return g


func _row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for b in buttons:
		var btn := Button.new()
		btn.text = String(b.label)
		btn.custom_minimum_size = Vector2(0, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if b.get("on", false):
			btn.theme_type_variation = "OnButton"
		btn.pressed.connect(func(): action.emit(String(b.id)))
		row.add_child(btn)
	return row


## In front of the head: 0.85 m ahead, slightly below eye height, facing you.
func show_menu(head: Vector3, dir: Vector3) -> void:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	if not d.is_finite() or d.length() < 0.1:
		d = Vector3(0, 0, -1)
	var p := head + d * 0.85 + Vector3(0, -0.12, 0)
	global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), p)
	pinned = false
	_wake()
	visible = true


## Stand in the room at `xf` (faces +z of xf), e.g. on the start screen's pedestal.
func _wake(ms := 400) -> void:
	_awake_until = Time.get_ticks_msec() + ms
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func pin(xf: Transform3D) -> void:
	_wake()
	global_transform = xf
	pinned = true
	visible = true


func hide_menu() -> void:
	pinned = false
	visible = false
	_dot.visible = false


func _process(_dt: float) -> void:
	if not visible:
		return
	_dot.visible = false
	if not input_enabled:
		return
	for c in [right, left]:
		if not c.get_is_active():
			continue
		var hit = _hit(c)
		var pressed: bool = c.get_float("trigger") > 0.6 or c.is_button_pressed("trigger_click")
		var key := "right" if c == right else "left"
		if hit != null:
			_wake(250)
			_dot.global_position = hit[0]
			_dot.visible = true
			var pos: Vector2 = hit[1]
			var mv := InputEventMouseMotion.new()
			mv.position = pos
			_vp.push_input(mv, true)
			if pressed != _trigger_prev[key]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = pressed
				ev.position = pos
				_vp.push_input(ev, true)
		_trigger_prev[key] = pressed
		if hit != null:
			break
	if Time.get_ticks_msec() > _awake_until and _vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Controller ray on the panel: [world point, pixel position] or null.
func _hit(c: XRController3D):
	var t := c.global_transform
	var o := t.origin
	var d := -t.basis.z
	var plane := Plane(global_transform.basis.z, global_position)
	var p = plane.intersects_ray(o, d)
	if p == null:
		return null
	var local: Vector3 = global_transform.affine_inverse() * (p as Vector3)
	var size: Vector2 = (_quad.mesh as QuadMesh).size
	var u := local.x / size.x + 0.5
	var v := 0.5 - local.y / size.y
	if u < 0 or u > 1 or v < 0 or v > 1:
		return null
	return [p, Vector2(u * PX.x, v * PX.y)]


# ------------------------------------------------------------------ start screen (like VD-Link's)
const CARD_SHADER := "shader_type canvas_item;
uniform vec2 size = vec2(2000.0, 1150.0);
uniform float radius = 44.0;
uniform float border = 3.0;
uniform vec4 bg : source_color;
uniform vec4 line : source_color;
uniform vec4 tint_a : source_color;
uniform vec4 tint_b : source_color;
float sd(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
void fragment() {
	vec2 p = UV * size;
	float d = sd(p - size * 0.5, size * 0.5, radius);
	float inside = clamp(0.5 - d, 0.0, 1.0);
	vec3 c = bg.rgb;
	float ta = 1.0 - smoothstep(0.0, 0.6, length((UV - vec2(0.15, 0.0)) / vec2(0.75, 0.9)));
	float tb = 1.0 - smoothstep(0.0, 0.6, length((UV - vec2(0.9, 1.0)) / vec2(0.7, 0.9)));
	c = mix(c, tint_a.rgb, ta * tint_a.a);
	c = mix(c, tint_b.rgb, tb * tint_b.a);
	c = mix(c, line.rgb, clamp(d + border + 0.5, 0.0, 1.0));
	COLOR = vec4(c, inside * bg.a);
}"


func _resize(px: Vector2i, width: float) -> void:
	if PX == px:
		return
	PX = px
	_vp.size = px
	_root.size = px
	(_quad.mesh as QuadMesh).size = Vector2(width, width * px.y / px.x)


func _flat(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.anti_aliasing = true
	return s


func _text(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


func _ignore(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Tile like VD-Link's start buttons: line icon, title, one line below.
func _tile(t: Dictionary, primary := false, height := 132) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hi := Color("ff7aa8")
	var border: Color = t.get("border", ART.ACCENT if primary else ART.LINE)
	b.add_theme_stylebox_override("normal", _flat(ART.ACCENT if primary else ART.PANEL, border, 22, 3))
	var hover := _flat(hi if primary else ART.RAISE, hi if primary else t.get("border", ART.DIM), 22, 3)
	for st in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): action.emit(String(t.id)))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 30
	row.offset_right = -24
	row.add_theme_constant_override("separation", 26)
	b.add_child(_ignore(row))
	var ic := TextureRect.new()
	ic.texture = ART.icon(String(t.get("icon", "play")), Color.WHITE if primary else t.get("icon_color", ART.DIM), 96)
	ic.custom_minimum_size = Vector2(58, 58)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ignore(ic))
	var tx := VBoxContainer.new()
	tx.alignment = BoxContainer.ALIGNMENT_CENTER
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.add_theme_constant_override("separation", 2)
	row.add_child(_ignore(tx))
	var title := _text(String(t.title), 35, Color.WHITE if primary else ART.TEXT, ART.bold(0.6))
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tx.add_child(title)
	if String(t.get("sub", "")) != "":
		var sub := _text(String(t.sub), 27, Color(1, 1, 1, 0.85) if primary else ART.DIM)
		if t.get("wrap", false):
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tx.add_child(sub)
	return b


func _heading(text: String) -> Label:
	return _text(text.to_upper(), 23, ART.DIM, ART.spaced(4))


## Model: {layout: "start", name, tag, primary: tile, tiles: [tile], recent_title, recent: [tile],
##  recent_none, net_title, net_text, net_ok, help, status, ok, foot, intro: bool}
## tile = {id, title, sub, icon}
func _build_start(m: Dictionary) -> void:
	_root.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var bg := ColorRect.new()
	var sh := Shader.new()
	sh.code = CARD_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("size", Vector2(PX))
	mat.set_shader_parameter("bg", Color(0.082, 0.094, 0.129, 1.0))
	mat.set_shader_parameter("line", ART.LINE)
	mat.set_shader_parameter("tint_a", Color(ART.SUITE[0], 0.10))
	mat.set_shader_parameter("tint_b", Color(ART.SUITE[3], 0.08))
	bg.material = mat
	_root.add_child(_ignore(bg))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 60 if side != "bottom" else 40)
	_root.add_child(_ignore(pad))
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 26)
	pad.add_child(_ignore(main))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	main.add_child(_ignore(body))

	# ---- left: logo, tag line, tiles
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.35
	left.add_theme_constant_override("separation", 18)
	body.add_child(_ignore(left))
	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 34)
	left.add_child(_ignore(logo))
	var sg := TextureRect.new()
	sg.texture = ART.slots(664)
	sg.custom_minimum_size = Vector2(332, 104)
	sg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.add_child(_ignore(sg))
	_logo_sign = sg
	var nm := _text(String(m.get("name", "VD VR")), 156, ART.TEXT, ART.bold(1.1))
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.add_child(nm)
	_logo_name = nm
	var tag := _text(String(m.get("tag", "")), 31, ART.DIM)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(tag)
	_reveal.append(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	left.add_child(_ignore(gap))
	if m.has("primary"):
		var p := _tile(m.primary, true, 146)
		left.add_child(p)
		_reveal.append(p)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	left.add_child(_ignore(grid))
	for t in m.get("tiles", []):
		var b := _tile(t)
		grid.add_child(b)
		_reveal.append(b)

	# ---- divider
	var g1 := Control.new()
	g1.custom_minimum_size = Vector2(52, 0)
	body.add_child(_ignore(g1))
	var div := ColorRect.new()
	div.color = ART.LINE
	div.custom_minimum_size = Vector2(3, 0)
	body.add_child(_ignore(div))
	var g2 := Control.new()
	g2.custom_minimum_size = Vector2(48, 0)
	body.add_child(_ignore(g2))

	# ---- right: saved shows, network, help
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	body.add_child(_ignore(right))
	var rh := _heading(String(m.get("recent_title", "")))
	right.add_child(rh)
	_reveal.append(rh)
	var recent: Array = m.get("recent", [])
	if recent.is_empty():
		var none := _text(String(m.get("recent_none", "")), 27, ART.DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(none)
		_reveal.append(none)
	for t in recent:
		var b := _tile(t, false, 108)
		right.add_child(b)
		_reveal.append(b)
	var net := PanelContainer.new()
	var ns := _flat(ART.PANEL, ART.LINE, 22, 3)
	ns.set_content_margin_all(24)
	net.add_theme_stylebox_override("panel", ns)
	right.add_child(_ignore(net))
	_reveal.append(net)
	var nb := VBoxContainer.new()
	nb.add_theme_constant_override("separation", 8)
	net.add_child(_ignore(nb))
	nb.add_child(_heading(String(m.get("net_title", ""))))
	var live := HBoxContainer.new()
	live.add_theme_constant_override("separation", 14)
	nb.add_child(_ignore(live))
	var col := ART.GOOD if m.get("net_ok", false) else ART.WARN
	var dot := _text("●", 26, col)
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	live.add_child(dot)
	var nt := _text(String(m.get("net_text", "")), 27, col)
	nt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live.add_child(nt)
	if m.has("music"):
		var mu := _tile(m.music, false, 108)
		right.add_child(mu)
		_reveal.append(mu)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_ignore(fill))
	if m.has("love"):
		var lv := _tile(m.love, false, 150)
		right.add_child(lv)
		_reveal.append(lv)
	var help := _text(String(m.get("help", "")), 26, ART.DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(help)
	_reveal.append(help)

	# ---- foot: status, name
	var foot := HBoxContainer.new()
	main.add_child(_ignore(foot))
	var st := _text(String(m.get("status", "")), 26, ART.GOOD if m.get("ok", true) else Color("ff7a8f"))
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot.add_child(st)
	foot.add_child(_text(String(m.get("foot", "")), 24, ART.DIM))
	_reveal.append(foot)
	if m.get("intro", false):
		_logo_name.visible_ratio = 0.0
		for c in _reveal:
			c.modulate.a = 0.0


## Start animation: the name wipes in next to the sign, then the parts fade in one after another.
func play_reveal() -> void:
	if _logo_name == null:
		return
	_wake(1800)
	var tw := _logo_name.create_tween()
	tw.tween_property(_logo_name, "visible_ratio", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var step := minf(0.05, 0.35 / maxf(_reveal.size() - 1, 1))
	for i in _reveal.size():
		var c: Control = _reveal[i]
		var t := c.create_tween()
		t.tween_interval(0.15 + i * step)
		t.tween_property(c, "modulate:a", 1.0, 0.3)


## Whole panel see-through (start animation).
func set_alpha(a: float) -> void:
	_mat.albedo_color.a = a


## Where the VD sign of the start screen is in the room: [centre, width] (for the start animation).
func sign_in_world() -> Array:
	if _logo_sign == null:
		return []
	var r := _logo_sign.get_global_rect()
	var size: Vector2 = (_quad.mesh as QuadMesh).size
	var c := r.get_center()
	var local := Vector3((c.x / PX.x - 0.5) * size.x, (0.5 - c.y / PX.y) * size.y, 0)
	var w := r.size.x / PX.x * size.x * global_transform.basis.x.length()
	return [global_transform * local, w]
