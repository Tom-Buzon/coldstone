extends RefCounted
class_name HopliteHitEvent

var source: Node = null
var position: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.UP
var direction: Vector3 = Vector3.ZERO
var impulse: Vector3 = Vector3.ZERO
var damage: float = 0.0
var sever_damage: float = 0.0
var blade_speed: float = 0.0
var attack_slot: StringName = StringName()
var attack_context: StringName = &"idle"
var damage_type: StringName = &"slash"

func clone() -> HopliteHitEvent:
    var copy := HopliteHitEvent.new()
    copy.source = source
    copy.position = position
    copy.normal = normal
    copy.direction = direction
    copy.impulse = impulse
    copy.damage = damage
    copy.sever_damage = sever_damage
    copy.blade_speed = blade_speed
    copy.attack_slot = attack_slot
    copy.attack_context = attack_context
    copy.damage_type = damage_type
    return copy
