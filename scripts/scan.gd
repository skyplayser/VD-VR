# Club studio in the headset: draw the real club by hand while you see it (passthrough) – like
# SteamVR's room setup, Oculus' furniture boxes and Pico's boundary, plus storeys, curves,
# openings, furniture and VD-Link's materials. VD-Link builds an editable location from it
# (src/shared/scan.ts).
#
# Toolbox over the left controller, right ray, trigger:
#   Boden     put the right controller on the floor, trigger – measures this storey (EG, OG, UG …)
#   Wand      points along the walls on the floor (right angles and corners snap), grip ends the line
#   Rundung   start, end, then a point on the curve
#   Empore    on its storey (measure its floor first): outline point by point, back at the first point
#             (or grip) closes it – a slab whose top is that floor; curves with more points
#   Geländer  railing / parapet as a line (1.1 m, glass) – along the edge of a gallery, a stair …
#   Öffnung   door, double door, gate, passage (to the next room), window, window band – on a wall
#   Möbel     two corners on the floor, then lift the controller to the height, trigger. Starting on
#             top of a platform (Bühne/Podest/Block/Empore) it stands on that – stairs from a landing.
#   Auswahl   pick a thing: drag it (corners of walls too), turn, resize, duplicate in the toolbox
#   Farbe     pick a VD-Link material, then point at a wall, a thing or the floor
#   Löschen   point, trigger · A: undo
# Rooms: „+ Raum“ starts the next room in the same coordinates (storeys and direction stay, finished
# rooms stay visible). Only when the Pico sets a new play area / recentres do the coordinates change
# (`frame` + 1) – then a passage marked in both rooms joins them in VD-Link.
# Big clubs: best with the Pico's play boundary off (Einstellungen → Entwickler → Entwickler-Tools
# Spielbereich → Spielbereich deaktivieren).
# Every change is kept as a draft (user://scans/_draft.json).
#
# Data, per room (tracking space, metres, x/z on the floor):
#   {format: "vd-vr-scan", version: 4, name, created, device,
#    rooms: [{name, frame, forward: [x, z], grid,      frame: same number = same coordinates
#             levels: [{name, y, height, floor, ceiling}],            materials: VD-Link presets ("" = default)
#             walls: [{level, a: [x, z], b: [x, z], via?: [x, z], h?, mat, kind?: "railing"}],  via = point on a curve
#             openings: [{wall, t, w, h, sill, kind, link?}],          t = centre along the wall 0…1
#             objects: [{level, type, c: [x, z], w, d, h, angle, mat, base?, pts?}]}]}
#   angle = direction of the width; base = bottom above the storey's floor (galleries: −h, their top
#   is the floor); stairs rise uphill along angle + 90°; type "slab" (Empore): pts = outline around c,
#   in the frame of angle.
# Desktop check without a headset: `-- --scan-fake` (an example club with two storeys).
extends Node3D

signal command(id: String)
## The drawing changed (main.gd sends it live to VD-Link).
signal drawing_changed

const DRAFT := "user://scans/_draft.json"
## VD-Link's material presets (src/render/objects.ts) with their colours.
const MATERIALS := [
	["black", "Schwarz", Color("0c0c0e")], ["darkgrey", "Dunkelgrau", Color("2a2b30")], ["grey", "Grau", Color("6a6c72")],
	["white", "Weiß", Color("d8d8d4")], ["marble", "Marmor", Color("1b1b20")], ["velvet-petrol", "Samt petrol", Color("0f5d70")],
	["velvet-violet", "Samt violett", Color("3a1e46")], ["metal", "Metall", Color("b9bcc4")], ["wood", "Holz", Color("5a3b24")],
	["glass", "Glas", Color("99aabb")], ["concrete", "Beton", Color("55565a")], ["led", "LED", Color("b23cff")],
]
## Furniture: name, default height (0 = up to the next storey / ceiling), material, one point only.
const FURNITURE := {
	"bar": ["Tresen", 1.1, "black", false], "table": ["Tisch", 0.75, "wood", false], "hightable": ["Stehtisch", 1.1, "wood", false],
	"sofa": ["Sofa", 0.9, "velvet-violet", false], "djbooth": ["DJ-Pult", 1.05, "black", false], "stage": ["Bühne", 0.6, "black", false],
	"podest": ["Podest", 0.4, "concrete", false],
	"pillar": ["Säule", 0.0, "concrete", true], "stairs": ["Treppe", 0.0, "concrete", false], "box": ["Block", 1.0, "grey", false],
	"speaker": ["Lautsprecher", 1.2, "black", false], "ledwall": ["LED-Wand", 2.5, "led", false],
}
## Not in the furniture list, but drawn: Empore (slab) and older galleries.
const OTHER_NAMES := { "slab": "Empore", "level": "Galerie" }
## Openings: name, width, height, sill.
const OPENINGS := {
	"door": ["Tür", 0.9, 2.1, 0.0], "double": ["Doppeltür", 1.6, 2.1, 0.0], "gate": ["Tor", 2.4, 2.4, 0.0],
	"passage": ["Durchgang", 1.2, 2.2, 0.0], "window": ["Fenster", 1.2, 1.2, 0.9], "band": ["Fensterband", 3.0, 1.0, 1.1],
}
const TOOLS := [["floor", "Boden"], ["wall", "Wand"], ["arc", "Rundung"], ["opening", "Öffnung"],
	["empore", "Empore"], ["railing", "Geländer"], ["furniture", "Möbel"], ["select", "Auswahl"],
	["paint", "Farbe"], ["delete", "Löschen"]]
## Platforms things can stand on (their top is a base for stairs and furniture).
const PLATFORMS := ["stage", "podest", "box", "slab", "level", "djbooth"]
const WALL := Color("22C8F0")
const OPEN := Color("FFB020")
const LINK := Color("3DDC84")
const OBJ := Color("FF5C93")
const SEL := Color("FFD84A")
const PLAY := Color("FFD84A")
const SNAP_POINT := 0.3
const SNAP_ANGLE := deg_to_rad(10.0)

var origin: XROrigin3D
var camera: XRCamera3D
var left: XRController3D
var right: XRController3D
var toolbox: Node3D
var menu: Node3D
var xr: XRInterface
var fake := false
## Address of VD-Link known: the toolbox offers „Senden“.
var can_send := false
## Model view: solid in the materials (instead of see-through over the real room).
var model_view := false
## Asks main.gd to switch passthrough (true = real room behind).
var passthrough_changed: Callable
## Writes a line to the log on the computer (net.gd).
var net_log: Callable
## Live view on the computer: „Live: Laptop“ or why not (shown in the toolbox).
var live_info := ""

var tool := "wall"
var furniture := "bar"
var opening := "door"
var material := "darkgrey"
var snap90 := true
var grid := 0.0
var has_grid := false
var lv := 0
var levels: Array = []
var walls: Array = []
var openings: Array = []
var objects: Array = []
## Finished rooms (room_data()), passages numbered across rooms.
var rooms: Array = []
var next_link := 1
## Coordinates: changes only when the Pico recentres (rooms of one frame fit together as drawn).
var frame := 0
var note := ""
## Selected thing: ["wall" | "object" | "opening", index] or [].
var selected: Array = []

var _forward := Vector2(0, -1)
var _chain := false
var _last := Vector2.ZERO
var _pts: Array = []
var _stage := 0
var _lift := 0.0
## Bottom of the furniture being drawn, above the storey's floor (on top of a platform).
var _base := 0.0
var _drag := {}
var _history: Array = []
var _prev := {}
var _cursor := Vector2.ZERO
var _cursor_ok := false
var _play := PackedVector2Array()
var _edge_note := ""
var _stick_turned := false

var _drawn := Node3D.new()
var _play_node := MeshInstance3D.new()
var _ring := MeshInstance3D.new()
var _preview := MeshInstance3D.new()
var _preview_mesh := ImmediateMesh.new()
var _label := Label3D.new()
var _laser := MeshInstance3D.new()
var _laser_mesh := ImmediateMesh.new()


