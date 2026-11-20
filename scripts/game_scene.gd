extends Node2D

# The board fills most of the screen; icon controls float on a layer above it.
const GRID_SIZE := 88
const GRID_WIDTH := 14
const GRID_HEIGHT := 7
const BOARD := Vector2(GRID_WIDTH * GRID_SIZE, GRID_HEIGHT * GRID_SIZE)
const ORIGIN := Vector2(24, 92)
const MIRROR_HALF_LENGTH := GRID_SIZE * 0.394
const STAR_HIT_RADIUS := GRID_SIZE * 0.31
const FREE_HINTS := 1
# Piece art is drawn for a 52 px cell.
const PIECE_SCALE := GRID_SIZE / 52.0
# Tilt to rotate (optional setting): m/s² away from the resting tilt.
const TILT_TRIGGER := 3.5
const TILT_RESET := 1.5
const RAY_MAX_BOUNCES := 64
const RAY_EPSILON := 0.05
# Seconds between the last star lighting up and the completion panel.
const SUCCESS_DELAY := 1.5
const BEAM_FLOW_SPEED := 240.0  # px per second, sparks flowing along the beam
const BEAM_SPARK_GAP := 90.0
const BEAM_RUN_SPEED := 2600.0  # px per second, a new beam running out
const MIRROR_SCENE := preload("res://scenes/pieces/mirror.tscn")
const PRISM_SCENE := preload("res://scenes/pieces/prism.tscn")
const WALL_TEXTURE := preload("res://assets/art/pieces/wall.png")
const STAR_SCENE := preload("res://scenes/pieces/target_star.tscn")
const SOURCE_SCENE := preload("res://scenes/pieces/light_source.tscn")
# -1: take the chapter from Aura.current_level (0 = Creative Studio).
@export var level_number := -1
var mirrors: Array[Dictionary] = []
var selected_mirror := -1
var light_source_pos := Vector2.ZERO
var target_stars: Array[Dictionary] = []
var stars_hit := 0
var level_data: Dictionary = {}
var ray_segments: Array[Dictionary] = []
# Beam animation (drawing only; the rules use ray_segments at once):
# new parts of the beam run out from the sun up to beam_reveal pixels of path.
var beam_reveal := INF
var beam_tween: Tween
var level_won := false
var blocked := false
var history: Array[Dictionary] = []
var hints_used := 0
var hint_index := 0
var hints_left := FREE_HINTS
var walls: Array[Vector2i] = []
var max_mirrors := 99
var tilt_base := Vector3.ZERO
var tilt_armed := true
var hint_cells: Array = []
var tool := "mirror"
# Prism placement mode (shop item): the next empty cell gets a prism.
var place_prism := false
var ui: CanvasLayer
var scenery: Node2D
# Board pieces are scene instances (see scenes/pieces); the code only places them.
var pieces: Node2D
var source_piece: Node2D
var mirror_pieces: Array[Node2D] = []
var star_pieces: Array[Node2D] = []
var piece_event := ""
var message := ""

func _ready() -> void:
	if level_number < 0: level_number = Aura.current_level
	if level_number > Aura.unlocked:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")
		return
	level_data = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%d.json" % maxi(1,level_number))) if level_number > 0 else {"source":[7,1],"stars":[[12,5]],"walls":[],"par":0,"solution":[]}
	setup_level()
	_restore_board()
	scenery = load("res://scenes/background.tscn").instantiate()
	add_child(scenery)
	move_child(scenery,0)
	scenery.show_behind_parent = true
	pieces = Node2D.new()
	pieces.position = ORIGIN
	add_child(pieces)
	source_piece = SOURCE_SCENE.instantiate()
	source_piece.scale = Vector2.ONE * PIECE_SCALE
	pieces.add_child(source_piece)
	ui = load("res://scripts/game_ui.gd").new()
	add_child(ui)
	_update_board()

