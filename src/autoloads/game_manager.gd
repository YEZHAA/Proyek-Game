extends Node
## GameManager — central game state manager.
## ALL game state lives here. ALL mutations go through here.
## Other systems read state and call mutation funcs; they never write directly.

# ─── Signals ─────────────────────────────────────────────────────────────────
signal dewdrops_changed(amount: float)
signal tile_changed(pos: Vector2i, state: String)
signal flora_planted(pos: Vector2i, tier: int)
signal flora_tapped(pos: Vector2i)
signal tap_bar_harvested(pos: Vector2i, amount: float)
signal creature_arrived(creature_id: String)
signal creature_arrival_finished(creature_id: String)
signal skill_purchased(skill_id: String)
signal tier_unlocked(tier: int)
signal game_over()
signal show_tile_menu(pos: Vector2i, screen_pos: Vector2)
signal hide_tile_menu()
signal seed_menu_focus_changed(is_focused: bool)
signal show_overlay(overlay_name: String)
signal hide_overlay()
signal tutorial_advance(step: String)
signal heart_tree_updated(luminance: float)

# ─── State ───────────────────────────────────────────────────────────────────
var dewdrops: float = 10.0
var total_earned: float = 10.0
var tile_states: Dictionary = {}     ## Vector2i → String ("barren"/"clear"/"planted")
var flora_map: Dictionary = {}       ## Vector2i → {tier: int, taps: int}
var skill_levels: Dictionary = {}    ## String → int  e.g. "tier_1" → 0..4, "tap_harvest" → 0..3
var arrived_creatures: Array[String] = []
var unlocked_tiers: Array[int] = [1]
var cleared_count: int = 0
var is_ended: bool = false
var tutorial_done: bool = false
var game_input_locked: bool = false
var seed_menu_focused: bool = false
var game_time: float = 0.0
var last_save_time: float = 0.0

const SAVE_PATH := "user://re_leaf_save.json"
const AUTO_SAVE_INTERVAL := 30.0


# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	# Initialize the grid — all tiles start barren
	for col in range(GameData.GRID_SIZE):
		for row in range(GameData.GRID_SIZE):
			tile_states[Vector2i(col, row)] = "barren"

	# The Starter Tile is cleared for free (Luma's tears)
	tile_states[GameData.STARTER_TILE] = "clear"
	cleared_count = 1

	# Initialize skill levels
	for tier_idx in range(1, 6):
		skill_levels["tier_%d" % tier_idx] = 0
	for skill_id in GameData.GLOBAL_SKILLS:
		skill_levels[skill_id] = 0

	# Attempt to load saved game
	_load_game()

	# Emit initial heart tree state
	_update_heart_tree()


func _process(delta: float) -> void:
	if is_ended:
		return

	game_time += delta

	# Passive income — the spine of the idle game
	var income := Economy.get_total_income(flora_map, skill_levels)
	if income > 0.0:
		earn_dewdrops(income * delta)

	# Auto-save
	last_save_time += delta
	if last_save_time >= AUTO_SAVE_INTERVAL:
		last_save_time = 0.0
		_save_game()


# ─── Currency ────────────────────────────────────────────────────────────────

func earn_dewdrops(amount: float) -> void:
	dewdrops += amount
	total_earned += amount
	dewdrops_changed.emit(dewdrops)
	_check_creature_triggers()


func can_afford(cost: float) -> bool:
	return dewdrops >= cost


func spend(amount: float) -> bool:
	if not can_afford(amount):
		return false
	dewdrops -= amount
	dewdrops_changed.emit(dewdrops)
	return true


func can_clear(pos: Vector2i) -> bool:
	if tile_states.get(pos) != "barren":
		return false
	if flora_map.is_empty():
		return false
	return can_afford(Economy.get_clear_cost(cleared_count))


# ─── Tile Actions ────────────────────────────────────────────────────────────

func try_clear(pos: Vector2i) -> bool:
	if game_input_locked:
		return false
	if not can_clear(pos):
		return false
	var cost := Economy.get_clear_cost(cleared_count)
	if not spend(cost):
		return false
	tile_states[pos] = "clear"
	cleared_count += 1
	tile_changed.emit(pos, "clear")
	_update_heart_tree()
	_check_game_end()
	return true


