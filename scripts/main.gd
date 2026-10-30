extends Control

const RECORDS_PATH = "user://records.json"
const SETTINGS_PATH = "user://settings.cfg"
const SAVE_PATH = "user://saved_game.json"
const TOKEN_NAMES = {"water": "Water", "mountain": "Mountain", "trunk": "Trunk", "tree": "Tree", "field": "Field", "building": "Building"}

var game = EcoGame.new()
var screen = "home"
var mode = "token"
var spirit_enabled = true
var selected_card_id = 0
var selected_token_index = 0
var detail_card: Dictionary = {}
var detail_index = -1
var score_result: Dictionary = {}
var dark_mode = false
var ui_scale = 1.0
var hand_page = 0
var saved_game_available = false
var saved_summary: Dictionary = {}
var records = {"games": 0, "best": 0, "last": 0, "suns": 0, "history": []}
var sound_enabled = true
var audio: Dictionary = {}
var buttons: Dictionary = {}
var board_hit: Array = []
var cube_hit: Array = []
var selected_hit: Array = []
var toast = ""
var toast_time = 0.0
var elapsed = 0.0
var animations: Array = []
var fade = 1.0
var regular: Font
var bold: Font
var board_center = Vector2.ZERO
var board_radius = 32.0
var logical_size = Vector2.ZERO

func _ready() -> void:
	regular = load("res://assets/fonts/Inter-Regular.ttf")
	bold = load("res://assets/fonts/Inter-SemiBold.ttf")
	_load_records()
	_load_settings()
	EcoArt.set_dark_mode(dark_mode)
	_refresh_saved_summary()
	_make_audio()
	_update_scale()
	get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()

func _on_viewport_resized() -> void:
	_update_scale()
	queue_redraw()

func _update_scale() -> void:
	var physical = get_viewport_rect().size
	if physical.x > physical.y and physical.y < 600:
		# Compact landscape needs a shorter logical canvas so controls remain legible.
		ui_scale = clampf(physical.y / 320.0, 1.0, 1.8)
	else:
		ui_scale = clampf(minf(physical.x / 390.0, physical.y / 640.0), 1.0, 3.0)

func _view_size() -> Vector2:
	return get_viewport_rect().size / ui_scale

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_game()

func _exit_tree() -> void:
	_save_game()

func _handle_back() -> void:
	match screen:
		"game":
			if not detail_card.is_empty():
				detail_card = {}
			else:
				_save_game()
				_change_screen("pause")
		"pause": _change_screen("game")
		"score": _change_screen("game")
		"help", "records": _change_screen("home")
		"results", "setup": _change_screen("home")
		_: get_tree().quit()
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	fade = maxf(0, fade - delta * 3.5)
	if toast_time > 0:
		toast_time -= delta
	for i in range(animations.size() - 1, -1, -1):
		animations[i].time -= delta
		if animations[i].time <= 0:
			animations.remove_at(i)
	queue_redraw()

func _draw() -> void:
	buttons.clear()
	board_hit.clear()
	cube_hit.clear()
	selected_hit.clear()
	logical_size = _view_size()
	var size = logical_size
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
	draw_rect(Rect2(Vector2.ZERO, size), EcoArt.CREAM)
	match screen:
		"home": _draw_home()
		"setup": _draw_setup()
		"game": _draw_game()
		"pause": _draw_pause()
		"score": _draw_score_overlay()
		"results": _draw_results()
		"help": _draw_help()
		"records": _draw_records()
	for animation in animations:
		var p = _cell_position(animation.cell)
		var progress = 1.0 - animation.time / 0.7
		draw_arc(p, board_radius * (0.5 + progress * 0.8), 0, TAU, 40, Color(0.85, 0.65, 0.2, 1.0 - progress), 3, true)
	if toast_time > 0:
		var toast_rect = Rect2(size.x * 0.08, size.y - 60, size.x * 0.84, 42)
		EcoArt.panel(self, toast_rect, EcoArt.INK, 18, false)
		EcoArt.text(self, regular, toast, toast_rect.position + Vector2(12, 27), 14, EcoArt.PAPER, toast_rect.size.x - 24, HORIZONTAL_ALIGNMENT_CENTER)
	if fade > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(EcoArt.CREAM, fade))

