extends Node
## Integration: builds every region for real, fights something, devours it,
## walks the gate chain, and drives the boss through all three phases.
## Run with:  godot --headless tests/playthrough.tscn

var failures := 0
var checks := 0
var world: Node3D

func _ready() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	Game.world = world
	await _run()
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

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _run() -> void:
	await _regions()
	await _combat_and_devour()
	await _trait_effects()
	await _travel_chain()
	await _boss()
	await _persistence()

# --- world --------------------------------------------------------------------

func _regions() -> void:
	print("regions")
	for id in Game.REGION_ORDER:
		Game.new_run() if id == "awakening_cavern" else Game.load_region(id, "entry")
		await wait(0.1)
		var region := Game.region_node
		ok(region != null, "region built: " + id)
		if region == null:
			continue
		var terrain: Terrain = region.terrain
		ok(terrain != null, "terrain built: " + id)
		ok(terrain.is_walkable(terrain.zone_center(0).x, terrain.zone_center(0).z),
			"first chamber is walkable: " + id)
		ok(region.pools.size() >= 1, "region has a memory pool: " + id)
		var creatures := get_tree().get_nodes_in_group("creature")
		ok(creatures.size() >= 3, "region is populated: %s (%d)" % [id, creatures.size()])
		var p := Game.player
		ok(p != null and is_instance_valid(p), "player spawned: " + id)
		if p != null:
			ok(terrain.is_walkable(p.global_position.x, p.global_position.z),
				"player starts on solid ground: " + id)
			ok(p.cam_rig != null, "camera attached: " + id)
		# Everything must be able to stand up: let physics settle and check
		# nothing has fallen out of the world.
		await wait(0.7)
		var fell := 0
		for c in get_tree().get_nodes_in_group("creature"):
			if is_instance_valid(c) and c.global_position.y < -60.0:
				fell += 1
		eq(fell, 0, "nothing fell out of " + id)
		if Game.player != null and is_instance_valid(Game.player):
			# Standing ON the floor, not falling through it: this is the check
			# that catches a terrain whose collision does not match its mesh.
			var pp: Vector3 = Game.player.global_position
			var ground: float = terrain.height_at(pp.x, pp.z)
			ok(pp.y > ground - 1.5 and pp.y < ground + 3.0,
				"the player is standing on the floor of %s (y %.1f, ground %.1f)" % [id, pp.y, ground])
			ok(Game.player.is_on_floor(), "and the floor is solid in " + id)

# --- combat -------------------------------------------------------------------

func _combat_and_devour() -> void:
	print("combat")
	Game.new_run()
	await wait(0.4)
	var p: Player = Game.player
	ok(p != null, "player exists")
	if p == null:
		return
	var data := DB.get_creature("moss_grazer")
	var c := Creature.new()
	c.setup(data)
	Game.region_node.add_child(c)
	c.global_position = p.global_position + Vector3(0, 0.5, 2.0)
	await wait(0.2)
	var before := c.health
	p._facing = Vector3(0, 0, 1)
	p._use("body_slam")
	await wait(0.1)
	ok(c.health < before, "a strike removes health (%.1f -> %.1f)" % [before, c.health])
	ok(Game.stats["damage_dealt"] > 0.0, "damage is recorded")
	# Statuses must apply through the same path.
	c.apply_status("poison", 5.0, 2.0)
	var poisoned := c.health
	await wait(0.6)
	ok(c.health < poisoned, "poison keeps working after the hit")
	# Kill it and confirm the body persists.
	var kill := Hit.make(500.0, p, "player", c.global_position)
	c.take_hit(kill)
	await wait(0.3)
	var corpses := get_tree().get_nodes_in_group("devourable")
	ok(corpses.size() == 1, "the body stays behind")
	eq(Game.stats["kills"], 1, "the kill is recorded")
	if corpses.is_empty():
		return
	var corpse = corpses[0]
	ok(not Game.loadout.discovered.has("regenerative_tissue"), "trait not known yet")
	var essence_before := Game.essence
	corpse.set_devour_progress(0.5)
	ok(corpse.progress > 0.0, "devour progress registers")
	corpse.devour(p)
	await wait(0.2)
	ok(Game.loadout.discovered.has("regenerative_tissue"), "devouring yields the trait")
	ok(Game.loadout.equipped.has("regenerative_tissue"), "and integrates it when there is room")
	ok(Game.essence > essence_before, "and yields essence")
	eq(Game.stats["devoured"], 1, "the meal is recorded")
	ok(Game.species_seen.has("moss_grazer"), "the species is catalogued")
	ok(p.stats.regen > 0.0, "the player's body changed as a result")

