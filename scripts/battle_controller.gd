## Main battle controller - handles turn system, input, and game flow

extends Node2D
class_name BattleController

const EffectsScript = preload("res://scripts/effects.gd")

enum TurnSide {
	PLAYER,
	ENEMY
}

var current_turn: TurnSide = TurnSide.PLAYER
var selected_unit: Unit = null
var reachable_tiles: Array = []
var units: Array[Unit] = []
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []

@onready var grid_root: Node2D = $GridRoot
@onready var unit_root: Node2D = $UnitRoot
@onready var overlay_root: Node2D = $OverlayRoot
@onready var ui_layer: CanvasLayer = $UI
@onready var grid: HexGrid = grid_root.get_node("HexGrid") if grid_root.has_node("HexGrid") else null

var unit_scene: PackedScene
var hex_tile_scene: PackedScene

func _ready():
	# Load scenes
	unit_scene = load("res://scenes/Unit.tscn")
	hex_tile_scene = load("res://scenes/HexTile.tscn")
	
	if not unit_scene or not hex_tile_scene:
		push_error("Failed to load required scenes")
		return
	
	# Create grid
	if not grid:
		grid = HexGrid.new()
		grid.name = "HexGrid"
		grid_root.add_child(grid)
	
	# Spawn units
	spawn_units()
	
	# Update UI
	update_turn_label()
	
	print("=== HEX TACTICS PROTOTYPE ===")
	print("How to Play:")
	print("- Click a blue unit to select it")
	print("- Green tiles show movement range")
	print("- Click a green tile to move")
	print("- Click an enemy in range to attack")
	print("- Poison deals 2 damage per turn for 3 turns")

func spawn_units():
	# Spawn 2 player units
	spawn_unit(Unit.Team.PLAYER, Vector2i(-2, -1), "Player1")
	spawn_unit(Unit.Team.PLAYER, Vector2i(-1, -2), "Player2")
	
	# Spawn 2 enemy units
	spawn_unit(Unit.Team.ENEMY, Vector2i(2, 1), "Enemy1")
	spawn_unit(Unit.Team.ENEMY, Vector2i(1, 2), "Enemy2")
	
	# Apply poison to one enemy for demonstration
	if enemy_units.size() > 0:
		var poison = EffectsScript.PoisonEffect.new(3)
		enemy_units[0].effects.add_effect(poison)

func spawn_unit(team: Unit.Team, coord: Vector2i, unit_name: String) -> Unit:
	var unit = unit_scene.instantiate()
	unit.team = team
	unit.name = unit_name
	unit.set_coord(coord)
	unit_root.add_child(unit)
	units.append(unit)
	
	if team == Unit.Team.PLAYER:
		player_units.append(unit)
	else:
		enemy_units.append(unit)
	
	return unit

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_turn != TurnSide.PLAYER:
			return
		
		handle_click(event.position)

func handle_click(mouse_pos: Vector2):
	# Convert to local coordinates
	var local_pos = to_local(mouse_pos)
	
	# First check if clicking on a unit
	var clicked_unit = get_unit_at_position(local_pos)
	
	if clicked_unit:
		if clicked_unit.team == Unit.Team.PLAYER and current_turn == TurnSide.PLAYER:
			select_unit(clicked_unit)
		elif selected_unit and selected_unit.can_attack(clicked_unit.coord):
			# Attack enemy
			selected_unit.attack(clicked_unit)
			# Process effects at end of action
			selected_unit.effects.on_turn_end(selected_unit)
			clear_selection()
			check_game_over()
			end_player_turn()
		return
	
	# Check if clicking on a reachable tile
	var clicked_coord = Hex.pixel_to_axial(local_pos)
	if clicked_coord in reachable_tiles:
		if selected_unit:
			move_unit(selected_unit, clicked_coord)
			clear_selection()
			end_player_turn()

func get_unit_at_position(pos: Vector2) -> Unit:
	var closest_unit: Unit = null
	var closest_dist: float = 999999.0
	
	for unit in units:
		if not unit.is_alive():
			continue
		
		var dist = pos.distance_to(unit.position)
		if dist < 30.0 and dist < closest_dist:  # Within unit radius
			closest_dist = dist
			closest_unit = unit
	
	return closest_unit

