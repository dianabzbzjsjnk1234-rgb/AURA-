extends Node
# Aura: the in-game currency and shop (a demo economy, no real money).
# Earned by improving a chapter's stars and by a daily visit; spent on
# consumables (hints, extra crystals) and cosmetics (crystal and beam skins).
# Saved together with the progress in user://aura_progress.cfg (see aura.gd).

signal changed

const STAR_REWARD := 5        # per newly earned reward star
const FIRST_CLEAR_REWARD := 5 # the first time a chapter is completed
const DAILY_REWARD := 10       # once per calendar day, from the main menu
const ITEMS := {
	"hint": {"name": "Hint", "desc": "Shows where a crystal goes.", "price": 30, "kind": "consumable"},
	"mirror": {"name": "Extra crystal", "desc": "One more crystal above the chapter\'s limit.", "price": 40, "kind": "consumable"},
	"prism": {"name": "Prism", "desc": "Splits the beam in two. A chapter won with a prism gives max ★★.", "price": 60, "kind": "consumable"},
	"crystal_rose": {"name": "Rose crystals", "desc": "Makes your crystals pink.", "price": 120, "kind": "crystal", "tint": Color("f6b9cb")},
	"crystal_mint": {"name": "Mint crystals", "desc": "Makes your crystals mint green.", "price": 120, "kind": "crystal", "tint": Color("b5ead4")},
	"crystal_gold": {"name": "Gold crystals", "desc": "Makes your crystals golden.", "price": 200, "kind": "crystal", "tint": Color("f4d58c")},
	"beam_aurora": {"name": "Aurora beam", "desc": "Makes the light beam green-blue.", "price": 150, "kind": "beam", "colors": [Color("7fe3c8", 0.28), Color("3fa98f"), Color("e6fff7")]},
	"beam_sunset": {"name": "Sunset beam", "desc": "Makes the light beam pink-orange.", "price": 150, "kind": "beam", "colors": [Color("f6a28c", 0.28), Color("c9665a"), Color("ffe6dc")]},
}
const ORDER := ["hint", "mirror", "prism", "crystal_rose", "crystal_mint", "crystal_gold", "beam_aurora", "beam_sunset"]
const DEFAULT_BEAM := [Color("eac66c", 0.25), Color("bd9547"), Color("fff1b4")]

var coins := 0
var inventory := {"hint": 0, "mirror": 0, "prism": 0}
var owned: Array = []
var crystal_skin := ""
var beam_skin := ""
var last_daily := ""
var last_earned := 0

func earn(amount: int) -> void:
	if amount <= 0: return
	coins += amount
	changed.emit()

# Shards for a finished chapter: only stars that beat the old best count, so
# replaying a solved chapter cannot farm currency.
func reward_for(old_best: int, rating: int) -> int:
	return maxi(0, rating - old_best) * STAR_REWARD + (FIRST_CLEAR_REWARD if old_best == 0 else 0)

func price(id: String) -> int:
	return int(ITEMS[id].price)

func is_owned(id: String) -> bool:
	return owned.has(id)

func can_buy(id: String) -> bool:
	if not ITEMS.has(id) or coins < price(id): return false
	return ITEMS[id].kind == "consumable" or not is_owned(id)

func buy(id: String) -> bool:
	if not can_buy(id): return false
	coins -= price(id)
	if ITEMS[id].kind == "consumable":
		inventory[id] = int(inventory.get(id, 0)) + 1
	else:
		owned.append(id)
		equip(id)
	changed.emit()
	Aura.save_progress()
	return true

# Cosmetics: equipping an equipped skin again takes it off.
func equip(id: String) -> void:
	if not is_owned(id): return
	match ITEMS[id].kind:
		"crystal": crystal_skin = "" if crystal_skin == id else id
		"beam": beam_skin = "" if beam_skin == id else id
	changed.emit()
	Aura.save_progress()

func is_equipped(id: String) -> bool:
	return crystal_skin == id or beam_skin == id

func use(id: String) -> bool:
	if int(inventory.get(id, 0)) <= 0: return false
	inventory[id] = int(inventory[id]) - 1
	changed.emit()
	Aura.save_progress()
	return true

# Returns the shards given today (0 when already claimed).
func claim_daily(today: String) -> int:
	if last_daily == today: return 0
	last_daily = today
	earn(DAILY_REWARD)
	Aura.save_progress()
	return DAILY_REWARD

func crystal_tint() -> Color:
	return ITEMS[crystal_skin].tint if ITEMS.has(crystal_skin) else Color.WHITE

# [glow, edge, core] colours of the light beam.
func beam_colors() -> Array:
	return ITEMS[beam_skin].colors if ITEMS.has(beam_skin) else DEFAULT_BEAM

func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("shop", "coins", coins)
	cfg.set_value("shop", "inventory", inventory)
	cfg.set_value("shop", "owned", owned)
	cfg.set_value("shop", "crystal_skin", crystal_skin)
	cfg.set_value("shop", "beam_skin", beam_skin)
	cfg.set_value("shop", "last_daily", last_daily)

func load_from(cfg: ConfigFile) -> void:
	coins = maxi(0, int(cfg.get_value("shop", "coins", 0)))
	var saved = cfg.get_value("shop", "inventory", {})
	inventory = {"hint": 0, "mirror": 0, "prism": 0}
	if saved is Dictionary:
		for key in inventory: inventory[key] = maxi(0, int(saved.get(key, 0)))
	owned = []
	for id in cfg.get_value("shop", "owned", []):
		if ITEMS.has(str(id)) and ITEMS[str(id)].kind != "consumable": owned.append(str(id))
	crystal_skin = str(cfg.get_value("shop", "crystal_skin", ""))
	beam_skin = str(cfg.get_value("shop", "beam_skin", ""))
	if not owned.has(crystal_skin): crystal_skin = ""
	if not owned.has(beam_skin): beam_skin = ""
	last_daily = str(cfg.get_value("shop", "last_daily", ""))

func reset() -> void:
	coins = 0
	inventory = {"hint": 0, "mirror": 0, "prism": 0}
	owned = []
	crystal_skin = ""
	beam_skin = ""
	last_daily = ""
	last_earned = 0
	changed.emit()
