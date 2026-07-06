extends CanvasLayer
## Guided tutorial for new players. Steps:
## 1. "luma_tears" — Luma weeps, first tile clears (narrative moment, the bootstrap)
## 2. "first_plant" — Prompt to tap the clear tile and plant starter seed
## 3. "first_tap" — Prompt to tap the planted flora to fill Tap Bar
## 4. "explain_passive" — Brief explanation of passive income (the spine of the game)
## 5. Done — tutorial complete, the forest awaits
##
## The tutorial teaches the core interaction verb: tap-to-interact.

var _current_step: String = ""
var _text_label: Label
var _bg: PanelContainer
var _luma_icon: TextureRect
var _is_active: bool = false
var _step_queue: Array[String] = ["luma_tears", "first_plant", "first_tap", "explain_passive"]
var _step_index: int = 0
var _pulse_tween: Tween = null


func _ready() -> void:
	layer = 5

	if GameManager.tutorial_done:
		queue_free()
		return

	# ── Tutorial panel (bottom of screen, semi-transparent, cozy) ──
	_bg = PanelContainer.new()
	_bg.name = "TutorialPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.09, 0.88)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.border_width_top = 2
	style.border_color = Color(0.3, 0.5, 0.35, 0.4)
	_bg.add_theme_stylebox_override("panel", style)
	_bg.position = Vector2(0, 560)
	_bg.size = Vector2(576, 160)

	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 14)

	# ── Luma sprite (small companion icon) ──
	_luma_icon = TextureRect.new()
	_luma_icon.name = "TutorialLumaIcon"
	_luma_icon.texture = SpriteGen.get_texture("luma")
	_luma_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_luma_icon.custom_minimum_size = Vector2(40, 40)
	_luma_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content_hbox.add_child(_luma_icon)

	# ── Tutorial text ──
	_text_label = Label.new()
	_text_label.name = "TutorialTextLabel"
	_text_label.add_theme_font_size_override("font_size", 15)
	_text_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(_text_label)

	_bg.add_child(content_hbox)
	add_child(_bg)

	# Initial fade-in
	_bg.modulate.a = 0.0

	# Start first step after a brief delay
	await get_tree().create_timer(0.5).timeout
	_fade_in_panel()
	_advance_tutorial()

	# ── Connect game signals ──
	GameManager.tile_changed.connect(_on_tile_changed)
	GameManager.flora_planted.connect(_on_flora_planted)
	GameManager.flora_tapped.connect(_on_flora_tapped)


func _fade_in_panel() -> void:
	var tween := create_tween()
	tween.tween_property(_bg, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)


func _advance_tutorial() -> void:
	if _step_index >= _step_queue.size():
		_finish_tutorial()
		return

	_current_step = _step_queue[_step_index]
	_is_active = true
	GameManager.tutorial_advance.emit(_current_step)

	# Stop any existing pulse
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	match _current_step:
		"luma_tears":
			_set_tutorial_text("✨ Luma weeps over the barren land...\nHer tears heal one tile, bringing hope.")
			# Auto-advance after delay (the starter tile is already cleared)
			await get_tree().create_timer(3.5).timeout
			if _current_step == "luma_tears":  # Guard against race condition
				_step_index += 1
				_advance_tutorial()

		"first_plant":
			_set_tutorial_text("🌱 Tap the green tile to plant your first Mossling!\nFlora produce Dewdrops passively.")
			_start_hint_pulse()

		"first_tap":
			_set_tutorial_text("👆 Tap your Mossling to fill its Tap Bar!\nA full bar gives bonus Dewdrops.")
			_start_hint_pulse()

		"explain_passive":
			_set_tutorial_text("💧 Your flora now produce Dewdrops automatically!\nUse them to clear more land and grow the forest.")
			await get_tree().create_timer(4.5).timeout
			if _current_step == "explain_passive":
				_step_index += 1
				_advance_tutorial()


func _set_tutorial_text(text: String) -> void:
	# Fade out old text, set new, fade in
	var tween := create_tween()
	tween.tween_property(_text_label, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func() -> void: _text_label.text = text)
	tween.tween_property(_text_label, "modulate:a", 1.0, 0.25)


func _start_hint_pulse() -> void:
	# Gentle breathing pulse on the Luma icon to draw attention
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_luma_icon, "modulate", Color(1.2, 1.3, 1.2), 0.8).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_luma_icon, "modulate", Color.WHITE, 0.8).set_ease(Tween.EASE_IN_OUT)


func _on_tile_changed(_pos: Vector2i, state: String) -> void:
	if _current_step == "first_plant" and state == "planted":
		_step_index += 1
		_advance_tutorial()


func _on_flora_planted(_pos: Vector2i, _tier: int) -> void:
	# Handled by _on_tile_changed
	pass


func _on_flora_tapped(_pos: Vector2i) -> void:
	if _current_step == "first_tap":
		_step_index += 1
		_advance_tutorial()


func _finish_tutorial() -> void:
	_is_active = false
	_current_step = "done"
	GameManager.tutorial_done = true

	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_set_tutorial_text("🌿 The forest awaits healing. Good luck, little spirit!")

	var tween := create_tween()
	tween.tween_interval(3.5)
	tween.tween_property(_bg, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: queue_free())
