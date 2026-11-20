extends Node
# Saves screenshots of the main screens (for the GDD and layout checks).
@export var out_dir := "/private/tmp/claude-501/-Users-elli-by-el-Desktop-AURA-Assignment3/5c5d3883-6efb-4ad0-80f9-99a7a261b932/scratchpad/shots4"
func shot(name: String) -> void:
	await get_tree().create_timer(0.9).timeout
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
func level(n: int) -> Node:
	Aura.current_level = n
	var l = load(Aura.GAME_SCENE).instantiate()
	add_child(l)
	return l
var saved: PackedByteArray
var had_save := false
func _ready() -> void:
	# Optional: -- --lang=ru / kk renders the screens in that language.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="): TranslationServer.set_locale(arg.trim_prefix("--lang="))
	had_save = FileAccess.file_exists(Aura.SAVE_PATH)
	if had_save: saved = FileAccess.get_file_as_bytes(Aura.SAVE_PATH)
	Aura.reset_progress()
	for i in range(Aura.LEVEL_COUNT - 2): Aura.complete(i + 1, 3 - i % 3)
	Aura.menu_visits = 0
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await shot("menu")
	menu.show_chapters()
	await shot("chapters")
	Aura.shop.earn(150)
	Aura.shop.buy("hint")
	Aura.shop.buy("crystal_rose")
	menu.show_shop()
	await shot("shop")
	for tab in ["Crystals", "Beams"]:
		menu.shop_tab = tab
		menu.show_shop()
		await shot("shop_" + tab.to_lower())
	menu.shop_tab = "Boosts"
	menu.show_shop()
	await get_tree().process_frame
	var bal: Label = null
	for node in menu.content.get_children():
		if node is Panel and node.position == Vector2(1034, 40): bal = node.get_child(1)
	menu._shop_tap("prism", bal)
	await shot("shop_confirm")
	menu.get_child(menu.get_child_count()-1).queue_free()
	menu._open_story(-1, func(): pass)
	var intro: Node = menu.get_child(menu.get_child_count()-1)
	for k in range(5): intro._advance()
	await shot("intro")
	intro.queue_free()
	menu.show_story()
	await shot("story")
	menu._open_story(3)
	var episode: Node = menu.get_child(menu.get_child_count()-1)
	episode._advance()
	episode._advance()
	await shot("episode")
	for k in range(10):
		if episode.choosing: break
		episode._advance()
	await shot("episode_choice")
	episode.choose(0)
	await get_tree().create_timer(0.35).timeout
	await shot("episode_reward")
	episode.queue_free()
	menu.queue_free()
	var l = level(5)
	var sol: Array = l.level_data.solution
	for i in range(sol.size() - 1):
		l.board_tap(l.grid_center(sol[i][0], sol[i][1]))
		l.rotate_selected(sol[i][2])
	await shot("gameplay")
	l.show_hint()
	await shot("hint")
	l.show_hint()
	await shot("ad_offer")
	l.ui._play_ad()
	await shot("ad")
	l.queue_free()
	Aura.shop.inventory.prism = 2
	var pr = level(0)
	pr.target_stars.clear()
	for c in [Vector2i(2,4), Vector2i(12,4)]: pr.target_stars.append({"pos":pr.grid_center(c.x,c.y),"hit":false})
	pr.place_prism = true
	pr.board_tap(pr.grid_center(7,4))
	await shot("prism")
	pr.queue_free()
	var w = level(6)
	for s in w.level_data.solution:
		w.board_tap(w.grid_center(s[0], s[1]))
		w.rotate_selected(s[2])
	await get_tree().create_timer(2.0).timeout
	await shot("win")
	w.ui.success.queue_free(); w.ui.success = null
	w.ui.open_pause()
	Aura.open_settings(w.ui)
	await shot("settings")
	# Put the player's real progress back.
	if had_save:
		var file := FileAccess.open(Aura.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(saved)
		file.close()
	else: DirAccess.remove_absolute(Aura.SAVE_PATH)
	get_tree().quit()
