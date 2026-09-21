extends Node3D

const Art = preload("res://world/art.gd")
const InputSetup = preload("res://systems/input_setup.gd")
const SaveStore = preload("res://systems/save_store.gd")
const SPECIES = ["moss","ember","shell","spore","bat","hopper","eel","shade"]
const TRAITS = ["regen","heat","armor","venom","echo","legs","electric","shadow"]
const SYNERGIES = [
	["armor","legs","Meteor Slam","Burst lands with an armored shockwave."],
	["regen","venom","Toxic Blood","Attackers are poisoned by your blood."],
	["heat","electric","Plasma Core","Attacks deal 35% more damage."],
	["echo","electric","Resonant Arc","Secondary chains across nearby prey."],
	["shadow","legs","Rift Stride","Burst recovery is accelerated."]
]
var traits: Dictionary = {}
var species: Dictionary = {}
var abilities: Dictionary = {}
var player
var world
var hud
var sound
var camera: Camera3D
var creatures: Array = []
var projectiles: Array = []
var effects: Array = []
var playing = false
var menu_open = true
var settings = {"smart":true,"assist":true,"sensitivity":1.0,"invert":false,"shake":0.25,"motion":0.75,"numbers":true,"subtitles":true,"volume":0.45,"quality":"Auto","ui_scale":1.0,"touch_size":1.0,"touch_opacity":0.7,"floating":true,"toggle_devour":false}
var health: float = 100
var essence: int = 0
var form: String = "Wisp"
var equipped: Array = []
var discovered: Array = []
var synergies: Array = []
var secrets: Array = []
var consumed_ids: Array = []
var checkpoint: int = 0
var region: int = 0
var stats = {"time":0.0,"kills":0,"devoured":0,"deaths":0,"best":0.0}
var completed = false
var boss_killed = false
var camera_yaw: float = 0
var camera_pitch: float = 0.58
var camera_manual: float = 0
var camera_shake: float = 0
var touch_vector = Vector2.ZERO
var device: String = "keyboard"
var devour_progress: float = 0
var devour_target
var devour_toggle = false
var in_combat: float = 0
var autosave_clock: float = 0
var checkpoint_cooldown: float = 0
var echo_time: float = 0
var ending_time: float = -1
var remap_action: String = ""
var saved: Dictionary = {}
var spawned_regions: Dictionary = {}
var test_mode: bool = false
var last_dash: float = 0

func _ready():
	InputSetup.setup()
	for id in TRAITS: traits[id] = load("res://data/trait_%s.tres" % id)
	for id in SPECIES: species[id] = load("res://data/%s.tres" % id)
	for id in ["slam","flame","arc","venom"]: abilities[id] = load("res://data/ability_%s.tres" % id)
	saved = SaveStore.read_save()
	settings.merge(saved.get("settings",{}),true)
	for action in saved.get("bindings",{}):
		if not InputMap.has_action(action): continue
		var codes = saved.bindings[action]
		if not codes is Array: codes = [codes]
		for event in InputMap.action_get_events(action):
			if event is InputEventKey: InputMap.action_erase_event(action,event)
		for code in codes:
			var event = InputEventKey.new()
			event.physical_keycode = int(code)
			InputMap.action_add_event(action,event)
	sound = preload("res://systems/sound.gd").new()
	add_child(sound)
	sound.volume = settings.volume
	world = preload("res://world/hollow.gd").new()
	world.game = self
	add_child(world)
	player = preload("res://player/wisp.gd").new()
	player.game = self
	add_child(player)
	player.position = Vector3(0,0,8)
	camera = Camera3D.new()
	camera.fov = 57
	camera.far = 130
	add_child(camera)
	camera.position = Vector3(9,9,19)
	camera.look_at(Vector3(0,0,2))
	hud = preload("res://ui/interface.gd").new()
	hud.game = self
	add_child(hud)
	spawn_region(0)
	hud.main_menu()
	apply_quality()
	if "--self-test" in OS.get_cmdline_user_args():
		test_mode = true
		call_deferred("self_test")