func _trait_effects() -> void:
	print("traits")
	var p: Player = Game.player
	if p == null:
		return
	Game.loadout.clear_equipped()
	Sig.loadout_changed.emit()
	await wait(0.05)
	p.health = p.max_health
	var bare := Hit.make(50.0, null, "creature", p.global_position + Vector3.FORWARD)
	p._invuln = 0.0
	p._spawn_grace = 0.0
	p.take_hit(bare)
	var unarmoured := p.max_health - p.health
	Game.loadout.discover("chitin_armor")
	Game.loadout.equip("chitin_armor")
	Sig.loadout_changed.emit()
	await wait(0.05)
	p.health = p.max_health
	p._invuln = 0.0
	var armoured_hit := Hit.make(50.0, null, "creature", p.global_position + Vector3.FORWARD)
	p.take_hit(armoured_hit)
	var armoured := p.max_health - p.health
	ok(armoured < unarmoured * 0.85,
		"chitin reduces damage (%.1f -> %.1f)" % [unarmoured, armoured])
	eq(p.slots.primary, "shell_bash", "and it changed which strike the control does")
	# Evolution has to be felt, not just recorded.
	var health_before := p.max_health
	Game.essence = DB.ESSENCE_TO_EVOLVE
	Game.spend_evolution("bulwark")
	p.refresh_from_loadout()
	ok(p.max_health > health_before, "bulwark adds mass")
	ok(Game.loadout.capacity() > DB.BASE_CAPACITY, "and Core capacity")

# --- flow ---------------------------------------------------------------------

func _travel_chain() -> void:
	print("travel")
	Game.new_run()
	await wait(0.3)
	var visited: Array[String] = ["awakening_cavern"]
	for i in 4:
		var next := Game.next_region()
		ok(next != "", "there is a next region after " + Game.current_region)
		Game.travel(next, "entry")
		await wait(0.25)
		eq(Game.current_region, next, "arrived in " + next)
		ok(Game.player != null and is_instance_valid(Game.player), "player travelled with us")
		visited.append(next)
	eq(visited.size(), 5, "all five regions are reachable in order")
	eq(Game.current_region, "ancient_nest", "the chain ends at the nest")
	# A checkpoint has to survive a death.
	Game.set_checkpoint("nest_gate")
	var before_traits := Game.loadout.discovered.size()
	Game.on_player_died()
	Game.respawn()
	await wait(0.3)
	eq(Game.loadout.discovered.size(), before_traits, "death keeps what was learned")
	eq(Game.current_region, "ancient_nest", "respawn returns to the checkpoint region")
	eq(Game.stats["deaths"], 1, "the death is recorded")
	ok(Game.player != null and is_instance_valid(Game.player), "and there is a body again")

func _boss() -> void:
	print("boss")
	Game.load_region("ancient_nest", "entry")
	await wait(0.4)
	var bosses := get_tree().get_nodes_in_group("boss")
	ok(bosses.size() == 1, "the nest contains exactly one Root Devourer")
	if bosses.is_empty():
		return
	var boss: RootDevourer = bosses[0]
	var p: Player = Game.player
	Game.loadout.extra_capacity = 10
	for id in ["heat_gland", "electrical_organ"]:
		Game.loadout.discover(id)
		Game.loadout.equip(id)
	Sig.loadout_changed.emit()
	eq(boss.phase, 1, "it starts in phase one")
	boss._intro_done = true
	boss.take_hit(Hit.make(boss.max_health * 0.4, p, "player", p.global_position))
	await wait(0.2)
	eq(boss.phase, 2, "it reaches phase two")
	await wait(2.6)                      # it calls something in and eats it
	ok(boss.copied_traits.size() >= 1, "it took a trait from what it ate")
	boss.take_hit(Hit.make(boss.max_health * 0.4, p, "player", p.global_position))
	await wait(0.2)
	eq(boss.phase, 3, "it reaches phase three")
	var copied_from_player := false
	for id2 in boss.copied_traits:
		if Game.loadout.equipped.has(id2):
			copied_from_player = true
	ok(copied_from_player, "and in phase three it copies what the player is wearing")
	ok(boss._pool.size() > 3, "its attack pool grew with what it took")
	var defeated := [false]
	Sig.boss_defeated.connect(func(): defeated[0] = true)
	boss.take_hit(Hit.make(boss.max_health, p, "player", p.global_position))
	await wait(0.2)
	ok(boss.dead, "it can be killed")
	ok(defeated[0], "and it announces it")

func _persistence() -> void:
	print("save")
	Game.stats["kills"] = 7
	Game.run_time = 123.0
	Game.write_save()
	var traits_before := Game.loadout.discovered.duplicate()
	var region_before := Game.checkpoint_region
	SaveMgr.load_game()
	Game.read_save()
	eq(Game.loadout.discovered.size(), traits_before.size(), "traits survive a reload")
	eq(Game.checkpoint_region, region_before, "the checkpoint survives a reload")
	eq(int(Game.stats["kills"]), 7, "statistics survive a reload")
	Game.finish_run()
	ok(bool(SaveMgr.data["completed"]), "finishing marks the save complete")
	ok(float(SaveMgr.data["best_time"]) > 0.0, "and records a best time")
	var summary := Game.results_summary()
	ok(int(summary.species_total) >= 10, "the end screen knows how many species exist")
	ok(int(summary.traits_total) >= 10, "and how many traits")
	SaveMgr.clear()
