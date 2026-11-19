# Background music after the start animation, on the start screen and in shows without a computer
# (in Live the music plays in the real room). The track fades out at its end, so it loops with a
# short crossfade: the next round starts while the last one rings out.
# Track: „Chill Out“ by atlasaudio, Pixabay (Pixabay Content License, see THIRD_PARTY.md). The file is
# not in the source repository (the licence does not allow passing it on by itself) – it is in the
# released app; for own builds see README. Without it VD VR simply plays no music.
extends Node

const TRACK_PATH := "res://music/atlasaudio-chill-out-621545.mp3"
## The track's own fade-out starts here (measured: level falls after 96.5 s).
const LOOP_AT := 96.5
## Below the start animation and quiet enough to talk over.
const BASE_DB := -2.0

## 0…1 from the settings.
var volume := 0.6
var _players: Array = []
var _gain := [0.0, 0.0]
var _cur := 0
var _level := 0.0
var _want := false
var _fade := 2.0


func _ready() -> void:
	var track: AudioStream = load(TRACK_PATH) if ResourceLoader.exists(TRACK_PATH) else null
	if track == null:
		return
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.stream = track
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


## Fades in over `fade` seconds (continues where it was if still playing).
func play(fade := 2.0) -> void:
	_fade = maxf(fade, 0.05)
	if _players.is_empty():
		return
	if _want:
		return
	_want = true
	var p: AudioStreamPlayer = _players[_cur]
	if not p.playing:
		_gain[_cur] = 1.0
		p.play()


func stop(fade := 1.5) -> void:
	_fade = maxf(fade, 0.05)
	_want = false


func _process(dt: float) -> void:
	if _players.is_empty():
		return
	_level = move_toward(_level, 1.0 if _want else 0.0, dt / _fade)
	var p: AudioStreamPlayer = _players[_cur]
	if _want and p.playing and p.get_playback_position() >= LOOP_AT:
		# Next round from the start, faded in quickly; the old one rings out on its own.
		_cur = 1 - _cur
		_gain[_cur] = 0.0
		_players[_cur].play()
	for i in 2:
		var q: AudioStreamPlayer = _players[i]
		if i == _cur:
			_gain[i] = move_toward(_gain[i], 1.0, dt / 0.6)
		if not q.playing:
			continue
		var g: float = volume * _level * _gain[i]
		q.volume_db = BASE_DB + linear_to_db(maxf(g, 0.00001))
		if _level <= 0.0:
			q.stop()