## Starts; `forward` is the view direction (tracking space) at the start.
func start(forward: Vector3, use_fake: bool) -> void:
	fake = use_fake
	var f := Vector2(forward.x, forward.z)
	_forward = f.normalized() if f.length() > 0.01 else Vector2(0, -1)
	add_child(_drawn)
	add_child(_play_node)
	_build_cursor()
	_load_draft()
	if levels.is_empty():
		levels.append(_level("EG", 0.0, 4.0))
	if fake and walls.is_empty() and rooms.is_empty():
		_fake_club()
	if fake and OS.get_cmdline_user_args().has("--scan-model"):
		model_view = true
	if fake and OS.get_cmdline_user_args().has("--scan-fake-edit"):
		# Desktop check of the live view: something new after 8 s.
		get_tree().create_timer(8.0).timeout.connect(func():
			objects.append({ "level": 0, "type": "box", "c": [0.0, 0.0], "w": 3.0, "d": 3.0, "angle": grid, "h": 2.5, "mat": "led", "base": 0.0 })
			_changed())
	_read_play_area()
	if xr:
		xr.pose_recentered.connect(_on_recentered)
		xr.play_area_changed.connect(func(_m): _read_play_area())
	_rebuild()
	_update_toolbox()


static func _level(name: String, y: float, h: float) -> Dictionary:
	return { "name": name, "y": y, "height": h, "floor": "", "ceiling": "" }


# ------------------------------------------------------------------ data
func room_data() -> Dictionary:
	return { "name": "Raum %d" % (rooms.size() + 1), "frame": frame, "forward": [_forward.x, _forward.y], "grid": grid,
		"levels": levels.duplicate(true), "walls": _plain(walls), "openings": openings.duplicate(true), "objects": objects.duplicate(true) }


## Walls with arrays instead of Vector2 (JSON).
static func _plain(ws: Array) -> Array:
	var out: Array = []
	for w in ws:
		var o: Dictionary = w.duplicate()
		o.a = [_r(w.a.x), _r(w.a.y)]
		o.b = [_r(w.b.x), _r(w.b.y)]
		if w.has("via"):
			o.via = [_r(w.via.x), _r(w.via.y)]
		out.append(o)
	return out


static func _vec(ws: Array) -> Array:
	var out: Array = []
	for w in ws:
		var o: Dictionary = w.duplicate()
		o.a = Vector2(w.a[0], w.a[1])
		o.b = Vector2(w.b[0], w.b[1])
		o.level = int(w.get("level", 0))
		if w.has("via"):
			o.via = Vector2(w.via[0], w.via[1])
		out.append(o)
	return out


func data(device: String) -> Dictionary:
	return { "format": "vd-vr-scan", "version": 4, "device": device,
		"name": "Club %s" % Time.get_datetime_string_from_system().substr(0, 16).replace("T", " "),
		"created": Time.get_unix_time_from_system(), "rooms": rooms + [room_data()] }


static func _r(v: float) -> float:
	return snappedf(v, 0.001)


func summary() -> String:
	var parts: PackedStringArray = []
	parts.append("%d %s" % [walls.size(), "Wand" if walls.size() == 1 else "Wände"])
	parts.append("%d %s" % [openings.size(), "Öffnung" if openings.size() == 1 else "Öffnungen"])
	parts.append("%d Möbel" % objects.size())
	if levels.size() > 1:
		parts.append("%d Ebenen" % levels.size())
	if rooms.size():
		parts.append("%d %s fertig" % [rooms.size(), "Raum" if rooms.size() == 1 else "Räume"])
	return " · ".join(parts)


## Start over: all rooms gone.
func clear() -> void:
	rooms.clear()
	next_link = 1
	frame = 0
	_reset_room(true)
	_changed()


## `fresh`: new coordinates – storeys and direction start over too.
func _reset_room(fresh: bool) -> void:
	walls.clear()
	openings.clear()
	objects.clear()
	if fresh:
		levels = [_level("EG", 0.0, 4.0)]
		lv = 0
		has_grid = false
	else:
		for l in levels:
			l.floor = ""
			l.ceiling = ""
	_history.clear()
	selected = []
	_chain = false
	_pts.clear()
	_stage = 0


## This room is done; go on in the next one – in the same coordinates.
func new_room() -> void:
	rooms.append(room_data())
	_reset_room(false)
	note = "Raum %d: weiterzeichnen – die fertigen Räume bleiben blass zu sehen." % (rooms.size() + 1)
	_changed()


## The Pico recentred / set a new play area: the old coordinates no longer fit.
func _on_recentered() -> void:
	_read_play_area()
	net_log.call("pose recentered") if net_log.is_valid() else null
	if walls.is_empty() and objects.is_empty():
		frame += 1
		return
	rooms.append(room_data())
	frame += 1
	_reset_room(true)
	var f := -camera.transform.basis.z
	if Vector2(f.x, f.z).length() > 0.1:
		_forward = Vector2(f.x, f.z).normalized()
	note = "Die Pico hat neu zentriert – weiter als Raum %d. Boden einmessen und die Tür zum vorigen Raum als Durchgang markieren." % (rooms.size() + 1)
	_changed()


func _snapshot() -> void:
	_history.append({ "walls": walls.duplicate(true), "openings": openings.duplicate(true), "objects": objects.duplicate(true),
		"levels": levels.duplicate(true), "lv": lv })
	if _history.size() > 80:
		_history.pop_front()


func _undo() -> void:
	if _chain or not _pts.is_empty() or _stage > 0:
		_chain = false
		_pts.clear()
		_stage = 0
		_update_toolbox()
		return
	if _history.is_empty():
		return
	var h: Dictionary = _history.pop_back()
	walls = h.walls
	openings = h.openings
	objects = h.objects
	levels = h.levels
	lv = h.lv
	selected = []
	_changed()


func _changed() -> void:
	if not selected.is_empty() and not _sel_valid():
		selected = []
	_rebuild()
	_update_toolbox()
	drawing_changed.emit()
	DirAccess.make_dir_recursive_absolute(DRAFT.get_base_dir())
	var f := FileAccess.open(DRAFT, FileAccess.WRITE)
	if f:
		var d := data("")
		d["next_link"] = next_link
		d["lv"] = lv
		f.store_string(JSON.stringify(d))


func _load_draft() -> void:
	if not FileAccess.file_exists(DRAFT):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(DRAFT))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) < 4 or typeof(d.get("rooms")) != TYPE_ARRAY or d.rooms.is_empty():
		return
	rooms = d.rooms.slice(0, d.rooms.size() - 1)
	var cur: Dictionary = d.rooms.back()
	levels = cur.get("levels", [])
	walls = _vec(cur.get("walls", []))
	openings = cur.get("openings", [])
	objects = cur.get("objects", [])
	for o in objects:
		o.level = int(o.get("level", 0))
	grid = float(cur.get("grid", 0.0))
	frame = int(cur.get("frame", 0))
	has_grid = not walls.is_empty() or rooms.any(func(r): return int(r.get("frame", 0)) == frame and not r.get("walls", []).is_empty())
	next_link = int(d.get("next_link", 1))
	lv = clampi(int(d.get("lv", 0)), 0, maxi(0, levels.size() - 1))
	if not walls.is_empty() or not objects.is_empty() or not rooms.is_empty():
		note = "Entwurf geladen – weiterzeichnen oder im Menü neu beginnen."


# ------------------------------------------------------------------ toolbox
func on_tool(id: String) -> void:
	var p := id.split(":")
	match p[0]:
		"tool":
			tool = p[1]
			_chain = false
			_pts.clear()
			_stage = 0
			if tool != "select":
				selected = []
				_rebuild()
		"fur":
			furniture = p[1]
			tool = "furniture"
			_stage = 0
			_pts.clear()
		"open":
			opening = p[1]
			tool = "opening"
		"mat":
			material = p[1]
			if tool == "select" and _sel_valid():
				_snapshot()
				_set_mat(selected, material)
				_changed()
				return
			tool = "paint"
		"ceil":
			_snapshot()
			levels[lv].ceiling = material
			_changed()
			return
		"lv":
			lv = int(p[1])
			_rebuild()
		"lvh":
			_snapshot()
			levels[lv].height = clampf(float(levels[lv].height) + float(p[1]), 2.0, 30.0)
			_changed()
			return
		"snap":
			snap90 = not snap90
		"view":
			model_view = not model_view
			if passthrough_changed.is_valid():
				passthrough_changed.call(not model_view)
			_rebuild()
		"undo":
			_undo()
			return
		"room":
			new_room()
			return
		"save", "send":
			command.emit(id)
			return
		"sel":
			_edit_selected(p[1], float(p[2]) if p.size() > 2 else 0.0)
			return
	_update_toolbox()


