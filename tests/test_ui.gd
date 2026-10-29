extends SceneTree

var failures = 0
var checks = 0
var scene

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("UI FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame

func click(rect: Rect2) -> void:
	scene._handle_click(rect.get_center())
	await frames()

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(8)
	check(scene.buttons.has("play_a"), "Home play button exists")
	await click(scene.buttons.play_a)
	check(scene.screen == "game" and scene.overlay == "spirit", "Play opens spirit choice")
	await click(scene.buttons.spirit_0)
	check(scene.overlay.is_empty() and not scene.game.spirit.is_empty(), "Spirit selected")
	await click(scene.market_regions[0])
	check(scene.game.selected_group == 0 and scene.game.selected_tokens.size() == 3, "Market group selected through hit region")
	var placements = 0
	while not scene.game.selected_tokens.is_empty() and placements < 3:
		var acted = false
		for cell in scene.cell_regions.keys():
			if EcoRules.can_place(scene.game.board, scene.game.cubes, cell, scene.game.selected_tokens[scene.selected_token_index]):
				await click(scene.cell_regions[cell])
				acted = true
				placements += 1
				break
		check(acted, "Legal token placement %d" % placements)
	check(scene.game.selected_tokens.is_empty(), "All three tokens placed through board hit regions")
	await click(scene.faceup_regions[0])
	check(scene.overlay == "detail" and scene.buttons.has("draft"), "Face-up card opens draft detail")
	await click(scene.buttons.draft)
	check(scene.game.acquired.size() == 1 and scene.game.drafted, "Card drafted through detail button")
	await click(scene.buttons.end_turn)
	check(scene.game.turn == 2 and scene.game.selected_group == -1, "End turn refreshes solo market")
	await click(scene.buttons.refresh)
	await click(scene.faceup_regions[1])
	check(scene.game.refreshed, "Skipped-draft card refresh works")
	await click(scene.buttons.pause)
	check(scene.overlay == "pause", "Pause opens")
	await click(scene.buttons.resume)
	check(scene.overlay.is_empty(), "Resume works")
	await click(scene.buttons.pause)
	await click(scene.buttons.home)
	check(scene.screen == "home", "Pause returns to main menu")
	await click(scene.buttons.help)
	check(scene.screen == "help", "Help opens")
	await click(scene.buttons.help_next)
	await click(scene.buttons.help_next)
	check(scene.help_page == 2, "Help paging works")
	await click(scene.buttons.home)
	await click(scene.buttons.records)
	check(scene.screen == "records", "Records open")
	await click(scene.buttons.home)
	var sound_before = scene.sound_enabled
	await click(scene.buttons.sound)
	check(scene.sound_enabled != sound_before, "Sound toggle works")
	for id in scene.buttons.keys():
		var rect: Rect2 = scene.buttons[id]
		check(rect.size.x >= 44 and rect.size.y >= 44, "Touch target %s is at least 44 px" % id)
	for player in scene.audio.values():
		player.stop()
	scene.queue_free()
	await frames()
	print("Eco Masters UI %dx%d: %d checks, %d failures" % [root.size.x, root.size.y, checks, failures])
	quit(0 if failures == 0 else 1)
