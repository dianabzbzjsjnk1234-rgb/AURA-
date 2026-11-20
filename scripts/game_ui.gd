extends CanvasLayer
# Immersive phone HUD (Assignment 4): the board fills the screen and the
# controls are round icon buttons on this layer, pinned to the screen edges
# inside the safe area. Text is limited to small chips and short toasts.
const ICONS := "res://assets/ui/icons/%s.svg"
const AD_SECONDS := 5
var game: Node2D
var chips: Array[Label] = []
var toast: Label
var toast_tween: Tween
var last_message := ""
var mutations: Array[Button] = []
var rotate_left: Button
var rotate_right: Button
var remove_button: Button
var undo_button: Button
var hint_button: Button
var hint_badge: Label
var prism_button: Button
var prism_badge: Label
var success: Control
var modal: Control
# Pop-up next to the selected crystal (rotate left/right, delete). It replaces
# the side buttons, so nothing covers the board on any screen shape.
var mirror_menu: Control
var menu_cell := Vector2i(-1, -1)
var left_edge := 0.0
var right_edge := 0.0

func _ready() -> void:
	game=get_parent()
	offset.x=Aura.margin_x
	Aura.layout_changed.connect(func():offset.x=Aura.margin_x)
	var edge:=_safe_edges()
	var left:=edge.x
	var right:=edge.y
	left_edge=left
	right_edge=right
	var top:=_safe_top()
	# Top strip: pause in the top-left corner (players looked for it there),
	# then compact chips; hint on the right. All inside the safe area.
	_icon_button("pause",Rect2(left,top,80,80),open_pause)
	var cx:=left+96
	if game.level_number>0:
		chips.append(_chip(Vector2(cx,top),str(game.level_number)))
		chips.append(_chip(Vector2(cx+90,top),""))
		chips.append(_chip(Vector2(cx+250,top),""))
		# A small crystal picture in front of the crystal count.
		var gem:=TextureRect.new()
		gem.texture=load("res://assets/art/pieces/mirror.png")
		gem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		gem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gem.size=Vector2(44,44)
		gem.position=Vector2(cx+258,top+6)
		gem.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(gem)
	else:
		var pictures:Array=["res://assets/art/pieces/mirror.png","res://assets/art/pieces/star_lit.png","res://assets/art/pieces/sun.png"]
		var keys:Array=["mirror","star","source"]
		for i in range(3):
			var tool_button:=Aura.icon_button(self,pictures[i],Rect2(cx+i*92,top,80,80),func():
				game.tool=keys[i]
				refresh())
			tool_button.set_meta("tool",keys[i])
			mutations.append(tool_button)
		Aura.icon_button(self,"save",Rect2(cx+300,top,80,80),game.save_layout)
		Aura.icon_button(self,"load",Rect2(cx+392,top,80,80),game.load_layout)
	if game.level_number>0:
		hint_button=_icon_button("hint",Rect2(right-80,top,80,80),game.show_hint)
		hint_badge=Aura.label(hint_button,"",Rect2(48,-6,40,34),22,Color.WHITE)
		hint_badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var badge:=StyleBoxFlat.new()
		badge.bg_color=Aura.GOLD
		badge.set_corner_radius_all(16)
		hint_badge.add_theme_stylebox_override("normal",badge)
		mutations.append(hint_button)
	# Undo and reset sit in the top strip next to the hint; the crystal tools
	# appear next to the crystal itself.
	var tools_x:=right-176 if game.level_number>0 else right-80
	undo_button=_icon_button("undo",Rect2(tools_x,top,80,80),game.undo_mirror)
	var reset:=_icon_button("reset",Rect2(tools_x-96,top,80,80),game.reset_level)
	# Prism (shop item): shown only while the player owns prisms.
	if game.level_number>0:
		prism_button=_icon_button("prism",Rect2(tools_x-192,top,80,80),toggle_prism)
		prism_badge=Aura.label(prism_button,"",Rect2(48,-6,40,34),22,Color.WHITE)
		prism_badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var pbadge:=StyleBoxFlat.new()
		pbadge.bg_color=Color("8a7bd1")
		pbadge.set_corner_radius_all(16)
		prism_badge.add_theme_stylebox_override("normal",pbadge)
		mutations.append(prism_button)
	mirror_menu=Control.new()
	mirror_menu.size=Vector2(3*76+2*10,76)
	mirror_menu.visible=false
	add_child(mirror_menu)
	rotate_left=_icon_button("rotate_ccw",Rect2(0,0,76,76),func():game.rotate_selected(-45),mirror_menu)
	rotate_right=_icon_button("rotate_cw",Rect2(86,0,76,76),func():game.rotate_selected(45),mirror_menu)
	remove_button=_icon_button("delete",Rect2(172,0,76,76),game.delete_selected,mirror_menu)
	mutations.append_array([rotate_left,rotate_right,undo_button,remove_button,reset])
	toast=Aura.label(self,"",Rect2(240,690,800,52),24,Color.WHITE)
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var toast_bg:=StyleBoxFlat.new()
	toast_bg.bg_color=Color(0.23,0.18,0.39,0.86)
	toast_bg.set_corner_radius_all(24)
	toast_bg.content_margin_left=20
	toast_bg.content_margin_right=20
	toast.add_theme_stylebox_override("normal",toast_bg)
	toast.modulate.a=0.0
	refresh()
	# Each chapter brings one new idea; its tip shows when the chapter starts.
	if game.level_number>0 and Aura.tutorial and not str(game.level_data.get("tip","")).is_empty(): show_toast(str(game.level_data.tip))