func try_plant(pos: Vector2i, tier: int) -> bool:
	if game_input_locked:
		return false
	if tile_states.get(pos) != "clear":
		return false
	if tier not in unlocked_tiers:
		return false
	var cost: float = GameData.FLORA[tier].cost
	if not spend(cost):
		return false
	tile_states[pos] = "planted"
	flora_map[pos] = {"tier": tier, "taps": 0}
	tile_changed.emit(pos, "planted")
	flora_planted.emit(pos, tier)
	_check_creature_triggers()
	return true


# ─── Tapping ─────────────────────────────────────────────────────────────────

func do_tap(pos: Vector2i) -> void:
	if game_input_locked:
		return
	if pos not in flora_map:
		return
	flora_map[pos].taps += 1
	flora_tapped.emit(pos)
	var max_taps := Economy.get_taps_needed(skill_levels.get("tap_speed", 0))
	if flora_map[pos].taps >= max_taps:
		var tier: int = flora_map[pos].tier
		var harvest := Economy.get_tap_harvest(tier, skill_levels.get("tap_harvest", 0))
		earn_dewdrops(harvest)
		flora_map[pos].taps = 0
		tap_bar_harvested.emit(pos, harvest)


func notify_creature_arrival_finished(creature_id: String) -> void:
	creature_arrival_finished.emit(creature_id)


func set_game_input_locked(is_locked: bool) -> void:
	game_input_locked = is_locked


func set_seed_menu_focused(is_focused: bool) -> void:
	if seed_menu_focused == is_focused:
		return
	seed_menu_focused = is_focused
	seed_menu_focus_changed.emit(seed_menu_focused)


# ─── Skill Tree ──────────────────────────────────────────────────────────────

func try_buy_skill(skill_id: String) -> bool:
	var cost: float
	var max_level: int

	if skill_id.begins_with("tier_"):
		var tier := int(skill_id.split("_")[1])
		if tier not in GameData.SKILL_COSTS:
			return false
		cost = float(GameData.SKILL_COSTS[tier])
		max_level = 4
	elif skill_id in GameData.GLOBAL_SKILLS:
		cost = float(GameData.GLOBAL_SKILLS[skill_id].cost)
		max_level = GameData.GLOBAL_SKILLS[skill_id].max_level
	else:
		return false

	var current: int = skill_levels.get(skill_id, 0)
	if current >= max_level:
		return false
	if not spend(cost):
		return false

	skill_levels[skill_id] = current + 1
	skill_purchased.emit(skill_id)

	# Seed Unlock: completing all 4 nodes of a tier branch unlocks the next tier
	if skill_id.begins_with("tier_"):
		var tier := int(skill_id.split("_")[1])
		if skill_levels[skill_id] >= 4 and tier < 5:
			var next_tier := tier + 1
			if next_tier not in unlocked_tiers:
				unlocked_tiers.append(next_tier)
				tier_unlocked.emit(next_tier)

	return true


# ─── Queries ─────────────────────────────────────────────────────────────────

func get_income() -> float:
	return Economy.get_total_income(flora_map, skill_levels)


func _has_tier_planted(tier: int) -> bool:
	for pos in flora_map:
		if flora_map[pos].tier == tier:
			return true
	return false


# ─── Creature Triggers ──────────────────────────────────────────────────────

func _check_creature_triggers() -> void:
	for creature_id in GameData.CREATURE_ORDER:
		if creature_id in arrived_creatures:
			continue
		var data: Dictionary = GameData.CREATURES[creature_id]
		var triggered := false

		if data.trigger == "dewdrops":
			triggered = total_earned >= float(data.threshold)
		elif data.trigger == "plant_tier":
			triggered = _has_tier_planted(int(data.threshold))

		if triggered:
			arrived_creatures.append(creature_id)
			creature_arrived.emit(creature_id)
			if creature_id == "kirin":
				_check_game_end()
			break  # one creature arrival at a time


# ─── Heart Tree & Ending ────────────────────────────────────────────────────

func _update_heart_tree() -> void:
	var total_tiles: int = GameData.GRID_SIZE * GameData.GRID_SIZE
	var luminance := float(cleared_count) / float(total_tiles)
	heart_tree_updated.emit(luminance)


