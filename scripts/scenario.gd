# Scenarios on the headset: a recorded piece of a VD-Link show that plays without a computer.
#   <dir>/meta.json   {name, created, duration, walls: [states], view, gobo_cols, gobo_rows}
#   <dir>/scene.json  the scene as VD-Link sent it (api/scene)
#   <dir>/frames.bin  zstd: per frame float32 t, int32 n, n × float32 (frame layout of `frame`)
#   <dir>/walls.bin   per picture int32 screen, float32 t, int32 len, JPEG bytes
#   <dir>/gobos.bin   gobo atlas (PNG bytes)
#   <dir>/venue.bin   the room as VD-Link draws it ("VDV1", venue_mesh.gd) – optional
# Saved scenarios live in user://scenarios/<id>/, the demo ships in res://demo/. A world from VD-Link
# (api/world.vdworld: the open project with the light of one moment) is unpacked into the same layout
# with a single frame – nothing plays, you walk around in it (meta.world = true).
extends Node

signal scene_received(data: Dictionary)
signal frame_received(floats: PackedFloat32Array)
signal walls_received(walls: Array)
signal view_received(view: Dictionary)
signal gobos_received(png: PackedByteArray, cols: int, rows: int)
signal venue_received(bytes: PackedByteArray)
signal picture(i: int, jpeg: PackedByteArray)
signal recording_done(ok: bool, name: String)

const ROOT := "user://scenarios/"
const REC_FPS := 30.0
const REC_WALL_FPS := 4.0

# ------------------------------------------------------------------ recording
var recording := false
var rec_seconds := 0.0
var rec_length := 60.0
var _rec_dir := ""
var _rec_frames: FileAccess
var _rec_walls: FileAccess
var _rec_t0 := 0
var _rec_last := -1.0
var _rec_wall_last := {}
var _rec_meta := {}


