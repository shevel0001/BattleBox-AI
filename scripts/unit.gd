## Unit script - handles unit logic, HP, movement, attacks

extends Node2D
class_name Unit

enum Team {
	PLAYER,
	ENEMY
}

@export var team: Team = Team.PLAYER
@export var max_hp: int = 20
@export var move_points: int = 3
@export var attack_range: int = 1
@export var attack_damage: int = 5
@export var portrait: Texture2D

var hp: int
var coord: Vector2i = Vector2i.ZERO
var effects: EffectManager
var hp_label: Label

func _ready():
	hp = max_hp
	effects = EffectManager.new()
	
	# Find HP label
	hp_label = get_node_or_null("HpLabel")
	update_hp_label()
	
	# Set visual based on team
	update_visual()

## Set unit's axial coordinate and update position
func set_coord(new_coord: Vector2i) -> void:
	coord = new_coord
	position = Hex.axial_to_pixel(coord)

## Apply damage to unit
func apply_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	update_hp_label()
	
	if hp <= 0:
		on_death()

## Update HP label display
func update_hp_label() -> void:
	if hp_label:
		hp_label.text = "%d/%d" % [hp, max_hp]

## Update visual appearance based on team
func update_visual() -> void:
	var sprite = get_node_or_null("Sprite2D")
	var color_rect = get_node_or_null("ColorRect")
	
	var color: Color
	if team == Team.PLAYER:
		color = Color.BLUE
	else:
		color = Color.RED
	
	if sprite:
		sprite.modulate = color
	elif color_rect:
		color_rect.color = color

## Check if unit can attack target at given coordinate
func can_attack(target_coord: Vector2i) -> bool:
	return Hex.distance(coord, target_coord) <= attack_range

## Attack target unit
func attack(target: Unit) -> void:
	if not can_attack(target.coord):
		return
	
	target.apply_damage(attack_damage)
	print("%s attacks %s for %d damage" % [name, target.name, attack_damage])

## Called when unit dies
func on_death() -> void:
	print("%s has been defeated!" % name)
	# Unit will be removed by battle controller

## Check if unit is alive
func is_alive() -> bool:
	return hp > 0
