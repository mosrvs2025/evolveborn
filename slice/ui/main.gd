extends Node
## The shell. Owns the world node, every screen, and the transitions between
## them. Game state changes arrive as requests on the signal bus; this is the
## only script that knows what a screen looks like.

var world: Node3D
var ui: CanvasLayer
var overlay: CanvasLayer
var fade: ColorRect

var hud: Control = null
var touch: Control = null
var screen: Control = null          ## the exclusive screen currently open
var _screen_stack: Array = []
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	overlay = CanvasLayer.new()
	overlay.layer = 50
	add_child(overlay)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.02, 0.03, 0.05, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(fade)
	Game.world = world
	Sig.request_state.connect(_on_request)
	Sig.synergy_discovered.connect(_on_synergy)
	Sig.trait_discovered.connect(_on_trait)
	Sig.evolution_available.connect(func(): Sig.toast.emit("EVOLUTION AVAILABLE", Palette.UI_ACCENT))
	Sig.boss_defeated.connect(func(): pass)
	show_title()

# --- screens ------------------------------------------------------------------

func _clear_screen() -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = null

func _set_screen(node: Control) -> void:
	_clear_screen()
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(node)
	screen = node
	# A menu owns the screen; leaving the HUD visible underneath only makes
	# both harder to read.
	_hide_hud()

func _ensure_hud() -> void:
	if hud == null or not is_instance_valid(hud):
		hud = load("res://ui/hud.gd").new()
		ui.add_child(hud)
		ui.move_child(hud, 0)
	if touch == null or not is_instance_valid(touch):
		touch = load("res://ui/touch_controls.gd").new()
		ui.add_child(touch)
	hud.visible = true
	touch.visible = touch._should_show()

func _hide_hud() -> void:
	if hud != null and is_instance_valid(hud):
		hud.visible = false
	if touch != null and is_instance_valid(touch):
		touch.release_all()
		touch.visible = false

func show_title() -> void:
	Game.unload_region()
	Game.set_state(Game.State.TITLE)
	_hide_hud()
	Audio.play_music("title")
	var t = load("res://ui/title_screen.gd").new()
	t.new_run.connect(_start_new_run)
	t.continue_run.connect(_start_continue)
	t.continue_exploring.connect(_start_exploring)
	t.open_settings.connect(func(): _push(load("res://ui/settings_menu.gd").new(), "closed"))
	t.open_controls.connect(func(): _push(load("res://ui/controls_menu.gd").new(), "closed"))
	_set_screen(t)

## Pushes a sub-screen over the current one and restores it when closed.
func _push(node: Control, close_signal: String) -> void:
	var previous := screen
	if previous != null:
		previous.visible = false
	_screen_stack.append(previous)
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(node)
	screen = node
	node.connect(close_signal, func():
		node.queue_free()
		var back = _screen_stack.pop_back()
		screen = back
		if back != null and is_instance_valid(back):
			back.visible = true)

# --- run flow -----------------------------------------------------------------

func _start_new_run() -> void:
	await _fade_to(1.0, 0.4)
	_clear_screen()
	SaveMgr.data["echo_seen"] = []
	Game.new_run()
	_ensure_hud()
	await _fade_to(0.0, 0.7)

func _start_continue() -> void:
	await _fade_to(1.0, 0.4)
	_clear_screen()
	Game.continue_run()
	_ensure_hud()
	await _fade_to(0.0, 0.7)

func _start_exploring() -> void:
	await _fade_to(1.0, 0.4)
	_clear_screen()
	Game.read_save()
	Game.endless = true
	Game.load_region(Game.checkpoint_region,
		"pool:" + Game.checkpoint_pool if Game.checkpoint_pool != "" else "entry")
	Game.set_state(Game.State.PLAYING)
	_ensure_hud()
	await _fade_to(0.0, 0.7)

func _on_request(state: String, payload: Dictionary) -> void:
	match state:
		"travel": _travel(String(payload.get("to", "")))
		"pool": _open_pool()
		"dead": _on_death()
		"boss_devour": _boss_devour()
		_: pass

