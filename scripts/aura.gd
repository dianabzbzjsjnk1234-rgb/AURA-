extends Node

const SAVE_PATH := "user://aura_progress.cfg"
const CREAM := Color("faf5ec")
const INK := Color("393346")
const GOLD := Color("ae8749")
const PURPLE := Color("837495")
# Secondary text colour: dark enough to read on the lavender scenery (about 7:1).
const MUTED := Color("4d4160")
# Sound effects chosen by our team from Freesound (CC0 / CC BY 4.0, credited in
# the README); trimmed, levelled and converted to OGG.
const SOUNDS := {
	"place": "res://assets/audio/sfx/place.ogg",
	"rotate": "res://assets/audio/sfx/rotate.ogg",
	"delete": "res://assets/audio/sfx/delete.ogg",
	"click": "res://assets/audio/sfx/click.ogg",
	"error": "res://assets/audio/sfx/error.ogg",
	"star": "res://assets/audio/sfx/star.ogg",
	"whoosh": "res://assets/audio/sfx/whoosh.ogg",
	"pop": "res://assets/audio/sfx/pop.ogg",
	"win": "res://assets/audio/sfx/win.ogg",
	"coins": "res://assets/audio/sfx/coins.ogg",
	"story_line": "res://assets/audio/sfx/story_line.ogg",
}
# Aliases: name -> [sound, pitch] (none needed now that every event has its own file).
const SFX := {}
# Drop the team's own loop here; the game runs without music until it exists.
const MUSIC_PATH := "res://assets/audio/music/ambience.ogg"
signal motion_changed
signal layout_changed
# Wide phones (iPhone ~19.5:9) get extra width instead of black bars: the
# 1280x800 layout is centred and only the background fills the sides.
const DESIGN := Vector2(1280, 800)
const LEVEL_COUNT := 8
const GAME_SCENE := "res://scenes/game.tscn"
var margin_x := 0.0
# Best reward (0-3 stars) per chapter; chapters unlock one after another.
var best: Array = []
var unlocked := 1
var current_level := 1
# Page the main menu opens on ("chapters" when returning from a level).
var menu_page := ""
var vibration := true
var tilt_rotate := false
var show_fps := false
var perf: CanvasLayer
# Shards of light and the shop (scripts/economy.gd).
var shop: Node
# Story episodes unlocked by chapters (scripts/story.gd).
var story: Node
var sfx_volume := 0.7
var music_volume := 0.3
var reduced_motion := false
var tutorial := true
# How many times the main menu has opened: the first visits show icon captions.
var menu_visits := 0
# Default caption for each icon (shown on a long press); callers can override.
const ICON_HINTS := {
	"settings": "Settings", "info": "Credits", "shop": "Shop", "chapters": "Chapters",
	"play": "Play", "studio": "Studio", "story": "Episodes", "back": "Back", "reset": "Restart",
	"check": "OK", "close": "Cancel", "home": "Main menu", "hint": "Hint", "prism": "Prism",
	"undo": "Undo", "delete": "Delete", "rotate_cw": "Turn right", "rotate_ccw": "Turn left",
	"pause": "Pause", "motion": "Reduce animation", "vibration": "Vibration",
	"tilt": "Tilt to rotate", "fps": "Show FPS", "save": "Save", "load": "Load", "star": "Beams",
	"sound": "Sound", "music": "Music", "language": "Language",
}
# Interface language: "en", "ru" or "kk" (Settings → Language); empty = phone language.
const LANGUAGES := ["en", "ru", "kk"]
const LANGUAGE_NAMES := {"en": "English", "ru": "Русский", "kk": "Қазақша"}
var language := ""
var save_error := ""
var music: AudioStreamPlayer
var voices: Dictionary = {}