func _hint() -> String:
	match tool:
		"floor":
			return "Rechten Controller auf den Boden legen, Trigger: diese Ebene einmessen (andere Höhe = neue Ebene)"
		"wall":
			return "Am Boden entlang der Wand: Trigger Punkt für Punkt · Grip: Linie beenden" if not _chain else "Nächster Punkt · an einer Ecke einrasten schließt · Grip: beenden"
		"arc":
			return ["Rundung: Trigger am Anfang", "Trigger am Ende der Rundung", "Trigger auf einem Punkt der Rundung"][mini(_pts.size(), 2)]
		"empore":
			if _pts.is_empty():
				return "Empore auf ihrer Ebene (vorher Boden einmessen): Umriss Punkt für Punkt, Trigger"
			return "Nächster Punkt · am ersten Punkt oder Grip: Empore schließen (%d Punkte)" % _pts.size()
		"railing":
			return "Geländer (1,1 m, Glas): Trigger Punkt für Punkt · Grip: beenden" if not _chain else "Nächster Punkt · Grip: beenden"
		"opening":
			var o: Array = OPENINGS[opening]
			return "%s %s × %s m%s: auf die Wand am Boden zeigen, Trigger" % [o[0], _n(o[1]), _n(o[2]), (", Brüstung %s m" % _n(o[3])) if o[3] > 0 else ""]
		"furniture":
			var f: Array = FURNITURE[furniture]
			if _stage == 2:
				return "Controller auf die Höhe heben (%s), Trigger: fertig" % _m(_lift)
			if f[3]:
				return "Trigger: %s setzen" % f[0]
			if furniture == "stairs":
				return "Trigger unten an der ersten Stufe" if _pts.is_empty() else "Trigger oben an der gegenüberliegenden Ecke"
			return ("Trigger: erste Ecke von %s" % f[0]) if _pts.is_empty() else "Trigger: gegenüberliegende Ecke"
		"select":
			return "Auf ein Teil zeigen, Trigger: auswählen · halten und ziehen: verschieben · rechter Stick: drehen"
		"paint":
			return "Material %s: auf Wand, Möbel oder Boden zeigen, Trigger" % _mat_name(material)
		"delete":
			return "Auf Wand, Öffnung oder Möbel zeigen, Trigger: löschen"
	return ""


static func _n(v: float) -> String:
	var s := ("%.2f" % v)
	while s.ends_with("0") and s.contains("."):
		s = s.left(-1)
	if s.ends_with("."):
		s = s.left(-1)
	return s.replace(".", ",")


static func _mat_name(id: String) -> String:
	for m in MATERIALS:
		if m[0] == id:
			return m[1]
	return "Standard"


static func _mat_color(id: String, fallback: Color) -> Color:
	for m in MATERIALS:
		if m[0] == id:
			return m[2]
	return fallback


func _update_toolbox() -> void:
	if toolbox == null:
		return
	var on := func(id: String, label: String, active: bool) -> Dictionary:
		return { "id": id, "label": label, "on": active }
	var tb: Array = []
	for t in TOOLS:
		tb.append(on.call("tool:" + t[0], t[1], tool == t[0]))
	var sections: Array = [{ "title": "", "cols": 4, "buttons": tb }]
	match tool:
		"furniture":
			var b: Array = []
			for k in FURNITURE:
				b.append(on.call("fur:" + k, FURNITURE[k][0], furniture == k))
			sections.append({ "title": "", "cols": 4, "buttons": b })
		"opening":
			var b: Array = []
			for k in OPENINGS:
				b.append(on.call("open:" + k, OPENINGS[k][0], opening == k))
			sections.append({ "title": "", "cols": 3, "buttons": b })
		"paint":
			var b: Array = []
			for m in MATERIALS:
				b.append(on.call("mat:" + m[0], m[1], material == m[0]))
			sections.append({ "title": "", "cols": 4, "buttons": b })
			sections.append({ "title": "", "cols": 1, "buttons": [{ "id": "ceil", "label": "Decke von %s: %s" % [levels[lv].name, _mat_name(material)] }] })
		"wall", "railing", "empore":
			sections.append({ "title": "", "cols": 1, "buttons": [on.call("snap", "Rechte Winkel einrasten", snap90)] })
		"select":
			sections.append_array(_selection_sections())
	# Storeys: pick one, ceiling height.
	var lb: Array = []
	for i in mini(levels.size(), 4):
		lb.append(on.call("lv:%d" % i, "%s %s" % [levels[i].name, _n(float(levels[i].y))], i == lv))
	sections.append({ "title": "Ebene · Deckenhöhe %s m" % _n(float(levels[lv].height)), "cols": 3,
		"buttons": lb + [{ "id": "lvh:-0.25", "label": "Decke −" }, { "id": "lvh:0.25", "label": "Decke +" }] })
	var acts: Array = [{ "id": "undo", "label": "Zurück" }, on.call("view", "Modell", model_view), { "id": "room", "label": "+ Raum" },
		{ "id": "save", "label": "Speichern" }]
	if can_send:
		acts.append({ "id": "send", "label": "Senden" })
	sections.append({ "title": summary(), "cols": 3, "buttons": acts })
	var n := _edge_note if _edge_note != "" else note
	if n != "":
		sections.append({ "title": n, "buttons": [] })
	toolbox.set_model({ "layout": "tools", "title": "Raum %d · %s%s" % [rooms.size() + 1, levels[lv].name, (" · " + live_info) if live_info != "" else " · Club-Studio"],
		"status": _hint(), "ok": true, "sections": sections, "footer": [] })


func _selection_sections() -> Array:
	if not _sel_valid():
		return [{ "title": "Nichts ausgewählt", "buttons": [] }]
	var kind: String = selected[0]
	var i: int = selected[1]
	var b := func(id: String, label: String) -> Dictionary:
		return { "id": "sel:" + id, "label": label }
	match kind:
		"object":
			var o: Dictionary = objects[i]
			return [{ "title": "%s · %s × %s × %s m%s · %s" % [_obj_name(o), _n(o.w), _n(o.d), _n(_obj_h(o)), (" · unten %s m" % _n(_obj_base(o))) if absf(_obj_base(o)) > 0.01 else "", _mat_name(o.get("mat", ""))], "cols": 4, "buttons": [
				b.call("turn:-15", "↺ 15°"), b.call("turn:15", "↻ 15°"), b.call("dup", "Duplizieren"), b.call("del", "Löschen"),
				b.call("w:-0.1", "Breite −"), b.call("w:0.1", "Breite +"), b.call("d:-0.1", "Tiefe −"), b.call("d:0.1", "Tiefe +"),
				b.call("h:-0.1", "Höhe −"), b.call("h:0.1", "Höhe +"), b.call("base:-0.1", "Unterkante −"), b.call("base:0.1", "Unterkante +")] }]
		"opening":
			var o: Dictionary = openings[i]
			return [{ "title": "%s · %s × %s m%s" % [OPENINGS.get(o.kind, ["Öffnung"])[0], _n(o.w), _n(o.h), (" · Brüstung %s m" % _n(o.sill)) if float(o.sill) > 0 else ""], "cols": 4, "buttons": [
				b.call("w:-0.1", "Breite −"), b.call("w:0.1", "Breite +"), b.call("h:-0.1", "Höhe −"), b.call("h:0.1", "Höhe +"),
				b.call("sill:-0.1", "Brüstung −"), b.call("sill:0.1", "Brüstung +"), b.call("del", "Löschen")] }]
		"wall":
			var w: Dictionary = walls[i]
			return [{ "title": "Wand · %s m%s · %s" % [_n(_wall_len(w)), " · Rundung" if w.has("via") else "", _mat_name(w.get("mat", ""))], "cols": 3, "buttons": [
				b.call("h:-0.25", "Höhe −"), b.call("h:0.25", "Höhe +"), b.call("del", "Löschen")] }]
	return []


func _sel_valid() -> bool:
	if selected.size() != 2:
		return false
	var list: Array = { "wall": walls, "object": objects, "opening": openings }.get(selected[0], [])
	return int(selected[1]) < list.size()