func max_health() -> float: return 175.0 if form == "Bulwark" else (120.0 if form != "Wisp" else 100.0)
func capacity() -> int: return 16 if form == "Arcane" else (13 if form != "Wisp" else 9)
func used_capacity() -> int:
	var value = 0
	for id in equipped: value += traits[id].core_cost
	return value
func has_synergy(a: String,b: String) -> bool: return a in equipped and b in equipped
func ability():
	for id in ["electric","heat","venom"]:
		if id in equipped: return abilities[traits[id].active_ability]
	return abilities.slam

func start_run(resume: bool = false):
	if resume and not saved.is_empty():
		essence = int(saved.get("essence",0))
		form = saved.get("form","Wisp")
		discovered = saved.get("discovered",[])
		equipped = saved.get("equipped",[])
		synergies = saved.get("synergies",[])
		secrets = saved.get("secrets",[])
		consumed_ids = saved.get("consumed_ids",[])
		checkpoint = clampi(int(saved.get("checkpoint",0)),0,4)
		stats.merge(saved.get("stats",{}),true)
		completed = saved.get("completed",false)
		boss_killed = saved.get("boss_killed",false)
	else:
		essence = 0
		form = "Wisp"
		discovered = []
		equipped = []
		synergies = []
		secrets = []
		consumed_ids = []
		checkpoint = 0
		stats = {"time":0.0,"kills":0,"devoured":0,"deaths":0,"best":saved.get("stats",{}).get("best",0.0)}
		completed = false
		boss_killed = false
	for creature in creatures:
		if is_instance_valid(creature): creature.queue_free()
	creatures.clear()
	spawned_regions.clear()
	clear_projectiles()
	region = checkpoint
	world.stream(region)
	spawn_region(region)
	if region<4: spawn_region(region+1)
	player.position = world.pools[checkpoint]+Vector3(3,0.7,0)
	player.velocity = Vector3.ZERO
	player.rebuild()
	health = max_health()
	playing = true
	menu_open = false
	ending_time = -1
	hud.close_menu()
	echo("THE ECHO AWAKENS","Move toward the small grazer. Strike, then hold Devour beside its remains.")
	camera_yaw = 0
	save_game()

func spawn_region(id: int):
	if spawned_regions.has(id): return
	spawned_regions[id] = true
	var roster = [["moss","moss","ember","shell","moss","ember"],["spore","hopper","moss","spore","bat","hopper","shell"],["shell","bat","eel","shade","shell","bat","eel","ember"],["moss","hopper","eel","shade","ember","spore","moss","hopper","shade"],["shade","shell","ember","spore"]][id]
	for i in range(roster.size()):
		var uid = id*100+i
		if uid in consumed_ids: continue
		var node = preload("res://creatures/creature.gd").new()
		node.game = self
		node.data = species[roster[i]]
		node.index = uid
		node.position = Vector3((-1 if i%2==0 else 1)*(3.5+(i%3)*3),0,-id*48+2-i*4.4)
		add_child(node)
		creatures.append(node)
	if id == 4 and not boss_killed:
		var boss_data = CreatureData.new()
		boss_data.id = "root"
		boss_data.display_name = "THE ROOT DEVOURER"
		boss_data.max_health = 1450
		boss_data.damage = 19
		boss_data.movement_speed = 1.15
		boss_data.essence_reward = 160
		boss_data.tint = Color("b17b8d")
		boss_data.silhouette = "spider"
		var boss_node = preload("res://creatures/creature.gd").new()
		boss_node.game = self
		boss_node.data = boss_data
		boss_node.boss = true
		boss_node.index = 499
		boss_node.position = Vector3(0,0,-215)
		add_child(boss_node)
		creatures.append(boss_node)

