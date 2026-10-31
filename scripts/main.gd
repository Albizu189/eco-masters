extends Node2D

const SAVE_PATH = "user://saved_game.json"

var screen = "home"
var overlay = ""
var game = EcoGame.new()
var spirit_enabled = true
var sound_enabled = true
var dark_mode = false
var ui_scale = 1.0
var buttons: Dictionary = {}
var disabled_buttons: Dictionary = {}
var cell_regions: Dictionary = {}
var market_regions: Array = []
var faceup_regions: Array = []
var active_regions: Dictionary = {}
var mode = "token"
var selected_token_index = 0
var selected_card_id = 0
var detail_card: Dictionary = {}
var detail_source = ""
var toast = ""
var toast_time = 0.0
var fade = 0.0
var clock = 0.0
var animations: Array = []
var help_page = 0
var hand_page = 0
var record_saved = false
var records: Dictionary = {}
var audio: Dictionary = {}
var rng = RandomNumberGenerator.new()
var saved_game_available = false
var saved_summary: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	_load_settings()
	_load_records()
	_refresh_saved_summary()
	for sound_name in ["tap", "place", "complete", "finish"]:
		var player = AudioStreamPlayer.new()
		player.stream = _make_sound(sound_name)
		add_child(player)
		audio[sound_name] = player
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	fade = maxf(0.0, fade - delta * 2.8)
	toast_time = maxf(0.0, toast_time - delta)
	for item in animations:
		item.age += delta
	animations = animations.filter(func(item): return item.age < 0.7)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position / ui_scale)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_handle_back()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_game()

func _exit_tree() -> void:
	_save_game()

func _handle_back() -> void:
	if overlay == "spirit":
		_go_home()
	elif not overlay.is_empty():
		overlay = ""
	elif screen == "game":
		overlay = "pause"
		_save_game()
	elif screen != "home":
		_change_screen("home")

func _change_screen(next_screen: String) -> void:
	screen = next_screen
	overlay = ""
	fade = 0.65
	_play("tap")

func _go_home() -> void:
	_save_game()
	_refresh_saved_summary()
	_change_screen("home")

func start_game(side: String) -> void:
	game.new_game(side, spirit_enabled)
	mode = "token"
	selected_token_index = 0
	selected_card_id = 0
	hand_page = 0
	record_saved = false
	animations.clear()
	_change_screen("game")
	if spirit_enabled:
		overlay = "spirit"
	_save_game()
	_show_toast("Choose a token group to begin" if not spirit_enabled else "Choose your Nature’s Spirit")

func continue_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_refresh_saved_summary()
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_delete_save()
		_show_toast("The saved game could not be read")
		return
	var restored = EcoGame.new()
	if not restored.load_dict(parsed) or restored.ended:
		_delete_save()
		_show_toast("The saved game is not compatible")
		return
	game = restored
	spirit_enabled = game.spirit_enabled
	mode = "token"
	selected_token_index = 0
	selected_card_id = 0
	hand_page = 0
	record_saved = false
	animations.clear()
	_change_screen("game")
	if game.spirit_enabled and game.spirit.is_empty() and not game.spirit_options.is_empty():
		overlay = "spirit"
	_show_toast("Welcome back · Side %s · Turn %d" % [game.side, game.turn])

func _save_game() -> void:
	if game.board.is_empty() or game.ended:
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(game.to_dict()))
		saved_game_available = true
		saved_summary = {"side": game.side, "turn": game.turn}

func _delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	saved_game_available = false
	saved_summary.clear()

func _refresh_saved_summary() -> void:
	saved_game_available = false
	saved_summary.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and int(parsed.get("save_version", 0)) == EcoGame.SAVE_VERSION and not bool(parsed.get("ended", false)):
		saved_game_available = true
		saved_summary = {"side": str(parsed.get("side", "A")), "turn": int(parsed.get("turn", 1))}

func _show_toast(message: String) -> void:
	toast = message
	toast_time = 3.0

func _play(sound_name: String) -> void:
	if sound_enabled and audio.has(sound_name) and audio[sound_name].stream != null:
		audio[sound_name].stop()
		audio[sound_name].play()

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		sound_enabled = bool(config.get_value("audio", "enabled", true))
		dark_mode = bool(config.get_value("display", "dark", false))
	EcoArt.set_dark_mode(dark_mode)

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "enabled", sound_enabled)
	config.set_value("display", "dark", dark_mode)
	config.save("user://settings.cfg")

func _default_records() -> Dictionary:
	return {
		"A": {"best_score": 0, "best_suns": 0, "games": 0},
		"B": {"best_score": 0, "best_suns": 0, "games": 0},
		"history": []
	}

func _load_records() -> void:
	records = _default_records()
	if not FileAccess.file_exists("user://records.json"):
		return
	var file = FileAccess.open("user://records.json", FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in ["A", "B"]:
			if parsed.has(key):
				records[key] = parsed[key]
		if parsed.has("history") and parsed.history is Array:
			records.history = parsed.history

func _save_result(result: Dictionary) -> void:
	if record_saved:
		return
	record_saved = true
	var side_record: Dictionary = records[game.side]
	side_record.games = int(side_record.get("games", 0)) + 1
	side_record.best_score = maxi(int(side_record.get("best_score", 0)), int(result.total))
	side_record.best_suns = maxi(int(side_record.get("best_suns", 0)), int(result.suns))
	records[game.side] = side_record
	var history_entry = {"side": game.side, "score": int(result.total), "suns": int(result.suns), "turns": game.turn}
	records.history.push_front(history_entry)
	records.history = records.history.slice(0, 5)
	var file = FileAccess.open("user://records.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "  "))
	_delete_save()
	_play("finish")

func _update_scale() -> void:
	var physical = get_viewport_rect().size
	if physical.x > physical.y and physical.y < 600:
		# Compact landscape needs a shorter logical canvas so controls remain legible.
		ui_scale = clampf(physical.y / 320.0, 1.0, 1.8)
	else:
		ui_scale = clampf(minf(physical.x / 390.0, physical.y / 640.0), 1.0, 3.0)

func _view_size() -> Vector2:
	return get_viewport_rect().size / ui_scale

func _panel(alpha: float = 0.65) -> Color:
	return Color(0.12, 0.19, 0.16, alpha) if dark_mode else Color(1, 1, 1, alpha)

func _soft() -> Color:
	return Color("263b35") if dark_mode else Color("e2eadc")

func _board_color() -> Color:
	return Color("1b2a26") if dark_mode else Color("e8e8d9")

func _cell_color() -> Color:
	return Color("2a3a35") if dark_mode else Color("f4f1e5")

func _draw() -> void:
	_update_scale()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
	buttons.clear()
	disabled_buttons.clear()
	cell_regions.clear()
	market_regions.clear()
	faceup_regions.clear()
	active_regions.clear()
	_draw_background()
	match screen:
		"home": _draw_home()
		"game": _draw_game()
		"results": _draw_results()
		"records": _draw_records()
		"help": _draw_help()
	if not overlay.is_empty():
		buttons.clear()
		disabled_buttons.clear()
		cell_regions.clear()
		market_regions.clear()
		faceup_regions.clear()
		active_regions.clear()
		_draw_overlay()
	if toast_time > 0.0 and overlay.is_empty():
		_draw_toast()
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _view_size()), Color(0.03, 0.08, 0.06, fade))

func _draw_background() -> void:
	var size = _view_size()
	draw_rect(Rect2(Vector2.ZERO, size), EcoArt.CREAM)
	draw_circle(Vector2(size.x * 0.93, size.y * 0.08), minf(size.x, size.y) * 0.24, Color("20352e") if dark_mode else Color("e3ecdb"))
	draw_circle(Vector2(size.x * 0.03, size.y * 0.96), minf(size.x, size.y) * 0.2, Color("302d22") if dark_mode else Color("eee3ca"))
	for i in range(6):
		var p = Vector2(size.x - 30 - i * 22, 25 + (i % 2) * 14)
		draw_circle(p, 2.5, EcoArt.MUTED)

