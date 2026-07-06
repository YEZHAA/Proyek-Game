extends Node
## Economy — pure calculation functions for the polynomial Dewdrop economy.
## No state lives here. All inputs come from GameData (constants) or
## GameManager (runtime state). All outputs are floats/ints.
##
## ADR-0001: polynomial curve, NOT exponential. Do not "fix" this.


## Returns the Dewdrop cost to Clear the next Barren tile.
## Polynomial: base + linear + quadratic pressure, then discount.
func get_clear_cost(cleared_count: int) -> float:
	var cleared := float(cleared_count)
	var base := GameData.CLEAR_COST_BASE + GameData.CLEAR_COST_INC * cleared + GameData.CLEAR_COST_QUAD * cleared * cleared
	var discount_level: int = 0
	if GameManager:
		discount_level = GameManager.skill_levels.get("clear_discount", 0)
	return base * (1.0 - 0.15 * float(discount_level))


## Returns the per-second Dewdrop production of a single Flora at [tier],
## accounting for the tier's Skill Tree production multiplier level.
func get_flora_production(tier: int, tier_skill_level: int) -> float:
	var base: float = GameData.FLORA[tier].production
	return base * (1.0 + GameData.SKILL_MULT * float(tier_skill_level))


## Returns the bonus Dewdrop chunk from harvesting a full Tap Bar.
func get_tap_harvest(tier: int, harvest_level: int) -> float:
	var base: float = GameData.FLORA[tier].production * GameData.TAP_HARVEST_MULT
	return base * (1.0 + 0.5 * float(harvest_level))


## Returns how many taps are needed to fill a Tap Bar.
func get_taps_needed(speed_level: int) -> int:
	return maxi(5, GameData.TAP_BAR_MAX - 3 * speed_level)


## Returns the total passive Dewdrop income per second across all planted Flora.
func get_total_income(flora_map: Dictionary, skill_levels: Dictionary) -> float:
	var total := 0.0
	for pos in flora_map:
		var data: Dictionary = flora_map[pos]
		var tier_skill: int = skill_levels.get("tier_%d" % data.tier, 0)
		total += get_flora_production(data.tier, tier_skill)
	return total


## Returns the maximum offline minutes (base + upgrades).
func get_offline_cap_minutes(offline_level: int) -> float:
	return GameData.OFFLINE_BASE_MINUTES + 30.0 * float(offline_level)
