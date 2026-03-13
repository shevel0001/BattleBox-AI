extends Node2D
## Main battle: grid, units, turn order, input, attack, win condition.

const COLS: int = 10
const ROWS: int = 20
const HEX_RADIUS: float = 42.0

# Starting positions using offset coords (col,row), then converted to axial.
# Five units per side, spaced vertically near opposite edges of the board.
const BLUE_OFFSET_STARTS: Array[Vector2i] = [
	Vector2i(1, 3),
	Vector2i(1, 6),
	Vector2i(1, 9),
	Vector2i(1, 12),
	Vector2i(1, 15),
]
const RED_OFFSET_STARTS: Array[Vector2i] = [
	Vector2i(8, 3),
	Vector2i(8, 6),
	Vector2i(8, 9),
	Vector2i(8, 12),
	Vector2i(8, 15),
]

var grid: Grid
var active_team: Unit.Team = Unit.Team.BLUE
var selected_unit: Unit = null  # unit chosen to move/attack (uses one of 3 actions)
var inspected_unit: Unit = null  # unit being viewed in panel (click to look, does not use action)
var move_options: Dictionary = {}  # Vector2i -> true (coords we can move to)
var unit_has_moved_this_selection: bool = false
var winner: Unit.Team = -1  # -1 = none

const MAX_ACTIONS_PER_TURN: int = 3
var actions_used_this_turn: int = 0

var grid_root: Node2D
var unit_root: Node2D
var hud: Control
var active_team_label: Label
var info_label: Label
var log_label: Label
var end_turn_button: Button
var unit_info_panel: Control
var unit_info_name_label: Label
var unit_info_rarity_label: Label
var unit_info_hp_label: Label
var unit_info_damage_label: Label
var unit_info_defense_label: Label
var unit_info_move_label: Label
var unit_info_level_xp_label: Label
var unit_info_select_hint: Label
var unit_info_title_label: Label
var unit_info_portrait: TextureRect
var unit_info_description_label: Label

var hex_tile_scene: PackedScene
var unit_scene: PackedScene

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var team_spawn_counts: Dictionary = {}

func _ready() -> void:
	print("How to Play: Click a unit (your color) to select. Click a highlighted tile to move. Click an adjacent enemy to attack. Click your unit again to skip attack. Press End Turn when done.")
	rng.randomize()
	team_spawn_counts[Unit.Team.BLUE] = 0
	team_spawn_counts[Unit.Team.RED] = 0
	grid_root = get_node("GridRoot")
	unit_root = get_node("UnitRoot")
	var hud_layer: CanvasLayer = get_node("HUDLayer")
	hud = hud_layer.get_child(0)
	active_team_label = hud.get_node("ActiveTeamLabel")
	info_label = hud.get_node("InfoLabel")
	log_label = hud.get_node("LogLabel")
	end_turn_button = hud.get_node("EndTurnButton")
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	unit_info_panel = hud.get_node("UnitInfoPanel")
	unit_info_name_label = hud.get_node("UnitInfoPanel/VBox/NameLabel")
	unit_info_rarity_label = hud.get_node("UnitInfoPanel/VBox/RarityLabel")
	unit_info_hp_label = hud.get_node("UnitInfoPanel/VBox/HpLabel")
	unit_info_damage_label = hud.get_node("UnitInfoPanel/VBox/DamageLabel")
	unit_info_defense_label = hud.get_node("UnitInfoPanel/VBox/DefenseLabel")
	unit_info_move_label = hud.get_node("UnitInfoPanel/VBox/MoveLabel")
	unit_info_level_xp_label = hud.get_node("UnitInfoPanel/VBox/LevelXpLabel")
	unit_info_select_hint = hud.get_node("UnitInfoPanel/VBox/SelectHintLabel")
	unit_info_title_label = hud.get_node("UnitInfoPanel/VBox/TitleLabel")
	_ensure_unit_info_panel_controls()
	unit_info_panel.visible = false

	hex_tile_scene = preload("res://scenes/HexTile.tscn")
	unit_scene = preload("res://scenes/Unit.tscn")

	grid = Grid.new(COLS, ROWS, HEX_RADIUS)
	_build_grid()
	_spawn_units()
	_start_team_turn()
	_update_hud()