func _button(id: String, rect: Rect2, label: String, style: String = "primary", enabled: bool = true, font_size: int = 18) -> void:
	buttons[id] = rect
	if not enabled:
		disabled_buttons[id] = true
	var fill = Color("2f6d5a") if not dark_mode else Color("397d62")
	var ink = Color.WHITE
	if style == "secondary":
		fill = _soft()
		ink = EcoArt.INK
	elif style == "ghost":
		fill = _panel(0.45)
		ink = EcoArt.INK
	elif style == "gold":
		fill = EcoArt.GOLD
		ink = Color("203b35")
	if not enabled:
		fill = Color("34413c") if dark_mode else Color("d9ddd3")
		ink = Color("84958b") if dark_mode else Color("89958b")
	EcoArt.rounded(self, rect, fill, mini(14, int(rect.size.y * 0.25)), EcoArt.MUTED if style == "ghost" else Color.TRANSPARENT, 1 if style == "ghost" else 0)
	EcoArt.fitted_text(self, label, Rect2(rect.position + Vector2(5, (rect.size.y - font_size) * 0.5), Vector2(rect.size.x - 10, font_size + 3)), font_size, ink, true)

func _heading(label: String, position: Vector2, size: int = 15) -> void:
	EcoArt.text(self, label, position, size, EcoArt.MUTED)

func _draw_home() -> void:
	var size = _view_size()
	var portrait = size.y > size.x
	_button("dark", Rect2(size.x - 142, 14, 58, 48), "DARK" if not dark_mode else "LIGHT", "ghost", true, 10)
	_button("sound", Rect2(size.x - 76, 14, 62, 48), "SOUND" if sound_enabled else "MUTED", "ghost", true, 10)
	if portrait:
		EcoArt.leaf(self, Vector2(size.x * 0.5, size.y * 0.15), 1.65, EcoArt.GREEN)
		EcoArt.text_center(self, "ECO", Vector2(size.x * 0.5, size.y * 0.28), 52, EcoArt.INK)
		EcoArt.text_center(self, "MASTERS", Vector2(size.x * 0.5, size.y * 0.28 + 54), 52, EcoArt.GREEN)
		EcoArt.text_center(self, "A quiet world, built one habitat at a time.", Vector2(size.x * 0.5, size.y * 0.28 + 84), 14, EcoArt.MUTED)
		var w = minf(360, size.x - 42)
		var x = (size.x - w) * 0.5
		var y = size.y * (0.41 if saved_game_available else 0.47)
		if saved_game_available:
			_button("continue", Rect2(x, y, w, 54), "CONTINUE  ·  SIDE %s  ·  TURN %d" % [saved_summary.get("side", "A"), int(saved_summary.get("turn", 1))], "gold", true, 15)
			y += 64
		_button("play_a", Rect2(x, y, w, 54), "NEW SOLO  ·  SIDE A", "primary", true, 17)
		_button("play_b", Rect2(x, y + 64, w, 54), "NEW SOLO  ·  SIDE B", "secondary", true, 17)
		_button("spirit", Rect2(x, y + 126, w, 46), "NATURE’S SPIRIT  ·  " + ("ON" if spirit_enabled else "OFF"), "ghost", true, 14)
		_button("records", Rect2(x, y + 182, w * 0.48, 48), "RECORDS", "ghost", true, 14)
		_button("help", Rect2(x + w * 0.52, y + 182, w * 0.48, 48), "HOW TO PLAY", "ghost", true, 14)
	elif size.y < 600:
		var left = maxf(30, size.x * 0.05)
		var w = minf(330, size.x * 0.43)
		EcoArt.text(self, "ECO MASTERS", Vector2(left, 47), 30, EcoArt.INK)
		EcoArt.text(self, "Grow landscapes. Welcome wildlife.", Vector2(left, 66), 12, EcoArt.MUTED)
		var y = 78.0 if saved_game_available else 102.0
		if saved_game_available:
			_button("continue", Rect2(left, y, w, 44), "CONTINUE · SIDE %s · TURN %d" % [saved_summary.get("side", "A"), int(saved_summary.get("turn", 1))], "gold", true, 13)
			y += 48
		_button("play_a", Rect2(left, y, w, 44), "NEW SOLO · SIDE A", "primary", true, 15)
		_button("play_b", Rect2(left, y + 48, w, 44), "NEW SOLO · SIDE B", "secondary", true, 15)
		_button("spirit", Rect2(left, y + 96, w, 44), "NATURE’S SPIRIT · " + ("ON" if spirit_enabled else "OFF"), "ghost", true, 12)
		_button("records", Rect2(left, y + 144, w * 0.48, 44), "RECORDS", "ghost", true, 12)
		_button("help", Rect2(left + w * 0.52, y + 144, w * 0.48, 44), "HOW TO PLAY", "ghost", true, 12)
		_draw_home_hero(Rect2(size.x * 0.58, 58, size.x * 0.35, size.y - 78))
	else:
		var left = maxf(56, size.x * 0.08)
		EcoArt.leaf(self, Vector2(left + 34, 70), 0.8, EcoArt.GREEN)
		EcoArt.text(self, "ECO MASTERS", Vector2(left, 158), 54, EcoArt.INK)
		EcoArt.text(self, "Grow landscapes. Welcome wildlife.", Vector2(left, 192), 19, EcoArt.MUTED)
		var w = minf(380, size.x * 0.36)
		var y = 230.0
		if saved_game_available:
			_button("continue", Rect2(left, y, w, 52), "CONTINUE · SIDE %s · TURN %d" % [saved_summary.get("side", "A"), int(saved_summary.get("turn", 1))], "gold", true, 15)
			y += 62
		_button("play_a", Rect2(left, y, w, 54), "NEW SOLO · SIDE A", "primary")
		_button("play_b", Rect2(left, y + 64, w, 54), "NEW SOLO · SIDE B", "secondary")
		_button("spirit", Rect2(left, y + 126, w, 46), "NATURE’S SPIRIT · " + ("ON" if spirit_enabled else "OFF"), "ghost", true, 14)
		_button("records", Rect2(left, y + 182, w * 0.48, 48), "RECORDS", "ghost", true, 14)
		_button("help", Rect2(left + w * 0.52, y + 182, w * 0.48, 48), "HOW TO PLAY", "ghost", true, 14)
		_draw_home_hero(Rect2(size.x * 0.53, size.y * 0.18, size.x * 0.4, size.y * 0.65))
	if size.y >= 600:
		EcoArt.text(self, "Version 1.1 · Original digital adaptation · Godot 4", Vector2(20, size.y - 18), 12, EcoArt.MUTED)

func _draw_home_hero(rect: Rect2) -> void:
	EcoArt.rounded(self, rect, _soft(), 32)
	var center = rect.get_center() + Vector2(0, -12)
	var cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1)]
	var names = ["tree", "water", "field", "mountain", "building", "trunk", "water"]
	for i in range(cells.size()):
		var cell: Vector2i = cells[i]
		var p = center + Vector2(1.5 * cell.x, sqrt(3.0) * (cell.y + cell.x * 0.5)) * minf(55, rect.size.x * 0.1)
		EcoArt.token(self, names[i], p, minf(50, rect.size.x * 0.09))
	EcoArt.text_center(self, "YOUR LITTLE WILDERNESS", Vector2(center.x, rect.end.y - 28), 14, EcoArt.MUTED)

func _game_layout() -> Dictionary:
	var size = _view_size()
	var portrait = size.y > size.x * 1.05
	if portrait:
		var active_height = clampf(size.y * 0.18, 116, 154)
		var faceup_height = clampf(size.y * 0.17, 118, 154)
		var active = Rect2(8, size.y - active_height - 8, size.x - 16, active_height)
		var faceup = Rect2(8, active.position.y - faceup_height - 4, size.x - 16, faceup_height)
		var market = Rect2(8, faceup.position.y - 92, size.x - 16, 88)
		var hint = Rect2(8, market.position.y - 64, size.x - 16, 60)
		var board = Rect2(8, 70, size.x - 16, maxf(88, hint.position.y - 74))
		return {"portrait": true, "compact": false, "board": board, "hint": hint, "market": market, "faceup": faceup, "active": active, "right": Rect2()}
	var left_width = size.x * 0.59
	if size.y < 600:
		var market_height = clampf(size.y * 0.24, 76, 88)
		var faceup_height = minf(clampf(size.y * 0.34, 96, 128), size.y - market_height - 146)
		var faceup_y = 70 + market_height + 4
		var hint_y = faceup_y + faceup_height + 4
		return {
			"portrait": false, "compact": true,
			"board": Rect2(12, 70, left_width - 24, size.y - 184),
			"right": Rect2(left_width + 4, 70, size.x - left_width - 16, size.y - 78),
			"market": Rect2(left_width + 4, 70, size.x - left_width - 16, market_height),
			"faceup": Rect2(left_width + 4, faceup_y, size.x - left_width - 16, faceup_height),
			"hint": Rect2(left_width + 4, hint_y, size.x - left_width - 16, maxf(60, size.y - hint_y - 8)),
			"active": Rect2(12, size.y - 106, left_width - 24, 98)
		}
	return {
		"portrait": false, "compact": false,
		"board": Rect2(18, 76, left_width - 30, size.y - 228),
		"right": Rect2(left_width + 4, 76, size.x - left_width - 20, size.y - 88),
		"market": Rect2(left_width + 4, 76, size.x - left_width - 20, 108),
		"faceup": Rect2(left_width + 4, 190, size.x - left_width - 20, 166),
		"hint": Rect2(left_width + 4, 362, size.x - left_width - 20, maxf(88, size.y - 450)),
		"active": Rect2(16, size.y - 144, left_width - 28, 136)
	}