func _ready() -> void:
	best.resize(LEVEL_COUNT)
	best.fill(0)
	shop = load("res://scripts/economy.gd").new()
	add_child(shop)
	story = load("res://scripts/story.gd").new()
	add_child(story)
	load_progress()
	apply_language()
	perf = load("res://scripts/perf_monitor.gd").new()
	add_child(perf)
	_make_veil()
	get_tree().root.size_changed.connect(apply_layout)
	apply_layout()
	music = AudioStreamPlayer.new()
	add_child(music)
	if ResourceLoader.exists(MUSIC_PATH):
		var stream := load(MUSIC_PATH) as AudioStreamOggVorbis
		stream.loop = true
		music.stream = stream
		music.play()
	for key in SOUNDS:
		var voice := AudioStreamPlayer.new()
		voice.stream = load(SOUNDS[key])
		voice.max_polyphony = 4
		add_child(voice)
		voices[key] = voice
	apply_audio()

func apply_layout() -> void:
	var width := get_tree().root.get_visible_rect().size.x
	margin_x = maxf(0.0, (width - DESIGN.x) / 2.0)
	get_tree().root.canvas_transform = Transform2D(0.0, Vector2(margin_x, 0.0))
	layout_changed.emit()

# Uses the saved language, or the phone's language when it is Russian or Kazakh.
func apply_language() -> void:
	var lang := language
	if lang.is_empty():
		var system := OS.get_locale_language()
		lang = system if LANGUAGES.has(system) else "en"
	TranslationServer.set_locale(lang)

func current_language() -> String:
	var lang := TranslationServer.get_locale().substr(0, 2)
	return lang if LANGUAGES.has(lang) else "en"

func has_music() -> bool:
	return music.stream != null

# Freezes editor-authored animation (AnimationPlayer / AnimatedSprite2D) in a scene.
func apply_motion(root: Node) -> void:
	for player in root.find_children("*", "AnimationPlayer", true, false):
		if reduced_motion and player.is_playing() and player.get_animation(player.current_animation).loop_mode == Animation.LOOP_NONE:
			player.seek(player.current_animation_length, true)
		player.speed_scale = 0.0 if reduced_motion else 1.0
	for sprite in root.find_children("*", "AnimatedSprite2D", true, false):
		sprite.speed_scale = 0.0 if reduced_motion else 1.0
	for particles in root.find_children("*", "CPUParticles2D", true, false):
		particles.speed_scale = 0.0 if reduced_motion else 1.0

func apply_audio() -> void:
	music.volume_db = linear_to_db(maxf(music_volume, 0.0001)) - 7.0
	for voice in voices.values():
		voice.volume_db = linear_to_db(maxf(sfx_volume, 0.0001)) - 5.0

func sound(key: String, pitch: float = 1.0) -> void:
	if SFX.has(key):
		pitch *= float(SFX[key][1])
		key = SFX[key][0]
	if sfx_volume > 0.0 and voices.has(key):
		voices[key].pitch_scale = pitch
		voices[key].play()

# --- Juice: every input gets a tween and a sound (polish pass for the final) ---
# Pops a node in from scale 0 with a little overshoot.
func pop_in(node: CanvasItem, delay: float = 0.0, duration: float = 0.3) -> void:
	if reduced_motion or not is_instance_valid(node): return
	if node is Control: node.pivot_offset = node.size / 2.0
	var target: Vector2 = node.scale
	node.scale = Vector2.ONE * 0.01
	var tween := node.create_tween()
	if delay > 0.0: tween.tween_interval(delay)
	tween.tween_property(node, "scale", target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Short squash when a button is pressed.
func press(node: Control) -> void:
	if reduced_motion: return
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * 0.9, 0.06)
	tween.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Side-to-side shake for "not allowed" feedback.
