extends Node3D

const Art = preload("res://world/art.gd")
const TITLES = ["A name in the dark", "The garden's song", "A weight worth carrying", "The last courier", "What hunger remembers"]
const MEMORIES = [
	"LUMA: I was the Hollow's gardener. I made a tiny life to carry seeds through the dark. That life was you. Follow my lanterns; there is still something here worth saving.",
	"LUMA: We taught the garden to sing: seed, rain, sunlight. Then we built a guardian to eat the blight. We forgot to teach it when to stop.",
	"LUMA: The Root Devourer was our protector. When the blight was gone, it ate our bridges, our towers, our names. Your appetite is its gift. Your choices can be different.",
	"LUMA: I hid the last seeds inside these memories. You have been carrying a garden, not a weapon. Take it through the roots. Give the Hollow another morning.",
	"LUMA: I cannot leave this lantern. But you can. Face the guardian, carry our seeds beyond it, and grow into something we never imagined. I am glad I met you."
]
const HINTS = ["Touch lanterns 1 > 2 > 3", "A seed drinks rain before it sees the sun", "Grow to 4.4 m, then rest on the seal", "Touch 1 > 2 > 3 within 14 seconds; Burst helps", "Night (3), dawn (1), then day (2)"]
const ORDERS = [[0,1,2],[0,2,1],[0],[0,1,2],[2,0,1]]
var game
var solved: Array = []
var progress: int = 0
var timer: float = 0
var hold: float = 0
var current: int = -1
var last_pad: int = -1
var shrine: Node3D
var pads: Array = []
var captions: Array = []
var companion: Node3D
var clock: float = 0
var entered: bool = false

func _ready():
	companion = Node3D.new()
	add_child(companion)
	Art.shape(companion,"sphere",Vector3.ZERO,Vector3.ONE*0.23,Color("ffe3a1"),2)
	Art.shape(companion,"torus",Vector3.ZERO,Vector3.ONE*0.4,Color("e8bb75"),0.8).rotation.x=PI/2

func reset(data: Dictionary = {}):
	solved = data.get("solved",[]).duplicate()
	current = -1
	if is_instance_valid(shrine):
		remove_child(shrine)
		shrine.queue_free()
		shrine=null

func snapshot() -> Dictionary:
	return {"solved":solved.duplicate()}

func center(id: int) -> Vector3:
	return Vector3(10,0,-id*48-10)

func build(id: int):
	if is_instance_valid(shrine):
		remove_child(shrine)
		shrine.queue_free()
		shrine=null
	current=id
	progress=0
	timer=0
	hold=0
	last_pad=-1
	entered=false
	pads.clear()
	captions.clear()
	shrine=Node3D.new()
	add_child(shrine)
	var c=center(id)
	# A golden breadcrumb trail makes optional exploration discoverable.
	for j in range(8):
		var point=game.world.pools[id].lerp(c,float(j+1)/9.0)
		Art.shape(shrine,"sphere",point+Vector3(0,0.16,0),Vector3(0.19,0.12,0.19),Color("ffd48c"),0.6)
	for side in [-1,1]:
		var pillar=Art.shape(shrine,"cone",c+Vector3(side*3.3,1.5,-2),Vector3(0.65,1.6,0.65),Color("597b79"))
		pillar.rotation.z=side*0.23
		Art.shape(shrine,"sphere",c+Vector3(side*3.0,3,-2),Vector3.ONE*0.35,Color("efbf7e"),1)
	Art.shape(shrine,"cylinder",c+Vector3(0,0.04,0),Vector3(3,0.04,3),Color("314d60"))
	Art.shape(shrine,"torus",c+Vector3(0,0.12,0),Vector3(3.2,0.1,3.2),Color("e5be7e"),0.7)
	Art.label(shrine,"LUMA'S MEMORY\n"+HINTS[id],c+Vector3(0,4.8,0),Color("ffe6af"),25)
	for i in range(1 if id==2 else 3):
		var p=c+Vector3((i-1)*5,0,(2 if i==1 else -2)) if id!=2 else c
		pads.append(p)
		Art.shape(shrine,"cylinder",p+Vector3(0,0.09,0),Vector3(1.8,0.06,1.8),Color("4c6977"))
		Art.shape(shrine,"torus",p+Vector3(0,0.18,0),Vector3(1.9,0.12,1.9),Color("d7b77e"),0.8)
		Art.shape(shrine,"cone",p+Vector3(0,1.1,0),Vector3(0.5,0.6,0.5),Color("a0e6dc"),1)
		captions.append(Art.label(shrine,str(i+1),p+Vector3(0,2.3,0),Color("fff0c2"),38))
	refresh()

