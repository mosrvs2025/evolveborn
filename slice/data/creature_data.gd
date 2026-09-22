extends Resource
class_name CreatureData
## One species. The same fields drive the player's prey and the creatures that
## hunt each other, which is what makes the basin an ecosystem rather than a
## spawn list.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var max_health: float = 30.0
@export var damage: float = 6.0
@export var armor: float = 0.0
@export var move_speed: float = 3.0
@export var turn_speed: float = 6.0
## grazer | aggressor | ambusher | flyer | ranged | territorial | leaper
@export var behavior: String = "aggressor"
@export var aggro_range: float = 11.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.8
@export var attack_windup: float = 0.45
@export var ranged_ability: String = ""
@export var essence_reward: int = 10
@export var trait_reward: String = ""
## Key into ProcCreature's body plans.
@export var body_plan: String = "grub"
@export var body_scale: float = 1.0
@export var color_primary: Color = Color(0.5, 0.5, 0.55)
@export var color_secondary: Color = Color(0.7, 0.7, 0.8)
@export var glow: Color = Color(0, 0, 0, 0)
@export var flies: bool = false
@export var hover_height: float = 0.0
## What this creature IS, for the ecosystem: prey / predator / fungal / armored...
@export var species_tags: PackedStringArray = PackedStringArray()
## Tags this creature hunts.
@export var diet: PackedStringArray = PackedStringArray()
## Tags this creature runs from.
@export var fears: PackedStringArray = PackedStringArray()
@export var voice: String = ""
@export var flags: Dictionary = {}
