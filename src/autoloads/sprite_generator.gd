extends Node
## SpriteGen — procedural pixel art sprite generator.
## Generates ALL game sprites using Godot's Image API. No external assets needed.
## Every sprite is cached after first generation.
##
## Size conventions:
##   Tiles:     16×16
##   Flora:     16×16
##   Creatures: 32×32
##   Heart Tree: 32×48
##   Icons:     12×12
##   Dewdrop:   12×12
##   Luma:      16×16
##   Particle:   4×4

var _cache: Dictionary = {}


## Public API — returns a cached ImageTexture by sprite name.
func get_texture(sprite_name: String) -> ImageTexture:
	if sprite_name in _cache:
		return _cache[sprite_name]
	var tex := _generate(sprite_name)
	_cache[sprite_name] = tex
	return tex


func _generate(sprite_name: String) -> ImageTexture:
	match sprite_name:
		"tile_barren":     return _make_barren()
		"tile_clear":      return _make_clear()
		"mossling":        return _make_mossling()
		"glowcap":         return _make_glowcap()
		"bamboo":          return _make_bamboo()
		"willowweep":      return _make_willowweep()
		"heartbloom":      return _make_heartbloom()
		"owl_spirit":      return _make_owl_spirit()
		"jade_rabbit":     return _make_jade_rabbit()
		"fawn":            return _make_fawn()
		"mythical_panda":  return _make_mythical_panda()
		"white_stag":      return _make_white_stag()
		"kirin":           return _make_kirin()
		"heart_tree":      return _make_heart_tree()
		"heart_tree_glow": return _make_heart_tree_glow()
		"dewdrop":         return _make_dewdrop()
		"luma":            return _make_luma()
		"icon_skill":      return _make_icon_skill()
		"icon_bestiary":   return _make_icon_bestiary()
		"icon_settings":   return _make_icon_settings()
		"particle":        return _make_particle()
	return _make_placeholder()


# ═══════════════════════════════════════════════════════════════════════════════
# Helper functions
# ═══════════════════════════════════════════════════════════════════════════════

func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


func _fill_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if (Vector2(x, y) - Vector2(cx, cy)).length() <= r:
				img.set_pixel(x, y, col)


func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)


func _fill_rect(img: Image, x1: int, y1: int, x2: int, y2: int, col: Color) -> void:
	for y in range(maxi(0, y1), mini(img.get_height(), y2)):
		for x in range(maxi(0, x1), mini(img.get_width(), x2)):
			img.set_pixel(x, y, col)


func _set_px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, col)


func _draw_line_v(img: Image, x: int, y1: int, y2: int, col: Color) -> void:
	for y in range(maxi(0, y1), mini(img.get_height(), y2 + 1)):
		_set_px(img, x, y, col)


func _draw_line_h(img: Image, y: int, x1: int, x2: int, col: Color) -> void:
	for x in range(maxi(0, x1), mini(img.get_width(), x2 + 1)):
		_set_px(img, x, y, col)