func select_unit(unit: Unit) -> void:
	# If another unit was selected, end its turn first
	if selected_unit and selected_unit != unit:
		selected_unit.effects.on_turn_end(selected_unit)
	
	# Process effects at start of unit's turn
	unit.effects.on_turn_start(unit)
	
	selected_unit = unit
	show_movement_range(unit)

func show_movement_range(unit: Unit) -> void:
	clear_highlights()
	reachable_tiles = grid.movement_range(unit.coord, unit.move_points)
	
	# Remove starting tile from reachable
	reachable_tiles.erase(unit.coord)
	
	# Filter out tiles occupied by other units
	var filtered_tiles: Array = []
	for coord in reachable_tiles:
		var occupied = false
		for other_unit in units:
			if other_unit != unit and other_unit.is_alive() and other_unit.coord == coord:
				occupied = true
				break
		if not occupied:
			filtered_tiles.append(coord)
	
	reachable_tiles = filtered_tiles
	
	# Highlight reachable tiles
	for coord in reachable_tiles:
		var tile = grid.get_tile(coord)
		if tile:
			tile.set_highlighted(true)

func clear_highlights() -> void:
	reachable_tiles.clear()
	for tile in grid.tiles.values():
		tile.set_highlighted(false)

func clear_selection() -> void:
	selected_unit = null
	clear_highlights()

func move_unit(unit: Unit, target_coord: Vector2i) -> void:
	# Check if tile is occupied
	for other_unit in units:
		if other_unit != unit and other_unit.is_alive() and other_unit.coord == target_coord:
			return  # Can't move to occupied tile
	
	unit.set_coord(target_coord)
	print("%s moved to (%d, %d)" % [unit.name, target_coord.x, target_coord.y])
	
	# Process effects at end of action
	unit.effects.on_turn_end(unit)

func end_player_turn() -> void:
	current_turn = TurnSide.ENEMY
	update_turn_label()
	clear_selection()
	
	# Process enemy turn after a short delay
	await get_tree().create_timer(0.5).timeout
	process_enemy_turn()

func process_enemy_turn() -> void:
	for enemy in enemy_units:
		if not enemy.is_alive():
			continue
		
		# Process effects at start of turn
		enemy.effects.on_turn_start(enemy)
		
		# Simple AI: attack adjacent player unit if possible
		var attacked = false
		for player in player_units:
			if not player.is_alive():
				continue
			
			if enemy.can_attack(player.coord):
				enemy.attack(player)
				attacked = true
				break
		
		if not attacked:
			# Could move here, but for simplicity just end
			pass
		
		# Process effects at end of turn
		enemy.effects.on_turn_end(enemy)
		
		await get_tree().create_timer(0.3).timeout
	
	check_game_over()
	
	# Switch back to player turn
	current_turn = TurnSide.PLAYER
	update_turn_label()

func check_game_over() -> void:
	# Remove dead units
	var alive_players = []
	var alive_enemies = []
	
	for unit in player_units:
		if unit.is_alive():
			alive_players.append(unit)
		else:
			unit.queue_free()
			units.erase(unit)
	
	for unit in enemy_units:
		if unit.is_alive():
			alive_enemies.append(unit)
		else:
			unit.queue_free()
			units.erase(unit)
	
	player_units = alive_players
	enemy_units = alive_enemies
	
	# Check win/lose conditions
	if player_units.size() == 0:
		print("=== GAME OVER - DEFEAT ===")
		show_message("DEFEAT - All units lost!")
	elif enemy_units.size() == 0:
		print("=== VICTORY ===")
		show_message("VICTORY - All enemies defeated!")

func show_message(text: String) -> void:
	# Simple message display
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 32)
	label.position = Vector2(400, 300)
	ui_layer.add_child(label)

func update_turn_label() -> void:
	var label = ui_layer.get_node_or_null("TurnLabel")
	if not label:
		label = Label.new()
		label.name = "TurnLabel"
		label.position = Vector2(10, 10)
		label.add_theme_font_size_override("font_size", 24)
		ui_layer.add_child(label)
	
	if current_turn == TurnSide.PLAYER:
		label.text = "Turn: PLAYER"
		label.modulate = Color.BLUE
	else:
		label.text = "Turn: ENEMY"
		label.modulate = Color.RED
