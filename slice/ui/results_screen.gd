extends Control
## End of the slice. Every line here is something the player did, which is what
## makes the missing ones an invitation.

signal play_again
signal keep_exploring
signal main_menu

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.035, 0.055, 0.97)
	add_child(bg)
	var r := Game.results_summary()
	var root := Kit.vbox(6)
	root.custom_minimum_size = Vector2(560 * Kit.scale(), 0)
	root.add_child(Kit.title("EVOLVEBORN", 46))
	root.add_child(Kit.label("END OF VERTICAL SLICE", 16, Palette.UI_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(Kit.spacer(14))
	var evo := DB.evolution(String(r.evolution))
	var rows := [
		["COMPLETION TIME", Game.format_time(float(r.time))],
		["BEST TIME", Game.format_time(float(r.best_time)) if float(r.best_time) > 0.0 else "—"],
		["CREATURES DEFEATED", str(r.kills)],
		["ORGANISMS DEVOURED", str(r.devoured)],
		["SPECIES DISCOVERED", "%d / %d" % [r.species, r.species_total]],
		["TRAITS FOUND", "%d / %d" % [r.traits, r.traits_total]],
		["SYNERGIES DISCOVERED", "%d / %d" % [r.synergies, r.synergies_total]],
		["EVOLUTION", String(evo.get("display_name", "NONE")).to_upper()],
		["HIDDEN CACHES", str(r.secrets)],
		["DEATHS", str(r.deaths)],
	]
	for row in rows:
		var h := Kit.hbox(10)
		var k := Kit.label(String(row[0]), 15, Palette.UI_DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(Kit.label(String(row[1]), 16, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
		root.add_child(h)
	root.add_child(Kit.spacer(16))
	var buttons := Kit.hbox(10)
	var again := Kit.button("PLAY AGAIN", 17)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): play_again.emit())
	buttons.add_child(again)
	var keep := Kit.button("CONTINUE EXPLORING", 17)
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.pressed.connect(func(): keep_exploring.emit())
	buttons.add_child(keep)
	var menu := Kit.button("MAIN MENU", 17)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func(): main_menu.emit())
	buttons.add_child(menu)
	root.add_child(buttons)
	add_child(Kit.center(root))
	keep.call_deferred("grab_focus")