# Left and right x positions of the visible screen (design coordinates),
# moved in by the iPhone safe area so nothing sits under the Dynamic Island.
# Top inset (status bar, notch or camera cut-out) in design pixels, 6..14.
func _safe_top() -> float:
	var view:=get_viewport().get_visible_rect().size
	var window:=Vector2(DisplayServer.window_get_size())
	var safe:=Rect2(DisplayServer.get_display_safe_area())
	if window.y<=0 or safe.size.y<=0: return 6.0
	var inset:=maxf(0.0,safe.position.y-DisplayServer.window_get_position().y)*view.y/window.y
	# Phones in landscape have no top cut-out (the Dynamic Island is on a side),
	# so the inset stays small; the clamp keeps the chips above the board.
	return clampf(inset+6.0,6.0,14.0)

func _safe_edges() -> Vector2:
	var view:=get_viewport().get_visible_rect().size
	var window:=Vector2(DisplayServer.window_get_size())
	var safe:=Rect2(DisplayServer.get_display_safe_area())
	var inset_l:=0.0
	var inset_r:=0.0
	if window.x>0 and safe.size.x>0:
		var k:=view.x/window.x
		inset_l=maxf(0.0,safe.position.x)*k
		inset_r=maxf(0.0,window.x-safe.end.x)*k
	return Vector2(-Aura.margin_x+inset_l+12,Aura.DESIGN.x+Aura.margin_x-inset_r-12)

func _chip(pos: Vector2, text: String) -> Label:
	var chip:=Aura.label(self,text,Rect2(pos,Vector2(0,56)),24,Aura.INK)
	chip.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var box:=StyleBoxFlat.new()
	box.bg_color=Color(1,1,1,0.72)
	box.border_color=Color(1,1,1,0.95)
	box.set_border_width_all(2)
	box.set_corner_radius_all(28)
	box.content_margin_left=18
	box.content_margin_right=18
	chip.add_theme_stylebox_override("normal",box)
	return chip

func _icon_button(icon: String, rect: Rect2, action: Callable, parent: Node = null) -> Button:
	var item:=Aura.button(parent if parent else self,"",rect,action)
	if Aura.ICON_HINTS.has(icon): item.set_meta("hint",Aura.ICON_HINTS[icon])
	item.icon=load(ICONS % icon)
	item.expand_icon=true
	item.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_constant_override("icon_max_width",int(rect.size.x*0.5))
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var box:=StyleBoxFlat.new()
		box.bg_color=Color(1,1,1,0.62 if state!="pressed" else 0.9)
		if state=="disabled": box.bg_color=Color(1,1,1,0.3)
		box.border_color=Color(1,1,1,0.95)
		box.set_border_width_all(2)
		box.set_corner_radius_all(int(rect.size.x/2))
		box.shadow_color=Color(0.24,0.16,0.35,0.18)
		box.shadow_size=8
		item.add_theme_stylebox_override(state,box)
	item.add_theme_color_override("icon_disabled_color",Color(1,1,1,0.4))
	return item

