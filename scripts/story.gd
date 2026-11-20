extends Node
# Story episodes (season 1): one short episode per chapter, unlocked when the
# chapter is finished. Text lives in story/season1.json; read episodes are saved.

const DATA_PATH := "res://story/season1.json"
var season := ""
var episodes: Array = []
var data: Dictionary = {}
var read: Array = []
# The prologue (Lira meets Frieren) is shown once, before the first chapter.
var intro_seen := false
# Episode -> chosen option at the end of the episode (the reward is given once).
var choices: Dictionary = {}

func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if data is Dictionary:
		self.data = data
		season = str(data.get("season", ""))
		episodes = data.get("episodes", [])

# Text in the interface language: "text_ru" / "text_kk" when present, else English.
func loc(entry: Dictionary, field: String) -> String:
	var lang: String = Aura.current_language()
	return str(entry.get(field + "_" + lang, entry.get(field, "")))

func title(i: int) -> String:
	return loc(episode(i), "title")

# Episode data; -1 is the prologue.
func episode(i: int) -> Dictionary:
	return data.get("intro", {}) if i < 0 else episodes[i]

func count() -> int:
	return episodes.size()

func is_unlocked(i: int) -> bool:
	return i >= 0 and i < episodes.size() and i < Aura.best.size() and int(Aura.best[i]) > 0

func is_read(i: int) -> bool:
	return read.has(i)

func mark_read(i: int) -> void:
	if i < 0:
		intro_seen = true
		Aura.save_progress()
		return
	if is_unlocked(i) and not read.has(i):
		read.append(i)
		Aura.save_progress()

# The newest unlocked episode the player has not opened yet, or -1.
func newest_unread() -> int:
	for i in range(episodes.size() - 1, -1, -1):
		if is_unlocked(i) and not is_read(i): return i
	return -1

# Records the player's choice; shards are given only the first time.
func choose(i: int, option: int) -> int:
	if not is_unlocked(i): return 0
	var first := not choices.has(i)
	choices[i] = option
	var shards := 0
	if first:
		shards = int(episodes[i].get("choice", {}).get("options", [])[option].get("aura", 0))
		Aura.shop.earn(shards)
	Aura.save_progress()
	return shards

func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("story", "read", read)
	cfg.set_value("story", "choices", choices)
	cfg.set_value("story", "intro_seen", intro_seen)

func load_from(cfg: ConfigFile) -> void:
	read = []
	choices = {}
	intro_seen = bool(cfg.get_value("story", "intro_seen", false))
	var saved = cfg.get_value("story", "choices", {})
	if saved is Dictionary:
		for key in saved: choices[int(key)] = int(saved[key])
	for i in cfg.get_value("story", "read", []):
		if int(i) >= 0 and int(i) < 64: read.append(int(i))

func reset() -> void:
	intro_seen = false
	read = []
	choices = {}
