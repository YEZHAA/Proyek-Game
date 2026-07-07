extends Node2D

const GRID_ORIGIN := Vector2(640.0, 205.0)
const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0

var tiles: Dictionary = {}

func _ready():
	position = GRID_ORIGIN
	y_sort_enabled = true
	for row in range(GameData.GRID_SIZE):
		for col in range(GameData.GRID_SIZE):
			var pos = Vector2i(col, row)
			var tile_script = load("res://src/grid/tile.gd")
			if tile_script:
				var tile = tile_script.new()
				var iso_x = (col - row) * TILE_HALF_WIDTH
				var iso_y = (col + row) * TILE_HALF_HEIGHT
				tile.position = Vector2(iso_x, iso_y)
				add_child(tile)
				tile.setup(pos)
				tiles[pos] = tile

func get_tile(pos: Vector2i) -> Node2D:
	return tiles.get(pos)

func grid_to_screen(pos: Vector2i) -> Vector2:
	var iso_x = (pos.x - pos.y) * TILE_HALF_WIDTH
	var iso_y = (pos.x + pos.y) * TILE_HALF_HEIGHT
	return position + Vector2(iso_x, iso_y)