# Shard counter: a gold sparkle and a number, used by the menu, shop and win panel.
func shard_chip(parent: Node, pos: Vector2, amount: int, prefix: String = "") -> Label:
	var box := panel(parent, Rect2(pos, Vector2(176, 56)))
	box.add_theme_stylebox_override("panel", style(Color(1, 1, 1, 0.8)))
	var icon := TextureRect.new()
	icon.texture = load("res://assets/art/pieces/sparkle.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(10, 8)
	icon.size = Vector2(40, 40)
	icon.modulate = Color("d9a93c")
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var count := label(box, prefix + str(amount), Rect2(54, 6, 116, 44), 28)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return count

# Counts a shard label up to its new value with ticks.
func count_up(count: Label, from: int, to: int, prefix: String = "") -> void:
	if reduced_motion or to == from:
		count.text = prefix + str(to)
		return
	var tween := count.create_tween()
	tween.tween_method(func(v: float): count.text = prefix + str(int(v)), float(from), float(to), 0.6)
	tween.tween_callback(func(): sound("coins"))

# Board of the chapter in progress, kept while the language changes.
var carry_board := {}

# One colour grade for all story pictures (shaders/story_grade.gdshader).
const STORY_GRADE := preload("res://shaders/story_grade.gdshader")
func grade_story(picture: CanvasItem, strength := 0.5) -> void:
	var material := ShaderMaterial.new()
	material.shader = STORY_GRADE
	material.set_shader_parameter("strength", strength)
	picture.material = material

# Runs a callback after a delay, but only while `owner_node` still exists
# (a tween bound to the node: if the screen closes first, nothing happens).
func later(owner_node: Node, delay: float, callback: Callable) -> void:
	var tween := owner_node.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(callback)

func shake(node: CanvasItem) -> void:
	if reduced_motion or not is_instance_valid(node): return
	var start: Vector2 = node.position
	var tween := node.create_tween()
	for offset in [12.0, -10.0, 7.0, -4.0, 0.0]:
		tween.tween_property(node, "position:x", start.x + offset, 0.05)

func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for i in range(LEVEL_COUNT):
		best[i] = clampi(int(cfg.get_value("progress", "level_%d" % (i + 1), 0)), 0, 3)
	# Assignment 3 saves: chapter 1 is unchanged, the old chapter 2 was replaced.
	if cfg.has_section_key("progress", "stars_0") and best[0] == 0:
		best[0] = clampi(int(cfg.get_value("progress", "stars_0", 0)), 0, 3)
	_update_unlocked()
	shop.load_from(cfg)
	story.load_from(cfg)
	vibration = bool(cfg.get_value("settings", "vibration", true))
	tilt_rotate = bool(cfg.get_value("settings", "tilt_rotate", false))
	show_fps = bool(cfg.get_value("settings", "show_fps", false))
	sfx_volume = clampf(float(cfg.get_value("settings", "sfx", 0.7)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("settings", "music", 0.3)), 0.0, 1.0)
	reduced_motion = bool(cfg.get_value("settings", "reduced_motion", false))
	# The old picture-only Settings made "Reduce animation" easy to switch on by
	# mistake (it hides confetti and star bursts): saves from before settings
	# version 2 get it switched off once.
	if int(cfg.get_value("settings", "version", 1)) < 2: reduced_motion = false
	language = str(cfg.get_value("settings", "language", ""))
	tutorial = bool(cfg.get_value("settings", "tutorial", true))
	menu_visits = int(cfg.get_value("settings", "menu_visits", 0))

func save_progress() -> void:
	var cfg := ConfigFile.new()
	for i in range(LEVEL_COUNT):
		cfg.set_value("progress", "level_%d" % (i + 1), best[i])
	shop.save_to(cfg)
	story.save_to(cfg)
	cfg.set_value("settings", "vibration", vibration)
	cfg.set_value("settings", "tilt_rotate", tilt_rotate)
	cfg.set_value("settings", "show_fps", show_fps)
	cfg.set_value("settings", "sfx", sfx_volume)
	cfg.set_value("settings", "music", music_volume)
	cfg.set_value("settings", "reduced_motion", reduced_motion)
	cfg.set_value("settings", "version", 2)
	cfg.set_value("settings", "language", language)
	cfg.set_value("settings", "tutorial", tutorial)
	cfg.set_value("settings", "menu_visits", menu_visits)
	save_error = "" if cfg.save(SAVE_PATH) == OK else "Progress could not be saved on this device."

func complete(level: int, rating: int) -> void:
	var old := int(best[level - 1])
	shop.last_earned = shop.reward_for(old, rating)
	shop.earn(shop.last_earned)
	best[level - 1] = maxi(old, rating)
	_update_unlocked()
	save_progress()

func reset_progress() -> void:
	best.fill(0)
	shop.reset()
	story.reset()
	_update_unlocked()
	save_progress()

func _update_unlocked() -> void:
	unlocked = 1
	while unlocked < LEVEL_COUNT and int(best[unlocked - 1]) > 0:
		unlocked += 1

func total_stars() -> int:
	var total := 0
	for value in best: total += int(value)
	return total

# Soft light between screens: the new screen appears out of a cream glow.
var veil: ColorRect
var veil_tween: Tween
func _make_veil() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	veil = ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(1.0, 0.98, 0.94, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)

func light_transition(strength := 1.0, duration := 0.45) -> void:
	if reduced_motion or veil == null: return
	if veil_tween: veil_tween.kill()
	veil.color.a = maxf(veil.color.a, strength)
	veil_tween = veil.create_tween()
	veil_tween.tween_property(veil, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func change_scene(path: String) -> void:
	light_transition()
	get_tree().change_scene_to_file(path)

func reload_scene() -> void:
	light_transition(0.8)
	get_tree().reload_current_scene()

# 0 opens Creative Studio; 1..LEVEL_COUNT open a chapter.
func start_level(number: int) -> void:
	if number > unlocked: return
	current_level = number
	light_transition()
	# The menu starts loading the chapter scene in the background, so the
	# switch does not stall on a long frame.
	if ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(GAME_SCENE))
	else:
		get_tree().change_scene_to_file(GAME_SCENE)

func preload_game() -> void:
	if ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(GAME_SCENE)

func haptic(ms: int) -> void:
	if vibration: Input.vibrate_handheld(ms)

func label(parent: Node, text: String, rect: Rect2, size: int = 24, color: Color = INK) -> Label:
	var item := Label.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	fit_text(item)
	return item

func paragraph(parent: Node, text: String, rect: Rect2, size: int = 24) -> Label:
	var item := Label.new()
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", INK)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.text = text
	item.position = rect.position
	item.size = rect.size
	parent.add_child(item)
	return item

func style(fill: Color = CREAM) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color("cbb995")
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box

func button(parent: Node, text: String, rect: Rect2, action: Callable, size: int = 26) -> Button:
	var item := Button.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.focus_mode = Control.FOCUS_NONE
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", INK)
	item.add_theme_color_override("font_hover_color", INK)
	item.add_theme_color_override("font_pressed_color", INK)
	item.add_theme_color_override("font_disabled_color", Color("7a7180"))
	item.add_theme_stylebox_override("normal", style())
	item.add_theme_stylebox_override("hover", style(Color("fffaf2")))
	item.add_theme_stylebox_override("pressed", style(Color("e9ddc7")))
	item.add_theme_stylebox_override("hover_pressed", style(Color("e9ddc7")))
	item.add_theme_color_override("font_hover_pressed_color", INK)
	item.add_theme_stylebox_override("disabled", style(Color("e1dce3")))
	parent.add_child(item)
	# A long press shows the button's caption instead of pressing it.
	item.pressed.connect(func():
		if item.get_meta("long_pressed", false):
			item.set_meta("long_pressed", false)
			return
		action.call())
	item.button_down.connect(func():
		press(item)
		sound("click")
		item.set_meta("long_pressed", false)
		item.set_meta("held", true)
		if item.has_meta("hint") and not item.toggle_mode:
			later(item, 0.45, func():
				if item.get_meta("held", false):
					item.set_meta("long_pressed", true)
					show_hint(item)))
	item.button_up.connect(func(): item.set_meta("held", false))
	fit_text(item)
	return item

# Caption bubble above a button (long press), fades out after a moment.
func show_hint(item: Control) -> void:
	var text := TranslationServer.translate(str(item.get_meta("hint", "")))
	if text.is_empty(): return
	var bubble := Label.new()
	bubble.text = text
	bubble.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bubble.add_theme_font_size_override("font_size", 24)
	bubble.add_theme_color_override("font_color", Color.WHITE)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.23, 0.18, 0.39, 0.92)
	box.set_corner_radius_all(18)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("normal", box)
	bubble.z_index = 50
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(bubble)
	bubble.reset_size()
	var below: bool = item.get_global_rect().position.y < 120
	bubble.position = Vector2((item.size.x - bubble.size.x) / 2.0, item.size.y + 8 if below else -bubble.size.y - 8)
	haptic(15)
	pop_in(bubble, 0.0, 0.2)
	var fade := bubble.create_tween()
	fade.tween_interval(1.6)
	fade.tween_property(bubble, "modulate:a", 0.0, 0.4)
	fade.tween_callback(bubble.queue_free)

