extends Control
var content: Control
var scenery: Node2D
var character: Node2D

func _ready() -> void:
	scenery = load("res://scenes/background.tscn").instantiate()
	add_child(scenery)
	character = load("res://scenes/lightkeeper.tscn").instantiate()
	character.position = Vector2(1015, 358)
	character.scale = Vector2.ONE * 1.45
	add_child(character)
	content = Control.new()
	add_child(content)
	if Aura.menu_page == "chapters": show_chapters()
	else: show_home()
	Aura.menu_page = ""
	Aura.preload_game()

# Menu buttons and cards pop in one after another.
func _stagger_in() -> void:
	var delay := 0.0
	for node in content.get_children():
		if node is Button:
			Aura.pop_in(node, delay, 0.3)
			delay += 0.05

func clear() -> void:
	Aura.light_transition(0.5, 0.3)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func show_home() -> void:
	clear()
	character.visible = true
	character.position = Vector2(640, 398)
	character.scale = Vector2.ONE * 1.15
	character.happy = Aura.total_stars() > 0
	# Pictures instead of words: settings and credits top left, aura and shop top right.
	Aura.icon_button(content, "settings", Rect2(40, 24, 84, 84), func(): Aura.open_settings(self))
	Aura.icon_button(content, "info", Rect2(176, 24, 84, 84), show_credits)
	Aura.shard_chip(content, Vector2(950, 38), Aura.shop.coins)
	Aura.icon_button(content, "shop", Rect2(1150, 24, 84, 84), show_shop, true)
	# Title in Cinzel (SIL Open Font License, assets/fonts/Cinzel_OFL.txt).
	var title_font := FontVariation.new()
	title_font.base_font = load("res://assets/fonts/Cinzel.ttf")
	title_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	title_font.spacing_glyph = 18
	var title := Aura.label(content, "AURA", Rect2(240, 92, 800, 130), 112)
	title.add_theme_font_override("font", title_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_breathe(title)
	var total := Aura.label(content, "★ %d / %d" % [Aura.total_stars(), Aura.LEVEL_COUNT * 3], Rect2(540, 222, 200, 40), 26, Color("7d5f2a"))
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sparkles: Node2D = load("res://scenes/fx/title_sparkles.tscn").instantiate()
	sparkles.position = Vector2(640, 158)
	content.add_child(sparkles)
	# The lightkeeper stands in the middle; tap her to change her mood.
	var touch := Control.new()
	touch.position = Vector2(490, 270)
	touch.size = Vector2(300, 440)
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			character.next_emotion())
	content.add_child(touch)
	_episode_card()
	# Bottom: chapters map, the big Play button (with the chapter number), studio.
	Aura.icon_button(content, "chapters", Rect2(250, 650, 100, 100), show_chapters)
	var play := Aura.icon_button(content, "play", Rect2(567, 606, 146, 146), _play, true)
	play.add_theme_constant_override("icon_max_width", 70)
	var badge := Aura.label(play, str(Aura.unlocked), Rect2(98, 4, 46, 40), 26, Color.WHITE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gold := StyleBoxFlat.new()
	gold.bg_color = Aura.GOLD
	gold.set_corner_radius_all(20)
	badge.add_theme_stylebox_override("normal", gold)
	_glow(play)
	Aura.icon_button(content, "studio", Rect2(930, 650, 100, 100), func(): start_level(0))
	_stagger_in()
	# The first few visits explain the pictures with small fading captions.
	if Aura.menu_visits < 3:
		for node in content.get_children():
			if node is Button and node.has_meta("hint"): Aura.caption(node, "", 5.0)
	Aura.menu_visits += 1
	Aura.save_progress()
	_daily_reward()
	if not Aura.save_error.is_empty(): Aura.label(content, Aura.save_error, Rect2(400, 260, 560, 34), 22)

# Play: the very first time, the prologue introduces Lira and Frieren.
func _play() -> void:
	if not Aura.story.intro_seen:
		_open_story(-1, func(): start_level(Aura.unlocked))
	else:
		start_level(Aura.unlocked)

# Story: the newest episode as a picture of its scene, left of the lightkeeper.
func _episode_card() -> void:
	var story: Node = Aura.story
	var newest: int = story.newest_unread()
	var shown := newest
	if shown < 0:
		for i in range(story.count() - 1, -1, -1):
			if story.is_unlocked(i):
				shown = i
				break
	var card := _scene_card(maxi(shown, 0), Rect2(60, 280, 340, 254), func(): _open_story(newest) if newest >= 0 else show_story(), shown >= 0, newest >= 0)
	if newest >= 0: _glow(card)
	Aura.icon_button(content, "story", Rect2(60, 548, 84, 84), show_story)

# A button showing an episode's scene, its number, and new / watched / locked.
func _scene_card(i: int, rect: Rect2, action: Callable, open: bool, fresh: bool) -> Button:
	var story: Node = Aura.story
	var card := _pill("", rect, action, 24, fresh)
	# Soft corners (not a pill), a framed 16:9 picture and the episode's name below it.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := card.get_theme_stylebox(state) as StyleBoxFlat
		if box: box.set_corner_radius_all(22)
	var pic := Vector2(rect.size.x - 20, (rect.size.x - 20) * 9.0 / 16.0)
	var frame := Panel.new()
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color("2a2340")
	frame_box.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", frame_box)
	frame.position = Vector2(10, 10)
	frame.size = pic
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	var path := "res://story/scenes/" + str(story.episodes[i].get("scene", ""))
	if ResourceLoader.exists(path):
		var picture := TextureRect.new()
		picture.texture = load(path)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.size = pic
		picture.modulate = Color.WHITE if open else Color(0.35, 0.33, 0.42)
		Aura.grade_story(picture, 0.4)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(picture)
	var number := Aura.label(card, str(i + 1), Rect2(18, 18, 44, 40), 26, Color.WHITE)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color(0.23, 0.18, 0.39, 0.85)
	dot.set_corner_radius_all(20)
	number.add_theme_stylebox_override("normal", dot)
	var center := Vector2(10, 10) + pic / 2.0
	var back := Panel.new()
	var round := StyleBoxFlat.new()
	round.bg_color = Color(1, 1, 1, 0.85)
	round.set_corner_radius_all(32)
	back.add_theme_stylebox_override("panel", round)
	back.size = Vector2(64, 64)
	back.position = center - back.size / 2.0
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(back)
	var mark := TextureRect.new()
	mark.texture = load("res://assets/ui/icons/%s.svg" % ("play" if fresh else ("check" if open and story.is_read(i) else ("lock" if not open else "play"))))
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.size = Vector2(44, 44)
	mark.position = center - mark.size / 2.0
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(mark)
	var title := Aura.label(card, story.title(i) if open else "", Rect2(12, pic.y + 18, rect.size.x - 24, 40), 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return card

func _open_story(i: int, back: Callable = Callable()) -> void:
	var viewer := ColorRect.new()
	viewer.set_script(load("res://scripts/story_viewer.gd"))
	add_child(viewer)
	viewer.closed.connect(back if back.is_valid() else show_home)
	viewer.open(i)

# All episodes of the season as scene pictures: watched, new or locked.
func show_story() -> void:
	clear()
	character.visible = false
	var story: Node = Aura.story
	for i in range(story.count()):
		var open: bool = story.is_unlocked(i)
		_scene_card(i, Rect2(60 + (i % 4) * 292, 100 + (i / 4) * 250, 272, 222), func(): _story_tap(i), open, open and not story.is_read(i))
	Aura.icon_button(content, "back", Rect2(40, 666, 84, 84), show_home)
	_stagger_in()

func _story_tap(i: int) -> void:
	if Aura.story.is_unlocked(i):
		_open_story(i, show_story)
		return
	Aura.sound("error")
	Aura.shake(content.get_child(i))

# Rounded "glass" pill button used across the menu.
func _pill(text: String, rect: Rect2, action: Callable, size: int = 26, gold: bool = false) -> Button:
	var item := Aura.button(content, text, rect, action, size)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.9 if state.contains("pressed") else 0.72)
		if state == "disabled": box.bg_color = Color(1, 1, 1, 0.35)
		box.border_color = Aura.GOLD if gold else Color(1, 1, 1, 0.95)
		box.set_border_width_all(3 if gold else 2)
		box.set_corner_radius_all(int(rect.size.y / 2))
		box.shadow_color = Color(0.24, 0.16, 0.35, 0.16)
		box.shadow_size = 10
		box.content_margin_left = 18
		box.content_margin_right = 18
		item.add_theme_stylebox_override(state, box)
	if gold: item.add_theme_color_override("font_color", Color("6d4f1f"))
	return item

# Slow up-and-down float for the title.
func _breathe(node: Control) -> void:
	if Aura.reduced_motion: return
	var start := node.position.y
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "position:y", start - 6, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", start, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Gentle pulse that invites a tap on the main button.
func _glow(node: Control) -> void:
	if Aura.reduced_motion: return
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween().set_loops()
	tween.tween_interval(0.8)
	tween.tween_property(node, "scale", Vector2.ONE * 1.04, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Once a day the lightkeeper gives some shards.
func _daily_reward() -> void:
	var gift: int = Aura.shop.claim_daily(Time.get_date_string_from_system())
	if gift <= 0: return
	var chip := Aura.shard_chip(content, Vector2(552, 270), gift, "+")
	var box: Control = chip.get_parent()
	Aura.pop_in(box, 0.4, 0.35)
	Aura.later(box, 0.5, func(): Aura.sound("coins"))
	var fade := box.create_tween()
	fade.tween_interval(3.5)
	fade.tween_property(box, "modulate:a", 0.0, 0.6)
	fade.tween_callback(func(): if is_instance_valid(box): box.queue_free())
	show_home_counter_refresh()

func show_home_counter_refresh() -> void:
	for node in content.get_children():
		if node is Panel and node.position == Vector2(880, 32):
			node.get_child(1).text = str(Aura.shop.coins)

# Shop: big pictures instead of descriptions, split into three tabs.
const SHOP_TABS := {"Boosts": ["hint", "mirror", "prism"], "Crystals": ["crystal_rose", "crystal_mint", "crystal_gold"], "Beams": ["beam_aurora", "beam_sunset"]}
var shop_tab := "Boosts"
const SHOP_TAB_ICONS := {"Boosts": "hint", "Crystals": "res://assets/art/pieces/mirror.png", "Beams": "star"}

func show_shop() -> void:
	clear()
	character.visible = false
	var balance := Aura.shard_chip(content, Vector2(1034, 40), Aura.shop.coins)
	# Tabs as pictures: boosts (hint), crystals, beams.
	var x := 60.0
	for tab in SHOP_TABS:
		Aura.icon_button(content, SHOP_TAB_ICONS[tab], Rect2(x, 26, 96, 96), func():
			shop_tab = tab
			show_shop(), tab == shop_tab)
		x += 112
	var ids: Array = SHOP_TABS[shop_tab]
	for n in range(ids.size()):
		var id: String = ids[n]
		var card := _pill("", Rect2(60 + n * 384, 150, 360, 470), func(): _shop_tap(id, balance), 24, Aura.shop.is_equipped(id))
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			(card.get_theme_stylebox(state) as StyleBoxFlat).set_corner_radius_all(32)
		var picture := _item_picture(id)
		picture.position = Vector2(30, 40)
		card.add_child(picture)
		_price_row(card, id)
	Aura.icon_button(content, "back", Rect2(40, 666, 84, 84), show_home)
	_stagger_in()

# Price (sparkle + number), or the item's state for skins already bought.
func _price_row(card: Control, id: String) -> void:
	var shop: Node = Aura.shop
	if shop.is_equipped(id) or shop.is_owned(id):
		# Owned skins: a tick when worn, an empty ring when not.
		var mark := TextureRect.new()
		mark.texture = load("res://assets/ui/icons/%s.svg" % ("check" if shop.is_equipped(id) else "info"))
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.position = Vector2(140, 330)
		mark.size = Vector2(80, 80)
		mark.modulate = Color.WHITE if shop.is_equipped(id) else Color(1, 1, 1, 0.35)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(mark)
		return
	var chip := Aura.shard_chip(card, Vector2(92, 340), shop.price(id))
	chip.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shop.ITEMS[id].kind == "consumable":
		var have := Aura.label(card, "×%d" % shop.inventory[id], Rect2(262, 24, 70, 44), 28, Color("7d5f2a"))
		have.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

# A picture of each item, built from the game's own art.
func _item_picture(id: String) -> Control:
	var area := Control.new()
	area.size = Vector2(300, 250)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := Panel.new()
	var round := StyleBoxFlat.new()
	round.bg_color = Color("f4ead6")
	round.set_corner_radius_all(110)
	glow.add_theme_stylebox_override("panel", round)
	glow.position = Vector2(40, 15)
	glow.size = Vector2(220, 220)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(glow)
	var item: Dictionary = Aura.shop.ITEMS[id]
	match id:
		"hint":
			_picture(area, "res://assets/ui/icons/hint.svg", Rect2(80, 55, 140, 140), 0.0, Color.WHITE)
		"mirror":
			_picture(area, "res://assets/art/pieces/mirror.png", Rect2(70, 45, 160, 160), 0.0, Color.WHITE)
			Aura.label(area, "+1", Rect2(190, 30, 90, 70), 48, Color("7d5f2a"))
		"prism":
			_beam(area, Vector2(150, 10), Vector2(150, 125), [Color("eac66c", 0.35), Color("bd9547")])
			_beam(area, Vector2(150, 125), Vector2(30, 125), [Color("eac66c", 0.35), Color("bd9547")])
			_beam(area, Vector2(150, 125), Vector2(270, 125), [Color("eac66c", 0.35), Color("bd9547")])
			_picture(area, "res://assets/art/pieces/mirror.png", Rect2(95, 70, 110, 110), 45.0, Color(0.78, 0.92, 1))
			_picture(area, "res://assets/art/pieces/mirror.png", Rect2(95, 70, 110, 110), -45.0, Color(0.95, 0.8, 1))
			Aura.label(area, "max ★★", Rect2(150, 190, 140, 40), 24, Color("7d5f2a"))
		_:
			if item.kind == "crystal":
				_picture(area, "res://assets/art/pieces/mirror.png", Rect2(60, 35, 180, 180), 0.0, item.tint)
			else:
				_beam(area, Vector2(10, 190), Vector2(150, 60), item.colors)
				_beam(area, Vector2(150, 60), Vector2(290, 190), item.colors)
				_picture(area, "res://assets/art/pieces/star_lit.png", Rect2(110, 20, 80, 80), 0.0, Color.WHITE)
	return area

func _picture(parent: Control, path: String, rect: Rect2, degrees: float, tint: Color) -> void:
	var image := TextureRect.new()
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = rect.position
	image.size = rect.size
	image.pivot_offset = rect.size / 2.0
	image.rotation_degrees = degrees
	image.modulate = tint
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

# A light beam (glow + core) between two points, for the beam and prism pictures.
func _beam(parent: Control, from: Vector2, to: Vector2, colors: Array) -> void:
	for k in range(2):
		var line := Line2D.new()
		line.points = PackedVector2Array([from, to])
		line.width = 16.0 if k == 0 else 5.0
		line.default_color = colors[k]
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		parent.add_child(line)

# Tapping an item: owned skins are worn at once; anything else opens a
# "Buy this?" window with a big picture, a short definition and the price.
func _shop_tap(id: String, balance: Label) -> void:
	var shop: Node = Aura.shop
	if shop.is_owned(id):
		shop.equip(id)
		Aura.sound("pop")
		show_shop()
		return
	var item: Dictionary = shop.ITEMS[id]
	var shade := ColorRect.new()
	shade.color = Color(0.15, 0.12, 0.22, 0.6)
	shade.position = Vector2(-640, 0)
	shade.size = Vector2(2560, 800)
	add_child(shade)
	var box := Aura.panel(shade, Rect2(1020, 110, 520, 590))
	Aura.pop_in(box)
	Aura.sound("whoosh")
	var picture := _item_picture(id)
	picture.position = Vector2(110, 10)
	box.add_child(picture)
	var title := Aura.label(box, item.name, Rect2(20, 268, 480, 48), 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var about := Aura.paragraph(box, item.desc, Rect2(30, 320, 460, 90), 24)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var price := Aura.shard_chip(box, Vector2(172, 412), shop.price(id))
	price.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	Aura.icon_button(box, "close", Rect2(100, 480, 96, 96), shade.queue_free)
	var buy := Aura.icon_button(box, "check", Rect2(324, 480, 96, 96), func(): _buy(id, picture, shade, balance), true)
	if not shop.can_buy(id):
		buy.disabled = true
		price.add_theme_color_override("font_color", Color("b04a4a"))

# Buying: the item flies up into the aura bank (top right) and the balance counts down.
func _buy(id: String, picture: Control, shade: Control, balance: Label) -> void:
	var shop: Node = Aura.shop
	var before: int = shop.coins
	if not shop.buy(id):
		Aura.sound("error")
		Aura.shake(balance.get_parent())
		return
	Aura.sound("coins")
	Aura.haptic(30)
	var flyer: Control = picture.duplicate()
	add_child(flyer)
	flyer.global_position = picture.global_position
	flyer.pivot_offset = flyer.size / 2.0
	shade.queue_free()
	var bank: Vector2 = balance.get_parent().global_position + Vector2(10, -20)
	var fly := flyer.create_tween().set_parallel()
	fly.tween_property(flyer, "global_position", bank - flyer.size * 0.15, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.tween_property(flyer, "scale", Vector2.ONE * 0.25, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.chain().tween_callback(func():
		flyer.queue_free()
		Aura.sound("pop")
		show_shop()
		for node in content.get_children():
			if node is Panel and node.position == Vector2(1034, 40):
				Aura.count_up(node.get_child(1), before, shop.coins)
				Aura.press(node))

# Chapter select: a constellation. Each chapter is a star on a path of light;
# finished links glow gold, the next chapter pulses, locked ones stay dim.
const MAP := [Vector2(150, 540), Vector2(290, 380), Vector2(450, 500), Vector2(600, 330), Vector2(760, 470), Vector2(910, 300), Vector2(1060, 440), Vector2(1170, 250)]

func show_chapters() -> void:
	clear()
	character.visible = false
	var total := Aura.label(content, "★ %d / %d" % [Aura.total_stars(), Aura.LEVEL_COUNT * 3], Rect2(940, 44, 280, 50), 32, Color("7d5f2a"))
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var path := Line2D.new()
	path.width = 5
	path.default_color = Color(1, 1, 1, 0.45)
	path.joint_mode = Line2D.LINE_JOINT_ROUND
	for point in MAP: path.add_point(point)
	content.add_child(path)
	var lit := Line2D.new()
	lit.width = 7
	lit.default_color = Color("e2b65c")
	lit.joint_mode = Line2D.LINE_JOINT_ROUND
	for i in range(mini(Aura.unlocked, Aura.LEVEL_COUNT)): lit.add_point(MAP[i])
	content.add_child(lit)
	for i in range(Aura.LEVEL_COUNT):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%d.json" % (i + 1)))
		var open := i < Aura.unlocked
		var node := _pill(str(i + 1), Rect2(MAP[i] - Vector2(52, 52), Vector2(104, 104)), func(): _chapter_tap(i), 40, open and int(Aura.best[i]) == 0)
		if not open:
			node.add_theme_color_override("font_color", Color("8b8296"))
			for state in ["normal", "hover", "pressed", "hover_pressed"]:
				(node.get_theme_stylebox(state) as StyleBoxFlat).bg_color = Color("e6e1ea")
		else:
			for state in ["normal", "hover"]:
				(node.get_theme_stylebox(state) as StyleBoxFlat).bg_color = Color("fbf7f0")
			if int(Aura.best[i]) == 0: _glow(node)
		var stars := Aura.label(content, ("★".repeat(int(Aura.best[i])) + "☆".repeat(3 - int(Aura.best[i]))) if open else "", Rect2(MAP[i].x - 80, MAP[i].y + 56, 160, 34), 26, Color("7d5f2a"))
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Aura.icon_button(content, "back", Rect2(40, 666, 84, 84), show_home)
	Aura.icon_button(content, "reset", Rect2(140, 666, 84, 84), confirm_reset, false, "Reset progress")
	_stagger_in()

func _chapter_tap(i: int) -> void:
	if i < Aura.unlocked:
		start_level(i + 1)
		return
	Aura.sound("error")
	for node in content.get_children():
		if node is Button and node.text == str(i + 1): Aura.shake(node)

func confirm_reset() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.4)
	shade.position = Vector2(-640,0)
	shade.size = Vector2(2560,800)
	add_child(shade)
	var box := Aura.panel(shade,Rect2(1000,230,560,300))
	Aura.paragraph(box,"Reset all stars, aura and purchases?",Rect2(24,30,512,120),28).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	Aura.icon_button(box,"close",Rect2(110,176,96,96),shade.queue_free)
	Aura.icon_button(box,"check",Rect2(354,176,96,96),func():
		Aura.reset_progress()
		shade.queue_free()
		show_chapters())

func show_credits() -> void:
	clear()
	character.visible = false
	var box := Aura.panel(content,Rect2(70,40,1140,700))
	Aura.label(box,"AURA / MT-2402",Rect2(20,16,1000,50),36)
	Aura.paragraph(box,"Elmira Bukhanova — mechanics & level design\nKhalida Yerpan — interface & game flow\nDiana Zhumagali — visual & sound direction\n\nSounds: Freesound (CC0 / CC BY 4.0); authors and links in the README.\nMusic: made by us in Apple GarageBand (GarageBand licence).\nArt: made by our team in Canva; faces by Elizaveta Krasnoshchekova (with permission).\nEngine: Godot 4.7 (MIT). Fonts: Godot default; title in Cinzel (SIL OFL 1.1).\nAI tools used in development are listed in the README.\n\nInspired by Frieren, Monument Valley and Portal; no material from them is used.",Rect2(20,80,1090,500),25)
	Aura.icon_button(box,"back",Rect2(20,600,84,84),show_home)

func start_level(number: int) -> void:
	Aura.start_level(number)
