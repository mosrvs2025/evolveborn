extends Node
## Developer tools. Off unless the build is a debug build or the page was opened
## with ?debug=1, so a player never trips over them.
##
## F3 toggles the readout; the rest only respond while it is enabled.

var enabled := false
var god := false
var start_region := ""
var start_traits := false
var overlay: Label = null
var _layer: CanvasLayer = null
var _accum := 0.0
var _query := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_query = _query_string()
	enabled = OS.is_debug_build() or _query.contains("debug=1")
	if not enabled:
		return
	god = _query.contains("god=1")
	start_traits = _query.contains("traits=1")
	start_region = _query_value("region")
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	overlay = Label.new()
	overlay.add_theme_font_size_override("font_size", 13)
	overlay.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	overlay.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	overlay.add_theme_constant_override("outline_size", 4)
	overlay.position = Vector2(20, 150)
	overlay.visible = false
	_layer.add_child(overlay)

func _query_string() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.search", true))
	var args := ""
	for a in OS.get_cmdline_user_args():
		args += a
	return args

func _query_value(key: String) -> String:
	for part in _query.trim_prefix("?").split("&"):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] == key:
			return kv[1]
	return ""

## Called by the run once the first region exists, so ?region= and ?traits=
## land a test straight where it needs to be.
func apply_run_overrides() -> void:
	if not enabled:
		return
	if start_traits:
		for id in DB.trait_ids():
			Game.discover_trait(id)
	if start_region != "" and Layouts.REGIONS.has(start_region):
		Sig.request_state.emit("travel", {"to": start_region})

func _process(delta: float) -> void:
	if not enabled or overlay == null or not overlay.visible:
		return
	# A menu owns the screen; the readout is for watching the game run.
	_layer.visible = Game.state == Game.State.PLAYING
	_accum += delta
	if _accum < 0.25:
		return
	_accum = 0.0
	var lines: Array[String] = []
	lines.append("FPS            %d" % Engine.get_frames_per_second())
	lines.append("DRAW CALLS     %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	lines.append("PRIMITIVES     %d" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	lines.append("OBJECTS        %d" % Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	lines.append("NODES          %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	lines.append("CREATURES      %d" % get_tree().get_nodes_in_group("creature").size())
	lines.append("QUALITY        %s" % Settings.quality_resolved)
	lines.append("REGION         %s" % Game.current_region)
	var p := Game.player
	if p != null and is_instance_valid(p):
		lines.append("POS            %.0f %.0f %.0f" % [p.global_position.x, p.global_position.y, p.global_position.z])
		lines.append("HEALTH         %.0f / %.0f" % [p.health, p.max_health])
	lines.append("")
	lines.append("F3 hide  F4 heal  F5 kill  F6 all traits")
	lines.append("F7 next region  F8 essence  F9 boss  F10 wipe save")
	overlay.text = "\n".join(lines)

func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F3:
			overlay.visible = not overlay.visible
		KEY_F4:
			if overlay.visible and Game.player != null:
				Game.player.full_heal()
		KEY_F5:
			if overlay.visible and Game.player != null:
				Game.player.die()
		KEY_F6:
			if overlay.visible:
				for id in DB.trait_ids():
					Game.discover_trait(id)
				Sig.toast.emit("ALL TRAITS CATALOGUED", Palette.UI_ACCENT)
		KEY_F7:
			if overlay.visible:
				var next := Game.next_region()
				if next != "":
					Sig.request_state.emit("travel", {"to": next})
		KEY_F8:
			if overlay.visible:
				Game.add_essence(60)
		KEY_F9:
			if overlay.visible:
				Sig.request_state.emit("travel", {"to": "ancient_nest"})
		KEY_F10:
			if overlay.visible:
				SaveMgr.clear()
				Sig.toast.emit("SAVE CLEARED", Palette.UI_WARN)