func _draw_game() -> void:
	var size = _view_size()
	var layout = _game_layout()
	var current = game.score()
	EcoArt.rounded(self, Rect2(10, 10, size.x - 20, 52), _panel(0.66), 16)
	_button("pause", Rect2(18, 14, 48, 44), "II", "ghost", true, 18)
	EcoArt.text(self, "ECO · " + game.side if size.x < 600 else "ECO MASTERS", Vector2(76, 42), 18 if size.x < 600 else 21, EcoArt.INK)
	_button("score", Rect2(size.x * 0.42, 14, 104, 44), "%d PTS" % int(current.total), "ghost", true, 16)
	EcoArt.text(self, "POUCH %d" % game.bag.size(), Vector2(size.x - (142 if size.x < 600 else 238), 41), 11, EcoArt.MUTED)
	EcoArt.text(self, "OPEN %d" % game.empty_cells(), Vector2(size.x - (74 if size.x < 600 else 130), 41), 11, EcoArt.MUTED)
	_draw_board(layout.board)
	_draw_market(layout.market)
	_draw_faceup(layout.faceup)
	_draw_active(layout.active)
	_draw_turn_controls(layout.hint, layout.portrait or layout.compact)

func _draw_board(rect: Rect2) -> void:
	EcoArt.rounded(self, rect, _board_color(), 22)
	var cells = EcoRules.board_cells(game.side)
	var base_radius = 54.0
	var minimum = Vector2(INF, INF)
	var maximum = Vector2(-INF, -INF)
	var projected: Dictionary = {}
	for cell in cells:
		var p = Vector2(1.5 * cell.x, sqrt(3.0) * (cell.y + cell.x * 0.5)) * base_radius
		projected[cell] = p
		minimum.x = minf(minimum.x, p.x - base_radius)
		minimum.y = minf(minimum.y, p.y - base_radius * 0.9)
		maximum.x = maxf(maximum.x, p.x + base_radius)
		maximum.y = maxf(maximum.y, p.y + base_radius * 0.9)
	var base_size = maximum - minimum
	var scale_factor = minf(rect.size.x / base_size.x, rect.size.y / base_size.y)
	scale_factor = minf(scale_factor, 1.2)
	var origin = rect.position + (rect.size - base_size * scale_factor) * 0.5 - minimum * scale_factor
	var radius = base_radius * scale_factor
	var targets: Array = []
	if mode == "cube" and selected_card_id > 0:
		targets = game.available_cube_cells(selected_card_id)
	var selected_token = ""
	if not game.selected_tokens.is_empty():
		selected_token_index = clampi(selected_token_index, 0, game.selected_tokens.size() - 1)
		selected_token = game.selected_tokens[selected_token_index]
	for cell in cells:
		var center: Vector2 = origin + projected[cell] * scale_factor
		cell_regions[cell] = Rect2(center - Vector2(maxf(radius * 0.86, 22), maxf(radius * 0.8, 22)), Vector2(maxf(radius * 1.72, 44), maxf(radius * 1.6, 44)))
		EcoArt.hex(self, center + Vector2(0, radius * 0.1), radius * 0.94, Color("0d1714") if dark_mode else Color("c5c9b8"))
		EcoArt.hex(self, center, radius * 0.92, _cell_color(), EcoArt.MUTED, maxf(1.0, scale_factor * 1.5))
		var stack: Array = game.board[cell]
		for i in range(stack.size()):
			EcoArt.token(self, stack[i], center - Vector2(0, i * radius * 0.16), radius * 0.84)
		if game.cubes.has(cell):
			var cube_center = center - Vector2(0, maxf(0, stack.size() - 1) * radius * 0.16 + radius * 0.25)
			EcoArt.cube(self, cube_center, int(game.cubes[cell]) > 32, scale_factor)
		var legal = false
		var highlight = EcoArt.GREEN
		if not selected_token.is_empty() and mode == "token":
			legal = EcoRules.can_place(game.board, game.cubes, cell, selected_token)
		elif targets.has(cell):
			legal = true
			highlight = EcoArt.GOLD
		if legal:
			var pulse = 0.7 + sin(clock * 5.0) * 0.2
			EcoArt.hex(self, center, radius * 0.95, Color(0, 0, 0, 0), Color(highlight, pulse), maxf(3.0, radius * 0.08))
	for item in animations:
		if item.has("cell"):
			var center: Vector2 = origin + projected[item.cell] * scale_factor
			var progress: float = item.age / 0.7
			draw_arc(center, radius * (0.4 + progress), 0, TAU, 32, Color(EcoArt.GOLD, 1.0 - progress), 3.0, true)

func _draw_market(rect: Rect2) -> void:
	_heading("TOKEN MARKET · CHOOSE ONE GROUP", rect.position + Vector2(4, 13), 11)
	market_regions.clear()
	var gap = 8.0
	var group_width = (rect.size.x - gap * 2) / 3.0
	for i in range(3):
		var group_rect = Rect2(rect.position + Vector2(i * (group_width + gap), 22), Vector2(group_width, rect.size.y - 25))
		market_regions.append(group_rect)
		var selected = game.selected_group == i
		var unavailable = game.selected_group >= 0 and not selected
		var fill = EcoArt.LIGHT_GREEN if selected else _panel(0.62)
		EcoArt.rounded(self, group_rect, fill, 12, EcoArt.GREEN if selected else EcoArt.MUTED, 2 if selected else 1)
		var tokens: Array = game.market[i] if i < game.market.size() else []
		var radius = minf(23.0, group_width / 7.2)
		for j in range(tokens.size()):
			var center = group_rect.position + Vector2(group_width * (j + 0.5) / 3.0, group_rect.size.y * 0.52)
			EcoArt.token(self, tokens[j], center, radius, selected)
			if unavailable:
				draw_circle(center, radius, Color(0.1, 0.15, 0.12, 0.35))

func _draw_faceup(rect: Rect2) -> void:
	_heading("AVAILABLE HABITATS · DRAFT UP TO ONE EACH TURN", rect.position + Vector2(4, 13), 10)
	faceup_regions.clear()
	var gap = 7.0
	var card_width = (rect.size.x - gap * 2) / 3.0
	for i in range(game.faceup.size()):
		var card_rect = Rect2(rect.position + Vector2(i * (card_width + gap), 21), Vector2(card_width, rect.size.y - 23))
		faceup_regions.append(card_rect)
		var data: Dictionary = game.faceup[i]
		if data.is_empty():
			EcoArt.rounded(self, card_rect, _soft(), 10)
			EcoArt.text_center(self, "DECK EMPTY", card_rect.get_center(), 11, EcoArt.MUTED)
			continue
		_draw_small_card(data, card_rect, mode == "refresh", false)

