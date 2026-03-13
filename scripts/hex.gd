class_name Hex
extends RefCounted
## Pointy-top axial hex utilities: directions, distance, axial<->pixel, polygon.

# Pointy-top axial directions (q, r). Six neighbors.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # E
	Vector2i(1, -1),  # NE
	Vector2i(0, -1),  # NW
	Vector2i(-1, 0),  # W
	Vector2i(-1, 1),  # SW
	Vector2i(0, 1),   # SE
]

## Returns neighbor coords for axial coord (q, r).
static func get_neighbors(axial: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRECTIONS:
		out.append(axial + d)
	return out

## Axial (hex) distance between two coords.
static func axial_distance(a: Vector2i, b: Vector2i) -> int:
	var ac := _axial_to_cube(a)
	var bc := _axial_to_cube(b)
	return _cube_distance(ac, bc)

static func _axial_to_cube(axial: Vector2i) -> Vector3i:
	var x := axial.x
	var z := axial.y
	var y := -x - z
	return Vector3i(x, y, z)

static func _cube_distance(a: Vector3i, b: Vector3i) -> int:
	return (abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)) / 2

## Axial (q,r) to offset (col, row) for pointy-top odd-r rectangular layout.
static func axial_to_offset(axial: Vector2i) -> Vector2i:
	var q := axial.x
	var r := axial.y
	var col := q + (r - (r & 1)) / 2
	return Vector2i(col, r)

## Offset (col, row) to axial (q, r) for pointy-top odd-r.
static func offset_to_axial(offset: Vector2i) -> Vector2i:
	var col := offset.x
	var row := offset.y
	var q := col - (row - (row & 1)) / 2
	return Vector2i(q, row)

## Pointy-top odd-r: offset (col, row) to pixel (center of hex). Gives rectangular grid.
static func offset_to_pixel(offset: Vector2i, radius: float) -> Vector2:
	var col := float(offset.x)
	var row := float(offset.y)
	var x := radius * (sqrt(3.0) * (col + 0.5 * (int(row) % 2)))
	var y := radius * (1.5 * row)
	return Vector2(x, y)

## Pixel to offset (pointy-top odd-r). Rounds to nearest hex.
static func pixel_to_offset(pixel: Vector2, radius: float) -> Vector2i:
	var row := int(round(pixel.y / (1.5 * radius)))
	var col := int(round((pixel.x / (sqrt(3.0) * radius)) - 0.5 * (row % 2)))
	return Vector2i(col, row)

## Pointy-top rectangular layout: axial (q, r) to pixel (via offset).
static func axial_to_pixel(axial: Vector2i, radius: float) -> Vector2:
	return offset_to_pixel(axial_to_offset(axial), radius)

## Pixel to axial (rectangular layout). Rounds via offset.
static func pixel_to_axial(pixel: Vector2, radius: float) -> Vector2i:
	return offset_to_axial(pixel_to_offset(pixel, radius))

static func _cube_round(cube: Vector3) -> Vector2i:
	var rx := int(round(cube.x))
	var ry := int(round(cube.y))
	var rz := int(round(cube.z))
	var dx := absf(float(rx) - cube.x)
	var dy := absf(float(ry) - cube.y)
	var dz := absf(float(rz) - cube.z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(rx, rz)

## Pointy-top hex polygon (vertices in order). radius = center to vertex.
static func make_hex_polygon(radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i in range(6):
		var angle_deg := 60.0 * i
		var angle_rad := deg_to_rad(angle_deg)
		points.append(Vector2(radius * cos(angle_rad), radius * sin(angle_rad)))
	return points