## Start recording `seconds` of the live show; scene, wall states and gobos come along.
func start_recording(scene: Dictionary, walls: Array, view: Dictionary, gobos: PackedByteArray, gcols: int, grows: int, seconds := 60.0, venue := PackedByteArray()) -> bool:
	if recording or scene.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(ROOT)
	var name := String(scene.get("project", {}).get("name", "Show"))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", " ")
	var id := "%s %s" % [name.validate_filename().left(40), stamp]
	_rec_dir = ROOT + id + "/"
	DirAccess.make_dir_recursive_absolute(_rec_dir)
	var f := FileAccess.open(_rec_dir + "scene.json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(scene))
	f.close()
	if not gobos.is_empty():
		var g := FileAccess.open(_rec_dir + "gobos.bin", FileAccess.WRITE)
		g.store_buffer(gobos)
		g.close()
	if not venue.is_empty():
		var v := FileAccess.open(_rec_dir + "venue.bin", FileAccess.WRITE)
		v.store_buffer(venue)
		v.close()
	_rec_frames = FileAccess.open_compressed(_rec_dir + "frames.bin", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	_rec_walls = FileAccess.open(_rec_dir + "walls.bin", FileAccess.WRITE)
	_rec_meta = { "name": "%s · %s" % [name, Time.get_datetime_string_from_system().substr(0, 16).replace("T", " ")], "created": Time.get_unix_time_from_system(),
		"walls": walls, "view": view, "gobo_cols": gcols, "gobo_rows": grows, "version": 1 }
	_rec_t0 = Time.get_ticks_msec()
	_rec_last = -1.0
	_rec_wall_last.clear()
	rec_seconds = 0.0
	rec_length = seconds
	recording = true
	return true


## Leave out dark moments of the show (no beams) – used for the demo recording.
var skip_dark := false
var _dark_since := -1

func record_frame(f: PackedFloat32Array) -> void:
	if not recording:
		return
	if skip_dark:
		var now := Time.get_ticks_msec()
		if f.size() >= 1 and f[0] < 0.5:
			if _dark_since < 0:
				_dark_since = now
			return
		if _dark_since >= 0:
			_rec_t0 += now - _dark_since
			_dark_since = -1
	var t := (Time.get_ticks_msec() - _rec_t0) / 1000.0
	if t - _rec_last < 1.0 / REC_FPS - 0.002:
		return
	_rec_last = t
	_rec_frames.store_float(t)
	_rec_frames.store_32(f.size())
	_rec_frames.store_buffer(f.to_byte_array())
	rec_seconds = t
	if t >= rec_length:
		stop_recording(true)


func record_picture(i: int, jpeg: PackedByteArray) -> void:
	if not recording:
		return
	var t := (Time.get_ticks_msec() - _rec_t0) / 1000.0
	if t - float(_rec_wall_last.get(i, -10.0)) < 1.0 / REC_WALL_FPS:
		return
	_rec_wall_last[i] = t
	_rec_walls.store_32(i)
	_rec_walls.store_float(t)
	_rec_walls.store_32(jpeg.size())
	_rec_walls.store_buffer(jpeg)


func stop_recording(keep: bool) -> void:
	if not recording:
		return
	recording = false
	_rec_frames.close()
	_rec_walls.close()
	if keep and rec_seconds > 2.0:
		_rec_meta.duration = rec_seconds
		var m := FileAccess.open(_rec_dir + "meta.json", FileAccess.WRITE)
		m.store_string(JSON.stringify(_rec_meta))
		m.close()
		recording_done.emit(true, String(_rec_meta.name))
	else:
		_delete_dir(_rec_dir)
		recording_done.emit(false, "")


# ------------------------------------------------------------------ list / delete
## Saved scenarios, newest first: [{id, dir, name, duration}]
func list_saved() -> Array:
	var out: Array = []
	var d := DirAccess.open(ROOT)
	if d == null:
		return out
	for sub in d.get_directories():
		var meta = _read_json(ROOT + sub + "/meta.json")
		if typeof(meta) == TYPE_DICTIONARY:
			out.append({ "id": sub, "dir": ROOT + sub + "/", "name": String(meta.get("name", sub)), "duration": float(meta.get("duration", 0)),
				"created": float(meta.get("created", 0)), "world": bool(meta.get("world", false)) })
	out.sort_custom(func(a, b): return a.created > b.created)
	return out


func delete_saved(dir: String) -> void:
	if dir.begins_with(ROOT):
		_delete_dir(dir)


func _delete_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# ------------------------------------------------------------------ worlds from VD-Link
## Unpacks a .vdworld (electron/vr-server.ts worldPackage) into user://scenarios/welt-<name>/ – the
## same project again replaces its old copy. Returns the folder or "".
func import_world(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 8 or f.get_buffer(4).get_string_from_ascii() != "VDS1":
		return ""
	var n := f.get_32()
	if n <= 0 or n > 16000000:
		return ""
	var h = JSON.parse_string(f.get_buffer(n).get_string_from_utf8())
	if typeof(h) != TYPE_DICTIONARY or h.get("format") != "vd-link-world" or typeof(h.get("parts")) != TYPE_DICTIONARY:
		return ""
	var base := 8 + n
	var parts: Dictionary = h.parts
	var part := func(name: String) -> PackedByteArray:
		var p = parts.get(name)
		if typeof(p) != TYPE_ARRAY or p.size() < 2 or base + int(p[0]) + int(p[1]) > f.get_length():
			return PackedByteArray()
		f.seek(base + int(p[0]))
		return f.get_buffer(int(p[1]))
	var scene: PackedByteArray = part.call("scene")
	if scene.is_empty():
		return ""
	var name := String(h.get("name", "Club"))
	DirAccess.make_dir_recursive_absolute(ROOT)
	var dir := ROOT + "welt-" + name.validate_filename().left(48) + "/"
	_delete_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var files := { "scene.json": scene, "walls.bin": part.call("pics"), "gobos.bin": part.call("gobos"), "venue.bin": part.call("venue") }
	for fname in files:
		var b: PackedByteArray = files[fname]
		if b.is_empty():
			continue
		var w := FileAccess.open(dir + fname, FileAccess.WRITE)
		if w == null:
			_delete_dir(dir)
			return ""
		w.store_buffer(b)
		w.close()
	# The light of that moment, standing still (no frame: dark room, only the room light).
	var frame: PackedByteArray = part.call("frame")
	f.close()
	var fr := FileAccess.open_compressed(dir + "frames.bin", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	fr.store_float(0.0)
	if frame.size() >= 16:
		fr.store_32(frame.size() / 4)
		fr.store_buffer(frame)
	else:
		fr.store_32(4)
		fr.store_buffer(PackedFloat32Array([0, 0, 0, 0]).to_byte_array())
	fr.close()
	var meta := { "name": name, "created": float(h.get("created", Time.get_unix_time_from_system())),
		"duration": 3600.0, "walls": h.get("walls", []), "view": h.get("view", {}),
		"gobo_cols": int(h.get("gobo_cols", 0)), "gobo_rows": int(h.get("gobo_rows", 0)), "version": 1, "world": true }
	var m := FileAccess.open(dir + "meta.json", FileAccess.WRITE)
	m.store_string(JSON.stringify(meta))
	m.close()
	return dir


# ------------------------------------------------------------------ playback
var playing := false
var play_name := ""
## The playing folder is a world from VD-Link (one moment, nothing plays).
var play_world := false
var _times := PackedFloat32Array()
var _frames: Array[PackedFloat32Array] = []
var _pics: Array = []   # [screen, t, bytes]
var _duration := 1.0
var _t := 0.0
var _fi := 0
var _pi := 0


## Load and play a scenario folder in a loop. Returns false if it cannot be read.
func play(dir: String) -> bool:
	stop()
	var meta = _read_json(dir + "meta.json")
	var scene = _read_json(dir + "scene.json")
	if typeof(meta) != TYPE_DICTIONARY or typeof(scene) != TYPE_DICTIONARY:
		return false
	_times = PackedFloat32Array()
	_frames.clear()
	_pics.clear()
	var f := FileAccess.open_compressed(dir + "frames.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	while f.get_position() < f.get_length():
		var t := f.get_float()
		var n := f.get_32()
		if n <= 0 or n > 200000:
			break
		_times.append(t)
		_frames.append(f.get_buffer(n * 4).to_float32_array())
	f.close()
	if _frames.is_empty():
		return false
	var w := FileAccess.open(dir + "walls.bin", FileAccess.READ)
	if w:
		while w.get_position() < w.get_length():
			var i := w.get_32()
			var t := w.get_float()
			var n := w.get_32()
			if n <= 0 or n > 20000000:
				break
			_pics.append([i, t, w.get_buffer(n)])
		w.close()
	_duration = maxf(float(meta.get("duration", _times[_times.size() - 1])), 0.5)
	play_name = String(meta.get("name", "Show"))
	play_world = bool(meta.get("world", false))
	scene_received.emit(scene)
	var walls: Array = meta.get("walls", [])
	walls_received.emit(walls)
	if typeof(meta.get("view")) == TYPE_DICTIONARY:
		view_received.emit(meta.view)
	if FileAccess.file_exists(dir + "gobos.bin"):
		gobos_received.emit(FileAccess.get_file_as_bytes(dir + "gobos.bin"), int(meta.get("gobo_cols", 0)), int(meta.get("gobo_rows", 0)))
	if FileAccess.file_exists(dir + "venue.bin"):
		venue_received.emit(FileAccess.get_file_as_bytes(dir + "venue.bin"))
	_t = 0.0
	_fi = 0
	_pi = 0
	playing = true
	return true


func stop() -> void:
	playing = false
	_frames.clear()
	_pics.clear()


func _process(dt: float) -> void:
	if not playing:
		return
	_t += dt
	if _t >= _duration:
		_t = fmod(_t, _duration)
		_fi = 0
		_pi = 0
	# Newest frame up to now.
	var last := -1
	while _fi < _times.size() and _times[_fi] <= _t:
		last = _fi
		_fi += 1
	if last >= 0:
		frame_received.emit(_frames[last])
	while _pi < _pics.size() and float(_pics[_pi][1]) <= _t:
		picture.emit(int(_pics[_pi][0]), _pics[_pi][2])
		_pi += 1
