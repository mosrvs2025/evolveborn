extends Node
## Pooled one-shots plus a small layered music system. Buses are created in code
## so the project carries no binary bus layout.

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const POOL_2D := 12
const POOL_3D := 16

var _sfx: Dictionary = {}            # name -> AudioStream
var _music: Dictionary = {}
var _pool2: Array[AudioStreamPlayer] = []
var _pool3: Array[AudioStreamPlayer3D] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current := ""
var _fade := 0.0
var _fading := false
var _target_db := -6.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_streams()
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool2.append(p)
	for i in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 6.0
		p3.max_distance = 45.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		_pool3.append(p3)
	_music_a = _make_music_player()
	_music_b = _make_music_player()

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	Settings._apply_audio()

func _load_streams() -> void:
	_sfx = _load_dir(SFX_DIR)
	_music = _load_dir(MUSIC_DIR)

func _load_dir(dir_path: String) -> Dictionary:
	var out := {}
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir():
			var clean := fn.replace(".remap", "").replace(".import", "")
			if clean.get_extension() == "wav" or clean.get_extension() == "ogg":
				var stream = load(dir_path + clean)
				if stream != null:
					out[clean.get_basename()] = stream
		fn = d.get_next()
	d.list_dir_end()
	return out

# --- one-shots ----------------------------------------------------------------

func play(sfx_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s = _sfx.get(sfx_name)
	if s == null:
		return
	for p in _pool2:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return

func play_at(sfx_name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var s = _sfx.get(sfx_name)
	if s == null:
		return
	for p in _pool3:
		if not p.playing:
			p.stream = s
			p.global_position = pos
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	play(sfx_name, volume_db - 6.0, pitch)

## Small random pitch keeps repeated hits from sounding like a machine gun.
func play_varied(sfx_name: String, pos: Vector3, spread := 0.12, volume_db := 0.0) -> void:
	play_at(sfx_name, pos, volume_db, 1.0 + randf_range(-spread, spread))

# --- music --------------------------------------------------------------------

func play_music(track: String, fade_time := 1.6, db := -8.0) -> void:
	if track == _music_current:
		return
	var s = _music.get(track)
	_music_current = track
	_target_db = db
	if s == null:
		_fade_out_all(fade_time)
		return
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if _music_a.playing else _music_b
	# Looping is set at import time (tools/set_audio_import.py); touching it here
	# would break the QOA-compressed streams.
	incoming.stream = s
	incoming.volume_db = -80.0
	incoming.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(incoming, "volume_db", db, fade_time)
	if outgoing.playing:
		t.tween_property(outgoing, "volume_db", -80.0, fade_time)
		t.chain().tween_callback(outgoing.stop)

func _fade_out_all(fade_time := 1.0) -> void:
	for p in [_music_a, _music_b]:
		if p.playing:
			var t := create_tween()
			t.tween_property(p, "volume_db", -80.0, fade_time)
			t.tween_callback(p.stop)

func duck(amount_db := -10.0, seconds := 1.2) -> void:
	var p := _music_a if _music_a.playing else _music_b
	if not p.playing:
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", _target_db + amount_db, 0.15)
	t.tween_interval(seconds)
	t.tween_property(p, "volume_db", _target_db, 0.9)
