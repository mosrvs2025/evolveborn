extends CanvasLayer

const InputSetup = preload("res://systems/input_setup.gd")
var game
var root: Control
var overlay: Control
var panel: PanelContainer
var content: VBoxContainer
var health_bar: ProgressBar
var essence_bar: ProgressBar
var health_label: Label
var size_label: Label
var size_bar: ProgressBar
var location_label: Label
var objective: Label
var ability_label: Label
var echo_title: Label
var echo_message: Label
var echo_box: PanelContainer
var devour_label: Label
var devour_bar: ProgressBar
var boss_bar: ProgressBar
var boss_label: Label
var touch_layer: Control
var joystick: Control
var touch_devour: Button
var stick_id: int = -1
var camera_id: int = -1
var stick_origin: Vector2
var menu_title: String = ""
var resize_clock: float = 0
const MINT = Color("b0f0d6")
const INK = Color("101e24")
const CREAM = Color("eee7cf")

func _ready():
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme = Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color","Label",CREAM)
	theme.set_color("font_color","Button",CREAM)
	theme.set_color("font_hover_color","Button",MINT)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style = box(Color("243b3e") if state in ["hover","focus"] else Color("17292f"),Color("709788") if state=="focus" else Color("38534f"))
		theme.set_stylebox(state,"Button",style)
	theme.set_stylebox("background","ProgressBar",box(Color("203439"),Color("38534f")))
	theme.set_stylebox("fill","ProgressBar",box(Color("8ed7b8"),Color("8ed7b8")))
	root.theme = theme
	build_hud()
	build_touch()
	root.resized.connect(layout)