func _ensure_unit_info_panel_controls() -> void:
	var vbox := unit_info_panel.get_node("VBox") as VBoxContainer
	if vbox == null:
		return
	
	# Ensure panel has enough vertical room for portrait + description.
	unit_info_panel.offset_bottom = max(unit_info_panel.offset_bottom, 360.0)
	unit_info_panel.custom_minimum_size.y = max(unit_info_panel.custom_minimum_size.y, 340.0)
	if unit_info_panel.size.y < 340.0:
		var resized := unit_info_panel.size
		resized.y = 340.0
		unit_info_panel.size = resized
	vbox.custom_minimum_size.y = max(vbox.custom_minimum_size.y, 310.0)
	
	var portrait_node := vbox.get_node_or_null("Portrait")
	if portrait_node is TextureRect:
		unit_info_portrait = portrait_node as TextureRect
	else:
		if portrait_node:
			portrait_node.name = "PortraitLegacy"
			portrait_node.visible = false
		unit_info_portrait = TextureRect.new()
		unit_info_portrait.name = "Portrait"
		unit_info_portrait.custom_minimum_size = Vector2(200, 160)
		unit_info_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		unit_info_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(unit_info_portrait)
		if portrait_node:
			vbox.move_child(unit_info_portrait, portrait_node.get_index())
		else:
			vbox.move_child(unit_info_portrait, 1)
	unit_info_portrait.visible = true
	unit_info_portrait.modulate = Color(1, 1, 1, 1)
	
	var description_node := vbox.get_node_or_null("DescriptionLabel")
	if description_node is Label:
		unit_info_description_label = description_node as Label
	else:
		if description_node:
			description_node.queue_free()
		unit_info_description_label = Label.new()
		unit_info_description_label.name = "DescriptionLabel"
		unit_info_description_label.custom_minimum_size = Vector2(0, 56)
		unit_info_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unit_info_description_label.add_theme_font_size_override("font_size", 13)
		unit_info_description_label.text = "Description: -"
		vbox.add_child(unit_info_description_label)
		var hint_node := vbox.get_node_or_null("SelectHintLabel")
		if hint_node:
			vbox.move_child(unit_info_description_label, hint_node.get_index())
	unit_info_description_label.visible = true

func _build_grid() -> void:
	# Build 10 cols x 20 rows in rectangular (offset) layout; store tiles by axial for logic.
	for row in range(ROWS):
		for col in range(COLS):
			var offset := Vector2i(col, row)
			var coord := Hex.offset_to_axial(offset)
			var tile: Node2D = hex_tile_scene.instantiate()
			grid_root.add_child(tile)
			tile.hex_radius = HEX_RADIUS
			tile.set_coord(coord)
			grid.tiles[coord] = tile

func _spawn_units() -> void:
	for offset in BLUE_OFFSET_STARTS:
		_spawn_unit(Hex.offset_to_axial(offset), Unit.Team.BLUE)
	for offset in RED_OFFSET_STARTS:
		_spawn_unit(Hex.offset_to_axial(offset), Unit.Team.RED)

func _spawn_unit(coord: Vector2i, team: Unit.Team) -> void:
	var u: Unit = unit_scene.instantiate()
	u.team = team
	u.hex_radius = HEX_RADIUS
	u.set_coord(coord)
	# Assign per-team Warrior index for label display.
	var current_count: int = int(team_spawn_counts.get(team, 0))
	current_count += 1
	team_spawn_counts[team] = current_count
	u.unit_type = "Warrior"
	u.unit_index = current_count
	u.refresh_labels()
	grid.set_occupied(coord, u)
	unit_root.add_child(u)
	u.tree_exited.connect(_on_unit_died.bind(team))

func _on_unit_died(_team: Unit.Team) -> void:
	_check_win_condition()

func _start_team_turn() -> void:
	for coord in grid.occupied:
		var u: Unit = grid.occupied[coord]
		if is_instance_valid(u) and u.team == active_team:
			u.has_acted = false
	actions_used_this_turn = 0
	selected_unit = null
	unit_has_moved_this_selection = false
	_clear_highlights()
	_update_selected_unit_panel()

func _clear_highlights() -> void:
	move_options.clear()
	for coord in grid.tiles:
		var tile = grid.tiles[coord]
		if tile.has_method("set_highlight"):
			tile.set_highlight(false)

