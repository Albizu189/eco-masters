extends SceneTree

var output_dir = "/mnt/agents/work/screenshots"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await settle()
	scene.fade = 0
	scene.toast_time = 0
	await save_image("01-home")
	scene.spirit_enabled = false
	scene.start_game("A")
	scene.fade = 0
	for turn in range(3):
		scene.game.select_market(turn % 3)
		while not scene.game.selected_tokens.is_empty():
			var placed = false
			for cell in scene.game.board.keys():
				if EcoRules.can_place(scene.game.board, scene.game.cubes, cell, scene.game.selected_tokens[0]):
					scene.game.place_token(cell, 0)
					placed = true
					break
			if not placed:
				break
		if scene.game.can_draft(0):
			scene.game.draft_card(0)
		scene.game.end_turn()
	scene.fade = 0
	scene.toast_time = 0
	await settle()
	await save_image("02-game")
	scene.game.ended = true
	scene.game.end_reason = "Visual verification ecosystem"
	scene._finish_game()
	scene.fade = 0
	scene.toast_time = 0
	await settle()
	await save_image("03-results")
	for player in scene.audio.values():
		player.stop()
	scene.queue_free()
	await process_frame
	quit()

func settle() -> void:
	for index in range(8):
		await process_frame

func save_image(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var suffix = "%dx%d" % [int(root.size.x), int(root.size.y)]
	var result = image.save_png(output_dir + "/" + label + "-" + suffix + ".png")
	print("CAPTURE ", label, " ", suffix, " result=", result)