func box(color: Color,border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func label(parent: Node,text: String,size: int = 18,color: Color = CREAM) -> Label:
	var l = Label.new()
	l.text = text
	l.set_meta("base_font_size",size)
	l.add_theme_font_size_override("font_size",int(size*game.settings.ui_scale))
	l.add_theme_color_override("font_color",color)
	if parent == content:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

func button(parent: Node,text: String,callback: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0,48)
	b.pressed.connect(func(): game.sound.play("ui"); callback.call())
	parent.add_child(b)
	return b

func build_hud():
	var top = PanelContainer.new()
	top.name = "Vitals"
	top.add_theme_stylebox_override("panel",box(Color(0.04,0.10,0.13,0.9),Color("3c615a")))
	root.add_child(top)
	top.position = Vector2(28,25)
	top.size = Vector2(300,125)
	var stack = VBoxContainer.new()
	top.add_child(stack)
	health_label = label(stack,"WISP  /  VITALITY",16,MINT)
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size.y = 10
	stack.add_child(health_bar)
	essence_bar = ProgressBar.new()
	essence_bar.show_percentage = false
	essence_bar.custom_minimum_size.y = 5
	stack.add_child(essence_bar)
	size_label=label(stack,"0.75 m  /  DROPLET",16,Color("e4d49e"))
	size_bar=ProgressBar.new()
	size_bar.show_percentage=false
	size_bar.custom_minimum_size.y=6
	stack.add_child(size_bar)
	location_label = label(root,"01  /  AWAKENING CAVERN",16,MINT)
	objective = label(root,"Become something more.",22)
	ability_label = label(root,"",17)
	ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	ability_label.add_theme_constant_override("shadow_offset_x",2)
	ability_label.add_theme_constant_override("shadow_offset_y",2)
	echo_box = PanelContainer.new()
	echo_box.add_theme_stylebox_override("panel",box(Color(0.035,0.09,0.12,0.93),Color("3c615a")))
	root.add_child(echo_box)
	var echo_stack = VBoxContainer.new()
	echo_box.add_child(echo_stack)
	echo_title = label(echo_stack,"THE ECHO",16,MINT)
	echo_message = label(echo_stack,"",17)
	echo_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	devour_label = label(root,"",23,MINT)
	devour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	devour_bar = ProgressBar.new()
	devour_bar.max_value = 1.4
	devour_bar.show_percentage = false
	root.add_child(devour_bar)
	boss_label = label(root,"THE ROOT DEVOURER",18,Color("e8b4c2"))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	root.add_child(boss_bar)
	var pause = button(root,"II",pause_menu)
	pause.name = "PauseButton"
	pause.tooltip_text = "Pause / settings"
	var body = button(root,"BODY",body_menu)
	body.name = "BodyButton"
	layout()

func layout():
	var s = root.size
	if s.x<100: s = Vector2(1440,900)
	var compact = s.x<900
	var landscape = s.y<550
	root.get_node("Vitals").position = Vector2(18,18)
	root.get_node("Vitals").size.x = 185 if s.x<500 else (260 if compact else 300)
	location_label.position = Vector2(24,182) if compact else Vector2(s.x*0.5-200,28)
	objective.position = location_label.position+Vector2(0,25)
	objective.add_theme_font_size_override("font_size",16 if compact else 20)
	objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	objective.size.x=minf(480,s.x-objective.position.x-24)
	root.get_node("PauseButton").position = Vector2(s.x-70,20)
	root.get_node("PauseButton").size.x = 50
	root.get_node("BodyButton").position = Vector2(s.x-177,20)
	root.get_node("BodyButton").size.x = 96
	ability_label.position = Vector2(20,s.y-68)
	ability_label.size.x = s.x-40
	echo_box.position = Vector2(24,s.y-185 if not compact else 237)
	echo_box.size = Vector2(minf(490,s.x-48),95)
	if landscape:
		root.get_node("Vitals").size = Vector2(215,145)
		location_label.position = Vector2(250,23)
		objective.position = Vector2(250,48)
		echo_box.position = Vector2(235,95)
		echo_box.size = Vector2(maxf(230,s.x-485),95)
		echo_title.add_theme_font_size_override("font_size",13)
		echo_message.add_theme_font_size_override("font_size",14)
	else:
		echo_title.add_theme_font_size_override("font_size",16)
		echo_message.add_theme_font_size_override("font_size",17)
	devour_label.position = Vector2(maxf(10,s.x*0.5-250),s.y*0.62)
	devour_label.size.x = minf(500,s.x-20)
	devour_bar.position = Vector2(s.x*0.5-100,s.y*0.62+35)
	devour_bar.size = Vector2(200,7)
	boss_label.position = Vector2(maxf(16,s.x*0.5-230),100 if not compact else 110)
	boss_label.size.x = minf(460,s.x-32)
	boss_bar.position = boss_label.position+Vector2(0,28)
	boss_bar.size = Vector2(minf(460,s.x-32),8)
	if is_instance_valid(panel):
		panel.position = Vector2(maxf(16,(s.x-690)/2),maxf(16,(s.y-740)/2))
		panel.size = Vector2(minf(690,s.x-32),minf(740,s.y-32))
	if is_instance_valid(touch_layer):
		joystick.position = Vector2(30,s.y-185)
		var names = ["Strike","Special","Burst","Devour"]
		for i in range(4):
			var b = touch_layer.get_node(names[i])
			b.position = Vector2(s.x-115-(i%2)*100,s.y-140-(i/2)*95)
			b.size = Vector2(90,80)*game.settings.touch_size
			b.modulate.a = game.settings.touch_opacity

func update_hud():
	root.get_node("Vitals").visible = game.playing and not game.menu_open
	location_label.visible = not game.menu_open
	objective.visible = not game.menu_open
	ability_label.visible = not game.menu_open and game.device!="touch" and not DisplayServer.is_touchscreen_available()
	root.get_node("PauseButton").visible = game.playing and not game.menu_open
	root.get_node("BodyButton").visible = game.playing and not game.menu_open
	health_label.text = "%s  ·  %d / %d" % [game.form.to_upper(),game.health,game.max_health()]
	health_bar.max_value = game.max_health()
	health_bar.value = game.health
	essence_bar.max_value = 180
	essence_bar.value = game.essence
	var size=game.growth.size_value()
	size_label.text="%.2f m  /  %s" % [size*1.25,game.growth.TITLES[game.growth.stage]]
	var next_stage=mini(game.growth.stage+1,game.growth.STAGES.size()-1)
	size_bar.min_value=game.growth.STAGES[game.growth.stage]
	size_bar.max_value=maxf(size_bar.min_value+0.1,game.growth.STAGES[next_stage])
	size_bar.value=size
	location_label.text = "%02d  /  %s" % [game.region+1,game.world.NAMES[game.region]]
	objective.text = "Next chamber  /  grow to %.1f m" % (game.growth.GATES[game.region+1]*1.25) if game.region<4 else "Consume the Ancient Nest"
	if game.region<4 and size>=game.growth.GATES[game.region+1]: objective.text="Chamber open  /  follow the trail"
	if game.essence>=180 and game.form=="Wisp": objective.text="Evolution ready  /  find a Memory Pool"
	var quest=game.story.objective()
	if quest!="": objective.text=quest
	if game.growth.combo>=3: size_label.text += "  ·  FEAST x%d" % game.growth.combo
	var primary = InputSetup.prompt("action_primary",game.device)
	var secondary = InputSetup.prompt("action_secondary",game.device)
	var mobility = InputSetup.prompt("mobility",game.device)
	ability_label.text = "[%s] %s    ·    [%s] %s    ·    [%s] Burst %s    ·    [%s] Body" % [primary,game.ability_name(),secondary,"Inhale + special" if game.player.secondary_cd<=0 else "%.1fs" % game.player.secondary_cd,mobility,"" if game.player.mobility_cd<=0 else "%.1fs" % game.player.mobility_cd,InputSetup.prompt("body",game.device)]
	echo_box.visible = game.echo_time>0 and not game.menu_open and game.settings.subtitles
	var can_devour = is_instance_valid(game.devour_target) and not game.menu_open
	devour_label.visible = can_devour
	devour_bar.visible = can_devour
	devour_label.text = "[%s]  %s DEVOUR" % [InputSetup.prompt("devour",game.device),"TOGGLE" if game.settings.toggle_devour else "HOLD"]
	devour_bar.value = game.devour_progress
	boss_bar.visible = false
	boss_label.visible = false
	for c in game.creatures:
		if is_instance_valid(c) and c.boss and not c.dead and c.position.distance_to(game.player.position)<35 and not game.menu_open:
			boss_bar.visible = true
			boss_label.visible = true
			boss_bar.max_value = c.data.max_health
			boss_bar.value = c.health
			boss_label.text = "THE ROOT DEVOURER  /  PHASE %d" % c.phase
	touch_layer.visible = game.playing and not game.menu_open and (game.device=="touch" or DisplayServer.is_touchscreen_available())
	touch_devour.visible = can_devour

func set_echo(title: String,message: String):
	echo_title.text = title
	echo_message.text = message

func menu(title: String,subtitle: String = ""):
	if is_instance_valid(overlay):
		root.remove_child(overlay)
		overlay.queue_free()
	game.menu_open = true
	menu_title = title
	game.touch_vector = Vector2.ZERO
	for action in ["action_primary","action_secondary","mobility","devour"]: Input.action_release(action)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var shade = ColorRect.new()
	shade.color = Color(0.015,0.035,0.045,0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",box(Color(0.045,0.09,0.11,0.98),Color("49665c")))
	overlay.add_child(panel)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	label(content,"E V O L V E B O R N",16,MINT)
	label(content,title,38)
	if subtitle!="":
		var sub = label(content,subtitle,18,Color("a5b8b2"))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout()
	update_hud()

func focus_first():
	for child in content.get_children():
		if child is Button:
			child.grab_focus()
			break

func close_menu():
	game.menu_open = false
	if is_instance_valid(overlay):
		root.remove_child(overlay)
		overlay.queue_free()
	panel = null
	overlay = null
	game.player.attack_cd = maxf(game.player.attack_cd,0.25)
	game.player.secondary_cd = maxf(game.player.secondary_cd,0.25)
	update_hud()

func main_menu():
	game.playing = false
	menu("A hungry heart.\nA world to heal.","Follow Luma, the last gardener. Grow from a droplet into a giant, solve five memory shrines, and uncover the secret of the Root Devourer.")
	label(content,"ABSORB   /   GROW   /   MUTATE   /   DEVOUR",16,MINT)
	if not game.saved.is_empty(): button(content,"Continue your evolution",func(): game.start_run(true))
	button(content,"Awaken in the Hollow",func():
		if not game.saved.is_empty(): confirm_new()
		else: game.start_run(false))
	button(content,"Settings & accessibility",settings_menu)
	button(content,"Controls",controls_menu)
	label(content,"Five chambers. Five memories. One hungry little hero.\nLocal saves · No account · Plays offline after loading",16,Color("8da59d"))
	focus_first()

func confirm_new():
	menu("Begin a new life?","Your current run will be replaced. Settings and best completion time remain.")
	button(content,"Begin new run",func(): game.start_run(false))
	button(content,"Keep current run",main_menu)
	focus_first()

func pause_menu():
	menu("Memory suspended","The Hollow waits.")
	button(content,"Resume",close_menu)
	button(content,"Body configuration",body_menu)
	button(content,"Luma's journal",journal_menu)
	button(content,"Settings & accessibility",settings_menu)
	button(content,"Controls",controls_menu)
	button(content,"Return to Memory Pool",func(): game.respawn(); close_menu())
	button(content,"Save & main menu",func(): game.save_game(); main_menu())
	if OS.has_feature("debug"): button(content,"Developer tools",debug_menu)
	focus_first()

func debug_menu():
	menu("Developer tools","Available only in editor/debug builds.")
	button(content,"Back",pause_menu)
	button(content,"Discover every trait",func(): game.discovered=game.TRAITS.duplicate(); body_menu())
	button(content,"Grant evolution Essence",func(): game.essence=180; game.player.position=game.world.pools[game.checkpoint]; body_menu())
	button(content,"Restore vitality",func(): game.health=game.max_health(); close_menu())
	for size in [0.6,2.0,5.0,9.0]:
		button(content,"Growth preview  /  %.1f m" % (size*1.25),func(): game.growth.mass=pow(size,3); game.growth.display_size=size; game.growth.stage=game.growth.stage_index(); game.world.stream(game.region); close_menu())
	button(content,"Test death recovery",func(): game.stats.deaths+=1; game.respawn(); close_menu())
	for i in range(5):
		button(content,"Travel to "+game.world.NAMES[i],func(): game.player.position=game.world.pools[i]+Vector3(3,1,0); game.region=i; game.world.stream(i); game.spawn_region(i); close_menu())
	label(content,"FPS: %d    Active organisms: %d" % [Engine.get_frames_per_second(),game.creatures.size()],18)
	focus_first()

func body_menu():
	menu("Your body. Your build.","CORE CAPACITY  %d / %d    ·    %d ESSENCE    ·    %s" % [game.used_capacity(),game.capacity(),game.essence,game.form.to_upper()])
	button(content,"Return to the Hollow",close_menu)
	label(content,"%.2f m WIDE  /  %s  /  %d OBJECTS ABSORBED" % [game.growth.size_value()*1.25,game.growth.TITLES[game.growth.stage],game.growth.objects_eaten],18,Color("e4d49e"))
	label(content,"Your appetite grows with your body. Glide over smaller objects to absorb them. Secondary action inhales nearby food. Much smaller creatures can be swallowed whole.",17)
	if game.in_combat>0: label(content,"Adaptations are locked during combat. Move to safety first.",17,Color("f2bc92"))
	if game.discovered.is_empty(): label(content,"Defeat a creature, then hold Devour beside its remains.\nThe Echo will analyze a new adaptation.",18)
	for id in game.TRAITS:
		if not id in game.discovered: continue
		var adaptation = game.traits[id]
		var b = button(content,("●  " if id in game.equipped else "○  ")+adaptation.display_name+"    /    %d CORE" % adaptation.core_cost,func():
			if not game.equip(id): game.echo("CAPACITY LIMIT","Remove a adaptation to make room, or leave combat first.")
			body_menu())
		b.disabled = game.in_combat>0 or (not id in game.equipped and game.used_capacity()+adaptation.core_cost>game.capacity())
		label(content,adaptation.description,16,Color("a7bbb2"))
		label(content,{"regen":"Appetite: +12% biomass from every meal.","heat":"Appetite: consume plants 20% earlier.","armor":"Appetite: consume minerals 20% earlier.","venom":"Appetite: digest plants 15% earlier.","echo":"Appetite: wider automatic absorption field.","legs":"Mobility: leap over oversized obstacles.","electric":"Appetite: magnetically attract edible minerals.","shadow":"Mobility: slip past threats while foraging."}[id],15,MINT)
	if game.form=="Wisp":
		label(content,"EVOLUTION  /  180 ESSENCE",23,MINT)
		if game.essence>=180 and game.near_pool():
			for item in [["Predator","+35% attack · faster movement & Devour"],["Arcane","16 Core · stronger specials · shorter cooldowns"],["Bulwark","175 vitality · 20% resistance"]]:
				button(content,item[0]+"  /  "+item[1],func(): game.evolve(item[0]); close_menu())
		else: label(content,"Gather Essence, then return to a Memory Pool to evolve.",16)
	label(content,"DISCOVERED SYNERGIES",23,MINT)
	for recipe in game.SYNERGIES:
		if recipe[2] in game.synergies: label(content,recipe[2]+"  /  "+recipe[3],16)
		elif recipe[0] in game.discovered and recipe[1] in game.discovered: label(content,"Possible pairing: "+game.traits[recipe[0]].display_name+" + "+game.traits[recipe[1]].display_name,16,Color("a9ac91"))
	focus_first()

func settings_menu():
	menu("Tune your experience","All changes apply immediately and are saved locally.")
	button(content,"Back",pause_menu if game.playing else main_menu)
	for item in [["smart","Smart camera"],["assist","Soft target assistance"],["invert","Invert camera Y"],["numbers","Damage numbers"],["subtitles","Echo captions"],["floating","Floating touch joystick"],["toggle_devour","Toggle Devour instead of hold"]]:
		var check = CheckButton.new()
		check.text = item[1]
		check.custom_minimum_size.y = 46
		check.button_pressed = game.settings[item[0]]
		check.toggled.connect(func(value): game.settings[item[0]]=value; game.save_game())
		content.add_child(check)
	for item in [["sensitivity","Camera sensitivity",0.3,2.5],["shake","Screen shake",0.0,1.0],["motion","Motion intensity",0.0,1.0],["volume","Audio volume",0.0,1.0],["ui_scale","Text scale",0.85,1.3],["touch_size","Touch button size",0.8,1.3],["touch_opacity","Touch opacity",0.25,1.0]]:
		label(content,item[1],17)
		var slider = HSlider.new()
		slider.min_value = item[2]
		slider.max_value = item[3]
		slider.step = 0.05
		slider.value = game.settings[item[0]]
		slider.custom_minimum_size.y = 36
		slider.value_changed.connect(func(value):
			game.settings[item[0]]=value
			game.apply_quality()
			root.theme.default_font_size = int(19*game.settings.ui_scale)
			layout()
			rescale_text(root)
			game.save_game())
		content.add_child(slider)
	label(content,"Graphics quality",17)
	var quality = OptionButton.new()
	quality.custom_minimum_size.y = 48
	for text in ["Auto","Low","Medium","High"]: quality.add_item(text)
	quality.selected = ["Auto","Low","Medium","High"].find(game.settings.quality)
	quality.item_selected.connect(func(index): game.settings.quality=["Auto","Low","Medium","High"][index]; game.apply_quality(); game.save_game())
	content.add_child(quality)
	focus_first()

func rescale_text(node: Node):
	if node is Label and node.has_meta("base_font_size"):
		node.add_theme_font_size_override("font_size",int(node.get_meta("base_font_size")*game.settings.ui_scale))
	for child in node.get_children(): rescale_text(child)

func controls_menu():
	menu("A body you can control","WASD or arrows to move. Middle-mouse drag to orbit. Smart camera follows automatically. Hold E / Ctrl to Devour. Controller and touch are detected automatically.")
	button(content,"Back",pause_menu if game.playing else main_menu)
	for preset in ["Standard","One-hand","Controller","Touch"]:
		button(content,preset+" preset",func():
			if preset in ["Standard","One-hand"]:
				for action in InputSetup.KEYS:
					var keys = InputSetup.KEYS[action]
					game.bind_key(action,keys[1] if preset=="One-hand" and keys.size()>1 else keys[0])
				game.device="keyboard"
			elif preset=="Touch": game.device="touch"
			else: game.device="controller"
			game.settings.smart=true
			game.save_game()
			controls_menu())
	label(content,"REMAP KEYBOARD",22,MINT)
	for action in InputSetup.KEYS:
		button(content,action.replace("_"," ").capitalize()+"    ["+InputSetup.prompt(action,"keyboard")+"]",func(): game.remap_action=action; menu("Press a key","Assign a keyboard key to "+action.replace("_"," ")))
	label(content,"Controller: left stick move · right stick orbit\nX strike · Y special · A burst · B Devour\nLB recenter · View body · Menu pause",17)
	focus_first()

func end_menu():
	menu("Beyond the Hollow",game.story.ending())
	label(content,"%02d:%02d  /  %s" % [int(game.stats.time)/60,int(game.stats.time)%60,game.form.to_upper()],30,MINT)
	label(content,"FINAL SIZE  %.1f m  /  %d SCENERY OBJECTS\nBIGGEST MEAL  %s" % [game.growth.size_value()*1.25,game.growth.objects_eaten,game.growth.biggest],21,Color("e4d49e"))
	label(content,"%d defeated   ·   %d Devoured   ·   %d / 8 species\n%d traits   ·   %d / 5 synergies   ·   %d deaths\n%d / 5 hidden memories discovered" % [game.stats.kills,game.stats.devoured,game.discovered.size(),game.discovered.size(),game.synergies.size(),game.stats.deaths,game.secrets.size()],20)
	button(content,"Continue exploring",func(): game.player.position=game.world.pools[3]+Vector3(3,1,0); close_menu())
	button(content,"Play again",confirm_new)
	button(content,"Main menu",main_menu)
	focus_first()

func build_touch():
	touch_layer = Control.new()
	touch_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_layer)
	joystick = Panel.new()
	joystick.size = Vector2(145,145)
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = box(Color(0.15,0.35,0.34,0.35),Color(0.6,0.85,0.72,0.45))
	style.set_corner_radius_all(72)
	joystick.add_theme_stylebox_override("panel",style)
	touch_layer.add_child(joystick)
	var center = label(joystick,"MOVE",17,MINT)
	center.position = Vector2(47,59)
	for pair in [["Strike","action_primary"],["Special","action_secondary"],["Burst","mobility"],["Devour","devour"]]:
		var b = Button.new()
		b.name = pair[0]
		b.text = pair[0].to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.button_down.connect(func(): game.device="touch"; Input.action_press(pair[1]))
		b.button_up.connect(func(): Input.action_release(pair[1]))
		touch_layer.add_child(b)
		if pair[0]=="Devour": touch_devour=b
	layout()
	touch_layer.visible=false

func _input(event):
	if game.menu_open or not game.playing: return
	var s = root.size
	if event is InputEventScreenTouch:
		game.device="touch"
		if event.pressed and event.position.x<s.x*0.45 and event.position.y>s.y*0.42:
			stick_id=event.index
			stick_origin=event.position if game.settings.floating else joystick.position+Vector2(72,72)
			joystick.position=stick_origin-Vector2(72,72)
		elif not event.pressed and event.index==stick_id:
			stick_id=-1
			game.touch_vector=Vector2.ZERO
		elif event.pressed and event.position.x>s.x*0.45 and event.position.y<s.y-260:
			camera_id=event.index
		elif not event.pressed and event.index==camera_id: camera_id=-1
	if event is InputEventScreenDrag:
		if event.index==stick_id: game.touch_vector=((event.position-stick_origin)/60).limit_length()
		elif event.index==camera_id: game.orbit(event.relative)


func journal_menu():
	menu("Luma's journal","Restore golden shrines in each chamber. Every recovered memory carries a seed into the ending.")
	label(content,"%d / 5 MEMORIES RESTORED" % game.story.solved.size(),22,MINT)
	for i in range(5):
		label(content,"%02d / %s" % [i+1,game.story.TITLES[i]],22,MINT)
		var entry=label(content,game.story.MEMORIES[i] if i in game.story.solved else game.story.HINTS[i]+" — "+game.world.NAMES[i],18)
		entry.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(content,"Back",pause_menu)
	focus_first()
