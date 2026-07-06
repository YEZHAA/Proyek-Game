extends Node2D

var tier: int = 1
var grid_pos: Vector2i
var tap_count: int = 0
var _sprite: Sprite2D
var _bob_tween: Tween
var _tap_flash: float = 0.0

func setup(flora_tier: int, pos: Vector2i):
	tier = flora_tier
	grid_pos = pos
	z_index = 1
	
	var flora_name = GameData.FLORA[tier].name.to_lower()
	_sprite = Sprite2D.new()
	_sprite.texture = SpriteGen.get_texture(flora_name)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2.2, 2.2)
	_sprite.position = Vector2(0, -6)
	add_child(_sprite)
	
	_start_idle_anim()
	
	if grid_pos in GameManager.flora_map:
		tap_count = GameManager.flora_map[grid_pos].taps
		
	GameManager.tap_bar_harvested.connect(_on_harvested)

func on_tapped():
	var tween = create_tween()
	_sprite.scale = Vector2(2.6, 2.6)
	tween.tween_property(_sprite, "scale", Vector2(2.2, 2.2), 0.15).set_ease(Tween.EASE_OUT)
	_tap_flash = 0.3
	
	if grid_pos in GameManager.flora_map:
		tap_count = GameManager.flora_map[grid_pos].taps
	queue_redraw()

func _on_harvested(pos: Vector2i, amount: float):
	if pos != grid_pos: return
	tap_count = 0
	queue_redraw()
	
	var tween = create_tween()
	_sprite.scale = Vector2(3.2, 3.2)
	tween.tween_property(_sprite, "scale", Vector2(2.2, 2.2), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _start_idle_anim():
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_sprite, "position:y", -6.0, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_sprite, "position:y", -3.0, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _process(delta):
	if _tap_flash > 0:
		_tap_flash -= delta
		queue_redraw()

func _draw():
	var max_taps = Economy.get_taps_needed(GameManager.skill_levels.get("tap_speed", 0))
	var fill = float(tap_count) / float(max_taps) if max_taps > 0 else 0.0
	
	if fill > 0:
		var bar_width = 48
		var bar_height = 8
		var bar_x = -bar_width / 2
		var bar_y = -40
		
		draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0.15, 0.15, 0.15, 0.8))
		
		var fill_color = GameData.FLORA[tier].color2
		if fill >= 1.0:
			fill_color = Color(1.0, 0.9, 0.3)
		draw_rect(Rect2(bar_x, bar_y, bar_width * fill, bar_height), fill_color)
		
	if _tap_flash > 0:
		var alpha = _tap_flash * 0.5
		draw_circle(Vector2(0, 8), 20, Color(1, 1, 1, alpha))
