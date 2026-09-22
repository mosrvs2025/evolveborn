extends Node3D
class_name CameraRig
## Third-person camera with an optional Smart Camera that keeps the game
## playable with one hand on the arrow cluster and no mouse at all.
##
## The rule that makes Smart Camera bearable: it only moves when the player is
## not moving it, it eases rather than snaps, and it gives up the moment a
## manual input arrives.

const BASE_DISTANCE := 7.4
const BASE_HEIGHT := 2.4
const KEY_LOOK_SPEED := 2.6
const PAD_LOOK_SPEED := 2.9
const MOUSE_SENS := 0.0026
const SMART_DELAY := 1.1
const SMART_RATE := 1.35

var target: Node3D = null
var yaw := 0.0
var pitch := -0.22
var distance := BASE_DISTANCE
var spring: SpringArm3D
var camera: Camera3D

var _manual := 0.0
var _recenter := 0.0
var _shake_offset := Vector3.ZERO
var _extra_distance := 0.0
var _focus: Node3D = null          ## boss or locked target
var _captured := false
var _touch_look := Vector2.ZERO

func _ready() -> void:
	spring = SpringArm3D.new()
	spring.spring_length = distance
	spring.margin = 0.45
	spring.collision_mask = 1
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.12
	camera.far = 420.0
	spring.add_child(camera)
	camera.current = true
	Sig.settings_changed.connect(_read_settings)
	_read_settings()