func _travel(to_region: String) -> void:
	if _busy or to_region == "":
		return
	_busy = true
	await _fade_to(1.0, 0.6)
	Game.travel(to_region, "entry")
	await get_tree().process_frame
	await _fade_to(0.0, 0.8)
	_busy = false

# --- in-game menus ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not Game.is_playing():
		return
	if event.is_action_pressed("menu_pause"):
		get_viewport().set_input_as_handled()
		_open_pause()
	elif event.is_action_pressed("menu_body"):
		get_viewport().set_input_as_handled()
		_open_body(true)

func _open_pause() -> void:
	Game.set_state(Game.State.PAUSED)
	if touch != null and is_instance_valid(touch):
		touch.release_all()
	var p = load("res://ui/pause_menu.gd").new()
	p.resume_requested.connect(_resume)
	p.open_body.connect(func(): _open_body(true))
	p.open_settings.connect(func(): _push(load("res://ui/settings_menu.gd").new(), "closed"))
	p.open_controls.connect(func(): _push(load("res://ui/controls_menu.gd").new(), "closed"))
	p.restart_checkpoint.connect(func():
		_clear_screen()
		Game.respawn())
	p.quit_to_menu.connect(func():
		Game.write_save()
		show_title())
	_set_screen(p)

func _resume() -> void:
	_clear_screen()
	_ensure_hud()
	Game.set_state(Game.State.PLAYING)

func _open_body(allow_swap: bool) -> void:
	Game.set_state(Game.State.MENU)
	if touch != null and is_instance_valid(touch):
		touch.release_all()
	var b = load("res://ui/body_menu.gd").new()
	b.closed.connect(func():
		_clear_screen()
		_ensure_hud()
		Game.set_state(Game.State.PLAYING))
	_set_screen(b)
	b.open(allow_swap)

func _open_pool() -> void:
	Game.set_state(Game.State.MENU)
	var p = load("res://ui/pool_menu.gd").new()
	p.closed.connect(func():
		_clear_screen()
		_ensure_hud()
		Game.set_state(Game.State.PLAYING))
	p.open_body.connect(func(): _open_body(true))
	p.open_evolution.connect(_open_evolution)
	_set_screen(p)

func _open_evolution() -> void:
	Game.set_state(Game.State.MENU)
	var e = load("res://ui/evolution_screen.gd").new()
	e.cancelled.connect(func():
		_clear_screen()
		_open_pool())
	e.chosen.connect(_do_evolution)
	_set_screen(e)

## The transformation: the one moment the game stops for, on purpose.
func _do_evolution(form_id: String) -> void:
	_clear_screen()
	_ensure_hud()
	Game.set_state(Game.State.CUTSCENE)
	var evo := DB.evolution(form_id)
	var p := Game.player
	Audio.play_music("evolution", 0.8)
	Audio.play("evolve", 1.0)
	if p != null and is_instance_valid(p):
		if p.cam_rig != null:
			p.cam_rig.set_focus(null)
		for i in 5:
			Fx.burst(p.global_position + Vector3.UP * 0.8, evo.color, "dissolve", 26, 1.8)
			Fx.ring_flash(p.global_position, 4.0 + i * 2.0, evo.color, 0.7)
			Fx.shake(0.5)
			p.visuals.set_charge(1.0)
			await get_tree().create_timer(0.32, true, false, true).timeout
	Sig.echo_analysis.emit(evo.lines)
	Game.spend_evolution(form_id)
	if p != null and is_instance_valid(p):
		p.refresh_from_loadout()
		p.full_heal()
		p.visuals.set_charge(0.0)
		Fx.burst(p.global_position + Vector3.UP * 0.8, evo.color, "dissolve", 40, 2.4)
	Sig.toast.emit(String(evo.display_name).to_upper(), evo.color)
	Sig.loadout_changed.emit()
	await get_tree().create_timer(1.1, true, false, true).timeout
	Game.set_state(Game.State.PLAYING)

# --- death --------------------------------------------------------------------