func _blend_px(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or x >= img.get_width() or y < 0 or y >= img.get_height():
		return
	var existing := img.get_pixel(x, y)
	var a := col.a
	var blended := Color(
		existing.r * (1.0 - a) + col.r * a,
		existing.g * (1.0 - a) + col.g * a,
		existing.b * (1.0 - a) + col.b * a,
		maxf(existing.a, a)
	)
	img.set_pixel(x, y, blended)


func _draw_pixel_line(img: Image, from_px: Vector2i, to_px: Vector2i, col: Color, width: int = 1) -> void:
	var x0 := from_px.x
	var y0 := from_px.y
	var x1 := to_px.x
	var y1 := to_px.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var radius := maxi(0, floori(float(width) / 2.0))

	while true:
		for oy in range(-radius, radius + 1):
			for ox in range(-radius, radius + 1):
				if radius == 0 or ox * ox + oy * oy <= radius * radius:
					_set_px(img, x0 + ox, y0 + oy, col)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func _fill_spans(img: Image, spans: Array, col: Color, inflate_x: int = 0, y_offset: int = 0) -> void:
	for span in spans:
		var y := int(span[0]) + y_offset
		_draw_line_h(img, y, int(span[1]) - inflate_x, int(span[2]) + inflate_x, col)


# ═══════════════════════════════════════════════════════════════════════════════
# TILES (16×16)
# ═══════════════════════════════════════════════════════════════════════════════

func _make_barren() -> ImageTexture:
	var img := _img(16, 16)
	var base := Color(0.22, 0.18, 0.15)
	var crack := Color(0.15, 0.12, 0.10)
	var dark := Color(0.12, 0.10, 0.08)

	# Fill base earth
	for y in range(16):
		for x in range(16):
			var noise_val := sin(float(x) * 2.7 + float(y) * 1.3) * 0.03
			img.set_pixel(x, y, Color(base.r + noise_val, base.g + noise_val, base.b + noise_val))

	# Cracks — organic-looking jagged lines
	_set_px(img, 3, 2, crack);  _set_px(img, 4, 3, crack);  _set_px(img, 5, 4, crack)
	_set_px(img, 5, 5, crack);  _set_px(img, 6, 6, crack)
	_set_px(img, 10, 1, crack); _set_px(img, 11, 2, crack); _set_px(img, 11, 3, crack)
	_set_px(img, 12, 4, crack)
	_set_px(img, 2, 9, crack);  _set_px(img, 3, 10, crack); _set_px(img, 4, 10, crack)
	_set_px(img, 5, 11, crack); _set_px(img, 6, 12, crack)
	_set_px(img, 9, 8, crack);  _set_px(img, 10, 9, crack); _set_px(img, 11, 10, crack)
	_set_px(img, 12, 10, crack); _set_px(img, 13, 11, crack)

	# Dark spots — pebbles and divots
	_set_px(img, 1, 5, dark);  _set_px(img, 7, 2, dark)
	_set_px(img, 14, 7, dark); _set_px(img, 8, 13, dark)
	_set_px(img, 3, 14, dark); _set_px(img, 13, 3, dark)

	return _tex(img)


func _make_clear() -> ImageTexture:
	var img := _img(16, 16)
	var base := Color(0.22, 0.38, 0.22)
	var light := Color(0.30, 0.50, 0.30)
	var tuft := Color(0.28, 0.48, 0.28)
	var flower1 := Color(0.9, 0.85, 0.3)
	var flower2 := Color(0.85, 0.5, 0.6)

	# Fill grass base with subtle variation
	for y in range(16):
		for x in range(16):
			var noise_val := sin(float(x) * 3.1 + float(y) * 2.3) * 0.025
			img.set_pixel(x, y, Color(base.r + noise_val, base.g + noise_val * 1.5, base.b + noise_val))

	# Grass tufts — lighter patches
	_set_px(img, 2, 3, light);  _set_px(img, 3, 3, light)
	_set_px(img, 7, 6, light);  _set_px(img, 8, 6, light)
	_set_px(img, 12, 4, light); _set_px(img, 13, 4, light)
	_set_px(img, 4, 10, light); _set_px(img, 5, 10, light)
	_set_px(img, 10, 12, light); _set_px(img, 11, 12, light)
	_set_px(img, 1, 8, tuft);  _set_px(img, 14, 9, tuft)

	# Tiny flower dots
	_set_px(img, 5, 2, flower1)
	_set_px(img, 11, 8, flower2)
	_set_px(img, 3, 13, flower1)
	_set_px(img, 14, 2, flower2)

	return _tex(img)


# ═══════════════════════════════════════════════════════════════════════════════
# FLORA (16×16)
# ═══════════════════════════════════════════════════════════════════════════════

func _make_mossling() -> ImageTexture:
	var img := _img(16, 16)
	var c1: Color = GameData.FLORA[1].color   # darker green
	var c2: Color = GameData.FLORA[1].color2  # lighter green
	var dirt := Color(0.25, 0.20, 0.16)

	# Ground mound — soft mossy hemisphere at bottom
	_fill_ellipse(img, 8.0, 12.0, 6.0, 4.0, c1)
	# Highlight on mound top
	_fill_ellipse(img, 7.0, 11.0, 4.0, 2.5, c2)

	# Tiny dirt edge
	_set_px(img, 2, 14, dirt); _set_px(img, 13, 14, dirt)
	_set_px(img, 3, 15, dirt); _set_px(img, 12, 15, dirt)

	# Sprout 1 — center
	_draw_line_v(img, 7, 5, 9, c1)
	_set_px(img, 6, 5, c2); _set_px(img, 8, 5, c2)  # tiny leaves
	_set_px(img, 7, 4, c2)  # tip

	# Sprout 2 — left
	_draw_line_v(img, 4, 7, 9, c1)
	_set_px(img, 3, 7, c2); _set_px(img, 5, 7, c2)

	# Sprout 3 — right
	_draw_line_v(img, 11, 6, 9, c1)
	_set_px(img, 10, 6, c2); _set_px(img, 12, 6, c2)
	_set_px(img, 11, 5, c2)

	return _tex(img)


func _make_glowcap() -> ImageTexture:
	var img := _img(16, 16)
	var c1: Color = GameData.FLORA[2].color   # blue-purple
	var c2: Color = GameData.FLORA[2].color2  # lighter glow
	var stem := Color(0.55, 0.50, 0.65)
	var glow := Color(0.7, 0.75, 1.0, 0.5)

	# Stem — thin, centered
	_draw_line_v(img, 7, 9, 14, stem)
	_draw_line_v(img, 8, 10, 14, stem)

	# Cap — round mushroom cap
	_fill_circle(img, 7.5, 7.0, 4.5, c1)
	# Cap highlight
	_fill_circle(img, 6.5, 5.5, 2.5, c2)

	# Spots on cap
	_set_px(img, 5, 7, c2); _set_px(img, 10, 6, c2)
	_set_px(img, 8, 4, c2)

	# Glow effect — translucent pixels around cap
	_blend_px(img, 2, 5, glow); _blend_px(img, 3, 3, glow)
	_blend_px(img, 12, 5, glow); _blend_px(img, 11, 3, glow)
	_blend_px(img, 7, 1, glow); _blend_px(img, 8, 2, glow)
	_blend_px(img, 3, 8, glow); _blend_px(img, 12, 8, glow)
	_blend_px(img, 1, 7, glow); _blend_px(img, 13, 7, glow)

	return _tex(img)


func _make_bamboo() -> ImageTexture:
	var img := _img(16, 16)
	var c1: Color = GameData.FLORA[3].color
	var c2: Color = GameData.FLORA[3].color2
	var joint := Color(0.2, 0.6, 0.25)

	# Stalk 1 — left
	_draw_line_v(img, 4, 1, 15, c1)
	_draw_line_v(img, 5, 1, 15, c1)
	_set_px(img, 4, 5, joint); _set_px(img, 5, 5, joint)
	_set_px(img, 4, 10, joint); _set_px(img, 5, 10, joint)

	# Stalk 2 — center-right
	_draw_line_v(img, 9, 2, 15, c1)
	_draw_line_v(img, 10, 2, 15, c1)
	_set_px(img, 9, 7, joint); _set_px(img, 10, 7, joint)
	_set_px(img, 9, 12, joint); _set_px(img, 10, 12, joint)

	# Stalk 3 — far right (shorter)
	_draw_line_v(img, 13, 4, 15, c1)
	_set_px(img, 13, 9, joint)

	# Leaves branching off
	_set_px(img, 2, 4, c2); _set_px(img, 3, 3, c2); _set_px(img, 1, 5, c2)  # left stalk leaves
	_set_px(img, 6, 2, c2); _set_px(img, 7, 1, c2)  # left stalk top
	_set_px(img, 11, 4, c2); _set_px(img, 12, 3, c2)  # center stalk leaves
	_set_px(img, 8, 6, c2); _set_px(img, 7, 5, c2)  # center left
	_set_px(img, 14, 6, c2); _set_px(img, 15, 5, c2)  # right stalk leaves

	# Tip highlights
	_set_px(img, 4, 1, c2); _set_px(img, 9, 2, c2); _set_px(img, 13, 4, c2)

	return _tex(img)


func _make_willowweep() -> ImageTexture:
	var img := _img(16, 16)
	var c1: Color = GameData.FLORA[4].color
	var c2: Color = GameData.FLORA[4].color2
	var trunk := Color(0.35, 0.25, 0.18)
	var trunk_light := Color(0.42, 0.32, 0.22)

	# Trunk — center bottom, going up
	_fill_rect(img, 7, 6, 9, 15, trunk)
	_set_px(img, 7, 6, trunk_light); _set_px(img, 8, 5, trunk_light)

	# Drooping branches — left side
	_set_px(img, 6, 5, c1); _set_px(img, 5, 6, c1); _set_px(img, 4, 7, c1)
	_set_px(img, 3, 8, c1); _set_px(img, 3, 9, c1); _set_px(img, 3, 10, c1)
	_set_px(img, 3, 11, c2); _set_px(img, 2, 12, c2)

	_set_px(img, 5, 5, c1); _set_px(img, 4, 6, c1)
	_set_px(img, 2, 7, c1); _set_px(img, 1, 8, c1)
	_set_px(img, 1, 9, c2); _set_px(img, 1, 10, c2); _set_px(img, 1, 11, c2)

	# Drooping branches — right side
	_set_px(img, 9, 5, c1); _set_px(img, 10, 6, c1); _set_px(img, 11, 7, c1)
	_set_px(img, 12, 8, c1); _set_px(img, 12, 9, c1); _set_px(img, 12, 10, c1)
	_set_px(img, 12, 11, c2); _set_px(img, 13, 12, c2)

	_set_px(img, 10, 5, c1); _set_px(img, 11, 6, c1)
	_set_px(img, 13, 7, c1); _set_px(img, 14, 8, c1)
	_set_px(img, 14, 9, c2); _set_px(img, 14, 10, c2); _set_px(img, 14, 11, c2)

	# Crown top
	_set_px(img, 7, 4, c1); _set_px(img, 8, 3, c1); _set_px(img, 8, 4, c1)
	_set_px(img, 6, 4, c2); _set_px(img, 9, 4, c2)

	return _tex(img)


func _make_heartbloom() -> ImageTexture:
	var img := _img(16, 16)
	var c1: Color = GameData.FLORA[5].color   # pink
	var c2: Color = GameData.FLORA[5].color2  # lighter pink
	var stem_col := Color(0.25, 0.55, 0.3)
	var leaf_col := Color(0.35, 0.7, 0.4)
	var glow := Color(1.0, 0.9, 0.4, 0.5)

	# Stem
	_draw_line_v(img, 7, 8, 14, stem_col)
	_draw_line_v(img, 8, 9, 14, stem_col)

	# Leaves on stem
	_set_px(img, 6, 11, leaf_col); _set_px(img, 5, 10, leaf_col)
	_set_px(img, 9, 12, leaf_col); _set_px(img, 10, 11, leaf_col)

	# Heart shape at top — two bumps + point
	# Left bump
	_fill_circle(img, 5.5, 4.5, 2.8, c1)
	# Right bump
	_fill_circle(img, 9.5, 4.5, 2.8, c1)
	# Bottom point of heart
	_set_px(img, 7, 8, c1); _set_px(img, 8, 8, c1)
	_set_px(img, 6, 7, c1); _set_px(img, 9, 7, c1)
	_set_px(img, 7, 7, c1); _set_px(img, 8, 7, c1)

	# Heart highlight
	_set_px(img, 4, 3, c2); _set_px(img, 5, 3, c2)
	_set_px(img, 9, 3, c2); _set_px(img, 10, 3, c2)

	# Gold glow around heart
	_blend_px(img, 3, 2, glow); _blend_px(img, 12, 2, glow)
	_blend_px(img, 2, 5, glow); _blend_px(img, 13, 5, glow)
	_blend_px(img, 7, 1, glow); _blend_px(img, 8, 1, glow)
	_blend_px(img, 5, 1, glow); _blend_px(img, 10, 1, glow)

	return _tex(img)


# ═══════════════════════════════════════════════════════════════════════════════
# CREATURES (32×32)
# ═══════════════════════════════════════════════════════════════════════════════

func _make_owl_spirit() -> ImageTexture:
	var img := _img(32, 32)
	var body := Color(0.55, 0.55, 0.72, 0.85)  # translucent blue-gray
	var light_body := Color(0.65, 0.65, 0.82, 0.9)
	var eye := Color(1.0, 0.95, 0.6)
	var pupil := Color(0.15, 0.12, 0.20)
	var beak := Color(0.8, 0.65, 0.35)
	var wing := Color(0.48, 0.48, 0.65, 0.8)
	var tuft := Color(0.6, 0.58, 0.75)

	# Body — large rounded shape
	_fill_circle(img, 16.0, 18.0, 9.0, body)
	# Lighter chest
	_fill_ellipse(img, 16.0, 20.0, 5.0, 6.0, light_body)

	# Wings — ellipses on sides
	_fill_ellipse(img, 7.0, 18.0, 4.5, 7.0, wing)
	_fill_ellipse(img, 25.0, 18.0, 4.5, 7.0, wing)

	# Head shape — slightly overlapping body
	_fill_circle(img, 16.0, 11.0, 7.0, body)

	# Ear tufts — pointy triangles
	_set_px(img, 10, 4, tuft); _set_px(img, 9, 3, tuft); _set_px(img, 10, 5, tuft)
	_set_px(img, 22, 4, tuft); _set_px(img, 23, 3, tuft); _set_px(img, 22, 5, tuft)

	# Eyes — large round circles
	_fill_circle(img, 13.0, 11.0, 2.5, eye)
	_fill_circle(img, 19.0, 11.0, 2.5, eye)
	# Pupils
	_fill_circle(img, 13.0, 11.0, 1.0, pupil)
	_fill_circle(img, 19.0, 11.0, 1.0, pupil)
	# Eye highlight
	_set_px(img, 12, 10, Color.WHITE)
	_set_px(img, 18, 10, Color.WHITE)

	# Beak
	_set_px(img, 15, 13, beak); _set_px(img, 16, 14, beak); _set_px(img, 17, 13, beak)

	# Feet
	_set_px(img, 13, 26, beak); _set_px(img, 14, 27, beak); _set_px(img, 12, 27, beak)
	_set_px(img, 19, 26, beak); _set_px(img, 20, 27, beak); _set_px(img, 18, 27, beak)

	# Spirit glow outline
	for angle_i in range(12):
		var angle := float(angle_i) * TAU / 12.0
		var gx := int(16.0 + cos(angle) * 12.0)
		var gy := int(16.0 + sin(angle) * 12.0)
		_blend_px(img, gx, gy, Color(0.7, 0.7, 1.0, 0.25))

	return _tex(img)


func _make_jade_rabbit() -> ImageTexture:
	var img := _img(32, 32)
	var c1: Color = GameData.CREATURES["jade_rabbit"].color
	var c2 := Color(0.5, 0.9, 0.6)  # lighter jade
	var eye := Color(0.15, 0.1, 0.1)
	var nose := Color(0.85, 0.55, 0.6)
	var white := Color(0.9, 0.95, 0.9)

	# Body — round sitting shape
	_fill_circle(img, 16.0, 20.0, 8.0, c1)
	# Lighter belly
	_fill_ellipse(img, 16.0, 22.0, 5.0, 5.0, c2)

	# Head — smaller circle on top
	_fill_circle(img, 16.0, 12.0, 6.0, c1)
	# Cheeks
	_fill_circle(img, 13.0, 14.0, 2.0, c2)
	_fill_circle(img, 19.0, 14.0, 2.0, c2)

	# Ears — tall ovals pointing up
	_fill_ellipse(img, 12.0, 4.0, 2.0, 5.0, c1)
	_fill_ellipse(img, 20.0, 4.0, 2.0, 5.0, c1)
	# Inner ears
	_fill_ellipse(img, 12.0, 4.0, 1.0, 3.5, c2)
	_fill_ellipse(img, 20.0, 4.0, 1.0, 3.5, c2)

	# Eyes
	_set_px(img, 13, 11, eye); _set_px(img, 14, 11, eye)
	_set_px(img, 18, 11, eye); _set_px(img, 19, 11, eye)
	# Eye shine
	_set_px(img, 13, 10, Color.WHITE)
	_set_px(img, 18, 10, Color.WHITE)

	# Nose
	_set_px(img, 16, 13, nose)

	# Tiny tail (fluffy white dot)
	_fill_circle(img, 24.0, 20.0, 2.0, white)

	# Paws
	_set_px(img, 12, 27, c2); _set_px(img, 13, 27, c2)
	_set_px(img, 19, 27, c2); _set_px(img, 20, 27, c2)

	return _tex(img)


func _make_fawn() -> ImageTexture:
	var img := _img(32, 32)
	var c1: Color = GameData.CREATURES["fawn"].color  # warm brown
	var c2 := Color(0.9, 0.8, 0.6)  # lighter
	var spot := Color(1.0, 0.92, 0.7)  # golden spots
	var eye := Color(0.12, 0.08, 0.06)
	var leg := Color(0.7, 0.6, 0.4)

	# Body — elongated oval (sideways fawn)
	_fill_ellipse(img, 16.0, 17.0, 10.0, 6.0, c1)
	# Lighter underbelly
	_fill_ellipse(img, 16.0, 20.0, 7.0, 3.0, c2)

	# Head — smaller circle on left side
	_fill_circle(img, 6.0, 12.0, 5.0, c1)
	# Lighter muzzle
	_fill_circle(img, 4.0, 14.0, 2.5, c2)

	# Ears
	_fill_ellipse(img, 4.0, 7.0, 1.5, 2.5, c1)
	_fill_ellipse(img, 9.0, 7.0, 1.5, 2.5, c1)

	# Eye
	_set_px(img, 5, 11, eye); _set_px(img, 6, 11, eye)
	_set_px(img, 5, 10, Color.WHITE)

	# Nose
	_set_px(img, 2, 13, Color(0.3, 0.2, 0.15))

	# Spots on back
	_set_px(img, 12, 14, spot); _set_px(img, 15, 13, spot)
	_set_px(img, 18, 14, spot); _set_px(img, 21, 15, spot)
	_set_px(img, 14, 16, spot); _set_px(img, 20, 13, spot)
	_set_px(img, 10, 15, spot); _set_px(img, 17, 16, spot)

	# Legs — thin lines
	_draw_line_v(img, 10, 22, 28, leg)
	_draw_line_v(img, 13, 22, 28, leg)
	_draw_line_v(img, 19, 22, 28, leg)
	_draw_line_v(img, 22, 22, 28, leg)
	# Hooves
	_set_px(img, 10, 29, Color(0.3, 0.2, 0.15))
	_set_px(img, 13, 29, Color(0.3, 0.2, 0.15))
	_set_px(img, 19, 29, Color(0.3, 0.2, 0.15))
	_set_px(img, 22, 29, Color(0.3, 0.2, 0.15))

	# Small tail
	_set_px(img, 26, 14, c1); _set_px(img, 27, 13, c2)

	return _tex(img)


func _make_mythical_panda() -> ImageTexture:
	var img := _img(32, 32)
	var white := Color(0.92, 0.92, 0.92)
	var dark := Color(0.12, 0.12, 0.14)
	var eye_white := Color(1.0, 1.0, 1.0)
	var leaf := Color(0.35, 0.75, 0.35)
	var nose := Color(0.2, 0.15, 0.15)

	# Large round body (white)
	_fill_circle(img, 16.0, 19.0, 10.0, white)

	# Dark arms
	_fill_ellipse(img, 7.0, 19.0, 4.0, 6.0, dark)
	_fill_ellipse(img, 25.0, 19.0, 4.0, 6.0, dark)

	# Head
	_fill_circle(img, 16.0, 9.0, 7.5, white)

	# Dark ears
	_fill_circle(img, 9.0, 3.0, 3.0, dark)
	_fill_circle(img, 23.0, 3.0, 3.0, dark)

	# Dark eye patches
	_fill_ellipse(img, 12.0, 9.0, 3.0, 2.5, dark)
	_fill_ellipse(img, 20.0, 9.0, 3.0, 2.5, dark)

	# Eyes inside patches
	_set_px(img, 12, 9, eye_white); _set_px(img, 13, 9, eye_white)
	_set_px(img, 19, 9, eye_white); _set_px(img, 20, 9, eye_white)
	# Pupil
	_set_px(img, 12, 9, Color(0.1, 0.1, 0.1))
	_set_px(img, 20, 9, Color(0.1, 0.1, 0.1))
	# Eye sparkle
	_set_px(img, 13, 8, Color.WHITE)
	_set_px(img, 19, 8, Color.WHITE)

	# Nose
	_set_px(img, 16, 12, nose)

	# Mouth line
	_set_px(img, 15, 13, nose); _set_px(img, 17, 13, nose)

	# Dark feet
	_fill_circle(img, 12.0, 27.0, 3.0, dark)
	_fill_circle(img, 20.0, 27.0, 3.0, dark)

	# Bamboo leaf detail — holding a small bamboo leaf
	_set_px(img, 5, 14, leaf); _set_px(img, 4, 13, leaf)
	_set_px(img, 3, 12, leaf); _set_px(img, 4, 12, leaf)
	_set_px(img, 5, 15, leaf)

	return _tex(img)


func _make_white_stag() -> ImageTexture:
	var img := _img(32, 32)
	var body := Color(0.93, 0.93, 0.98)
	var light := Color(0.98, 0.98, 1.0)
	var antler := Color(0.82, 0.85, 0.95)
	var glow := Color(0.7, 0.8, 1.0, 0.4)
	var eye := Color(0.3, 0.4, 0.7)
	var hoof := Color(0.75, 0.78, 0.88)
	var leg := Color(0.88, 0.88, 0.94)

	# Body — elongated, standing sideways
	_fill_ellipse(img, 16.0, 18.0, 10.0, 6.0, body)
	# Lighter top
	_fill_ellipse(img, 16.0, 16.0, 7.0, 3.0, light)

	# Neck
	_fill_ellipse(img, 7.0, 13.0, 3.0, 5.0, body)

	# Head
	_fill_circle(img, 6.0, 8.0, 4.5, body)
	# Lighter face
	_fill_circle(img, 5.0, 9.0, 2.5, light)

	# Eye
	_set_px(img, 5, 7, eye); _set_px(img, 6, 7, eye)
	_set_px(img, 5, 6, Color.WHITE)

	# Nose
	_set_px(img, 3, 9, Color(0.75, 0.75, 0.85))

	# Antlers — branching upward
	# Left antler
	_draw_line_v(img, 5, 1, 4, antler)
	_set_px(img, 4, 1, antler); _set_px(img, 3, 0, antler)
	_set_px(img, 6, 2, antler)
	# Right antler
	_draw_line_v(img, 9, 1, 4, antler)
	_set_px(img, 10, 1, antler); _set_px(img, 11, 0, antler)
	_set_px(img, 8, 2, antler)

	# Legs
	_draw_line_v(img, 10, 23, 29, leg)
	_draw_line_v(img, 13, 23, 29, leg)
	_draw_line_v(img, 19, 23, 29, leg)
	_draw_line_v(img, 22, 23, 29, leg)
	# Hooves
	_set_px(img, 10, 30, hoof); _set_px(img, 13, 30, hoof)
	_set_px(img, 19, 30, hoof); _set_px(img, 22, 30, hoof)

	# Small tail
	_set_px(img, 26, 15, body); _set_px(img, 27, 14, light)

	# Blue-white glow aura
	for angle_i in range(16):
		var angle := float(angle_i) * TAU / 16.0
		var gx := int(16.0 + cos(angle) * 14.0)
		var gy := int(16.0 + sin(angle) * 14.0)
		_blend_px(img, gx, gy, glow)

	return _tex(img)


func _make_kirin() -> ImageTexture:
	var img := _img(32, 32)
	var c1: Color = GameData.CREATURES["kirin"].color  # golden
	var body := Color(0.95, 0.82, 0.35)
	var scales := Color(0.85, 0.7, 0.25)
	var mane := Color(1.0, 0.5, 0.2)  # flame orange
	var mane2 := Color(1.0, 0.7, 0.3)
	var eye := Color(0.6, 0.1, 0.1)
	var white := Color(1.0, 1.0, 0.95)
	var leg := Color(0.8, 0.68, 0.3)
	var glow := Color(1.0, 0.9, 0.5, 0.35)

	# Body — deer-like elongated
	_fill_ellipse(img, 17.0, 18.0, 10.0, 6.0, body)

	# Scales pattern on body — scattered darker dots
	_set_px(img, 11, 16, scales); _set_px(img, 13, 18, scales)
	_set_px(img, 15, 15, scales); _set_px(img, 17, 17, scales)
	_set_px(img, 19, 16, scales); _set_px(img, 21, 18, scales)
	_set_px(img, 23, 17, scales); _set_px(img, 14, 20, scales)
	_set_px(img, 18, 20, scales); _set_px(img, 22, 19, scales)
	_set_px(img, 10, 18, scales); _set_px(img, 20, 15, scales)

	# Neck
	_fill_ellipse(img, 8.0, 13.0, 3.5, 5.0, body)

	# Head
	_fill_circle(img, 7.0, 8.0, 4.5, body)
	# Face highlight
	_fill_circle(img, 6.0, 9.0, 2.0, white)

	# Eye
	_set_px(img, 6, 7, eye); _set_px(img, 7, 7, eye)
	_set_px(img, 6, 6, Color.WHITE)

	# Horn (single, spiraling upward)
	_draw_line_v(img, 7, 0, 4, c1)
	_set_px(img, 8, 1, c1); _set_px(img, 6, 2, c1)
	_set_px(img, 8, 3, c1)
	_set_px(img, 7, 0, white)  # tip glow

	# Flowing mane — flame-like pixels along neck and back
	_set_px(img, 5, 5, mane);  _set_px(img, 4, 4, mane);  _set_px(img, 3, 3, mane2)
	_set_px(img, 6, 6, mane);  _set_px(img, 5, 7, mane2)
	_set_px(img, 7, 10, mane); _set_px(img, 6, 11, mane2); _set_px(img, 5, 10, mane)
	_set_px(img, 8, 12, mane); _set_px(img, 9, 11, mane2)
	_set_px(img, 10, 13, mane); _set_px(img, 11, 12, mane2)
	_set_px(img, 12, 14, mane2)

	# Tail — flame-like
	_set_px(img, 27, 16, mane); _set_px(img, 28, 15, mane2)
	_set_px(img, 29, 14, mane); _set_px(img, 30, 13, mane2)
	_set_px(img, 28, 17, mane2); _set_px(img, 29, 16, mane)

	# Legs
	_draw_line_v(img, 11, 23, 28, leg)
	_draw_line_v(img, 14, 23, 28, leg)
	_draw_line_v(img, 20, 23, 28, leg)
	_draw_line_v(img, 23, 23, 28, leg)
	# Hooves — golden
	_set_px(img, 11, 29, c1); _set_px(img, 14, 29, c1)
	_set_px(img, 20, 29, c1); _set_px(img, 23, 29, c1)

	# Auspicious golden glow
	for angle_i in range(20):
		var angle := float(angle_i) * TAU / 20.0
		var gx := int(16.0 + cos(angle) * 15.0)
		var gy := int(16.0 + sin(angle) * 15.0)
		_blend_px(img, gx, gy, glow)

	return _tex(img)


# ═══════════════════════════════════════════════════════════════════════════════
# HEART TREE (32×48)
# ═══════════════════════════════════════════════════════════════════════════════

func _make_heart_tree() -> ImageTexture:
	var img := _img(32, 48)
	_draw_heart_tree_sprite(img, false)
	return _tex(img)


func _make_heart_tree_glow() -> ImageTexture:
	var img := _img(32, 48)
	_draw_heart_tree_sprite(img, true)
	return _tex(img)


func _draw_heart_tree_sprite(img: Image, restored: bool) -> void:
	var bark_dark := Color(0.17, 0.11, 0.08)
	var bark := Color(0.35, 0.23, 0.15)
	var bark_mid := Color(0.48, 0.33, 0.20)
	var bark_light := Color(0.63, 0.44, 0.25)
	var leaf_outline := Color(0.13, 0.24, 0.17)
	var leaf_shadow := Color(0.20, 0.38, 0.24)
	var leaf := Color(0.31, 0.56, 0.33)
	var leaf_mid := Color(0.41, 0.66, 0.38)
	var leaf_light := Color(0.59, 0.78, 0.47)
	var heart_light := Color(0.76, 0.65, 0.34)
	var sparkle := Color(0.72, 0.88, 0.56)

	if restored:
		bark_dark = Color(0.22, 0.14, 0.09)
		bark = Color(0.46, 0.31, 0.18)
		bark_mid = Color(0.62, 0.43, 0.24)
		bark_light = Color(0.82, 0.60, 0.34)
		leaf_outline = Color(0.20, 0.38, 0.22)
		leaf_shadow = Color(0.32, 0.58, 0.30)
		leaf = Color(0.48, 0.75, 0.39)
		leaf_mid = Color(0.63, 0.86, 0.48)
		leaf_light = Color(0.84, 0.96, 0.62)
		heart_light = Color(1.0, 0.90, 0.42)
		sparkle = Color(0.98, 1.0, 0.72)
		_draw_heart_tree_aura(img)

	var heart_spans := [
		[2, 8, 13], [2, 19, 24],
		[3, 6, 15], [3, 17, 26],
		[4, 5, 27],
		[5, 3, 29],
		[6, 2, 30],
		[7, 2, 30],
		[8, 1, 31],
		[9, 1, 31],
		[10, 1, 31],
		[11, 2, 30],
		[12, 2, 30],
		[13, 2, 30],
		[14, 3, 29],
		[15, 3, 29],
		[16, 4, 28],
		[17, 5, 27],
		[18, 5, 27],
		[19, 6, 26],
		[20, 7, 25],
		[21, 8, 24],
		[22, 9, 23],
		[23, 10, 22],
		[24, 11, 21],
		[25, 12, 20],
		[26, 13, 19],
		[27, 14, 18],
		[28, 15, 17],
	]

	var trunk_spans := [
		[26, 15, 17],
		[27, 14, 18],
		[28, 13, 19],
		[29, 13, 19],
		[30, 13, 18],
		[31, 12, 18],
		[32, 12, 18],
		[33, 12, 18],
		[34, 12, 19],
		[35, 12, 19],
		[36, 12, 19],
		[37, 12, 20],
		[38, 12, 20],
		[39, 12, 20],
		[40, 11, 20],
		[41, 11, 20],
		[42, 11, 21],
		[43, 10, 21],
		[44, 10, 22],
		[45, 9, 23],
		[46, 8, 24],
		[47, 7, 25],
	]

	_draw_heart_tree_wood(img, trunk_spans, bark_dark, bark, bark_mid, bark_light)
	_fill_spans(img, heart_spans, leaf_outline, 1, -1)
	_fill_spans(img, heart_spans, leaf_outline, 1, 1)
	_fill_spans(img, heart_spans, leaf_outline, 1)
	_fill_spans(img, heart_spans, leaf)
	_draw_heart_tree_leaf_texture(img, leaf_shadow, leaf_mid, leaf_light, heart_light, sparkle, restored)


func _draw_heart_tree_wood(
	img: Image,
	trunk_spans: Array,
	bark_dark: Color,
	bark: Color,
	bark_mid: Color,
	bark_light: Color
) -> void:
	_draw_pixel_line(img, Vector2i(15, 27), Vector2i(8, 22), bark_dark, 2)
	_draw_pixel_line(img, Vector2i(17, 27), Vector2i(24, 22), bark_dark, 2)
	_draw_pixel_line(img, Vector2i(15, 27), Vector2i(10, 24), bark_mid, 1)
	_draw_pixel_line(img, Vector2i(17, 27), Vector2i(22, 24), bark_mid, 1)

	_fill_spans(img, trunk_spans, bark_dark, 1)
	_fill_spans(img, trunk_spans, bark)

	_draw_pixel_line(img, Vector2i(10, 45), Vector2i(3, 47), bark_dark, 2)
	_draw_pixel_line(img, Vector2i(22, 45), Vector2i(29, 47), bark_dark, 2)
	_draw_pixel_line(img, Vector2i(14, 45), Vector2i(9, 47), bark_mid, 1)
	_draw_pixel_line(img, Vector2i(18, 45), Vector2i(24, 47), bark_mid, 1)

	_draw_pixel_line(img, Vector2i(16, 27), Vector2i(14, 35), bark_mid, 1)
	_draw_pixel_line(img, Vector2i(14, 35), Vector2i(17, 43), bark_light, 1)
	_draw_pixel_line(img, Vector2i(18, 30), Vector2i(16, 37), bark_dark, 1)
	_draw_pixel_line(img, Vector2i(13, 39), Vector2i(15, 46), bark_dark, 1)
	_set_px(img, 17, 33, bark_light)
	_set_px(img, 13, 31, bark_light)
	_set_px(img, 19, 41, bark_mid)


func _draw_heart_tree_leaf_texture(
	img: Image,
	leaf_shadow: Color,
	leaf_mid: Color,
	leaf_light: Color,
	heart_light: Color,
	sparkle: Color,
	restored: bool
) -> void:
	_draw_line_h(img, 5, 4, 11, leaf_mid)
	_draw_line_h(img, 5, 21, 28, leaf_mid)
	_draw_line_h(img, 6, 5, 14, leaf_mid)
	_draw_line_h(img, 6, 18, 27, leaf_mid)
	_draw_line_h(img, 9, 3, 10, leaf_shadow)
	_draw_line_h(img, 10, 23, 29, leaf_shadow)
	_draw_line_h(img, 15, 4, 9, leaf_shadow)
	_draw_line_h(img, 16, 22, 27, leaf_shadow)
	_draw_line_h(img, 22, 10, 14, leaf_shadow)
	_draw_line_h(img, 23, 18, 22, leaf_shadow)

	_fill_circle(img, 8.0, 9.0, 3.0, leaf_light)
	_fill_circle(img, 24.0, 9.0, 3.0, leaf_light)
	_fill_circle(img, 16.0, 13.0, 2.5, leaf_mid)
	_fill_circle(img, 12.0, 18.0, 2.0, leaf_mid)
	_fill_circle(img, 20.0, 18.0, 2.0, leaf_mid)

	_draw_pixel_line(img, Vector2i(16, 25), Vector2i(16, 15), heart_light, 1)
	_draw_pixel_line(img, Vector2i(16, 17), Vector2i(10, 11), heart_light, 1)
	_draw_pixel_line(img, Vector2i(16, 17), Vector2i(22, 11), heart_light, 1)
	_set_px(img, 15, 26, heart_light)
	_set_px(img, 17, 26, heart_light)

	_set_px(img, 6, 13, sparkle)
	_set_px(img, 11, 7, sparkle)
	_set_px(img, 21, 7, sparkle)
	_set_px(img, 26, 13, sparkle)
	_set_px(img, 9, 21, sparkle)
	_set_px(img, 23, 21, sparkle)
	_set_px(img, 16, 4, sparkle)

	if restored:
		_set_px(img, 4, 7, sparkle)
		_set_px(img, 28, 7, sparkle)
		_set_px(img, 2, 16, sparkle)
		_set_px(img, 30, 16, sparkle)
		_set_px(img, 16, 29, heart_light)


func _draw_heart_tree_aura(img: Image) -> void:
	var warm := Color(1.0, 0.90, 0.42, 0.36)
	var green := Color(0.68, 1.0, 0.58, 0.18)
	for angle_i in range(36):
		var angle := float(angle_i) * TAU / 36.0
		_blend_px(img, int(16.0 + cos(angle) * 15.0), int(14.0 + sin(angle) * 13.0), warm)
		_blend_px(img, int(16.0 + cos(angle) * 17.0), int(14.0 + sin(angle) * 15.0), green)

	for p in [Vector2i(3, 6), Vector2i(29, 6), Vector2i(1, 13), Vector2i(31, 13), Vector2i(7, 28), Vector2i(25, 28)]:
		_blend_px(img, p.x, p.y, Color(1.0, 0.96, 0.65, 0.5))


# UI ELEMENTS & ICONS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_dewdrop() -> ImageTexture:
	var img := _img(12, 12)
	var blue := Color(0.4, 0.7, 0.95)
	var light := Color(0.6, 0.85, 1.0)
	var dark := Color(0.3, 0.55, 0.8)

	# Pointed top
	_set_px(img, 6, 1, blue)
	_set_px(img, 5, 2, blue); _set_px(img, 6, 2, blue); _set_px(img, 7, 2, blue)
	_set_px(img, 5, 3, blue); _set_px(img, 6, 3, light); _set_px(img, 7, 3, blue)

	# Widening body
	_set_px(img, 4, 4, blue); _set_px(img, 5, 4, light); _set_px(img, 6, 4, light); _set_px(img, 7, 4, blue); _set_px(img, 8, 4, blue)

	# Round bottom
	_fill_circle(img, 6.0, 7.0, 3.5, blue)
	# Inner highlight
	_set_px(img, 5, 6, light); _set_px(img, 5, 5, light)
	_set_px(img, 4, 7, light)

	# White sparkle highlight
	_set_px(img, 4, 5, Color.WHITE)

	# Bottom shadow
	_set_px(img, 6, 10, dark); _set_px(img, 7, 10, dark)

	return _tex(img)


func _make_luma() -> ImageTexture:
	var img := _img(16, 16)
	var body := Color(0.85, 0.9, 1.0)
	var core := Color(1.0, 1.0, 1.0)
	var glow := Color(0.7, 0.8, 1.0, 0.4)
	var eye := Color(0.2, 0.3, 0.5)
	var tail := Color(0.6, 0.75, 1.0, 0.5)

	# Body — small round wisp
	_fill_circle(img, 8.0, 7.0, 4.5, body)
	# Bright core
	_fill_circle(img, 7.5, 6.5, 2.5, core)

	# Tiny dot eyes
	_set_px(img, 6, 7, eye)
	_set_px(img, 9, 7, eye)

	# Mouth — tiny happy curve
	_set_px(img, 7, 9, Color(0.5, 0.6, 0.8))
	_set_px(img, 8, 9, Color(0.5, 0.6, 0.8))

	# Trailing light tail
	_blend_px(img, 8, 11, tail)
	_blend_px(img, 7, 12, tail)
	_blend_px(img, 9, 12, Color(tail.r, tail.g, tail.b, 0.3))
	_blend_px(img, 7, 13, Color(tail.r, tail.g, tail.b, 0.2))
	_blend_px(img, 8, 14, Color(tail.r, tail.g, tail.b, 0.1))

	# Glow aura
	for angle_i in range(8):
		var angle := float(angle_i) * TAU / 8.0
		var gx := int(8.0 + cos(angle) * 6.0)
		var gy := int(7.0 + sin(angle) * 6.0)
		_blend_px(img, gx, gy, glow)

	return _tex(img)


func _make_icon_skill() -> ImageTexture:
	var img := _img(12, 12)
	var trunk := Color(0.45, 0.32, 0.2)
	var leaf := Color(0.4, 0.7, 0.35)
	var leaf2 := Color(0.55, 0.85, 0.45)

	# Trunk
	_draw_line_v(img, 6, 5, 11, trunk)
	_set_px(img, 5, 10, trunk); _set_px(img, 7, 10, trunk)  # roots

	# Branches
	_set_px(img, 5, 5, trunk); _set_px(img, 4, 4, trunk)
	_set_px(img, 7, 5, trunk); _set_px(img, 8, 4, trunk)

	# Leaves (green dots)
	_set_px(img, 3, 3, leaf);  _set_px(img, 4, 2, leaf2); _set_px(img, 5, 3, leaf)
	_set_px(img, 9, 3, leaf);  _set_px(img, 8, 2, leaf2); _set_px(img, 7, 3, leaf)
	_set_px(img, 5, 1, leaf2); _set_px(img, 6, 0, leaf);  _set_px(img, 7, 1, leaf2)
	_set_px(img, 6, 2, leaf)

	return _tex(img)


func _make_icon_bestiary() -> ImageTexture:
	var img := _img(12, 12)
	var cover := Color(0.5, 0.35, 0.22)
	var page := Color(0.9, 0.88, 0.8)
	var detail := Color(0.35, 0.25, 0.16)

	# Book cover — rectangle
	_fill_rect(img, 2, 2, 10, 10, cover)
	# Spine
	_draw_line_v(img, 2, 2, 10, detail)
	# Pages inside
	_fill_rect(img, 3, 3, 9, 9, page)
	# Text lines
	_draw_line_h(img, 4, 4, 8, Color(0.6, 0.55, 0.5))
	_draw_line_h(img, 6, 4, 8, Color(0.6, 0.55, 0.5))
	_draw_line_h(img, 8, 4, 7, Color(0.6, 0.55, 0.5))

	# Paw print accent on cover top
	_set_px(img, 5, 1, cover); _set_px(img, 7, 1, cover)
	_set_px(img, 6, 0, cover)

	return _tex(img)


func _make_icon_settings() -> ImageTexture:
	var img := _img(12, 12)
	var gear := Color(0.6, 0.6, 0.65)
	var center := Color(0.4, 0.4, 0.45)

	# Gear body — center circle
	_fill_circle(img, 6.0, 6.0, 3.0, gear)
	_fill_circle(img, 6.0, 6.0, 1.5, center)

	# Gear teeth — cardinal + diagonal
	_set_px(img, 6, 1, gear); _set_px(img, 6, 2, gear)  # top
	_set_px(img, 6, 10, gear); _set_px(img, 6, 9, gear)  # bottom
	_set_px(img, 1, 6, gear); _set_px(img, 2, 6, gear)  # left
	_set_px(img, 10, 6, gear); _set_px(img, 9, 6, gear)  # right
	_set_px(img, 3, 3, gear); _set_px(img, 9, 3, gear)   # diagonals
	_set_px(img, 3, 9, gear); _set_px(img, 9, 9, gear)

	return _tex(img)


func _make_particle() -> ImageTexture:
	var img := _img(4, 4)
	var center := Color(1.0, 1.0, 0.9, 1.0)
	var edge := Color(1.0, 1.0, 0.8, 0.5)
	var corner := Color(1.0, 1.0, 0.7, 0.15)

	# Center bright
	_set_px(img, 1, 1, center); _set_px(img, 2, 1, center)
	_set_px(img, 1, 2, center); _set_px(img, 2, 2, center)

	# Edge fade
	_set_px(img, 0, 1, edge); _set_px(img, 3, 1, edge)
	_set_px(img, 0, 2, edge); _set_px(img, 3, 2, edge)
	_set_px(img, 1, 0, edge); _set_px(img, 2, 0, edge)
	_set_px(img, 1, 3, edge); _set_px(img, 2, 3, edge)

	# Corner subtle
	_set_px(img, 0, 0, corner); _set_px(img, 3, 0, corner)
	_set_px(img, 0, 3, corner); _set_px(img, 3, 3, corner)

	return _tex(img)


func _make_placeholder() -> ImageTexture:
	var img := _img(16, 16)
	var pink := Color(1.0, 0.0, 1.0)
	var black := Color(0.0, 0.0, 0.0)
	# Checkerboard pattern — classic "missing texture"
	for y in range(16):
		for x in range(16):
			if (x + y) % 2 == 0:
				img.set_pixel(x, y, pink)
			else:
				img.set_pixel(x, y, black)
	return _tex(img)
