extends Resource
class_name AbilityData
## A thing the body can do. The ability system dispatches on `shape`, so new
## abilities are new rows rather than new branches in the player controller.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cooldown: float = 0.6
@export var damage: float = 10.0
## melee_arc | projectile | cone | aoe | dash | web | slam | beam
@export var shape: String = "melee_arc"
@export var range: float = 2.4
@export var radius: float = 1.6
@export var angle_deg: float = 110.0
@export var duration: float = 0.0
@export var speed: float = 18.0
@export var knockback: float = 6.0
@export var windup: float = 0.08
@export var recovery: float = 0.22
## poison | burn | shock | root | mark | ""
@export var status: String = ""
@export var status_power: float = 0.0
@export var status_time: float = 0.0
@export var lunge: float = 0.0
@export var iframes: float = 0.0
@export var color: Color = Color(0.8, 0.9, 1.0)
@export var sfx: String = ""
@export var vfx: String = ""
@export var flags: Dictionary = {}