func _draw_small_card(data: Dictionary, rect: Rect2, highlighted: bool = false, owned: bool = false) -> void:
	var available = game.available_cube_cells(int(data.id)).size() if owned else 0
	var border = EcoArt.GOLD if highlighted else (EcoArt.GREEN if available > 0 else EcoArt.MUTED)
	EcoArt.rounded(self, Rect2(rect.position + Vector2(0, 3), rect.size), Color(0.02, 0.06, 0.04, 0.22), 10)
	EcoArt.rounded(self, rect, EcoArt.PAPER, 10, border, 2 if highlighted or available > 0 else 1)
	var header = Rect2(rect.position, Vector2(rect.size.x, 29))
	EcoArt.rounded(self, header, Color("2f6d5a") if data.kind == "animal" else Color("756345"), 9)
	var icon_radius = minf(11, rect.size.y * 0.1)
	EcoArt.animal_icon(self, int(data.id), rect.position + Vector2(17, 14), icon_radius, Color.WHITE)
	EcoArt.fitted_text(self, data.name.to_upper(), Rect2(rect.position + Vector2(32, 6), Vector2(rect.size.x - 37, 18)), 11, Color.WHITE)
	var pattern_radius = minf(13, minf(rect.size.x * 0.1, rect.size.y * 0.105))
	EcoArt.pattern(self, data, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.52), pattern_radius)
	if owned:
		var max_cubes = 1 if data.kind == "spirit" else data.scores.size()
		var score_label = "%d PTS · %d/%d" % [game.card_points(data), int(data.get("cubes", 0)), max_cubes]
		EcoArt.fitted_text(self, score_label, Rect2(rect.position + Vector2(4, rect.size.y - 20), Vector2(rect.size.x - 8, 15)), 11, EcoArt.GOLD, true)
	else:
		var scores = " · ".join(data.scores.map(func(value): return str(value)))
		EcoArt.fitted_text(self, scores, Rect2(rect.position + Vector2(4, rect.size.y - 20), Vector2(rect.size.x - 8, 15)), 11, EcoArt.MUTED, true)

func _hand_cards() -> Array:
	var cards: Array = []
	if not game.spirit.is_empty():
		cards.append(game.spirit)
	cards.append_array(game.acquired)
	return cards

func _draw_active(rect: Rect2) -> void:
	var cards = _hand_cards()
	_heading("YOUR HABITATS · %d/4 ACTIVE · LIVE CARD POINTS" % game.active_count(), rect.position + Vector2(4, 13), 10)
	active_regions.clear()
	if cards.is_empty():
		EcoArt.rounded(self, Rect2(rect.position + Vector2(0, 21), Vector2(rect.size.x, rect.size.y - 23)), _panel(0.38), 10)
		EcoArt.text_center(self, "Draft an animal card to start building habitats", rect.position + Vector2(rect.size.x * 0.5, 58), 13, EcoArt.MUTED)
		return
	var per_page = 4 if rect.size.x > 520 else 3
	var pages = maxi(1, int(ceil(float(cards.size()) / per_page)))
	hand_page = clampi(hand_page, 0, pages - 1)
	var paged = pages > 1
	var content = Rect2(rect.position + Vector2(50 if paged else 0, 21), Vector2(rect.size.x - (100 if paged else 0), rect.size.y - 23))
	if paged:
		_button("hand_prev", Rect2(rect.position + Vector2(0, 43), Vector2(44, 44)), "<", "ghost", hand_page > 0, 20)
		_button("hand_next", Rect2(rect.end - Vector2(44, rect.size.y - 43), Vector2(44, 44)), ">", "ghost", hand_page < pages - 1, 20)
		EcoArt.text_center(self, "%d/%d" % [hand_page + 1, pages], rect.position + Vector2(rect.size.x - 25, 15), 10, EcoArt.MUTED)
	var start = hand_page * per_page
	var shown = cards.slice(start, mini(start + per_page, cards.size()))
	var gap = 6.0
	var card_width = (content.size.x - gap * (shown.size() - 1)) / shown.size()
	for i in range(shown.size()):
		var data: Dictionary = shown[i]
		var card_rect = Rect2(content.position + Vector2(i * (card_width + gap), 0), Vector2(card_width, content.size.y))
		active_regions[int(data.id)] = card_rect
		_draw_small_card(data, card_rect, mode == "cube" and selected_card_id == int(data.id), true)

func _draw_turn_controls(rect: Rect2, compact: bool) -> void:
	EcoArt.rounded(self, rect, _panel(0.5), 14)
	var end_enabled = game.selected_group >= 0 and game.selected_tokens.is_empty() and not game.ended
	if compact:
		var end_rect = Rect2(rect.end.x - 102, rect.position.y + 6, 96, 48)
		_button("end_turn", end_rect, "END TURN", "gold", end_enabled, 13)
		_button("undo", Rect2(end_rect.position.x - 76, rect.position.y + 6, 70, 48), "UNDO", "ghost", game.can_undo(), 12)
		if not game.drafted and not game.refreshed and not game.deck.is_empty():
			_button("refresh", Rect2(end_rect.position.x - 126, rect.position.y + 6, 44, 48), "NEW", "ghost", true, 10)
		var message_rect = Rect2(rect.position + Vector2(8, 5), Vector2(maxf(44, rect.size.x - 238), 50))
		if not game.selected_tokens.is_empty():
			_draw_selected_tokens(message_rect)
		else:
			var message = "Choose one market group"
			if mode == "cube":
				message = "Tap a gold ring to place the cube"
			elif game.selected_group >= 0:
				message = "Place cubes or end your turn"
			EcoArt.fitted_text(self, message, Rect2(message_rect.position + Vector2(4, 14), Vector2(message_rect.size.x - 8, 25)), 12, EcoArt.MUTED)
	else:
		var message = "Choose one group of three tokens."
		if mode == "cube":
			message = "Tap a gold highlighted space to place your cube."
		elif game.selected_group >= 0 and not game.selected_tokens.is_empty():
			message = "Place all three tokens. Tap a token below to change its order."
		elif game.selected_group >= 0:
			message = "You may place habitat cubes, then end the turn."
		EcoArt.wrapped_text(self, message, Rect2(rect.position + Vector2(12, 8), Vector2(rect.size.x - 24, 46)), 13, EcoArt.MUTED)
		if not game.selected_tokens.is_empty():
			_draw_selected_tokens(Rect2(rect.position + Vector2(10, 52), Vector2(rect.size.x - 20, 46)))
		var button_y = rect.end.y - 52
		_button("end_turn", Rect2(rect.end.x - 104, button_y, 96, 46), "END TURN", "gold", end_enabled, 13)
		_button("undo", Rect2(rect.end.x - 184, button_y, 74, 46), "UNDO", "ghost", game.can_undo(), 12)
		if not game.drafted and not game.refreshed and not game.deck.is_empty():
			_button("refresh", Rect2(rect.end.x - 282, button_y, 92, 46), "NEW CARD", "ghost", true, 11)

func _draw_selected_tokens(rect: Rect2) -> void:
	var count = game.selected_tokens.size()
	var chip_width = minf(52, rect.size.x / maxf(1, count))
	for i in range(count):
		var chip = Rect2(rect.position + Vector2(i * chip_width, 0), Vector2(maxf(44, chip_width - 4), rect.size.y))
		buttons["token_%d" % i] = chip
		if mode == "token" and selected_token_index == i:
			EcoArt.rounded(self, chip, EcoArt.LIGHT_GREEN, 10, EcoArt.GREEN, 2)
		EcoArt.token(self, game.selected_tokens[i], chip.get_center(), minf(20, chip.size.y * 0.38), mode == "token" and selected_token_index == i)

