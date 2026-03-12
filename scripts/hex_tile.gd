## HexTile script - individual hex tile with coordinate and walkable state

extends Node2D
class_name HexTile

var coord: Vector2i = Vector2i.ZERO
var walkable: bool = true
var polygon: Polygon2D

func _ready():
	polygon = get_node("Polygon2D")
	set_color(Color(0.8, 0.8, 0.8, 1))

## Set the axial coordinate and update position
func set_coord(new_coord: Vector2i) -> void:
	coord = new_coord
	position = Hex.axial_to_pixel(coord)

## Set walkable state
func set_walkable(value: bool) -> void:
	walkable = value
	if not walkable:
		set_color(Color(0.3, 0.3, 0.3, 1))
	else:
		set_color(Color(0.8, 0.8, 0.8, 1))

## Check if tile is walkable
func is_walkable() -> bool:
	return walkable

## Set tile color
func set_color(color: Color) -> void:
	if polygon:
		polygon.color = color

## Set highlighted state (for movement range)
func set_highlighted(value: bool) -> void:
	if polygon:
		if value:
			polygon.color = Color(0.4, 0.9, 0.4, 0.7)  # Green tint
		else:
			if walkable:
				polygon.color = Color(0.8, 0.8, 0.8, 1)
			else:
				polygon.color = Color(0.3, 0.3, 0.3, 1)