func refresh():
	for i in range(captions.size()):
		var lit=current in solved or i in ORDERS[current].slice(0,progress)
		captions[i].text="LIT" if lit else (["1 / SEED","2 / SUN","3 / RAIN"][i] if current==1 else str(i+1))
		captions[i].modulate=Color("a3ffd0") if lit else Color("fff0c2")

func touch_pad(index: int):
	if current in solved or current==2: return
	if index==ORDERS[current][progress]:
		progress+=1
		if current==3 and progress==1: timer=14
		game.sound.play("trait",0.8+progress*0.2)
		game.burst(pads[index]+Vector3.UP,Color("ffe3a1"),8)
		if progress==3: complete()
	else:
		progress=0
		timer=0
		game.echo("THE MELODY RESTARTS",HINTS[current]+". Step off the lantern to try again.")
	refresh()

func complete():
	if current in solved: return
	solved.append(current)
	game.essence+=45
	game.growth.add_mass([1.8,8.0,24.0,65.0,100.0][current],"Luma's seed",0)
	game.health=game.max_health()
	game.echo("MEMORY RESTORED  /  "+TITLES[current],MEMORIES[current]+" (+45 Essence)")
	game.echo_time=14
	game.sound.play("evolve")
	game.burst(center(current)+Vector3.UP*2,Color("ffe5a0"),32)
	refresh()
	game.save_game()

func objective() -> String:
	if current<0 or current in solved: return ""
	if game.player.position.distance_to(center(current))>16: return ""
	if current==2: return "Seal: %.1f / 4.4 m  ·  rest %.1f / 3 s" % [game.growth.size_value()*1.25,hold]
	return "Memory %d/3  ·  %s" % [progress,("%.0f s remaining" % timer) if timer>0 else HINTS[current]]

func ending() -> String:
	if solved.size()==5: return "THE GARDEN REMEMBERS\nYou carry every seed beyond the roots. Behind you, Luma's lantern goes dark. Ahead, the first new flower opens."
	return "A SEED OF TOMORROW\nThe guardian falls. %d of Luma's five memories travel with you. The remaining lanterns still wait in the Hollow." % solved.size()

func _process(delta):
	visible=game.playing
	if not game.playing or game.menu_open or game.ending_time>=0: return
	clock+=delta*game.settings.motion
	if current!=game.region: build(game.region)
	var size=game.growth.display_size
	companion.position=game.player.position+Vector3(1.4+size*0.5,size+1.2+sin(clock*2)*0.25,0.5)
	companion.rotation.y=clock
	if current in solved: return
	if not entered and game.player.position.distance_to(center(current))<15:
		entered=true
		game.echo("LUMA  /  A VOICE IN THE LANTERN",HINTS[current]+". Restore this memory to learn what happened here. You can reread memories in Pause > Luma's journal.")
	if timer>0:
		timer=maxf(0,timer-delta)
		if timer==0:
			progress=0
			refresh()
			game.echo("THE LIGHT FADES","Try the route again. Use Burst between the lanterns.")
	var pad=-1
	# Use the player's center: growing never activates several switches at once.
	for i in range(pads.size()):
		var offset=game.player.position-pads[i]
		offset.y=0
		if offset.length()<1.9: pad=i
	if current==2:
		if pad==0 and game.growth.size_value()>=3.5 and game.player.velocity.length()<0.8:
			hold+=delta
			if hold>=3: complete()
		else: hold=0
	elif pad>=0 and pad!=last_pad: touch_pad(pad)
	last_pad=pad