func _process(delta):
	update_camera(delta)
	update_effects(delta)
	if not playing or menu_open: return
	if ending_time >= 0:
		ending_time += delta
		if ending_time>8:
			ending_time = -1
			hud.end_menu()
		return
	stats.time += delta
	in_combat = maxf(0,in_combat-delta)
	checkpoint_cooldown = maxf(0,checkpoint_cooldown-delta)
	echo_time = maxf(0,echo_time-delta)
	if "regen" in equipped and in_combat<=0: health=minf(max_health(),health+delta*1.5)
	var next_region = clampi(int((12-player.position.z)/48),0,4)
	if next_region != region:
		var eaten_here = 0
		for uid in consumed_ids:
			if int(uid/100)==region: eaten_here+=1
		if next_region>region and (eaten_here<3 or (next_region==4 and form=="Wisp")):
			player.position.z = 12-(region+1)*48+0.7
			if echo_time<2: echo("LIVING MEMBRANE", "The nest rejects an unevolved Core. Evolve at a Memory Pool." if next_region==4 and form=="Wisp" else "Absorb %d more organisms in this region to pass." % (3-eaten_here))
			next_region = region
	if next_region != region:
		region = next_region
		world.stream(region)
		spawn_region(region)
		if region<4: spawn_region(region+1)
		# Keep only neighboring creature regions active.
		for c in creatures.duplicate():
			if is_instance_valid(c) and absi(int(c.index/100)-region)>1:
				spawned_regions.erase(int(c.index/100))
				creatures.erase(c)
				c.queue_free()
		echo(world.NAMES[region], ["A small life. An impossible appetite.","Toxins gather in the still water. Burst across them.","These stones remember their makers.","Hunt what your body needs.","Something below is eating everything."][region])
	for i in range(5):
		if player.position.distance_to(world.pools[i])<3:
			health = minf(max_health(),health+delta*25)
			if checkpoint != i or checkpoint_cooldown<=0:
				checkpoint = i
				checkpoint_cooldown = 20
				save_game()
				echo("MEMORY ANCHORED", "Evolution ready. Open Body to choose a form." if essence>=180 and form=="Wisp" else "Health restored. Progress preserved. Open Body to adapt.")
			if Input.is_action_just_pressed("interact"): hud.body_menu()
	var relic = Vector3(18,0,-region*48-16)
	if player.position.distance_to(relic)<2.2 and not region in secrets:
		secrets.append(region)
		essence += 35
		echo("MEMORY OF THE MAKERS","A civilization cultivated this ecosystem. +35 Essence")
		sound.play("trait")
		burst(relic+Vector3.UP,Color("f3d291"),20)
		save_game()
	if region == 1:
		for p in [Vector3(8,0,-56),Vector3(-15,0,-66)]:
			if player.position.distance_to(p)<2 and player.position.y<0.4: hurt(delta*7)
	update_devour(delta)
	update_projectiles(delta)
	if last_dash>0 and player.dash_time<=0 and has_synergy("armor","legs"):
		for c in creatures:
			if is_instance_valid(c) and not c.dead and c.position.distance_to(player.position)<4.5: c.hit(20,Color("e6c99c"))
		burst(player.position,Color("e6c99c"),12)
	last_dash = player.dash_time
	if has_synergy("shadow","legs"): player.mobility_cd=maxf(0,player.mobility_cd-delta*0.35)
	autosave_clock += delta
	if autosave_clock>20:
		autosave_clock = 0
		save_game()
	sound.intensity = 2 if region==4 else (1 if in_combat>0 else 0)
	hud.update_hud()

func _unhandled_input(event):
	if remap_action != "" and event is InputEventKey and event.pressed:
		bind_key(remap_action,event.physical_keycode)
		remap_action = ""
		save_game()
		hud.controls_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion: device = "controller"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag: device = "touch"
	elif event is InputEventKey or event is InputEventMouseButton: device = "keyboard"
	if event.is_action_pressed("pause") and playing:
		if menu_open: hud.close_menu()
		else: hud.pause_menu()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("body") and playing:
		if menu_open: hud.close_menu()
		else: hud.body_menu()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("target"):
		camera_yaw = atan2(-player.facing.x,-player.facing.z)
		camera_manual = 0
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and not menu_open:
		orbit(event.relative)

func orbit(relative: Vector2):
	camera_yaw -= relative.x*0.004*settings.sensitivity
	camera_pitch = clampf(camera_pitch+relative.y*0.003*settings.sensitivity*(-1 if settings.invert else 1),0.25,1.1)
	camera_manual = 4

