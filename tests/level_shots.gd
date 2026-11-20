extends Node
# Renders every chapter with its stored solution (for checking level design).
@export var out_dir := "/private/tmp/claude-501/-Users-elli-by-el-Desktop-AURA-Assignment3/5c5d3883-6efb-4ad0-80f9-99a7a261b932/scratchpad/levels"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	Aura.tutorial = false
	for n in range(1, Aura.LEVEL_COUNT + 1):
		Aura.unlocked = Aura.LEVEL_COUNT
		Aura.current_level = n
		var l = load(Aura.GAME_SCENE).instantiate()
		add_child(l)
		for s in l.level_data.solution:
			l.board_tap(l.grid_center(s[0], s[1]))
			l.rotate_selected(s[2])
		l.selected_mirror = -1
		l._update_board()
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("%s/level_%d.png" % [out_dir, n])
		l.queue_free()
		await get_tree().process_frame
	get_tree().quit()