func _edit_selected(what: String, v: float) -> void:
	if not _sel_valid():
		return
	_snapshot()
	var kind: String = selected[0]
	var i: int = selected[1]
	match what:
		"del":
			_remove(kind, i)
			selected = []
		"dup":
			if kind == "object":
				var o: Dictionary = objects[i].duplicate(true)
				var off := Vector2(0.5, 0.5).rotated(float(o.angle))
				o.c = [_r(o.c[0] + off.x), _r(o.c[1] + off.y)]
				objects.append(o)
				selected = ["object", objects.size() - 1]
		"turn":
			objects[i].angle = float(objects[i].angle) + deg_to_rad(v)
		"w", "d":
			var list: Array = objects if kind == "object" else openings
			var old := float(list[i][what])
			list[i][what] = _r(maxf(0.1, old + v))
			# An Empore's outline grows with it.
			if kind == "object" and list[i].has("pts") and old > 0.01:
				var k := float(list[i][what]) / old
				for q in list[i].pts:
					q[0 if what == "w" else 1] = _r(float(q[0 if what == "w" else 1]) * k)
		"h":
			if kind == "object":
				objects[i].h = _r(maxf(0.05, _obj_h(objects[i]) + v))
			elif kind == "opening":
				openings[i].h = _r(maxf(0.3, float(openings[i].h) + v))
			else:
				walls[i].h = _r(maxf(0.3, _wall_h(walls[i]) + v))
		"sill":
			openings[i].sill = _r(maxf(0.0, float(openings[i].sill) + v))
		"base":
			objects[i].base = _r(_obj_base(objects[i]) + v)
	_changed()


func _remove(kind: String, i: int) -> void:
	match kind:
		"object":
			objects.remove_at(i)
		"opening":
			openings.remove_at(i)
		"wall":
			walls.remove_at(i)
			var keep: Array = []
			for o in openings:
				if int(o.wall) == i:
					continue
				if int(o.wall) > i:
					o.wall = int(o.wall) - 1
				keep.append(o)
			openings = keep


func _set_mat(sel: Array, mat: String) -> void:
	match sel[0]:
		"wall":
			walls[sel[1]].mat = mat
		"object":
			objects[sel[1]].mat = mat
		"floor":
			levels[sel[1]].floor = mat


# ------------------------------------------------------------------ every frame
func _process(_dt: float) -> void:
	_place_toolbox()
	_check_edge()
	_aim()
	if right == null or not right.get_is_active():
		return
	var trig := right.get_float("trigger") > 0.6 or right.is_button_pressed("trigger_click")
	var grip := right.get_float("grip") > 0.6 or right.is_button_pressed("grip_click")
	var a := right.is_button_pressed("ax_button")
	var busy := _pointing_at_panel()
	if trig and not _prev.get("trig", false) and not busy:
		_act()
	elif trig and not _drag.is_empty() and _cursor_ok:
		_drag_to(_cursor)
	if not trig and _prev.get("trig", false) and not _drag.is_empty():
		_drag = {}
		_changed()
	if grip and not _prev.get("grip", false):
		if tool == "empore" and _pts.size() >= 3:
			_close_empore()
		_chain = false
		_pts.clear()
		_stage = 0
		_update_toolbox()
	if a and not _prev.get("a", false):
		_undo()
	# Right stick turns the selected piece of furniture.
	var s: Vector2 = right.get_vector2("primary")
	if tool == "select" and _sel_valid() and selected[0] == "object":
		if absf(s.x) > 0.7 and not _stick_turned:
			_stick_turned = true
			_edit_selected("turn", 15.0 * signf(s.x))
		elif absf(s.x) < 0.3:
			_stick_turned = false
	if _stage == 2:
		var hand := origin.global_transform.affine_inverse() * right.global_transform
		var lift := maxf(0.05, snappedf(hand.origin.y - _ly() - _base, 0.05))
		if lift != _lift:
			_lift = lift
			_update_toolbox()
		_update_preview_lift()
	_prev = { "trig": trig, "grip": grip, "a": a }


func _ly() -> float:
	return float(levels[lv].y)


func _pointing_at_panel() -> bool:
	for p in [toolbox, menu]:
		if p != null and p.visible and right != null and p._hit(right) != null:
			return true
	return false


## Toolbox above the left controller, turned to your eyes (or in front on the left without one).
func _place_toolbox() -> void:
	if toolbox == null:
		return
	var head := camera.global_position
	var p: Vector3
	if left != null and left.get_is_active():
		p = left.global_position + Vector3(0, 0.2, 0)
	else:
		var f := -camera.global_transform.basis.z
		f = Vector3(f.x, 0, f.z).normalized()
		p = head + f * 0.6 + Vector3(-f.z, 0, f.x) * -0.34 + Vector3(0, -0.15, 0)
	var d := p - head
	if d.length() < 0.05:
		return
	toolbox.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), p)


## Right ray → point on this storey's floor (tracking space), snapped.
func _aim() -> void:
	_cursor_ok = false
	_preview_mesh.clear_surfaces()
	_laser_mesh.clear_surfaces()
	_label.visible = false
	if right == null or not right.get_is_active() or origin == null:
		_ring.visible = false
		return
	var xf := origin.global_transform.affine_inverse() * right.global_transform
	var o := xf.origin
	var d := -xf.basis.z
	var hit := o + d * 2.0
	if d.y < -0.03 and not _pointing_at_panel():
		var t := (_ly() - o.y) / d.y
		if t > 0.0 and t < 40.0:
			hit = o + d * t
			_cursor = _snap(Vector2(hit.x, hit.z))
			_cursor_ok = true
	_laser_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_laser_mesh.surface_set_color(Color(1, 1, 1, 0.6))
	_laser_mesh.surface_add_vertex(o)
	_laser_mesh.surface_add_vertex(_v3(_cursor) if _cursor_ok else hit)
	_laser_mesh.surface_end()
	_ring.visible = _cursor_ok and tool != "floor"
	if not _cursor_ok:
		return
	_ring.position = _v3(_cursor, 0.01)
	var col: Color = { "wall": WALL, "arc": WALL, "railing": LINK, "empore": OBJ, "opening": OPEN, "furniture": OBJ, "select": SEL, "paint": _mat_color(material, WALL) }.get(tool, Color("ff4f6d"))
	(_ring.material_override as StandardMaterial3D).albedo_color = col
	match tool:
		"wall", "railing":
			if _chain:
				_line(_preview_mesh, [_v3(_last), _v3(_cursor)], col)
				_show_label((_last + _cursor) / 2.0, _m(_last.distance_to(_cursor)))
		"empore":
			if not _pts.is_empty():
				var pl: Array = []
				for q in _pts:
					pl.append(_v3(q, 0.01))
				pl.append(_v3(_cursor, 0.01))
				_line(_preview_mesh, pl, OBJ)
				_show_label(_cursor, "%d Punkte" % (_pts.size() + 1))
		"arc":
			if _pts.size() == 1:
				_line(_preview_mesh, [_v3(_pts[0]), _v3(_cursor)], col)
			elif _pts.size() == 2:
				var w := { "a": _pts[0], "b": _pts[1], "via": _cursor }
				var pts: Array = []
				for q in _wall_points(w):
					pts.append(_v3(q))
				_line(_preview_mesh, pts, col)
				_show_label(_cursor, _m(_wall_len(w)))
		"furniture":
			if _stage == 1:
				var r := _rect(_pts[0], _cursor)
				_box_lines(_preview_mesh, r.corners, 0.0, col)
				_show_label(r.c, "%s × %s" % [_m(r.w), _m(r.d)])


## Height pull of new furniture: the box grows with the controller.
func _update_preview_lift() -> void:
	if _pts.size() < 2:
		return
	var r := _rect(_pts[0], _pts[1])
	_box_lines(_preview_mesh, r.corners, _lift, OBJ, _base)
	_label.text = _m(_lift)
	_label.position = _v3(r.c, _base + _lift + 0.2)
	_label.visible = true


func _v3(p: Vector2, up := 0.0) -> Vector3:
	return Vector3(p.x, _ly() + up, p.y)


static func _m(v: float) -> String:
	return ("%.2f m" % v).replace(".", ",")


func _show_label(at: Vector2, text: String) -> void:
	_label.text = text
	_label.position = _v3(at, 0.25)
	_label.visible = true


