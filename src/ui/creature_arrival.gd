extends Control
## Dramatic full-screen animation when a Mythical Creature arrives.
## Each creature arrival IS a story event — a chapter moment.
## Shows the creature sprite large and centered with name, lore, and particle effects.
## Tap anywhere to dismiss after the animation completes.

var _is_showing: bool = false
var _current_creature: String = ""
var _can_dismiss: bool = false
var _particles: Array[Dictionary] = []
var _particle_time: float = 0.0
var _particle_alpha: float = 0.0
var _creature_particle_center := Vector2(GameData.VIEWPORT_SIZE.x * 0.5, 276.0)

const PARTICLE_COUNT: int = 24


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameManager.creature_arrived.connect(_on_creature_arrived)


func _on_creature_arrived(creature_id: String) -> void:
	_current_creature = creature_id
	_show_arrival()


func _show_arrival() -> void:
	visible = true
	_is_showing = true
	_can_dismiss = false
	_particle_time = 0.0
	_particle_alpha = 0.0

	# Clear previous children
	for c in get_children():
		c.queue_free()

	var data: Dictionary = GameData.CREATURES[_current_creature]
	var creature_color: Color = data.color

	# ── Dark overlay with fade in ──
	var bg := ColorRect.new()
	bg.name = "ArrivalBackground"
	bg.color = Color(0.02, 0.02, 0.05, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── Decorative glow circle behind creature ──
	var glow := ColorRect.new()
	glow.name = "ArrivalGlow"
	glow.color = Color(creature_color.r, creature_color.g, creature_color.b, 0.0)
	glow.position = Vector2(GameData.VIEWPORT_SIZE.x / 2 - 100, 180)
	glow.size = Vector2(200, 200)
	glow.modulate.a = 0.0
	add_child(glow)

	# ── Creature sprite (large, centered) ──
	var sprite := TextureRect.new()
	sprite.name = "ArrivalCreatureSprite"
	sprite.texture = SpriteGen.get_texture(_current_creature)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.custom_minimum_size = Vector2(192, 192)
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.position = Vector2(GameData.VIEWPORT_SIZE.x / 2 - 96, 180)
	sprite.pivot_offset = Vector2(96, 96)
	sprite.scale = Vector2(0.4, 0.4)
	sprite.modulate.a = 0.0
	_creature_particle_center = sprite.position + sprite.pivot_offset
	add_child(sprite)

	# ── Name ──
	var name_label := Label.new()
	name_label.name = "ArrivalCreatureName"
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", creature_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 380)
	name_label.size = Vector2(GameData.VIEWPORT_SIZE.x, 50)
	name_label.modulate.a = 0.0
	add_child(name_label)

	# ── Subtitle (creature role) ──
	var subtitle := Label.new()
	subtitle.name = "ArrivalSubtitle"
	subtitle.text = "has arrived"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(creature_color.r, creature_color.g, creature_color.b, 0.6))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 418)
	subtitle.size = Vector2(GameData.VIEWPORT_SIZE.x, 25)
	subtitle.modulate.a = 0.0
	add_child(subtitle)

	# ── Lore text ──
	var lore := Label.new()
	lore.name = "ArrivalLoreText"
	lore.text = data.desc
	lore.add_theme_font_size_override("font_size", 15)
	lore.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.position = Vector2(GameData.VIEWPORT_SIZE.x / 2 - 240, 460)
	lore.size = Vector2(480, 100)
	lore.modulate.a = 0.0
	add_child(lore)

	# ── "Tap to continue" hint ──
	var hint := Label.new()
	hint.name = "ArrivalDismissHint"
	hint.text = "tap to continue"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 620)
	hint.size = Vector2(GameData.VIEWPORT_SIZE.x, 30)
	hint.modulate.a = 0.0
	add_child(hint)

	# ── Initialize floating particles ──
	_init_particles(creature_color)

	# ── Sequenced animation ──
	var tween := create_tween()
	tween.set_parallel(false)

	# Phase 1: Background darkens
	tween.tween_property(bg, "color:a", 0.92, 0.5).set_ease(Tween.EASE_IN_OUT)

	# Phase 2: Glow appears
	tween.tween_property(glow, "modulate:a", 0.15, 0.4).set_ease(Tween.EASE_OUT)

	# Phase 3: Creature materializes (scale up + fade in)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(self, "_particle_alpha", 1.0, 0.8).set_ease(Tween.EASE_OUT)

	# Phase 4: Subtle bounce
	tween.tween_property(sprite, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN)

	# Phase 5: Name appears
	tween.tween_property(name_label, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)

	# Phase 6: Subtitle
	tween.tween_property(subtitle, "modulate:a", 1.0, 0.3)

	# Phase 7: Lore fades in
	tween.tween_property(lore, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)

	# Phase 8: Dismiss hint pulses in
	tween.tween_property(hint, "modulate:a", 0.6, 0.3)
	tween.tween_callback(func() -> void: _can_dismiss = true)

	# Hint pulse loop (gentle breathing)
	tween.tween_property(hint, "modulate:a", 0.3, 0.8).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hint, "modulate:a", 0.6, 0.8).set_ease(Tween.EASE_IN_OUT)


func _init_particles(base_color: Color) -> void:
	_particles.clear()
	for i in range(PARTICLE_COUNT):
		var angle: float = randf() * TAU
		var dist: float = randf_range(60.0, 200.0)
		var speed: float = randf_range(0.3, 1.2)
		var particle_size: float = randf_range(1.5, 4.0)
		var phase: float = randf() * TAU
		_particles.append({
			"angle": angle,
			"dist": dist,
			"speed": speed,
			"size": particle_size,
			"phase": phase,
			"color": Color(
				base_color.r + randf_range(-0.1, 0.1),
				base_color.g + randf_range(-0.1, 0.1),
				base_color.b + randf_range(-0.1, 0.1),
				randf_range(0.2, 0.6)
			),
		})


func _process(delta: float) -> void:
	if not _is_showing:
		return
	_particle_time += delta
	queue_redraw()


func _draw() -> void:
	if not _is_showing:
		return
	if _particle_alpha <= 0.0:
		return

	# Draw floating particles around the creature
	var center := _creature_particle_center
	for p in _particles:
		var current_angle: float = p.angle + _particle_time * p.speed
		var wobble: float = sin(_particle_time * 2.0 + p.phase) * 15.0
		var pos := center + Vector2(
			cos(current_angle) * (p.dist + wobble),
			sin(current_angle) * (p.dist + wobble) * 0.7  # Slight ellipse
		)
		var alpha: float = p.color.a * _particle_alpha * (0.5 + 0.5 * sin(_particle_time * 1.5 + p.phase))
		draw_circle(pos, p.size, Color(p.color.r, p.color.g, p.color.b, alpha))


func _input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if not _can_dismiss:
		# Still animating — block input but consume it
		if event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_dismiss()
		get_viewport().set_input_as_handled()


func _dismiss() -> void:
	var dismissed_creature := _current_creature
	_is_showing = false
	_can_dismiss = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
		for c in get_children():
			c.queue_free()
		_particles.clear()
		GameManager.notify_creature_arrival_finished(dismissed_creature)
	)