func refresh() -> void:
	if game.level_number>0:
		chips[1].text="★ %d / %d" % [game.stars_hit,game.target_stars.size()]
		chips[2].text="      %d / %d" % [game.crystal_count(),game.max_mirrors]
		var prisms_left:int=int(Aura.shop.inventory.prism)-game.prism_count()
		prism_button.visible=int(Aura.shop.inventory.prism)>0
		prism_badge.text=str(maxi(prisms_left,0))
		var bought:int=Aura.shop.inventory.hint
		hint_badge.text=str(game.hints_left) if game.hints_left>0 else (str(bought) if bought>0 else "AD")
	var frozen:bool=game.blocked or (game.level_won and game.level_number>0)
	# Creative Studio: the chosen tool's picture is highlighted.
	for button in mutations:
		if button.has_meta("tool"): button.modulate=Color(1,0.9,0.55) if game.tool==button.get_meta("tool") else Color.WHITE
	for button in mutations:button.disabled=frozen
	rotate_left.disabled=frozen or game.selected_mirror<0
	rotate_right.disabled=rotate_left.disabled
	remove_button.disabled=rotate_left.disabled
	undo_button.disabled=frozen or game.history.is_empty()
	if prism_button:
		prism_button.disabled=frozen or int(Aura.shop.inventory.prism)-game.prism_count()<=0
		prism_button.modulate=Color(1,0.92,0.6) if game.place_prism else Color.WHITE
	# A prism has no direction, so only Delete is offered for it.
	var on_prism:bool=game.selected_mirror>=0 and game.is_prism(game.selected_mirror)
	rotate_left.visible=not on_prism
	rotate_right.visible=not on_prism
	remove_button.position.x=0.0 if on_prism else 172.0
	mirror_menu.size.x=76.0 if on_prism else 248.0
	_place_mirror_menu(not remove_button.disabled)
	if not game.message.is_empty() and game.message!=last_message:
		show_toast(game.message)
	elif game.level_number==1 and Aura.tutorial and game.crystal_count()==1 and not game.level_won and last_message=="Tap under the sun.":
		show_toast("Turn the crystal to hit the star.")
	last_message=game.message if not game.message.is_empty() else last_message

# Shows the crystal tools above the selected crystal (below it on the top
# rows), kept inside the visible screen.
func _place_mirror_menu(show: bool) -> void:
	if not show:
		mirror_menu.visible=false
		menu_cell=Vector2i(-1,-1)
		return
	var m:Dictionary=game.mirrors[game.selected_mirror]
	var cell:=Vector2i(int(m.grid_x),int(m.grid_y))
	var center:Vector2=game.ORIGIN+game.grid_center(cell.x,cell.y)
	var half:float=game.GRID_SIZE*0.5
	var y:=center.y-half-mirror_menu.size.y-10
	if y<game.ORIGIN.y+4: y=center.y+half+10
	var x:=clampf(center.x-mirror_menu.size.x/2.0,left_edge,right_edge-mirror_menu.size.x)
	mirror_menu.position=Vector2(x,y)
	if cell!=menu_cell or not mirror_menu.visible:
		mirror_menu.visible=true
		menu_cell=cell
		mirror_menu.scale=Vector2.ONE
		Aura.pop_in(mirror_menu,0.0,0.22)

func toggle_prism() -> void:
	game.place_prism=not game.place_prism
	if game.place_prism: game.message="Tap a cell for the prism."
	Aura.sound("pop" if game.place_prism else "click")
	refresh()

func shake_mirror_count() -> void:
	if chips.size()>2: Aura.shake(chips[2])

