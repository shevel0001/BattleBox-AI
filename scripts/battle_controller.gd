extends Node2D
## Main battle: grid, units, turn order, input, attack, win condition.

const COLS: int = 10
const ROWS: int = 20
const HEX_RADIUS: float = 42.0

const STARTING_ARMY_POINTS: int = 10
const UNIT_DRAFT_OPTIONS := [
	{
		"id": "warrior_l1",
		"display_name": "Level 1 Warrior",
		"cost": 1,
		"unit_type": "Warrior"
	}
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
var is_draft_phase: bool = true
var draft_team_order: Array = [Unit.Team.BLUE, Unit.Team.RED]
var current_draft_index: int = 0
var team_points_remaining: Dictionary = {}
var team_draft_counts: Dictionary = {}

var draft_panel: PanelContainer
var draft_title_label: Label
var draft_points_label: Label
var draft_help_label: Label
var draft_finish_button: Button
var draft_option_count_labels: Dictionary = {}
var draft_option_minus_buttons: Dictionary = {}
var draft_option_plus_buttons: Dictionary = {}
var is_deploy_phase: bool = false
var deploy_team: Unit.Team = Unit.Team.BLUE
var deploy_unit_queue: Array[String] = []
var deploy_min_screen_y: float = 0.0
var deploy_max_screen_y: float = 0.0

func _ready() -> void:
	print("Team setup: Spend 10 Army points per team, then start battle.")
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
	_apply_unit_info_font_overrides()
	unit_info_panel.visible = false

	hex_tile_scene = preload("res://scenes/HexTile.tscn")
	unit_scene = preload("res://scenes/Unit.tscn")

	grid = Grid.new(COLS, ROWS, HEX_RADIUS)
	_build_grid()
	_init_team_draft_state()
	_setup_team_draft_ui()
	_update_team_draft_ui()
	_update_hud()

func _ensure_unit_info_panel_controls() -> void:
	var vbox := unit_info_panel.get_node("VBox") as VBoxContainer
	if vbox == null:
		return
	
	# Ensure panel has enough vertical room for portrait + description.
	unit_info_panel.offset_bottom = max(unit_info_panel.offset_bottom, 520.0)
	unit_info_panel.custom_minimum_size.y = max(unit_info_panel.custom_minimum_size.y, 500.0)
	if unit_info_panel.size.y < 500.0:
		var resized := unit_info_panel.size
		resized.y = 500.0
		unit_info_panel.size = resized
	vbox.custom_minimum_size.y = max(vbox.custom_minimum_size.y, 460.0)
	
	var portrait_node := vbox.get_node_or_null("Portrait")
	if portrait_node is TextureRect:
		unit_info_portrait = portrait_node as TextureRect
	else:
		if portrait_node:
			portrait_node.name = "PortraitLegacy"
			portrait_node.visible = false
		unit_info_portrait = TextureRect.new()
		unit_info_portrait.name = "Portrait"
		unit_info_portrait.custom_minimum_size = Vector2(200, 180)
		unit_info_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		unit_info_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(unit_info_portrait)
		if portrait_node:
			vbox.move_child(unit_info_portrait, portrait_node.get_index())
		else:
			vbox.move_child(unit_info_portrait, 1)
	unit_info_portrait.visible = true
	unit_info_portrait.modulate = Color(1, 1, 1, 1)
	unit_info_portrait.custom_minimum_size = Vector2(200, 180)
	unit_info_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unit_info_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
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

func _apply_unit_info_font_overrides() -> void:
	var gothic_font := SystemFont.new()
	gothic_font.font_names = PackedStringArray([
		"Cloister Black",
		"Old English Text MT",
		"UnifrakturCook",
		"Goudy Text MT",
		"Garamond",
		"Georgia"
	])
	
	var labels: Array[Label] = [
		unit_info_title_label,
		unit_info_name_label,
		unit_info_rarity_label,
		unit_info_hp_label,
		unit_info_damage_label,
		unit_info_defense_label,
		unit_info_move_label,
		unit_info_level_xp_label,
		unit_info_description_label,
		unit_info_select_hint
	]
	for label_node in labels:
		if label_node is Label:
			(label_node as Label).add_theme_font_override("font", gothic_font)

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

func _init_team_draft_state() -> void:
	is_draft_phase = true
	is_deploy_phase = false
	current_draft_index = 0
	team_points_remaining.clear()
	team_draft_counts.clear()
	for team in draft_team_order:
		team_points_remaining[team] = STARTING_ARMY_POINTS
		var counts: Dictionary = {}
		for option in UNIT_DRAFT_OPTIONS:
			counts[option["id"]] = 0
		team_draft_counts[team] = counts

func _setup_team_draft_ui() -> void:
	if draft_panel:
		draft_panel.queue_free()
	draft_option_count_labels.clear()
	draft_option_minus_buttons.clear()
	draft_option_plus_buttons.clear()
	
	draft_panel = PanelContainer.new()
	draft_panel.name = "TeamDraftPanel"
	draft_panel.anchor_left = 0.5
	draft_panel.anchor_top = 0.5
	draft_panel.anchor_right = 0.5
	draft_panel.anchor_bottom = 0.5
	draft_panel.offset_left = -220
	draft_panel.offset_top = -170
	draft_panel.offset_right = 220
	draft_panel.offset_bottom = 170
	draft_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(draft_panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	draft_panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	draft_title_label = Label.new()
	draft_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draft_title_label.add_theme_font_size_override("font_size", 28)
	draft_title_label.text = "Select your team"
	vbox.add_child(draft_title_label)
	
	draft_points_label = Label.new()
	draft_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draft_points_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(draft_points_label)
	
	var options_box := VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 8)
	vbox.add_child(options_box)
	
	for option in UNIT_DRAFT_OPTIONS:
		var option_id := String(option["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		options_box.add_child(row)
		
		var option_name := Label.new()
		option_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_name.text = "%s (Cost: %d)" % [option["display_name"], int(option["cost"])]
		row.add_child(option_name)
		
		var minus_button := Button.new()
		minus_button.text = "◀"
		minus_button.tooltip_text = "Decrease unit count"
		minus_button.custom_minimum_size = Vector2(30, 28)
		minus_button.pressed.connect(_on_draft_adjust_pressed.bind(option_id, -1))
		row.add_child(minus_button)
		draft_option_minus_buttons[option_id] = minus_button
		
		var count_label := Label.new()
		count_label.text = "0"
		count_label.custom_minimum_size = Vector2(40, 24)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count_label)
		draft_option_count_labels[option_id] = count_label
		
		var plus_button := Button.new()
		plus_button.text = "▶"
		plus_button.tooltip_text = "Increase unit count"
		plus_button.custom_minimum_size = Vector2(30, 28)
		plus_button.pressed.connect(_on_draft_adjust_pressed.bind(option_id, 1))
		row.add_child(plus_button)
		draft_option_plus_buttons[option_id] = plus_button
	
	draft_help_label = Label.new()
	draft_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	draft_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(draft_help_label)
	
	draft_finish_button = Button.new()
	draft_finish_button.text = "Finish"
	draft_finish_button.pressed.connect(_on_draft_finish_pressed)
	vbox.add_child(draft_finish_button)

func _get_current_draft_team() -> Unit.Team:
	return draft_team_order[current_draft_index]

func _team_name(team: Unit.Team) -> String:
	return "BLUE" if team == Unit.Team.BLUE else "RED"

func _get_draft_option_by_id(option_id: String) -> Dictionary:
	for option in UNIT_DRAFT_OPTIONS:
		if String(option["id"]) == option_id:
			return option
	return {}

func _update_team_draft_ui() -> void:
	if not draft_panel:
		return
	
	var team := _get_current_draft_team()
	var remaining: int = int(team_points_remaining.get(team, 0))
	var team_counts: Dictionary = team_draft_counts.get(team, {})
	var team_number: int = current_draft_index + 1
	
	draft_title_label.text = "Select your team (Team %d - %s)" % [team_number, _team_name(team)]
	draft_points_label.text = "Army Points: %d / %d" % [remaining, STARTING_ARMY_POINTS]
	draft_help_label.text = "Use all Army points, then press Finish."
	draft_finish_button.text = "Finish Team %d" % team_number
	draft_finish_button.disabled = (remaining != 0)
	
	for option in UNIT_DRAFT_OPTIONS:
		var option_id := String(option["id"])
		var count_value: int = int(team_counts.get(option_id, 0))
		var cost: int = int(option["cost"])
		if draft_option_count_labels.has(option_id):
			var count_label := draft_option_count_labels[option_id] as Label
			count_label.text = str(count_value)
		if draft_option_minus_buttons.has(option_id):
			var minus_button := draft_option_minus_buttons[option_id] as Button
			minus_button.disabled = (count_value <= 0)
		if draft_option_plus_buttons.has(option_id):
			var plus_button := draft_option_plus_buttons[option_id] as Button
			plus_button.disabled = (remaining < cost)
	
	unit_info_panel.visible = false

func _on_draft_adjust_pressed(option_id: String, delta: int) -> void:
	if not is_draft_phase:
		return
	
	var option: Dictionary = _get_draft_option_by_id(option_id)
	if option.is_empty():
		return
	
	var team := _get_current_draft_team()
	var team_counts: Dictionary = team_draft_counts.get(team, {})
	var current_value: int = int(team_counts.get(option_id, 0))
	var remaining: int = int(team_points_remaining.get(team, 0))
	var cost: int = int(option["cost"])
	
	if delta > 0:
		if remaining < cost:
			return
		current_value += 1
		remaining -= cost
	elif delta < 0:
		if current_value <= 0:
			return
		current_value -= 1
		remaining += cost
	
	team_counts[option_id] = current_value
	team_draft_counts[team] = team_counts
	team_points_remaining[team] = remaining
	_update_team_draft_ui()
	_update_hud()

func _on_draft_finish_pressed() -> void:
	if not is_draft_phase:
		return
	
	var team := _get_current_draft_team()
	if int(team_points_remaining.get(team, 0)) != 0:
		return
	
	_start_team_deployment(team)

func _start_team_deployment(team: Unit.Team) -> void:
	is_draft_phase = false
	is_deploy_phase = true
	deploy_team = team
	deploy_unit_queue.clear()
	
	var team_counts: Dictionary = team_draft_counts.get(team, {})
	for option in UNIT_DRAFT_OPTIONS:
		var option_id := String(option["id"])
		var count_value: int = int(team_counts.get(option_id, 0))
		for _i in range(count_value):
			deploy_unit_queue.append(option_id)
	
	if draft_panel:
		draft_panel.visible = false
	unit_info_panel.visible = false
	selected_unit = null
	inspected_unit = null
	_cache_deploy_screen_bounds()
	_update_deploy_highlights()
	_update_hud()

func _is_coord_in_team_deploy_rows(coord: Vector2i, team: Unit.Team) -> bool:
	if deploy_max_screen_y <= deploy_min_screen_y:
		return false
	
	var tile_node := grid.get_tile(coord) as Node2D
	if tile_node == null:
		return false
	
	var span: float = maxf(deploy_max_screen_y - deploy_min_screen_y, 1.0)
	var band_size: float = span * (3.0 / float(ROWS))
	var y: float = tile_node.global_position.y
	if team == Unit.Team.BLUE:
		return y <= deploy_min_screen_y + band_size
	return y >= deploy_max_screen_y - band_size

func _cache_deploy_screen_bounds() -> void:
	deploy_min_screen_y = INF
	deploy_max_screen_y = -INF
	
	for coord in grid.tiles:
		var tile_node := grid.get_tile(coord) as Node2D
		if tile_node == null:
			continue
		var y: float = tile_node.global_position.y
		deploy_min_screen_y = minf(deploy_min_screen_y, y)
		deploy_max_screen_y = maxf(deploy_max_screen_y, y)
	
	if deploy_min_screen_y == INF or deploy_max_screen_y == -INF:
		var viewport_rect := get_viewport_rect()
		deploy_min_screen_y = viewport_rect.position.y
		deploy_max_screen_y = viewport_rect.end.y

func _is_valid_deploy_coord(coord: Vector2i, team: Unit.Team) -> bool:
	if not grid.in_bounds(coord):
		return false
	if grid.is_occupied(coord):
		return false
	return _is_coord_in_team_deploy_rows(coord, team)

func _update_deploy_highlights() -> void:
	_clear_highlights()
	for coord in grid.tiles:
		if _is_valid_deploy_coord(coord, deploy_team):
			var tile = grid.get_tile(coord)
			if tile and tile.has_method("set_highlight"):
				tile.set_highlight(true)

func _handle_deploy_click(global_pos: Vector2) -> void:
	if not is_deploy_phase:
		return
	if deploy_unit_queue.is_empty():
		return
	
	var local := grid_root.get_global_transform().affine_inverse() * global_pos
	var coord := Hex.pixel_to_axial(local, HEX_RADIUS)
	if not _is_valid_deploy_coord(coord, deploy_team):
		return
	
	var option_id: String = String(deploy_unit_queue.pop_front())
	var option: Dictionary = _get_draft_option_by_id(option_id)
	var unit_type := String(option.get("unit_type", "Warrior"))
	_spawn_unit(coord, deploy_team, unit_type)
	
	if deploy_unit_queue.is_empty():
		_finish_team_deployment()
	else:
		_update_deploy_highlights()
		_update_hud()

func _finish_team_deployment() -> void:
	is_deploy_phase = false
	_clear_highlights()
	current_draft_index += 1
	if current_draft_index < draft_team_order.size():
		is_draft_phase = true
		if draft_panel:
			draft_panel.visible = true
		_update_team_draft_ui()
		_update_hud()
		return
	_begin_battle_after_draft()

func _begin_battle_after_draft() -> void:
	is_draft_phase = false
	is_deploy_phase = false
	if draft_panel:
		draft_panel.visible = false
	_clear_highlights()
	_start_team_turn()
	_update_hud()
	log_label.text = "Team setup complete. Battle start!"
	print("How to Play: Click a unit (your color) to select. Click a highlighted tile to move. Click an adjacent enemy to attack. Click your unit again to skip attack. Press End Turn when done.")

func _spawn_unit(coord: Vector2i, team: Unit.Team, unit_type: String = "Warrior") -> void:
	var u: Unit = unit_scene.instantiate()
	u.team = team
	u.hex_radius = HEX_RADIUS
	u.set_coord(coord)
	# Assign per-team Warrior index for label display.
	var current_count: int = int(team_spawn_counts.get(team, 0))
	current_count += 1
	team_spawn_counts[team] = current_count
	u.unit_type = unit_type
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
	if is_draft_phase:
		var draft_team: Unit.Team = _get_current_draft_team()
		active_team_label.text = "Select your team"
		info_label.text = "Team %s: choose units with +/- and spend all Army points." % _team_name(draft_team)
		log_label.text = "Army points left: %d" % int(team_points_remaining.get(draft_team, 0))
		end_turn_button.disabled = true
		return
	if is_deploy_phase:
		var rows_text: String = "top 3 rows" if deploy_team == Unit.Team.BLUE else "bottom 3 rows"
		active_team_label.text = "Deploy: %s Team" % _team_name(deploy_team)
		info_label.text = "Place your units on the %s. One unit per hex." % rows_text
		if deploy_unit_queue.is_empty():
			log_label.text = "Deployment complete."
		else:
			var next_option_id: String = String(deploy_unit_queue[0])
			var next_option: Dictionary = _get_draft_option_by_id(next_option_id)
			var next_name := String(next_option.get("display_name", "Unit"))
			log_label.text = "Units left to place: %d | Next: %s" % [deploy_unit_queue.size(), next_name]
		end_turn_button.disabled = true
		return
	
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
	if is_draft_phase or is_deploy_phase:
		return
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
	if is_deploy_phase:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_deploy_click(get_global_mouse_position())
		return
	if is_draft_phase:
		return
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
