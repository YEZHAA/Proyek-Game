extends CanvasLayer

func _ready():
	var bg = ColorRect.new()
	bg.color = GameData.BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var title = Label.new()
	title.text = "Re-Leaf:\nIdle Fantasy"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 150)
	title.size = Vector2(GameData.VIEWPORT_SIZE.x, 200)
	add_child(title)
	
	var btn_play = Button.new()
	btn_play.text = "PLAY"
	btn_play.add_theme_font_size_override("font_size", 24)
	btn_play.position = Vector2(GameData.VIEWPORT_SIZE.x / 2 - 100, 350)
	btn_play.size = Vector2(200, 60)
	btn_play.pressed.connect(func(): get_tree().change_scene_to_file("res://src/main.tscn"))
	add_child(btn_play)
	
	var btn_reset = Button.new()
	btn_reset.text = "RESET SAVE & PLAY"
	btn_reset.add_theme_font_size_override("font_size", 18)
	btn_reset.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	btn_reset.position = Vector2(GameData.VIEWPORT_SIZE.x / 2 - 100, 430)
	btn_reset.size = Vector2(200, 50)
	btn_reset.pressed.connect(_on_reset_pressed)
	add_child(btn_reset)
	
	var btn_quit = Button.new()
	btn_quit.text = "QUIT"
	btn_quit.add_theme_font_size_override("font_size", 18)
	btn_quit.position = Vector2(GameData.VIEWPORT_SIZE.x / 2 - 100, 500)
	btn_quit.size = Vector2(200, 50)
	btn_quit.pressed.connect(func(): get_tree().quit())
	add_child(btn_quit)

func _on_reset_pressed():
	if FileAccess.file_exists(GameManager.SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("re_leaf_save.json")
	
	# Reset GameManager state
	GameManager.dewdrops = 10.0
	GameManager.total_earned = 10.0
	GameManager.cleared_count = 1
	GameManager.tutorial_done = false
	GameManager.game_time = 0.0
	GameManager.arrived_creatures.clear()
	GameManager.unlocked_tiers = [1]
	GameManager.flora_map.clear()
	
	for col in range(GameData.GRID_SIZE):
		for row in range(GameData.GRID_SIZE):
			GameManager.tile_states[Vector2i(col, row)] = "barren"
	GameManager.tile_states[GameData.STARTER_TILE] = "clear"
	
	for tier_idx in range(1, 6):
		GameManager.skill_levels["tier_%d" % tier_idx] = 0
	for skill_id in GameData.GLOBAL_SKILLS:
		GameManager.skill_levels[skill_id] = 0
		
	get_tree().change_scene_to_file("res://src/main.tscn")
