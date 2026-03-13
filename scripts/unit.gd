extends Node2D
class_name Unit
## Unit: team, axial coord, hp, move_points, has_acted. Updates position from coord.

enum Team { BLUE, RED }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const MAX_HP: int = 5
const MOVE_POINTS: int = 3
const ATTACK_RANGE: int = 1
const ATTACK_POWER: int = 4  # max damage on a successful hit
const DEFAULT_PORTRAIT_PATH := "res://assets/portraits/default_unit.svg"

@onready var body_poly: Polygon2D = $BodyPoly
@onready var hp_label: Label = $LabelRoot/HpLabel
@onready var level_label: Label = $LabelRoot/LevelLabel
@onready var xp_label: Label = $LabelRoot/XpLabel

var team: Team = Team.BLUE
var coord: Vector2i = Vector2i.ZERO
var hp: int = 5
var max_hp: int = 5
var move_points: int = 3
var attack_range: int = 1
var attack_power: int = 4
var has_acted: bool = false

var level: int = 1
var xp: int = 0

var hex_radius: float = 28.0

var unit_type: String = "Warrior"
var unit_index: int = 0
var defense: int = 0
var rarity: Rarity = Rarity.COMMON

var base_max_hp: int = 0
var damage_die_sides: int = 4
var base_damage_bonus: int = 0
var level_bonus_hp: int = 0
var level_bonus_damage: int = 0

func _ready() -> void:
	level = 1
	xp = 0
	move_points = MOVE_POINTS
	attack_range = ATTACK_RANGE
	randomize_rarity()
	set_team_color()
	refresh_labels()

func set_team_color() -> void:
	if body_poly:
		body_poly.color = Color.BLUE if team == Team.BLUE else Color.RED

func set_coord(new_coord: Vector2i) -> void:
	coord = new_coord
	position = Hex.axial_to_pixel(coord, hex_radius)

func set_selected(selected: bool) -> void:
	if body_poly:
		if selected:
			scale = Vector2(1.15, 1.15)
		else:
			set_team_color()
			scale = Vector2(1.0, 1.0)

func apply_damage(amount: int) -> void:
	var actual: int = maxi(amount - defense, 0)
	hp = clampi(hp - actual, 0, max_hp)
	update_hp_label()
	if is_dead():
		queue_free()

func is_dead() -> bool:
	return hp <= 0

func update_hp_label() -> void:
	if hp_label:
		hp_label.text = str(hp) + "/" + str(max_hp)

func refresh_labels() -> void:
	update_hp_label()
	_update_progress_labels()

func randomize_rarity() -> void:
	var roll: int = randi_range(1, 100)
	if roll <= 60:
		rarity = Rarity.COMMON
	elif roll <= 80:
		rarity = Rarity.UNCOMMON
	elif roll <= 94:
		rarity = Rarity.RARE
	elif roll <= 98:
		rarity = Rarity.EPIC
	else:
		rarity = Rarity.LEGENDARY

	var base_hp: int = 0
	match rarity:
		Rarity.COMMON:
			# HP: 3 + 1d4, Damage: 1d4
			base_hp = 3 + randi_range(1, 4)
			damage_die_sides = 4
			base_damage_bonus = 0
		Rarity.UNCOMMON:
			# HP: 4 + 1d4, Damage: 1d4 + 1
			base_hp = 4 + randi_range(1, 4)
			damage_die_sides = 4
			base_damage_bonus = 1
		Rarity.RARE:
			# HP: 4 + 1d6, Damage: 1d6
			base_hp = 4 + randi_range(1, 6)
			damage_die_sides = 6
			base_damage_bonus = 0
		Rarity.EPIC:
			# HP: 5 + 1d8, Damage: 1d8 + 1
			base_hp = 5 + randi_range(1, 8)
			damage_die_sides = 8
			base_damage_bonus = 1
		Rarity.LEGENDARY:
			# HP: 6 + 1d10, Damage: 1d8 + 3
			base_hp = 6 + randi_range(1, 10)
			damage_die_sides = 8
			base_damage_bonus = 3

	base_max_hp = base_hp
	level_bonus_hp = 0
	level_bonus_damage = 0
	defense = 0
	_update_stats_for_level()
	hp = max_hp
	_apply_rarity_colors()

func _apply_rarity_colors() -> void:
	var c := Color.WHITE
	match rarity:
		Rarity.COMMON:
			c = Color(1, 1, 1)
		Rarity.UNCOMMON:
			c = Color(0.3, 1.0, 0.3)
		Rarity.RARE:
			c = Color(0.4, 0.8, 1.0)
		Rarity.EPIC:
			c = Color(0.8, 0.6, 1.0)
		Rarity.LEGENDARY:
			c = Color(1.0, 0.84, 0.2)

	if level_label:
		level_label.add_theme_color_override("font_color", c)
	if hp_label:
		hp_label.add_theme_color_override("font_color", c)
	if xp_label:
		xp_label.add_theme_color_override("font_color", c)

