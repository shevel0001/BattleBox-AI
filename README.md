# Hex Tactics Prototype

A minimal playable hex tactics prototype built with Godot 4.x and GDScript.

## Project Structure

```
res://
  scenes/
    Main.tscn          - Main game scene
    Unit.tscn          - Unit scene template
    HexTile.tscn       - Hex tile scene template
  scripts/
    hex.gd             - Hex coordinate utilities (axial system)
    hex_tile.gd        - Individual hex tile logic
    grid.gd            - Grid generation and pathfinding
    unit.gd            - Unit logic (HP, movement, attacks)
    effects.gd         - Status effect system (Poison)
    battle_controller.gd - Main game controller (turns, input)
  project.godot        - Godot project configuration
```

## How to Play

1. **Open the project** in Godot 4.x
2. **Set Main.tscn as the main scene** (already configured in project.godot)
3. **Press Play (F5)**

### Gameplay

- **Click a blue unit** to select it (player units)
- **Green tiles** show movement range
- **Click a green tile** to move the selected unit
- **Click an enemy in attack range** to attack it
- **Poison effect** deals 2 damage per turn for 3 turns (demonstrated on one enemy at start)

### Turn System

- **Player Turn**: Select a unit, move or attack, then turn ends automatically
- **Enemy Turn**: Enemies process effects, then attack if adjacent to player units
- Effects tick at the **start** of each unit's turn

## Features

✅ 2D top-down hex grid using axial coordinates (q, r)  
✅ Unit selection and movement with BFS pathfinding  
✅ Attack system with range checking  
✅ HP tracking displayed above units  
✅ Status effect system (Poison: 3 turns, 2 damage/tick)  
✅ Turn-based system (Player ↔ Enemy)  
✅ Win/lose conditions  

## Technical Details

- **Hex System**: Pointy-top hexagons with axial coordinates
- **Movement**: BFS-based movement range calculation
- **Pathfinding**: BFS pathfinding (unweighted)
- **Effects**: Extensible effect system with turn-based duration
- **Visuals**: Simple colored shapes (no external assets)

## Notes

- Grid size: 10x8 hexes (configurable in grid.gd)
- Units spawn at fixed coordinates
- Some tiles are blocked for variety
- Camera is centered at origin (0, 0)
