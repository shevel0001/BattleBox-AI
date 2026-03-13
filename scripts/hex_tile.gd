extends Node2D
class_name HexTile
## Single hex tile: base polygon, claim overlay, highlight overlay.

enum Claim { NONE, RED, BLUE }

@onready var base_poly: Polygon2D = $BasePoly
@onready var claim_poly: Polygon2D = $ClaimPoly
@onready var highlight_poly: Polygon2D = $HighlightPoly

var coord: Vector2i
var hex_radius: float = 28.0

func _ready() -> void:
	claim_poly.visible = false
	highlight_poly.visible = false

func set_coord(axial: Vector2i) -> void:
	coord = axial
	position = Hex.axial_to_pixel(axial, hex_radius)
	var poly := Hex.make_hex_polygon(hex_radius)
	if base_poly:
		base_poly.polygon = poly
	if claim_poly:
		claim_poly.polygon = poly
	if highlight_poly:
		highlight_poly.polygon = poly

func set_walkable(_walkable: bool) -> void:
	# Reserved for future use (e.g. terrain).
	pass

func set_claim(team: Claim) -> void:
	claim_poly.visible = (team != Claim.NONE)
	match team:
		Claim.NONE:
			claim_poly.visible = false
		Claim.RED:
			claim_poly.color = Color(1, 0.2, 0.2, 0.4)
			claim_poly.visible = true
		Claim.BLUE:
			claim_poly.color = Color(0.2, 0.2, 1, 0.4)
			claim_poly.visible = true

func set_highlight(enabled: bool) -> void:
	highlight_poly.visible = enabled
	if enabled:
		highlight_poly.polygon = Hex.make_hex_polygon(hex_radius)
		highlight_poly.color = Color(0.95, 0.95, 0.2, 0.75)
		highlight_poly.z_index = 1
	else:
		highlight_poly.z_index = 0