func show_toast(text: String) -> void:
	last_message=text
	toast.text=text
	toast.size=Vector2(800,52)
	if toast_tween: toast_tween.kill()
	toast_tween=create_tween()
	toast.modulate.a=1.0
	Aura.pop_in(toast,0.0,0.25)
	toast_tween.tween_interval(3.5)
	toast_tween.tween_property(toast,"modulate:a",0.0,0.6)

func _overlay() -> ColorRect:
	var shade:=ColorRect.new()
	shade.color=Color(0.15,0.12,0.22,0.55)
	shade.position=Vector2(-640,0)
	shade.size=Vector2(2560,800)
	add_child(shade)
	return shade

func show_success() -> void:
	if success:return
	success=_overlay()
	var confetti:Node2D=load("res://scenes/fx/confetti.tscn").instantiate()
	success.add_child(confetti)
	confetti.position=Vector2(640,0)
	if not Aura.reduced_motion:
		for burst in confetti.get_children(): burst.emitting=true
	var box:=Aura.panel(success,Rect2(930,150,700,480))
	Aura.pop_in(box,0.0,0.35)
	var last:bool=game.level_number>=Aura.LEVEL_COUNT
	var title:=Aura.label(box,tr("Chapter %d complete") % game.level_number,Rect2(20,18,660,52),36)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	# Reward stars land one by one, each with a rising chime.
	for i in range(3):
		var star:=Aura.label(box,"★" if i<game.rating() else "☆",Rect2(240+i*76,74,76,70),56,Color("7d5f2a"))
		star.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		Aura.pop_in(star,0.35+i*0.25,0.3)
		if i<game.rating():
			Aura.later(star,0.35+i*0.25,func():Aura.sound("star",1.0+i*0.2))
	var line:=tr("Crystals: %d · best: %d") % [game.crystal_count(),int(game.level_data.par)]
	if game.hints_used>0: line+="  ·  "+tr("hints: %d") % game.hints_used
	var info:=Aura.label(box,line,Rect2(20,156,660,40),26,Aura.MUTED)
	info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var next_story:bool=Aura.story.is_unlocked(game.level_number-1) and not Aura.story.is_read(game.level_number-1)
	if next_story:
		var teaser:=Aura.label(box,"Lira and Frieren's story continues...",Rect2(20,200,660,40),26,Color("7d5f2a"))
		teaser.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if not Aura.save_error.is_empty(): Aura.label(box,Aura.save_error,Rect2(24,236,652,34),22)
	if Aura.shop.last_earned>0:
		var shards:=Aura.shard_chip(box,Vector2(262,262),0,"+")
		Aura.pop_in(shards.get_parent(),1.1,0.3)
		Aura.later(shards,1.3,func(): Aura.count_up(shards,0,Aura.shop.last_earned,"+"))
	Aura.icon_button(box,"reset",Rect2(120,350,100,100),func():Aura.reload_scene())
	Aura.icon_button(box,"chapters",Rect2(300,350,100,100),go_chapters)
	Aura.icon_button(box,"play",Rect2(480,350,100,100),continue_journey,true)
	refresh()

func open_pause() -> void:
	if modal or success:return
	game.blocked=true
	refresh()
	modal=_overlay()
	var box:=Aura.panel(modal,Rect2(1030,90,500,610))
	Aura.pop_in(box)
	Aura.sound("whoosh")
	Aura.label(box,"Paused",Rect2(20,18,460,56),38).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	Aura.button(box,"Resume",Rect2(40,90,420,84),resume)
	Aura.button(box,"Restart" if game.level_number==0 else "Restart chapter",Rect2(40,188,420,84),func():Aura.reload_scene())
	Aura.button(box,"Chapters",Rect2(40,286,420,84),go_chapters)
	Aura.button(box,"Settings",Rect2(40,384,420,84),func():Aura.open_settings(self))
	Aura.button(box,"Main menu",Rect2(40,482,420,84),go_menu)

