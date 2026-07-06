extends Control
## Full-screen overlay showing collected Mythical Creatures.
## The Bestiary IS the story-progress display — each creature = one chapter.
## Arrived creatures show full sprite + lore. Unknown ones are dark silhouettes.
## By endgame, the Bestiary is complete (all creatures collected).

var _is_open: bool = false
var _bg: ColorRect
var _title_label: Label
var _close_btn: Button
var _scroll: ScrollContainer
var _entries_container: VBoxContainer


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	GameManager.creature_arrived.connect(func(_id: String) -> void:
		if _is_open:
			_build_entries()
	)


func show_overlay() -> void:
	visible = true
	_is_open = true
	_build_ui()
	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)


func hide_overlay() -> void:
	_is_open = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: visible = false)


func _build_ui() -> void:
	# Clear all children
	for c in get_children():
		c.queue_free()

	# ── Background — deep dark with slight warmth ──
	_bg = ColorRect.new()
	_bg.name = "BestiaryBackground"
	_bg.color = Color(0.06, 0.05, 0.09, 0.94)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# ── Title ──
	_title_label = Label.new()
	_title_label.name = "BestiaryTitle"
	_title_label.text = "📖 Bestiary"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	_title_label.position = Vector2(20, 20)
	add_child(_title_label)

	# ── Progress indicator ──
	var arrived_count: int = GameManager.arrived_creatures.size()
	var total_count: int = GameData.CREATURE_ORDER.size()
	var progress_label := Label.new()
	progress_label.name = "BestiaryProgress"
	progress_label.text = "%d / %d discovered" % [arrived_count, total_count]
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.45, 0.7))
	progress_label.position = Vector2(20, 50)
	add_child(progress_label)

	# ── Close button ──
	_close_btn = Button.new()
	_close_btn.name = "BestiaryCloseButton"
	_close_btn.text = "✕"
	_close_btn.position = Vector2(520, 15)
	_close_btn.size = Vector2(40, 40)
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.15, 0.12, 0.2)
	close_style.corner_radius_top_left = 8
	close_style.corner_radius_top_right = 8
	close_style.corner_radius_bottom_left = 8
	close_style.corner_radius_bottom_right = 8
	_close_btn.add_theme_stylebox_override("normal", close_style)
	_close_btn.add_theme_color_override("font_color", Color(0.7, 0.6, 0.6))
	_close_btn.pressed.connect(func() -> void: GameManager.hide_overlay.emit())
	add_child(_close_btn)

	# ── Scrollable creature list ──
	_scroll = ScrollContainer.new()
	_scroll.name = "BestiaryScroll"
	_scroll.position = Vector2(16, 75)
	_scroll.size = Vector2(544, 620)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_entries_container = VBoxContainer.new()
	_entries_container.name = "BestiaryEntriesContainer"
	_entries_container.add_theme_constant_override("separation", 16)
	_entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_entries_container)

	_build_entries()


func _build_entries() -> void:
	# Clear existing entries
	for c in _entries_container.get_children():
		c.queue_free()

	for creature_id in GameData.CREATURE_ORDER:
		var data: Dictionary = GameData.CREATURES[creature_id]
		var arrived: bool = creature_id in GameManager.arrived_creatures
		_entries_container.add_child(_make_creature_entry(creature_id, data, arrived))


func _make_creature_entry(creature_id: String, data: Dictionary, arrived: bool) -> PanelContainer:
	var entry := PanelContainer.new()
	entry.name = "CreatureEntry_%s" % creature_id

	var style := StyleBoxFlat.new()
	if arrived:
		style.bg_color = Color(0.12, 0.11, 0.16, 0.95)
		style.border_width_left = 3
		style.border_color = data.color * 0.8
	else:
		style.bg_color = Color(0.08, 0.08, 0.10, 0.8)
		style.border_width_left = 1
		style.border_color = Color(0.2, 0.2, 0.25, 0.3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	entry.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# ── Creature sprite ──
	var tex_rect := TextureRect.new()
	tex_rect.name = "CreatureSprite_%s" % creature_id
	tex_rect.texture = SpriteGen.get_texture(creature_id)
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.custom_minimum_size = Vector2(64, 64)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not arrived:
		# Dark silhouette — mysterious, inviting discovery
		tex_rect.modulate = Color(0.08, 0.08, 0.12, 0.9)
	hbox.add_child(tex_rect)

	# ── Info column ──
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Name
	var name_label := Label.new()
	name_label.name = "CreatureName_%s" % creature_id
	if arrived:
		name_label.text = data.name
		name_label.add_theme_color_override("font_color", data.color)
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	# Trigger info (how to unlock)
	if arrived:
		var trigger_label := Label.new()
		trigger_label.text = "✧ Arrived"
		trigger_label.add_theme_font_size_override("font_size", 11)
		trigger_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55, 0.8))
		vbox.add_child(trigger_label)
	else:
		var hint_label := Label.new()
		# Give a vague hint based on trigger type
		if data.has("trigger") and data.trigger == "dewdrops":
			hint_label.text = "Arrives when dewdrops reach %d..." % data.threshold
		else:
			hint_label.text = "Awaiting the forest's call..."
		hint_label.add_theme_font_size_override("font_size", 11)
		hint_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45, 0.6))
		vbox.add_child(hint_label)

	# Lore description (only when arrived)
	if arrived and data.has("desc"):
		var desc_label := Label.new()
		desc_label.name = "CreatureDesc_%s" % creature_id
		desc_label.text = data.desc
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)

	hbox.add_child(vbox)
	entry.add_child(hbox)
	return entry