func _draw_results() -> void:
	var size = _view_size()
	var result = game.score()
	var portrait = size.y > size.x
	if not portrait and size.y < 500:
		_draw_results_compact(result)
		return
	EcoArt.text_center(self, "YOUR ECOSYSTEM", Vector2(size.x * 0.5, 64), 16, EcoArt.MUTED)
	EcoArt.text_center(self, str(result.total), Vector2(size.x * 0.5, 142), 72, EcoArt.GREEN)
	EcoArt.text_center(self, "POINTS", Vector2(size.x * 0.5, 172), 14, EcoArt.MUTED)
	var sun_count = int(result.suns)
	var sun_spacing = 30.0
	var sun_start = size.x * 0.5 - (sun_count - 1) * sun_spacing * 0.5
	for i in range(sun_count):
		var p = Vector2(sun_start + i * sun_spacing, 207)
		draw_circle(p, 10, EcoArt.GOLD)
		for ray in range(8):
			var direction = Vector2.from_angle(ray * TAU / 8.0)
			draw_line(p + direction * 13, p + direction * 17, EcoArt.GOLD, 2, true)
	EcoArt.text_center(self, "%d SUNS · %d FROM SCORE + %d CONFIGURATION" % [result.suns, result.base_suns, result.configuration], Vector2(size.x * 0.5, 243), 13, EcoArt.MUTED)
	var panel = Rect2(20, 270, size.x - 40, maxf(190, size.y - 382))
	EcoArt.rounded(self, panel, _panel(0.62), 20)
	var labels = [["trees", "Trees"], ["mountains", "Mountains"], ["fields", "Fields"], ["buildings", "Buildings"], ["water", "Water / islands"], ["animals", "Animal cards"], ["spirit", "Nature’s Spirit"]]
	if portrait:
		for i in range(labels.size()):
			var y = panel.position.y + 34 + i * 34
			EcoArt.text(self, labels[i][1], Vector2(panel.position.x + 22, y), 17, EcoArt.INK)
			EcoArt.text(self, str(result[labels[i][0]]), Vector2(panel.end.x - 58, y), 18, EcoArt.GREEN)
	else:
		var column_width = panel.size.x * 0.5
		for i in range(labels.size()):
			var column = 0 if i < 4 else 1
			var row = i if i < 4 else i - 4
			var x = panel.position.x + 26 + column * column_width
			var y = panel.position.y + 42 + row * 48
			EcoArt.text(self, labels[i][1], Vector2(x, y), 18, EcoArt.INK)
			EcoArt.text(self, str(result[labels[i][0]]), Vector2(x + column_width - 68, y), 20, EcoArt.GREEN)
	var button_width = minf(240, (size.x - 58) * 0.5)
	_button("restart", Rect2(size.x * 0.5 - button_width - 7, size.y - 86, button_width, 56), "PLAY AGAIN", "primary")
	_button("home", Rect2(size.x * 0.5 + 7, size.y - 86, button_width, 56), "MAIN MENU", "secondary")
	EcoArt.text_center(self, game.end_reason, Vector2(size.x * 0.5, size.y - 102), 12, EcoArt.MUTED)

func _draw_records() -> void:
	var size = _view_size()
	if size.y < 500:
		_draw_records_compact()
		return
	EcoArt.text_center(self, "LOCAL RECORDS", Vector2(size.x * 0.5, 66), 32, EcoArt.INK)
	EcoArt.text_center(self, "Stored only on this device", Vector2(size.x * 0.5, 94), 14, EcoArt.MUTED)
	var width = minf(700, size.x - 36)
	var x = (size.x - width) * 0.5
	var card_width = (width - 14) * 0.5
	for i in range(2):
		var side = ["A", "B"][i]
		var data: Dictionary = records[side]
		var rect = Rect2(x + i * (card_width + 14), 122, card_width, 142)
		EcoArt.rounded(self, rect, _panel(0.65), 18)
		EcoArt.text_center(self, "SIDE " + side, rect.position + Vector2(rect.size.x * 0.5, 30), 15, EcoArt.MUTED)
		EcoArt.text_center(self, str(data.get("best_score", 0)), rect.position + Vector2(rect.size.x * 0.5, 80), 42, EcoArt.GREEN)
		EcoArt.text_center(self, "BEST · %d SUNS · %d GAMES" % [int(data.get("best_suns", 0)), int(data.get("games", 0))], rect.position + Vector2(rect.size.x * 0.5, 113), 11, EcoArt.MUTED)
	_heading("RECENT ECOSYSTEMS", Vector2(x + 4, 306), 13)
	var history: Array = records.history
	if history.is_empty():
		EcoArt.rounded(self, Rect2(x, 326, width, 116), _panel(0.45), 16)
		EcoArt.text_center(self, "Complete a solo game to grow your records.", Vector2(size.x * 0.5, 390), 16, EcoArt.MUTED)
	else:
		for i in range(history.size()):
			var item: Dictionary = history[i]
			var rect = Rect2(x, 322 + i * 52, width, 44)
			EcoArt.rounded(self, rect, _panel(0.5), 10)
			EcoArt.text(self, "SIDE " + str(item.get("side", "A")), rect.position + Vector2(16, 28), 14, EcoArt.MUTED)
			EcoArt.text(self, "%d points" % int(item.get("score", 0)), rect.position + Vector2(width * 0.38, 28), 16, EcoArt.INK)
			EcoArt.text(self, "%d suns" % int(item.get("suns", 0)), rect.position + Vector2(width * 0.72, 28), 16, EcoArt.GOLD)
	_button("home", Rect2(size.x * 0.5 - 110, size.y - 76, 220, 50), "MAIN MENU", "secondary")

func _draw_records_compact() -> void:
	var size = _view_size()
	EcoArt.text_center(self, "LOCAL RECORDS · STORED ON THIS DEVICE", Vector2(size.x * 0.5, 34), 22, EcoArt.INK)
	var width = minf(700, size.x - 36)
	var x = (size.x - width) * 0.5
	var card_width = (width - 14) * 0.5
	for i in range(2):
		var side = ["A", "B"][i]
		var data: Dictionary = records[side]
		var rect = Rect2(x + i * (card_width + 14), 54, card_width, 90)
		EcoArt.rounded(self, rect, _panel(0.65), 14)
		EcoArt.text(self, "SIDE " + side, rect.position + Vector2(16, 25), 13, EcoArt.MUTED)
		EcoArt.text(self, str(data.get("best_score", 0)), rect.position + Vector2(16, 66), 32, EcoArt.GREEN)
		EcoArt.fitted_text(self, "BEST · %d SUNS · %d GAMES" % [int(data.get("best_suns", 0)), int(data.get("games", 0))], Rect2(rect.position + Vector2(82, 43), Vector2(rect.size.x - 96, 24)), 12, EcoArt.MUTED)
	_heading("RECENT ECOSYSTEMS", Vector2(x + 4, 169), 12)
	var history: Array = records.history
	if history.is_empty():
		EcoArt.text(self, "Complete a solo game to grow your records.", Vector2(x + 4, 202), 14, EcoArt.MUTED)
	else:
		for i in range(mini(2, history.size())):
			var item: Dictionary = history[i]
			var rect = Rect2(x, 180 + i * 38, width, 34)
			EcoArt.rounded(self, rect, _panel(0.5), 8)
			EcoArt.text(self, "SIDE " + str(item.get("side", "A")), rect.position + Vector2(12, 23), 12, EcoArt.MUTED)
			EcoArt.text(self, "%d points" % int(item.get("score", 0)), rect.position + Vector2(width * 0.4, 23), 13, EcoArt.INK)
			EcoArt.text(self, "%d suns" % int(item.get("suns", 0)), rect.position + Vector2(width * 0.74, 23), 13, EcoArt.GOLD)
	_button("home", Rect2(size.x * 0.5 - 110, size.y - 54, 220, 44), "MAIN MENU", "secondary", true, 14)