## Rolls damage for a successful hit.
## Kept as a method so future unit qualifiers/modifiers can change damage rules cleanly.
func roll_attack_damage(rng: RandomNumberGenerator) -> int:
	var max_damage: int = get_max_damage_for_level()
	# Damage = 1d[die_sides] + base_bonus + per-level bonus.
	var roll: int = randi_range(1, damage_die_sides)
	return roll + base_damage_bonus + level_bonus_damage

func get_max_damage_for_level() -> int:
	return damage_die_sides + base_damage_bonus + level_bonus_damage

## XP required to level up from current level (L1->2 = 10, L2->3 = 20, L3->4 = 30, ...).
func get_xp_required_for_next_level() -> int:
	return 10 * level

func gain_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var required: int = get_xp_required_for_next_level()
	while xp >= required:
		xp -= required
		level += 1
		# On each level gained beyond 1:
		# - Add 1d6 to max HP
		# - Add +2 flat damage
		var hp_gain: int = randi_range(1, 6)
		level_bonus_hp += hp_gain
		level_bonus_damage += 2
		_update_stats_for_level()
		hp = max_hp   # fully heal on level-up
		required = get_xp_required_for_next_level()
	refresh_labels()

func _update_stats_for_level() -> void:
	# Update attack_power, defense, and max_hp based on current level.
	max_hp = base_max_hp + level_bonus_hp
	if level >= 2:
		defense = 1
	else:
		defense = 0
	attack_power = get_max_damage_for_level()
	if hp > max_hp:
		hp = max_hp

func _update_progress_labels() -> void:
	if level_label:
		level_label.text = "Level%d %s %d" % [level, unit_type, unit_index]
	if xp_label:
		xp_label.text = "(%d/%d)" % [xp, get_xp_required_for_next_level()]

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
	return "Unknown"

func get_display_name() -> String:
	return "Level%d %s %d" % [level, unit_type, unit_index]

func get_damage_expression() -> String:
	var bonus: int = base_damage_bonus + level_bonus_damage
	if bonus == 0:
		return "1d%d" % damage_die_sides
	return "1d%d+%d" % [damage_die_sides, bonus]

func get_portrait_texture() -> Texture2D:
	var team_name := "blue" if team == Team.BLUE else "red"
	var type_name := unit_type.strip_edges().to_lower()
	var candidates: Array[String] = []
	
	# Prioritize the filenames you already have in assets/portraits.
	if type_name == "warrior":
		candidates.append("res://assets/portraits/warrior_1a_%s.png" % team_name)
		candidates.append("res://assets/portraits/warrior_1a_%s.jpg" % team_name)
		candidates.append("res://assets/portraits/Warrior 1a %s.png" % team_name)
		candidates.append("res://assets/portraits/Warrior 1a %s.jpg" % team_name)
		if unit_index == 2:
			candidates.append("res://assets/portraits/Warrior 1b %s.png" % team_name)
			candidates.append("res://assets/portraits/Warrior 1b %s.jpg" % team_name)
		if unit_index >= 3:
			var tier_index := min(unit_index, 3)
			candidates.append("res://assets/portraits/Warrior%d %s.png" % [tier_index, team_name])
			candidates.append("res://assets/portraits/Warrior%d %s.jpg" % [tier_index, team_name])
	elif type_name == "archer":
		candidates.append("res://assets/portraits/archer 1a %s.jpg" % team_name)
		candidates.append("res://assets/portraits/archer 1b %s.jpg" % team_name)
		candidates.append("res://assets/portraits/archer 2 %s.jpg" % team_name)
	
	candidates.append(DEFAULT_PORTRAIT_PATH)
	
	for path in candidates:
		if FileAccess.file_exists(path):
			var tex = load(path)
			if tex is Texture2D:
				return tex
	
	var fallback := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	fallback.fill(Color(0.75, 0.15, 0.75, 1.0))
	return ImageTexture.create_from_image(fallback)

func get_description_text() -> String:
	var type_name := unit_type.strip_edges().to_lower()
	var summary := "Balanced unit."
	match type_name:
		"warrior":
			summary = "Frontline melee fighter. Reliable HP and defense for holding lanes."
		"archer":
			summary = "Ranged skirmisher. Trades toughness for flexible damage pressure."
	
	var rarity_note := "Rarity bonus: %s." % get_rarity_name()
	return "%s\n%s" % [summary, rarity_note]
