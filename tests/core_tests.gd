extends Node
## Logic tests: content integrity, loadout maths, statuses, saves, input map.
## Run with:  godot --headless tests/core_tests.tscn

var failures := 0
var checks := 0

func _ready() -> void:
	_content()
	_loadout()
	_synergies()
	_status()
	_input_map()
	_save_round_trip()
	_layouts()
	print("\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func ok(condition: bool, what: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("  FAIL  ", what)

func eq(a, b, what: String) -> void:
	checks += 1
	if a != b:
		failures += 1
		print("  FAIL  %s  (%s != %s)" % [what, a, b])

# --- content ------------------------------------------------------------------

func _content() -> void:
	print("content")
	ok(DB.traits.size() >= 10, "at least ten traits")
	ok(DB.creatures.size() >= 10, "at least ten species")
	ok(DB.abilities.size() >= 20, "ability table loaded")
	for id in DB.traits.keys():
		var t: TraitData = DB.traits[id]
		eq(t.id, id, "trait id matches filename: " + id)
		ok(t.core_cost > 0, "trait has a cost: " + id)
		ok(t.description != "", "trait has a description: " + id)
		if t.active_ability != "":
			ok(DB.get_ability(t.active_ability) != null, "trait ability exists: " + id)
			ok(t.ability_slot in ["primary", "secondary", "mobility"], "valid slot: " + id)
		ok(t.visual_mutation != "", "trait has a visible mutation: " + id)
		ok(PlayerVisuals.MUTATIONS.has(t.visual_mutation), "mutation is built: " + t.visual_mutation)
	var rewards := {}
	for id in DB.creatures.keys():
		var c: CreatureData = DB.creatures[id]
		eq(c.id, id, "creature id matches filename: " + id)
		ok(c.max_health > 0.0, "creature has health: " + id)
		ok(c.essence_reward > 0, "creature is worth essence: " + id)
		if c.trait_reward != "":
			ok(DB.get_trait(c.trait_reward) != null, "creature trait exists: " + id)
			ok(not rewards.has(c.trait_reward), "trait has one source: " + c.trait_reward)
			rewards[c.trait_reward] = id
		if c.ranged_ability != "":
			ok(DB.get_ability(c.ranged_ability) != null, "creature ability exists: " + id)
	# Every trait must be obtainable, or the build space is a lie.
	for id in DB.traits.keys():
		ok(rewards.has(id), "trait is reachable by devouring something: " + id)

# --- loadout ------------------------------------------------------------------

func _loadout() -> void:
	print("loadout")
	var lo := Loadout.new()
	eq(lo.capacity(), DB.BASE_CAPACITY, "starting capacity")
	eq(lo.used_capacity(), 0, "starting used")
	ok(not lo.equip("chitin_armor"), "cannot equip what is not discovered")
	lo.discover("chitin_armor")
	ok(lo.equip("chitin_armor"), "equip after discovery")
	eq(lo.used_capacity(), 3, "capacity consumed")
	ok(not lo.equip("chitin_armor"), "cannot equip twice")
	# Capacity must actually block: fill it and try to exceed.
	for id in ["regenerative_tissue", "heat_gland", "power_legs"]:
		lo.discover(id)
	ok(lo.equip("regenerative_tissue"), "second trait fits (3+4 of 8)")
	eq(lo.used_capacity(), 7, "seven of eight used")
	ok(not lo.equip("heat_gland"), "a three-cost trait no longer fits")
	ok(not lo.equip("power_legs"), "not even a two-cost trait fits at 7 of 8")
	ok(lo.unequip("regenerative_tissue"), "remove to make room")
	ok(lo.equip("power_legs"), "cheap trait fits once room is made")
	ok(lo.equip("heat_gland"), "and the Core fills exactly")
	eq(lo.used_capacity(), 8, "capacity is spent to the last point")
	eq(lo.free_capacity(), 0, "nothing left over")
	var stats := lo.stats()
	ok(stats.phys_resist > 0.29, "chitin gives resistance")
	ok(stats.move_speed > Loadout.BASE.move_speed, "power legs are a net speed gain over chitin")
	eq(lo.abilities().primary, "shell_bash", "chitin takes over the primary")
	eq(lo.abilities().secondary, "flame_burst", "heat gland fills the secondary")
	# Plate plus legs is Meteor Slam, so mobility here is the synergy, not Leap.
	eq(lo.abilities().mobility, "meteor_slam", "chitin + power legs produce the synergy")
	# Evolution must widen the Core.
	lo.evolution = "arcane"
	eq(lo.capacity(), DB.BASE_CAPACITY + 5, "arcane adds capacity")
	ok(lo.stats().cooldown_mult < 1.0, "arcane shortens cooldowns")
	lo.unequip("chitin_armor")
	eq(lo.abilities().primary, "body_slam", "primary reverts when the trait comes off")
	# Quick-swap builds
	lo.save_build(0, "test")
	lo.clear_equipped()
	ok(lo.load_build(0), "saved build reloads")
	eq(lo.equipped.size(), 2, "build restored every trait in it")
	eq(lo.abilities().mobility, "leap", "Leap is back now that the plate is not")

func _synergies() -> void:
	print("synergies")
	for s in DB.SYNERGIES:
		eq(s.requires.size(), 2, "synergy is a pair: " + String(s.id))
		for req in s.requires:
			ok(DB.get_trait(String(req)) != null, "synergy requires a real trait: " + String(req))
		if String(s.get("grants", "")) != "":
			ok(DB.get_ability(String(s.grants)) != null, "synergy grants a real ability: " + String(s.id))
			ok(String(s.slot) in ["primary", "secondary", "mobility"], "synergy slot valid")
	var lo := Loadout.new()
	lo.extra_capacity = 12
	for id in ["electrical_organ", "web_gland"]:
		lo.discover(id)
		lo.equip(id)
	var active := lo.active_synergies()
	eq(active.size(), 1, "web + charge is exactly one synergy")
	eq(String(active[0].id), "conductive_web", "the right one")
	eq(lo.abilities().secondary, "conductive_web", "synergy overrides the trait ability")
	# Toxic Blood is a flag rather than an ability, and must still register.
	var lo2 := Loadout.new()
	lo2.extra_capacity = 12
	for id2 in ["regenerative_tissue", "toxin_gland"]:
		lo2.discover(id2)
		lo2.equip(id2)
	ok(lo2.flags().has("retaliate_poison"), "toxic blood sets its flag")
	ok(lo2.flags().has("on_hit_status"), "trait flags survive alongside synergy flags")

func _status() -> void:
	print("status")
	var s := StatusSet.new()
	s.apply("poison", 4.0, 2.0)
	ok(s.has("poison"), "status applied")
	var dealt := s.tick(1.0)
	ok(absf(dealt - 4.0) < 0.001, "poison deals power per second")
	s.apply("poison", 2.0, 5.0)
	eq(s.power("poison"), 4.0, "refresh keeps the stronger dose")
	s.apply("root", 1.0, 1.0)
	eq(s.speed_multiplier(), 0.0, "root stops movement")
	s.tick(1.2)
	ok(not s.has("root"), "root expires")
	s.apply("mark", 2.5, 4.0)
	ok(s.consume("mark"), "mark is consumed by the strike that uses it")
	ok(not s.has("mark"), "mark does not linger")

func _input_map() -> void:
	print("input")
	for action in InputMgr.GAMEPLAY_ACTIONS:
		ok(InputMap.has_action(action), "action exists: " + action)
	ok(InputMap.action_get_events("move_forward").size() >= 2,
		"movement is bound on more than one device")
	# The one-hand cluster must be live in the default scheme.
	var has_arrow := false
	var has_wasd := false
	for ev in InputMap.action_get_events("move_forward"):
		if ev is InputEventKey:
			if ev.physical_keycode == KEY_UP:
				has_arrow = true
			if ev.physical_keycode == KEY_W:
				has_wasd = true
	ok(has_arrow, "arrow key moves forward by default")
	ok(has_wasd, "W moves forward by default")
	var strike_keys := []
	for ev2 in InputMap.action_get_events("act_primary"):
		if ev2 is InputEventKey:
			strike_keys.append(ev2.physical_keycode)
	ok(strike_keys.has(KEY_KP_0) or strike_keys.has(KEY_0),
		"primary can be triggered from the arrow cluster without a mouse")
	# Arrows must not also be turning the camera, or one-hand play fights itself.
	for ev3 in InputMap.action_get_events("look_left"):
		if ev3 is InputEventKey:
			ok(ev3.physical_keycode != KEY_LEFT, "arrow keys are not bound to the camera")
	# The on-screen prompt must name the device in the player's hands: a
	# keyboard player should never be told to press LMB.
	InputMgr.device = "keyboard"
	var kb_prompt := InputMgr.prompt_for("act_primary")
	ok(kb_prompt != "" and kb_prompt != "LMB" and kb_prompt != "RMB",
		"keyboard player sees a key for primary, got '%s'" % kb_prompt)
	ok(InputMgr.prompt_for("act_devour") not in ["", "LMB", "RMB"],
		"keyboard player sees a key for devour")
	InputMgr.device = "mouse"
	eq(InputMgr.prompt_for("act_primary"), "LMB", "mouse player sees LMB for primary")
	InputMgr.device = "gamepad"
	var pad_prompt := InputMgr.prompt_for("act_primary")
	ok(pad_prompt != "" and pad_prompt != "LMB", "gamepad player sees a pad glyph")
	InputMgr.device = "touch"
	eq(InputMgr.prompt_for("act_primary"), "", "touch play shows no key glyph")
	InputMgr.device = "keyboard"
	# Render scale follows the preset until the player overrides it.
	Settings.set_value("render_scale", 0.0)
	Settings.set_value("quality", "low")
	ok(Settings.render_scale() < 1.0, "low quality renders 3D below window size")
	Settings.set_value("quality", "high")
	eq(Settings.render_scale(), 1.0, "high quality renders 3D at full size")
	Settings.set_value("render_scale", 0.6)
	eq(Settings.render_scale(), 0.6, "an explicit render scale wins over the preset")
	Settings.set_value("render_scale", 0.0)
	Settings.set_value("quality", "auto")
	# Rebinding round-trips through the shorthand.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	eq(InputMgr.event_to_shorthand(key), "k:J", "key shorthand")
	var back := InputMgr.shorthand_to_event("k:J")
	eq(back.physical_keycode, KEY_J, "shorthand round-trip")
	eq(InputMgr.shorthand_to_event("jb:2").button_index, 2, "gamepad shorthand")
	eq(InputMgr.shorthand_to_event("ja:4+").axis, 4, "axis shorthand")

func _save_round_trip() -> void:
	print("save")
	var lo := Loadout.new()
	lo.extra_capacity = 6
	for id in ["echo_sense", "shadow_membrane"]:
		lo.discover(id)
		lo.equip(id)
	lo.evolution = "predator"
	lo.save_build(1, "stalk")
	var restored := Loadout.new()
	restored.from_dict(lo.to_dict())
	eq(restored.equipped.size(), 2, "equipped survives a save")
	eq(restored.evolution, "predator", "evolution survives a save")
	eq(restored.capacity(), lo.capacity(), "capacity survives a save")
	eq(restored.build_label(1), "stalk", "build labels survive a save")
	eq(restored.flags().has("mark_crit"), true, "synergy still resolves after load")

func _layouts() -> void:
	print("world")
	var seen_species := {}
	for id in Layouts.REGIONS.keys():
		var l: Dictionary = Layouts.REGIONS[id]
		ok(l.zones.size() > 0, "region has chambers: " + id)
		for link in l.links:
			ok(int(link[0]) < l.zones.size() and int(link[1]) < l.zones.size(),
				"link points at real chambers: " + id)
		for s in l.get("spawns", []):
			ok(DB.get_creature(String(s.species)) != null, "spawn species exists: " + String(s.species))
			seen_species[String(s.species)] = true
			ok(int(s.zone) < l.zones.size(), "spawn chamber exists in " + id)
		for p in l.get("pools", []):
			ok(int(p.zone) < l.zones.size(), "pool chamber exists in " + id)
		var g: Dictionary = l.get("gate", {})
		if not g.is_empty():
			ok(Layouts.REGIONS.has(String(g.to)), "gate leads somewhere real: " + id)
	for id2 in DB.creatures.keys():
		ok(seen_species.has(id2), "species is actually placed in the world: " + id2)
	# The five regions must form one chain ending at the boss.
	var current := "awakening_cavern"
	var steps := 0
	while steps < 10:
		var g2: Dictionary = Layouts.get_layout(current).get("gate", {})
		if g2.is_empty():
			break
		current = String(g2.to)
		steps += 1
	eq(current, "ancient_nest", "the path leads to the nest")
	eq(steps, 4, "four gates between five regions")
	ok(Layouts.get_layout("ancient_nest").has("boss"), "the nest contains the boss")
