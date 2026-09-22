extends Node

const TYPES = ["dew","seed","fungus","crystal","boulder","tree","ruin","ancient_root"]
const GATES = [0.0,1.8,3.0,4.7,6.5]
const STAGES = [0.6,1.0,1.8,3.0,4.7,6.5,9.0,12.0]
const TITLES = ["DROPLET","FORAGER","GULPER","HEAVYWEIGHT","LANDSHAPER","COLOSSUS","HOLLOW TITAN","LIVING WORLD"]
var game
var mass: float = 0.216
var display_size: float = 0.6
var consumed: Array = []
var items: Array = []
var data: Dictionary = {}
var objects_eaten: int = 0
var biggest: String = "Dew bead"
var biggest_size: float = 0
var combo: int = 0
var combo_clock: float = 0
var suction_time: float = 0
var stage: int = 0
var target
var scan_clock: float = 0

func _ready():
	for id in TYPES: data[id] = load("res://data/edible_%s.tres" % id)

func size_value() -> float: return pow(maxf(0.216,mass),1.0/3.0)

func reset(snapshot: Dictionary = {}):
	mass = float(snapshot.get("mass",0.216))
	display_size = size_value()
	consumed = snapshot.get("consumed",[]).duplicate()
	objects_eaten = int(snapshot.get("objects_eaten",0))
	biggest = snapshot.get("biggest","Dew bead")
	biggest_size = float(snapshot.get("biggest_size",0))
	combo = 0
	combo_clock = 0
	stage = stage_index()
	target = null

func snapshot() -> Dictionary:
	return {"mass":mass,"consumed":consumed,"objects_eaten":objects_eaten,"biggest":biggest,"biggest_size":biggest_size}

func stage_index() -> int:
	var result = 0
	for i in range(STAGES.size()):
		if size_value()+0.001>=STAGES[i]: result = i
	return result

func requirement(item: EdibleData) -> float:
	var threshold = item.required_size
	if game.form=="Bulwark": threshold*=0.85
	if item.family=="plant":
		if "heat" in game.equipped: threshold*=0.8
		if "venom" in game.equipped: threshold*=0.85
	elif item.family=="mineral" and "armor" in game.equipped: threshold*=0.8
	return threshold

func can_eat(item: EdibleData) -> bool: return size_value()+0.005>=requirement(item)

func add_mass(amount: float,source: String,source_size: float):
	mass = minf(2744.0,mass+amount*(1.12 if "regen" in game.equipped else 1.0))
	if source_size>biggest_size:
		biggest_size=source_size
		biggest=source
	var next = stage_index()
	if next>stage:
		stage=next
		game.echo("GROWTH MILESTONE  /  "+TITLES[stage],"You are %.1f m wide. Familiar obstacles are becoming food." % (size_value()*1.25))
		game.sound.play("evolve",1.35-stage*0.08)
		game.burst(game.player.position+Vector3.UP*display_size,Color("d8f0a3"),24)
		game.camera_shake=0.18
		game.world.stream(game.region)

func _process(delta):
	if not is_instance_valid(game.player) or not game.playing or game.menu_open or game.ending_time>=0: return
	display_size = lerpf(display_size,size_value(),1-exp(-delta*3.5))
	combo_clock = maxf(0,combo_clock-delta)
	if combo_clock<=0: combo=0
	suction_time = maxf(0,suction_time-delta)
	scan_clock += delta
	if scan_clock<0.06: return
	scan_clock=0
	target=null
	var nearest = 6.0+display_size
	var body_radius = display_size*0.6
	for item in items.duplicate():
		if not is_instance_valid(item):
			items.erase(item)
			continue
		if item.absorbing: continue
		var offset = item.global_position-game.player.position
		offset.y=0
		var distance=offset.length()
		if distance>display_size*4+12: continue
		var reach = body_radius+item.data.body_size*0.45+0.3
		if "echo" in game.equipped: reach += 0.6+display_size*0.3
		if "electric" in game.equipped and item.data.family=="mineral": reach += 1.5+display_size*0.5
		if game.form=="Arcane": reach += 0.8+display_size*0.25
		if suction_time>0: reach += 2+display_size*0.6
		if distance<reach and can_eat(item.data) and game.player.position.y<body_radius+2:
			absorb(item)
		elif distance<nearest:
			nearest=distance
			target=item
	# A predator that once hunted you can become a mouthful.
	for creature in game.creatures.duplicate():
		if not is_instance_valid(creature) or creature.dead or creature.boss: continue
		var required = creature.data.body_size*(1.45 if game.form=="Predator" else 1.8)
		if size_value()<required: continue
		var distance = creature.position.distance_to(game.player.position)
		if distance<body_radius+creature.data.body_size*0.55:
			game.stats.kills+=1
			game.consume(creature)

func absorb(item):
	if item.absorbing: return
	item.begin_absorb()
	consumed.append(item.uid)
	objects_eaten+=1
	combo+=1
	combo_clock=4.0
	add_mass(item.data.biomass*(1.0+minf(combo,10)*0.04),item.data.display_name,item.data.required_size)
	game.essence += 1 if item.data.required_size<2 else 3
	game.health=minf(game.max_health(),game.health+0.6)
	game.sound.play("devour",minf(1.85,0.85+combo*0.05))
	if combo%5==0: game.damage_text(game.player.position+Vector3.UP*display_size*1.8,"%d ABSORBED" % combo,Color("c8f4b0"))
	game.player.add_morsel(item.data.tint)