func setup_level() -> void:
	light_source_pos = grid_center(int(level_data.source[0]),int(level_data.source[1]))
	target_stars.clear()
	for pos in level_data.stars:
		target_stars.append({"pos":grid_center(int(pos[0]),int(pos[1])),"hit":false})
	walls.clear()
	for cell in level_data.get("walls", []):
		walls.append(Vector2i(int(cell[0]), int(cell[1])))
	max_mirrors = int(level_data.get("max_mirrors", 99)) if level_number > 0 else 99
	hints_left = FREE_HINTS
	mirrors.clear()
	history.clear()
	selected_mirror = -1
	level_won = false
	hints_used = 0
	hint_index = 0
	hint_cells = []
	message = ""

# Language change in Settings reloads the scene: these two keep the board.
func board_state() -> Dictionary:
	return {"level": level_number, "mirrors": mirrors.duplicate(true), "history": history.duplicate(true),
		"selected": selected_mirror, "source": light_source_pos, "hints_used": hints_used,
		"hint_index": hint_index, "hints_left": hints_left, "hint_cells": hint_cells.duplicate(true),
		"won": level_won}

func _restore_board() -> void:
	var state: Dictionary = Aura.carry_board
	Aura.carry_board = {}
	if state.is_empty() or int(state.level) != level_number or state.won: return
	mirrors.assign(state.mirrors)
	history.assign(state.history)
	selected_mirror = state.selected
	light_source_pos = state.source
	hints_used = state.hints_used
	hint_index = state.hint_index
	hints_left = state.hints_left
	hint_cells = state.hint_cells

func grid_center(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * GRID_SIZE, (y + 0.5) * GRID_SIZE)

func _draw() -> void:
	# Only the board and the light beam are drawn in code: the beam is
	# geometry computed from the mirrors every time the layout changes.
	draw_set_transform(ORIGIN)
	draw_rect(Rect2(Vector2(-4,-4),BOARD+Vector2(8,8)),Color(1,1,1,0.85))
	draw_rect(Rect2(Vector2.ZERO,BOARD),Color("f8f3ee",0.94))
	for x in range(GRID_WIDTH+1):
		draw_line(Vector2(x*GRID_SIZE,0),Vector2(x*GRID_SIZE,BOARD.y),Color("e2d9e0"),1)
	for y in range(GRID_HEIGHT+1):
		draw_line(Vector2(0,y*GRID_SIZE),Vector2(BOARD.x,y*GRID_SIZE),Color("e2d9e0"),1)
	for wall in walls:
		var box := Rect2(Vector2(wall)*GRID_SIZE+Vector2(4,4),Vector2(GRID_SIZE-8,GRID_SIZE-8))
		draw_texture_rect(WALL_TEXTURE,box,false)
	for cell in hint_cells:
		draw_rect(Rect2(Vector2(cell[0],cell[1])*GRID_SIZE+Vector2(3,3),Vector2(GRID_SIZE-6,GRID_SIZE-6)),Color("f2d78f",0.55))
		draw_rect(Rect2(Vector2(cell[0],cell[1])*GRID_SIZE+Vector2(3,3),Vector2(GRID_SIZE-6,GRID_SIZE-6)),Aura.GOLD,false,3)
	var beam: Array = Aura.shop.beam_colors()
	var now := Time.get_ticks_msec() / 1000.0
	var moving := not Aura.reduced_motion
	for segment in ray_segments:
		var a: Vector2 = segment.from
		var b: Vector2 = segment.to
		var length := a.distance_to(b)
		var d0 := float(segment.get("d0", 0.0))
		var shown := clampf(beam_reveal - d0, 0.0, length)
		if shown <= 0.0 or length <= 0.0: continue
		var way := (b - a) / length
		var end := a + way * shown
		draw_line(a,end,beam[0],10,true)
		draw_line(a,end,beam[1],3,true)
		draw_line(a,end,beam[2],1,true)
		if not moving: continue
		# Sparks of light travel from the sun along the path.
		var spark := d0 + fposmod(now * BEAM_FLOW_SPEED - d0, BEAM_SPARK_GAP)
		while spark < d0 + shown:
			var p := a + way * (spark - d0)
			draw_circle(p, 7.0, Color(beam[1], 0.22))
			draw_circle(p, 3.0, beam[2])
			spark += BEAM_SPARK_GAP
		# A soft pulse where the light bounces off a crystal.
		if segment.get("bounce", false) and shown >= length:
			var r := 9.0 + 2.5 * sin(now * 5.0 + d0 * 0.01)
			draw_circle(b, r * 1.8, Color(beam[0], 0.35))
			draw_circle(b, r * 0.6, Color(beam[2], 0.9))
		elif shown < length:
			draw_circle(end, 8.0, Color(beam[2], 0.95))  # the head of the running light

