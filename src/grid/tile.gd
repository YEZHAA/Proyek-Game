extends Node2D

var grid_pos: Vector2i = Vector2i.ZERO
var state: String = "barren"
var flora_node: Node2D = null
var _sprite: Sprite2D
var _hover: bool = false
var _area: Area2D

func setup(pos: Vector2i):
	grid_pos = pos
	state = GameManager.tile_states.get(pos, "barren")
	
	_sprite = Sprite2D.new()
	_sprite.texture = SpriteGen.get_texture("tile_barren" if state == "barren" else "tile_clear")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Isometric transform for 16x16 tile to become 64x32 diamond
	_sprite.transform = Transform2D(Vector2(2, 1), Vector2(-2, 1), Vector2(0, 0))
	add_child(_sprite)
	
	_area = Area2D.new()
	var shape = CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)])
	_area.add_child(shape)
	_area.input_event.connect(_on_input)
	_area.mouse_entered.connect(func(): _hover = true; queue_redraw())
	_area.mouse_exited.connect(func(): _hover = false; queue_redraw())
	add_child(_area)
	
	GameManager.tile_changed.connect(_on_tile_changed)
	GameManager.flora_planted.connect(_on_flora_planted)
	
	if state == "planted" and pos in GameManager.flora_map:
		_create_flora(GameManager.flora_map[pos].tier)

func _on_input(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			match state:
				"barren":
					GameManager.try_clear(grid_pos)
				"clear":
					var screen_pos = global_position
					GameManager.show_tile_menu.emit(grid_pos, screen_pos)
				"planted":
					GameManager.do_tap(grid_pos)
					if flora_node and flora_node.has_method("on_tapped"):
						flora_node.on_tapped()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if state == "planted" and grid_pos in GameManager.flora_map:
				var tier = GameManager.flora_map[grid_pos].tier
				var cost = GameData.FLORA[tier].cost
				# Sell for 50%
				GameManager.earn_dewdrops(cost * 0.5)
				GameManager.flora_map.erase(grid_pos)
				GameManager.tile_states[grid_pos] = "clear"
				state = "clear"
				GameManager.tile_changed.emit(grid_pos, "clear")
				if flora_node:
					flora_node.queue_free()
					flora_node = null

func _on_tile_changed(pos: Vector2i, new_state: String):
	if pos != grid_pos: return
	state = new_state
	match state:
		"barren":
			_sprite.texture = SpriteGen.get_texture("tile_barren")
		"clear":
			_sprite.texture = SpriteGen.get_texture("tile_clear")
			_animate_clear()
		"planted":
			_sprite.texture = SpriteGen.get_texture("tile_clear")

func _on_flora_planted(pos: Vector2i, tier: int):
	if pos != grid_pos: return
	_create_flora(tier)

func _create_flora(tier: int):
	var flora_script = load("res://src/flora/flora.gd")
	if flora_script:
		flora_node = flora_script.new()
		add_child(flora_node)
		flora_node.setup(tier, grid_pos)

func _animate_clear():
	var tween = create_tween()
	_sprite.scale = Vector2(5, 5)
	tween.tween_property(_sprite, "scale", Vector2(4, 4), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _draw():
	if _hover:
		var rect = Rect2(-32, -32, 64, 64)
		draw_rect(rect, Color(1, 1, 1, 0.15))
	
	if _hover and state == "barren":
		var cost = Economy.get_clear_cost(GameManager.cleared_count)
		var can = GameManager.can_afford(cost)
		var col = Color(0.5, 1, 0.5) if can else Color(1, 0.5, 0.5)
		draw_circle(Vector2(24, -24), 4, col)
