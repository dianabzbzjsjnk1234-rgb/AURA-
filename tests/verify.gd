extends Node
var checks := 0
var backups: Dictionary = {}
func check(value: bool, description: String) -> void:
	if not value:
		push_error("FAIL: "+description)
		restore_saves()
		get_tree().quit(1)
		assert(value,description)
	checks += 1
	print("PASS: "+description)
# Puts the player's real save files back (also after a failed check).
func restore_saves() -> void:
	for path in backups:
		if backups[path] == null: DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path,FileAccess.WRITE)
			file.store_buffer(backups[path])
			file.close()
	Aura.best.fill(0)
	Aura.load_progress()
func spawn_level(number: int) -> Node:
	Aura.current_level = number
	var level=load(Aura.GAME_SCENE).instantiate()
	add_child(level)
	return level
func play_solution(level: Node) -> void:
	for item in level.level_data.solution:
		level.board_tap(level.grid_center(int(item[0]),int(item[1])))
		level.rotate_selected(float(item[2]))
# Phone readability rules from the Assignment 2 feedback.
func check_readable(root: Node, name: String) -> void:
	var ok := true
	for node in root.find_children("*", "Button", true, false):
		var b: Button = node
		if b.size.y < 64 or b.get_theme_font_size("font_size") < 24 or b.get_global_rect().end.y > 756:
			ok = false
			print("  small or low button: ", b.text, " ", b.get_global_rect(), " font ", b.get_theme_font_size("font_size"))
	for node in root.find_children("*", "Label", true, false):
		var l: Label = node
		if l.get_theme_font_size("font_size") < 22 or l.get_theme_color("font_color") == Aura.PURPLE:
			ok = false
			print("  small or purple text: ", l.text.left(40))
	check(ok, name + ": buttons >= 64 px, text >= 22 px, no purple text, controls above home indicator")

