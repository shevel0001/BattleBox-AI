## Hex grid manager - generates tiles and handles pathfinding

extends Node2D
class_name HexGrid

## Dictionary mapping Vector2i(q, r) -> HexTile node
var tiles: Dictionary = {}

## Grid dimensions
@export var grid_width: int = 10
@export var grid_height: int = 8

## Reference to HexTile scene
var hex_tile_scene: PackedScene

func _ready():
	# Load HexTile scene
	hex_tile_scene = load("res://scenes/HexTile.tscn")
	if not hex_tile_scene:
		push_error("Failed to load HexTile.tscn")
		return
	
	generate_grid()

## Generate the hex grid
func generate_grid():
	tiles.clear()
	
	# Generate rectangular-ish grid in axial coordinates
	for q in range(-grid_width/2, grid_width/2 + 1):
		for r in range(-grid_height/2, grid_height/2 + 1):
			var coord = Vector2i(q, r)
			
			# Skip some tiles to make it more interesting (block a few)
			if coord == Vector2i(2, 0) or coord == Vector2i(-2, 1):
				continue
			
			var tile = hex_tile_scene.instantiate()
			tile.set_coord(coord)
			tile.set_walkable(true)
			add_child(tile)
			tiles[coord] = tile

## Get tile at coordinate, or null if doesn't exist
func get_tile(coord: Vector2i) -> Node:
	return tiles.get(coord, null)

## Check if coordinate is walkable
func is_walkable(coord: Vector2i) -> bool:
	var tile = get_tile(coord)
	if not tile:
		return false
	return tile.is_walkable()

## Get movement range using BFS
## Returns a Set of Vector2i coordinates within move_points distance
func movement_range(start: Vector2i, move_points: int) -> Array:
	var reachable: Array = []
	var visited: Dictionary = {}
	var queue: Array = []
	
	queue.append({"coord": start, "cost": 0})
	visited[start] = true
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var coord: Vector2i = current.coord
		var cost: int = current.cost
		
		if cost <= move_points:
			reachable.append(coord)
		
		if cost >= move_points:
			continue
		
		# Check neighbors
		for neighbor in Hex.get_neighbors(coord):
			if visited.has(neighbor):
				continue
			
			if not is_walkable(neighbor):
				continue
			
			# Check if there's a unit blocking this tile
			# (We'll check this in battle_controller)
			
			visited[neighbor] = true
			queue.append({"coord": neighbor, "cost": cost + 1})
	
	return reachable

## Pathfind from start to goal using BFS
## Returns Array of Vector2i coordinates (path) or empty array if no path
func pathfind(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return [start]
	
	var visited: Dictionary = {}
	var queue: Array = []
	var came_from: Dictionary = {}
	
	queue.append(start)
	visited[start] = true
	
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		
		if current == goal:
			# Reconstruct path
			var path: Array = []
			var node = goal
			while node != start:
				path.insert(0, node)
				node = came_from[node]
			path.insert(0, start)
			return path
		
		for neighbor in Hex.get_neighbors(current):
			if visited.has(neighbor):
				continue
			
			if not is_walkable(neighbor):
				continue
			
			visited[neighbor] = true
			came_from[neighbor] = current
			queue.append(neighbor)
	
	return []  # No path found
