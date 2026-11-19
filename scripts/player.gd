# Moving around in VD VR, like the browser viewer (src/vr/locomotion.ts):
#   right stick forward = aim the teleport arc, release = jump (only onto surfaces facing up)
#   right stick left/right = turn (30° / 45° steps or smooth)
#   left stick = walk (blocked by solid objects, follows floors and steps up to 40 cm)
#   B / Y or the menu button = menu
# The player is the XROrigin3D: moving it moves the play space through the club.
extends Node3D

const WALK_SPEED := 1.8
const SMOOTH_TURN := PI * 0.6
const STEP_UP := 0.4
const ARC_POINTS := 48
const COLOR_OK := Color("4fe3ff")
const COLOR_BAD := Color("ff4f6d")

var origin: XROrigin3D
var camera: XRCamera3D
var left: XRController3D
var right: XRController3D
var menu: Node3D
var settings: Dictionary
## Room rectangle (half width/depth) – the room walls are not solid, so walking stops here.
var room_half := Vector2(10, 7)

var _aiming := false
var _turned := false
var _menu_prev := false
## Set by main: what B / Y does (open, close, pin back on the start screen).
var menu_button: Callable
## Club scan: the sticks and the trigger belong to the drawing tools – no walking, turning, teleporting.
var locked := false
var _target = null
var _arc := MeshInstance3D.new()
var _arc_mesh := ImmediateMesh.new()
var _arc_mat := StandardMaterial3D.new()
var _marker := MeshInstance3D.new()


func _ready() -> void:
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.vertex_color_use_as_albedo = true
	_arc_mat.no_depth_test = true
	_arc.mesh = _arc_mesh
	_arc.material_override = _arc_mat
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc.top_level = true
	add_child(_arc)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.3
	ring.rings = 32
	ring.ring_segments = 4
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = COLOR_OK
	rm.no_depth_test = true
	_marker.mesh = ring
	_marker.material_override = rm
	_marker.scale = Vector3(1, 0.1, 1)
	_marker.top_level = true
	_marker.visible = false
	add_child(_marker)
	for c in [left, right]:
		_add_controller_model(c)


## Simple controller body and pointer ray (no render models – they are switched off).
func _add_controller_model(c: XRController3D) -> void:
	var body := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = 0.025
	m.height = 0.14
	body.mesh = m
	body.rotation_degrees = Vector3(90, 0, 0)
	body.position = Vector3(0, 0, 0.05)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.85, 0.85, 0.9)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body.material_override = bm
	c.add_child(body)
	var ray := MeshInstance3D.new()
	var rmesh := BoxMesh.new()
	rmesh.size = Vector3(0.004, 0.004, 1.0)
	ray.mesh = rmesh
	ray.position = Vector3(0, 0, -0.5)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(1, 1, 1, 0.8)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray.material_override = rmat
	ray.name = "Ray"
	ray.visible = false
	c.add_child(ray)


func head() -> Vector3:
	return camera.global_position


func head_dir() -> Vector3:
	return -camera.global_transform.basis.z


## Put the player on a floor point, looking in direction `yaw` (radians).
func place(p: Vector3, yaw: float) -> void:
	origin.global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
	# Head offset inside the play space: put the head (not the play-space centre) on the point.
	var h := head()
	origin.global_position += Vector3(p.x - h.x, 0, p.z - h.z)


## Like place(), but the user's current view (not the play space) ends up looking along `yaw`.
func place_view(p: Vector3, yaw: float) -> void:
	var f := camera.global_transform.basis.z
	var origin_yaw := origin.global_transform.basis.get_euler().y
	var head_yaw := atan2(f.x, f.z) - origin_yaw
	place(p, yaw - head_yaw)


