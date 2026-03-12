## Hex coordinate utilities for axial coordinate system (q, r)
## Pointy-top hexagons

class_name Hex

## Axial directions (q, r) for pointy-top hexes
const DIRECTIONS = [
	Vector2i(1, 0),   # East
	Vector2i(1, -1),  # Northeast
	Vector2i(0, -1),  # Northwest
	Vector2i(-1, 0),  # West
	Vector2i(-1, 1),  # Southwest
	Vector2i(0, 1),   # Southeast
]

## Hex size (radius from center to corner)
const HEX_SIZE = 40.0

## Get all 6 neighbors of an axial coordinate
static func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in DIRECTIONS:
		neighbors.append(coord + dir)
	return neighbors

## Get distance between two axial coordinates
static func distance(a: Vector2i, b: Vector2i) -> int:
	var q1 = a.x
	var r1 = a.y
	var q2 = b.x
	var r2 = b.y
	
	# Convert to cube coordinates
	var s1 = -q1 - r1
	var s2 = -q2 - r2
	
	# Manhattan distance in cube space
	return (abs(q1 - q2) + abs(r1 - r2) + abs(s1 - s2)) / 2

## Convert axial coordinate (q, r) to pixel position (pointy-top)
static func axial_to_pixel(coord: Vector2i) -> Vector2:
	var q = float(coord.x)
	var r = float(coord.y)
	var x = HEX_SIZE * (sqrt(3.0) * q + sqrt(3.0) / 2.0 * r)
	var y = HEX_SIZE * (3.0 / 2.0 * r)
	return Vector2(x, y)

## Convert pixel position to approximate axial coordinate (pointy-top)
static func pixel_to_axial(pos: Vector2) -> Vector2i:
	var q = (sqrt(3.0) / 3.0 * pos.x - 1.0 / 3.0 * pos.y) / HEX_SIZE
	var r = (2.0 / 3.0 * pos.y) / HEX_SIZE
	return hex_round(Vector2(q, r))

## Round fractional hex coordinates to nearest integer hex
static func hex_round(hex: Vector2) -> Vector2i:
	# Convert to cube coordinates
	var q = hex.x
	var r = hex.y
	var s = -q - r
	
	# Round each component
	var rq = round(q)
	var rr = round(r)
	var rs = round(s)
	
	# Calculate differences
	var q_diff = abs(rq - q)
	var r_diff = abs(rr - r)
	var s_diff = abs(rs - s)
	
	# Reset the component with largest difference
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	else:
		rs = -rq - rr
	
	return Vector2i(int(rq), int(rr))
