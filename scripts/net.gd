# Connection to the VD-Link VR server (electron/vr-server.ts) – same protocol as the
# browser viewer, plus `?frame=1`: ready-made beams and surface spots per frame, so the
# headset only draws (no DMX decoding or fixture logic in the app).
#   GET  <base>api/scene       project, lamp definitions and the room as location (`loc`)
#   SSE  <base>api/events      scene / view / walls / frame / record
#   GET  <base>api/wall/<i>.jpg  picture of screen i (walls.gd)
#   GET  <base>api/gobos.png   gobo atlas (tile layout in X-Gobo-Cols / X-Gobo-Rows)
#   POST <base>api/pose        where the headset is (shown in VD-Link)
#   POST <base>api/log         text lines, written to userData/vr-log.txt on the computer
#   GET  <base>api/world.vdworld  the open project as a world to walk without a computer (event `world`)
#   POST <base>api/world-status  how loading the world goes (VD-Link shows it in the VR menu)
#   POST <base>api/scan        a club scan (scan.gd) – VD-Link builds a location from it
#   POST <base>api/scan-live   the club studio's drawing while you draw (VD-Link follows it live)
#   UDP  broadcast „VDM?“ to port 7702 → VD-Link answers {app, name, port}
extends Node

signal scene_received(data: Dictionary)
signal scene_changed
signal frame_received(floats: PackedFloat32Array)
signal view_received(view: Dictionary)
signal walls_received(walls: Array)
signal status_changed(text: String, ok: bool)
signal gobos_received(png: PackedByteArray, cols: int, rows: int)
## VD-Link asks to save the running show on the headset (VERBINDEN → VR-Brille).
signal record_requested(seconds: float)
## Computers with VD-Link found in the network: [{name, ip, port}]
signal found_changed(list: Array)
## The room as VD-Link draws it (GET api/venue.bin, "VDV1"), see venue_mesh.gd.
signal venue_received(bytes: PackedByteArray)
## VD-Link puts this headset somewhere (VR menu „Hierher holen“): feet position, view yaw (rad).
signal goto_requested(pos: Vector3, yaw: float)
## VD-Link sends the open project as a world (VR menu „Welt auf Brillen übertragen“).
signal world_offered
## The world download ended: file in user:// ("" if it failed).
signal world_downloaded(path: String)

const WORLD_FILE := "user://incoming.vdworld"
## A club scan reached VD-Link (or not).
signal scan_sent(ok: bool)
## A live update of the club studio reached VD-Link (or not).
signal live_sent(ok: bool)


const DISCOVERY_PORT := 7702

var base := ""          # e.g. https://192.168.1.20:7701/7512/
var enabled := false
var _host := ""
var _port := 0
var _tls: TLSOptions = null
var _path := ""

var _sse := HTTPClient.new()
var _sse_bytes := PackedByteArray()
var _sse_requested := false
var _retry_at := 0.0
var connected := false
## The last scene request failed because of the code (VD-Link answers with its code page).
var wrong_code := false
var has_scene := false
var _log_lines: PackedStringArray = []
var _log_req := HTTPRequest.new()
var _scene_req := HTTPRequest.new()
var _gobo_req := HTTPRequest.new()
var _venue_req := HTTPRequest.new()
var _log_busy := false
var _pose_req := HTTPRequest.new()
var _pose_busy := false
var _pose_at := 0
var _scene_retry: SceneTreeTimer = null
## Stays the same for this installation, so VD-Link keeps one marker per headset.
var device_id := ""
var device_name := ""
var frames_in := 0
var last_frame_ms := 0
var _last_st := -1

var _world_req := HTTPRequest.new()
var _scan_req := HTTPRequest.new()
var _live_req := HTTPRequest.new()
var live_busy := false
var _status_req := HTTPRequest.new()
## The world is being downloaded, and how far (0…1).
var world_loading := false
var world_progress := 0.0
## Name of the world being loaded or just saved (for the status in VD-Link).
var world_name := ""
var _world_report_at := 0

var _udp: PacketPeerUDP = null
var _discover_until := 0
var _discover_next := 0
var found: Array = []