# Small caption under a button (first visits of the menu, and in Settings).
func caption(item: Control, text: String = "", fade_after: float = 0.0) -> Label:
	var words := text if not text.is_empty() else str(item.get_meta("hint", ""))
	var width := maxf(item.size.x + 28, 134.0)
	var under := paragraph(item.get_parent(), words, Rect2(item.position.x + item.size.x / 2.0 - width / 2.0, item.position.y + item.size.y + 2, width, 56), 22)
	under.add_theme_color_override("font_color", MUTED)
	# A soft cream outline keeps captions readable over dark parts of the background.
	under.add_theme_color_override("font_outline_color", Color(0.98, 0.96, 0.93, 0.92))
	under.add_theme_constant_override("outline_size", 10)
	under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	under.autowrap_mode = TextServer.AUTOWRAP_WORD  # break only between words
	under.clip_text = false
	if fade_after > 0.0 and not reduced_motion:
		var fade := under.create_tween()
		fade.tween_interval(fade_after)
		fade.tween_property(under, "modulate:a", 0.0, 0.8)
		fade.tween_callback(under.queue_free)
	return under

# Round "glass" button with a picture instead of words. icon: a name from
# assets/ui/icons (svg) or a full res:// path to a picture.
func icon_button(parent: Node, icon: String, rect: Rect2, action: Callable, gold: bool = false, hint: String = "") -> Button:
	var item := button(parent, "", rect, action)
	var key := icon.get_file().get_basename()
	if not hint.is_empty() or ICON_HINTS.has(key): item.set_meta("hint", hint if not hint.is_empty() else ICON_HINTS[key])
	item.icon = load(icon if icon.begins_with("res://") else "res://assets/ui/icons/%s.svg" % icon)
	item.expand_icon = true
	item.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_constant_override("icon_max_width", int(rect.size.x * 0.52))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.9 if state.contains("pressed") else 0.72)
		if state == "disabled": box.bg_color = Color(1, 1, 1, 0.3)
		box.border_color = GOLD if gold else Color(1, 1, 1, 0.95)
		box.set_border_width_all(3 if gold else 2)
		box.set_corner_radius_all(int(rect.size.y / 2))
		box.shadow_color = Color(0.24, 0.16, 0.35, 0.18)
		box.shadow_size = 8
		item.add_theme_stylebox_override(state, box)
	item.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.4))
	return item