func _draw_help() -> void:
	var size = _view_size()
	if size.y < 500:
		_draw_help_compact()
		return
	var width = minf(760, size.x - 34)
	var rect = Rect2((size.x - width) * 0.5, 28, width, size.y - 112)
	EcoArt.rounded(self, rect, _panel(0.78), 22)
	var titles = ["BUILD YOUR LANDSCAPE", "WELCOME WILDLIFE", "SCORE & SOLO SUNS"]
	EcoArt.text_center(self, titles[help_page], Vector2(size.x * 0.5, rect.position.y + 48), 25, EcoArt.GREEN)
	var content: Array = []
	if help_page == 0:
		content = [
			["1", "Choose one market group", "Take all three tokens from one group. The other six tokens leave the game when you end the turn."],
			["2", "Place them in any order", "Tap a selected token, then a highlighted board space. UNDO reverses placements, cubes, drafts, and refreshes during the current turn."],
			["3", "Stack with care", "Mountains stack to 3 on mountains. Trunks stack to 2; foliage goes on trunks. Buildings reach height 2 on mountains, trunks, or buildings. Water and fields never stack."],
			["4", "End the turn", "After placing all three tokens, place any habitat cubes and end your turn. Your game is saved automatically on this device."]
		]
	elif help_page == 1:
		content = [
			["A", "Draft animal cards", "Take at most one face-up card each turn. You may hold four incomplete cards, including an incomplete Nature’s Spirit."],
			["B", "Match the habitat", "Every card shows its habitat pattern and animal icon. Stacked pieces show exact heights. Patterns rotate but never mirror."],
			["C", "Place cubes", "Tap one of your cards, then a gold-highlighted cube target. A gold ring on the pattern marks its cube space."],
			["D", "Refresh if you skip", "If you have not drafted this turn, NEW lets you replace one face-up animal before ending the turn."]
		]
	else:
		content = [
			["T", "Landscape scoring", "Trees and connected mountains score 1 / 3 / 7 by height. Field groups of 2+ and qualifying height-2 buildings score 5. Side A scores the longest river; Side B scores separate land areas."],
			["A", "Live card scoring", "Your cards and the top HUD show current points. Scores update after every placement, cube, or undo, and may rise or fall as the landscape changes."],
			["S", "Nature’s Spirit", "Choose one of two spirits, or play without one. Its habitat cube activates its special scoring rule."],
			["☀", "Solo suns", "Score thresholds award up to 8 suns. Side A adds 1. No spirit adds 2; a completed group-scoring spirit adds 1. The game ends when the pouch cannot refill or at most two spaces remain."]
		]
	var y = rect.position.y + 82
	var row_height = minf(104, (rect.size.y - 100) / 4.0)
	for item in content:
		draw_circle(Vector2(rect.position.x + 38, y + 20), 17, EcoArt.LIGHT_GREEN)
		EcoArt.text_center(self, item[0], Vector2(rect.position.x + 38, y + 26), 15, EcoArt.GREEN)
		EcoArt.text(self, item[1], Vector2(rect.position.x + 68, y + 18), 17, EcoArt.INK)
		EcoArt.wrapped_text(self, item[2], Rect2(rect.position.x + 68, y + 26, rect.size.x - 92, row_height - 30), 14, EcoArt.MUTED)
		y += row_height
	for i in range(3):
		draw_circle(Vector2(size.x * 0.5 + (i - 1) * 20, rect.end.y - 22), 4, EcoArt.GREEN if i == help_page else EcoArt.MUTED)
	_button("help_prev", Rect2(20, size.y - 68, 110, 46), "BACK", "ghost", help_page > 0, 14)
	_button("home", Rect2(size.x * 0.5 - 85, size.y - 68, 170, 46), "MAIN MENU", "secondary", true, 14)
	_button("help_next", Rect2(size.x - 130, size.y - 68, 110, 46), "NEXT", "primary", help_page < 2, 14)

func _draw_help_compact() -> void:
	var size = _view_size()
	var rect = Rect2(14, 12, size.x - 28, size.y - 72)
	EcoArt.rounded(self, rect, _panel(0.78), 18)
	var titles = ["BUILD YOUR LANDSCAPE", "WELCOME WILDLIFE", "SCORE & SOLO SUNS"]
	EcoArt.text_center(self, titles[help_page], Vector2(size.x * 0.5, 40), 20, EcoArt.GREEN)
	var content: Array = []
	if help_page == 0:
		content = [
			["1", "Choose a market group; the other tokens are discarded at turn end."],
			["2", "Place all three tokens. UNDO reverses actions during this turn."],
			["3", "Match exact stack heights. Cubed spaces cannot accept more tokens."],
			["4", "Place habitat cubes, then end the turn. Your game saves automatically."]
		]
	elif help_page == 1:
		content = [
			["A", "Draft at most one card per turn, with four incomplete cards active."],
			["B", "Card patterns rotate but never mirror. Rings mark cube targets."],
			["C", "Tap one of your cards, then a gold-highlighted board space."],
			["D", "If you skip drafting, NEW replaces one face-up animal card."]
		]
	else:
		content = [
			["T", "Terrain scores live; card and total scores may rise or fall."],
			["A", "Animal cards use their score ladder as habitat cubes are placed."],
			["S", "A completed Nature’s Spirit activates its special scoring rule."],
			["☀", "Score thresholds and solo configuration bonuses award suns."]
		]
	var row_height = (rect.size.y - 62) / 4.0
	for i in range(content.size()):
		var y = 58 + i * row_height
		EcoArt.text_center(self, content[i][0], Vector2(38, y + 18), 13, EcoArt.GREEN)
		EcoArt.wrapped_text(self, content[i][1], Rect2(62, y + 5, rect.size.x - 82, row_height - 6), 12, EcoArt.INK)
	_button("help_prev", Rect2(20, size.y - 54, 110, 44), "BACK", "ghost", help_page > 0, 14)
	_button("home", Rect2(size.x * 0.5 - 85, size.y - 54, 170, 44), "MAIN MENU", "secondary", true, 14)
	_button("help_next", Rect2(size.x - 130, size.y - 54, 110, 44), "NEXT", "primary", help_page < 2, 14)

func _draw_overlay() -> void:
	var size = _view_size()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.08, 0.06, 0.76))
	match overlay:
		"pause": _draw_pause()
		"spirit": _draw_spirit_choice()
		"detail": _draw_card_detail()
		"score": _draw_score_overlay()

func _draw_pause() -> void:
	var size = _view_size()
	if size.y < 420:
		_draw_pause_compact()
		return
	var width = minf(380, size.x - 24)
	var height = minf(390, size.y - 20)
	var rect = Rect2((size.x - width) * 0.5, (size.y - height) * 0.5, width, height)
	EcoArt.rounded(self, rect, EcoArt.CREAM, 24, EcoArt.MUTED, 1)
	EcoArt.text_center(self, "PAUSED", Vector2(size.x * 0.5, rect.position.y + 43), 28, EcoArt.INK)
	var x = rect.position.x + 24
	var w = rect.size.x - 48
	_button("resume", Rect2(x, rect.position.y + 62, w, 48), "RESUME", "primary", true, 16)
	_button("restart", Rect2(x, rect.position.y + 118, w, 48), "RESTART", "secondary", true, 16)
	_button("sound", Rect2(x, rect.position.y + 174, w * 0.48, 46), "SOUND " + ("ON" if sound_enabled else "OFF"), "ghost", true, 12)
	_button("dark", Rect2(x + w * 0.52, rect.position.y + 174, w * 0.48, 46), "DARK " + ("ON" if dark_mode else "OFF"), "ghost", true, 12)
	_button("help", Rect2(x, rect.position.y + 228, w, 46), "HOW TO PLAY", "ghost", true, 14)
	_button("home", Rect2(x, rect.position.y + 282, w, 48), "SAVE & MAIN MENU", "gold", true, 15)
	EcoArt.text_center(self, "Your current game is saved automatically", Vector2(size.x * 0.5, rect.end.y - 18), 11, EcoArt.MUTED)

func _draw_pause_compact() -> void:
	var size = _view_size()
	var width = minf(520, size.x - 24)
	var rect = Rect2((size.x - width) * 0.5, 10, width, size.y - 20)
	EcoArt.rounded(self, rect, EcoArt.CREAM, 20, EcoArt.MUTED, 1)
	EcoArt.text_center(self, "PAUSED · GAME SAVED", Vector2(size.x * 0.5, 40), 22, EcoArt.INK)
	var x = rect.position.x + 20
	var w = rect.size.x - 40
	_button("resume", Rect2(x, 52, w, 44), "RESUME", "primary", true, 15)
	_button("restart", Rect2(x, 102, w, 44), "RESTART", "secondary", true, 15)
	_button("sound", Rect2(x, 152, w * 0.48, 44), "SOUND " + ("ON" if sound_enabled else "OFF"), "ghost", true, 12)
	_button("dark", Rect2(x + w * 0.52, 152, w * 0.48, 44), "DARK " + ("ON" if dark_mode else "OFF"), "ghost", true, 12)
	_button("help", Rect2(x, 202, w, 44), "HOW TO PLAY", "ghost", true, 14)
	_button("home", Rect2(x, 252, w, 44), "SAVE & MAIN MENU", "gold", true, 14)