func _ready() -> void:
	for r in [_log_req, _pose_req, _scene_req, _gobo_req, _venue_req]:
		r.timeout = 8.0
		add_child(r)
	_venue_req.timeout = 30.0
	_venue_req.accept_gzip = true
	_venue_req.request_completed.connect(_on_venue)
	_log_req.request_completed.connect(func(_r, _c, _h, _b): _log_busy = false)
	_pose_req.request_completed.connect(func(_r, _c, _h, _b): _pose_busy = false)
	_scene_req.request_completed.connect(_on_scene)
	_gobo_req.request_completed.connect(_on_gobos)
	for r in [_world_req, _status_req]:
		r.timeout = 10.0
		add_child(r)
	_world_req.timeout = 120.0
	_world_req.use_threads = true
	_world_req.download_file = WORLD_FILE
	_world_req.request_completed.connect(_on_world)
	_scan_req.timeout = 30.0
	add_child(_scan_req)
	_live_req.timeout = 6.0
	add_child(_live_req)
	_live_req.request_completed.connect(func(r, c, _h, _b):
		live_busy = false
		live_sent.emit(r == HTTPRequest.RESULT_SUCCESS and c == 204))
	_scan_req.request_completed.connect(func(r, c, _h, _b): scan_sent.emit(r == HTTPRequest.RESULT_SUCCESS and c == 204))
	_load_device_id()


## Connect to VD-Link (address with code, e.g. https://192.168.1.20:7701/1234/).
func start(url: String) -> void:
	stop()
	base = url if url.ends_with("/") else url + "/"
	var u := base
	var https := u.begins_with("https://")
	u = u.trim_prefix("https://").trim_prefix("http://")
	var slash := u.find("/")
	var hostport := u.substr(0, slash)
	_path = u.substr(slash)
	var colon := hostport.rfind(":")
	_host = hostport.substr(0, colon) if colon > 0 else hostport
	_port = int(hostport.substr(colon + 1)) if colon > 0 else (443 if https else 80)
	# VD-Link makes its own certificate – accept it (local network only, code-protected).
	_tls = TLSOptions.client_unsafe() if https else null
	if _tls:
		for r in [_log_req, _pose_req, _scene_req, _gobo_req, _venue_req, _world_req, _status_req]:
			r.set_tls_options(_tls)
	enabled = true
	wrong_code = false
	load_scene()


## Disconnect (scenario or demo playing, or a different computer chosen).
func stop() -> void:
	enabled = false
	connected = false
	has_scene = false
	_host = ""
	_sse.close()
	_sse_bytes = PackedByteArray()
	_sse_requested = false
	for r in [_scene_req, _gobo_req, _pose_req, _venue_req]:
		r.cancel_request()
	_pose_busy = false
	if world_loading:
		_world_req.cancel_request()
		world_loading = false
		world_downloaded.emit("")


func load_scene() -> void:
	if not enabled:
		return
	status_changed.emit("Lade Szene …", true)
	_scene_req.cancel_request()
	if _scene_req.request(base + "api/scene") != OK:
		_retry_scene()


func _retry_scene() -> void:
	if enabled:
		get_tree().create_timer(2.0).timeout.connect(load_scene)