# Russian and Kazakh words are longer than English: shrink the font until the
# translated text fits its box (not below min_size), then let it wrap.
func fit_text(item: Control, min_size: int = 22) -> void:
	var fit := func():
		if not is_instance_valid(item): return
		var text: String = TranslationServer.translate(item.text) if item.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else item.text
		if text.is_empty() or "\n" in text: return
		var font: Font = item.get_theme_font("font")
		var size: int = item.get_theme_font_size("font_size")
		var room: float = item.size.x - (36.0 if item is Button else 4.0)
		var lowest := maxi(min_size, 24 if item is Button else min_size)
		while size > lowest and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
			size -= 1
		item.add_theme_font_size_override("font_size", size)
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
			item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fit.call_deferred()

func panel(parent: Node, rect: Rect2) -> Panel:
	var item := Panel.new()
	item.position = rect.position
	item.size = rect.size
	item.add_theme_stylebox_override("panel", style())
	parent.add_child(item)
	return item

# On/off switch drawn as a picture: gold ring and full colour when on, faded when off.
func icon_switch(parent: Node, icon: String, rect: Rect2, value: bool, on_change: Callable) -> Button:
	var item := icon_button(parent, icon, rect, func(): pass)
	item.toggle_mode = true
	item.button_pressed = value
	var paint := func(state: bool):
		item.modulate = Color.WHITE if state else Color(1, 1, 1, 0.45)
		for name in ["normal", "hover", "pressed", "hover_pressed"]:
			(item.get_theme_stylebox(name) as StyleBoxFlat).border_color = GOLD if state else Color(1, 1, 1, 0.95)
			(item.get_theme_stylebox(name) as StyleBoxFlat).set_border_width_all(4 if state else 2)
	paint.call(value)
	item.toggled.connect(func(state: bool):
		paint.call(state)
		on_change.call(state))
	return item

