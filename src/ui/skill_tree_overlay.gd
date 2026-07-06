extends Control
## Full-screen overlay showing the Skill Tree.
## Per-tier production branches (4 nodes each) + global skill nodes.
## Branch unlock is gated by Mythical Creature arrival (linear narrative).
## Completing all 4 nodes in a branch → unlocks next Tier's Seed.

var _is_open: bool = false
var _close_btn: Button
var _scroll: ScrollContainer
var _nodes_container: VBoxContainer
var _skill_buttons: Dictionary = {}  # "skill_id_index" → Button
var _bg: ColorRect
var _title_label: Label


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks to game below

	# ── Semi-transparent dark background ──
	_bg = ColorRect.new()
	_bg.name = "SkillTreeBackground"
	_bg.color = Color(0.05, 0.04, 0.08, 0.92)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# ── Title ──
	_title_label = Label.new()
	_title_label.name = "SkillTreeTitle"
	_title_label.text = "🌿 Skill Tree"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_title_label.position = Vector2(20, 20)
	add_child(_title_label)

	# ── Close button ──
	_close_btn = Button.new()
	_close_btn.name = "SkillTreeCloseButton"
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

	# ── Scrollable content area ──
	_scroll = ScrollContainer.new()
	_scroll.name = "SkillTreeScroll"
	_scroll.position = Vector2(20, 70)
	_scroll.size = Vector2(536, 620)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_nodes_container = VBoxContainer.new()
	_nodes_container.name = "SkillTreeNodesContainer"
	_nodes_container.add_theme_constant_override("separation", 16)
	_nodes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_nodes_container)

	# ── Build initial tree ──
	_build_tree()

	# ── Connect signals ──
	GameManager.skill_purchased.connect(_on_skill_purchased)
	GameManager.tier_unlocked.connect(func(_t: int) -> void: _build_tree())
	GameManager.dewdrops_changed.connect(func(_a: float) -> void:
		if _is_open:
			_refresh_affordability()
	)


func show_overlay() -> void:
	visible = true
	_is_open = true
	_build_tree()
	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)


func hide_overlay() -> void:
	_is_open = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: visible = false)


func _build_tree() -> void:
	# Clear existing children
	for child in _nodes_container.get_children():
		child.queue_free()
	_skill_buttons.clear()

	# ── Per-tier branches ──
	for tier in range(1, 6):
		var tier_data: Dictionary = GameData.FLORA[tier]
		var is_unlocked: bool = _is_tier_branch_available(tier)

		# Branch header with decorative line
		var header_container := HBoxContainer.new()
		header_container.add_theme_constant_override("separation", 10)

		var tier_icon := TextureRect.new()
		tier_icon.texture = SpriteGen.get_texture(tier_data.name.to_lower())
		tier_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tier_icon.custom_minimum_size = Vector2(24, 24)
		tier_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not is_unlocked:
			tier_icon.modulate = Color(0.3, 0.3, 0.35)
		header_container.add_child(tier_icon)

		var header := Label.new()
		header.name = "TierHeader_%d" % tier
		header.text = "Tier %d — %s" % [tier, tier_data.name]
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", tier_data.color if is_unlocked else Color(0.35, 0.35, 0.4))
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_container.add_child(header)

		# Lock indicator
		if not is_unlocked:
			var lock_label := Label.new()
			lock_label.text = "🔒"
			lock_label.add_theme_font_size_override("font_size", 16)
			header_container.add_child(lock_label)

		_nodes_container.add_child(header_container)

		# Description
		if is_unlocked:
			var desc := Label.new()
			desc.text = "Production ×%.0f%% per node" % (GameData.SKILL_MULT * 100.0)
			desc.add_theme_font_size_override("font_size", 11)
			desc.add_theme_color_override("font_color", Color(0.5, 0.55, 0.5, 0.7))
			_nodes_container.add_child(desc)

		# 4 production nodes in a row
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		var skill_id: String = "tier_%d" % tier
		var current_level: int = GameManager.skill_levels.get(skill_id, 0)
		var cost: int = GameData.SKILL_COSTS[tier]

		for i in range(4):
			var node_btn := _make_skill_node(skill_id, i, current_level, tier, cost, is_unlocked)
			row.add_child(node_btn)

		# Progress indicator (dots below the row)
		var progress_label := Label.new()
		progress_label.text = "%d / 4" % mini(current_level, 4)
		progress_label.add_theme_font_size_override("font_size", 11)
		progress_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5, 0.6))
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		_nodes_container.add_child(row)
		_nodes_container.add_child(progress_label)

		# Separator
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 8)
		sep.add_theme_stylebox_override("separator", _make_separator_style())
		_nodes_container.add_child(sep)

	# ── Global skills section ──
	var global_header := Label.new()
	global_header.name = "GlobalSkillsHeader"
	global_header.text = "🌍 Global Skills"
	global_header.add_theme_font_size_override("font_size", 20)
	global_header.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_nodes_container.add_child(global_header)

	var global_desc := Label.new()
	global_desc.text = "Universal upgrades that affect all flora and actions."
	global_desc.add_theme_font_size_override("font_size", 11)
	global_desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.6))
	_nodes_container.add_child(global_desc)

	for skill_id in GameData.GLOBAL_SKILLS:
		var skill_data: Dictionary = GameData.GLOBAL_SKILLS[skill_id]
		_nodes_container.add_child(_make_global_skill_row(skill_id, skill_data))