func _draw_spirit_choice() -> void:
	var size = _view_size()
	var panel = Rect2(16, 18, size.x - 32, size.y - 36)
	EcoArt.rounded(self, panel, EcoArt.CREAM, 24)
	_button("home", Rect2(panel.position + Vector2(12, 12), Vector2(86, 44)), "MENU", "ghost", true, 12)
	EcoArt.text_center(self, "CHOOSE YOUR NATURE’S SPIRIT", Vector2(size.x * 0.5, panel.position.y + 48), 22, EcoArt.GREEN)
	EcoArt.text_center(self, "Its habitat cube activates a unique scoring rule.", Vector2(size.x * 0.5, panel.position.y + 74), 13, EcoArt.MUTED)
	var card_area = Rect2(panel.position + Vector2(20, 94), Vector2(panel.size.x - 40, panel.size.y - 112))
	var gap = 16.0
	var card_width = minf(310, (card_area.size.x - gap) * 0.5)
	var total = card_width * 2 + gap
	for i in range(2):
		var data: Dictionary = game.spirit_options[i]
		var rect = Rect2(card_area.position.x + (card_area.size.x - total) * 0.5 + i * (card_width + gap), card_area.position.y, card_width, card_area.size.y)
		EcoArt.rounded(self, rect, EcoArt.PAPER, 16, EcoArt.GOLD, 2)
		EcoArt.animal_icon(self, int(data.id), rect.position + Vector2(30, 30), 18, EcoArt.GREEN)
		EcoArt.fitted_text(self, data.name.to_upper(), Rect2(rect.position + Vector2(54, 18), Vector2(rect.size.x - 66, 26)), 18, EcoArt.GREEN)
		EcoArt.pattern(self, data, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.3), minf(25, minf(rect.size.x * 0.085, rect.size.y * 0.09)))
		EcoArt.wrapped_text(self, data.rule, Rect2(rect.position + Vector2(16, rect.size.y * 0.49), Vector2(rect.size.x - 32, rect.size.y * 0.25)), 14, EcoArt.INK)
		_button("spirit_%d" % i, Rect2(rect.position + Vector2(14, rect.size.y - 58), Vector2(rect.size.x - 28, 46)), "CHOOSE", "primary", true, 14)

func _draw_card_detail() -> void:
	if detail_card.is_empty():
		return
	var size = _view_size()
	var width = minf(420, size.x - 30)
	var height = minf(590, size.y - 30)
	var rect = Rect2((size.x - width) * 0.5, (size.y - height) * 0.5, width, height)
	EcoArt.rounded(self, rect, EcoArt.PAPER, 20, EcoArt.GOLD if detail_card.kind == "spirit" else EcoArt.GREEN, 2)
	EcoArt.animal_icon(self, int(detail_card.id), rect.position + Vector2(40, 39), 22, EcoArt.GREEN)
	EcoArt.fitted_text(self, detail_card.name.to_upper(), Rect2(rect.position + Vector2(72, 24), Vector2(width - 132, 32)), 22, EcoArt.GREEN)
	EcoArt.text_center(self, "NATURE’S SPIRIT" if detail_card.kind == "spirit" else "ANIMAL HABITAT", rect.position + Vector2(width * 0.5, 76), 12, EcoArt.MUTED)
	EcoArt.pattern(self, detail_card, rect.position + Vector2(width * 0.5, height * 0.32), minf(30, minf(width * 0.073, height * 0.055)))
	EcoArt.text_center(self, "Gold ring = cube target · rotate, never mirror", rect.position + Vector2(width * 0.5, height * 0.51), 12, EcoArt.MUTED)
	if detail_card.kind == "spirit":
		EcoArt.wrapped_text(self, detail_card.rule, Rect2(rect.position + Vector2(28, height * 0.55), Vector2(width - 56, 82)), 15, EcoArt.INK)
	else:
		var score_text = "  ·  ".join(detail_card.scores.map(func(value): return str(value)))
		EcoArt.text_center(self, score_text, rect.position + Vector2(width * 0.5, height * 0.59), 24, EcoArt.GOLD)
		EcoArt.text_center(self, "Points increase with each cube placed", rect.position + Vector2(width * 0.5, height * 0.64), 12, EcoArt.MUTED)
		if detail_card.has("cubes"):
			EcoArt.text_center(self, "NOW %d PTS · %d / %d CUBES" % [game.card_points(detail_card), int(detail_card.cubes), detail_card.scores.size()], rect.position + Vector2(width * 0.5, height * 0.7), 14, EcoArt.GREEN)
	var button_rect = Rect2(rect.position + Vector2(24, height - 68), Vector2(width - 48, 46))
	if detail_source.begins_with("market"):
		var index = int(detail_source.get_slice(":", 1))
		_button("draft", button_rect, "DRAFT CARD", "primary", game.can_draft(index))
	elif detail_source == "active":
		_button("find_habitat", button_rect, "FIND HABITAT", "gold", game.available_cube_cells(int(detail_card.id)).size() > 0)
	else:
		_button("close", button_rect, "CLOSE", "secondary")
	_button("close", Rect2(rect.end.x - 54, rect.position.y + 10, 44, 44), "X", "ghost", true, 15)

func _draw_score_overlay() -> void:
	var size = _view_size()
	var compact = size.y < 420
	var width = minf(560 if compact else 430, size.x - 30)
	var height = minf(520, size.y - 30)
	var rect = Rect2((size.x - width) * 0.5, (size.y - height) * 0.5, width, height)
	var result = game.score()
	EcoArt.rounded(self, rect, EcoArt.PAPER, 20, EcoArt.GREEN, 2)
	EcoArt.text_center(self, "LIVE ECOSYSTEM SCORE", rect.position + Vector2(width * 0.5, 36 if compact else 42), 19 if compact else 21, EcoArt.GREEN)
	EcoArt.text_center(self, "%d POINTS" % int(result.total), rect.position + Vector2(width * 0.5, 70 if compact else 86), 26 if compact else 32, EcoArt.GOLD)
	var labels = [["trees", "Trees"], ["mountains", "Mountains"], ["fields", "Fields"], ["buildings", "Buildings"], ["water", "Water / islands"], ["animals", "Placed animals"], ["spirit", "Nature’s Spirit"]]
	if compact:
		var column_width = (width - 48) * 0.5
		for i in range(labels.size()):
			var column = 0 if i < 4 else 1
			var row = i if i < 4 else i - 4
			var x = rect.position.x + 24 + column * column_width
			var y = rect.position.y + 106 + row * 30
			EcoArt.text(self, labels[i][1], Vector2(x, y), 13, EcoArt.INK)
			EcoArt.text(self, str(result[labels[i][0]]), Vector2(x + column_width - 34, y), 14, EcoArt.GREEN)
	else:
		for i in range(labels.size()):
			var y = rect.position.y + 128 + i * 38
			EcoArt.text(self, labels[i][1], Vector2(rect.position.x + 28, y), 16, EcoArt.INK)
			EcoArt.text(self, str(result[labels[i][0]]), Vector2(rect.end.x - 62, y), 17, EcoArt.GREEN)
		EcoArt.text_center(self, "Updates after placements, animals, and undo", Vector2(size.x * 0.5, rect.end.y - 78), 11, EcoArt.MUTED)
	_button("close", Rect2(rect.position + Vector2(24, height - 58), Vector2(width - 48, 44)), "BACK TO GAME", "primary", true, 14)

func _draw_toast() -> void:
	var size = _view_size()
	var width = minf(480, size.x - 40)
	var rect = Rect2((size.x - width) * 0.5, 72, width, 44)
	EcoArt.rounded(self, rect, Color(0.12, 0.23, 0.19, 0.96), 14)
	EcoArt.fitted_text(self, toast, Rect2(rect.position + Vector2(10, 12), Vector2(rect.size.x - 20, 22)), 13, Color.WHITE, true)