func _process(dt: float) -> void:
	var menu_open: bool = menu.is_open()
	# Menu toggle: B / Y (upper face button) or the menu button, either hand.
	var menu_btn := false
	for c in [left, right]:
		if c.get_has_tracking_data() or c.get_is_active():
			menu_btn = menu_btn or c.is_button_pressed("by_button") or c.is_button_pressed("menu_button")
	if menu_btn and not _menu_prev:
		if menu_button.is_valid():
			menu_button.call()
		elif menu_open:
			menu.hide_menu()
		else:
			menu.show_menu(head(), head_dir())
		menu_open = menu.is_open()
	_menu_prev = menu_btn
	for c in [left, right]:
		c.get_node("Ray").visible = menu_open and c.get_is_active()
	if locked:
		_hide_arc()
		return
	# A panel standing in the room (start screen) does not stop walking and teleporting.
	if menu_open and not menu.pinned:
		_hide_arc()
		return
	var both := left.get_is_active() and right.get_is_active()
	# Walking: left stick (only with two controllers – one controller teleports and turns).
	if settings.walk and both:
		var v: Vector2 = left.get_vector2("primary")
		if v.length() > 0.15:
			var d := head_dir()
			var f := Vector3(d.x, 0, d.z).normalized()
			var r := Vector3(-f.z, 0, f.x)
			_walk((f * v.y + r * v.x) * WALK_SPEED * dt)
	var turn_hand := right if right.get_is_active() else left
	var s: Vector2 = turn_hand.get_vector2("primary")
	# Teleport: stick forward = aim, release = jump.
	if s.y > 0.6 and absf(s.x) < 0.6:
		_aiming = true
	if _aiming:
		_update_arc(turn_hand)
		if s.length() < 0.3:
			_aiming = false
			if _target != null:
				_teleport(_target)
			_hide_arc()
		return
	# Turning: snap or smooth, around the head.
	if int(settings.turn) == 0:
		if absf(s.x) > 0.2:
			_turn(-s.x * SMOOTH_TURN * dt)
	elif absf(s.x) > 0.7 and not _turned:
		_turned = true
		_turn(-signf(s.x) * deg_to_rad(float(settings.turn)))
	elif absf(s.x) < 0.3:
		_turned = false


func _turn(angle: float) -> void:
	var h := head()
	var t := origin.global_transform
	t.origin -= Vector3(h.x, 0, h.z)
	t = Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO) * t
	t.origin += Vector3(h.x, 0, h.z)
	origin.global_transform = t


func _teleport(p: Vector3) -> void:
	var h := head()
	origin.global_position += Vector3(p.x - h.x, p.y - origin.global_position.y, p.z - h.z)


## Smooth walking: stops at solid objects and the room edge, follows floors and stairs.
func _walk(step: Vector3) -> void:
	var h := head()
	var feet := origin.global_position.y
	var space := get_world_3d().direct_space_state
	for y in [0.5, 1.2]:
		var from := Vector3(h.x, feet + y, h.z)
		var q := PhysicsRayQueryParameters3D.create(from, from + step.normalized() * (step.length() + 0.25))
		var hit := space.intersect_ray(q)
		if hit and (hit.normal as Vector3).y < 0.7:
			return
	var nx := clampf(h.x + step.x, -room_half.x + 0.3, room_half.x - 0.3)
	var nz := clampf(h.z + step.z, -room_half.y + 0.3, room_half.y - 0.3)
	# Floor below the new position: at most STEP_UP higher, any amount lower.
	var down := PhysicsRayQueryParameters3D.create(Vector3(nx, feet + STEP_UP + 0.05, nz), Vector3(nx, feet - 5.0, nz))
	var g := space.intersect_ray(down)
	var fy: float = (g.position as Vector3).y if g else feet
	origin.global_position += Vector3(nx - h.x, fy - feet, nz - h.z)


## Throwing arc from the controller, landing on any surface facing up.
func _update_arc(c: XRController3D) -> void:
	var t := c.global_transform
	var o := t.origin
	var v := -t.basis.z.normalized() * 8.0
	var space := get_world_3d().direct_space_state
	var pts: PackedVector3Array = [o]
	var prev := o
	_target = null
	var bad := true
	for i in range(1, ARC_POINTS):
		var tt := i * 0.04
		var p := o + v * tt + Vector3(0, -0.5 * 9.81 * tt * tt, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(prev, p))
		if hit:
			pts.append(hit.position)
			if (hit.normal as Vector3).y > 0.7:
				_target = hit.position
				bad = false
			break
		pts.append(p)
		prev = p
		if p.y < -2.0:
			break
	_arc_mesh.clear_surfaces()
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in pts:
		_arc_mesh.surface_set_color(COLOR_BAD if bad else COLOR_OK)
		_arc_mesh.surface_add_vertex(p)
	_arc_mesh.surface_end()
	_arc.visible = true
	_marker.visible = _target != null
	if _target != null:
		_marker.global_position = _target + Vector3(0, 0.02, 0)


func _hide_arc() -> void:
	_arc.visible = false
	_marker.visible = false
	_target = null
