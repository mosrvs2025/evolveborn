extends Resource
class_name TraitData
## One adaptation the Core can integrate. Traits are pure data: what they cost,
## what they change about the body, and which ability (if any) they graft onto a
## control. Behaviour lives in the systems that read these fields.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var core_cost: int = 2
## passive | active | hybrid
@export var trait_type: String = "passive"
## Additive fractions unless the key says otherwise; see PlayerStats.
@export var stat_modifiers: Dictionary = {}
## Ability id grafted onto a control while this trait is equipped.
@export var active_ability: String = ""
## Which control it takes over: primary | secondary | mobility
@export var ability_slot: String = "secondary"
## Key into PlayerVisuals' mutation builders.
@export var visual_mutation: String = ""
@export var synergy_tags: PackedStringArray = PackedStringArray()
@export var color: Color = Color(0.7, 0.8, 0.9)
## Behavioural switches other systems check by name, e.g. on_hit_status.
@export var flags: Dictionary = {}
@export_multiline var echo_note: String = ""