func update_camera(delta):
	if not is_instance_valid(player): return
	if ending_time>=0:
		camera.position = camera.position.lerp(player.position+Vector3(0,10,14),delta*0.5)
		camera.look_at(player.position+Vector3(0,4,-18))
		return
	if not playing: return
	camera_manual = maxf(0,camera_manual-delta)
	var stick = Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y))
	if stick.length()>0.2 and not menu_open: orbit(stick*delta*400)
	# A restrained heading bias avoids disorienting movement-relative feedback.
	if settings.smart and camera_manual<=0 and player.velocity.length()>0.8:
		camera_yaw = lerp_angle(camera_yaw,clampf(atan2(-player.facing.x,-player.facing.z),-0.35,0.35),delta*0.35)
	var target = player.position+Vector3(0,1.3,0)
	var distance = 15.5 if region==4 else 12.5
	var offset = Vector3(0,sin(camera_pitch)*distance,cos(camera_pitch)*distance).rotated(Vector3.UP,camera_yaw)
	var desired = target+offset
	desired.x = clampf(desired.x,-20,20)
	var query = PhysicsRayQueryParameters3D.create(target,desired)
	query.exclude = [player.get_rid()]
	var collision = get_world_3d().direct_space_state.intersect_ray(query)
	if not collision.is_empty(): desired = collision.position+collision.normal*0.4
	camera.position = camera.position.lerp(desired,1-exp(-delta*7))
	camera_shake = maxf(0,camera_shake-delta*2)
	if camera_shake>0: camera.position += Vector3(randf_range(-1,1),randf_range(-1,1),0)*camera_shake*settings.shake
	camera.look_at(target)

func attack(secondary: bool):
	var definition = ability()
	var damage = definition.damage*(1.35 if form=="Predator" else 1.0)
	var reach = definition.reach
	if has_synergy("heat","electric"): damage*=1.35
	if secondary:
		player.secondary_cd = 3.5 if form=="Arcane" else 5
		damage *= 1.8*(1.4 if form=="Arcane" else 1.0)
		reach = 7 if not "electric" in equipped else 12
	else: player.attack_cd = definition.cooldown*(0.75 if form=="Arcane" else 1.0)
	var facing = player.facing
	var nearest
	var best = reach+1
	for c in creatures:
		if not is_instance_valid(c) or c.dead: continue
		var offset = c.position-player.position
		var dist = offset.length()
		if dist<best and facing.dot(offset.normalized())>0.25:
			nearest = c
			best = dist
	if settings.assist and is_instance_valid(nearest): facing = (nearest.position-player.position).normalized()
	var color = traits[equipped[0]].tint if not equipped.is_empty() else Color("a8ffe0")
	burst(player.position+Vector3.UP+facing*1.2,color,12 if secondary else 6)
	sound.play("attack",0.7 if secondary else 1.2)
	var hits = 0
	for c in creatures:
		if not is_instance_valid(c) or c.dead: continue
		var offset = c.position-player.position
		var allowed = reach+(2 if c.boss else 0)
		if offset.length()<allowed and (secondary or facing.dot(offset.normalized())>0.15):
			c.hit(damage,color)
			if "venom" in equipped: c.poison = 4
			if "heat" in equipped: c.burn = 3
			if definition.id == "arc" or secondary: beam(player.position+Vector3.UP,c.position+Vector3.UP,color)
			if not c.boss: c.position += offset.normalized()*0.3
			hits += 1
			in_combat = 4
			if not secondary and definition.id=="arc": break
	if secondary and has_synergy("echo","electric"):
		for c in creatures:
			if is_instance_valid(c) and not c.dead and c.position.distance_to(player.position)<16:
				c.hit(12,color)
				beam(player.position+Vector3.UP,c.position+Vector3.UP,color)
	if hits>0:
		camera_shake = 0.3
		sound.play("hit",randf_range(0.85,1.15))
	player.visual.scale.y *= 0.78

