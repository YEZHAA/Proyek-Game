extends CanvasLayer
## Guided tutorial for new players.
## Luma introduces the healed starter tile in-world, then leaves the player to tend it.

const BUBBLE_SIZE := Vector2(318, 98)
const BUBBLE_TEXT_INSET := Vector2(16, 10)
const LUMA_TILE_OFFSET := Vector2(-54, -12)
const LUMA_EXIT_OFFSET := Vector2(-132, 42)
const LUMA_BUBBLE_OFFSET := Vector2(22, -120)
const STARTER_BUBBLE_OFFSET := Vector2(42, -128)
const SCREEN_PADDING := 18.0
const HUD_CLEARANCE := 92.0

var _current_step: String = ""
var _text_label: Label
var _speech_bubble: Panel
var _bubble_tail: Polygon2D
var _input_blocker: Control
var _luma_sprite: Sprite2D
var _grid: Node2D
var _is_active: bool = false
var _bubble_visible: bool = false
var _bubble_anchor: String = "luma"
var _step_queue: Array[String] = ["luma_tears", "first_plant", "first_tap", "explain_passive"]
var _step_index: int = 0
var _pulse_tween: Tween = null
var _luma_idle_tween: Tween = null
var _active_creature_arrival: String = ""
var _is_waiting_for_first_plant_transition: bool = false


func _ready() -> void:
	layer = 5

	if GameManager.tutorial_done:
		GameManager.set_game_input_locked(false)
		queue_free()
		return

	_grid = _find_game_grid()
	_build_input_blocker()
	_build_luma()
	_build_speech_bubble()

	await get_tree().create_timer(0.5).timeout
	_advance_tutorial()

	GameManager.tile_changed.connect(_on_tile_changed)
	GameManager.flora_planted.connect(_on_flora_planted)
	GameManager.flora_tapped.connect(_on_flora_tapped)
	GameManager.creature_arrived.connect(_on_creature_arrived)
	GameManager.creature_arrival_finished.connect(_on_creature_arrival_finished)


func _process(_delta: float) -> void:
	if _bubble_visible:
		_position_bubble()


func _build_input_blocker() -> void:
	_input_blocker = Control.new()
	_input_blocker.name = "IntroInputBlocker"
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input_blocker.visible = true
	_input_blocker.gui_input.connect(func(event: InputEvent) -> void:
		if _input_blocker.visible and (event is InputEventMouseButton or event is InputEventMouseMotion):
			get_viewport().set_input_as_handled()
	)
	add_child(_input_blocker)


func _set_intro_input_blocked(is_blocked: bool) -> void:
	if _input_blocker == null:
		return

	_input_blocker.visible = is_blocked
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP if is_blocked else Control.MOUSE_FILTER_IGNORE
	GameManager.set_game_input_locked(is_blocked)


func _find_game_grid() -> Node2D:
	var parent := get_parent()
	if parent == null:
		return null

	for child in parent.get_children():
		if child is Node2D and child.has_method("grid_to_screen"):
			return child

	return null


func _build_luma() -> void:
	if _grid == null:
		return

	_luma_sprite = Sprite2D.new()
	_luma_sprite.name = "IntroLuma"
	_luma_sprite.texture = SpriteGen.get_texture("luma")
	_luma_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_luma_sprite.scale = Vector2(2.6, 2.6)
	_luma_sprite.z_index = 30
	_luma_sprite.modulate.a = 0.0
	_grid.add_child(_luma_sprite)

	_luma_sprite.global_position = _starter_screen_pos() + LUMA_TILE_OFFSET

	var fade_tween := create_tween()
	fade_tween.tween_property(_luma_sprite, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)
	_start_luma_idle()


