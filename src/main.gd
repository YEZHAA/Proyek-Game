extends Node2D

var _bg: ColorRect
var _grid: Node2D
var _heart_tree: Node2D
var _hud: CanvasLayer
var _tile_menu: Node2D
var _overlay_layer: CanvasLayer
var _skill_tree: Control
var _bestiary: Control
var _creature_arrival: Control
var _tutorial: CanvasLayer

func _ready():
	# 1. Background
	_bg = ColorRect.new()
	_bg.color = GameData.BG_COLOR
	_bg.size = GameData.VIEWPORT_SIZE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	print("Background added")
	
	# 2. GameGrid
	var grid_script = load("res://src/grid/game_grid.gd")
	if grid_script:
		_grid = grid_script.new()
		add_child(_grid)
		print("Grid added, child count: ", _grid.get_child_count())
	else:
		print("Failed to load game_grid.gd")
	
	# 3. HeartTree
	var tree_script = load("res://src/heart_tree/heart_tree.gd")
	if tree_script:
		_heart_tree = tree_script.new()
		_grid.add_child(_heart_tree)
		print("Heart tree added to grid for Y-sorting")
	
	# 4. HUD
	var hud_script = load("res://src/ui/hud.gd")
	if hud_script:
		_hud = hud_script.new()
		add_child(_hud)
		print("HUD added")
	else:
		print("Failed to load hud.gd")
		
	# 5. TileMenu
	var tile_menu_script = load("res://src/ui/tile_menu.gd")
	if tile_menu_script:
		_tile_menu = tile_menu_script.new()
		add_child(_tile_menu)
		
	# 6. Overlay CanvasLayer
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)
	
	# 7. Overlays
	var skill_script = load("res://src/ui/skill_tree_overlay.gd")
	if skill_script:
		_skill_tree = skill_script.new()
		_overlay_layer.add_child(_skill_tree)
		
	var bestiary_script = load("res://src/ui/bestiary_overlay.gd")
	if bestiary_script:
		_bestiary = bestiary_script.new()
		_overlay_layer.add_child(_bestiary)
		
	# 8. Creature Arrival
	var arrival_script = load("res://src/ui/creature_arrival.gd")
	if arrival_script:
		_creature_arrival = arrival_script.new()
		_overlay_layer.add_child(_creature_arrival)
		
	# 9. Tutorial
	var tutorial_script = load("res://src/ui/tutorial.gd")
	if tutorial_script:
		_tutorial = tutorial_script.new()
		add_child(_tutorial)
		
	# 10. Signals
	GameManager.show_overlay.connect(_on_show_overlay)
	GameManager.hide_overlay.connect(_on_hide_overlay)
	GameManager.game_over.connect(_on_game_over)

func _on_show_overlay(overlay_name: String):
	if _skill_tree and overlay_name == "skill_tree":
		_skill_tree.show_overlay()
	if _bestiary and overlay_name == "bestiary":
		_bestiary.show_overlay()

func _on_hide_overlay():
	if _skill_tree and _skill_tree.has_method("hide_overlay"):
		_skill_tree.hide_overlay()
	if _bestiary and _bestiary.has_method("hide_overlay"):
		_bestiary.hide_overlay()

func _on_game_over():
	# Simple ending screen
	var ending = CanvasLayer.new()
	ending.layer = 20
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.size = GameData.VIEWPORT_SIZE
	ending.add_child(bg)
	
	var lbl = Label.new()
	lbl.text = "The forest is whole again.\nThank you, Luma."
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = GameData.VIEWPORT_SIZE
	ending.add_child(lbl)
	add_child(ending)
