extends Node3D

const Art = preload("res://world/art.gd")
var game
var data: CreatureData
var health: float
var visual: Node3D
var caption: Label3D
var ring: MeshInstance3D
var home: Vector3
var state: String = "WANDER"
var state_time: float = 0
var cooldown: float = 2
var poison: float = 0
var burn: float = 0
var status_tick: float = 0
var dead: bool = false
var consumed: bool = false
var boss: bool = false
var phase: int = 1
var copied: String = ""
var wander_dir = Vector3.FORWARD
var age: float = 0
var index: int = 0
var dissolve: float = 0
var target_pos: Vector3

func _ready():
	health = data.max_health
	home = position
	visual = Art.organism(self,data.silhouette,data.tint,boss)
	visual.scale = Vector3.ONE*(8.0 if boss else data.body_size)
	caption = Art.label(self,data.display_name,Vector3(0,2.4*data.body_size if not boss else 18,0),Color("e9f4db"),25 if not boss else 38)
	ring = Art.shape(self,"torus",Vector3(0,0.08,0),Vector3(1.4,0.13,1.4),Color("ff946d"),0.6)
	ring.visible = false
	cooldown = randf_range(1,3)
	wander_dir = Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized()

func _process(delta):
	if game == null or not game.playing or game.menu_open: return
	age += delta
	if dead:
		visual.scale.y = lerpf(visual.scale.y,data.body_size*0.2 if not boss else 1.6,delta*7)
		caption.text = ("ROOT FRAGMENT" if boss else data.display_name.to_upper()) + "  ·  DEVOUR"
		caption.modulate = Color("97f8d2")
		return
	var distance = position.distance_to(game.player.position)
	caption.visible = distance < (24 if "echo" in game.equipped else 12) or boss
	if distance > 35: return
	state_time += delta
	cooldown -= delta
	status_tick += delta
	if status_tick > 0.5:
		status_tick = 0
		if poison > 0: hit(2.8,Color("c391ef"),false)
		if burn > 0: hit(3.5,Color("ff9b62"),false)
	poison = maxf(poison-delta,0)
	burn = maxf(burn-delta,0)
	if dead: return
	if boss:
		var next_phase = 3 if health < data.max_health*0.33 else (2 if health < data.max_health*0.66 else 1)
		if next_phase > phase:
			phase = next_phase
			game.echo("PREDATORY ADAPTATION", "It is consuming the nest." if phase == 2 else "It has analyzed your body.")
			game.burst(position+Vector3.UP*3,Color("e99ad6"),28)
			game.sound.play("boss",0.6)
			visual.scale *= 1.12
			if phase == 2:
				for other in game.creatures:
					if other != self and is_instance_valid(other) and not other.dead and position.distance_to(other.position)<18:
						other.hit(999,Color("c391ef"))
						health = minf(data.max_health,health+15)
			if phase == 3 and not game.equipped.is_empty(): copied = game.equipped[0]
	if state == "STUNNED":
		if state_time > 0.22: state = "CHASE"
		return
	var toward = game.player.position-position
	toward.y = 0
	var attack_range = (10.0 if boss else (8.0 if data.behavior_type == "ranged" else data.body_size+game.growth.display_size*0.5))
	if state == "ATTACK":
		ring.visible = true
		var warning = 1.25 if boss else 0.85
		ring.scale = Vector3.ONE*(attack_range*(0.75+0.25*state_time/warning))
		ring.scale.y = 0.12
		visual.position.y = sin(state_time/warning*PI)*0.4
		if state_time >= warning:
			ring.visible = false
			if boss or data.behavior_type == "ranged":
				game.projectile(position+Vector3.UP, target_pos+Vector3.UP,data.damage*(1+0.18*(phase-1)),data.tint,false)
				if boss and phase>=2:
					for offset in [-0.45,0.45]: game.projectile(position+Vector3.UP,position+Vector3.UP+toward.rotated(Vector3.UP,offset),data.damage,data.tint,false)
			if distance < attack_range and data.behavior_type != "ranged":
				game.hurt(data.damage*(1.3 if copied == "heat" else 1.0))
				game.burst(position,Color("d3aa7b"),12)
			if copied == "venom" and distance<9: game.hurt(3)
			state = "CHASE"
			cooldown = 2.8 if boss else 1.8
			state_time = 0
		return
	var move = Vector3.ZERO
	if not boss and game.growth.size_value()>data.body_size*1.6 and distance<14:
		state="FLEE"
		move=-toward.normalized()
	elif data.behavior_type == "graze":
		state = "FLEE" if health < data.max_health and distance<9 else "GRAZE"
		move = -toward.normalized() if state == "FLEE" else wander_dir*0.25
	elif distance < (18 if boss else 12):
		state = "CHASE"
		if distance > attack_range*0.75: move = toward.normalized()
		if distance < attack_range+1 and cooldown <= 0:
			state = "ATTACK"
			state_time = 0
			target_pos = game.player.position
	else:
		state = "WANDER"
		move = wander_dir*0.32
		# Predators also hunt grazers; this does not award player kills.
		if data.behavior_type == "hunt" and cooldown<=0:
			for other in game.creatures:
				if is_instance_valid(other) and not other.dead and other.data.behavior_type == "graze" and position.distance_to(other.position)<7:
					move = (other.position-position).normalized()
					if position.distance_to(other.position)<1.9:
						other.hit(data.damage,data.tint,false)
						cooldown = 2.5
					break
	if position.distance_to(home)>12 and state in ["WANDER","GRAZE"]: move = (home-position).normalized()*0.5
	position += move*data.movement_speed*delta
	position.x = clampf(position.x,-21,21)
	position.z = clampf(position.z,home.z-16,home.z+16)
	if move.length()>0.1: visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-move.x,-move.z),delta*7)
	visual.position.y = absf(sin(age*(7 if data.behavior_type == "leap" else 4)))*(0.65 if data.silhouette == "bat" else 0.10)
	caption.text = data.display_name + ("  /  SWALLOW WHOLE" if not boss and game.growth.size_value()>=data.body_size*(1.45 if game.form=="Predator" else 1.8) else ("  %d" % health if health<data.max_health else ""))

func hit(amount: float, color: Color, credited: bool = true):
	if dead: return
	if data.id == "shell": amount *= 0.75
	if copied == "armor": amount *= 0.8
	health -= amount
	game.burst(position+Vector3.UP,color,4)
	if game.settings.numbers: game.damage_text(position+Vector3.UP*1.5,str(int(amount)),color)
	if not boss and state != "ATTACK":
		state = "STUNNED"
		state_time = 0
	if health <= 0:
		dead = true
		ring.visible = false
		if credited:
			game.stats.kills += 1
			game.essence += int(data.essence_reward*0.3)
		if boss:
			game.echo("THE ROOT FALLS", "Hold Devour beside its remains. Take the Primordial Core.")
		game.sound.play("hit",0.65)