# New parts of the beam run out from where they start instead of appearing at once.
func _animate_new_beam(old_beam: Dictionary) -> void:
	var start := INF
	var finish := 0.0
	for segment in ray_segments:
		finish = maxf(finish, float(segment.d0) + segment.from.distance_to(segment.to))
		if not old_beam.has([segment.from, segment.to]): start = minf(start, float(segment.d0))
	if beam_tween: beam_tween.kill()
	if Aura.reduced_motion or start == INF or old_beam.is_empty() and start > 0.0:
		beam_reveal = INF
		return
	beam_reveal = start
	beam_tween = create_tween()
	beam_tween.tween_method(func(v: float):
		beam_reveal = v
		queue_redraw(), start, finish, clampf((finish - start) / BEAM_RUN_SPEED, 0.12, 0.5))
	beam_tween.tween_callback(func(): beam_reveal = INF)

func _sync_pieces() -> void:
	source_piece.position = light_source_pos
	while mirror_pieces.size() > mirrors.size():
		mirror_pieces.pop_back().queue_free()
	for i in range(mirrors.size()):
		# Each board piece matches its kind (crystal mirror or prism).
		var kind := "prism" if is_prism(i) else "mirror"
		if i >= mirror_pieces.size() or mirror_pieces[i].get_meta("kind", "mirror") != kind:
			var piece: Node2D = (PRISM_SCENE if kind == "prism" else MIRROR_SCENE).instantiate()
			piece.set_meta("kind", kind)
			piece.scale = Vector2.ONE * PIECE_SCALE
			pieces.add_child(piece)
			if i < mirror_pieces.size():
				mirror_pieces[i].queue_free()
				mirror_pieces[i] = piece
			else: mirror_pieces.append(piece)
	for i in range(mirrors.size()):
		mirror_pieces[i].position = grid_center(int(mirrors[i].grid_x),int(mirrors[i].grid_y))
		var target := float(mirrors[i].rotation)
		if i == selected_mirror and piece_event == "turn" and not Aura.reduced_motion:
			# Turn smoothly the short way round (a mirror looks the same after 180°).
			var from: float = mirror_pieces[i].rotation_degrees
			var turn := create_tween()
			turn.tween_property(mirror_pieces[i], "rotation_degrees", from + wrapf(target - from, -90.0, 90.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not is_equal_approx(fposmod(mirror_pieces[i].rotation_degrees, 180.0), target):
			mirror_pieces[i].rotation_degrees = target
		mirror_pieces[i].set_selected(i == selected_mirror)
		if not is_prism(i): mirror_pieces[i].get_node("Crystal").modulate = Aura.shop.crystal_tint()
	if selected_mirror >= 0 and not piece_event.is_empty():
		mirror_pieces[selected_mirror].play_once(piece_event)
	piece_event = ""
	while star_pieces.size() < target_stars.size():
		star_pieces.append(STAR_SCENE.instantiate())
		star_pieces.back().scale = Vector2.ONE * PIECE_SCALE
		pieces.add_child(star_pieces.back())
	while star_pieces.size() > target_stars.size():
		star_pieces.pop_back().queue_free()
	for i in range(target_stars.size()):
		star_pieces[i].position = target_stars[i].pos
		if bool(target_stars[i].hit) and not star_pieces[i].lit:
			Aura.haptic(25)
			Aura.sound("star", 1.0 + 0.15 * stars_hit)
		star_pieces[i].set_lit(bool(target_stars[i].hit))

func _process(_delta: float) -> void:
	# The light flows along the beam all the time.
	if not Aura.reduced_motion and not ray_segments.is_empty(): queue_redraw()
	if not Aura.tilt_rotate or blocked or selected_mirror < 0:
		tilt_base = Vector3.ZERO
		return
	var accel := Input.get_accelerometer()
	if accel == Vector3.ZERO: return
	if tilt_base == Vector3.ZERO:
		tilt_base = accel
		return
	# In landscape the left/right tilt shows up on whichever axis changes most.
	var change := accel - tilt_base
	var tilt := change.x if absf(change.x) > absf(change.y) else -change.y
	if tilt_armed and absf(tilt) > TILT_TRIGGER:
		tilt_armed = false
		rotate_selected(45.0 if tilt > 0 else -45.0)
	elif absf(tilt) < TILT_RESET:
		tilt_armed = true

func _unhandled_input(event: InputEvent) -> void:
	if blocked or (level_won and level_number>0): return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		board_tap(make_input_local(event).position-ORIGIN)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT,KEY_A: rotate_selected(-45)
			KEY_RIGHT,KEY_D: rotate_selected(45)
			KEY_Z: undo_mirror()
			KEY_DELETE,KEY_BACKSPACE: delete_selected()
			KEY_R: reset_level()
			KEY_ESCAPE: ui.open_pause()

func board_tap(pos: Vector2) -> void:
	if blocked or (level_won and level_number>0): return
	if not Rect2(Vector2.ZERO,BOARD).has_point(pos): return
	var cell := Vector2i(floori(pos.x/GRID_SIZE),floori(pos.y/GRID_SIZE))
	var point := grid_center(cell.x,cell.y)
	if level_number==0 and tool=="source":
		if find_mirror_at(cell.x,cell.y)>=0 or star_at(point)>=0:
			message="This cell is taken."
			ui.refresh()
			return
		snapshot()
		light_source_pos=point
	elif level_number==0 and tool=="star":
		if point==light_source_pos or find_mirror_at(cell.x,cell.y)>=0: return
		snapshot()
		var found:=star_at(point)
		if found>=0: target_stars.remove_at(found)
		elif target_stars.size()<12: target_stars.append({"pos":point,"hit":false})
		else: message="Up to 12 stars."
	else:
		if point==light_source_pos or star_at(point)>=0 or walls.has(cell):
			message="This cell is taken."
			Aura.sound("error")
			ui.refresh()
			return
		var found:=find_mirror_at(cell.x,cell.y)
		if found>=0:
			# Tapping the selected crystal again closes its tools.
			selected_mirror=-1 if found==selected_mirror else found
			Aura.sound("click")
		elif place_prism and prism_count()>=int(Aura.shop.inventory.prism):
			place_prism=false
			message="No prisms left."
			Aura.sound("error")
			ui.refresh()
			return
		elif place_prism:
			snapshot()
			mirrors.append({"grid_x":cell.x,"grid_y":cell.y,"rotation":0.0,"kind":"prism"})
			selected_mirror=mirrors.size()-1
			place_prism=false
			piece_event="place"
			message="The prism splits the beam."
			Aura.sound("pop")
			Aura.sound("place",1.5)
		elif crystal_count()>=max_mirrors and Aura.shop.inventory.mirror>0 and level_number>0:
			ui.offer_extra_mirror()
			return
		elif crystal_count()>=max_mirrors:
			message="No crystals left."
			Aura.haptic(60)
			Aura.sound("error")
			if ui: ui.shake_mirror_count()
			ui.refresh()
			return
		else:
			snapshot()
			mirrors.append({"grid_x":cell.x,"grid_y":cell.y,"rotation":0.0})
			selected_mirror=mirrors.size()-1
			piece_event="place"
			Aura.sound("place")
	_update_board()

func star_at(pos: Vector2) -> int:
	for i in range(target_stars.size()):
		if target_stars[i].pos==pos:return i
	return -1

func find_mirror_at(x: int,y: int) -> int:
	for i in range(mirrors.size()):
		if mirrors[i].grid_x==x and mirrors[i].grid_y==y:return i
	return -1

func snapshot() -> void:
	history.append({"mirrors":mirrors.duplicate(true),"selected":selected_mirror,"source":light_source_pos,"stars":target_stars.duplicate(true)})
	if history.size()>200: history.pop_front()
	message=""

func rotate_selected(amount: float) -> void:
	if blocked or (level_won and level_number>0) or selected_mirror<0 or is_prism(selected_mirror):return
	snapshot()
	mirrors[selected_mirror].rotation=fposmod(float(mirrors[selected_mirror].rotation)+amount,180)
	piece_event="turn"
	Aura.sound("rotate")
	_update_board()

func delete_selected() -> void:
	if blocked or (level_won and level_number>0) or selected_mirror<0:return
	snapshot()
	# A copy of the crystal shrinks away where it stood.
	if selected_mirror < mirror_pieces.size() and not Aura.reduced_motion:
		var ghost: Node2D = mirror_pieces[selected_mirror].duplicate()
		pieces.add_child(ghost)
		var fade := ghost.create_tween().set_parallel()
		fade.tween_property(ghost, "scale", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		fade.tween_property(ghost, "modulate:a", 0.0, 0.22)
		fade.chain().tween_callback(ghost.queue_free)
	mirrors.remove_at(selected_mirror)
	selected_mirror=-1
	Aura.sound("delete")
	_update_board()

func undo_mirror() -> void:
	if blocked or (level_won and level_number>0) or history.is_empty():return
	var state:Dictionary=history.pop_back()
	mirrors.assign(state.mirrors)
	selected_mirror=state.selected
	light_source_pos=state.source
	target_stars.assign(state.stars)
	message="Undone."
	_update_board()

func reset_level() -> void:
	if blocked or (level_won and level_number>0):return
	snapshot()
	mirrors.clear()
	selected_mirror=-1
	_update_board()

# Hints are built from the level's verified solution (tools/level_solver.py):
# the first shows where the first mirror goes, the next shows every mirror cell.
func show_hint() -> void:
	if blocked or level_won or level_number==0:return
	if hints_left<=0:
		# A hint bought in the shop is used before the ad is offered.
		if Aura.shop.use("hint"): hints_left+=1
		else:
			ui.offer_ad()
			return
	hints_left-=1
	hints_used+=1
	var solution:Array=level_data.solution
	if hint_index==0:
		hint_cells=[solution[0]]
		message=tr("You need 1 crystal. Put it on the glowing cell.") if solution.size()==1 else tr("You need %d crystals. Start on the glowing cell.") % solution.size()
	else:
		hint_cells=solution.duplicate()
		message="All crystal cells are glowing."
	hint_index+=1
	ui.refresh()
	queue_redraw()

func use_extra_mirror() -> void:
	if Aura.shop.use("mirror"):
		max_mirrors+=1
		message="One more crystal!"
		Aura.sound("pop")
		ui.refresh()

func grant_hint() -> void:
	hints_left+=1
	show_hint()

# 3 stars: the minimum number of mirrors and no hints. Each extra mirror or
# using hints costs a star (minimum 1).
func rating() -> int:
	var result:=3
	if crystal_count()>int(level_data.par): result-=1
	if hints_used>0: result-=1
	# A prism is a paid shortcut: a chapter won with one gives at most 2 stars.
	if prism_count()>0: result=mini(result,2)
	return maxi(result,1)

func _update_board() -> void:
	var previously_won:=level_won
	var old_beam:={}
	for segment in ray_segments: old_beam[[segment.from,segment.to]]=true
	_recalculate_rays()
	_animate_new_beam(old_beam)
	_sync_pieces()
	if level_won and not previously_won:
		Aura.sound("win")
		Aura.haptic(80)
		if level_number>0:
			Aura.complete(level_number,rating())
			# Prisms are used up only when the chapter is won with them.
			for _p in range(prism_count()): Aura.shop.use("prism")
			if ui: Aura.later(ui, SUCCESS_DELAY, ui.show_success)
	if ui: ui.refresh()
	queue_redraw()

func save_layout() -> void:
	var data:Dictionary={"version":3,"source":_cell_of(light_source_pos),"stars":[],"mirrors":mirrors}
	for star in target_stars:data.stars.append(_cell_of(star.pos))
	var file:=FileAccess.open("user://creative.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		message="Saved."
	else:message="Could not save."
	ui.refresh()

func load_layout() -> void:
	if not FileAccess.file_exists("user://creative.json"):
		message="Nothing saved yet."
		ui.refresh()
		return
	var data=JSON.parse_string(FileAccess.get_file_as_string("user://creative.json"))
	if not data is Dictionary or not data.has_all(["source","stars","mirrors"]):
		message="Could not load."
		ui.refresh()
		return
	snapshot()
	mirrors.assign(data.mirrors)
	# Assignment 2 saves stored pixel positions on a 48 px grid.
	var cell_px:=1.0 if int(data.get("version",2))>=3 else 48.0
	light_source_pos=grid_center(floori(data.source[0]/cell_px),floori(data.source[1]/cell_px))
	target_stars.clear()
	for pos in data.stars:target_stars.append({"pos":grid_center(floori(pos[0]/cell_px),floori(pos[1]/cell_px)),"hit":false})
	selected_mirror=-1
	message="Loaded."
	_update_board()

func _cell_of(point: Vector2) -> Array:
	return [floori(point.x/GRID_SIZE),floori(point.y/GRID_SIZE)]

func _recalculate_rays() -> void:
	for star in target_stars:
		star["hit"] = false
	stars_hit = 0
	ray_segments.clear()
	# Rays to trace: a prism splits a beam into two, so this is a queue.
	var queue: Array = [[light_source_pos, Vector2.DOWN, 0.0]]
	var split_done := {}
	while not queue.is_empty() and ray_segments.size() < RAY_MAX_BOUNCES * 2:
		var ray: Array = queue.pop_front()
		var ray_start: Vector2 = ray[0]
		var ray_direction: Vector2 = ray[1]
		var ray_dist: float = ray[2]  # path length from the sun, for the beam animation
		for _bounce in range(RAY_MAX_BOUNCES):
			var end_point := _board_exit(ray_start, ray_direction)
			var nearest_t := ray_start.distance_to(end_point)
			var nearest_mirror := -1
			for wall in walls:
				var t_wall := _ray_rect(ray_start, ray_direction, Rect2(Vector2(wall) * GRID_SIZE, Vector2.ONE * GRID_SIZE))
				if t_wall < nearest_t:
					nearest_t = t_wall
			for i in range(mirrors.size()):
				var mirror: Dictionary = mirrors[i]
				var center := grid_center(int(mirror["grid_x"]), int(mirror["grid_y"]))
				var hit_t := INF
				if is_prism(i):
					# A prism catches a beam that passes through its centre.
					var to_center := center - ray_start
					var t := to_center.dot(ray_direction)
					if t > RAY_EPSILON and (to_center - ray_direction * t).length() < 2.0: hit_t = t
				else:
					var hit := _ray_segment_intersection(ray_start, ray_direction, center, Vector2.RIGHT.rotated(deg_to_rad(float(mirror["rotation"]))), MIRROR_HALF_LENGTH)
					if hit.x >= 0.0: hit_t = hit.y
				if hit_t < nearest_t:
					nearest_t = hit_t
					nearest_mirror = i
			# Stars are checkpoints, not solid obstacles: the beam can activate several
			# stars along one segment before reaching the next mirror or board edge.
			for i in range(target_stars.size()):
				var star: Dictionary = target_stars[i]
				var to_star: Vector2 = star["pos"] - ray_start
				var t := to_star.dot(ray_direction)
				if t > RAY_EPSILON and t <= nearest_t and (to_star - ray_direction * t).length() <= STAR_HIT_RADIUS:
					target_stars[i]["hit"] = true
			end_point = ray_start + ray_direction * nearest_t
			ray_segments.append({"from": ray_start, "to": end_point, "d0": ray_dist, "bounce": nearest_mirror >= 0})
			ray_dist += nearest_t
			if nearest_mirror < 0:
				break
			if is_prism(nearest_mirror):
				# Split into the two perpendicular directions (once per prism and side).
				var key := "%d:%d,%d" % [nearest_mirror, roundi(ray_direction.x), roundi(ray_direction.y)]
				if not split_done.has(key):
					split_done[key] = true
					for side in [Vector2(-ray_direction.y, ray_direction.x), Vector2(ray_direction.y, -ray_direction.x)]:
						queue.append([end_point + side * RAY_EPSILON, side, ray_dist])
				break
			var mirror: Dictionary = mirrors[nearest_mirror]
			var tangent := Vector2.RIGHT.rotated(deg_to_rad(float(mirror["rotation"])))
			var normal := Vector2(-tangent.y, tangent.x)
			ray_direction = ray_direction.bounce(normal).normalized()
			ray_start = end_point + ray_direction * RAY_EPSILON

	stars_hit = 0
	for star in target_stars:
		if bool(star["hit"]):
			stars_hit += 1
	level_won = not target_stars.is_empty() and stars_hit == target_stars.size()

func is_prism(i: int) -> bool:
	return str(mirrors[i].get("kind", "mirror")) == "prism"

# Mirrors that count towards the chapter's limit (prisms do not).
func crystal_count() -> int:
	var n := 0
	for i in range(mirrors.size()):
		if not is_prism(i): n += 1
	return n

func prism_count() -> int:
	return mirrors.size() - crystal_count()

func _ray_segment_intersection(origin: Vector2, direction: Vector2, center: Vector2, tangent: Vector2, half_length: float) -> Vector2:
	var normal := Vector2(-tangent.y, tangent.x)
	var denominator := direction.dot(normal)
	if absf(denominator) < 0.0001:
		return Vector2(-1.0, -1.0)
	var t := (center - origin).dot(normal) / denominator
	if t <= RAY_EPSILON:
		return Vector2(-1.0, -1.0)
	var point := origin + direction * t
	if absf((point - center).dot(tangent)) > half_length:
		return Vector2(-1.0, -1.0)
	return Vector2(point.x, t)

# Distance along the ray to a wall cell, or INF (slab method).
func _ray_rect(origin: Vector2, direction: Vector2, rect: Rect2) -> float:
	var t_min := -INF
	var t_max := INF
	for axis in range(2):
		var o := origin[axis]
		var d := direction[axis]
		var lo := rect.position[axis]
		var hi := rect.end[axis]
		if absf(d) < 0.0001:
			if o < lo or o > hi: return INF
		else:
			var t1 := (lo - o) / d
			var t2 := (hi - o) / d
			t_min = maxf(t_min, minf(t1, t2))
			t_max = minf(t_max, maxf(t1, t2))
	if t_max < t_min or t_min <= RAY_EPSILON: return INF
	return t_min

func _board_exit(origin: Vector2, direction: Vector2) -> Vector2:
	var candidates: Array[float] = []
	if direction.x > 0.0001:
		candidates.append((GRID_WIDTH * GRID_SIZE - origin.x) / direction.x)
	elif direction.x < -0.0001:
		candidates.append((0.0 - origin.x) / direction.x)
	if direction.y > 0.0001:
		candidates.append((GRID_HEIGHT * GRID_SIZE - origin.y) / direction.y)
	elif direction.y < -0.0001:
		candidates.append((0.0 - origin.y) / direction.y)
	var t := INF
	for value in candidates:
		if value > RAY_EPSILON:
			t = minf(t, value)
	if is_inf(t):
		return origin + direction * 1000.0
	return origin + direction * t
