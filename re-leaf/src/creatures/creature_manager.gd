extends Node

var creature_nodes: Dictionary = {}

func _ready():
	GameManager.creature_arrived.connect(_on_creature_arrived)
	for cid in GameManager.arrived_creatures:
		creature_nodes[cid] = {"arrived": true}

func _on_creature_arrived(creature_id: String):
	creature_nodes[creature_id] = {"arrived": true, "time": GameManager.game_time}

func get_arrived_creatures() -> Array:
	return GameManager.arrived_creatures

func is_creature_arrived(creature_id: String) -> bool:
	return creature_id in GameManager.arrived_creatures

func get_creature_data(creature_id: String) -> Dictionary:
	return GameData.CREATURES.get(creature_id, {})

func get_next_creature() -> String:
	for cid in GameData.CREATURE_ORDER:
		if cid not in GameManager.arrived_creatures:
			return cid
	return ""
