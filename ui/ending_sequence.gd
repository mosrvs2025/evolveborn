extends Control
## Drives the last two minutes: the Echo's three readings, the fade, the title
## card, then the statistics.

signal finished

var _label: Label
var _fade: ColorRect
var _title: Label
var _sub: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Kit.label("", 20, Palette.UI_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Kit.anchor_box(_label, Vector2(0.5, 1), Vector2(-420 * Kit.scale(), -180 * Kit.scale()),
		Vector2(840 * Kit.scale(), 96 * Kit.scale()))
	_label.modulate.a = 0.0
	add_child(_label)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.02, 0.03, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var card := Kit.vbox(8)
	_title = Kit.label("EVOLVEBORN", 72, Palette.UI_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_title.modulate.a = 0.0
	card.add_child(_title)
	_sub = Kit.label("END OF VERTICAL SLICE", 18, Palette.UI_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_sub.modulate.a = 0.0
	card.add_child(_sub)
	add_child(Kit.center(card))
	_run()

func _run() -> void:
	await _wait(5.0)
	await _say(DB.echo("ending_1"))
	await _wait(3.4)
	await _say(DB.echo("ending_2"))
	await _wait(3.4)
	await _say(DB.echo("ending_3"))
	await _wait(4.0)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 3.0)
	await t.finished
	await _wait(0.8)
	var t2 := create_tween()
	t2.tween_property(_title, "modulate:a", 1.0, 1.6)
	await t2.finished
	await _wait(1.6)
	var t3 := create_tween()
	t3.tween_property(_sub, "modulate:a", 1.0, 1.2)
	await t3.finished
	await _wait(2.6)
	finished.emit()

func _say(lines: Array) -> void:
	if lines.is_empty():
		return
	_label.text = "\n".join(lines)
	Audio.play("echo", -8.0)
	var t := create_tween()
	t.tween_property(_label, "modulate:a", 1.0, 1.1)
	await t.finished

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
