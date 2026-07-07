extends Node2D

const TREE_SCALE := Vector2(4.0, 4.0)
const TREE_PULSE_SCALE := Vector2(4.16, 4.16)
const TREE_CENTER_OFFSET := Vector2(0.0, -128.0)

var luminance: float = 0.0
var _sprite: Sprite2D
var _glow_sprite: Sprite2D
var _pulse_tween: Tween

func _ready():
	position = Vector2(0, 180)
	z_index = 0
	
	_sprite = Sprite2D.new()
	_sprite.texture = SpriteGen.get_texture("heart_tree")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = TREE_SCALE
	_sprite.position = TREE_CENTER_OFFSET
	_sprite.modulate.a = 0.52
	add_child(_sprite)
	
	_glow_sprite = Sprite2D.new()
	_glow_sprite.texture = SpriteGen.get_texture("heart_tree_glow")
	_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow_sprite.scale = TREE_SCALE
	_glow_sprite.position = TREE_CENTER_OFFSET
	_glow_sprite.modulate.a = 0.0
	add_child(_glow_sprite)
	
	GameManager.heart_tree_updated.connect(_on_luminance_changed)
	_start_pulse()

func _on_luminance_changed(new_luminance: float):
	luminance = new_luminance
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.52 + 0.48 * luminance, 0.5)
	tween.parallel().tween_property(_glow_sprite, "modulate:a", 0.08 + luminance * 0.72, 0.5)

func _start_pulse():
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_glow_sprite, "scale", TREE_PULSE_SCALE, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_glow_sprite, "scale", TREE_SCALE, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