func _handle_click(position: Vector2) -> void:
	for id in buttons.keys():
		if buttons[id].has_point(position):
			if disabled_buttons.has(id):
				if id == "draft":
					_show_toast("Draft limit reached or a card was already taken")
				return
			_activate(id)
			return
	if not overlay.is_empty():
		return
	if screen != "game" or game.ended:
		return
	for i in range(market_regions.size()):
		if market_regions[i].has_point(position) and game.selected_group < 0:
			if game.select_market(i):
				mode = "token"
				selected_token_index = 0
				_play("tap")
				_save_game()
				_show_toast("Place all three tokens in any order")
			return
	for i in range(faceup_regions.size()):
		if faceup_regions[i].has_point(position) and not game.faceup[i].is_empty():
			if mode == "refresh":
				if game.refresh_card(i):
					mode = "token"
					_play("tap")
					_save_game()
					_show_toast("Face-up animal replaced")
				return
			detail_card = game.faceup[i]
			detail_source = "market:%d" % i
			overlay = "detail"
			_play("tap")
			return
	for card_id in active_regions.keys():
		if active_regions[card_id].has_point(position):
			var available = game.available_cube_cells(card_id)
			if not available.is_empty():
				selected_card_id = card_id
				mode = "cube"
				_play("tap")
				_show_toast("Tap a gold space to place the habitat cube")
			else:
				detail_card = game.card_instance(card_id)
				detail_source = "active"
				overlay = "detail"
				_play("tap")
			return
	for cell in cell_regions.keys():
		if cell_regions[cell].has_point(position):
			if mode == "cube" and selected_card_id > 0:
				if game.place_cube(selected_card_id, cell):
					animations.append({"cell": cell, "age": 0.0})
					var card = game.card_instance(selected_card_id)
					var complete = card.kind == "spirit" or int(card.cubes) >= card.scores.size()
					_play("complete" if complete else "place")
					if complete or game.available_cube_cells(selected_card_id).is_empty():
						mode = "token"
						selected_card_id = 0
					_save_game()
					_show_toast("Habitat complete!" if complete else "Animal cube placed")
				else:
					_show_toast("Choose a gold highlighted habitat target")
				return
			if not game.selected_tokens.is_empty():
				selected_token_index = clampi(selected_token_index, 0, game.selected_tokens.size() - 1)
				var placed = game.place_token(cell, selected_token_index)
				if placed.is_empty():
					_show_toast("That token cannot be placed on this space")
					return
				animations.append({"cell": cell, "age": 0.0})
				_play("place")
				selected_token_index = mini(selected_token_index, maxi(0, game.selected_tokens.size() - 1))
				_save_game()
				if game.selected_tokens.is_empty():
					_show_toast("All tokens placed — draft, place cubes, undo, or end turn")
				elif not game.has_legal_token_placement():
					game.finish_early()
					_finish_game()
				return
			_show_toast("Choose a market group first")
			return

func _activate(id: String) -> void:
	_play("tap")
	match id:
		"play_a": start_game("A")
		"play_b": start_game("B")
		"continue": continue_game()
		"spirit": spirit_enabled = not spirit_enabled
		"sound":
			sound_enabled = not sound_enabled
			_save_settings()
		"dark":
			dark_mode = not dark_mode
			EcoArt.set_dark_mode(dark_mode)
			_save_settings()
		"records": _change_screen("records")
		"help":
			help_page = 0
			_save_game()
			_change_screen("help")
		"help_prev": help_page = maxi(0, help_page - 1)
		"help_next": help_page = mini(2, help_page + 1)
		"home": _go_home()
		"pause":
			overlay = "pause"
			_save_game()
		"resume": overlay = ""
		"restart": start_game(game.side)
		"close":
			overlay = ""
			detail_card = {}
		"score": overlay = "score"
		"hand_prev": hand_page = maxi(0, hand_page - 1)
		"hand_next": hand_page += 1
		"undo":
			if game.undo():
				mode = "token"
				selected_card_id = 0
				selected_token_index = 0
				animations.clear()
				_save_game()
				_show_toast("Last action undone · scores updated")
		"refresh":
			mode = "refresh"
			selected_card_id = 0
			_show_toast("Tap one face-up animal to replace it")
		"draft":
			var index = int(detail_source.get_slice(":", 1))
			if game.draft_card(index):
				overlay = ""
				detail_card = {}
				_save_game()
				_show_toast("Animal added to your habitats")
		"find_habitat":
			selected_card_id = int(detail_card.id)
			mode = "cube"
			overlay = ""
			detail_card = {}
			_show_toast("Tap a gold space to place the habitat cube")
		"end_turn":
			if game.end_turn():
				mode = "token"
				selected_card_id = 0
				if game.ended:
					_finish_game()
				else:
					_save_game()
					_show_toast("Turn %d · choose a new token group" % game.turn)
		_:
			if id.begins_with("token_"):
				selected_token_index = int(id.get_slice("_", 1))
				mode = "token"
				selected_card_id = 0
			elif id.begins_with("spirit_"):
				var index = int(id.get_slice("_", 1))
				if game.choose_spirit(index):
					overlay = ""
					_save_game()
					_show_toast("Choose a token group to begin")

func _finish_game() -> void:
	var result = game.score()
	_change_screen("results")
	_save_result(result)

func _draw_results_compact(result: Dictionary) -> void:
	var size = _view_size()
	var left_width = size.x * 0.33
	EcoArt.text_center(self, "YOUR ECOSYSTEM", Vector2(left_width * 0.5, 42), 14, EcoArt.MUTED)
	EcoArt.text_center(self, str(result.total), Vector2(left_width * 0.5, 112), 58, EcoArt.GREEN)
	EcoArt.text_center(self, "POINTS", Vector2(left_width * 0.5, 139), 12, EcoArt.MUTED)
	var sun_count = int(result.suns)
	var spacing = 23.0
	var start = left_width * 0.5 - (sun_count - 1) * spacing * 0.5
	for i in range(sun_count):
		var p = Vector2(start + i * spacing, 172)
		draw_circle(p, 8, EcoArt.GOLD)
		for ray in range(8):
			var direction = Vector2.from_angle(ray * TAU / 8.0)
			draw_line(p + direction * 10, p + direction * 13, EcoArt.GOLD, 1.5, true)
	EcoArt.wrapped_text(self, "%d suns · %d score + %d configuration" % [result.suns, result.base_suns, result.configuration], Rect2(24, 196, left_width - 48, 52), 12, EcoArt.MUTED)
	EcoArt.wrapped_text(self, game.end_reason, Rect2(24, 246, left_width - 48, 50), 11, EcoArt.MUTED)
	var panel = Rect2(left_width + 6, 18, size.x - left_width - 24, size.y - 104)
	EcoArt.rounded(self, panel, _panel(0.62), 18)
	var labels = [["trees", "Trees"], ["mountains", "Mountains"], ["fields", "Fields"], ["buildings", "Buildings"], ["water", "Water / islands"], ["animals", "Animal cards"], ["spirit", "Nature’s Spirit"]]
	var row_gap = minf(34, (panel.size.y - 38) / labels.size())
	for i in range(labels.size()):
		var y = panel.position.y + 28 + i * row_gap
		EcoArt.text(self, labels[i][1], Vector2(panel.position.x + 22, y), 14, EcoArt.INK)
		EcoArt.text(self, str(result[labels[i][0]]), Vector2(panel.end.x - 48, y), 15, EcoArt.GREEN)
	var button_width = minf(220, (size.x - 58) * 0.5)
	_button("restart", Rect2(size.x * 0.5 - button_width - 7, size.y - 66, button_width, 48), "PLAY AGAIN", "primary", true, 15)
	_button("home", Rect2(size.x * 0.5 + 7, size.y - 66, button_width, 48), "MAIN MENU", "secondary", true, 15)

func _make_sound(sound_name: String) -> AudioStreamWAV:
	var duration = 0.11
	var notes = [520.0, 680.0]
	var volume = 0.12
	match sound_name:
		"place":
			duration = 0.22
			notes = [260.0, 390.0, 520.0]
			volume = 0.18
		"complete":
			duration = 0.65
			notes = [392.0, 493.88, 587.33, 783.99]
			volume = 0.16
		"finish":
			duration = 1.25
			notes = [261.63, 329.63, 392.0, 523.25, 659.25]
			volume = 0.14
	var rate = 22050
	var sample_count = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / rate
		var value = 0.0
		for j in range(notes.size()):
			var start = j * duration / (notes.size() + 1)
			var local = t - start
			if local >= 0:
				var envelope = exp(-local * (8.0 if sound_name == "tap" else 4.5)) * minf(1.0, local * 80.0)
				value += sin(TAU * notes[j] * local) * envelope
				value += 0.22 * sin(TAU * notes[j] * 2.0 * local) * envelope
		var fade_out = minf(t / 0.008, (duration - t) / 0.035)
		var sample = int(clampf(value * volume * minf(1.0, fade_out) / notes.size() * 2.2, -1.0, 1.0) * 32767.0)
		bytes[i * 2] = sample & 0xff
		bytes[i * 2 + 1] = (sample >> 8) & 0xff
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream
