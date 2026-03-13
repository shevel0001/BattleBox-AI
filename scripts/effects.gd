## Status effect system
extends RefCounted
class_name EffectManager

## Base effect class
class Effect:
	extends RefCounted
	
	var name: String
	var remaining_turns: int
	
	func _init(effect_name: String, duration: int):
		name = effect_name
		remaining_turns = duration
	
	## Called at start of unit's turn
	func on_turn_start(unit) -> void:
		pass
	
	## Called at end of unit's turn
	func on_turn_end(unit) -> void:
		remaining_turns -= 1

## Poison effect - deals damage at start of turn
class PoisonEffect extends Effect:
	var tick_damage: int = 2
	
	func _init(duration: int = 3):
		super._init("Poison", duration)
		tick_damage = 2
	
	func on_turn_start(unit) -> void:
		unit.apply_damage(tick_damage)
		print("Poison deals %d damage to %s" % [tick_damage, unit.name])

var effects: Array[Effect] = []

func add_effect(effect: Effect) -> void:
	# Check if effect already exists, refresh duration if so
	for existing in effects:
		if existing.name == effect.name:
			existing.remaining_turns = effect.remaining_turns
			return
	
	effects.append(effect)
	print("Added effect: %s (duration: %d)" % [effect.name, effect.remaining_turns])

func on_turn_start(unit) -> void:
	for effect in effects:
		effect.on_turn_start(unit)

func on_turn_end(unit) -> void:
	var to_remove: Array = []
	for effect in effects:
		effect.on_turn_end(unit)
		if effect.remaining_turns <= 0:
			to_remove.append(effect)
	
	# Remove expired effects
	for effect in to_remove:
		effects.erase(effect)
		print("Effect %s expired" % effect.name)

func has_effect(effect_name: String) -> bool:
	for effect in effects:
		if effect.name == effect_name:
			return true
	return false
