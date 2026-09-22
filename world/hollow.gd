extends Node3D

const Art = preload("res://world/art.gd")
const NAMES = ["AWAKENING CAVERN","FUNGAL GROTTO","SUNKEN RUINS","VERDANT BASIN","ANCIENT NEST"]
const COLORS = [Color("285155"),Color("413e62"),Color("466366"),Color("376354"),Color("493e50")]
var game
var loaded: Dictionary = {}
var pools: Array[Vector3] = []

func _ready():
	for i in range(5): pools.append(Vector3(-9,0,-i*48+8))
	var env = WorldEnvironment.new()
	var atmosphere = Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color("10272f")
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("91cec6")
	atmosphere.ambient_light_energy = 0.5
	atmosphere.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = Color("1b3940")
	atmosphere.fog_density = 0.009
	env.environment = atmosphere
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.light_color = Color("c3f0cb")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48
	add_child(sun)
	var floor_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(52,1,266)
	collision.shape = box
	floor_body.position = Vector3(0,-0.5,-108)
	floor_body.add_child(collision)
	add_child(floor_body)
	var outskirts=Art.shape(self,"box",Vector3(0,-2.0,-105),Vector3(350,0.5,500),Color("1c393d"))
	outskirts.visibility_range_end=0
	for i in range(18):
		var mountain=Art.shape(self,"cone",Vector3((-1 if i%2==0 else 1)*(65+i%3*18),8,-220+i*16),Vector3(25,14+i%4*4,35),Color("304f51"))
		mountain.visibility_range_end=0
	stream(0)

func stream(region: int):
	var radius=2 if game.growth.size_value()>=4.7 else 1
	for id in loaded.keys():
		if absi(id-region)>radius:
			loaded[id].queue_free()
			loaded.erase(id)
	for id in range(maxi(0,region-radius),mini(5,region+radius+1)):
		if not loaded.has(id): make_region(id)

func make_region(id: int):
	var root = Node3D.new()
	add_child(root)
	loaded[id] = root
	var rng = RandomNumberGenerator.new()
	rng.seed = 718+id*73
	var z = -id*48.0
	var ground = Art.shape(root,"box",Vector3(0,-0.6,z-5),Vector3(49,1.15,50),COLORS[id].darkened(0.4))
	ground.visibility_range_end=0
	var ground_mat = ShaderMaterial.new()
	ground_mat.shader = preload("res://world/ground.gdshader")
	ground_mat.set_shader_parameter("base_color",COLORS[id].darkened(0.38))
	ground.material_override = ground_mat
	# Ribbed stone gateways connect the five chambers.
	if id>0:
		for x in [-7,7]:
			Art.shape(root,"cylinder",Vector3(x,4,z+14),Vector3(1.2,4,1.2),Color("506866"))
			Art.shape(root,"box",Vector3(x,8,z+14),Vector3(2.2,0.6,2.2),Color("849286"))
		Art.shape(root,"box",Vector3(0,8.5,z+14),Vector3(16,0.9,1.8),Color("6e8075"))
		Art.label(root,"LIVING MEMBRANE  /  GROW TO %.1f m" % (game.growth.GATES[id]*1.25),Vector3(0,3.5,z+15),Color("d2e6bf"),24)
	populate_food(root,id,rng)
	add_motes(root,id,rng)
	# A winding luminous trail makes the next region legible.
	for j in range(15):
		var p = Vector3(sin(j*0.45+id)*3,0.018,z+17-j*3.2)
		Art.shape(root,"sphere",p,Vector3(2.8,0.018,2),COLORS[id].lightened(0.08))
		if j%3==0: Art.shape(root,"sphere",p+Vector3(2,0.04,0),Vector3(0.1,0.06,0.1),Color("abefd3"),1)
	for i in range(52):
		var x = rng.randf_range(-24,24)
		var p = Vector3(x,0,z+rng.randf_range(-27,20))
		if absf(x)<20: continue
		var scale_size = rng.randf_range(0.7,2.3)
		if absf(x)>20:
			var rock = Art.shape(root,"sphere",p+Vector3(0,2,0),Vector3(scale_size*3,scale_size*4,scale_size*3),COLORS[id].darkened(0.25))
			rock.rotation.y = rng.randf()*TAU
		elif id == 2 and i%3 == 0:
			Art.shape(root,"box",p+Vector3(0,1.8,0),Vector3(1.1,3.6,1.1),Color("78928c"))
			Art.shape(root,"box",p+Vector3(0,3.7,0),Vector3(1.6,0.3,1.6),Color("b1b99b"))
		elif id in [0,1] or i%4==0:
			Art.shape(root,"cylinder",p+Vector3(0,scale_size*0.6,0),Vector3(0.16,scale_size*0.6,0.16),Color("72968c"))
			Art.shape(root,"sphere",p+Vector3(0,scale_size*1.2,0),Vector3(scale_size,0.23*scale_size,scale_size),Color("65bdae") if id == 0 else Color("af8cce"),0.45)
		else:
			Art.shape(root,"cone",p+Vector3(0,2,0),Vector3(0.8,2.6,0.8),Color("324e45"))
			for h in range(2): Art.shape(root,"sphere",p+Vector3(0,3+h,0),Vector3(scale_size*2,1.3,scale_size*2),Color("436f57") if id==3 else Color("705567"))
	for i in range(40):
		var p = Vector3(rng.randf_range(-20,20),0,z+rng.randf_range(-26,18))
		for j in range(3):
			var grass = Art.shape(root,"cone",p+Vector3(j*0.13,0.22,0),Vector3(0.12,0.3+rng.randf()*0.2,0.14),Color("609785") if id!=4 else Color("a4778f"))
			grass.rotation.z = rng.randf_range(-0.3,0.3)
	var pool = pools[id]
	Art.shape(root,"cylinder",pool+Vector3(0,0.025,0),Vector3(4.5,0.02,4.5),Color("438d89"),0.6)
	Art.shape(root,"torus",pool+Vector3(0,0.1,0),Vector3(2.5,0.22,2.5),Color("acdcc7"),0.5)
	Art.shape(root,"cone",pool+Vector3(0,1.8,0),Vector3(0.75,1.0,0.75),Color("9affdb"),1.5)
	Art.shape(root,"cone",pool+Vector3(0,0.8,0),Vector3(0.75,0.5,0.75),Color("68c7c6"),1).rotation.z=PI
	Art.label(root,"MEMORY POOL",pool+Vector3(0,3.3,0),Color("b9ffe4"),27)
	Art.label(root,NAMES[id],Vector3(0,5,z+16),Color("c6ddce"),34)
	if id == 1:
		for p in [Vector3(8,0,z-8),Vector3(-15,0,z-18)]:
			Art.shape(root,"cylinder",p+Vector3(0,0.03,0),Vector3(4,0.015,4),Color("807d45"),0.15)
	if id == 4:
		Art.shape(root,"cone",Vector3(0,8,z-17),Vector3(7,9,6),Color("423d40"))
		for i in range(8):
			var limb = Art.shape(root,"cone",Vector3(sin(i)*4,3,z-17+cos(i)*3),Vector3(1.4,6,1.4),Color("664c53"))
			limb.rotation.z=sin(i)*0.7
	# Optional hidden alcove rewards exploration in every biome.
	var secret = Vector3(18,0.7,z-16)
	Art.shape(root,"torus",secret,Vector3(0.8,0.8,0.8),Color("f1cf86"),1.2)
	Art.label(root,"ECHO RELIC",secret+Vector3.UP*1.6,Color("f1cf86"),22)

