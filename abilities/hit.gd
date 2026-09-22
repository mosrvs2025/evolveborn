extends RefCounted
class_name Hit
## One blow, as data. Everything that can hurt anything builds one of these, so
## resistances, statuses, knockback and retaliation are handled in exactly one
## place on the receiving side.

var damage: float = 0.0
var source: Node = null
var team: String = "creature"      ## who threw it
var position: Vector3 = Vector3.ZERO
var knockback: float = 0.0
var status: String = ""
var status_power: float = 0.0
var status_time: float = 0.0
var armor_pierce: float = 0.0
var crit: bool = false
var color: Color = Color.WHITE

static func make(damage: float, source: Node, team: String, pos: Vector3) -> Hit:
	var h := Hit.new()
	h.damage = damage
	h.source = source
	h.team = team
	h.position = pos
	return h

func with_status(s: String, power: float, time: float) -> Hit:
	status = s
	status_power = power
	status_time = time
	return self
