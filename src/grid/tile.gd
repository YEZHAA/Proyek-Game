extends Node2D

const TILE_DIAMOND := [
	Vector2(0, -16),
	Vector2(32, 0),
	Vector2(0, 16),
	Vector2(-32, 0),
]
const TILE_DIAMOND_CLOSED := [
	Vector2(0, -16),
	Vector2(32, 0),
	Vector2(0, 16),
	Vector2(-32, 0),
	Vector2(0, -16),
]
const TILE_AXIS_X := Vector2(2, 1)
const TILE_AXIS_Y := Vector2(-2, 1)
const TILE_VISUAL_SCALE := 1.0
const CLEAR_POP_SCALE := 1.18

var grid_pos: Vector2i = Vector2i.ZERO
var state: String = "barren"
var flora_node: Node2D = null
var _sprite: Sprite2D
var _highlight_fill: Polygon2D
var _highlight_outline: Line2D
var _hover: bool = false
var _area: Area2D

func setup(pos: Vector2i):
	grid_pos = pos
	state = GameManager.tile_states.get(pos, "barren")
	
	_sprite = Sprite2D.new()
	_sprite.texture = SpriteGen.get_texture("tile_barren" if state == "barren" else "tile_clear")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Isometric transform for 16x16 tile to become 64x32 diamond
	_set_tile_visual_scale(TILE_VISUAL_SCALE)
	add_child(_sprite)
	
	_area = Area2D.new()
	var shape = CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array(TILE_DIAMOND)
	_area.add_child(shape)
	_area.input_event.connect(_on_input)
	_area.mouse_entered.connect(func(): _set_hovered(true))
	_area.mouse_exited.connect(func(): _set_hovered(false))
	add_child(_area)

	_highlight_fill = Polygon2D.new()
	_highlight_fill.polygon = PackedVector2Array(TILE_DIAMOND)
	_highlight_fill.color = Color(1, 1, 1, 0.18)
	_highlight_fill.visible = false
	add_child(_highlight_fill)

	_highlight_outline = Line2D.new()
	_highlight_outline.points = PackedVector2Array(TILE_DIAMOND_CLOSED)
	_highlight_outline.default_color = Color(1, 1, 1, 0.55)
	_highlight_outline.width = 1.5
	_highlight_outline.visible = false
	add_child(_highlight_outline)
	
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
			_set_tile_visual_scale(TILE_VISUAL_SCALE)
		"clear":
			_sprite.texture = SpriteGen.get_texture("tile_clear")
			_animate_clear()
		"planted":
			_sprite.texture = SpriteGen.get_texture("tile_clear")
			_set_tile_visual_scale(TILE_VISUAL_SCALE)

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
	_set_tile_visual_scale(CLEAR_POP_SCALE)
	tween.tween_method(Callable(self, "_set_tile_visual_scale"), CLEAR_POP_SCALE, TILE_VISUAL_SCALE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _set_tile_visual_scale(visual_scale: float) -> void:
	if not _sprite:
		return
	_sprite.transform = Transform2D(TILE_AXIS_X * visual_scale, TILE_AXIS_Y * visual_scale, Vector2.ZERO)

func _set_hovered(is_hovered: bool) -> void:
	_hover = is_hovered
	if _highlight_fill:
		_highlight_fill.visible = is_hovered
	if _highlight_outline:
		_highlight_outline.visible = is_hovered
	queue_redraw()

func _draw():
	if _hover and state == "barren":
		var cost = Economy.get_clear_cost(GameManager.cleared_count)
		var can = GameManager.can_afford(cost)
		var col = Color(0.5, 1, 0.5) if can else Color(1, 0.5, 0.5)
		draw_circle(Vector2(24, -24), 4, col)