func _build_speech_bubble() -> void:
	_bubble_tail = Polygon2D.new()
	_bubble_tail.name = "SpeechBubbleTail"
	_bubble_tail.color = Color(0.075, 0.065, 0.11, 0.94)
	_bubble_tail.visible = false
	_bubble_tail.modulate.a = 0.0
	add_child(_bubble_tail)

	_speech_bubble = Panel.new()
	_speech_bubble.name = "LumaSpeechBubble"
	_speech_bubble.visible = false
	_speech_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_bubble.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_speech_bubble.size = BUBBLE_SIZE
	_speech_bubble.modulate.a = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.065, 0.11, 0.94)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.45, 0.68, 0.48, 0.55)
	_speech_bubble.add_theme_stylebox_override("panel", style)

	_text_label = Label.new()
	_text_label.name = "TutorialTextLabel"
	_text_label.position = BUBBLE_TEXT_INSET
	_text_label.size = BUBBLE_SIZE - (BUBBLE_TEXT_INSET * 2.0)
	_text_label.add_theme_font_size_override("font_size", 15)
	_text_label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.86))
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_bubble.add_child(_text_label)

	add_child(_speech_bubble)


func _advance_tutorial() -> void:
	if _step_index >= _step_queue.size():
		_finish_tutorial()
		return

	_current_step = _step_queue[_step_index]
	_is_active = true

	_stop_pulse()

	match _current_step:
		"luma_tears":
			_set_intro_input_blocked(true)
			_set_tutorial_text("I weep for this barren land...\nLet my tears heal one tile.", "luma")
			await get_tree().create_timer(3.5).timeout
			if _current_step == "luma_tears":
				await _play_luma_exit()
				_set_intro_input_blocked(false)
				_step_index += 1
				_advance_tutorial()

		"first_plant":
			_set_tutorial_text("Tap the green tile to plant your first Mossling.\nFlora produce Dewdrops passively.", "starter")
			_start_hint_pulse()

		"first_tap":
			_set_tutorial_text("Tap your Mossling to fill its Tap Bar.\nA full bar gives bonus Dewdrops.", "starter")
			_start_hint_pulse()

		"explain_passive":
			_set_tutorial_text("Your flora now produce Dewdrops automatically.\nUse them to heal more land.", "starter")
			await get_tree().create_timer(4.5).timeout
			if _current_step == "explain_passive":
				_step_index += 1
				_advance_tutorial()


func _set_tutorial_text(text: String, anchor: String) -> void:
	_bubble_anchor = anchor
	_position_bubble()

	if not _bubble_visible:
		_text_label.text = text
		_text_label.modulate.a = 1.0
		_fade_bubble_in()
		return

	var tween := create_tween()
	tween.tween_property(_text_label, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func() -> void:
		_text_label.text = text
		_position_bubble()
	)
	tween.tween_property(_text_label, "modulate:a", 1.0, 0.2)


func _fade_bubble_in() -> void:
	_bubble_visible = true
	_speech_bubble.visible = true
	_bubble_tail.visible = true
	_speech_bubble.modulate.a = 0.0
	_bubble_tail.modulate.a = 0.0
	_position_bubble()

	var tween := create_tween()
	tween.tween_property(_speech_bubble, "modulate:a", 1.0, 0.28).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_bubble_tail, "modulate:a", 1.0, 0.28).set_ease(Tween.EASE_OUT)


func _fade_bubble_out(duration: float = 0.3) -> void:
	if not _bubble_visible:
		return

	_bubble_visible = false
	var tween := create_tween()
	tween.tween_property(_speech_bubble, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_bubble_tail, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_speech_bubble.visible = false
		_bubble_tail.visible = false
	)


func _position_bubble() -> void:
	if _speech_bubble == null or _bubble_tail == null:
		return

	var anchor_pos := _get_anchor_screen_pos()
	var bubble_offset := LUMA_BUBBLE_OFFSET if _bubble_anchor == "luma" else STARTER_BUBBLE_OFFSET
	var viewport_size := _get_viewport_size()
	var desired := anchor_pos + bubble_offset
	desired.x = clampf(desired.x, SCREEN_PADDING, viewport_size.x - BUBBLE_SIZE.x - SCREEN_PADDING)
	desired.y = clampf(desired.y, HUD_CLEARANCE, viewport_size.y - BUBBLE_SIZE.y - SCREEN_PADDING)
	_speech_bubble.position = desired

	var tail_base := desired + Vector2(28, BUBBLE_SIZE.y - 3)
	var tail_tip := anchor_pos + Vector2(6, -14)
	_bubble_tail.polygon = PackedVector2Array([
		tail_base,
		tail_base + Vector2(30, 0),
		tail_tip,
	])


func _get_viewport_size() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return GameData.VIEWPORT_SIZE
	return viewport_size


