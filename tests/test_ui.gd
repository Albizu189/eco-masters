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

func check_buttons(label: String) -> void:
	var view = scene._view_size()
	for id in scene.buttons.keys():
		var rect: Rect2 = scene.buttons[id]
		check(rect.size.x >= 44 and rect.size.y >= 44, "%s touch target %s is at least 44 logical px" % [label, id])
		check(rect.position.x >= -0.1 and rect.position.y >= -0.1 and rect.end.x <= view.x + 0.1 and rect.end.y <= view.y + 0.1, "%s button %s stays on screen" % [label, id])

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(8)
	check(scene.buttons.has("play_a"), "Home play button exists")
	check(scene.ui_scale >= 1.0 and scene._view_size().x > 0 and scene._view_size().y > 0, "Responsive logical canvas is valid")
	check_buttons("Home")
	var dark_before = scene.dark_mode
	await click(scene.buttons.dark)
	check(scene.dark_mode != dark_before, "Dark mode toggle works")
	await click(scene.buttons.dark)
	check(scene.dark_mode == dark_before, "Light mode can be restored")
	await click(scene.buttons.play_a)
	check(scene.screen == "game" and scene.overlay == "spirit", "Play opens spirit choice")
	check_buttons("Spirit")
	await click(scene.buttons.spirit_0)
	check(scene.overlay.is_empty() and not scene.game.spirit.is_empty(), "Spirit selected")
	check(scene.buttons.has("score") and scene.buttons.has("undo"), "Live score and undo controls exist")
	check_buttons("Game")
	await click(scene.market_regions[0])
	check(scene.game.selected_group == 0 and scene.game.selected_tokens.size() == 3, "Market group selected through hit region")
	await click(scene.buttons.undo)
	check(scene.game.selected_group == -1 and scene.game.selected_tokens.is_empty(), "Undo button reverses market selection")
	await click(scene.market_regions[0])
	var first_legal = Vector2i(999, 999)
	for cell in scene.cell_regions.keys():
		if EcoRules.can_place(scene.game.board, scene.game.cubes, cell, scene.game.selected_tokens[0]):
			first_legal = cell
			break
	check(first_legal != Vector2i(999, 999), "A legal first token target exists")
	await click(scene.cell_regions[first_legal])
	check(scene.game.selected_tokens.size() == 2, "First token placed")
	await click(scene.buttons.undo)
	check(scene.game.selected_tokens.size() == 3 and scene.game.board[first_legal].is_empty(), "Undo button restores placed token")
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
	await click(scene.buttons.score)
	check(scene.overlay == "score", "Live score breakdown opens")
	check_buttons("Score")
	await click(scene.buttons.close)
	check(scene.overlay.is_empty(), "Live score breakdown closes")
	await click(scene.buttons.pause)
	await click(scene.buttons.home)
	check(scene.screen == "home" and scene.buttons.has("continue"), "Saved game offers Continue on main menu")
	check_buttons("Saved home")
	await click(scene.buttons.continue)
	check(scene.screen == "game" and scene.game.acquired.size() == 1 and scene.game.turn == 1, "Continue restores saved game")
	await click(scene.buttons.end_turn)
	check(scene.game.turn == 2 and scene.game.selected_group == -1 and not scene.game.can_undo(), "End turn refreshes market and clears undo")
	await click(scene.buttons.refresh)
	await click(scene.faceup_regions[1])
	check(scene.game.refreshed, "Skipped-draft card refresh works")
	while scene.game.acquired.size() < 5 and not scene.game.deck.is_empty():
		var extra = scene.game.deck.pop_back()
		extra["cubes"] = 0
		scene.game.acquired.append(extra)
	await frames()
	check(scene.buttons.has("hand_next"), "Owned-card paging appears for five cards")
	await click(scene.buttons.hand_next)
	check(scene.hand_page == 1, "Owned-card next page works")
	await click(scene.buttons.hand_prev)
	check(scene.hand_page == 0, "Owned-card previous page works")
	await click(scene.buttons.pause)
	check(scene.overlay == "pause", "Pause opens")
	check_buttons("Pause")
	await click(scene.buttons.resume)
	check(scene.overlay.is_empty(), "Resume works")
	await click(scene.buttons.pause)
	await click(scene.buttons.home)
	check(scene.screen == "home", "Pause returns to main menu")
	await click(scene.buttons.help)
	check(scene.screen == "help", "Help opens")
	check_buttons("Help")
	await click(scene.buttons.help_next)
	await click(scene.buttons.help_next)
	check(scene.help_page == 2, "Help paging works")
	await click(scene.buttons.home)
	await click(scene.buttons.records)
	check(scene.screen == "records", "Records open")
	check_buttons("Records")
	await click(scene.buttons.home)
	var sound_before = scene.sound_enabled
	await click(scene.buttons.sound)
	check(scene.sound_enabled != sound_before, "Sound toggle works")
	check_buttons("Final home")
	for player in scene.audio.values():
		player.stop()
	scene.queue_free()
	await frames()
	print("Eco Masters UI %dx%d: %d checks, %d failures" % [root.size.x, root.size.y, checks, failures])
	quit(0 if failures == 0 else 1)
