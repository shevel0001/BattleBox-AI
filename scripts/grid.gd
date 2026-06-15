class_name Grid
extends RefCounted
## 10x20 axial grid: tiles, occupancy, BFS movement range.

var tiles: Dictionary = {}  # Vector2i -> HexTile (or Node)
var occupied: Dictionary = {}  # Vector2i -> Unit
var cols: int = 10
var rows: int = 20
var hex_radius: float = 28.0

func _init(cols_: int = 10, rows_: int = 20, hex_radius_: float = 28.0) -> void:
	cols = cols_
	rows = rows_
	hex_radius = hex_radius_

func in_bounds(coord: Vector2i) -> bool:
	var off := Hex.axial_to_offset(coord)
	return off.x >= 0 and off.x < cols and off.y >= 0 and off.y < rows

func get_tile(coord: Vector2i):
	return tiles.get(coord)

func is_occupied(coord: Vector2i) -> bool:
	return occupied.has(coord)

func set_occupied(coord: Vector2i, unit_or_null) -> void:
	if unit_or_null == null:
		occupied.erase(coord)
	else:
		occupied[coord] = unit_or_null

## Neighbors that are in bounds (walkability not considered here).
func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var n := Hex.get_neighbors(coord)
	var out: Array[Vector2i] = []
	for c in n:
		if in_bounds(c):
			out.append(c)
	return out

## Neighbors that are in bounds and not occupied (walkable).
func neighbors_walkable(coord: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in get_neighbors(coord):
		if not is_occupied(c):
			out.append(c)
	return out

## BFS: all coords reachable in at most max_steps steps; cannot step on occupied hexes.
func movement_range(start: Vector2i, max_steps: int) -> Array[Vector2i]:
	var reached: Dictionary = {}
	reached[start] = 0
	var frontier: Array[Vector2i] = [start]
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		var steps: int = reached[current]
		if steps >= max_steps:
			continue
		for next in neighbors_walkable(current):
			if not reached.has(next):
				reached[next] = steps + 1
				frontier.append(next)
	var result: Array[Vector2i] = []
	for c in reached:
		if c != start:
			result.append(c)
	return result