func hurt(amount: float):
	if player.invulnerable>0 or ending_time>=0: return
	if "armor" in equipped: amount *= 0.7
	if form=="Bulwark": amount *= 0.8
	health -= amount
	in_combat = 5
	if amount>1:
		player.invulnerable = 0.3
		camera_shake = 0.4
		sound.play("hurt")
	if has_synergy("regen","venom"):
		for c in creatures:
			if is_instance_valid(c) and not c.dead and c.position.distance_to(player.position)<5: c.poison=4
	if health<=0:
		stats.deaths += 1
		respawn()

func respawn():
	player.position = world.pools[checkpoint]+Vector3(3,1,0)
	player.velocity = Vector3.ZERO
	player.invulnerable = 3
	health = max_health()
	in_combat = 0
	devour_progress = 0
	clear_projectiles()
	for c in creatures:
		if is_instance_valid(c) and c.boss and not c.dead:
			c.health = c.data.max_health
			c.phase = 1
			c.position = c.home
			c.visual.scale = Vector3.ONE*3.3
			c.copied = ""
	echo("MEMORY RECONSTRUCTED","Your adaptations remain. Try a different body.")
	save_game()

func update_devour(delta):
	var candidate
	var nearest = 3.4
	for c in creatures:
		if is_instance_valid(c) and c.dead and not c.consumed:
			var d = c.position.distance_to(player.position)
			if d < nearest+(3 if c.boss else 0):
				candidate = c
				nearest = d
	if candidate != devour_target:
		devour_progress = 0
		devour_toggle = false
	devour_target = candidate
	if not is_instance_valid(candidate): return
	if settings.toggle_devour and Input.is_action_just_pressed("devour"): devour_toggle = not devour_toggle
	if Input.is_action_pressed("devour") or devour_toggle:
		if devour_progress == 0: sound.play("devour")
		devour_progress += delta*(1.6 if form=="Predator" else 1.0)
		candidate.visual.scale.x = maxf(0.1,1-devour_progress*0.5)*(3.3 if candidate.boss else 1)
		candidate.visual.scale.z = candidate.visual.scale.x
		if Engine.get_process_frames()%5==0: beam(candidate.position+Vector3.UP,player.position+Vector3.UP,Color("a0ffe2"))
		if devour_progress>=1.4: consume(candidate)
	else:
		devour_progress = maxf(0,devour_progress-delta*2)
		candidate.visual.scale.x = 3.3 if candidate.boss else 1
		candidate.visual.scale.z = candidate.visual.scale.x

func consume(c):
	c.consumed = true
	stats.devoured += 1
	essence += c.data.essence_reward
	health = minf(max_health(),health+14)
	consumed_ids.append(c.index)
	burst(c.position+Vector3.UP,Color("a4ffe4"),20)
	if c.boss:
		boss_killed = true
		finish()
	elif not c.data.trait_reward in discovered:
		var id = c.data.trait_reward
		discovered.append(id)
		essence += 12
		echo("TRAIT ANALYZED  /  "+traits[id].display_name.to_upper(),traits[id].description+" Open Body to integrate it.")
		sound.play("trait")
	else: echo("BIOLOGICAL ESSENCE ABSORBED","+%d Essence  ·  +14 health" % c.data.essence_reward)
	creatures.erase(c)
	c.queue_free()
	devour_target = null
	devour_progress = 0
	devour_toggle = false
	save_game()

func equip(id: String) -> bool:
	if in_combat>0: return false
	if id in equipped: equipped.erase(id)
	elif id in discovered and used_capacity()+traits[id].core_cost<=capacity(): equipped.append(id)
	else: return false
	player.rebuild()
	for recipe in SYNERGIES:
		if has_synergy(recipe[0],recipe[1]) and not recipe[2] in synergies:
			synergies.append(recipe[2])
			essence += 20
			echo("SYNERGY DISCOVERED  /  "+recipe[2].to_upper(),recipe[3])
			sound.play("trait",1.25)
			burst(player.position+Vector3.UP,Color("edcc91"),20)
	save_game()
	return true

func near_pool() -> bool: return player.position.distance_to(world.pools[checkpoint])<4.5

