extends Node
## GameData — SINGLE SOURCE OF TRUTH for all game constants.
## Nothing here is mutable at runtime. All balance numbers live in this file.

# ─── Grid & Display ──────────────────────────────────────────────────────────
const GRID_SIZE := 16
const TILE_SIZE := 64
const GRID_OFFSET := Vector2(96, 180)  # centers 384px grid in 576px viewport (now obsolete with new math)
const VIEWPORT_SIZE := Vector2(1280, 720)
const STARTER_TILE := Vector2i(8, 8)

# ─── Colors ──────────────────────────────────────────────────────────────────
const BG_COLOR := Color(0.10, 0.09, 0.14)
const BARREN_COLOR := Color(0.22, 0.18, 0.15)
const CLEAR_COLOR := Color(0.18, 0.32, 0.20)

# ─── Flora (tier → data) ────────────────────────────────────────────────────
## Each tier strictly outclasses the previous. Production is dewdrops/second.
## Polynomial economy: costs scale ~×3–5 per tier, never exponential.
const FLORA: Dictionary = {
	1: {
		"name": "Mossling",
		"production": 0.15,
		"cost": 5,
		"color": Color(0.3, 0.65, 0.35),
		"color2": Color(0.45, 0.8, 0.5),
		"desc": "Small green moss with tiny sprouts",
	},
	2: {
		"name": "Glowcap",
		"production": 0.6,
		"cost": 30,
		"color": Color(0.4, 0.45, 0.85),
		"color2": Color(0.6, 0.65, 0.95),
		"desc": "Luminous mushroom with soft glow",
	},
	3: {
		"name": "Bamboo",
		"production": 2.0,
		"cost": 150,
		"color": Color(0.25, 0.75, 0.3),
		"color2": Color(0.4, 0.9, 0.45),
		"desc": "Cluster of green bamboo stalks",
	},
	4: {
		"name": "Willowweep",
		"production": 7.0,
		"cost": 600,
		"color": Color(0.35, 0.75, 0.6),
		"color2": Color(0.5, 0.9, 0.75),
		"desc": "Weeping willow with drooping branches",
	},
	5: {
		"name": "Heartbloom",
		"production": 22.0,
		"cost": 2500,
		"color": Color(0.9, 0.45, 0.6),
		"color2": Color(1.0, 0.7, 0.8),
		"desc": "Heart-shaped flower of restoration",
	},
}

# ─── Mythical Creatures ─────────────────────────────────────────────────────
## Fixed arrival order. Each creature gates Skill Tree branches.
const CREATURES: Dictionary = {
	"owl_spirit": {
		"name": "Owl-Spirit",
		"trigger": "dewdrops",
		"threshold": 25,
		"color": Color(0.6, 0.6, 0.8),
		"desc": "The ancient watcher. Perched in silence over the dead forest, it was never gone, only waiting.",
	},
	"jade_rabbit": {
		"name": "Jade Rabbit",
		"trigger": "plant_tier",
		"threshold": 1,
		"color": Color(0.4, 0.8, 0.5),
		"desc": "Small, low to the ground, dwells among the moss. Quiet and kind.",
	},
	"fawn": {
		"name": "Fawn",
		"trigger": "plant_tier",
		"threshold": 2,
		"color": Color(0.8, 0.7, 0.5),
		"desc": "Gentle, delicate, drawn to the luminous mushroom-caps' soft light.",
	},
	"mythical_panda": {
		"name": "Mythical Panda",
		"trigger": "plant_tier",
		"threshold": 3,
		"color": Color(0.9, 0.9, 0.9),
		"desc": "The bamboo's guardian — round, slow, serene.",
	},
	"white_stag": {
		"name": "White Stag",
		"trigger": "plant_tier",
		"threshold": 4,
		"color": Color(0.95, 0.95, 1.0),
		"desc": "Majestic but calm; appears among the tall weeping-willow canopy.",
	},
	"kirin": {
		"name": "Kirin",
		"trigger": "plant_tier",
		"threshold": 5,
		"color": Color(1.0, 0.85, 0.4),
		"desc": "The most auspicious creature. Its arrival completes the restoration.",
	},
}

## The fixed sequence of creature arrivals (story arc).
const CREATURE_ORDER: Array[String] = [
	"owl_spirit",
	"jade_rabbit",
	"fawn",
	"mythical_panda",
	"white_stag",
	"kirin",
]

# ─── Skill Tree ──────────────────────────────────────────────────────────────
## Per-tier branch costs (4 nodes per tier, all same cost within a tier).
const SKILL_COSTS: Dictionary = {
	1: 40,
	2: 200,
	3: 800,
	4: 3000,
	5: 12000,
}
const SKILL_MULT := 0.25  ## Production multiplier gained per node

## Global (non-tier) skill definitions.
const GLOBAL_SKILLS: Dictionary = {
	"tap_harvest": {
		"name": "Tap Harvest+",
		"max_level": 3,
		"cost": 150,
		"desc": "+50% tap harvest per level",
	},
	"tap_speed": {
		"name": "Tap Speed+",
		"max_level": 2,
		"cost": 200,
		"desc": "-3 taps needed per level",
	},
	"clear_discount": {
		"name": "Clear Discount",
		"max_level": 2,
		"cost": 200,
		"desc": "-15% clear cost per level",
	},
	"offline_cap": {
		"name": "Offline Cap+",
		"max_level": 2,
		"cost": 300,
		"desc": "+30 min offline cap per level",
	},
}

# ─── Economy Tuning ──────────────────────────────────────────────────────────
const CLEAR_COST_BASE := 3.0
const CLEAR_COST_INC := 2.0
const TAP_BAR_MAX := 15
const TAP_HARVEST_MULT := 10.0
const OFFLINE_BASE_MINUTES := 30.0
