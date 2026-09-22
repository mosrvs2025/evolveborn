extends Node
## Player-facing settings: accessibility, camera, audio, quality, touch.
## Stored separately from run progress so wiping a save never loses comfort
## options. Everything reads through `get()`, nothing caches.

const PATH := "user://evolveborn_settings.json"

const DEFAULTS := {
	# camera
	"camera_sensitivity": 1.0,
	"camera_invert_x": false,
	"camera_invert_y": false,
	"smart_camera": true,
	"camera_distance": 1.0,
	# assist
	"target_assist": 0.65,          # 0 = off, 1 = strong
	"hold_to_devour": true,         # false = press toggles
	"auto_sprint": false,
	# feel
	"screen_shake": 0.8,
	"motion_intensity": 1.0,
	"damage_numbers": true,
	"hit_stop": true,
	# presentation
	"ui_scale": 1.0,
	"subtitles": true,
	"colorblind_shapes": true,      # status effects also carry a glyph
	# audio
	"volume_master": 0.9,
	"volume_music": 0.7,
	"volume_sfx": 0.9,
	# performance
	"quality": "auto",              # low / medium / high / auto
	"render_scale": 0.0,            # 0 = follow the quality preset, else 0.5-1.0
	# touch
	"touch_size": 1.0,
	"touch_opacity": 0.55,
	"touch_stick_floating": true,
	"touch_stick_side": "left",
}

var _values: Dictionary = {}
var quality_resolved: String = "medium"

func _ready() -> void:
	_values = DEFAULTS.duplicate(true)
	load_settings()
	_apply_all()

func get_value(key: String):
	return _values.get(key, DEFAULTS.get(key))

func set_value(key: String, value) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply_all()
	save_settings()
	Sig.settings_changed.emit()

func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate(true)
	_apply_all()
	save_settings()
	Sig.settings_changed.emit()

func all() -> Dictionary:
	return _values.duplicate(true)

# --- persistence --------------------------------------------------------------

func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in parsed.keys():
		if DEFAULTS.has(k):
			_values[k] = parsed[k]

func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_values, "  "))
	f.close()

# --- application --------------------------------------------------------------

func _apply_all() -> void:
	_apply_audio()
	_apply_quality()

func _apply_audio() -> void:
	_set_bus("Master", float(get_value("volume_master")))
	_set_bus("Music", float(get_value("volume_music")))
	_set_bus("SFX", float(get_value("volume_sfx")))

func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))

func _apply_quality() -> void:
	var q := String(get_value("quality"))
	if q == "auto":
		q = _detect_quality()
	quality_resolved = q
	_apply_render_scale()

## Rendering 3D below the window resolution and letting the browser upscale is
## the cheapest frame rate there is: the HUD stays crisp because 2D is drawn at
## full size. Compatibility supports bilinear 3D scaling.
func _apply_render_scale() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	tree.root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	tree.root.scaling_3d_scale = render_scale()

func render_scale() -> float:
	var s := float(get_value("render_scale"))
	if s > 0.0:
		return clampf(s, 0.5, 1.0)
	match quality_resolved:
		"low": return 0.65
		"medium": return 0.85
		_: return 1.0

func _detect_quality() -> String:
	# Conservative: anything that looks handheld gets the safe preset.
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		return "low"
	if DisplayServer.is_touchscreen_available():
		return "low"
	if OS.has_feature("web"):
		return "medium"
	return "high"

## Multipliers the world and FX read instead of branching on preset names.
func fx_scale() -> float:
	match quality_resolved:
		"low": return 0.4
		"medium": return 0.75
		_: return 1.0

func prop_density() -> float:
	match quality_resolved:
		"low": return 0.35
		"medium": return 0.7
		_: return 1.0

func view_distance() -> float:
	match quality_resolved:
		"low": return 55.0
		"medium": return 90.0
		_: return 140.0

func shadows_enabled() -> bool:
	return quality_resolved != "low"

func max_dynamic_lights() -> int:
	match quality_resolved:
		"low": return 3
		"medium": return 7
		_: return 14
