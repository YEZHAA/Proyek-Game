extends Node2D

var luminance: float = 0.0
var _sprite: Sprite2D
var _glow_sprite: Sprite2D
var _pulse_tween: Tween

func _ready():
	# Move to the top corner (pojok atas) to avoid blocking plants.
	# The top of the grid is around Y=0. -60 puts it safely behind all tiles.
	var grid_center = Vector2(0, -60)
	position = grid_center
	z_index = 1
	
	_sprite = Sprite2D.new()
	_sprite.texture = SpriteGen.get_texture("heart_tree")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(3, 3)
	_sprite.position = Vector2(0, -24)
	_sprite.modulate.a = 0.4
	add_child(_sprite)
	
	_glow_sprite = Sprite2D.new()
	_glow_sprite.texture = SpriteGen.get_texture("heart_tree_glow")
	_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow_sprite.scale = Vector2(3, 3)
	_glow_sprite.position = Vector2(0, -24)
	_glow_sprite.modulate.a = 0.0
	add_child(_glow_sprite)
	
	GameManager.heart_tree_updated.connect(_on_luminance_changed)
	_start_pulse()

func _on_luminance_changed(new_luminance: float):
	luminance = new_luminance
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.4 + 0.6 * luminance, 0.5)
	tween.parallel().tween_property(_glow_sprite, "modulate:a", luminance * 0.8, 0.5)

func _start_pulse():
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_glow_sprite, "scale", Vector2(3.15, 3.15), 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_glow_sprite, "scale", Vector2(3, 3), 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