## Corners snap to corners of this storey (not to the ones being dragged); walls to right angles.
func _snap(p: Vector2) -> Vector2:
	var dragged: Array = _drag.get("corners", [])
	for i in walls.size():
		var w: Dictionary = walls[i]
		if int(w.level) != lv:
			continue
		for e in ["a", "b"]:
			if p.distance_to(w[e]) < SNAP_POINT and not dragged.has([i, e]):
				return w[e]
	if (tool == "wall" or tool == "railing") and _chain and snap90 and has_grid:
		var v := p - _last
		var ang := fposmod(v.angle() - grid, PI / 2)
		if ang < SNAP_ANGLE or ang > PI / 2 - SNAP_ANGLE:
			var k := roundf((v.angle() - grid) / (PI / 2))
			var dir := Vector2.from_angle(grid + k * PI / 2)
			return _last + dir * v.dot(dir)
	return p


func _act() -> void:
	note = ""
	if tool == "floor":
		_measure_floor()
		return
	if not _cursor_ok and _stage != 2:
		return
	match tool:
		"empore":
			if _pts.size() >= 3 and _cursor.distance_to(_pts[0]) < SNAP_POINT:
				_close_empore()
				return
			_pts.append(_cursor)
			if not has_grid and _pts.size() == 2:
				grid = (_pts[1] - _pts[0]).angle()
				has_grid = true
			_update_toolbox()
		"railing":
			if not _chain:
				_chain = true
				_last = _cursor
				_update_toolbox()
				return
			if _cursor.distance_to(_last) < 0.2:
				return
			_snapshot()
			walls.append({ "level": lv, "a": _last, "b": _cursor, "mat": "glass", "h": 1.1, "kind": "railing" })
			_last = _cursor
			_changed()
		"wall":
			if not _chain:
				_chain = true
				_last = _cursor
				_update_toolbox()
				return
			if _cursor.distance_to(_last) < 0.2:
				return
			_snapshot()
			if not has_grid:
				grid = (_cursor - _last).angle()
				has_grid = true
			var closed := _is_corner(_cursor)
			walls.append({ "level": lv, "a": _last, "b": _cursor, "mat": "" })
			_last = _cursor
			if closed:
				_chain = false
			_changed()
		"arc":
			_pts.append(_cursor)
			if _pts.size() == 3:
				_snapshot()
				walls.append({ "level": lv, "a": _pts[0], "b": _pts[1], "via": _pts[2], "mat": "" })
				if not has_grid:
					grid = (_pts[1] - _pts[0]).angle()
					has_grid = true
				_pts.clear()
				_changed()
			else:
				_update_toolbox()
		"opening":
			var w := _wall_at(_cursor, 0.6, true)
			if w < 0:
				note = "Keine gerade Wand in der Nähe."
				_update_toolbox()
				return
			_snapshot()
			var s: Dictionary = walls[w]
			var len: float = s.a.distance_to(s.b)
			var t := clampf((_cursor - s.a).dot(s.b - s.a) / (len * len), 0.0, 1.0)
			var o: Array = OPENINGS[opening]
			var op := { "wall": w, "t": _r(t), "w": minf(o[1], len), "h": o[2], "sill": o[3], "kind": opening }
			if opening == "passage":
				var open := _open_links()
				if open.is_empty():
					op["link"] = next_link
					next_link += 1
				else:
					op["link"] = open[0]
			openings.append(op)
			_changed()
		"furniture":
			_furniture_click()
		"select":
			_select_at(_cursor)
		"paint":
			var hit := _thing_at(_cursor)
			_snapshot()
			if hit.is_empty() or hit[0] == "opening":
				_set_mat(["floor", lv], material)
			else:
				_set_mat(hit, material)
			_changed()
		"delete":
			var hit := _thing_at(_cursor)
			if hit.is_empty():
				return
			_snapshot()
			_remove(hit[0], hit[1])
			_changed()


## The outline is done: a slab (default 0.3 m thick) whose top is this storey's floor.
func _close_empore() -> void:
	_snapshot()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in _pts:
		var r: Vector2 = q.rotated(-grid)
		lo = lo.min(r)
		hi = hi.max(r)
	var c := ((lo + hi) / 2.0).rotated(grid)
	var local: Array = []
	for q in _pts:
		var r: Vector2 = (q - c).rotated(-grid)
		local.append([_r(r.x), _r(r.y)])
	objects.append({ "level": lv, "type": "slab", "c": [_r(c.x), _r(c.y)], "w": _r(hi.x - lo.x), "d": _r(hi.y - lo.y),
		"angle": grid, "h": 0.3, "base": -0.3, "mat": "concrete", "pts": local })
	_pts.clear()
	note = "Empore angelegt – Geländer an den offenen Kanten mit „Geländer“ einzeichnen."
	_changed()


## Right controller on the floor: this storey's floor height. A height ≥ 1.5 m away is a new storey.
func _measure_floor() -> void:
	if right == null or origin == null:
		return
	var hand := origin.global_transform.affine_inverse() * right.global_transform
	var y := _r(hand.origin.y - 0.03)
	_snapshot()
	for i in levels.size():
		if absf(float(levels[i].y) - y) < 1.5:
			levels[i].y = y
			lv = i
			note = "%s eingemessen: %s m." % [levels[i].name, _n(y)]
			_changed()
			return
	var l := _level("", y, 3.0)
	levels.append(l)
	_name_levels()
	lv = levels.find(l)
	note = "Neue Ebene %s bei %s m." % [levels[lv].name, _n(y)]
	_changed()


## EG is the storey you started on; above OG 1, OG 2 …, below UG 1 …
func _name_levels() -> void:
	var base := float(levels[0].y)
	var up: Array = []
	var down: Array = []
	for l in levels.slice(1):
		(up if float(l.y) > base else down).append(l)
	up.sort_custom(func(p, q): return p.y < q.y)
	down.sort_custom(func(p, q): return p.y > q.y)
	for i in up.size():
		up[i].name = "OG %d" % (i + 1)
	for i in down.size():
		down[i].name = "UG %d" % (i + 1)


func _furniture_click() -> void:
	var f: Array = FURNITURE[furniture]
	if _stage == 2:
		_snapshot()
		var r := _rect(_pts[0], _pts[1])
		var o := { "level": lv, "type": furniture, "c": [_r(r.c.x), _r(r.c.y)], "w": _r(r.w), "d": _r(r.d), "angle": grid,
			"h": _r(_lift), "mat": f[2], "base": _r(_base) }
		if furniture == "stairs":
			# From the first corner (bottom) up to the second (top): uphill along the longer side.
			var up: Vector2 = _pts[1] - _pts[0]
			var along := Vector2.from_angle(grid)
			if absf(up.dot(along.orthogonal())) > absf(up.dot(along)):
				along = along.orthogonal()
			if up.dot(along) < 0:
				along = -along
			o.w = _r(absf(up.dot(along.orthogonal())))
			o.d = _r(absf(up.dot(along)))
			o.angle = along.angle() - PI / 2
		objects.append(o)
		_pts.clear()
		_stage = 0
		_changed()
		return
	if _pts.is_empty():
		_base = _platform_top(_cursor)
	if f[3]:
		_pts = [_cursor - Vector2(0.25, 0.25).rotated(grid), _cursor + Vector2(0.25, 0.25).rotated(grid)]
	else:
		_pts.append(_cursor)
		if _pts.size() < 2:
			_stage = 1
			if _base > 0.01:
				note = "Steht auf der Plattform (Unterkante %s m)." % _n(_base)
			_update_toolbox()
			return
		var r := _rect(_pts[0], _pts[1])
		if r.w < 0.15 or r.d < 0.15:
			_pts.clear()
			_stage = 0
			_update_toolbox()
			return
	# Height: the controller's height above the base – start from the usual one.
	_stage = 2
	_lift = float(f[1]) if f[1] > 0 else maxf(0.2, _next_rise() - _base)
	_update_toolbox()


## Top of a platform under p on this storey (stage, block, gallery …), 0 if none.
func _platform_top(p: Vector2) -> float:
	var best := 0.0
	for o in objects:
		if int(o.level) != lv or not PLATFORMS.has(o.type):
			continue
		var local := (p - Vector2(o.c[0], o.c[1])).rotated(-float(o.angle))
		if absf(local.x) <= float(o.w) / 2.0 and absf(local.y) <= float(o.d) / 2.0:
			best = maxf(best, _obj_base(o) + _obj_h(o))
	return best


