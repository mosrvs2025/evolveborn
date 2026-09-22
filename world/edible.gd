extends Node3D

const Art = preload("res://world/art.gd")
var game
var data: EdibleData
var uid: int
var visual: Node3D
var collider: StaticBody3D
var absorbing: bool = false
var absorb_clock: float = 0
var original_scale = Vector3.ONE
var caption: Label3D

func _ready():
	game.growth.items.append(self)
	visual=Node3D.new()
	add_child(visual)
	var s=data.body_size
	var color=data.tint
	match data.id:
		"dew":
			Art.shape(visual,"sphere",Vector3(0,s*0.5,0),Vector3.ONE*s,color,0.4)
		"seed":
			Art.shape(visual,"sphere",Vector3(0,s*0.4,0),Vector3(s,s*0.7,s*1.25),color)
			Art.shape(visual,"cone",Vector3(0,s*0.9,0),Vector3(s*0.3,s*0.45,s*0.3),color.lightened(0.2))
		"fungus":
			Art.shape(visual,"cylinder",Vector3(0,s*0.7,0),Vector3(s*0.3,s*0.7,s*0.3),Color("91b69c"))
			Art.shape(visual,"sphere",Vector3(0,s*1.45,0),Vector3(s*1.4,s*0.35,s*1.4),color,0.2)
		"crystal":
			for i in range(3):
				var shard=Art.shape(visual,"cone",Vector3((i-1)*s*0.3,s*0.65,0),Vector3(s*0.45,s*(0.6+i*0.15),s*0.45),color,0.35)
				shard.rotation.z=(i-1)*0.3
		"boulder":
			Art.shape(visual,"sphere",Vector3(0,s*0.55,0),Vector3(s*1.2,s,s),color)
			Art.shape(visual,"sphere",Vector3(s*0.25,s*0.85,0),Vector3(s*0.6,s*0.25,s*0.7),Color("85a472"))
		"tree":
			Art.shape(visual,"cone",Vector3(0,s*0.95,0),Vector3(s*0.5,s,s*0.5),Color("536952"))
			Art.shape(visual,"sphere",Vector3(0,s*2,0),Vector3(s*1.45,s,s*1.4),color)
			Art.shape(visual,"sphere",Vector3(s*0.3,s*2.5,0),Vector3(s,s*0.8,s),color.lightened(0.1))
		"ruin":
			Art.shape(visual,"box",Vector3(0,s*0.6,0),Vector3(s,s*1.2,s*0.8),color)
			Art.shape(visual,"box",Vector3(0,s*1.3,0),Vector3(s*1.35,s*0.25,s),color.lightened(0.1))
			Art.shape(visual,"sphere",Vector3(0,s*0.8,-s*0.42),Vector3(s*0.3,s*0.3,s*0.05),Color("9dedcd"),0.4)
		"ancient_root":
			for i in range(4):
				var branch=Art.shape(visual,"cone",Vector3((i-1.5)*s*0.22,s*0.6,0),Vector3(s*0.35,s*(0.8+i*0.14),s*0.4),color)
				branch.rotation.z=(i-1.5)*0.35
	if data.required_size>=1:
		collider=StaticBody3D.new()
		var collision=CollisionShape3D.new()
		var shape=CylinderShape3D.new()
		shape.radius=s*0.36
		shape.height=s*1.4
		collision.shape=shape
		collision.position.y=s*0.7
		collider.add_child(collision)
		add_child(collider)
	caption=Art.label(self,"",Vector3(0,s*1.8+0.6,0),Color("ebddb5"),23)
	caption.visible=false

func begin_absorb():
	absorbing=true
	if is_instance_valid(collider): collider.collision_layer=0
	absorb_clock=0

func _process(delta):
	if not game.playing or game.menu_open: return
	if absorbing:
		absorb_clock+=delta
		var destination=game.player.position+Vector3.UP*game.growth.display_size*0.75
		global_position=global_position.lerp(destination,1-exp(-delta*10))
		visual.scale=Vector3.ONE*maxf(0.03,1-absorb_clock/0.5)
		visual.rotation.y+=delta*7*game.settings.motion
		caption.visible=false
		if absorb_clock>0.5:
			game.growth.items.erase(self)
			queue_free()
	else:
		caption.visible=game.growth.target==self
		if caption.visible:
			caption.text=data.display_name.to_upper()+ ("  /  GLIDE TO ABSORB" if game.growth.can_eat(data) else "  /  NEED %.1f m" % (game.growth.requirement(data)*1.25))
			caption.modulate=Color("b3f8ca") if game.growth.can_eat(data) else Color("e6ba8e")