# Next: the chapter's story episode plays first (once), then the next chapter.
func continue_journey() -> void:
	var i:int=game.level_number-1
	var after:=func():
		if game.level_number>=Aura.LEVEL_COUNT: go_menu()
		else: Aura.start_level(game.level_number+1)
	if Aura.story.is_unlocked(i) and not Aura.story.is_read(i):
		if success: success.queue_free()
		success=null
		var viewer:=ColorRect.new()
		viewer.set_script(load("res://scripts/story_viewer.gd"))
		add_child(viewer)
		viewer.closed.connect(after)
		viewer.open(i)
	else:
		after.call()

func resume() -> void:
	if modal:modal.queue_free()
	modal=null
	game.blocked=false
	refresh()

# Monetisation prototype: a rewarded "ad" for an extra hint. It is a local demo
# screen (no ad network, no tracking), clearly labelled as a demo.
func offer_ad() -> void:
	if modal or success:return
	game.blocked=true
	refresh()
	modal=_overlay()
	# Out of hints: watch a 5 s demo ad for one more (picture + AD badge).
	var box:=Aura.panel(modal,Rect2(1000,220,560,330))
	Aura.pop_in(box)
	Aura.sound("whoosh")
	var bulb:=TextureRect.new()
	bulb.texture=load("res://assets/ui/icons/hint.svg")
	bulb.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	bulb.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bulb.position=Vector2(190,24)
	bulb.size=Vector2(110,110)
	bulb.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_child(bulb)
	var ad:=Aura.label(box,"+1 · AD 5s",Rect2(150,140,260,44),30,Color("7d5f2a"))
	ad.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	ad.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	Aura.icon_button(box,"close",Rect2(110,206,100,100),resume)
	Aura.icon_button(box,"play",Rect2(350,206,100,100),_play_ad,true)

# Shop item: one crystal above the chapter's limit.
func offer_extra_mirror() -> void:
	if modal or success:return
	game.blocked=true
	refresh()
	modal=_overlay()
	# Crystal limit: use an extra crystal from the shop? (picture, +1, count).
	var box:=Aura.panel(modal,Rect2(1000,220,560,330))
	Aura.pop_in(box)
	Aura.sound("whoosh")
	var gem:=TextureRect.new()
	gem.texture=load("res://assets/art/pieces/mirror.png")
	gem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	gem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem.position=Vector2(170,20)
	gem.size=Vector2(130,130)
	gem.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_child(gem)
	var count:=Aura.label(box,"+1   ×%d" % Aura.shop.inventory.mirror,Rect2(150,140,260,44),30,Color("7d5f2a"))
	count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	count.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	Aura.icon_button(box,"close",Rect2(110,206,100,100),resume)
	Aura.icon_button(box,"check",Rect2(350,206,100,100),func():
		resume()
		game.use_extra_mirror(),true)

func _play_ad() -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal=_overlay()
	modal.color=Color(0.08,0.06,0.13,0.94)
	var box:=Aura.panel(modal,Rect2(930,110,700,560))
	Aura.pop_in(box)
	Aura.label(box,"ADVERTISEMENT · DEMO",Rect2(20,16,660,34),22,Aura.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	Aura.label(box,"AURA",Rect2(20,80,660,110),96).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	Aura.paragraph(box,"Enjoying the quiet light?\nShare AURA with a friend who loves puzzles.",Rect2(40,210,620,110),26).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var count:=Aura.label(box,"",Rect2(20,330,660,60),40,Aura.MUTED)
	count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var close:=Aura.icon_button(box,"check",Rect2(300,400,100,100),func():
		resume()
		game.grant_hint())
	close.disabled=true
	for left in range(AD_SECONDS,0,-1):
		count.text=str(left)
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(count): return
	count.text=""
	close.disabled=false
	Aura.pop_in(close,0.0,0.25)
	Aura.sound("pop")

func _notification(what: int) -> void:
	# Leaving the app (home gesture, call) pauses the puzzle.
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT] and is_node_ready():open_pause()

func go_menu() -> void:
	Aura.change_scene("res://scenes/main_menu.tscn")

func go_chapters() -> void:
	Aura.menu_page="chapters"
	go_menu()