func _make_skill_node(skill_id: String, index: int, current_level: int, tier: int, cost: int, is_unlocked: bool) -> Button:
	var btn := Button.new()
	var unique_key: String = "%s_%d" % [skill_id, index]
	btn.name = "SkillNode_%s" % unique_key
	var is_purchased: bool = index < current_level
	var is_next: bool = index == current_level
	var can_buy: bool = is_unlocked and is_next and GameManager.can_afford(cost)

	# Button text
	if is_purchased:
		btn.text = "✦"
	elif is_next and is_unlocked:
		btn.text = "%d" % cost
	else:
		btn.text = "—"

	btn.custom_minimum_size = Vector2(90, 55)
	btn.disabled = not can_buy and not is_purchased
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_buy else Control.CURSOR_ARROW

	# Styling
	var style_normal := StyleBoxFlat.new()
	var style_hover := StyleBoxFlat.new()
	var flora_color: Color = GameData.FLORA[tier].color

	if is_purchased:
		style_normal.bg_color = Color(flora_color.r * 0.7, flora_color.g * 0.7, flora_color.b * 0.7, 0.9)
		style_hover.bg_color = style_normal.bg_color
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9))
	elif can_buy:
		style_normal.bg_color = Color(0.18, 0.32, 0.18, 0.95)
		style_hover.bg_color = Color(0.22, 0.4, 0.22, 0.95)
		btn.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	else:
		style_normal.bg_color = Color(0.12, 0.12, 0.16, 0.8)
		style_hover.bg_color = Color(0.14, 0.14, 0.18, 0.8)
		btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))

	# Rounded corners
	for s in [style_normal, style_hover]:
		s.corner_radius_top_left = 10
		s.corner_radius_top_right = 10
		s.corner_radius_bottom_left = 10
		s.corner_radius_bottom_right = 10
		s.border_width_top = 1
		s.border_width_bottom = 1
		s.border_width_left = 1
		s.border_width_right = 1
		s.border_color = Color(flora_color.r, flora_color.g, flora_color.b, 0.3) if is_unlocked else Color(0.2, 0.2, 0.25, 0.3)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_font_size_override("font_size", 14)

	btn.set_meta("kind", "tier")
	btn.set_meta("skill_id", skill_id)
	btn.set_meta("index", index)
	btn.set_meta("tier", tier)
	btn.set_meta("cost", cost)
	btn.pressed.connect(func() -> void: _try_buy_skill_node(skill_id, index))

	_skill_buttons[unique_key] = btn
	return btn