func populate_food(root: Node3D,id: int,rng: RandomNumberGenerator):
	var menus=[
		["dew","dew","seed","seed","fungus","crystal"],
		["seed","fungus","fungus","crystal","crystal","boulder"],
		["fungus","crystal","boulder","boulder","tree","ruin"],
		["crystal","boulder","tree","tree","ruin","ancient_root"],
		["boulder","tree","ruin","ruin","ancient_root","ancient_root"]
	]
	for i in range(48):
		var uid=10000+id*100+i
		if uid in game.growth.consumed: continue
		var type=menus[id][i%6]
		var item=preload("res://world/edible.gd").new()
		item.game=game
		item.uid=uid
		item.data=game.growth.data[type]
		var x=rng.randf_range(-18,18)
		var z=-id*48+rng.randf_range(-26,12)
		if i<10 and id==0:
			x=-6+sin(i*0.9)*1.4
			z=7-i*1.4
			item.data=game.growth.data["dew" if i<3 else "seed"]
		if Vector3(x,0,z).distance_to(pools[id])<3.6: x+=5
		# Keep the memory puzzle route free of oversized edible colliders.
		if x>2 and z>-id*48-18 and z<-id*48-3: x=-absf(x)-1
		item.position=Vector3(x,0,z)
		root.add_child(item)

func add_motes(root: Node3D,id: int,rng: RandomNumberGenerator):
	var swarm=MultiMeshInstance3D.new()
	var multi=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_custom_data=true
	var mesh=SphereMesh.new()
	mesh.radial_segments=6
	mesh.rings=3
	multi.mesh=mesh
	multi.instance_count=48
	for i in range(48):
		var basis=Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(0.045,0.09))
		multi.set_instance_transform(i,Transform3D(basis,Vector3(rng.randf_range(-21,21),rng.randf_range(0.5,6),-id*48+rng.randf_range(-24,18))))
		multi.set_instance_custom_data(i,Color(rng.randf(),0,0))
	swarm.multimesh=multi
	var mat=ShaderMaterial.new()
	mat.shader=preload("res://world/motes.gdshader")
	mat.set_shader_parameter("motion",game.settings.motion)
	swarm.material_override=mat
	root.add_child(swarm)
