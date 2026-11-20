extends Node
# Full playthrough, the way a player goes: menu → Play → prologue → chapter 1 →
# win → Play → episode 1 (choice, reward) → chapter 2 → ... → chapter 8 → final
# episode → main menu. It survives scene changes by living under the tree root.
var saved := PackedByteArray()
var failures: Array[String] = []

func _ready() -> void:
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		var driver := Node.new()
		driver.set_script(get_script())
		driver.name = "PlaythroughDriver"
		get_tree().root.add_child.call_deferred(driver)
		return
	run.call_deferred()

func expect(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + what)
	if not ok: failures.append(what)

func scene() -> Node:
	return get_tree().current_scene

func wait_for(cond: Callable, seconds: float = 6.0) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call(): return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()

func run() -> void:
	saved = FileAccess.get_file_as_bytes(Aura.SAVE_PATH) if FileAccess.file_exists(Aura.SAVE_PATH) else PackedByteArray()
	TranslationServer.set_locale("en")
	Aura.reset_progress()
	Aura.menu_visits = 5
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await wait_for(func(): return scene() != null and scene().name == "MainMenu")
	expect(scene().name == "MainMenu", "the game opens on the main menu")
	scene()._play()
	var viewer: Node = scene().get_child(scene().get_child_count() - 1)
	expect(viewer.has_method("_advance") and viewer.index == -1, "Play opens the prologue first")
	while is_instance_valid(viewer) and not viewer.is_queued_for_deletion():
		viewer._advance()
		await get_tree().process_frame
	for n in range(1, Aura.LEVEL_COUNT + 1):
		var ok := await wait_for(func(): return scene() != null and "level_number" in scene() and scene().level_number == n and scene().ui != null)
		expect(ok, "chapter %d opens" % n)
		if not ok: break
		var level: Node = scene()
		for s in level.level_data.solution:
			level.board_tap(level.grid_center(s[0], s[1]))
			level.rotate_selected(s[2])
		expect(level.level_won and level.rating() == 3, "chapter %d solved with 3 stars" % n)
		await wait_for(func(): return level.ui.success != null, 3.0)
		expect(level.ui.success != null, "chapter %d shows the win panel" % n)
		level.ui.continue_journey()
		var story: Node = level.ui.get_child(level.ui.get_child_count() - 1)
		expect(story.has_method("_advance") and story.index == n - 1, "episode %d plays after chapter %d" % [n, n])
		var guard := 0
		while is_instance_valid(story) and not story.is_queued_for_deletion() and guard < 60:
			if story.choosing: story.choose(0)
			else: story._advance()
			await get_tree().process_frame
			guard += 1
		expect(Aura.story.is_read(n - 1), "episode %d is marked as watched" % n)
	var home := await wait_for(func(): return scene() != null and scene().name == "MainMenu")
	expect(home, "after the last chapter the game returns to the main menu")
	expect(Aura.total_stars() == Aura.LEVEL_COUNT * 3 and Aura.story.intro_seen and Aura.story.newest_unread() == -1, "all stars, the prologue and every episode are done")
	expect(Aura.shop.coins == Aura.LEVEL_COUNT * (3 * Aura.shop.STAR_REWARD + Aura.shop.FIRST_CLEAR_REWARD) + 7 * 5 + 10 + Aura.shop.DAILY_REWARD, "aura adds up: stars, first clears, story choices and the daily light")
	print("PLAYTHROUGH %s: %d problems" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	var file := FileAccess.open(Aura.SAVE_PATH, FileAccess.WRITE)
	if saved.size() > 0: file.store_buffer(saved)
	file.close()
	if saved.size() == 0: DirAccess.remove_absolute(Aura.SAVE_PATH)
	get_tree().quit(0 if failures.is_empty() else 1)
