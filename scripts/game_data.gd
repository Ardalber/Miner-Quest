class_name GameData
extends RefCounted
## Données du jeu : types de cases, minerais, pioches et probabilités.

const FLOOR := 0
const STONE := 1
const BEDROCK := 2
const COPPER := 3
const IRON := 4
const GOLD := 5
const CHEST := 6
const OPENED := 7
const STAIRS := 8

const TILE := 32

## Blocs que la pioche peut casser.
## hp : solidité, tier : niveau de pioche minimum, res : ressource obtenue.
static var BLOCKS := {
	STONE: {"name": "Roche", "hp": 3, "tier": 0, "color": Color(0.55, 0.47, 0.4)},
	COPPER: {"name": "Cuivre", "hp": 4, "tier": 0, "color": Color(0.91, 0.5, 0.25), "res": "copper", "min": 1, "max": 3},
	IRON: {"name": "Fer", "hp": 7, "tier": 1, "color": Color(0.84, 0.87, 0.93), "res": "iron", "min": 1, "max": 2},
	GOLD: {"name": "Or", "hp": 10, "tier": 2, "color": Color(1.0, 0.82, 0.25), "res": "gold", "min": 1, "max": 2},
}

static var RESOURCES := {
	"copper": {"name": "Cuivre", "color": Color(0.91, 0.5, 0.25)},
	"iron": {"name": "Fer", "color": Color(0.84, 0.87, 0.93)},
	"gold": {"name": "Or", "color": Color(1.0, 0.82, 0.25)},
}

## Pioches dans l'ordre d'amélioration.
## power : dégâts par coup, tier : minerais accessibles (0 cuivre, 1 fer, 2 or).
static var PICKAXES := [
	{"name": "Pioche en bois", "power": 1, "tier": 0, "color": Color(0.62, 0.42, 0.22), "cost": {}},
	{"name": "Pioche en cuivre", "power": 2, "tier": 1, "color": Color(0.91, 0.5, 0.25), "cost": {"copper": 8}},
	{"name": "Pioche en fer", "power": 3, "tier": 2, "color": Color(0.84, 0.87, 0.93), "cost": {"copper": 12, "iron": 10}},
	{"name": "Pioche en or", "power": 5, "tier": 2, "color": Color(1.0, 0.82, 0.25), "cost": {"iron": 15, "gold": 10}},
	{"name": "Pioche de maître", "power": 8, "tier": 2, "color": Color(0.5, 0.95, 1.0), "cost": {"copper": 30, "iron": 25, "gold": 20}},
]

## Nom de la pioche minimale pour chaque niveau de minerai.
const TIER_NAMES := ["bois", "cuivre", "fer"]


## Plus on descend, plus le fer et l'or sont fréquents.
static func ore_weights(floor_num: int) -> Dictionary:
	var copper := maxf(0.35, 1.0 - (floor_num - 1) * 0.1)
	var iron := 0.15 if floor_num < 2 else minf(1.0, 0.35 + (floor_num - 2) * 0.2)
	var gold := 0.0
	if floor_num == 2:
		gold = 0.05
	elif floor_num >= 3:
		gold = minf(0.9, 0.15 + (floor_num - 3) * 0.12)
	return {COPPER: copper, IRON: iron, GOLD: gold}


static func pick_weighted(weights: Dictionary) -> int:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return weights.keys()[0]


static func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for res in cost:
		parts.append("%d %s" % [cost[res], String(RESOURCES[res]["name"]).to_lower()])
	return ", ".join(parts)