func _on_scene(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if not enabled:
		return
	# Wrong code: VD-Link answers with its HTML code page (404).
	var html := " ".join(headers).to_lower().contains("text/html")
	if result == HTTPRequest.RESULT_SUCCESS and html:
		wrong_code = true
		status_changed.emit("Code stimmt nicht", false)
		stop()
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		var why := "VD-Link hat kein Projekt offen" if code == 503 else "VD-Link nicht erreichbar"
		status_changed.emit(why + " – neuer Versuch …", false)
		_retry_scene()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		status_changed.emit("Szene nicht lesbar", false)
		return
	has_scene = true
	scene_received.emit(data)
	_gobo_req.cancel_request()
	_gobo_req.request(base + "api/gobos.png")
	load_venue()


## Room geometry (VD-Link 0.5+; older versions answer 404, then VD VR builds the room itself).
func load_venue() -> void:
	if not enabled:
		return
	_venue_req.cancel_request()
	_venue_req.request(base + "api/venue.bin")


func _on_venue(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not enabled or result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		return
	venue_received.emit(body)


func _on_gobos(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		return
	var cols := 0
	var rows := 0
	for h in headers:
		var l := h.to_lower()
		if l.begins_with("x-gobo-cols:"):
			cols = int(h.substr(12).strip_edges())
		elif l.begins_with("x-gobo-rows:"):
			rows = int(h.substr(12).strip_edges())
	if cols > 0 and rows > 0:
		gobos_received.emit(body, cols, rows)


func _load_device_id() -> void:
	var f := "user://device.txt"
	if FileAccess.file_exists(f):
		device_id = FileAccess.get_file_as_string(f).strip_edges()
	if device_id == "":
		device_id = "%08x" % (randi() & 0x7fffffff)
		var w := FileAccess.open(f, FileAccess.WRITE)
		if w:
			w.store_string(device_id)
	var model := OS.get_model_name()
	device_name = "VD VR " + ("Pico 4 Ultra" if model.begins_with("A92") else model)


## Where the headset is and where it looks – VD-Link shows it in its 3D view (~10×/s).
func send_pose(xf: Transform3D) -> void:
	var now := Time.get_ticks_msec()
	if not connected or _pose_busy or now - _pose_at < 100:
		return
	_pose_at = now
	var q := xf.basis.get_rotation_quaternion()
	var body := JSON.stringify({ "id": device_id, "name": device_name, "pos": [xf.origin.x, xf.origin.y, xf.origin.z], "quat": [q.x, q.y, q.z, q.w] })
	_pose_busy = true
	if _pose_req.request(base + "api/pose", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body) != OK:
		_pose_busy = false


func log_line(text: String) -> void:
	print("vdm: ", text)
	_log_lines.append("%s %s" % [Time.get_time_string_from_system(), text])
	if _log_lines.size() > 200:
		_log_lines = _log_lines.slice(-200)


func _process(_dt: float) -> void:
	_poll_sse()
	_poll_discovery()
	_poll_world()
	if connected and _log_lines.size() and not _log_busy:
		_log_busy = true
		var body := "\n".join(_log_lines)
		_log_lines.clear()
		if _log_req.request(base + "api/log", PackedStringArray(["Content-Type: text/plain"]), HTTPClient.METHOD_POST, body) != OK:
			_log_busy = false


# ------------------------------------------------------------------ world (walk without a computer)
## Download the open project as a world into user://incoming.vdworld.
func download_world(name: String) -> bool:
	if not enabled or world_loading:
		return false
	world_loading = true
	world_progress = 0.0
	world_name = name
	if _world_req.request(base + "api/world.vdworld") != OK:
		world_loading = false
		return false
	report_world("loading")
	return true


func _poll_world() -> void:
	if not world_loading:
		return
	var size := _world_req.get_body_size()
	if size > 0:
		world_progress = clampf(float(_world_req.get_downloaded_bytes()) / size, 0.0, 1.0)
	var now := Time.get_ticks_msec()
	if now - _world_report_at > 700:
		_world_report_at = now
		report_world("loading")


func _on_world(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	if not world_loading:
		return
	world_loading = false
	world_downloaded.emit(WORLD_FILE if result == HTTPRequest.RESULT_SUCCESS and code == 200 else "")


## How loading the world goes: "loading" | "saved" | "failed" (VD-Link lists it per headset).
func report_world(state: String) -> void:
	if not enabled:
		return
	var body := JSON.stringify({ "headset": device_name, "name": world_name, "state": state, "progress": 1.0 if state == "saved" else world_progress })
	_status_req.cancel_request()
	_status_req.request(base + "api/world-status", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)


# ------------------------------------------------------------------ club scan
## Sends a scan to VD-Link at `url` (address with code) – works without a live connection.
func send_scan(url: String, json: String) -> bool:
	var u := url if url.ends_with("/") else url + "/"
	_scan_req.cancel_request()
	_scan_req.set_tls_options(TLSOptions.client_unsafe() if u.begins_with("https://") else TLSOptions.client())
	return _scan_req.request(u + "api/scan", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, json) == OK


## Live update of the club studio (one at a time; returns false while the last one is on its way).
func send_scan_live(url: String, json: String) -> bool:
	if live_busy:
		return false
	var u := url if url.ends_with("/") else url + "/"
	_live_req.set_tls_options(TLSOptions.client_unsafe() if u.begins_with("https://") else TLSOptions.client())
	live_busy = _live_req.request(u + "api/scan-live", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, json) == OK
	return live_busy


# ------------------------------------------------------------------ finding VD-Link
## Ask the network for VD-Link for `seconds` (broadcast every second).
func discover(seconds := 6.0) -> void:
	if _udp == null:
		_udp = PacketPeerUDP.new()
		_udp.set_broadcast_enabled(true)
		if _udp.bind(0) != OK:
			_udp = null
			return
	found.clear()
	found_changed.emit(found)
	_discover_until = Time.get_ticks_msec() + int(seconds * 1000)
	_discover_next = 0


func is_discovering() -> bool:
	return Time.get_ticks_msec() < _discover_until


func _poll_discovery() -> void:
	if _udp == null:
		return
	var now := Time.get_ticks_msec()
	if now < _discover_until and now >= _discover_next:
		_discover_next = now + 1000
		_udp.set_dest_address("255.255.255.255", DISCOVERY_PORT)
		_udp.put_packet("VDM?".to_utf8_buffer())
	while _udp.get_available_packet_count() > 0:
		var pkt := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		var j = JSON.parse_string(pkt.get_string_from_utf8())
		if typeof(j) != TYPE_DICTIONARY or j.get("app", "") != "VD-Link":
			continue
		if found.any(func(f): return f.ip == ip):
			continue
		found.append({ "name": String(j.get("name", ip)).left(40), "ip": ip, "port": int(j.get("port", 7701)) })
		found_changed.emit(found)


# ------------------------------------------------------------------ server-sent events
func _poll_sse() -> void:
	if not enabled or _host == "" or not has_scene:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var st := _sse.get_status()
	if st == HTTPClient.STATUS_DISCONNECTED or st == HTTPClient.STATUS_CONNECTION_ERROR or st == HTTPClient.STATUS_CANT_CONNECT or st == HTTPClient.STATUS_CANT_RESOLVE or st == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
		if connected:
			connected = false
			status_changed.emit("Verbindung zu VD-Link unterbrochen – verbinde neu …", false)
		if now < _retry_at:
			return
		_retry_at = now + 2.0
		_sse_requested = false
		_sse_bytes = PackedByteArray()
		_sse.close()
		_sse.connect_to_host(_host, _port, _tls)
		return
	_sse.poll()
	st = _sse.get_status()
	if OS.has_feature("editor") and st != _last_st:
		_last_st = st
		print("sse status ", st)
	if st == HTTPClient.STATUS_CONNECTED and not _sse_requested:
		_sse_requested = true
		_sse.request(HTTPClient.METHOD_GET, _path + "api/events?frame=1", PackedStringArray(["Accept: text/event-stream"]))
		return
	if st == HTTPClient.STATUS_BODY:
		if not connected:
			connected = true
			status_changed.emit("Live von VD-Link", true)
		# Read everything that arrived this frame (bytes; text only per finished event).
		for _i in 256:
			var chunk := _sse.read_response_body_chunk()
			if chunk.is_empty():
				break
			_sse_bytes.append_array(chunk)
		_parse_events()


func _parse_events() -> void:
	# Events are separated by an empty line (\n\n = 10, 10). Only the newest beam frame of
	# this batch is decoded – older ones would be drawn over in the same frame anyway.
	var latest_frame := ""
	var start := 0
	var n := _sse_bytes.size()
	while true:
		# Native byte search: newlines are rare (base64 data has none).
		var end := -1
		var i := _sse_bytes.find(10, start)
		while i >= 0 and i < n - 1:
			if _sse_bytes[i + 1] == 10:
				end = i
				break
			i = _sse_bytes.find(10, i + 1)
		if end < 0:
			break
		var block := _sse_bytes.slice(start, end).get_string_from_utf8()
		start = end + 2
		var ev := "message"
		var data := ""
		for line in block.split("\n"):
			if line.begins_with("event:"):
				ev = line.substr(6).strip_edges()
			elif line.begins_with("data:"):
				data += line.substr(5).strip_edges()
		match ev:
			"frame":
				frames_in += 1
				latest_frame = data
			"scene":
				scene_changed.emit()
			"view":
				var v = JSON.parse_string(data)
				if typeof(v) == TYPE_DICTIONARY:
					view_received.emit(v)
			"venue":
				load_venue()
			"goto":
				var g = JSON.parse_string(data)
				if typeof(g) == TYPE_DICTIONARY and typeof(g.get("pos")) == TYPE_ARRAY and g.pos.size() == 3:
					var who = g.get("id")
					if who == null or String(who).ends_with("#" + device_id):
						goto_requested.emit(Vector3(float(g.pos[0]), float(g.pos[1]), float(g.pos[2])), deg_to_rad(float(g.get("yaw", 0.0))))
			"world":
				var o = JSON.parse_string(data)
				if typeof(o) == TYPE_DICTIONARY:
					var who = o.get("to")
					if who == null or String(who).ends_with("#" + device_id):
						world_offered.emit()
			"record":
				var r = JSON.parse_string(data)
				if typeof(r) == TYPE_DICTIONARY:
					record_requested.emit(clampf(float(r.get("seconds", 60)), 5.0, 300.0))
			"walls":
				var w = JSON.parse_string(data)
				if typeof(w) == TYPE_ARRAY:
					walls_received.emit(w)
	if start > 0:
		_sse_bytes = _sse_bytes.slice(start)
	if latest_frame != "":
		last_frame_ms = Time.get_ticks_msec()
		frame_received.emit(Marshalls.base64_to_raw(latest_frame).to_float32_array())