func _make_global_skill_row(skill_id: String, skill_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "GlobalSkill_%s" % skill_id
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.09, 0.14, 0.7)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Skill name + description
	var name_label := Label.new()
	name_label.text = skill_data.name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = skill_data.desc
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Level dots row
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var cost_label := Label.new()
	cost_label.text = "Cost: %d" % skill_data.cost
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.5, 0.65, 0.5, 0.7))
	row.add_child(cost_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var current_level: int = GameManager.skill_levels.get(skill_id, 0)

	for i in range(skill_data.max_level):
		var btn := _make_global_dot_button(skill_id, i, current_level, skill_data.cost)
		row.add_child(btn)

	vbox.add_child(row)
	panel.add_child(vbox)
	return panel


func _make_global_dot_button(skill_id: String, index: int, current_level: int, cost: int) -> Button:
	var btn := Button.new()
	var unique_key: String = "%s_%d" % [skill_id, index]
	btn.name = "GlobalDot_%s" % unique_key
	var is_purchased: bool = index < current_level
	var is_next: bool = index == current_level
	var can_buy: bool = is_next and GameManager.can_afford(cost)

	btn.text = "●" if is_purchased else "○"
	btn.custom_minimum_size = Vector2(40, 40)
	btn.disabled = not can_buy and not is_purchased
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_buy else Control.CURSOR_ARROW

	var style := StyleBoxFlat.new()
	if is_purchased:
		style.bg_color = Color(0.3, 0.5, 0.8, 0.9)
	elif can_buy:
		style.bg_color = Color(0.18, 0.28, 0.2, 0.9)
	else:
		style.bg_color = Color(0.12, 0.12, 0.16, 0.7)

	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.4, 0.55, 0.8, 0.4) if is_purchased else Color(0.25, 0.25, 0.3, 0.3)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0) if is_purchased else Color(0.4, 0.45, 0.5))
	btn.add_theme_font_size_override("font_size", 18)

	btn.set_meta("kind", "global")
	btn.set_meta("skill_id", skill_id)
	btn.set_meta("index", index)
	btn.set_meta("cost", cost)
	btn.pressed.connect(func() -> void: _try_buy_skill_node(skill_id, index))

	_skill_buttons[unique_key] = btn
	return btn


func _make_separator_style() -> StyleBoxFlat:
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.2, 0.18, 0.28, 0.3)
	sep_style.content_margin_top = 4
	sep_style.content_margin_bottom = 4
	return sep_style


func _is_tier_branch_available(tier: int) -> bool:
	# Tier 1 is always available (gated by owl_spirit, which arrives first)
	if tier == 1:
		return true
	# Higher tiers require the corresponding creature to have arrived
	# Creature order: owl_spirit(0), jade_rabbit(1=tier1), fawn(2=tier2), etc.
	if tier < GameData.CREATURE_ORDER.size():
		var creature_id: String = GameData.CREATURE_ORDER[tier]
		return creature_id in GameManager.arrived_creatures
	return false


func _on_skill_purchased(_skill_id: String) -> void:
	if _is_open:
		_build_tree()  # Full rebuild to update visual states


func _refresh_affordability() -> void:
	# Keep button instances alive while passive income changes Dewdrops.
	# Rebuilding here can swallow a valid click between mouse-down and mouse-up.
	for key in _skill_buttons:
		var btn: Button = _skill_buttons[key]
		if not is_instance_valid(btn):
			continue
		var skill_id: String = str(btn.get_meta("skill_id", ""))
		var index: int = int(btn.get_meta("index", 0))
		var cost: float = float(btn.get_meta("cost", 0.0))
		var current_level: int = GameManager.skill_levels.get(skill_id, 0)
		var is_purchased: bool = index < current_level
		var can_buy: bool = index == current_level and GameManager.can_afford(cost)
		if btn.get_meta("kind", "") == "tier":
			can_buy = can_buy and _is_tier_branch_available(int(btn.get_meta("tier", 0)))
		btn.disabled = not can_buy and not is_purchased
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_buy else Control.CURSOR_ARROW


func _try_buy_skill_node(skill_id: String, index: int) -> void:
	if index != int(GameManager.skill_levels.get(skill_id, 0)):
		return
	if skill_id.begins_with("tier_"):
		var tier := int(skill_id.split("_")[1])
		if not _is_tier_branch_available(tier):
			return
	GameManager.try_buy_skill(skill_id)
