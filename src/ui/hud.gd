extends CanvasLayer
## The always-visible HUD. Shows ONLY: Dewdrop counter + corner icons.
## Deliberately MINIMAL per the design doc ("Lean UI").
## The garden IS the screen — HUD is a subtle top bar, never a panel wall.

var _dewdrop_label: Label
var _dewdrop_icon: TextureRect
var _income_label: Label
var _skill_btn: TextureButton
var _bestiary_btn: TextureButton
var _panel: PanelContainer


func _ready() -> void:
	layer = 1

	# ── Top bar panel (subtle, semi-transparent, cozy dark purple) ──
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.85)
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_width_bottom = 1
	style.border_color = Color(0.25, 0.22, 0.35, 0.4)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(0, 0)
	_panel.size = Vector2(GameData.VIEWPORT_SIZE.x, 80)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# ── Dewdrop icon ──
	_dewdrop_icon = TextureRect.new()
	_dewdrop_icon.texture = SpriteGen.get_texture("dewdrop")
	_dewdrop_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dewdrop_icon.custom_minimum_size = Vector2(32, 32)
	_dewdrop_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(_dewdrop_icon)

	# ── Dewdrop count ──
	_dewdrop_label = Label.new()
	_dewdrop_label.name = "DewdropCountLabel"
	_dewdrop_label.text = "0.0"
	_dewdrop_label.add_theme_font_size_override("font_size", 28)
	_dewdrop_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	_dewdrop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_dewdrop_label)

	# ── Income rate (small secondary text) ──
	_income_label = Label.new()
	_income_label.name = "IncomeRateLabel"
	_income_label.text = "+0.0/s"
	_income_label.add_theme_font_size_override("font_size", 14)
	_income_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5, 0.7))
	hbox.add_child(_income_label)

	# ── Spacer ──
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# ── Corner icons (Skill Tree, Bestiary) ──
	_skill_btn = _make_icon_btn("icon_skill", "skill_tree", "SkillTreeButton")
	hbox.add_child(_skill_btn)

	_bestiary_btn = _make_icon_btn("icon_bestiary", "bestiary", "BestiaryButton")
	hbox.add_child(_bestiary_btn)
	
	var menu_btn = Button.new()
	menu_btn.text = "MENU"
	menu_btn.add_theme_font_size_override("font_size", 14)
	menu_btn.custom_minimum_size = Vector2(80, 40)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://src/main_menu.tscn"))
	hbox.add_child(menu_btn)

	_panel.add_child(hbox)
	add_child(_panel)

	# ── Connect signals ──
	GameManager.dewdrops_changed.connect(_on_dewdrops_changed)
	_on_dewdrops_changed(GameManager.dewdrops)


func _make_icon_btn(texture_name: String, overlay_name: String, btn_name: String) -> TextureButton:
	var btn := TextureButton.new()
	btn.name = btn_name
	btn.texture_normal = SpriteGen.get_texture(texture_name)
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.custom_minimum_size = Vector2(40, 40)
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func() -> void: GameManager.show_overlay.emit(overlay_name))
	# Hover feedback — subtle scale pulse
	btn.mouse_entered.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.1).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_IN)
	)
	return btn


func _on_dewdrops_changed(amount: float) -> void:
	_dewdrop_label.text = _format_number(amount)
	# Juice: brief flash on the label when dewdrops change
	var tween := create_tween()
	_dewdrop_label.add_theme_color_override("font_color", Color(0.85, 1.0, 1.0))
	tween.tween_property(_dewdrop_label, "theme_override_colors/font_color", Color(0.6, 0.85, 1.0), 0.35)


func _process(_delta: float) -> void:
	var income := GameManager.get_income()
	_income_label.text = "+%s/s" % _format_number(income)


func _format_number(n: float) -> String:
	if n < 1000.0:
		return _format_one_decimal_floor(n)
	elif n < 1_000_000.0:
		return "%sK" % _format_one_decimal_floor(n / 1000.0)
	else:
		return "%.2fM" % (floor((n / 1_000_000.0) * 100.0) / 100.0)


func _format_one_decimal_floor(n: float) -> String:
	return "%.1f" % (floor(n * 10.0) / 10.0)