func _update_hud() -> void:
	var team_name := "BLUE" if active_team == Unit.Team.BLUE else "RED"
	active_team_label.text = "Active: %s" % team_name
	var remaining := _remaining_to_act()
	info_label.text = "Units that can act: %d. " % remaining
	if winner >= 0:
		var wname := "BLUE" if winner == Unit.Team.BLUE else "RED"
		info_label.text = "Winner: %s!" % wname
	elif selected_unit == null:
		info_label.text += "Left-click a unit to view stats. Right-click a friendly unit to select it to move/attack."
	elif not unit_has_moved_this_selection:
		info_label.text += "Click a highlighted tile to move, or click an adjacent enemy to attack."
	else:
		info_label.text += "Click an enemy to attack or click your unit to skip attack."
	end_turn_button.disabled = (winner >= 0)

func _remaining_to_act() -> int:
	var n := 0
	for coord in grid.occupied:
		var u: Unit = grid.occupied[coord]
		if is_instance_valid(u) and u.team == active_team and not u.has_acted:
			n += 1
	var remaining_actions := MAX_ACTIONS_PER_TURN - actions_used_this_turn
	if remaining_actions < 0:
		remaining_actions = 0
	return min(n, remaining_actions)

func _check_win_condition() -> void:
	var blue_alive := false
	var red_alive := false
	for coord in grid.occupied:
		var u: Unit = grid.occupied[coord]
		if not is_instance_valid(u):
			continue
		if u.team == Unit.Team.BLUE:
			blue_alive = true
		else:
			red_alive = true
	if not blue_alive:
		winner = Unit.Team.RED
		_update_hud()
	elif not red_alive:
		winner = Unit.Team.BLUE
		_update_hud()