func _on_death() -> void:
	var box := Control.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(Kit.dim(0.7))
	var v := Kit.vbox(10)
	v.add_child(Kit.label("COHESION LOST", 42, Palette.UI_BAD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.label("Nothing you learned is lost.", 15, Palette.UI_DIM,
		HORIZONTAL_ALIGNMENT_CENTER))
	var b := Kit.button("REFORM AT MEMORY POOL", 18)
	b.pressed.connect(_respawn)
	v.add_child(b)
	box.add_child(Kit.center(v))
	_set_screen(box)
	b.call_deferred("grab_focus")
	# Death is fast: it respawns itself if the player does nothing.
	await get_tree().create_timer(2.4, true, false, true).timeout
	if screen == box:
		_respawn()

func _respawn() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, 0.35)
	_clear_screen()
	Game.respawn()
	_ensure_hud()
	await _fade_to(0.0, 0.5)
	_busy = false

# --- the end ------------------------------------------------------------------

func _boss_devour() -> void:
	Game.set_state(Game.State.CUTSCENE)
	var p := Game.player
	Game.echo("boss_done", false)
	if p != null and is_instance_valid(p):
		p.full_heal()
		for i in 4:
			Fx.suck(p.global_position + Vector3(randf_range(-6, 6), randf_range(1, 5), randf_range(-6, 6)),
				p.global_position + Vector3.UP * 0.6, Color(1.0, 0.85, 0.5), 22)
			Fx.shake(0.4)
			await get_tree().create_timer(0.5, true, false, true).timeout
		p.visuals.set_charge(1.0)
		Fx.ring_flash(p.global_position, 10.0, Color(1.0, 0.9, 0.6), 1.0)
	Sig.toast.emit("PRIMORDIAL CORE", Color(1.0, 0.88, 0.55))
	# The body starts to become something else and then cannot finish. What it
	# keeps is room: two more points of Core capacity, and no idea what for.
	Game.loadout.extra_capacity += 2
	Sig.loadout_changed.emit()
	await get_tree().create_timer(1.6, true, false, true).timeout
	Game.echo("boss_stall", false)
	if p != null and is_instance_valid(p):
		p.visuals.set_charge(0.0)
		p.refresh_from_loadout()
	await get_tree().create_timer(3.2, true, false, true).timeout
	await _ending()

func _ending() -> void:
	await _fade_to(1.0, 1.4)
	_hide_hud()
	_clear_screen()
	Game.unload_region()
	var horizon = load("res://world/horizon.gd").new()
	world.add_child(horizon)
	Game.set_state(Game.State.CUTSCENE)
	await _fade_to(0.0, 2.2)
	var seq = load("res://ui/ending_sequence.gd").new()
	seq.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(seq)
	seq.finished.connect(func():
		seq.queue_free()
		_show_results())

func _show_results() -> void:
	Game.unload_region()
	Game.finish_run()
	var r = load("res://ui/results_screen.gd").new()
	r.play_again.connect(_start_new_run)
	r.keep_exploring.connect(_start_exploring)
	r.main_menu.connect(show_title)
	_set_screen(r)
	fade.color.a = 0.0

# --- feedback -----------------------------------------------------------------

func _on_synergy(id: String) -> void:
	var s := DB.synergy(id)
	if s.is_empty():
		return
	Sig.toast.emit("SYNERGY DISCOVERED  ·  " + String(s.display_name).to_upper(), s.color)
	Sig.echo_analysis.emit(["SYNERGY DETECTED", String(s.display_name).to_upper(),
		String(s.description)])
	Audio.play("synergy", 0.0)
	var p := Game.player
	if p != null and is_instance_valid(p):
		Fx.ring_flash(p.global_position, 5.0, s.color, 0.6)
		Fx.burst(p.global_position + Vector3.UP * 0.7, s.color, "dissolve", 26, 1.4)
		p.visuals.flash(s.color)
	Fx.shake(0.3)

func _on_trait(id: String) -> void:
	var t := DB.get_trait(id)
	if t != null:
		Sig.toast.emit("TRAIT ACQUIRED  ·  " + t.display_name.to_upper(), t.color)

# --- utility ------------------------------------------------------------------

func _fade_to(alpha: float, seconds: float) -> void:
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(fade, "color:a", alpha, seconds)
	await t.finished