func _read_settings() -> void:
	distance = BASE_DISTANCE * float(Settings.get_value("camera_distance"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _captured:
		var s := float(Settings.get_value("camera_sensitivity")) * MOUSE_SENS
		var dx: float = event.relative.x * (-1.0 if bool(Settings.get_value("camera_invert_x")) else 1.0)
		var dy: float = event.relative.y * (-1.0 if bool(Settings.get_value("camera_invert_y")) else 1.0)
		_look(-dx * s, -dy * s)
	elif event is InputEventMouseButton and event.pressed and Game.is_playing():
		_capture(true)

func _capture(on: bool) -> void:
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		return
	_captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func release_mouse() -> void:
	_capture(false)

## Touch drag on the camera half of the screen.
func add_look(delta: Vector2) -> void:
	var s := float(Settings.get_value("camera_sensitivity")) * 0.006
	_look(-delta.x * s, -delta.y * s)

func _look(dyaw: float, dpitch: float) -> void:
	yaw = wrapf(yaw + dyaw, -PI, PI)
	pitch = clampf(pitch + dpitch, -1.15, 0.6)
	_manual = SMART_DELAY
	_recenter = 0.0

func camera_yaw() -> float:
	return yaw

func camera_basis_flat() -> Basis:
	return Basis(Vector3.UP, yaw)

func set_focus(node: Node3D) -> void:
	_focus = node

func _process(delta: float) -> void:
	if not Game.is_playing() and _captured:
		_capture(false)
	if target == null or not is_instance_valid(target):
		return
	_manual = maxf(0.0, _manual - delta)
	_read_look_input(delta)
	if _recenter > 0.0:
		_do_recenter(delta)
	elif bool(Settings.get_value("smart_camera")) and _manual <= 0.0:
		_smart(delta)
	_frame(delta)

func _read_look_input(delta: float) -> void:
	var lv := InputMgr.look_vector()
	if lv.length_squared() > 0.02:
		var pad := InputMgr.device == "gamepad"
		var speed: float = (PAD_LOOK_SPEED if pad else KEY_LOOK_SPEED) * float(Settings.get_value("camera_sensitivity"))
		var ix: float = -1.0 if bool(Settings.get_value("camera_invert_x")) else 1.0
		var iy: float = -1.0 if bool(Settings.get_value("camera_invert_y")) else 1.0
		_look(-lv.x * ix * speed * delta, -lv.y * iy * speed * delta)
	if Input.is_action_just_pressed("act_target"):
		_recenter = 0.45

## Recenter snaps behind whatever matters: the focus if there is one, otherwise
## the direction the player is facing.
func _do_recenter(delta: float) -> void:
	_recenter = maxf(0.0, _recenter - delta)
	var want := yaw
	if _focus != null and is_instance_valid(_focus):
		var to: Vector3 = _focus.global_position - target.global_position
		want = atan2(-to.x, -to.z)
	elif target.has_method("aim_direction"):
		var f: Vector3 = target.aim_direction()
		want = atan2(-f.x, -f.z)
	yaw = _ease_angle(yaw, want, delta * 9.0)
	pitch = lerpf(pitch, -0.22, clampf(delta * 6.0, 0.0, 1.0))

## Follows where the player is going, at a rate slow enough that a player who
## wants to look somewhere else always wins.
func _smart(delta: float) -> void:
	var want := yaw
	var weight := 0.0
	if _focus != null and is_instance_valid(_focus):
		var to: Vector3 = _focus.global_position - target.global_position
		if to.length() < 42.0:
			want = atan2(-to.x, -to.z)
			weight = 1.0
	if weight <= 0.0:
		var vel: Vector3 = target.get("velocity") if target.get("velocity") != null else Vector3.ZERO
		var flat := Vector3(vel.x, 0, vel.z)
		if flat.length() > 2.2:
			want = atan2(-flat.x, -flat.z)
			weight = clampf((flat.length() - 2.2) / 4.0, 0.0, 1.0)
		else:
			var threat := _threat_direction()
			if threat != Vector3.ZERO:
				want = atan2(-threat.x, -threat.z)
				weight = 0.45
	if weight <= 0.0:
		return
	var diff := wrapf(want - yaw, -PI, PI)
	if absf(diff) < 0.12:
		return
	yaw = wrapf(yaw + clampf(diff, -1.0, 1.0) * SMART_RATE * weight * delta, -PI, PI)
	pitch = lerpf(pitch, -0.2, clampf(delta * 1.5, 0.0, 1.0))

func _threat_direction() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for c in get_tree().get_nodes_in_group("creature"):
		if not is_instance_valid(c) or c.get("dead") == true:
			continue
		if c.get("aggravated") != true:
			continue
		var to: Vector3 = c.global_position - target.global_position
		if to.length() < 16.0:
			sum += to.normalized()
			count += 1
	if count == 0:
		return Vector3.ZERO
	sum.y = 0.0
	return sum.normalized()

func _frame(delta: float) -> void:
	# Pull back when something big is on screen, so a boss stays readable.
	var want_extra := 0.0
	if _focus != null and is_instance_valid(_focus):
		var d: float = _focus.global_position.distance_to(target.global_position)
		want_extra = clampf(4.2 - d * 0.08, 0.0, 4.2)
	_extra_distance = lerpf(_extra_distance, want_extra, clampf(delta * 2.0, 0.0, 1.0))
	spring.spring_length = distance + _extra_distance
	# Tell the body how close the camera actually ended up, which is not the
	# spring's length: the arm shortens whenever geometry is in the way.
	if target != null and target.has_method("on_camera_proximity"):
		target.on_camera_proximity(spring.get_hit_length() * spring.spring_length)
	var anchor: Vector3 = target.global_position + Vector3(0, BASE_HEIGHT, 0)
	global_position = global_position.lerp(anchor, clampf(delta * 11.0, 0.0, 1.0)) + _shake_offset
	rotation = Vector3(pitch, yaw, 0)
	_apply_shake(delta)

func _apply_shake(delta: float) -> void:
	if Fx.shake_trauma <= 0.0:
		_shake_offset = Vector3.ZERO
		return
	var t := Fx.shake_trauma * Fx.shake_trauma
	var motion := float(Settings.get_value("motion_intensity"))
	_shake_offset = Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * t * 0.45 * motion
	Fx.shake_trauma = maxf(0.0, Fx.shake_trauma - delta * 2.0)

static func _ease_angle(from: float, to: float, weight: float) -> float:
	return wrapf(from + wrapf(to - from, -PI, PI) * clampf(weight, 0.0, 1.0), -PI, PI)