func _on_end_turn_pressed() -> void:
	if winner >= 0:
		return
	_clear_highlights()
	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null
	inspected_unit = null
	unit_has_moved_this_selection = false
	active_team = Unit.Team.RED if active_team == Unit.Team.BLUE else Unit.Team.BLUE
	_start_team_turn()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(get_global_mouse_position(), false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_click(get_global_mouse_position(), true)

func _handle_click(global_pos: Vector2, is_right_click: bool) -> void:
	if winner >= 0:
		return
	if actions_used_this_turn >= MAX_ACTIONS_PER_TURN and selected_unit == null:
		# No more units can act this turn.
		return
	# Convert to axial in grid space (Main is root; GridRoot has no transform)
	var local := grid_root.get_global_transform().affine_inverse() * global_pos
	var coord := Hex.pixel_to_axial(local, HEX_RADIUS)
	if not grid.in_bounds(coord):
		return

	var u_at: Unit = grid.occupied.get(coord) as Unit

	if selected_unit == null:
		if is_right_click:
			# Right-click on friendly unit that can act = select for action (uses one of 3 moves)
			if u_at and is_instance_valid(u_at) and u_at.team == active_team and not u_at.has_acted:
				selected_unit = u_at
				selected_unit.set_selected(true)
				unit_has_moved_this_selection = false
				move_options.clear()
				for c in grid.movement_range(selected_unit.coord, selected_unit.move_points):
					move_options[c] = true
				_apply_highlights()
				_update_selected_unit_panel()
				_update_hud()
		else:
			# Left-click on any unit = inspect only (show stats); do NOT select for action
			if u_at and is_instance_valid(u_at):
				inspected_unit = u_at
				_update_selected_unit_panel()
				_update_hud()
		return

	# We have a selected unit
	var tile = grid.get_tile(coord)
	if move_options.has(coord):
		# Move to this tile
		grid.set_occupied(selected_unit.coord, null)
		selected_unit.set_coord(coord)
		grid.set_occupied(coord, selected_unit)
		unit_has_moved_this_selection = true
		_clear_highlights()
		move_options.clear()
		_update_hud()
		return

	var target_unit: Unit = grid.occupied.get(coord) as Unit
	if target_unit and is_instance_valid(target_unit) and target_unit.team != selected_unit.team:
		if Hex.axial_distance(selected_unit.coord, target_unit.coord) <= selected_unit.attack_range:
			_resolve_attack(selected_unit, target_unit)
			_finish_unit_action()
			return

	# Click on same unit = skip attack (if we moved) or deselect (if we didn't move)
	if coord == selected_unit.coord:
		if unit_has_moved_this_selection:
			_finish_unit_action()
		else:
			selected_unit.set_selected(false)
			selected_unit = null
			unit_has_moved_this_selection = false
			_clear_highlights()
			move_options.clear()
			_update_selected_unit_panel()
			_update_hud()
		return

	# Click on another unit (while one is selected) = just inspect that unit
	if u_at and is_instance_valid(u_at):
		inspected_unit = u_at
		_update_selected_unit_panel()
		_update_hud()

func _apply_highlights() -> void:
	# Clear only the visual highlight state; keep move_options so movement works.
	for coord in grid.tiles:
		var tile = grid.tiles[coord]
		if tile.has_method("set_highlight"):
			tile.set_highlight(false)
	for c in move_options:
		var t = grid.get_tile(c)
		if t and t.has_method("set_highlight"):
			t.set_highlight(true)

func _resolve_attack(attacker: Unit, target: Unit) -> void:
	var to_hit := rng.randi_range(1, 6)
	var hit := to_hit <= 3
	var damage := attacker.roll_attack_damage(rng) if hit else 0
	log_label.text = "To-hit: %d -> %s, damage %d/%d" % [to_hit, "HIT" if hit else "MISS", damage, attacker.get_max_damage_for_level()]
	# XP: +1 for attacking, +1 if hit
	attacker.gain_xp(1)
	if hit:
		attacker.gain_xp(1)
	var target_level: int = target.level
	var target_coord: Vector2i = target.coord
	var was_inspected: bool = (inspected_unit == target)
	target.apply_damage(damage)
	if target.is_dead():
		grid.set_occupied(target_coord, null)
		if was_inspected:
			inspected_unit = null
		# Kill XP by target level: L1=5, L2=10, L3=20, L4+=20
		var kill_xp: int = 5
		if target_level == 2:
			kill_xp = 10
		elif target_level >= 3:
			kill_xp = 20
		attacker.gain_xp(kill_xp)

func _finish_unit_action() -> void:
	if not selected_unit:
		return
	selected_unit.has_acted = true
	actions_used_this_turn += 1
	var tile = grid.get_tile(selected_unit.coord)
	if tile and tile.has_method("set_claim"):
		tile.set_claim(HexTile.Claim.BLUE if selected_unit.team == Unit.Team.BLUE else HexTile.Claim.RED)
	selected_unit.set_selected(false)
	selected_unit = null
	unit_has_moved_this_selection = false
	_clear_highlights()
	move_options.clear()
	_update_selected_unit_panel()
	_check_win_condition()
	_update_hud()

func _update_selected_unit_panel() -> void:
	if unit_info_panel == null:
		return
	# Show panel for selected_unit (when acting) or inspected_unit (when just viewing)
	if selected_unit and not is_instance_valid(selected_unit):
		selected_unit = null
	if inspected_unit and not is_instance_valid(inspected_unit):
		inspected_unit = null
	var display_unit: Unit = selected_unit if (selected_unit != null) else inspected_unit
	if display_unit == null or not is_instance_valid(display_unit):
		unit_info_panel.visible = false
		return
	unit_info_panel.visible = true
	unit_info_title_label.text = "Selected unit" if selected_unit == display_unit else "Unit info"
	var u: Unit = display_unit
	unit_info_name_label.text = "Name: %s" % u.get_display_name()
	unit_info_rarity_label.text = "Rarity: %s" % u.get_rarity_name()
	unit_info_hp_label.text = "HP: %d/%d" % [u.hp, u.max_hp]
	unit_info_damage_label.text = "Damage: %s" % u.get_damage_expression()
	unit_info_defense_label.text = "Defense: %d" % u.defense
	unit_info_move_label.text = "Move points: %d" % u.move_points
	unit_info_level_xp_label.text = "Level %d  XP %d/%d" % [u.level, u.xp, u.get_xp_required_for_next_level()]
	if unit_info_portrait:
		var portrait_tex := u.get_portrait_texture()
		if portrait_tex == null:
			var fallback := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			fallback.fill(Color(0.75, 0.15, 0.75, 1.0))
			portrait_tex = ImageTexture.create_from_image(fallback)
		unit_info_portrait.texture = portrait_tex
	if unit_info_description_label:
		unit_info_description_label.text = "Description: %s" % u.get_description_text()
	# Hint to right-click when viewing a friendly unit that can still act
	var show_hint: bool = (selected_unit == null and inspected_unit == u and is_instance_valid(u)
		and u.team == active_team and not u.has_acted and actions_used_this_turn < MAX_ACTIONS_PER_TURN)
	unit_info_select_hint.visible = show_hint
