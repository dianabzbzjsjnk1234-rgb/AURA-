extends ColorRect
# Full-screen episode, staged like a visual novel: the lightkeeper on the left
# changes mood line by line, the lost star answers on the right, lines type out
# letter by letter in a speech bubble with a soft blip, and the episode ends
# with a choice that changes her last line and gives shards (the first time).

signal closed
const SPEED := 45.0   # letters per second
var index := 0
var line := -1
var lines: Array = []
var typing := false
var shown := 0.0
var blip := 0
var finished := false
var choosing := false
var root: Control
var character: Node2D
var star: TextureRect
var bubble: Panel
var name_tag: Label
var text: Label
var hint: Label
var choice_box: Control

func open(episode: int) -> void:
	index = episode
	var data: Dictionary = Aura.story.episode(index)
	lines = data.lines
	color = Color(0.13, 0.1, 0.2, 1.0)
	position = Vector2(-Aura.margin_x - 40, 0)
	size = Vector2(Aura.DESIGN.x + Aura.margin_x * 2 + 80, Aura.DESIGN.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scene(str(data.get("scene", "")))
	root = Control.new()
	root.position = Vector2(Aura.margin_x + 40, 0)
	add_child(root)
	var title := Aura.label(root, (Aura.story.loc(Aura.story.data, "season") + " · " + Aura.story.title(index)) if index < 0 else tr("%s · Episode %d · %s") % [Aura.story.loc(Aura.story.data, "season"), index + 1, Aura.story.title(index)], Rect2(60, 26, 1160, 40), 24, Color("e9dcc0"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character = load("res://scenes/lightkeeper.tscn").instantiate()
	character.position = Vector2(330, 250)
	character.scale = Vector2.ONE * 1.35
	root.add_child(character)
	star = TextureRect.new()
	star.texture = load("res://assets/art/pieces/star_lit.png")
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.position = Vector2(860, 150)
	star.size = Vector2(170, 170)
	star.pivot_offset = star.size / 2.0
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(star)
	if not Aura.reduced_motion:
		var bob := star.create_tween().set_loops()
		bob.tween_property(star, "position:y", 135.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(star, "position:y", 150.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bubble = Aura.panel(root, Rect2(70, 520, 1140, 230))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("fbf6ec")
	box.set_corner_radius_all(30)
	box.border_color = Aura.GOLD
	box.set_border_width_all(3)
	bubble.add_theme_stylebox_override("panel", box)
	name_tag = Aura.label(root, "", Rect2(110, 492, 260, 50), 24, Color.WHITE)
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tag := StyleBoxFlat.new()
	tag.bg_color = Color("8e7d9c")
	tag.set_corner_radius_all(24)
	name_tag.add_theme_stylebox_override("normal", tag)
	text = Aura.paragraph(bubble, "", Rect2(44, 46, 1052, 130), 32)
	hint = Aura.label(bubble, "▸", Rect2(980, 182, 140, 34), 22, Aura.MUTED)
	Aura.pop_in(bubble, 0.0, 0.3)
	Aura.sound("whoosh")
	_advance()

# The episode's scene (drawn by our team in Canva) fills the screen and drifts
# slowly; a soft shade at the bottom keeps the speech bubble readable.
func _scene(file: String) -> void:
	var path := "res://story/scenes/" + file
	if file.is_empty() or not ResourceLoader.exists(path): return
	var picture := TextureRect.new()
	picture.texture = load(path)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.size = size
	picture.pivot_offset = size / 2.0
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Aura.grade_story(picture)
	add_child(picture)
	move_child(picture, 0)
	if not Aura.reduced_motion:
		var drift := picture.create_tween()
		drift.tween_property(picture, "scale", Vector2.ONE * 1.08, 14.0).set_trans(Tween.TRANS_SINE)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.08, 0.16, 0.35)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	move_child(shade, 1)

# One tap: finish the typing line, or go to the next line / the choice.
func _advance() -> void:
	if choosing: return
	if typing:
		_finish_typing()
		return
	if finished:
		_close()
		return
	line += 1
	if line < lines.size():
		_show_line(lines[line])
	elif Aura.story.episode(index).has("choice"):
		_show_choice()
	else:
		_close()

func _show_line(entry) -> void:
	var data: Dictionary = entry if entry is Dictionary else {"speaker": "narrator", "text": str(entry)}
	var speaker := str(data.get("speaker", "narrator"))
	if data.has("mood"): character.set_emotion(_mood(str(data.mood)))
	# The one who speaks is bright; the other steps back a little.
	character.modulate = Color.WHITE if speaker != "star" else Color(0.7, 0.68, 0.78)
	star.modulate = Color.WHITE if speaker == "star" else Color(0.65, 0.62, 0.75)
	if speaker == "star" and not Aura.reduced_motion:
		star.scale = Vector2.ONE * 0.85
		star.create_tween().tween_property(star, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	name_tag.text = "" if speaker == "narrator" else Aura.story.loc(Aura.story.data.get("names", {}), speaker)
	name_tag.visible = not name_tag.text.is_empty()
	# The name sits under the one who speaks: Lira on the left, Frieren on the right.
	name_tag.position.x = 815.0 if speaker == "star" else 110.0
	(name_tag.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = Aura.GOLD if speaker == "star" else Color("8e7d9c")
	text.add_theme_color_override("font_color", Aura.MUTED if speaker == "narrator" else Aura.INK)
	text.text = Aura.story.loc(data, "text")
	text.visible_characters = 0
	shown = 0.0
	blip = 0
	typing = true
	hint.visible = false
	Aura.sound("story_line")
	if Aura.reduced_motion: _finish_typing()

func _process(delta: float) -> void:
	if not typing: return
	shown += delta * SPEED
	text.visible_characters = int(shown)
	if int(shown) / 3 > blip:
		blip = int(shown) / 3
		var speaker := str(lines[line].get("speaker", "")) if line < lines.size() and lines[line] is Dictionary else ""
		Aura.sound("click", 1.5 if speaker == "star" else 1.1)
	if text.visible_characters >= text.text.length(): _finish_typing()

func _finish_typing() -> void:
	typing = false
	text.visible_characters = -1
	hint.visible = true

func _mood(mood: String) -> String:
	return {"happy": "happy", "sad": "sad", "surprised": "surprised"}.get(mood, "idle")

func _show_choice() -> void:
	choosing = true
	var choice: Dictionary = Aura.story.episode(index).choice
	name_tag.visible = false
	text.add_theme_color_override("font_color", Aura.INK)
	text.text = Aura.story.loc(choice, "prompt")
	text.visible_characters = -1
	hint.visible = false
	choice_box = Control.new()
	bubble.add_child(choice_box)
	var options: Array = choice.options
	for k in range(options.size()):
		var option: Dictionary = options[k]
		var button := Aura.button(choice_box, Aura.story.loc(option, "text"), Rect2(44 + k * 536, 112, 516, 84), func(): choose(k), 28)
		if Aura.story.choices.get(index, -1) == k:
			button.add_theme_color_override("font_color", Color("7d5f2a"))
		Aura.pop_in(button, 0.1 + k * 0.08, 0.3)

# The chosen answer: her last line and, the first time, a few shards.
func choose(option: int) -> void:
	if not choosing: return
	choosing = false
	var picked: Dictionary = Aura.story.episode(index).choice.options[option]
	var reward: int = Aura.story.choose(index, option)
	if choice_box: choice_box.queue_free()
	_show_line({"speaker": "keeper", "mood": str(picked.get("mood", "idle")), "text": Aura.story.loc(picked, "reply")})
	if reward > 0: _show_reward(reward)
	finished = true

# Reward for the story: sparkles burst out and a card says what aura is.
func _show_reward(amount: int) -> void:
	var card := Aura.panel(root, Rect2(430, 140, 420, 250))
	var card_box := StyleBoxFlat.new()
	card_box.bg_color = Color("fbf6ec")
	card_box.set_corner_radius_all(28)
	card_box.border_color = Aura.GOLD
	card_box.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", card_box)
	var spark := TextureRect.new()
	spark.texture = load("res://assets/art/pieces/sparkle.png")
	spark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spark.modulate = Color("d9a93c")
	spark.position = Vector2(56, 22)
	spark.size = Vector2(76, 76)
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(spark)
	var amount_label := Aura.label(card, tr("+%d aura") % amount, Rect2(140, 30, 240, 60), 40, Color("7d5f2a"))
	amount_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var about := Aura.paragraph(card, "Aura is the light you collect. Spend it in the Shop.", Rect2(24, 108, 372, 124), 24)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Aura.pop_in(card, 0.25, 0.35)
	Aura.later(card, 0.3, func():
		Aura.sound("coins")
		Aura.haptic(30))
	if Aura.reduced_motion: return
	# A ring of little stars flies out of the card and fades.
	for k in range(14):
		var star := TextureRect.new()
		star.texture = load("res://assets/art/pieces/sparkle.png")
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.size = Vector2(34, 34)
		star.pivot_offset = star.size / 2.0
		star.modulate = Color("f3d27a")
		star.position = Vector2(640, 260) - star.size / 2.0
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(star)
		var direction := Vector2.RIGHT.rotated(TAU * k / 14.0)
		var fly := star.create_tween().set_parallel()
		fly.tween_interval(0.25)
		fly.chain().tween_property(star, "position", star.position + direction * randf_range(170.0, 260.0), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly.tween_property(star, "rotation", randf_range(-3.0, 3.0), 0.8)
		fly.tween_property(star, "modulate:a", 0.0, 0.8).set_delay(0.3)
		fly.chain().tween_callback(star.queue_free)

func _close() -> void:
	Aura.story.mark_read(index)
	Aura.sound("pop")
	closed.emit()
	queue_free()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()