func _check_game_end() -> void:
	if "kirin" not in arrived_creatures:
		return
	for pos in tile_states:
		if tile_states[pos] == "barren":
			return
	_trigger_ending()


func _trigger_ending() -> void:
	if is_ended:
		return
	is_ended = true
	game_over.emit()


# ─── Save / Load ────────────────────────────────────────────────────────────

func _save_game() -> void:
	var save_data := {
		"dewdrops": dewdrops,
		"total_earned": total_earned,
		"tile_states": _dict_vec2i_to_str(tile_states),
		"flora_map": _flora_map_to_save(),
		"skill_levels": skill_levels.duplicate(),
		"arrived_creatures": arrived_creatures.duplicate(),
		"unlocked_tiers": unlocked_tiers.duplicate(),
		"cleared_count": cleared_count,
		"tutorial_done": tutorial_done,
		"game_time": game_time,
		"save_timestamp": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		push_warning("Re-Leaf: Failed to parse save file.")
		return

	var data: Dictionary = json.data
	dewdrops = float(data.get("dewdrops", 0.0))
	total_earned = float(data.get("total_earned", 0.0))
	cleared_count = int(data.get("cleared_count", 1))
	tutorial_done = bool(data.get("tutorial_done", false))
	game_time = float(data.get("game_time", 0.0))

	# Fix for players stuck with 0 dewdrops at the start of the game
	if total_earned == 0.0 and dewdrops == 0.0:
		dewdrops = 10.0
		total_earned = 10.0

	# Restore tile states
	var saved_tiles: Dictionary = data.get("tile_states", {})
	for key in saved_tiles:
		var pos := _str_to_vec2i(key)
		tile_states[pos] = saved_tiles[key]

	# Restore flora map
	var saved_flora: Dictionary = data.get("flora_map", {})
	for key in saved_flora:
		var pos := _str_to_vec2i(key)
		var entry: Dictionary = saved_flora[key]
		flora_map[pos] = {"tier": int(entry.tier), "taps": int(entry.taps)}

	# Restore skill levels
	var saved_skills: Dictionary = data.get("skill_levels", {})
	for skill_id in saved_skills:
		skill_levels[skill_id] = int(saved_skills[skill_id])

	# Restore creatures
	var saved_creatures: Array = data.get("arrived_creatures", [])
	arrived_creatures.clear()
	for c in saved_creatures:
		arrived_creatures.append(str(c))

	# Restore unlocked tiers
	var saved_tiers: Array = data.get("unlocked_tiers", [1])
	unlocked_tiers.clear()
	for t in saved_tiers:
		unlocked_tiers.append(int(t))

	# Offline progress calculation
	var save_timestamp: float = float(data.get("save_timestamp", 0.0))
	if save_timestamp > 0.0:
		var now := Time.get_unix_time_from_system()
		var time_away := maxf(0.0, now - save_timestamp)
		var offline_level: int = skill_levels.get("offline_cap", 0)
		var cap_seconds := Economy.get_offline_cap_minutes(offline_level) * 60.0
		var clamped_time := minf(time_away, cap_seconds)
		var income := Economy.get_total_income(flora_map, skill_levels)
		if income > 0.0 and clamped_time > 0.0:
			var offline_earned := income * clamped_time
			earn_dewdrops(offline_earned)
			print("Re-Leaf: Offline progress — %.1f dew earned over %.0f seconds." % [offline_earned, clamped_time])

	_update_heart_tree()
	dewdrops_changed.emit(dewdrops)


# ─── Serialization Helpers ───────────────────────────────────────────────────

func _dict_vec2i_to_str(d: Dictionary) -> Dictionary:
	var out := {}
	for key in d:
		out["%d,%d" % [key.x, key.y]] = d[key]
	return out


func _flora_map_to_save() -> Dictionary:
	var out := {}
	for key in flora_map:
		var entry: Dictionary = flora_map[key]
		out["%d,%d" % [key.x, key.y]] = {"tier": entry.tier, "taps": entry.taps}
	return out


func _str_to_vec2i(s: String) -> Vector2i:
	var parts := s.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


# ─── Notification (save on quit) ────────────────────────────────────────────

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