func _get_anchor_screen_pos() -> Vector2:
	if _bubble_anchor == "luma" and is_instance_valid(_luma_sprite):
		return _luma_sprite.get_global_transform_with_canvas().origin

	return _starter_screen_pos()


func _starter_screen_pos() -> Vector2:
	if _grid != null and _grid.has_method("grid_to_screen"):
		return _grid.grid_to_screen(GameData.STARTER_TILE)

	var iso_x := float(GameData.STARTER_TILE.x - GameData.STARTER_TILE.y) * 32.0
	var iso_y := float(GameData.STARTER_TILE.x + GameData.STARTER_TILE.y) * 16.0
	return Vector2(GameData.VIEWPORT_SIZE.x * 0.5, 220.0) + Vector2(iso_x, iso_y)


func _start_luma_idle() -> void:
	if not is_instance_valid(_luma_sprite):
		return

	if _luma_idle_tween and _luma_idle_tween.is_valid():
		_luma_idle_tween.kill()

	var base_y := _luma_sprite.position.y
	_luma_idle_tween = create_tween().set_loops()
	_luma_idle_tween.tween_property(_luma_sprite, "position:y", base_y - 4.0, 0.9).set_ease(Tween.EASE_IN_OUT)
	_luma_idle_tween.tween_property(_luma_sprite, "position:y", base_y, 0.9).set_ease(Tween.EASE_IN_OUT)


func _play_luma_exit() -> void:
	_stop_pulse()
	_fade_bubble_out(0.28)

	if not is_instance_valid(_luma_sprite):
		return

	if _luma_idle_tween and _luma_idle_tween.is_valid():
		_luma_idle_tween.kill()

	var destination := _luma_sprite.position + LUMA_EXIT_OFFSET
	var tween := create_tween()
	tween.tween_property(_luma_sprite, "position", destination, 1.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_luma_sprite, "modulate:a", 0.0, 1.0).set_delay(0.35).set_ease(Tween.EASE_IN)
	await tween.finished

	if is_instance_valid(_luma_sprite):
		_luma_sprite.queue_free()


func _start_hint_pulse() -> void:
	if _speech_bubble == null:
		return

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_speech_bubble, "scale", Vector2(1.015, 1.015), 0.8).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_speech_bubble, "scale", Vector2.ONE, 0.8).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	if _speech_bubble:
		_speech_bubble.scale = Vector2.ONE


func _on_tile_changed(_pos: Vector2i, state: String) -> void:
	if _current_step == "first_plant" and state == "planted":
		_advance_after_first_plant_cutscene()


func _advance_after_first_plant_cutscene() -> void:
	if _is_waiting_for_first_plant_transition:
		return

	_is_waiting_for_first_plant_transition = true

	# Planting emits tile_changed before creature_arrived, so wait one frame
	# before deciding whether a creature cutscene needs to finish first.
	await get_tree().process_frame

	if _current_step != "first_plant":
		_is_waiting_for_first_plant_transition = false
		return

	if _active_creature_arrival == "jade_rabbit":
		while _active_creature_arrival == "jade_rabbit":
			var finished_creature: String = await GameManager.creature_arrival_finished
			if finished_creature == "jade_rabbit":
				break

	_step_index += 1
	_is_waiting_for_first_plant_transition = false
	_advance_tutorial()


func _on_flora_planted(_pos: Vector2i, _tier: int) -> void:
	pass


func _on_creature_arrived(creature_id: String) -> void:
	_active_creature_arrival = creature_id


func _on_creature_arrival_finished(creature_id: String) -> void:
	if _active_creature_arrival == creature_id:
		_active_creature_arrival = ""


func _on_flora_tapped(_pos: Vector2i) -> void:
	if _current_step == "first_tap":
		_step_index += 1
		_advance_tutorial()


func _finish_tutorial() -> void:
	_is_active = false
	_current_step = "done"
	GameManager.tutorial_done = true
	GameManager.set_game_input_locked(false)

	_stop_pulse()
	_set_tutorial_text("The forest awaits healing.\nGood luck, little spirit.", "starter")

	var tween := create_tween()
	tween.tween_interval(3.5)
	tween.tween_callback(func() -> void: _fade_bubble_out(1.0))
	tween.tween_interval(1.05)
	tween.tween_callback(func() -> void: queue_free())
