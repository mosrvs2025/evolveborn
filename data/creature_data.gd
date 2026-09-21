class_name CreatureData
extends Resource

@export var id: String
@export var display_name: String
@export var max_health: float = 40
@export var damage: float = 8
@export var movement_speed: float = 2
@export var behavior_type: String = "territorial"
@export var essence_reward: int = 12
@export var trait_reward: String
@export var tint: Color = Color.WHITE
@export var silhouette: String = "beetle"
@export var species_tags: PackedStringArray