## Stairs / pillar: up to the next storey (or the ceiling).
func _next_rise() -> float:
	var best := float(levels[lv].height)
	for l in levels:
		var dy := float(l.y) - _ly()
		if dy > 0.5 and dy < best:
			best = dy
	return best


func _is_corner(p: Vector2) -> bool:
	for w in walls:
		if int(w.level) == lv and (w.a == p or w.b == p):
			return true
	return false


## Rectangle from two corners, along the drawing grid.
func _rect(a: Vector2, b: Vector2) -> Dictionary:
	var ra := a.rotated(-grid)
	var rb := b.rotated(-grid)
	var lo := Vector2(minf(ra.x, rb.x), minf(ra.y, rb.y))
	var hi := Vector2(maxf(ra.x, rb.x), maxf(ra.y, rb.y))
	var corners: Array = []
	for q in [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]:
		corners.append(q.rotated(grid))
	return { "c": ((lo + hi) / 2.0).rotated(grid), "w": hi.x - lo.x, "d": hi.y - lo.y, "corners": corners }


func _wall_at(p: Vector2, max_d: float, straight_only := false) -> int:
	var best := -1
	var bd := max_d
	for i in walls.size():
		var w: Dictionary = walls[i]
		if int(w.level) != lv or (straight_only and (w.has("via") or w.get("kind", "") == "railing")):
			continue
		var pts := _wall_points(w)
		for k in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])
			if q.distance_to(p) < bd:
				bd = q.distance_to(p)
				best = i
	return best


## What is at p on this storey: furniture first, then openings, then walls.
func _thing_at(p: Vector2) -> Array:
	for i in range(objects.size() - 1, -1, -1):
		var o: Dictionary = objects[i]
		if int(o.level) != lv:
			continue
		var local := (p - Vector2(o.c[0], o.c[1])).rotated(-float(o.angle))
		if o.type == "slab" and o.has("pts"):
			var poly := PackedVector2Array()
			for q in o.pts:
				poly.append(Vector2(q[0], q[1]))
			if Geometry2D.is_point_in_polygon(local, poly):
				return ["object", i]
			continue
		if absf(local.x) <= float(o.w) / 2.0 + 0.15 and absf(local.y) <= float(o.d) / 2.0 + 0.15:
			return ["object", i]
	for i in range(openings.size() - 1, -1, -1):
		var op: Dictionary = openings[i]
		var w: Dictionary = walls[int(op.wall)]
		if int(w.level) == lv and p.distance_to(w.a.lerp(w.b, float(op.t))) < float(op.w) / 2.0 + 0.15:
			return ["opening", i]
	var w := _wall_at(p, 0.4)
	return ["wall", w] if w >= 0 else []


func _select_at(p: Vector2) -> void:
	# A corner of a wall: drag every wall end meeting there.
	var corners: Array = []
	var q := Vector2.INF
	for i in walls.size():
		var w: Dictionary = walls[i]
		if int(w.level) != lv:
			continue
		for e in ["a", "b"]:
			if w[e].distance_to(p) < 0.35 and (q == Vector2.INF or w[e] == q):
				q = w[e]
				corners.append([i, e])
	if not corners.is_empty():
		_snapshot()
		_drag = { "corners": corners }
		selected = ["wall", corners[0][0]]
		_rebuild()
		_update_toolbox()
		return
	var hit := _thing_at(p)
	selected = hit
	if not hit.is_empty():
		_snapshot()
		if hit[0] == "object":
			var o: Dictionary = objects[hit[1]]
			_drag = { "object": hit[1], "off": Vector2(o.c[0], o.c[1]) - p }
		elif hit[0] == "opening":
			_drag = { "opening": hit[1] }
	_rebuild()
	_update_toolbox()


func _drag_to(p: Vector2) -> void:
	if _drag.has("corners"):
		for c in _drag.corners:
			walls[c[0]][c[1]] = p
	elif _drag.has("object"):
		var c: Vector2 = p + _drag.off
		objects[_drag.object].c = [_r(c.x), _r(c.y)]
	elif _drag.has("opening"):
		var op: Dictionary = openings[_drag.opening]
		var w: Dictionary = walls[int(op.wall)]
		var len: float = w.a.distance_to(w.b)
		op.t = _r(clampf((p - w.a).dot(w.b - w.a) / (len * len), 0.0, 1.0))
	_rebuild()
	drawing_changed.emit()


## Passages of earlier rooms that this room has not joined yet.
func _open_links() -> Array:
	var seen := {}
	for r in rooms:
		for o in r.get("openings", []):
			if o.has("link"):
				seen[int(o.link)] = int(seen.get(int(o.link), 0)) + 1
	for o in openings:
		if o.has("link"):
			seen[int(o.link)] = int(seen.get(int(o.link), 0)) + 1
	var out: Array = []
	for k in seen:
		if seen[k] == 1 and not openings.any(func(o): return o.has("link") and int(o.link) == k):
			out.append(k)
	return out


# ------------------------------------------------------------------ geometry
func _wall_h(w: Dictionary) -> float:
	var h := float(w.get("h", 0.0))
	return h if h > 0.05 else float(levels[int(w.level)].height)


func _obj_h(o: Dictionary) -> float:
	var h := float(o.get("h", 0.0))
	return h if h > 0.01 else float(levels[int(o.level)].height) - _obj_base(o)


## Bottom above the storey's floor; older galleries: their top is the floor.
func _obj_base(o: Dictionary) -> float:
	if o.has("base"):
		return float(o.base)
	return -float(o.get("h", 0.25)) if o.type == "level" else 0.0


static func _obj_name(o: Dictionary) -> String:
	return String(OTHER_NAMES.get(o.type, FURNITURE.get(o.type, ["Möbel"])[0]))


## Points along a wall: two for a straight one, a polyline for a curve (through `via`).
static func _wall_points(w: Dictionary) -> Array:
	if not w.has("via"):
		return [w.a, w.b]
	var c = _circle(w.a, w.via, w.b)
	if c == null:
		return [w.a, w.b]
	var a0: float = (w.a - c.c).angle()
	var am: float = (w.via - c.c).angle()
	var a1: float = (w.b - c.c).angle()
	# From a to b the way that passes the via point.
	var span := fposmod(a1 - a0, TAU)
	if fposmod(am - a0, TAU) > span:
		span -= TAU
	var n := maxi(8, int(absf(span) * float(c.r) / 0.3))
	var out: Array = []
	for k in n + 1:
		out.append(c.c + Vector2.from_angle(a0 + span * k / n) * float(c.r))
	return out


static func _circle(a: Vector2, b: Vector2, c: Vector2):
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 1e-6:
		return null
	var ux := (a.length_squared() * (b.y - c.y) + b.length_squared() * (c.y - a.y) + c.length_squared() * (a.y - b.y)) / d
	var uy := (a.length_squared() * (c.x - b.x) + b.length_squared() * (a.x - c.x) + c.length_squared() * (b.x - a.x)) / d
	var cc := Vector2(ux, uy)
	return { "c": cc, "r": cc.distance_to(a) }


static func _wall_len(w: Dictionary) -> float:
	var pts := _wall_points(w)
	var l := 0.0
	for k in pts.size() - 1:
		l += (pts[k] as Vector2).distance_to(pts[k + 1])
	return l


# ------------------------------------------------------------------ play area
func _read_play_area() -> void:
	_play = PackedVector2Array()
	if xr == null or fake:
		return
	for v in xr.get_play_area():
		_play.append(Vector2(v.x, v.z))
	if _play.size() < 3:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in _play:
		lo = lo.min(v)
		hi = hi.max(v)
	if minf(hi.x - lo.x, hi.y - lo.y) < 2.5:
		note = "Spielbereich nur %s × %s – für freie Bewegung in der Pico: Entwickler → Entwickler-Tools Spielbereich → Spielbereich deaktivieren." % [_m(hi.x - lo.x), _m(hi.y - lo.y)]


func _check_edge() -> void:
	var n := ""
	if _play.size() >= 3:
		var h := Vector2(camera.position.x, camera.position.z)
		var inside := Geometry2D.is_point_in_polygon(h, _play)
		var dist := INF
		for i in _play.size():
			dist = minf(dist, Geometry2D.get_closest_point_to_segment(h, _play[i], _play[(i + 1) % _play.size()]).distance_to(h))
		if not inside:
			n = "Außerhalb des Spielbereichs – zurückgehen oder hier „+ Raum“."
		elif dist < 0.7:
			n = "Grenze des Spielbereichs – weiter geht es mit „+ Raum“."
	if n != _edge_note:
		_edge_note = n
		_update_toolbox()


