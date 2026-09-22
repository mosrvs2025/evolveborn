extends CharacterBody3D

const Art = preload("res://world/art.gd")
var game
var visual: Node3D
var mutations: Node3D
var facing = Vector3.FORWARD
var dash_time: float = 0
var invulnerable: float = 0
var mobility_cd: float = 0
var attack_cd: float = 0
var secondary_cd: float = 0
var wobble: float = 0
var step_clock: float = 0
var body_collision: CollisionShape3D
var morsels: Array = []

func _ready():
	var collider = CollisionShape3D.new()
	body_collision=collider
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.1
	collider.shape = capsule
	collider.position.y = 0.6
	add_child(collider)
	visual = Node3D.new()
	add_child(visual)
	var body=Art.shape(visual,"sphere",Vector3(0,0.65,0),Vector3(1.25,0.78,1.3),Color("63c8b6"))
	body.mesh.radial_segments=32
	body.mesh.rings=16
	var jelly=ShaderMaterial.new()
	jelly.shader=preload("res://world/slime.gdshader")
	jelly.set_shader_parameter("motion",game.settings.motion)
	body.material_override=jelly
	Art.shape(visual,"sphere",Vector3(0,0.76,-0.38),Vector3(0.44,0.42,0.38),Color("baffce"),1.3)
	for x in [-0.26,0.26]:
		Art.shape(visual,"sphere",Vector3(x,0.87,-0.57),Vector3(0.13,0.14,0.1),Color("102c33"))
	mutations = Node3D.new()
	visual.add_child(mutations)

func rebuild():
	for child in mutations.get_children():
		mutations.remove_child(child)
		child.queue_free()
	var count = 0
	for id in game.equipped:
		var adaptation = game.traits[id]
		var angle = count*2.4
		var pos = Vector3(sin(angle)*0.53,0.9,cos(angle)*0.48)
		match id:
			"armor":
				for i in range(3): Art.shape(mutations,"sphere",Vector3((i-1)*0.34,1.05,0.15),Vector3(0.55,0.22,0.8),adaptation.tint)
			"legs":
				for x in [-1,1]: Art.shape(mutations,"sphere",Vector3(x*0.62,0.28,0.35),Vector3(0.55,0.5,0.8),adaptation.tint)
			"echo":
				for x in [-1,1]:
					Art.shape(mutations,"cone",Vector3(x*0.4,1.3,-0.1),Vector3(0.12,0.5,0.12),adaptation.tint)
					Art.shape(mutations,"sphere",Vector3(x*0.4,1.8,-0.1),Vector3.ONE*0.15,adaptation.tint,2)
			"shadow":
				for i in range(3): Art.shape(mutations,"cone",Vector3((i-1)*0.25,0.8,0.6),Vector3(0.2,0.35,0.4),adaptation.tint)
			_:
				Art.shape(mutations,"sphere",pos,Vector3.ONE*0.35,adaptation.tint,1.2)
		count += 1
	visual.scale = Vector3.ONE*game.growth.display_size
	if game.form == "Predator":
		for x in [-1,1]: Art.shape(mutations,"cone",Vector3(x*0.35,0.55,-0.67),Vector3(0.15,0.4,0.15),Color("f2dbb2"))
	if game.form == "Arcane": Art.shape(mutations,"torus",Vector3(0,1.5,0),Vector3.ONE*0.75,Color("b6a5ff"),1)
	if game.form == "Bulwark": Art.shape(mutations,"sphere",Vector3(0,1,0.25),Vector3(1.5,0.45,1.3),Color("dec195"))

func add_morsel(color: Color):
	while morsels.size()>=12:
		var old=morsels.pop_front()
		if is_instance_valid(old): old.queue_free()
	var bit=Art.shape(visual,"sphere",Vector3(randf_range(-0.5,0.5),randf_range(0.4,1),randf_range(-0.4,0.5)),Vector3.ONE*0.16,color,0.2)
	morsels.append(bit)
	var tween=create_tween()
	tween.bind_node(bit)
	tween.tween_property(bit,"scale",Vector3.ONE*0.02,2.0)
	tween.tween_callback(func(): morsels.erase(bit); bit.queue_free())

func _physics_process(delta):
	if game == null or not game.playing or game.menu_open or game.ending_time>=0: return
	wobble += delta
	attack_cd = maxf(0,attack_cd-delta)
	secondary_cd = maxf(0,secondary_cd-delta)
	mobility_cd = maxf(0,mobility_cd-delta)
	invulnerable = maxf(0,invulnerable-delta)
	var axis = Input.get_vector("move_left","move_right","move_forward","move_back")
	if game.touch_vector.length() > 0.1: axis = game.touch_vector
	var direction = Vector3(axis.x,0,axis.y).rotated(Vector3.UP,game.camera_yaw)
	var size=game.growth.display_size
	body_collision.shape.radius=0.5*size
	body_collision.shape.height=1.2*size
	body_collision.position.y=0.6*size
	var speed = 2.0+3.6*sqrt(size) + (1.2 if game.form == "Predator" else 0) + (0.7 if "shadow" in game.equipped else 0)
	if Input.is_action_just_pressed("mobility") and mobility_cd <= 0:
		dash_time = 0.27
		invulnerable = 0.65 if "shadow" in game.equipped else 0.4
		mobility_cd = 1.15 if "legs" in game.equipped else 1.9
		velocity.y = 7 if "legs" in game.equipped else 4
		game.sound.play("attack",0.65)
		game.burst(global_position+Vector3.UP,Color("83ffe2"),8)
	if direction.length() > 0.15: facing = direction.normalized()
	if dash_time > 0:
		dash_time -= delta
		velocity.x = facing.x*(12+size*1.4)
		velocity.z = facing.z*(12+size*1.4)
	else:
		velocity.x = move_toward(velocity.x,direction.x*speed,delta*35)
		velocity.z = move_toward(velocity.z,direction.z*speed,delta*35)
	if not is_on_floor(): velocity.y -= 20*delta
	else: velocity.y = minf(velocity.y,0)
	move_and_slide()
	position.x = clampf(position.x,-23+size*0.5,23-size*0.5)
	position.z = clampf(position.z,-236,19)
	if position.y < -8: game.respawn()
	visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-facing.x,-facing.z),delta*14)
	visual.scale = Vector3.ONE*size
	visual.scale.y = size*(1+sin(wobble*9)*0.06*game.settings.motion)
	visual.rotation.z=sin(wobble*6)*minf(axis.length(),1)*0.12*game.settings.motion
	if invulnerable > 0: visual.scale.y *= 0.83
	if axis.length()>0.1:
		step_clock += delta
		if step_clock > 0.4:
			step_clock = 0
			game.sound.play("step",randf_range(0.8,1.2))
	if Input.is_action_pressed("action_primary") and attack_cd <= 0: game.attack(false)
	if Input.is_action_just_pressed("action_secondary") and secondary_cd <= 0: game.attack(true)