func toggle(parent: Node, rect: Rect2, title: String, value: bool, on_change: Callable) -> Button:
	var item := button(parent, "", rect, func(): pass, 24)
	item.toggle_mode = true
	item.button_pressed = value
	item.text = tr(title) + tr(": On" if value else ": Off")
	item.toggled.connect(func(state: bool):
		item.text = tr(title) + tr(": On" if state else ": Off")
		on_change.call(state))
	return item

func open_settings(parent: Node, on_close: Callable = Callable()) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.15, 0.12, 0.22, 0.55)
	overlay.position = Vector2(-640, 0)
	overlay.size = Vector2(2560, 800)
	parent.add_child(overlay)
	var box := panel(overlay, Rect2(780, 60, 1000, 660))
	pop_in(box)
	sound("whoosh")
	var close := func():
		save_progress()
		overlay.queue_free()
		if on_close.is_valid(): on_close.call()
	label(box, "Settings", Rect2(36, 20, 600, 56), 36)
	icon_button(box, "close", Rect2(904, 16, 76, 76), close)
	# Left column: volume and language. Right column: on/off switches.
	for i in range(2):
		var row := setting_row(box, "sound" if i == 0 else "music", "Sound" if i == 0 else "Music", Rect2(36, 100 + i * 88, 440, 76))
		if i == 1 and not has_music(): continue
		var value := label(row, "", Rect2(316, 18, 64, 40), 26)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var show := func(): value.text = "%d%%" % roundi((sfx_volume if i == 0 else music_volume) * 100)
		show.call()
		for step in [-0.1, 0.1]:
			button(row, "–" if step < 0 else "+", Rect2(244 if step < 0 else 376, 6, 64, 64), func():
				if i == 0: sfx_volume = clampf(snappedf(sfx_volume + step, 0.1), 0.0, 1.0)
				else: music_volume = clampf(snappedf(music_volume + step, 0.1), 0.0, 1.0)
				apply_audio()
				show.call()
				if i == 0: sound("rotate"), 30)
	var lang_row := setting_row(box, "language", "Language", Rect2(36, 276, 440, 76))
	var lang_button := button(lang_row, LANGUAGE_NAMES[current_language()], Rect2(244, 6, 196, 64), func(): pass, 24)
	lang_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lang_button.pressed.connect(func():
		language = LANGUAGES[(LANGUAGES.find(current_language()) + 1) % LANGUAGES.size()]
		apply_language()
		save_progress()
		overlay.queue_free()
		# The screen is rebuilt in the new language; a chapter in progress
		# keeps its board (crystals, undo history, hints) across the reload.
		var scene := get_tree().current_scene
		if scene and scene.has_method("board_state"): carry_board = scene.board_state()
		reload_scene())
	var switches := [
		["vibration", "Vibration", vibration, func(v: bool):
			vibration = v
			haptic(40)],
		["hint", "Tutorial tips", tutorial, func(v: bool): tutorial = v],
		["motion", "Reduce animation", reduced_motion, func(v: bool):
			reduced_motion = v
			motion_changed.emit()],
		["tilt", "Tilt to rotate", tilt_rotate, func(v: bool): tilt_rotate = v],
	]
	for k in range(switches.size()):
		setting_switch(box, switches[k][0], switches[k][1], Rect2(524, 100 + k * 88, 440, 76), switches[k][2], switches[k][3])
	# Developer tools, kept apart and smaller.
	label(box, "For developers", Rect2(36, 470, 600, 34), 22, MUTED)
	setting_switch(box, "fps", "Show FPS", Rect2(36, 512, 440, 76), show_fps, func(v: bool):
		show_fps = v
		perf.refresh_visibility())
	button(box, "Performance test (60 s)", Rect2(524, 512, 440, 76), func():
		close.call()
		perf.start_test(60.0), 24)
	return overlay