# ------------------------------------------------------------------ drawing
func _build_cursor() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.06
	ring.outer_radius = 0.09
	ring.rings = 24
	ring.ring_segments = 4
	_ring.mesh = ring
	_ring.scale = Vector3(1, 0.15, 1)
	_ring.material_override = _unshaded(WALL)
	add_child(_ring)
	_preview.mesh = _preview_mesh
	_preview.material_override = _unshaded(Color.WHITE, true)
	add_child(_preview)
	_laser.mesh = _laser_mesh
	_laser.material_override = _unshaded(Color.WHITE, true)
	add_child(_laser)
	_label.font_size = 40
	_label.pixel_size = 0.004
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)


static func _unshaded(c: Color, vertex := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.vertex_color_use_as_albedo = vertex
	m.no_depth_test = true
	m.render_priority = 5
	return m


static func _line(im: ImmediateMesh, pts: Array, c: Color) -> void:
	if pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	im.surface_set_color(c)
	for p in pts:
		im.surface_add_vertex(p)
	im.surface_end()


func _box_lines(im: ImmediateMesh, corners: Array, h: float, c: Color, base := 0.0) -> void:
	var lo: Array = []
	var hi: Array = []
	for q in corners:
		lo.append(_v3(q, base + 0.01))
		hi.append(_v3(q, base + h))
	_line(im, lo + [lo[0]], c)
	if h > 0.02:
		_line(im, hi + [hi[0]], c)
		for k in 4:
			_line(im, [lo[k], hi[k]], c)


func _rebuild() -> void:
	for c in _drawn.get_children():
		c.queue_free()
	var lines := ImmediateMesh.new()
	var fill := SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var alpha := 1.0 if model_view else 0.22
	var sel_wall: int = selected[1] if _sel_valid() and selected[0] == "wall" else -1
	var sel_obj: int = selected[1] if _sel_valid() and selected[0] == "object" else -1
	var sel_open: int = selected[1] if _sel_valid() and selected[0] == "opening" else -1
	for i in walls.size():
		var w: Dictionary = walls[i]
		var ly := float(levels[int(w.level)].y)
		var other := int(w.level) != lv
		var h := _wall_h(w)
		var railing: bool = w.get("kind", "") == "railing"
		var col := _mat_color(w.get("mat", ""), WALL if not model_view else Color("2a2b30"))
		var base_col := LINK if railing else WALL
		var line_col := SEL if i == sel_wall else (Color(base_col, 0.35) if other else base_col)
		var pts := _wall_points(w)
		var a_alpha := alpha * (0.4 if other else 1.0)
		if w.has("via"):
			for k in pts.size() - 1:
				count += _quad(fill, pts[k], pts[k + 1], ly, ly + h, col, a_alpha)
		else:
			var gaps: Array = []
			var len: float = w.a.distance_to(w.b)
			for k in openings.size():
				var op: Dictionary = openings[k]
				if int(op.wall) == i and len > 0:
					var half := float(op.w) / 2.0 / len
					gaps.append([clampf(float(op.t) - half, 0, 1), clampf(float(op.t) + half, 0, 1), float(op.sill), float(op.sill) + float(op.h), op.has("link"), k == sel_open])
			gaps.sort_custom(func(p, q): return p[0] < q[0])
			var t := 0.0
			for g in gaps:
				count += _quad(fill, w.a.lerp(w.b, t), w.a.lerp(w.b, g[0]), ly, ly + h, col, a_alpha)
				count += _quad(fill, w.a.lerp(w.b, g[0]), w.a.lerp(w.b, g[1]), ly, ly + g[2], col, a_alpha)
				count += _quad(fill, w.a.lerp(w.b, g[0]), w.a.lerp(w.b, g[1]), ly + minf(g[3], h), ly + h, col, a_alpha)
				var p0: Vector2 = w.a.lerp(w.b, g[0])
				var p1: Vector2 = w.a.lerp(w.b, g[1])
				var oc: Color = SEL if g[5] else (LINK if g[4] else OPEN)
				_line(lines, [Vector3(p0.x, ly + g[2], p0.y), Vector3(p0.x, ly + g[3], p0.y), Vector3(p1.x, ly + g[3], p1.y),
					Vector3(p1.x, ly + g[2], p1.y), Vector3(p0.x, ly + g[2], p0.y)], oc)
				t = g[1]
			count += _quad(fill, w.a.lerp(w.b, t), w.b, ly, ly + h, col, a_alpha)
		var base: Array = []
		var top: Array = []
		for q in pts:
			base.append(Vector3(q.x, ly + 0.01, q.y))
			top.append(Vector3(q.x, ly + h, q.y))
		_line(lines, base, line_col)
		_line(lines, top, Color(line_col, 0.6))
		if not other:
			var mid: Vector2 = pts[pts.size() / 2] if w.has("via") else (w.a + w.b) / 2.0
			_drawn.add_child(_tag(Vector3(mid.x, ly + 0.35, mid.y), _m(_wall_len(w)), line_col))
			for q in [w.a, w.b]:
				var dot := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.05
				sm.height = 0.1
				dot.mesh = sm
				dot.material_override = _unshaded(SEL)
				dot.position = Vector3(q.x, ly + 0.02, q.y)
				_drawn.add_child(dot)
	for i in objects.size():
		var o: Dictionary = objects[i]
		var ly := float(levels[int(o.level)].y)
		var other := int(o.level) != lv
		var c := Vector2(o.c[0], o.c[1])
		var ang := float(o.angle)
		var hw := float(o.w) / 2.0
		var hd := float(o.d) / 2.0
		var h := _obj_h(o)
		var y0 := ly + _obj_base(o)
		var col := _mat_color(o.get("mat", ""), OBJ)
		var cs: Array = []
		if o.type == "slab" and o.has("pts"):
			for q in o.pts:
				cs.append(c + Vector2(q[0], q[1]).rotated(ang))
		else:
			for q in [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)]:
				cs.append(c + q.rotated(ang))
		var a_alpha := alpha * (0.4 if other else 1.0)
		if o.type == "stairs":
			var n := maxi(1, roundi(h / 0.18))
			var up := Vector2.from_angle(ang + PI / 2)
			var across := Vector2.from_angle(ang) * hw
			for k in n:
				var m0: Vector2 = c - up * hd + up * (2.0 * hd) * float(k) / n
				var m1: Vector2 = c - up * hd + up * (2.0 * hd) * float(k + 1) / n
				var yy := y0 + h * (float(k) + 1.0) / n
				count += _flat(fill, [m0 - across, m1 - across, m1 + across, m0 + across], yy, col, a_alpha)
				count += _quad(fill, m0 - across, m0 + across, y0 + h * float(k) / n, yy, col, a_alpha)
		else:
			for k in cs.size():
				count += _quad(fill, cs[k], cs[(k + 1) % cs.size()], y0, y0 + h, col, a_alpha)
			count += _flat_poly(fill, cs, y0 + h, col, a_alpha)
			if o.type == "slab":
				count += _flat_poly(fill, cs, y0, col, a_alpha)
		var top: Array = []
		for q in cs:
			top.append(Vector3(q.x, y0 + h, q.y))
		top.append(top[0])
		var lc := SEL if i == sel_obj else (Color(OBJ, 0.35) if other else OBJ)
		_line(lines, top, lc)
		if not other:
			_drawn.add_child(_tag(Vector3(c.x, y0 + h + 0.2, c.y), _obj_name(o), lc))
	# Finished rooms in the same coordinates: faint outlines.
	for r in rooms:
		if int(r.get("frame", 0)) != frame:
			continue
		var rl: Array = r.get("levels", levels)
		for w in _vec(r.get("walls", [])):
			var ly := float(rl[mini(int(w.level), rl.size() - 1)].y) if not rl.is_empty() else 0.0
			var gp: Array = []
			for q in _wall_points(w):
				gp.append(Vector3(q.x, ly + 0.01, q.y))
			_line(lines, gp, Color(WALL, 0.3))
	# Floors of the storeys: in the model view in their material, else only when painted.
	for i in levels.size():
		var l: Dictionary = levels[i]
		var pts: Array = []
		for w in walls:
			if int(w.level) == i:
				pts.append_array(_wall_points(w))
		if pts.size() < 3:
			continue
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in pts:
			var r: Vector2 = (q as Vector2).rotated(-grid)
			lo = lo.min(r)
			hi = hi.max(r)
		var fl: Array = []
		for q in [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]:
			fl.append(q.rotated(grid))
		if model_view or l.floor != "":
			count += _flat(fill, fl, float(l.y) + 0.005, _mat_color(l.floor, Color("17171b")), alpha * (0.5 if i != lv else 1.0))
		if model_view and l.ceiling != "":
			count += _flat(fill, fl, float(l.y) + float(l.height), _mat_color(l.ceiling, Color("0c0c0e")), alpha)
	# Play area on the floor.
	var pa := ImmediateMesh.new()
	if _play.size() >= 3:
		var ring: Array = []
		for v in _play:
			ring.append(Vector3(v.x, float(levels[0].y) + 0.005, v.y))
		ring.append(ring[0])
		_line(pa, ring, PLAY)
	_play_node.mesh = pa
	_play_node.material_override = _unshaded(Color.WHITE, true)
	if count > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = fill.commit()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if not model_view:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		_drawn.add_child(mi)
	var li := MeshInstance3D.new()
	li.mesh = lines
	li.material_override = _unshaded(Color.WHITE, true)
	_drawn.add_child(li)


