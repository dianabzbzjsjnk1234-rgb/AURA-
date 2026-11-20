extends Node
# Zero-bug audit: opens every screen in English, Russian and Kazakh and reports
# text that does not fit its box, buttons that overlap and controls off screen.
var problems: Array[String] = []
var screen := ""

func audit(root: Node) -> void:
	var rects: Array = []
	for node in root.find_children("*", "Control", true, false):
		var c: Control = node
		if not c.is_visible_in_tree() or c.modulate.a < 0.05: continue
		var r := c.get_global_rect()
		if c is Label or c is Button:
			var text: String = TranslationServer.translate(c.text) if c.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else c.text
			if not text.is_empty() and c.size.x > 0:
				var font: Font = c.get_theme_font("font")
				var size: int = c.get_theme_font_size("font_size")
				var wraps: bool = c.autowrap_mode != TextServer.AUTOWRAP_OFF
				var room := c.size.x - (24.0 if c is Button else 0.0)
				if wraps:
					var lines := 0
					for part in text.split("\n"):
						for word in part.split(" "):
							if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room + 2: problems.append("%s | word too wide: '%s' in %s" % [screen, word, c.name])
					var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, room, size).y
					if h > c.size.y + 8 and c is Label and c.get_parent() is Control and r.end.y + (h - c.size.y) > (c.get_parent() as Control).get_global_rect().end.y + 4 and not (c.get_parent() is CanvasLayer):
						problems.append("%s | text taller than its box: '%s'" % [screen, text.left(40)])
				else:
					if not "\n" in text and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room + 2 and not c.clip_text:
						problems.append("%s | text too wide (%d px > %d): '%s'" % [screen, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, room, text.left(40)])
		if c is Button and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			for other in rects:
				if other[0].get_parent() == c.get_parent() and other[1].intersects(r.grow(-4)):
					problems.append("%s | buttons overlap: %s and %s" % [screen, other[0].name, c.name])
			rects.append([c, r])

func shot_and_audit(name: String, root: Node) -> void:
	await get_tree().create_timer(0.9).timeout
	screen = "%s/%s" % [TranslationServer.get_locale(), name]
	audit(root)

func _ready() -> void:
	var saved := FileAccess.get_file_as_bytes(Aura.SAVE_PATH) if FileAccess.file_exists(Aura.SAVE_PATH) else PackedByteArray()
	for lang in ["en", "ru", "kk"]:
		TranslationServer.set_locale(lang)
		Aura.reset_progress()
		for i in range(5): Aura.complete(i + 1, 3 - i % 3)
		Aura.shop.earn(300)
		Aura.menu_visits = 0
		var menu = load("res://scenes/main_menu.tscn").instantiate()
		add_child(menu)
		await shot_and_audit("home", menu)
		menu.show_chapters(); await shot_and_audit("chapters", menu)
		for tab in ["Boosts", "Crystals", "Beams"]:
			menu.shop_tab = tab; menu.show_shop(); await shot_and_audit("shop " + tab, menu)
		for id in ["hint", "prism", "crystal_gold"]:
			menu.shop_tab = "Boosts" if id != "crystal_gold" else "Crystals"; menu.show_shop()
			var bal: Label = null
			for node in menu.content.get_children():
				if node is Panel and node.position == Vector2(1034, 40): bal = node.get_child(1)
			menu._shop_tap(id, bal); await shot_and_audit("buy " + id, menu)
			menu.get_child(menu.get_child_count() - 1).queue_free()
		menu.show_story(); await shot_and_audit("story list", menu)
		menu.show_credits(); await shot_and_audit("credits", menu)
		menu.show_home()
		Aura.open_settings(menu); await shot_and_audit("settings", menu)
		menu.get_child(menu.get_child_count() - 1).queue_free()
		for ep in [-1, 0, 7]:
			menu._open_story(ep, func(): pass)
			var v: Node = menu.get_child(menu.get_child_count() - 1)
			for k in range(12):
				if not is_instance_valid(v) or v.is_queued_for_deletion() or v.choosing: break
				await shot_and_audit("episode %d line" % ep, menu)
				if not is_instance_valid(v): break
				v._advance()
				if is_instance_valid(v) and not v.is_queued_for_deletion() and not v.choosing: v._advance()
			if is_instance_valid(v) and not v.is_queued_for_deletion() and v.choosing:
				await shot_and_audit("episode %d choice" % ep, menu)
				v.choose(0); await shot_and_audit("episode %d reward" % ep, menu)
			if is_instance_valid(v) and not v.is_queued_for_deletion(): v.queue_free()
		menu.queue_free()
		await get_tree().process_frame
		for n in [1, 5, 8]:
			Aura.unlocked = 8
			Aura.current_level = n
			var l = load(Aura.GAME_SCENE).instantiate()
			add_child(l)
			await shot_and_audit("chapter %d start" % n, l)
			var sol: Array = l.level_data.solution
			l.board_tap(l.grid_center(sol[0][0], sol[0][1]))
			await shot_and_audit("chapter %d crystal menu" % n, l)
			l.ui.open_pause(); await shot_and_audit("chapter %d pause" % n, l)
			l.ui.resume()
			l.reset_level()
			for s in sol:
				l.board_tap(l.grid_center(s[0], s[1])); l.rotate_selected(s[2])
			await get_tree().create_timer(l.SUCCESS_DELAY + 0.3).timeout
			await shot_and_audit("chapter %d win" % n, l)
			l.queue_free()
			await get_tree().process_frame
		var studio_level = null
		Aura.current_level = 0
		studio_level = load(Aura.GAME_SCENE).instantiate()
		add_child(studio_level)
		await shot_and_audit("studio", studio_level)
		studio_level.queue_free()
		await get_tree().process_frame
	var unique := {}
	for p in problems: unique[p] = true
	print("UI AUDIT: %d problems" % unique.size())
	for p in unique: print("  ", p)
	var file := FileAccess.open(Aura.SAVE_PATH, FileAccess.WRITE)
	if saved.size() > 0: file.store_buffer(saved)
	file.close()
	if saved.size() == 0: DirAccess.remove_absolute(Aura.SAVE_PATH)
	get_tree().quit()