func _ready() -> void:
	await get_tree().process_frame
	TranslationServer.set_locale("en")  # the checks below read English texts
	for path in ["user://aura_progress.cfg","user://creative.json","user://perf_log.csv"]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	Aura.reset_progress()
	var one=spawn_level(1)
	check(one.target_stars.size()==1,"chapter 1 loads")
	await get_tree().process_frame
	check_readable(one.ui, "chapter 1 HUD")
	var text_buttons := 0
	for node in one.ui.find_children("*","Button",true,false):
		if not node.text.is_empty(): text_buttons += 1
	check(text_buttons==0,"in-game controls are icons, not long text buttons (Assignment 3 feedback)")
	check(one.BOARD.x*one.BOARD.y/(Aura.DESIGN.x*Aura.DESIGN.y)>0.7 and one.GRID_SIZE>=88 and one.GRID_WIDTH==14 and one.GRID_HEIGHT==7,"14 x 7 board with 88 px cells fills most of the screen")
	var pause_rect := Rect2()
	for node in one.ui.find_children("*","Button",true,false):
		if node.icon and node.icon.resource_path.ends_with("pause.svg"): pause_rect=node.get_global_rect()
	check(pause_rect.position.y<20 and pause_rect.position.x<20,"pause button sits in the top-left corner")
	var readme := FileAccess.get_file_as_string("res://README.md")
	for key in Aura.SOUNDS:
		check(Aura.voices[key].stream != null and readme.contains(Aura.SOUNDS[key].get_file()), "sound '%s' loads and is credited in the README" % key)
	check(Aura.has_music() and Aura.music.playing, "background music loads and plays")
	# Crystal tools pop up next to the selected crystal, inside the screen.
	one.board_tap(one.grid_center(13,6))
	var crystal_menu: Control = one.ui.mirror_menu
	var screen := Rect2(one.ui.left_edge-1, 0, one.ui.right_edge-one.ui.left_edge+2, Aura.DESIGN.y)
	check(crystal_menu.visible and screen.encloses(Rect2(crystal_menu.position, crystal_menu.size)), "crystal tools appear next to a corner crystal and stay on screen")
	var cell_rect := Rect2(one.ORIGIN+Vector2(13,6)*one.GRID_SIZE, Vector2.ONE*one.GRID_SIZE)
	check(not Rect2(crystal_menu.position, crystal_menu.size).intersects(cell_rect), "crystal tools do not cover the crystal itself")
	one.board_tap(one.grid_center(13,6))
	check(not crystal_menu.visible and one.selected_mirror==-1, "tapping the selected crystal again closes its tools")
	var side_buttons := 0
	for node in one.ui.find_children("*","Button",true,false):
		if node.get_parent()==one.ui and node.position.y>200: side_buttons += 1
	check(side_buttons==0, "no side buttons over the board (Assignment 4 feedback)")
	one.reset_level()
	one.history.clear()
	Aura.show_fps = true
	Aura.perf.refresh_visibility()
	check(not Aura.perf.overlay.get_global_rect().intersects(pause_rect), "FPS counter does not cover the pause button (Assignment 4 feedback)")
	Aura.show_fps = false
	Aura.perf.refresh_visibility()
	one.show_hint()
	check(one.hint_cells.size()==1 and Vector2i(one.hint_cells[0][0],one.hint_cells[0][1])==Vector2i(6,4), "first hint highlights the first solution cell")
	one.board_tap(one.grid_center(8,3))
	one.rotate_selected(45)
	one.undo_mirror()
	check(one.mirrors.size()==1 and one.mirrors[0].rotation==0,"undo rotation restores angle")
	one.board_tap(one.grid_center(3,3))
	check(one.mirrors.size()==1 and one.message.begins_with("No crystals left"),"mirror limit stops extra placements")
	one.delete_selected()
	one.undo_mirror()
	check(one.mirrors.size()==1 and one.selected_mirror==0,"undo deletion restores mirror and selection")
	one.reset_level()
	one.undo_mirror()
	check(one.mirrors.size()==1,"undo reset restores layout")
	one.reset_level()
	one.walls.assign([Vector2i(6,4)])
	one._update_board()
	check(is_equal_approx(one.ray_segments[0].to.y, 4.0*one.GRID_SIZE),"a wall stops the beam at its edge")
	one.walls.clear()
	one.board_tap(one.grid_center(6,4))
	one.rotate_selected(45)
	check(one.level_won and one.stars_hit==1,"chapter 1 solved through gameplay commands")
	await get_tree().create_timer(0.3).timeout
	check(one.mirror_pieces.size()==1 and is_equal_approx(fposmod(one.mirror_pieces[0].rotation_degrees,180.0),45.0) and one.star_pieces[0].lit, "board pieces follow the puzzle state (turn animates to 45°)")
	check(Aura.best[0]==2, "a hint costs one reward star")
	check(Aura.unlocked==2,"chapter 2 unlocks")
	check(one.ui.success == null, "completion panel waits so the lit star stays visible")
	await get_tree().create_timer(one.SUCCESS_DELAY + 0.2).timeout
	check_readable(one.ui.success, "completion panel")
	var layout=one.mirrors.duplicate(true)
	one.rotate_selected(45)
	one.delete_selected()
	one.undo_mirror()
	one.reset_level()
	one.board_tap(one.grid_center(2,2))
	check(one.mirrors==layout and one.level_won,"all board mutations blocked after victory")
	one.queue_free()
	await get_tree().process_frame
	# Every chapter is solvable with its stored solution (the minimum found by
	# tools/level_solver.py) and that solution earns three stars.
	for n in range(2, Aura.LEVEL_COUNT + 1):
		var level=spawn_level(n)
		var before_win:bool=level.level_won
		play_solution(level)
		check(not before_win and level.level_won and level.rating()==3 and Aura.best[n-1]==3, "chapter %d: solved with %d mirrors, 3 stars" % [n, level.level_data.solution.size()])
		level.queue_free()
		await get_tree().process_frame
	check(Aura.unlocked==Aura.LEVEL_COUNT and Aura.total_stars()==Aura.LEVEL_COUNT*3-1,"all chapters unlock in order and stars add up")
	var two=spawn_level(2)
	var extra:Array=[[13,6]]
	two.board_tap(two.grid_center(extra[0][0],extra[0][1]))
	play_solution(two)
	check(two.level_won and two.rating()==2,"one extra mirror costs one reward star")
	check(Aura.best[1]==3,"a weaker run keeps the chapter's best result")
	two.queue_free()
	await get_tree().process_frame
	var three=spawn_level(3)
	three.show_hint()
	three.show_hint()
	check(three.hints_used==1 and three.ui.modal!=null,"after the free hint, the hint button offers the demo ad")
	three.ui._play_ad()
	var close: Button = null
	for node in three.ui.modal.find_children("*","Button",true,false): close = node
	check(close.disabled,"demo ad reward is locked during the countdown")
	await get_tree().create_timer(three.ui.AD_SECONDS + 0.4).timeout
	check(not close.disabled,"demo ad reward unlocks after the countdown")
	close.pressed.emit()
	check(three.hints_used==2 and three.hint_cells.size()==three.level_data.solution.size() and three.ui.modal==null,"watching the ad grants a hint that shows every mirror cell")
	three.ui.open_pause()
	await get_tree().process_frame
	check(three.blocked and three.ui.modal != null, "pause opens and blocks the board")
	check_readable(three.ui.modal, "pause menu")
	var settings = Aura.open_settings(three.ui)
	await get_tree().process_frame
	check_readable(settings, "settings")
	settings.queue_free()
	three.ui.resume()
	check(not three.blocked and three.ui.modal == null, "resume unblocks the board")
	three.ui._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(three.ui.modal != null, "leaving the app opens the pause menu")
	three.ui.resume()
	Aura.perf.start_test(1.0)
	await get_tree().create_timer(1.4).timeout
	var result:Dictionary=Aura.perf.summary()
	check(Aura.perf.result_box!=null and result.avg_fps>0 and result.frames>0 and FileAccess.file_exists("user://perf_log.csv"),"performance test records FPS, frame time and memory")
	Aura.perf.result_box.queue_free()
	Aura.perf.result_box=null
	three.queue_free()
	await get_tree().process_frame
	Aura.save_progress()
	Aura.best.fill(0)
	Aura.unlocked=1
	Aura.load_progress()
	check(Aura.best[0]==2 and Aura.best[7]==3 and Aura.unlocked==Aura.LEVEL_COUNT,"saved rewards reload")
	var old := ConfigFile.new()
	old.set_value("progress","stars_0",3)
	old.save("user://aura_progress.cfg")
	Aura.best.fill(0)
	Aura.load_progress()
	check(Aura.best[0]==3 and Aura.unlocked==2,"Assignment 3 saves are migrated")
	# Economy: shards for new stars only, daily light once a day, shop items.
	var shop: Node = Aura.shop
	shop.reset()
	check(shop.reward_for(0,3)==20 and shop.reward_for(2,3)==5 and shop.reward_for(3,3)==0,"shards only for new stars and the first clear (no farming by replays)")
	check(shop.claim_daily("2026-11-20")==10 and shop.claim_daily("2026-11-20")==0 and shop.claim_daily("2026-11-21")==10 and shop.coins==20,"daily light gives aura once per day")
	shop.earn(20)
	check(not shop.buy("crystal_gold") and shop.coins==40,"cannot buy without enough aura")
	check(shop.buy("hint") and shop.buy("crystal_rose")==false and shop.coins==10 and shop.inventory.hint==1,"buying a hint spends aura")
	shop.earn(600)
	check(shop.buy("crystal_rose") and shop.crystal_skin=="crystal_rose" and not shop.can_buy("crystal_rose"),"a crystal skin is bought once and equipped")
	check(shop.buy("beam_aurora") and shop.beam_colors()==shop.ITEMS.beam_aurora.colors,"a beam skin changes the beam colours")
	check(shop.buy("mirror") and shop.inventory.mirror==1,"extra crystals can be bought")
	Aura.save_progress()
	shop.reset()
	Aura.load_progress()
	check(shop.coins==shop.coins and shop.inventory.hint==1 and shop.inventory.mirror==1 and shop.crystal_skin=="crystal_rose" and shop.is_owned("beam_aurora"),"shards, items and skins are saved")
	var four=spawn_level(2)
	four.show_hint()
	four.show_hint()
	check(four.hints_used==2 and shop.inventory.hint==0 and four.ui.modal==null,"a bought hint is used before the ad is offered")
	check(four.mirror_pieces.size()==0 or four.mirror_pieces[0].get_node("Crystal").modulate==shop.crystal_tint(),"crystal skin applies to placed crystals")
	for c in range(14*7):
		if four.crystal_count()>=int(four.max_mirrors): break
		var cell:=Vector2i(c%14,c/14)
		if four.walls.has(cell) or four.star_at(four.grid_center(cell.x,cell.y))>=0 or four.grid_center(cell.x,cell.y)==four.light_source_pos: continue
		four.board_tap(four.grid_center(cell.x,cell.y))
		four.selected_mirror=-1
	var limit:int=four.max_mirrors
	four.board_tap(four.grid_center(13,6) if four.find_mirror_at(13,6)<0 else four.grid_center(12,6))
	check(four.ui.modal!=null,"at the crystal limit an owned extra crystal is offered")
	four.ui.resume()
	four.use_extra_mirror()
	check(four.max_mirrors==limit+1 and shop.inventory.mirror==0,"using an extra crystal raises the limit by one")
	four.queue_free()
	await get_tree().process_frame
	# Prism: splits the beam into two perpendicular beams.
	shop.inventory.prism=1
	var ps=spawn_level(0)
	ps.target_stars.clear()
	ps.target_stars.append({"pos":ps.grid_center(2,4),"hit":false})
	ps.target_stars.append({"pos":ps.grid_center(12,4),"hit":false})
	ps.place_prism=true
	ps.board_tap(ps.grid_center(7,4))
	check(ps.prism_count()==1 and ps.crystal_count()==0 and ps.stars_hit==2 and ps.level_won,"a prism splits the beam and lights stars on both sides")
	ps.rotate_selected(45)
	check(float(ps.mirrors[0].rotation)==0.0 and not ps.ui.rotate_left.visible,"a prism cannot be turned; only Delete is offered")
	check(ps.rating()<=2,"a chapter won with a prism gives at most 2 stars")
	ps.place_prism=true
	ps.board_tap(ps.grid_center(5,6))
	check(ps.prism_count()==1 and ps.mirrors.size()==1 and not ps.place_prism,"cannot place more prisms than owned (nothing is placed)")
	ps.queue_free()
	await get_tree().process_frame
	shop.inventory.prism=0
	var shop_menu=load("res://scenes/main_menu.tscn").instantiate()
	add_child(shop_menu)
	shop_menu.show_shop()
	await get_tree().process_frame
	check_readable(shop_menu, "shop screen")
	shop_menu.queue_free()
	await get_tree().process_frame
	var studio=spawn_level(0)
	studio.tool="star"
	studio.board_tap(studio.grid_center(2,2))
	check(studio.target_stars.size()==2,"creative target placement")
	studio.tool="source"
	studio.board_tap(studio.grid_center(3,1))
	check(studio.light_source_pos==studio.grid_center(3,1),"creative source movement")
	studio.save_layout()
	studio.tool="star"
	studio.board_tap(studio.grid_center(2,2))
	studio.load_layout()
	check(studio.target_stars.size()==2,"creative save/load")
	studio.ui.open_pause()
	var before=studio.mirrors.size()
	studio.tool="mirror"
	studio.board_tap(studio.grid_center(5,5))
	check(studio.mirrors.size()==before,"pause blocks board input")
	studio.queue_free()
	await get_tree().process_frame
	var menu=load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	menu.show_chapters()
	menu.show_credits()
	await get_tree().process_frame
	await get_tree().process_frame
	var credits_panel = menu.content.get_child(0)
	var credits_text = credits_panel.get_child(1)
	check(credits_text.position.x + credits_text.size.x <= credits_panel.size.x - 30, "credits text stays within panel width")
	check(credits_text.position.y + credits_text.get_minimum_size().y <= 590, "credits text fits above Back button")
	menu.show_home()
	check(menu.content.get_child_count()>5,"all menu screens construct")
	await get_tree().process_frame
	check_readable(menu, "main menu")
	var first:String=menu.character.emotion
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	for node in menu.content.get_children():
		if node.get_class()=="Control" and node.size==Vector2(300,440): node.gui_input.emit(tap)
	var second:String=menu.character.emotion
	menu.character.next_emotion()
	check(second!=first and menu.character.emotion!=second and menu.character.get_node("Body").animation==menu.character.emotion,"tapping the lightkeeper changes her emotion (%s -> %s -> %s)" % [first,second,menu.character.emotion])
	menu.show_chapters()
	await get_tree().process_frame
	check_readable(menu, "chapter select")
	menu.queue_free()
	await get_tree().process_frame
	# Story episodes unlock with chapters and are remembered once watched.
	Aura.story.reset()
	check(Aura.story.count()==Aura.LEVEL_COUNT,"one story episode per chapter")
	Aura.best.fill(0)
	Aura.best[0]=3
	Aura.best[1]=2
	check(Aura.story.is_unlocked(1) and not Aura.story.is_unlocked(2) and Aura.story.newest_unread()==1,"finished chapters unlock their episodes, newest first")
	var story_menu=load("res://scenes/main_menu.tscn").instantiate()
	add_child(story_menu)
	await get_tree().process_frame
	story_menu._open_story(1)
	var viewer: Node = story_menu.get_child(story_menu.get_child_count()-1)
	check(viewer.line==0 and viewer.typing and viewer.name_tag.text=="","an episode opens by typing its first (narrator) line")
	viewer._advance()
	check(not viewer.typing and viewer.text.visible_characters==-1,"a tap shows the whole typing line at once")
	viewer._advance()
	check(viewer.name_tag.text=="Frieren" and viewer.star.modulate==Color.WHITE,"the lost star speaks with its name tag and lights up")
	for k in range(20):
		if viewer.choosing: break
		viewer._advance()
	check(viewer.choosing and viewer.choice_box.get_child_count()==2,"the episode ends with a choice of two answers")
	var coins_before:int=Aura.shop.coins
	viewer.choose(1)
	check(Aura.shop.coins==coins_before+5 and Aura.story.choices[1]==1 and viewer.character.emotion=="idle","the chosen answer changes her last line and gives shards")
	var reward_card:=false
	for node in viewer.root.get_children():
		if node is Panel:
			for child in node.get_children():
				if child is Label and child.text.contains("Aura is the light"): reward_card=true
	check(reward_card,"the story reward shows sparkles and says what aura is")
	check(Aura.story.choose(1,0)==0 and Aura.shop.coins==coins_before+5,"an episode's choice reward is given only once")
	viewer._advance()
	viewer._advance()
	check(Aura.story.is_read(1) and Aura.story.newest_unread()==0,"watching an episode to the end marks it as watched")
	Aura.save_progress()
	Aura.story.reset()
	Aura.load_progress()
	check(Aura.story.is_read(1) and Aura.story.choices.get(1,-1)==0,"watched episodes and choices are saved")
	story_menu.show_story()
	await get_tree().process_frame
	check_readable(story_menu, "story list")
	story_menu.queue_free()
	await get_tree().process_frame
	# Captions: every picture button has a name (long press), the first menu visits show them.
	var hint_menu=load("res://scenes/main_menu.tscn").instantiate()
	Aura.menu_visits=0
	add_child(hint_menu)
	await get_tree().process_frame
	var named:=0
	var buttons:=0
	for node in hint_menu.content.get_children():
		if node is Button and node.icon:
			buttons+=1
			if node.has_meta("hint"): named+=1
	var captions:=0
	for node in hint_menu.content.get_children():
		if node is Label and node.get_theme_color("font_color")==Aura.MUTED and node.autowrap_mode!=TextServer.AUTOWRAP_OFF: captions+=1
	check(buttons>0 and named==buttons and captions>=named,"every picture button has a name and the first visit shows captions")
	var some:Button=null
	for node in hint_menu.content.get_children():
		if node is Button and node.has_meta("hint"): some=node
	Aura.show_hint(some)
	var bubble_ok:=false
	for child in some.get_children():
		if child is Label and child.text==TranslationServer.translate(str(some.get_meta("hint"))): bubble_ok=true
	check(bubble_ok,"a long press shows the button's name")
	hint_menu.queue_free()
	await get_tree().process_frame
	# Prologue: shown once before the first chapter, then remembered.
	Aura.story.reset()
	check(not Aura.story.intro_seen and Aura.story.episode(-1).lines.size()>3,"a prologue introduces Lira and Frieren")
	var intro_menu=load("res://scenes/main_menu.tscn").instantiate()
	add_child(intro_menu)
	await get_tree().process_frame
	intro_menu._open_story(-1, func(): pass)
	var intro_view: Node = intro_menu.get_child(intro_menu.get_child_count()-1)
	for k in range(30):
		if not is_instance_valid(intro_view) or intro_view.is_queued_for_deletion(): break
		intro_view._advance()
	check(Aura.story.intro_seen,"the prologue is remembered after it is watched")
	intro_menu.queue_free()
	await get_tree().process_frame
	# Languages: English, Russian and Kazakh, chosen in Settings and saved.
	var langs_ok := true
	for lang in ["ru","kk"]:
		TranslationServer.set_locale(lang)
		langs_ok = langs_ok and tr("No crystals left.")!="No crystals left." and Aura.story.title(0)!=Aura.story.episodes[0].title
	TranslationServer.set_locale("en")
	check(langs_ok and tr("No crystals left.")=="No crystals left.","the interface and story are translated to Russian and Kazakh")
	Aura.language="kk"
	Aura.save_progress()
	Aura.language=""
	Aura.load_progress()
	Aura.apply_language()
	check(Aura.current_language()=="kk","the chosen language is saved and applied")
	var lang_old=spawn_level(1)
	var lang_cell=lang_old.level_data.solution[0]
	lang_old.board_tap(lang_old.grid_center(int(lang_cell[0]),int(lang_cell[1])))
	var lang_undo:int=lang_old.history.size()
	Aura.carry_board=lang_old.board_state()
	lang_old.free()
	var lang_new=spawn_level(1)
	check(lang_new.mirrors.size()==1 and lang_new.history.size()==lang_undo,"changing the language mid-chapter keeps the placed crystals and undo")
	lang_new.free()
	var old_cfg := ConfigFile.new()
	old_cfg.set_value("settings","reduced_motion",true)
	old_cfg.save("user://aura_progress.cfg")
	Aura.load_progress()
	check(not Aura.reduced_motion,"saves from the old Settings get Reduce animation switched off once")
	Aura.reduced_motion=true
	Aura.save_progress()
	Aura.load_progress()
	check(Aura.reduced_motion,"after that, Reduce animation is kept as chosen")
	Aura.reduced_motion=false
	Aura.language="en"
	Aura.apply_language()
	var csv := FileAccess.open("res://localization/aura.csv",FileAccess.READ)
	var empty_cells := 0
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size()==4:
			for cell in row: if cell.strip_edges().is_empty(): empty_cells += 1
	check(empty_cells==0,"every phrase has English, Russian and Kazakh text")
	restore_saves()
	print("AURA VERIFICATION COMPLETE: %d checks" % checks)
	if Aura.music: Aura.music.stop()
	for voice in Aura.voices.values(): voice.stop()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