static func _quad(st: SurfaceTool, a: Vector2, b: Vector2, y0: float, y1: float, c: Color, alpha: float) -> int:
	if a.distance_to(b) < 0.005 or y1 - y0 < 0.005:
		return 0
	# A little shading by direction, so walls stand apart in the model view.
	var n := Vector2(-(b.y - a.y), b.x - a.x).normalized()
	var shade := 0.75 + 0.25 * absf(n.dot(Vector2(0.6, 0.8)))
	st.set_color(Color(c.r * shade, c.g * shade, c.b * shade, alpha))
	var v := [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(v[k])
	return 1


## Any (also concave) outline: triangulated.
static func _flat_poly(st: SurfaceTool, pts: Array, y: float, c: Color, alpha: float) -> int:
	if pts.size() < 3:
		return 0
	var poly := PackedVector2Array()
	for q in pts:
		poly.append(q)
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return _flat(st, pts, y, c, alpha)
	st.set_color(Color(c, alpha))
	for k in idx:
		st.add_vertex(Vector3(poly[k].x, y, poly[k].y))
	return 1


static func _flat(st: SurfaceTool, pts: Array, y: float, c: Color, alpha: float) -> int:
	if pts.size() < 3:
		return 0
	st.set_color(Color(c, alpha))
	for k in range(1, pts.size() - 1):
		for q in [pts[0], pts[k], pts[k + 1]]:
			st.add_vertex(Vector3(q.x, y, q.y))
	return 1


func _tag(at: Vector3, text: String, c: Color) -> Label3D:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = 36
	lb.pixel_size = 0.004
	lb.modulate = c
	lb.outline_size = 8
	lb.outline_modulate = Color(0, 0, 0, 0.8)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.position = at
	return lb


# ------------------------------------------------------------------ desktop example
## An example club as if drawn in the headset: L-shaped hall with a curved corner, double door,
## window band, a passage, furniture, stairs up to a gallery storey (OG 1 at 3.2 m).
func _fake_club() -> void:
	var rot := deg_to_rad(12.0)
	var off := Vector2(1.5, 0.8)
	var tr := func(x: float, z: float) -> Vector2:
		return Vector2(x, z).rotated(rot) + off
	grid = rot
	has_grid = true
	levels = [_level("EG", 0.0, 4.5), _level("OG 1", 3.2, 3.0)]
	var outline := [Vector2(-7, -5), Vector2(7, -5), Vector2(7, 2), Vector2(3, 2), Vector2(3, 5), Vector2(-5, 5)]
	for i in outline.size() - 1:
		walls.append({ "level": 0, "a": tr.call(outline[i].x, outline[i].y), "b": tr.call(outline[i + 1].x, outline[i + 1].y), "mat": "velvet-violet" if i == 0 else "" })
	# Curved corner from (-5, 5) to (-7, -5), bulging out.
	walls.append({ "level": 0, "a": tr.call(-5, 5), "b": tr.call(-7, -5), "via": tr.call(-8.2, 0.5), "mat": "concrete" })
	openings.append({ "wall": 4, "t": 0.5, "w": 1.6, "h": 2.1, "sill": 0.0, "kind": "double" })
	openings.append({ "wall": 1, "t": 0.4, "w": 1.2, "h": 2.2, "sill": 0.0, "kind": "passage", "link": 1 })
	openings.append({ "wall": 2, "t": 0.5, "w": 3.0, "h": 1.0, "sill": 1.1, "kind": "band" })
	next_link = 2
	var obj := func(type: String, x: float, z: float, w: float, d: float, h: float, mat: String, level := 0) -> Dictionary:
		var c: Vector2 = tr.call(x, z)
		return { "level": level, "type": type, "c": [_r(c.x), _r(c.y)], "w": w, "d": d, "angle": rot, "h": h, "mat": mat }
	objects.append(obj.call("bar", -3.0, 4.2, 4.0, 0.8, 1.1, "black"))
	objects.append(obj.call("stage", 0.0, -3.6, 6.0, 2.6, 0.6, "black"))
	objects.append(obj.call("djbooth", 0.0, -3.7, 2.4, 1.0, 1.05, "black"))
	objects.append(obj.call("pillar", -2.0, 0.5, 0.5, 0.5, 0.0, "concrete"))
	objects.append(obj.call("ledwall", 0.0, -4.85, 5.0, 0.15, 3.0, "led"))
	# L-shaped stairs with a landing at 1.6 m up to the gallery (OG 1 at 3.2 m).
	objects.append(obj.call("podest", 5.6, 1.4, 1.4, 1.4, 1.6, "concrete"))
	var st1: Dictionary = obj.call("stairs", 3.9, 1.4, 1.2, 2.4, 1.6, "concrete")
	st1.angle = rot - PI / 2         # uphill towards +x (to the landing)
	objects.append(st1)
	var st2: Dictionary = obj.call("stairs", 5.6, -0.6, 1.2, 2.6, 1.6, "concrete")
	st2.angle = rot + PI             # uphill towards −z (to the gallery)
	st2.base = 1.6
	objects.append(st2)
	# OG 1: a curved gallery along the right side and the back, glass railing on its open edge.
	var gal := [Vector2(2.4, -5), Vector2(7, -5), Vector2(7, -1.9), Vector2(5.0, -1.9), Vector2(4.2, -2.3), Vector2(3.4, -3.0), Vector2(2.8, -3.8)]
	var g0: Array = []
	for q in gal:
		g0.append(tr.call(q.x, q.y))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in g0:
		lo = lo.min(q.rotated(-rot))
		hi = hi.max(q.rotated(-rot))
	var gc: Vector2 = ((lo + hi) / 2.0).rotated(rot)
	var pts: Array = []
	for q in g0:
		var r: Vector2 = (q - gc).rotated(-rot)
		pts.append([_r(r.x), _r(r.y)])
	objects.append({ "level": 1, "type": "slab", "c": [_r(gc.x), _r(gc.y)], "w": _r(hi.x - lo.x), "d": _r(hi.y - lo.y), "angle": rot,
		"h": 0.3, "base": -0.3, "mat": "concrete", "pts": pts })
	for k in range(3, gal.size()):
		var a2: Vector2 = tr.call(gal[k].x, gal[k].y)
		var b2: Vector2 = tr.call(gal[(k + 1) % gal.size()].x, gal[(k + 1) % gal.size()].y)
		walls.append({ "level": 1, "a": a2, "b": b2, "mat": "glass", "h": 1.1, "kind": "railing" })
	walls.append({ "level": 1, "a": tr.call(5.0, -1.9), "b": tr.call(5.6, -1.9), "mat": "glass", "h": 1.1, "kind": "railing" })
	objects.append(obj.call("bar", 5.6, -4.6, 2.4, 0.6, 1.1, "black", 1))
	levels[0].floor = "marble"