# A settings row: icon and title on the left, controls added on the right.
func setting_row(parent: Node, icon: String, title: String, rect: Rect2) -> Panel:
	var row := panel(parent, rect)
	row.add_theme_stylebox_override("panel", style(Color(1, 1, 1, 0.55)))
	var picture := TextureRect.new()
	picture.texture = load("res://assets/ui/icons/%s.svg" % icon)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.position = Vector2(14, 16)
	picture.size = Vector2(44, 44)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	label(row, title, Rect2(70, 18, 172, 40), 26)
	return row

# On/off switch row: the whole row is tappable; the pill on the right slides.
func setting_switch(parent: Node, icon: String, title: String, rect: Rect2, value: bool, on_change: Callable) -> Button:
	var item := button(parent, "", rect, func(): pass)
	item.toggle_mode = true
	item.button_pressed = value
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		item.add_theme_stylebox_override(state, style(Color(1, 1, 1, 0.55)))
	var picture := TextureRect.new()
	picture.texture = load("res://assets/ui/icons/%s.svg" % icon)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.position = Vector2(14, 16)
	picture.size = Vector2(44, 44)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(picture)
	var title_label := label(item, title, Rect2(70, 18, rect.size.x - 170, 40), 26)
	title_label.clip_text = true
	var track := Panel.new()
	track.position = Vector2(rect.size.x - 96, 20)
	track.size = Vector2(80, 38)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(track)
	var knob := Panel.new()
	knob.size = Vector2(30, 30)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_box := StyleBoxFlat.new()
	knob_box.bg_color = Color.WHITE
	knob_box.set_corner_radius_all(15)
	knob_box.shadow_color = Color(0, 0, 0, 0.18)
	knob_box.shadow_size = 3
	knob.add_theme_stylebox_override("panel", knob_box)
	track.add_child(knob)
	var paint := func(on: bool, animate: bool):
		var track_box := StyleBoxFlat.new()
		track_box.bg_color = GOLD if on else Color("cfc8d6")
		track_box.set_corner_radius_all(19)
		track.add_theme_stylebox_override("panel", track_box)
		var target := Vector2(46 if on else 4, 4)
		if animate and not reduced_motion: knob.create_tween().tween_property(knob, "position", target, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else: knob.position = target
	paint.call(value, false)
	item.toggled.connect(func(on: bool):
		paint.call(on, true)
		on_change.call(on))
	return item

func _exit_tree() -> void:
	if music: music.stop()
	for voice in voices.values(): voice.stop()
