extends Node2D
## Radial menu that appears AT the tapped Clear tile.
## Shows available seeds (unlocked Tiers) with Dewdrop costs.
## Contextual, inline — the player tends the garden directly, never visits a shop.
## Node position moves to the tile's screen position; drawing is local to Vector2.ZERO.

var _is_visible: bool = false
var _target_pos: Vector2i = Vector2i.ZERO
var _buttons: Array[Dictionary] = []
var _bg_alpha: float = 0.0
var _hover_index: int = -1

const RADIUS: float = 58.0
const BTN_RADIUS: float = 24.0
const LABEL_OFFSET: float = 14.0


func _ready() -> void:
	visible = false
	z_index = 10
	GameManager.show_tile_menu.connect(_on_show)
	GameManager.hide_tile_menu.connect(_on_hide)
	GameManager.flora_planted.connect(func(_p: Vector2i, _t: int) -> void: _on_hide())


func _on_show(pos: Vector2i, screen_pos: Vector2) -> void:
	if GameManager.game_input_locked:
		return

	GameManager.set_seed_menu_focused(true)
	_target_pos = pos
	position = screen_pos  # Move node to tile screen location
	visible = true
	_is_visible = true
	_hover_index = -1
	_build_menu()

	# Animate in
	_bg_alpha = 0.0
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_bg_alpha = v
		queue_redraw()
	, 0.0, 1.0, 0.2).set_ease(Tween.EASE_OUT)


func _on_hide() -> void:
	if not _is_visible:
		GameManager.set_seed_menu_focused(false)
		return
	visible = false
	_is_visible = false
	_buttons.clear()
	_hover_index = -1
	GameManager.set_seed_menu_focused(false)


func _build_menu() -> void:
	_buttons.clear()
	var tiers: Array = GameManager.unlocked_tiers.duplicate()
	tiers.sort()
	var count: int = tiers.size()
	if count == 0:
		return

	for i in range(count):
		var tier: int = tiers[i]
		# Distribute evenly starting from top (-PI/2)
		var angle: float = -PI / 2.0 + (TAU * float(i) / float(count))
		var btn_pos := Vector2(cos(angle), sin(angle)) * RADIUS
		var flora_data: Dictionary = GameData.FLORA[tier]
		var can_afford: bool = GameManager.can_afford(flora_data.cost)
		_buttons.append({
			"tier": tier,
			"pos": btn_pos,
			"name": flora_data.name,
			"cost": flora_data.cost,
			"color": flora_data.color as Color,
			"affordable": can_afford,
			"radius": BTN_RADIUS,
		})


func _draw() -> void:
	if not _is_visible:
		return

	var center := Vector2.ZERO  # Drawing is relative to node position

	# ── Soft glow behind center ──
	var glow_color := Color(0.4, 0.7, 0.5, 0.15 * _bg_alpha)
	draw_circle(center, RADIUS + 12.0, glow_color)

	# ── Connecting lines from center to each button ──
	for i in range(_buttons.size()):
		var btn: Dictionary = _buttons[i]
		var btn_pos: Vector2 = btn.pos
		var line_col := Color(0.6, 0.8, 0.6, 0.25 * _bg_alpha)
		draw_line(center, btn_pos, line_col, 1.0, true)

	# ── Draw each seed button ──
	for i in range(_buttons.size()):
		var btn: Dictionary = _buttons[i]
		var btn_pos: Vector2 = btn.pos
		var col: Color = btn.color if btn.affordable else Color(0.3, 0.3, 0.35)
		var is_hovered: bool = (i == _hover_index)
		var r: float = btn.radius + (3.0 if is_hovered else 0.0)

		# Button fill — darker shade
		var fill_col := Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.85 * _bg_alpha)
		draw_circle(btn_pos, r, fill_col)

		# Button border ring
		var ring_col := Color(col.r, col.g, col.b, 0.9 * _bg_alpha)
		draw_arc(btn_pos, r, 0, TAU, 32, ring_col, 2.0)

		# Inner highlight (top-left crescent illusion)
		var highlight_col := Color(col.r + 0.2, col.g + 0.2, col.b + 0.2, 0.35 * _bg_alpha)
		draw_arc(btn_pos + Vector2(-2, -2), r * 0.6, -PI * 0.8, PI * 0.2, 12, highlight_col, 1.5)

		# Flora sprite (small) centered in button
		var flora_texture: Texture2D = SpriteGen.get_texture(btn.name.to_lower())
		if flora_texture:
			var tex_size := Vector2(20, 20)
			var tex_rect := Rect2(btn_pos - tex_size * 0.5, tex_size)
			var tex_mod := Color(1, 1, 1, _bg_alpha) if btn.affordable else Color(0.5, 0.5, 0.5, _bg_alpha * 0.6)
			draw_texture_rect(flora_texture, tex_rect, false, tex_mod)

		# Cost text below button
		var cost_text: String = _format_cost(btn.cost)
		var cost_col: Color
		if btn.affordable:
			cost_col = Color(0.55, 1.0, 0.6, _bg_alpha)
		else:
			cost_col = Color(1.0, 0.45, 0.4, _bg_alpha)

		# Draw cost indicator dot + we'll use draw_string if a font is available,
		# otherwise a colored dot as cost-affordable indicator
		var dot_pos := btn_pos + Vector2(0, r + LABEL_OFFSET)
		draw_circle(dot_pos, 4.0, cost_col)

		# Second indicator dot for tier level
		var tier_dot_pos := btn_pos + Vector2(0, -(r + 8.0))
		for t in range(btn.tier):
			var offset_x: float = (float(t) - float(btn.tier - 1) * 0.5) * 6.0
			draw_circle(tier_dot_pos + Vector2(offset_x, 0), 2.0, Color(col.r, col.g, col.b, 0.6 * _bg_alpha))

	# ── Center node (small anchor dot) ──
	draw_circle(center, 4.0, Color(0.7, 0.9, 0.7, 0.5 * _bg_alpha))


func _input(event: InputEvent) -> void:
	if GameManager.game_input_locked:
		return

	if not _is_visible:
		return

	# ── Hover detection ──
	if event is InputEventMouseMotion:
		var local_pos: Vector2 = (event as InputEventMouseMotion).position - position
		_hover_index = -1
		for i in range(_buttons.size()):
			if local_pos.distance_to(_buttons[i].pos) <= _buttons[i].radius + 4.0:
				_hover_index = i
				break
		queue_redraw()
		return

	# ── Click detection ──
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mouse_local: Vector2 = (event as InputEventMouseButton).position - position
		for i in range(_buttons.size()):
			var btn: Dictionary = _buttons[i]
			if mouse_local.distance_to(btn.pos) <= btn.radius + 4.0:
				if btn.affordable:
					GameManager.try_plant(_target_pos, btn.tier)
				else:
					# Feedback: shake the button briefly
					_shake_button(i)
				_on_hide()
				get_viewport().set_input_as_handled()
				return

		# Clicked outside any button — close menu
		_on_hide()
		get_viewport().set_input_as_handled()


func _shake_button(_index: int) -> void:
	# Visual feedback for "can't afford" — brief position shake
	var original_pos := position
	var tween := create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(3, 0), 0.04)
	tween.tween_property(self, "position", original_pos + Vector2(-3, 0), 0.04)
	tween.tween_property(self, "position", original_pos, 0.04)


func _format_cost(cost: float) -> String:
	if cost < 1000.0:
		return "%d" % int(cost)
	else:
		return "%.1fK" % (cost / 1000.0)
