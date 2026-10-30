extends SceneTree

var failures = 0
var checks = 0
var scene

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("UI FAIL: ", message)

func click(id: String) -> void:
	await settle()
	check(scene.buttons.has(id), "Button exists: " + id)
	if scene.buttons.has(id):
		var rect: Rect2 = scene.buttons[id]
		scene._handle_click(rect.get_center())
		await settle()

func settle() -> void:
	for i in range(4):
		await process_frame

func check_buttons(label: String) -> void:
	var view = scene._view_size()
	for id in scene.buttons.keys():
		var rect: Rect2 = scene.buttons[id]
		check(rect.size.x >= 44 and rect.size.y >= 44, "%s touch target %s is at least 44 logical px" % [label, id])
		check(rect.position.x >= -0.1 and rect.position.y >= -0.1 and rect.end.x <= view.x + 0.1 and rect.end.y <= view.y + 0.1, "%s button %s stays on screen" % [label, id])

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await settle()
	check(scene.regular != null and scene.bold != null, "Bundled fonts loaded")
	check(scene.screen == "home", "Home shown")
	check(scene.ui_scale >= 1.0, "Responsive UI scale initialized")
	check_buttons("home")
	await click("dark")
	check(scene.dark_mode, "Dark mode toggles on")
	await click("dark")
	check(not scene.dark_mode, "Dark mode toggles off")
	await click("new")
	check(scene.screen == "setup", "Setup shown")
	check_buttons("setup")
	await click("spirit_toggle")
	await click("begin")
	check(scene.screen == "game" and not scene.game.spirit_enabled, "Game starts without spirit")
	check(scene.game.market.size() == 3 and scene.game.faceup.size() == 3, "Market and cards drawn")
	check_buttons("game")
	check(scene.buttons.has("score") and scene.buttons.has("undo"), "Score and undo controls visible")
	await click("market_0")
	check(scene.game.selected_group == 0, "Market group selected")
	await click("undo")
	check(scene.game.selected_group == -1, "Undo market selection")
	await click("market_0")
	var first = scene.board_hit[0]
	scene._handle_click(first.center)
	await settle()
	check(scene.game.selected_tokens.size() == 2, "Token placed through real hit region")
	await click("undo")
	check(scene.game.selected_tokens.size() == 3 and scene.game.board[first.cell].is_empty(), "Undo token placement through UI")
	var placed = 0
	for item in scene.board_hit:
		scene._handle_click(item.center)
		await settle()
		placed += 1
		if scene.game.selected_tokens.is_empty(): break
	check(scene.game.selected_tokens.is_empty(), "All selected tokens placed")
	await click("detail_0")
	check(not scene.detail_card.is_empty(), "Card detail shown")
	check(scene.buttons.has("draft_0"), "Draft available")
	await click("draft_0")
	check(scene.game.acquired.size() == 1, "Card drafted through detail")
	await click("score")
	check(scene.screen == "score", "Live score overlay opens")
	check_buttons("score")
	await click("close_score")
	check(scene.screen == "game", "Live score overlay closes")
	await click("pause")
	check(scene.screen == "pause", "Pause shown")
	check_buttons("pause")
	await click("save_home")
	check(scene.screen == "home" and scene.saved_game_available, "Save and main menu shows Continue")
	check_buttons("home_saved")
	await click("continue")
	check(scene.screen == "game" and scene.game.turn == 1 and scene.game.acquired.size() == 1, "Continue restores saved game")
	await click("end")
	check(scene.game.turn == 2, "End turn works")
	check(not scene.game.can_undo(), "Undo unavailable across turn boundary")
	await click("detail_1")
	check(scene.buttons.has("refresh_1"), "Refresh available when not drafted")
	await click("refresh_1")
	check(scene.game.refreshed, "Refresh updates state")
	for i in range(5):
		var card = EcoRules.card_by_id(i + 1).duplicate(true)
		card["cubes"] = 0
		scene.game.acquired.append(card)
	scene.hand_page = 0
	await settle()
	check(scene.buttons.has("hand_next"), "Owned card pager appears")
	await click("hand_next")
	check(scene.hand_page == 1, "Owned card pager advances")
	await click("hand_prev")
	check(scene.hand_page == 0, "Owned card pager returns")
	await click("pause")
	await click("resume")
	check(scene.screen == "game", "Resume works")
	scene._handle_back()
	check(scene.screen == "pause", "Android back opens pause")
	await click("help")
	check(scene.screen == "help", "Help shown")
	check_buttons("help")
	await click("home")
	await click("records")
	check(scene.screen == "records", "Records shown")
	check_buttons("records")
	await click("home")
	await click("sound")
	check(not scene.sound_enabled, "Sound toggles")
	for player in scene.audio.values(): player.stop()
	print("Eco Masters UI ", root.size, ": ", checks, " checks, ", failures, " failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)