func evolve(choice: String) -> bool:
	if form!="Wisp" or essence<180 or not near_pool(): return false
	form = choice
	health = max_health()
	player.rebuild()
	sound.play("evolve")
	burst(player.position+Vector3.UP,Color("eddda6"),36)
	echo("EVOLUTION COMPLETE  /  "+form.to_upper(),"You are no longer the smallest thing in the Hollow.")
	save_game()
	return true

func finish():
	completed = true
	if stats.best<=0 or stats.time<stats.best: stats.best = stats.time
	save_game()
	ending_time = 0
	player.position = Vector3(0,0,-232)
	health = max_health()
	echo("PRIMORDIAL CORE ACQUIRED","Core capacity insufficient. Evolution path unknown.")
	sound.play("evolve",0.65)
	# A distant world, visible only beyond the final root.
	var horizon = Node3D.new()
	add_child(horizon)
	for i in range(12):
		Art.shape(horizon,"cone",Vector3((i-6)*10,-3,-270-abs(i-6)*3),Vector3(16,18+sin(i)*6,14),Color("668e91"))
	for i in range(9):
		Art.shape(horizon,"box",Vector3(12+i%3*2,-1,-254-i/3*2),Vector3(1,1.5,1),Color("a9b3a0"))
		Art.shape(horizon,"sphere",Vector3(13+i%3*2,3+i*0.7,-256-i/3*2),Vector3(0.6,1.5,0.6),Color("9dafaf"))
	Art.shape(horizon,"sphere",Vector3(-12,18,-287),Vector3(10,10,1),Color("eedbb3"),1)
	Art.label(horizon,"MULTIPLE UNKNOWN LIFE FORMS DETECTED\nINTELLIGENT CIVILIZATION DETECTED\nANALYSIS IMPOSSIBLE AT CURRENT RANGE",Vector3(0,8,-250),Color("e4e8c8"),33)

func echo(title: String, message: String):
	echo_time = 7
	if is_instance_valid(hud): hud.set_echo(title,message)

func save_game():
	if test_mode: return
	var bindings = {}
	for action in InputSetup.KEYS:
		bindings[action] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				bindings[action].append(event.physical_keycode)
	if playing:
		saved = {"version":1,"settings":settings,"bindings":bindings,"essence":essence,"form":form,"equipped":equipped,"discovered":discovered,"synergies":synergies,"secrets":secrets,"consumed_ids":consumed_ids,"checkpoint":checkpoint,"stats":stats,"completed":completed,"boss_killed":boss_killed}
	else:
		saved["version"] = 1
		saved["settings"] = settings
		saved["bindings"] = bindings
	if not SaveStore.write_save(saved): echo("SAVE UNAVAILABLE","This browser has denied local storage. Keep this tab open to preserve this run.")

func bind_key(action: String, code: int):
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: InputMap.action_erase_event(action,event)
	var event = InputEventKey.new()
	event.physical_keycode = code
	InputMap.action_add_event(action,event)

func apply_quality():
	var low = settings.quality == "Low" or (settings.quality == "Auto" and OS.has_feature("web_android"))
	get_viewport().scaling_3d_scale = 0.65 if low else (0.85 if settings.quality=="Medium" else 1.0)
	for child in world.get_children():
		if child is DirectionalLight3D: child.shadow_enabled = not low
	sound.volume = settings.volume

func projectile(from: Vector3,to: Vector3,damage: float,color: Color,friendly: bool):
	if projectiles.size()>=48: return
	var node = Art.shape(self,"sphere",from,Vector3.ONE*0.3,color,1)
	projectiles.append({"node":node,"velocity":(to-from).normalized()*8,"life":4.0,"damage":damage,"friendly":friendly})

func update_projectiles(delta):
	for shot in projectiles.duplicate():
		shot.life-=delta
		shot.node.position += shot.velocity*delta
		if shot.node.position.distance_to(player.position+Vector3.UP*0.5)<0.9:
			hurt(shot.damage)
			shot.life=0
		if shot.life<=0:
			shot.node.queue_free()
			projectiles.erase(shot)

func clear_projectiles():
	for shot in projectiles: shot.node.queue_free()
	projectiles.clear()