func _button(id: String, label: String, rect: Rect2, primary: bool = false, enabled: bool = true) -> void:
	var color = EcoArt.GREEN if primary else EcoArt.PAPER
	if not enabled:
		color = EcoArt.PAPER.darkened(0.04)
	EcoArt.panel(self, rect, color, 14, primary)
	if not primary:
		EcoArt.outline(self, rect, EcoArt.LIGHT_GREEN.darkened(0.06), 14, 1.2)
	EcoArt.text(self, bold, label, rect.position + Vector2(8, rect.size.y * 0.5 + 6), 16, EcoArt.PAPER if primary else (EcoArt.MUTED if not enabled else EcoArt.INK), rect.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
	if enabled:
		buttons[id] = rect

func _header(title: String, subtitle: String, back: bool = false) -> void:
	if back:
		_button("home", "←", Rect2(16, 18, 48, 44))
	var x = 76 if back else 20
	EcoArt.text(self, bold, title, Vector2(x, 40), 25)
	EcoArt.text(self, regular, subtitle, Vector2(x, 61), 13, EcoArt.MUTED)

func _draw_home() -> void:
	var size = logical_size
	if size.x > size.y and size.y < 440:
		_draw_home_compact()
		return
	EcoArt.leaf(self, Vector2(size.x - 54, 66), 46, EcoArt.LIGHT_GREEN)
	EcoArt.text(self, bold, "ECO", Vector2(24, 76), 44, EcoArt.GREEN)
	EcoArt.text(self, bold, "MASTERS", Vector2(24, 116), 44)
	EcoArt.text(self, regular, "Grow a little world.", Vector2(26, 146), 17, EcoArt.MUTED)
	var hero = Rect2(20, 174, size.x - 40, minf(205, size.y * 0.27))
	EcoArt.panel(self, hero, EcoArt.LIGHT_GREEN, 24, false)
	var center = hero.get_center() + Vector2(0, 4)
	EcoArt.sun(self, center + Vector2(hero.size.x * 0.31, -30), 27)
	for data in [[-0.29, 0.08, "water"], [-0.08, 0.15, "field"], [0.13, 0.03, "tree"], [0.28, 0.19, "mountain"], [-0.03, -0.15, "building"]]:
		EcoArt.token(self, data[2], center + Vector2(hero.size.x * data[0], data[1] * hero.size.y), minf(34, hero.size.y * 0.17))
	EcoArt.text(self, bold, "Your solo ecosystem", hero.position + Vector2(18, 30), 18)
	var y = hero.end.y + 22
	var gap = 12.0
	var has_save = saved_game_available
	var height = minf(56, maxf(44, (size.y - y - 24 - gap * (4 if has_save else 3)) / (5 if has_save else 4)))
	if has_save:
		_button("continue", "Continue · Turn %d" % int(saved_summary.get("turn", 1)), Rect2(20, y, size.x - 40, height), true)
		y += height + gap
		_button("new", "New ecosystem", Rect2(20, y, size.x - 40, height))
	else:
		_button("new", "Start a new ecosystem", Rect2(20, y, size.x - 40, height), true)
	y += height + gap
	_button("help", "How to play", Rect2(20, y, size.x - 40, height))
	y += height + gap
	_button("records", "Local records", Rect2(20, y, size.x - 40, height))
	y += height + gap
	_button("sound", "Sound: " + ("on" if sound_enabled else "off"), Rect2(20, y, size.x - 40, height))
	_button("dark", "Dark", Rect2(size.x - 76, 20, 56, 44))
	EcoArt.text(self, regular, "Original art & sound · on-device only", Vector2(20, size.y - 12), 11, EcoArt.MUTED, size.x - 40, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_home_compact() -> void:
	var size = logical_size
	EcoArt.text(self, bold, "ECO MASTERS", Vector2(20, 47), 29, EcoArt.GREEN)
	EcoArt.text(self, regular, "Grow a little world.", Vector2(22, 66), 13, EcoArt.MUTED)
	var y = 78.0 if saved_game_available else 102.0
	if saved_game_available:
		_button("continue", "Continue · Turn %d" % int(saved_summary.get("turn", 1)), Rect2(20, y, size.x * 0.51, 44), true)
		y += 48
		_button("new", "New ecosystem", Rect2(20, y, size.x * 0.51, 44))
	else:
		_button("new", "Start a new ecosystem", Rect2(20, y, size.x * 0.51, 44), true)
	y += 48
	_button("help", "How to play", Rect2(20, y, size.x * 0.51, 44))
	y += 48
	_button("records", "Local records", Rect2(20, y, size.x * 0.51, 44))
	_button("dark", "Dark", Rect2(size.x - 76, 14, 56, 44))
	_button("sound", "Sound " + ("on" if sound_enabled else "off"), Rect2(size.x - 156, 14, 72, 44))
	var hero = Rect2(size.x * 0.58, 58, size.x * 0.35, size.y - 78)
	EcoArt.panel(self, hero, EcoArt.LIGHT_GREEN, 20, false)
	for data in [[-0.25, 0.1, "water"], [0.0, 0.22, "field"], [0.23, 0.0, "tree"], [0.0, -0.23, "building"]]:
		EcoArt.token(self, data[2], hero.get_center() + Vector2(hero.size.x * data[0], data[1] * hero.size.y), 25)

func _draw_setup() -> void:
	var size = logical_size
	if size.x > size.y and size.y < 440:
		_draw_setup_compact()
		return
	_header("New ecosystem", "Choose your solo setup", true)
	var y = 88.0
	EcoArt.text(self, bold, "Board side", Vector2(20, y), 18)
	y += 14
	_button("side_a", "A · Rivers & valleys", Rect2(20, y, (size.x - 50) / 2, 54), true)
	_button("side_b", "B · Open wilderness", Rect2(30 + (size.x - 50) / 2, y, (size.x - 50) / 2, 54))
	y += 78
	EcoArt.text(self, bold, "Nature’s Spirit", Vector2(20, y), 18)
	EcoArt.text(self, regular, "Optional: draw two and keep one.", Vector2(20, y + 24), 14, EcoArt.MUTED)
	y += 38
	_button("spirit_toggle", "Spirit: " + ("enabled" if spirit_enabled else "off"), Rect2(20, y, size.x - 40, 50))
	y += 70
	EcoArt.panel(self, Rect2(20, y, size.x - 40, 104), EcoArt.LIGHT_GREEN, 18, false)
	EcoArt.text(self, bold, "Solo objective", Vector2(38, y + 30), 17)
	EcoArt.text(self, regular, "Build habitats, place animal cubes, and", Vector2(38, y + 55), 14)
	EcoArt.text(self, regular, "turn your final score into as many suns", Vector2(38, y + 76), 14)
	EcoArt.text(self, regular, "as you can.", Vector2(38, y + 96), 14)
	_button("begin", "Choose your spirit" if spirit_enabled else "Begin", Rect2(20, size.y - 76, size.x - 40, 56), true)

func _draw_setup_compact() -> void:
	var size = logical_size
	_header("New ecosystem", "Solo setup", true)
	EcoArt.text(self, bold, "Board side", Vector2(20, 92), 16)
	_button("side_a", "A · Rivers", Rect2(20, 104, (size.x - 50) / 2, 48), true)
	_button("side_b", "B · Wilderness", Rect2(30 + (size.x - 50) / 2, 104, (size.x - 50) / 2, 48))
	_button("spirit_toggle", "Nature’s Spirit: " + ("enabled" if spirit_enabled else "off"), Rect2(20, 166, size.x - 40, 48))
	_button("begin", "Choose your spirit" if spirit_enabled else "Begin", Rect2(20, size.y - 60, size.x - 40, 48), true)

func _draw_spirit_choices() -> void:
	var size = logical_size
	if size.x > size.y and size.y < 440:
		_draw_spirit_choices_compact()
		return
	_header("Choose your Spirit", "One scoring companion for this ecosystem", true)
	var h = minf(380, (size.y - 140) / 2)
	for i in range(game.spirit_options.size()):
		var card: Dictionary = game.spirit_options[i]
		var rect = Rect2(20, 92 + i * (h + 14), size.x - 40, h)
		EcoArt.panel(self, rect, EcoArt.PAPER, 22)
		EcoArt.text(self, bold, card.name, rect.position + Vector2(18, 34), 23)
		EcoArt.text(self, regular, "Nature’s Spirit · one cube", rect.position + Vector2(18, 56), 13, EcoArt.MUTED)
		EcoArt.pattern(self, card, Rect2(rect.position + Vector2(15, 68), Vector2(rect.size.x - 30, h - 148)))
		EcoArt.text(self, regular, card.note, rect.position + Vector2(18, rect.size.y - 52), 13, EcoArt.MUTED, rect.size.x - 36, HORIZONTAL_ALIGNMENT_CENTER)
		_button("spirit_%d" % i, "Choose " + card.name, Rect2(rect.position + Vector2(16, rect.size.y - 42), Vector2(rect.size.x - 32, 36)), true)

func _draw_spirit_choices_compact() -> void:
	var size = logical_size
	_header("Choose your Spirit", "One scoring companion", true)
	var width = (size.x - 52) / 2
	for i in range(game.spirit_options.size()):
		var card: Dictionary = game.spirit_options[i]
		var rect = Rect2(20 + i * (width + 12), 86, width, size.y - 100)
		EcoArt.panel(self, rect, EcoArt.PAPER, 18)
		EcoArt.text(self, bold, card.name, rect.position + Vector2(12, 26), 18)
		EcoArt.pattern(self, card, Rect2(rect.position + Vector2(10, 38), Vector2(rect.size.x - 20, rect.size.y - 98)))
		_button("spirit_%d" % i, "Choose", Rect2(rect.position + Vector2(10, rect.size.y - 52), Vector2(rect.size.x - 20, 44)), true)

func _draw_game() -> void:
	var size = logical_size
	if size.x > size.y and size.y < 440:
		_draw_game_compact()
		return
	if not game.spirit_enabled and game.spirit.is_empty() and game.spirit_options.is_empty():
		pass
	elif game.spirit_enabled and not game.spirit.is_empty():
		pass
	elif game.spirit_enabled and game.spirit.is_empty():
		_draw_spirit_choices()
		return
	EcoArt.text(self, bold, "ECO MASTERS", Vector2(18, 31), 20, EcoArt.GREEN)
	EcoArt.text(self, regular, "Turn %d · Side %s" % [game.turn, game.side], Vector2(18, 50), 12, EcoArt.MUTED)
	_button("score", "%d pts" % int(game.score().total), Rect2(size.x - 162, 14, 72, 44))
	_button("pause", "Ⅱ", Rect2(size.x - 82, 14, 54, 44))
	if game.active_count() == 0 and game.drafted:
		EcoArt.text(self, bold, "Draft an Animal card", Vector2(18, 79), 17)
	else:
		EcoArt.text(self, bold, "1  Place tokens    2  Shape habitats", Vector2(18, 79), 16)
	_draw_faceup()
	_draw_board()
	_draw_market()
	_draw_acquired()
	if not detail_card.is_empty():
		_draw_card_detail()

func _draw_game_compact() -> void:
	var size = logical_size
	if game.spirit_enabled and game.spirit.is_empty():
		_draw_spirit_choices_compact()
		return
	EcoArt.text(self, bold, "ECO MASTERS", Vector2(14, 28), 18, EcoArt.GREEN)
	EcoArt.text(self, regular, "Turn %d · Side %s · %d active" % [game.turn, game.side, game.active_count()], Vector2(14, 47), 12, EcoArt.MUTED)
	_button("score", "%d pts" % int(game.score().total), Rect2(size.x - 196, 12, 68, 44))
	_button("undo", "Undo", Rect2(size.x - 122, 12, 60, 44), false, game.can_undo())
	_button("pause", "Ⅱ", Rect2(size.x - 56, 12, 46, 44))
	var market_height = clampf(size.y * 0.24, 76, 88)
	var faceup_height = minf(clampf(size.y * 0.34, 96, 128), size.y - market_height - 146)
	var faceup_y = 70 + market_height + 4
	var hint_y = faceup_y + faceup_height + 4
	EcoArt.text(self, regular, "Select tokens → place all 3 → draft or refresh → end turn", Vector2(16, hint_y + 15), 11, EcoArt.MUTED, size.x * 0.49)
	_draw_faceup(Rect2(10, faceup_y, size.x * 0.5 - 14, faceup_height))
	_draw_board(Rect2(size.x * 0.51, 64, size.x * 0.48, size.y - 72))
	_draw_market(Rect2(10, 66, size.x * 0.5 - 14, market_height))
	_draw_acquired(Rect2(10, hint_y + 26, size.x - 20, size.y - hint_y - 32))
	if not detail_card.is_empty():
		_draw_card_detail()

func _draw_faceup(area: Rect2 = Rect2()) -> void:
	var size = logical_size
	var y = area.position.y if area.size.x > 0 else 94.0
	var width = (area.size.x - 16) / 3 if area.size.x > 0 else (size.x - 52) / 3
	var x0 = area.position.x if area.size.x > 0 else 16.0
	var card_height = area.size.y - 24 if area.size.x > 0 else 132.0
	EcoArt.text(self, bold, "Available Animals", Vector2(x0 + 2, y), 13, EcoArt.MUTED)
	for i in range(3):
		var rect = Rect2(x0 + i * (width + 8), y + 10, width, card_height)
		var card: Dictionary = game.faceup[i] if i < game.faceup.size() else {}
		EcoArt.panel(self, rect, EcoArt.PAPER, 12, false)
		EcoArt.outline(self, rect, EcoArt.LIGHT_GREEN.darkened(0.07), 12, 1)
		if card.is_empty():
			EcoArt.text(self, regular, "Deck empty", rect.position + Vector2(8, 58), 13, EcoArt.MUTED, rect.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
			continue
			EcoArt.text(self, bold, card.name, rect.position + Vector2(7, 19), 12, EcoArt.INK, rect.size.x - 34)
			EcoArt.animal_icon(self, int(card.id), rect.position + Vector2(rect.size.x - 14, 14), 8)
			EcoArt.text(self, regular, "/".join(card.scores), rect.position + Vector2(7, 35), 10, EcoArt.MUTED, rect.size.x - 14)
			EcoArt.pattern(self, card, Rect2(rect.position + Vector2(4, 40), Vector2(rect.size.x - 8, rect.size.y - 48)))
			buttons["detail_%d" % i] = rect

func _draw_board(area: Rect2 = Rect2()) -> void:
	var size = logical_size
	var available = area if area.size.x > 0 else Rect2(8, 246, size.x - 16, size.y - 518)
	var board_width = available.size.x
	var board_height = maxf(160, available.size.y)
	board_center = available.get_center() + Vector2(0, 3)
	var xs: Array = []
	var ys: Array = []
	for cell in game.board.keys():
		var p = Vector2(sqrt(3) * (cell.x + cell.y * 0.5), 1.5 * cell.y)
		xs.append(p.x)
		ys.append(p.y)
	var span_x = xs.max() - xs.min() + 2.0
	var span_y = ys.max() - ys.min() + 1.8
	board_radius = minf(board_width / span_x, board_height / span_y)
	board_radius = maxf(18, board_radius)
	var valid_cells: Array = []
	if mode == "token" and game.selected_group >= 0 and selected_token_index < game.selected_tokens.size():
		var token = game.selected_tokens[selected_token_index]
		for cell in game.board.keys():
			if EcoRules.can_place(game.board, game.cubes, cell, token):
				valid_cells.append(cell)
	elif mode == "cube":
		valid_cells = game.available_cube_cells(selected_card_id)
	for cell in game.board.keys():
		var p = _cell_position(cell)
		var stack: Array = game.board[cell]
		var valid = valid_cells.has(cell)
		var selected = (mode == "token" and valid and selected_hit.is_empty())
		EcoArt.board_cell(self, p, board_radius * 0.92, stack, int(game.cubes.get(cell, 0)), selected, valid)
		board_hit.append({"cell": cell, "center": p, "radius": board_radius * 0.95})
	EcoArt.text(self, regular, "Side %s · %d open spaces" % [game.side, game.empty_cells()], Vector2(18, available.end.y + 14), 11, EcoArt.MUTED, available.size.x - 20, HORIZONTAL_ALIGNMENT_CENTER)

func _cell_position(cell: Vector2i) -> Vector2:
	return board_center + Vector2(sqrt(3) * (cell.x + cell.y * 0.5), 1.5 * cell.y) * board_radius

func _draw_market(area: Rect2 = Rect2()) -> void:
	var size = logical_size
	var y = area.position.y if area.size.x > 0 else size.y - 260
	var market_width = area.size.x if area.size.x > 0 else size.x - 32
	var x0 = area.position.x if area.size.x > 0 else 16.0
	var width = (market_width - 16) / 3
	EcoArt.text(self, bold, "Token market", Vector2(x0 + 2, y), 14)
	for i in range(3):
		var rect = Rect2(x0 + i * (width + 8), y + 10, width, 66)
		var selected = game.selected_group == i
		EcoArt.panel(self, rect, EcoArt.LIGHT_GREEN if selected else EcoArt.PAPER, 12, false)
		if selected:
			EcoArt.outline(self, rect, EcoArt.GREEN, 12, 2)
		if i < game.market.size():
			for j in range(game.market[i].size()):
				EcoArt.token(self, game.market[i][j], rect.position + Vector2(rect.size.x * (j + 0.5) / 3, rect.size.y * 0.52), minf(19, width * 0.14))
			buttons["market_%d" % i] = rect
	var selected_y = y + 88
	if game.selected_group >= 0:
		EcoArt.text(self, regular, "Selected:", Vector2(x0 + 2, selected_y + 22), 13, EcoArt.MUTED)
		for i in range(game.selected_tokens.size()):
			var center = Vector2(x0 + 84 + i * 50, selected_y + 17)
			if i == selected_token_index:
				draw_circle(center, 23, EcoArt.LIGHT_GREEN)
			EcoArt.token(self, game.selected_tokens[i], center, 19)
			selected_hit.append({"index": i, "rect": Rect2(center - Vector2(24, 24), Vector2(48, 48))})
		_button("end", "End turn", Rect2(size.x - 124, selected_y, 108, 44), true, game.selected_tokens.is_empty())
	else:
		EcoArt.text(self, regular, "Choose one group. Other groups are discarded.", Vector2(x0 + 2, selected_y + 24), 12, EcoArt.MUTED)
		_button("undo", "Undo", Rect2(size.x - 100, selected_y, 84, 44), false, game.can_undo())

func _draw_acquired(area: Rect2 = Rect2()) -> void:
	var size = logical_size
	var y = area.position.y if area.size.x > 0 else size.y - 112
	var all_cards: Array = game.acquired.duplicate()
	if not game.spirit.is_empty():
		all_cards.append(game.spirit)
	var page_size = 3 if size.x > size.y else 2
	var page_count = maxi(1, ceili(float(all_cards.size()) / page_size))
	hand_page = clampi(hand_page, 0, page_count - 1)
	EcoArt.text(self, bold, "Your habitats · live points", Vector2(area.position.x + 2 if area.size.x > 0 else 18, y), 13)
	_button("hand_prev", "‹", Rect2(size.x - 104, y - 22, 44, 44), false, hand_page > 0)
	_button("hand_next", "›", Rect2(size.x - 54, y - 22, 44, 44), false, hand_page < page_count - 1)
	if all_cards.is_empty():
		EcoArt.text(self, regular, "Draft a card to begin placing animal cubes.", Vector2(18, y + 32), 13, EcoArt.MUTED)
		return
	var start = hand_page * page_size
	var count = mini(page_size, all_cards.size() - start)
	var width = (size.x - 40 - (count - 1) * 8) / count
	for i in range(count):
		var card: Dictionary = all_cards[start + i]
		var rect = Rect2(20 + i * (width + 8), y + 10, width, 76)
		var active = int(card.get("cubes", 0)) < (1 if card.kind == "spirit" else card.scores.size())
		EcoArt.panel(self, rect, EcoArt.PAPER, 11, false)
		EcoArt.outline(self, rect, EcoArt.GREEN if selected_card_id == int(card.id) and mode == "cube" else EcoArt.LIGHT_GREEN.darkened(0.06), 11, 2 if selected_card_id == int(card.id) else 1)
		EcoArt.text(self, bold, card.name, rect.position + Vector2(7, 17), 11, EcoArt.INK, rect.size.x - 42)
		EcoArt.animal_icon(self, int(card.id), rect.position + Vector2(rect.size.x - 15, 14), 8)
		EcoArt.text(self, regular, "%d pts · ◉%d" % [game.card_points(card), int(card.get("cubes", 0))], rect.position + Vector2(7, 34), 10, EcoArt.GOLD if not active else EcoArt.MUTED)
		EcoArt.pattern(self, card, Rect2(rect.position + Vector2(5, 38), Vector2(rect.size.x - 10, 33)), false)
		buttons["card_%d" % int(card.id)] = rect

func _draw_card_detail() -> void:
	var size = logical_size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.09, 0.07, 0.64))
	var rect = Rect2(20, maxf(70, size.y * 0.12), size.x - 40, minf(500, size.y * 0.74))
	EcoArt.panel(self, rect, EcoArt.PAPER, 22)
	_button("close_detail", "×", Rect2(rect.end.x - 54, rect.position.y + 12, 44, 44))
	EcoArt.text(self, bold, detail_card.name, rect.position + Vector2(18, 42), 24, EcoArt.INK, rect.size.x - 84)
	EcoArt.animal_icon(self, int(detail_card.id), rect.position + Vector2(rect.size.x - 74, 34), 14)
	EcoArt.text(self, regular, "Habitat pattern · rotate in six directions", rect.position + Vector2(18, 65), 13, EcoArt.MUTED)
	EcoArt.pattern(self, detail_card, Rect2(rect.position + Vector2(20, 82), Vector2(rect.size.x - 40, rect.size.y - 220)))
	EcoArt.text(self, regular, detail_card.note, rect.position + Vector2(20, rect.size.y - 115), 14, EcoArt.INK, rect.size.x - 40, HORIZONTAL_ALIGNMENT_CENTER)
	EcoArt.text(self, regular, "Scores: " + "/".join(detail_card.scores), rect.position + Vector2(20, rect.size.y - 85), 14, EcoArt.MUTED, rect.size.x - 40, HORIZONTAL_ALIGNMENT_CENTER)
	if game.can_draft(detail_index):
		_button("draft_%d" % detail_index, "Draft this card", Rect2(rect.position + Vector2(16, rect.size.y - 64), Vector2(rect.size.x - 32, 48)), true)
	elif not game.drafted and not game.refreshed and detail_index >= 0 and not game.deck.is_empty():
		_button("refresh_%d" % detail_index, "Refresh from deck", Rect2(rect.position + Vector2(16, rect.size.y - 64), Vector2(rect.size.x - 32, 48)))
	else:
		EcoArt.text(self, regular, "Already drafted this turn." if game.drafted else "Card details", rect.position + Vector2(20, rect.size.y - 34), 13, EcoArt.MUTED, rect.size.x - 40, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_pause() -> void:
	if logical_size.x > logical_size.y and logical_size.y < 440:
		_draw_pause_compact()
		return
	var size = logical_size
	EcoArt.text(self, bold, "Ecosystem paused", Vector2(24, 100), 30)
	EcoArt.text(self, regular, "Your landscape is waiting.", Vector2(24, 130), 16, EcoArt.MUTED)
	var y = 180.0
	_button("resume", "Resume", Rect2(20, y, size.x - 40, 56), true)
	y += 72
	_button("restart", "Restart ecosystem", Rect2(20, y, size.x - 40, 52))
	y += 66
	_button("sound", "Sound: " + ("on" if sound_enabled else "off"), Rect2(20, y, size.x - 40, 52))
	y += 66
	_button("dark", "Dark mode: " + ("on" if dark_mode else "off"), Rect2(20, y, size.x - 40, 52))
	y += 66
	_button("help", "How to play", Rect2(20, y, size.x - 40, 52))
	y += 66
	_button("save_home", "Save & Main Menu", Rect2(20, y, size.x - 40, 52))

func _draw_pause_compact() -> void:
	var size = logical_size
	EcoArt.text(self, bold, "Ecosystem paused", Vector2(20, 46), 26)
	_button("resume", "Resume", Rect2(20, 68, size.x - 40, 44), true)
	_button("restart", "Restart", Rect2(20, 120, (size.x - 50) / 2, 44))
	_button("sound", "Sound: " + ("on" if sound_enabled else "off"), Rect2(30 + (size.x - 50) / 2, 120, (size.x - 50) / 2, 44))
	_button("dark", "Dark: " + ("on" if dark_mode else "off"), Rect2(20, 172, (size.x - 50) / 2, 44))
	_button("help", "How to play", Rect2(30 + (size.x - 50) / 2, 172, (size.x - 50) / 2, 44))
	_button("save_home", "Save & Main Menu", Rect2(20, 224, size.x - 40, 44))

func _draw_score_overlay() -> void:
	var size = logical_size
	var live = game.score()
	EcoArt.text(self, bold, "Live ecosystem score", Vector2(20, 54), 26)
	_button("close_score", "×", Rect2(size.x - 64, 18, 48, 44))
	var rows = [
		["Trees", int(live.trees)], ["Mountains", int(live.mountains)],
		["Fields", int(live.fields)], ["Buildings", int(live.buildings)],
		["Animals", int(live.animals)], ["Nature’s Spirit", int(live.spirit)],
		["River" if game.side == "A" else "Land areas", int(live.river if game.side == "A" else live.areas)]
	]
	var y = 100.0
	if size.y < 420:
		for i in range(rows.size()):
			var col = i % 2
			var row = i / 2
			var rect = Rect2(20 + col * (size.x - 32) / 2, 84 + row * 58, (size.x - 48) / 2, 50)
			EcoArt.panel(self, rect, EcoArt.PAPER, 10, false)
			EcoArt.text(self, regular, rows[i][0], rect.position + Vector2(10, 21), 12, EcoArt.MUTED, rect.size.x - 50)
			EcoArt.text(self, bold, str(rows[i][1]), rect.position + Vector2(rect.size.x - 40, 32), 19)
		y = 84 + ceili(rows.size() / 2.0) * 58 + 12
	else:
		for row in rows:
			EcoArt.panel(self, Rect2(20, y, size.x - 40, 50), EcoArt.PAPER, 12, false)
			EcoArt.text(self, regular, row[0], Vector2(38, y + 31), 15, EcoArt.MUTED)
			EcoArt.text(self, bold, str(row[1]), Vector2(size.x - 78, y + 32), 19)
			y += 58
	EcoArt.text(self, bold, "Current total: %d · %d sun%s" % [int(live.total), int(live.suns), "" if int(live.suns) == 1 else "s"], Vector2(20, y + 24), 17, EcoArt.GREEN, size.x - 40, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_results() -> void:
	var size = logical_size
	if size.x > size.y and size.y < 440:
		_draw_results_compact()
		return
	EcoArt.sun(self, Vector2(size.x / 2, 74), 30)
	EcoArt.text(self, bold, "Ecosystem complete", Vector2(20, 132), 28, EcoArt.INK, size.x - 40, HORIZONTAL_ALIGNMENT_CENTER)
	EcoArt.text(self, regular, game.end_reason, Vector2(28, 158), 13, EcoArt.MUTED, size.x - 56, HORIZONTAL_ALIGNMENT_CENTER)
	var panel_rect = Rect2(20, 184, size.x - 40, minf(330, size.y - 340))
	EcoArt.panel(self, panel_rect, EcoArt.PAPER, 22)
	var labels = [
		["Trees", score_result.trees], ["Mountains", score_result.mountains],
		["Fields", score_result.fields], ["Buildings", score_result.buildings],
		["Animals", score_result.animals], ["Nature’s Spirit", score_result.spirit],
		["River" if game.side == "A" else "Land areas", score_result.river if game.side == "A" else score_result.areas]
	]
	var row_gap = minf(34, (panel_rect.size.y - 38) / labels.size())
	for i in range(labels.size()):
		var y = panel_rect.position.y + 28 + i * row_gap
		EcoArt.text(self, regular, labels[i][0], Vector2(38, y), 14, EcoArt.MUTED)
		EcoArt.text(self, bold, str(labels[i][1]), Vector2(size.x - 74, y), 15)
	var result_y = panel_rect.end.y + 36
	EcoArt.text(self, bold, "%d points" % int(score_result.total), Vector2(20, result_y), 34, EcoArt.GREEN, size.x - 40, HORIZONTAL_ALIGNMENT_CENTER)
	EcoArt.text(self, bold, "%d sun%s · %s" % [int(score_result.suns), "" if int(score_result.suns) == 1 else "s", _rating(int(score_result.suns))], Vector2(20, result_y + 32), 18, EcoArt.INK, size.x - 40, HORIZONTAL_ALIGNMENT_CENTER)
	var button_y = size.y - 116
	_button("again", "Play again", Rect2(20, button_y, size.x - 40, 48), true)
	_button("home", "Main menu", Rect2(20, button_y + 58, size.x - 40, 48))

func _draw_results_compact() -> void:
	var size = logical_size
	EcoArt.text(self, bold, "Ecosystem complete · %d points" % int(score_result.total), Vector2(20, 42), 23, EcoArt.GREEN)
	EcoArt.text(self, regular, "%d sun%s · %s" % [int(score_result.suns), "" if int(score_result.suns) == 1 else "s", _rating(int(score_result.suns))], Vector2(20, 66), 15)
	var panel_rect = Rect2(20, 82, size.x * 0.58, size.y - 100)
	EcoArt.panel(self, panel_rect, EcoArt.PAPER, 18)
	var labels = [["Trees", score_result.trees], ["Mountains", score_result.mountains], ["Fields", score_result.fields], ["Buildings", score_result.buildings], ["Animals", score_result.animals], ["Spirit", score_result.spirit], ["River" if game.side == "A" else "Land areas", score_result.river if game.side == "A" else score_result.areas]]
	var row_gap = minf(34, (panel_rect.size.y - 38) / labels.size())
	for i in range(labels.size()):
		var y = panel_rect.position.y + 28 + i * row_gap
		EcoArt.text(self, regular, labels[i][0], Vector2(34, y), 13, EcoArt.MUTED)
		EcoArt.text(self, bold, str(labels[i][1]), Vector2(panel_rect.end.x - 42, y), 14)
	_button("again", "Play again", Rect2(size.x * 0.64, 102, size.x * 0.32, 48), true)
	_button("home", "Main menu", Rect2(size.x * 0.64, 162, size.x * 0.32, 48))

func _rating(suns: int) -> String:
	if suns >= 3:
		return "Master ecosystem"
	if suns == 2:
		return "Thriving landscape"
	if suns == 1:
		return "Growing habitat"
	return "Keep cultivating"

func _draw_help() -> void:
	if logical_size.x > logical_size.y and logical_size.y < 440:
		_draw_help_compact()
		return
	var size = logical_size
	_header("How to play", "A compact guide to your solo turn", true)
	var sections = [
		["1 · Choose tokens", "Select one market group, then place all three tokens. Empty land accepts anything; new stacks must match the token below."],
		["2 · Grow habitats", "Trees need trunks: T2 is trunk + tree; T3 is two trunks + tree. Mountains and buildings follow the card’s exact heights."],
		["3 · Draft or refresh", "Draft at most one available Animal per turn, up to four active cards. If you do not draft, you may refresh one face-up card."],
		["4 · Place cubes", "Tap one of your cards, then a highlighted matching habitat. A ring marks the pattern’s cube space. Rotate the pattern, but never mirror it."],
		["5 · Finish & score", "End your turn after placing all selected tokens. Unchosen market groups are discarded. Earn suns at 60/90/120 points plus a configuration bonus."]
	]
	var y = 96.0
	for section in sections:
		EcoArt.text(self, bold, section[0], Vector2(22, y), 17)
		y += 25
		var lines = _wrap(section[1], 52)
		for line in lines:
			EcoArt.text(self, regular, line, Vector2(22, y), 13, EcoArt.MUTED)
			y += 19
		y += 17
	EcoArt.text(self, regular, "On Android, the system Back button opens pause or returns.", Vector2(22, size.y - 24), 11, EcoArt.MUTED)

func _draw_help_compact() -> void:
	var size = logical_size
	_header("How to play", "Solo turn guide", true)
	var lines = ["Choose one market group; place all three tokens.", "Match exact stack heights. Ring = cube target.", "Draft one Animal or refresh one face-up card.", "Tap an owned card, then a highlighted habitat.", "Undo works within the current turn.", "End turn to discard other market groups.", "Suns: 60/90/120 points + configuration bonus."]
	for i in range(lines.size()):
		EcoArt.text(self, regular, lines[i], Vector2(22, 98 + i * 27), 13, EcoArt.MUTED, size.x - 44)

func _draw_records() -> void:
	if logical_size.x > logical_size.y and logical_size.y < 440:
		_draw_records_compact()
		return
	var size = logical_size
	_header("Local records", "Stored only on this device", true)
	var stats = [["Games", int(records.games)], ["Best score", int(records.best)], ["Best suns", int(records.suns)]]
	for i in range(3):
		var width = (size.x - 52) / 3
		var rect = Rect2(16 + i * (width + 10), 94, width, 94)
		EcoArt.panel(self, rect, EcoArt.LIGHT_GREEN, 16, false)
		EcoArt.text(self, bold, str(stats[i][1]), rect.position + Vector2(8, 42), 28, EcoArt.GREEN, rect.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
		EcoArt.text(self, regular, stats[i][0], rect.position + Vector2(8, 70), 12, EcoArt.MUTED, rect.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
	EcoArt.text(self, bold, "Recent ecosystems", Vector2(20, 230), 18)
	if records.history.is_empty():
		EcoArt.text(self, regular, "Complete a game to grow your records.", Vector2(20, 266), 14, EcoArt.MUTED)
	for i in range(mini(7, records.history.size())):
		var item: Dictionary = records.history[i]
		var y = 256 + i * 48
		EcoArt.panel(self, Rect2(20, y, size.x - 40, 40), EcoArt.PAPER, 10, false)
		EcoArt.text(self, regular, "Side %s · %s" % [item.get("side", "A"), item.get("date", "")], Vector2(32, y + 25), 12, EcoArt.MUTED)
		EcoArt.text(self, bold, "%d pts · %d suns" % [int(item.get("score", 0)), int(item.get("suns", 0))], Vector2(size.x * 0.54, y + 25), 13)

func _draw_records_compact() -> void:
	var size = logical_size
	_header("Local records", "On this device", true)
	var stats = [["Games", int(records.games)], ["Best score", int(records.best)], ["Best suns", int(records.suns)]]
	for i in range(3):
		var width = (size.x - 52) / 3
		var rect = Rect2(16 + i * (width + 10), 82, width, 72)
		EcoArt.panel(self, rect, EcoArt.LIGHT_GREEN, 14, false)
		EcoArt.text(self, bold, str(stats[i][1]), rect.position + Vector2(8, 31), 23, EcoArt.GREEN, rect.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
		EcoArt.text(self, regular, stats[i][0], rect.position + Vector2(8, 55), 12, EcoArt.MUTED, rect.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(mini(4, records.history.size())):
		var item: Dictionary = records.history[i]
		var y = 170 + i * 42
		EcoArt.text(self, regular, "Side %s · %s" % [item.get("side", "A"), item.get("date", "")], Vector2(20, y), 12, EcoArt.MUTED)
		EcoArt.text(self, bold, "%d pts · %d suns" % [int(item.get("score", 0)), int(item.get("suns", 0))], Vector2(size.x * 0.57, y), 13)

func _wrap(value: String, count: int) -> Array:
	var lines: Array = []
	var line = ""
	for word in value.split(" "):
		if line.length() + word.length() + 1 > count:
			lines.append(line)
			line = word
		else:
			line += (" " if not line.is_empty() else "") + word
	if not line.is_empty():
		lines.append(line)
	return lines

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position / ui_scale)
		accept_event()

func _handle_click(position: Vector2) -> void:
	for id in buttons:
		if buttons[id].has_point(position):
			_action(id)
			return
	if screen != "game" or not detail_card.is_empty():
		return
	for item in selected_hit:
		if item.rect.has_point(position):
			selected_token_index = item.index
			mode = "token"
			selected_card_id = 0
			_play("tap")
			return
	for item in board_hit:
		if position.distance_to(item.center) <= item.radius:
			if mode == "token":
				_place_token(item.cell)
			elif mode == "cube":
				_place_cube(item.cell)
			return

func _action(id: String) -> void:
	_play("tap")
	if id == "continue":
		continue_game()
	elif id == "new":
		_change_screen("setup")
	elif id == "side_a" or id == "side_b":
		game.side = "A" if id == "side_a" else "B"
	elif id == "spirit_toggle":
		spirit_enabled = not spirit_enabled
	elif id == "begin":
		start_game(game.side if game.side in ["A", "B"] else "A")
	elif id.begins_with("spirit_"):
		if game.choose_spirit(int(id.trim_prefix("spirit_"))):
			_play("success")
			_save_game()
	elif id == "home":
		_save_game()
		_change_screen("home")
	elif id == "pause":
		_save_game()
		_change_screen("pause")
	elif id == "resume":
		_change_screen("game")
	elif id == "restart":
		start_game(game.side)
	elif id == "sound":
		sound_enabled = not sound_enabled
		_save_settings()
	elif id == "dark":
		dark_mode = not dark_mode
		EcoArt.set_dark_mode(dark_mode)
		_save_settings()
	elif id == "help":
		_change_screen("help")
	elif id == "records":
		_change_screen("records")
	elif id == "score":
		_change_screen("score")
	elif id == "close_score":
		_change_screen("game")
	elif id == "undo":
		if game.undo():
			mode = "token"
			selected_card_id = 0
			selected_token_index = 0
			animations.clear()
			_save_game()
			_show_toast("Last action undone · scores updated")
	elif id == "save_home":
		_save_game()
		_change_screen("home")
	elif id == "again":
		start_game(game.side)
	elif id == "close_detail":
		detail_card = {}
		detail_index = -1
	elif id == "hand_prev":
		hand_page = maxi(0, hand_page - 1)
	elif id == "hand_next":
		hand_page += 1
	elif id.begins_with("detail_"):
		detail_index = int(id.trim_prefix("detail_"))
		detail_card = game.faceup[detail_index]
	elif id.begins_with("draft_"):
		if game.draft_card(int(id.trim_prefix("draft_"))):
			detail_card = {}
			detail_index = -1
			_play("success")
			_save_game()
	elif id.begins_with("refresh_"):
		if game.refresh_card(int(id.trim_prefix("refresh_"))):
			detail_card = {}
			detail_index = -1
			_save_game()
	elif id.begins_with("market_"):
		if game.select_market(int(id.trim_prefix("market_"))):
			selected_token_index = 0
			mode = "token"
			_save_game()
	elif id == "end":
		if game.end_turn():
			selected_card_id = 0
			mode = "token"
			if game.ended:
				_finish_game()
			else:
				_play("success")
				_save_game()
	elif id.begins_with("card_"):
		var card_id = int(id.trim_prefix("card_"))
		selected_card_id = card_id
		var cells = game.available_cube_cells(card_id)
		if cells.is_empty():
			_show_toast("No matching habitat is available for this card.")
		else:
			mode = "cube"
			_show_toast("Place the cube on a highlighted habitat.")

func _place_token(cell: Vector2i) -> void:
	if selected_token_index >= game.selected_tokens.size():
		return
	var token = game.place_token(cell, selected_token_index)
	if token.is_empty():
		_show_toast("That token cannot be stacked here.")
		_play("error")
		return
	selected_token_index = mini(selected_token_index, maxi(0, game.selected_tokens.size() - 1))
	animations.append({"cell": cell, "time": 0.7})
	_play("place")
	_save_game()
	if game.selected_tokens.is_empty():
		_show_toast("Tokens placed. Draft a card or end your turn.")
	elif not game.has_legal_token_placement():
		game.finish_early()
		_finish_game()

func _place_cube(cell: Vector2i) -> void:
	if game.place_cube(selected_card_id, cell):
		animations.append({"cell": cell, "time": 0.7})
		mode = "token"
		selected_card_id = 0
		_play("success")
		_save_game()
	else:
		_show_toast("Match the exact habitat and its ringed cube space.")
		_play("error")

func start_game(side: String) -> void:
	game = EcoGame.new()
	game.new_game(side, spirit_enabled)
	mode = "token"
	hand_page = 0
	selected_card_id = 0
	detail_card = {}
	_save_game()
	_change_screen("game")

func continue_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_refresh_saved_summary()
		_show_toast("No saved ecosystem found.")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var restored = EcoGame.new()
	if not parsed is Dictionary or not restored.load_dict(parsed):
		_show_toast("This saved game is not compatible with version 1.1.")
		return
	game = restored
	mode = "token"
	selected_card_id = 0
	selected_token_index = 0
	detail_card = {}
	hand_page = 0
	if game.ended:
		score_result = game.score()
		_change_screen("results")
	else:
		_change_screen("game")
	_show_toast("Saved ecosystem restored.")

func _change_screen(next_screen: String) -> void:
	screen = next_screen
	fade = 0.45
	detail_card = {}
	detail_index = -1
	queue_redraw()

func _finish_game() -> void:
	score_result = game.score()
	records.games = int(records.games) + 1
	records.last = int(score_result.total)
	records.best = maxi(int(records.best), int(score_result.total))
	records.suns = maxi(int(records.suns), int(score_result.suns))
	records.history.push_front({"score": int(score_result.total), "suns": int(score_result.suns), "side": game.side, "date": Time.get_date_string_from_system()})
	records.history = records.history.slice(0, 20)
	_save_records()
	_save_game()
	_play("success")
	_change_screen("results")

func _save_game() -> void:
	if screen == "home" or game.board.is_empty():
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(game.to_dict()))
		file.close()
	_refresh_saved_summary()

func _delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_refresh_saved_summary()

func _refresh_saved_summary() -> void:
	saved_game_available = false
	saved_summary = {}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary and int(parsed.get("save_version", 0)) == EcoGame.SAVE_VERSION:
		saved_game_available = true
		saved_summary = {"turn": int(parsed.get("turn", 1)), "side": str(parsed.get("side", "A")), "ended": bool(parsed.get("ended", false))}

func _show_toast(message: String) -> void:
	toast = message
	toast_time = 3.0

func _load_records() -> void:
	if FileAccess.file_exists(RECORDS_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RECORDS_PATH))
		if parsed is Dictionary:
			records.merge(parsed, true)

func _save_records() -> void:
	var file = FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(records))

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sound_enabled = bool(config.get_value("audio", "enabled", true))
		dark_mode = bool(config.get_value("display", "dark", false))

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "enabled", sound_enabled)
	config.set_value("display", "dark", dark_mode)
	config.save(SETTINGS_PATH)

func _make_audio() -> void:
	for sound in ["tap", "place", "success", "error"]:
		var player = AudioStreamPlayer.new()
		player.stream = _tone(sound)
		add_child(player)
		audio[sound] = player

func _tone(kind: String) -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.08 if kind == "tap" else (0.18 if kind == "place" else 0.32)
	var count = int(rate * duration)
	var data = PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t = float(i) / rate
		var envelope = pow(1.0 - float(i) / count, 2)
		var frequency = 440.0
		if kind == "place": frequency = 240.0 + t * 500
		elif kind == "success": frequency = 520.0 + floor(t * 12) * 65
		elif kind == "error": frequency = 150.0
		var sample = int(sin(TAU * frequency * t) * envelope * 5500)
		data.encode_s16(i * 2, sample)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

func _play(kind: String) -> void:
	if sound_enabled and audio.has(kind):
		audio[kind].play()