func burst(pos: Vector3,color: Color,count: int):
	if settings.quality == "Low": count = int(count/2)
	for i in range(mini(count,100-effects.size())):
		var node = Art.shape(self,"sphere",pos,Vector3.ONE*randf_range(0.06,0.17),color,0.8)
		effects.append({"node":node,"velocity":Vector3(randf_range(-2,2),randf_range(1,3),randf_range(-2,2)),"life":randf_range(0.3,0.7),"kind":"particle"})

func beam(from: Vector3,to: Vector3,color: Color):
	var node = Art.shape(self,"cylinder",(from+to)*0.5,Vector3(0.045,from.distance_to(to)*0.5,0.045),color,1)
	if from.distance_to(to)>0.01:
		node.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
	effects.append({"node":node,"velocity":Vector3.ZERO,"life":0.16,"kind":"beam"})

func damage_text(pos: Vector3,message: String,color: Color):
	var node = Art.label(self,message,pos,color,30)
	effects.append({"node":node,"velocity":Vector3.UP,"life":0.65,"kind":"text"})

func update_effects(delta):
	if menu_open: return
	for effect in effects.duplicate():
		effect.life-=delta
		effect.node.position+=effect.velocity*delta
		if effect.kind=="particle": effect.node.scale*=1-delta*2
		if effect.life<=0:
			effect.node.queue_free()
			effects.erase(effect)

func self_test():
	start_run(false)
	assert(playing and health==100)
	discovered = TRAITS.duplicate()
	assert(equip("armor"))
	assert(equip("legs"))
	assert("Meteor Slam" in synergies)
	assert(equip("regen"))
	assert(not equip("electric"))
	assert(used_capacity()==9)
	essence = 180
	player.position = world.pools[0]
	assert(evolve("Arcane"))
	assert(capacity()==16)
	assert(equip("electric"))
	var victim = creatures[0]
	victim.hit(999,Color.WHITE)
	assert(victim.dead)
	consume(victim)
	assert(stats.devoured==1)
	var before = discovered.duplicate()
	respawn()
	assert(discovered==before and health==max_health())
	for action in InputSetup.KEYS: assert(InputMap.has_action(action))
	spawn_region(4)
	var boss
	for c in creatures:
		if c.boss: boss=c
	assert(boss!=null)
	player.position = boss.position+Vector3(0,0,9)
	boss.health=boss.data.max_health*0.6
	boss._process(0.01)
	assert(boss.phase==2)
	boss.health=boss.data.max_health*0.3
	boss._process(0.01)
	assert(boss.phase==3 and boss.copied!="")
	boss.hit(9999,Color.WHITE)
	consume(boss)
	assert(completed and boss_killed)
	var payload = {"version":1,"checkpoint":3,"equipped":["armor"]}
	var json = JSON.parse_string(JSON.stringify(payload))
	assert(json.checkpoint==3 and json.equipped[0]=="armor")
	DirAccess.make_dir_recursive_absolute("res://build")
	assert(SaveStore.write_save(payload,"res://build/test-save.json"))
	assert(SaveStore.read_save("res://build/test-save.json").checkpoint==3)
	DirAccess.remove_absolute("res://build/test-save.json")
	# Exercise real physics input and the held Devour action across frames.
	start_run(false)
	var origin = player.position
	Input.action_press("move_forward")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("move_forward")
	assert(player.position.distance_to(origin)>1.5)
	var prey = creatures[0]
	prey.position = player.position+Vector3(0,0,-1.5)
	prey.home = prey.position
	player.facing = Vector3.FORWARD
	Input.action_press("action_primary")
	await get_tree().create_timer(1.5).timeout
	Input.action_release("action_primary")
	assert(prey.dead)
	player.position = prey.position+Vector3(0,0,0.6)
	Input.action_press("devour")
	await get_tree().create_timer(1.6).timeout
	Input.action_release("devour")
	assert(stats.devoured==1)
	print("SELF_TEST_PASS: input, traits, capacity, synergy, evolution, devour, respawn, boss, ending, serialization")
	get_tree().quit()
