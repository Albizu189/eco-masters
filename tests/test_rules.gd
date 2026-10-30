extends SceneTree

var failures = 0
var checks = 0

func _initialize() -> void:
	run_all()
	print("Eco Masters rules: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func card_ids(cards: Array) -> Array:
	var ids: Array = []
	for card in cards:
		ids.append(int(card.get("id", 0)) if card is Dictionary else 0)
	return ids

func run_all() -> void:
	check(EcoRules.board_cells("A").size() == 25, "Side A has 25 cells")
	check(EcoRules.board_cells("B").size() == 25, "Side B has 25 cells")
	var animals = 0
	var spirits = 0
	for card in EcoRules.CARDS:
		animals += 1 if card.kind == "animal" else 0
		spirits += 1 if card.kind == "spirit" else 0
	check(animals == 32, "All 32 animal cards")
	check(spirits == 10, "All 10 spirit cards")
	var sum = 0
	for value in EcoRules.TOKEN_COUNTS.values(): sum += value
	check(sum == 120, "120 tokens in pouch")
	test_placement()
	test_patterns()
	test_rotations()
	test_scoring()
	test_game_flow()
	test_v11_state()

func blank(side: String = "A") -> Dictionary:
	return EcoRules.empty_board(side)

func test_placement() -> void:
	var board = blank()
	var cubes: Dictionary = {}
	var c = Vector2i(0, 0)
	check(EcoRules.can_place(board, cubes, c, "water"), "Any token on empty")
	board[c] = ["trunk"]
	check(not EcoRules.can_place(board, cubes, c, "water"), "No token on trunk")
	check(EcoRules.can_place(board, cubes, c, "trunk"), "Trunk stacks on trunk")
	check(EcoRules.can_place(board, cubes, c, "tree"), "Tree stacks on trunk")
	board[c] = ["tree"]
	check(EcoRules.can_place(board, cubes, c, "tree"), "Tree stacks on tree")
	board[c] = ["mountain"]
	check(EcoRules.can_place(board, cubes, c, "mountain"), "Mountain stacks on mountain")
	check(not EcoRules.can_place(board, cubes, c, "field"), "No field on mountain")
	board[c] = ["building"]
	check(EcoRules.can_place(board, cubes, c, "building"), "Building stacks on building")
	cubes[c] = 1
	check(not EcoRules.can_place(board, cubes, c, "building"), "Cube blocks placement")

func test_patterns() -> void:
	for card in EcoRules.CARDS:
		var board = blank()
		var cubes: Dictionary = {}
		for i in range(card.pattern.size()):
			board[card.pattern[i].cell] = EcoRules.stack_for_spec(card.pattern[i].spec)
		var valid = EcoRules.valid_cube_cells(card, board, cubes)
		check(valid.has(card.pattern[card.target].cell), "Card %d accepts its exact pattern" % card.id)
		var first: Vector2i = card.pattern[0].cell
		board[first] = []
		check(EcoRules.valid_cube_cells(card, board, cubes).is_empty(), "Card %d rejects missing component" % card.id)

func test_rotations() -> void:
	var card = EcoRules.card_by_id(13)
	var board = blank()
	for i in range(card.pattern.size()):
		var cell = card.pattern[i].cell
		for rotation in range(4): cell = EcoRules.rotate_cell(cell)
		board[cell] = EcoRules.stack_for_spec(card.pattern[i].spec)
	var valid = EcoRules.valid_cube_cells(card, board, {})
	var target = card.pattern[card.target].cell
	for rotation in range(4): target = EcoRules.rotate_cell(target)
	check(valid.has(target), "Four rotations match a four-cell pattern")
	card = EcoRules.card_by_id(1)
	board = blank()
	var height_cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
	for cell in height_cells: board[cell] = EcoRules.stack_for_spec("T2")
	check(EcoRules.valid_cube_cells(card, board, {}).size() > 1, "Card 1 can share trees")
	card = EcoRules.card_by_id(19)
	board = blank()
	for cell in [Vector2i(0,0), Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(-1,1)]: board[cell] = ["field"]
	check(EcoRules.valid_cube_cells(card, board, {}).size() >= 2, "Card 19 straight and corner interpretations")

func test_scoring() -> void:
	var board = blank()
	board[Vector2i(0,0)] = ["trunk", "trunk", "tree"]
	board[Vector2i(1,0)] = ["trunk", "tree"]
	board[Vector2i(0,1)] = ["trunk"]
	var result = EcoRules.score_game(board, "A", [], {})
	check(result.trees == 11, "Tree heights 3+2+1")
	board = blank()
	for cell in [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1)]: board[cell] = ["mountain"]
	for cell in [Vector2i(-2,0), Vector2i(-1,0), Vector2i(0,0)]: board[cell] = ["mountain", "mountain"]
	for cell in [Vector2i(1,0), Vector2i(2,0)]: board[cell] = ["mountain", "mountain", "mountain"]
	result = EcoRules.score_game(board, "A", [], {})
	check(result.mountains == 12, "Mountain contiguous height zones")
	board = blank()
	for cell in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,1)]: board[cell] = ["field"]
	result = EcoRules.score_game(board, "A", [], {})
	check(result.fields == 8, "Field area")
	board = blank()
	for cell in [Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)]: board[cell] = ["building"]
	result = EcoRules.score_game(board, "A", [], {})
	check(result.buildings == 9, "Building row")
	board = blank()
	for cell in [Vector2i(-2,1), Vector2i(-1,1), Vector2i(0,1), Vector2i(1,1)]: board[cell] = ["water"]
	result = EcoRules.score_game(board, "A", [], {})
	check(result.river == 7, "Longest connected river component")
	result = EcoRules.score_game(board, "B", [], {})
	check(result.areas == 8, "Side B single area scores 8")
	check(EcoRules.sun_threshold(60) == 1 and EcoRules.sun_threshold(90) == 2 and EcoRules.sun_threshold(120) == 3, "Sun thresholds")
	check(EcoRules.sun_threshold(55) == 1 and EcoRules.sun_threshold(85) == 2 and EcoRules.sun_threshold(115) == 3, "Configuration bonus")
	var card = EcoRules.card_by_id(3).duplicate(true)
	card.cubes = 3
	board = blank()
	for cell in [Vector2i(0,0), Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(1,1)]: board[cell] = ["trunk", "tree"]
	var cards: Array = [card]
	result = EcoRules.score_game(board, "A", cards, {})
	check(result.animals == 12, "Three cubes use third ladder score")
	card = EcoRules.card_by_id(30).duplicate(true)
	card.cubes = 2
	board = blank()
	for cell in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(0,-1)]: board[cell] = ["building"]
	board[Vector2i(-1,0)] = ["building"]
	result = EcoRules.score_game(board, "A", [card], {})
	check(result.animals == 7, "Boar gets enclosed building bonus")

func test_game_flow() -> void:
	var game = EcoGame.new()
	game.new_game("A", false, 42)
	check(game.bag.size() == 111 and game.deck.size() == 29, "Initial draw counts")
	check(game.market.size() == 3 and game.market[0].size() == 3, "Initial market")
	check(game.faceup.size() == 3, "Three face-up cards")
	check(game.can_draft(0), "Can draft with no spirit")
	check(game.draft_card(0), "Draft succeeds")
	check(not game.can_draft(1), "Only one draft per turn")
	check(not game.refresh_card(1), "No refresh after draft")
	game.select_market(0)
	var token = game.selected_tokens[0]
	var placed = false
	for cell in game.board.keys():
		if EcoRules.can_place(game.board, game.cubes, cell, token):
			game.place_token(cell, 0)
			placed = true
			break
	check(placed and game.selected_tokens.size() == 2, "Placement consumes selected token")
	check(not game.end_turn(), "Cannot end turn with tokens in hand")
	while not game.selected_tokens.is_empty():
		var did_place = false
		for cell in game.board.keys():
			if EcoRules.can_place(game.board, game.cubes, cell, game.selected_tokens[0]):
				game.place_token(cell, 0)
				did_place = true
				break
			if not did_place: break
	check(game.selected_tokens.is_empty(), "Three empty-board placements")
	check(game.end_turn(), "End turn succeeds")
	check(game.turn == 2 and game.bag.size() == 102, "Discard other groups and refill")
	var game2 = EcoGame.new()
	game2.new_game("B", true, 42)
	check(game2.spirit_options.size() == 2, "Two spirit choices")
	check(game2.choose_spirit(1), "Choose spirit")
	check(game2.spirit_options.is_empty(), "Other spirit discarded")
	check(not game2.can_draft(0) == false, "Draft available after spirit")
	var game3 = EcoGame.new()
	game3.new_game("A", false, 1)
	check(not game3.refresh_card(0) or game3.refreshed, "Refresh once")
	check(not game3.refresh_card(1), "No second refresh")

func run_v11_state_tests() -> void:
	var game = EcoGame.new()
	game.new_game("A", false, 1101)
	check(game.select_market(0) and game.can_undo(), "Market selection creates undo history")
	var first: Vector2i = game.board.keys()[0]
	var token = game.selected_tokens[0]
	check(not game.place_token(first, 0).is_empty(), "Place token for undo test")
	check(game.board[first].size() == 1 and game.selected_tokens.size() == 2, "Token placement changes state")
	check(game.undo() and game.board[first].is_empty() and game.selected_tokens.size() == 3, "Undo restores token and selected hand")
	check(game.undo() and game.selected_group == -1 and not game.can_undo(), "Undo market selection and stop at turn boundary")
	var original_card = int(game.faceup[0].id)
	var deck_before = game.deck.size()
	check(game.draft_card(0) and game.acquired.size() == 1, "Draft for undo test")
	check(game.undo() and game.acquired.is_empty() and int(game.faceup[0].id) == original_card and game.deck.size() == deck_before, "Undo restores drafted card and deck")
	check(game.refresh_card(0) and game.refreshed, "Refresh creates undoable action")
	check(game.undo() and int(game.faceup[0].id) == original_card and not game.refreshed, "Undo refresh restores face-up card")
	game = EcoGame.new()
	game.new_game("B", true, 1102)
	check(game.choose_spirit(0), "Spirit selection creates undoable action")
	check(game.undo() and game.spirit.is_empty() and game.spirit_options.size() == 2, "Undo spirit selection")
	game.choose_spirit(1)
	game.draft_card(0)
	var card: Dictionary = game.acquired[0]
	for i in range(card.pattern.size()):
		game.board[card.pattern[i].cell] = EcoRules.stack_for_spec(card.pattern[i].spec)
	var target: Vector2i = card.pattern[card.target].cell
	check(game.place_cube(int(card.id), target) and int(card.cubes) == 1, "Place cube on exact habitat")
	check(game.cubes.has(target) and game.card_points(card) == int(card.scores[0]), "Cube occupies cell and live card score updates")
	check(int(game.score().animals) == game.card_points(card), "Cumulative animal score uses live card points")
	check(game.undo() and not game.cubes.has(target) and int(game.card_instance(int(card.id)).cubes) == 0, "Undo removes cube and live points")
	check(game.place_cube(int(card.id), target), "Place cube again after undo")
	game.select_market(0)
	while not game.selected_tokens.is_empty():
		var placed = false
		for cell in game.board.keys():
			if EcoRules.can_place(game.board, game.cubes, cell, game.selected_tokens[0]):
				game.place_token(cell, 0)
				placed = true
				break
		if not placed:
			break
	check(game.selected_tokens.is_empty() and game.end_turn(), "Complete undo test turn")
	check(not game.can_undo() and not game.undo(), "End turn clears current-turn undo history")
	game = EcoGame.new()
	game.new_game("A", true, 1103)
	game.choose_spirit(0)
	game.draft_card(1)
	game.select_market(2)
	game.place_token(Vector2i(0, 0), 0)
	var saved = game.to_dict()
	var restored = EcoGame.new()
	check(restored.load_dict(saved), "Load versioned JSON save")
	check(restored.side == game.side and restored.turn == game.turn and restored.selected_group == game.selected_group, "Save/load preserves turn and selection")
	check(restored.board == game.board and restored.cubes == game.cubes and restored.selected_tokens == game.selected_tokens, "Save/load preserves board cubes and selected tokens")
	check(card_ids(restored.deck) == card_ids(game.deck) and card_ids(restored.faceup) == card_ids(game.faceup) and card_ids(restored.acquired) == card_ids(game.acquired), "Save/load preserves complete gameplay snapshot")
	check(restored.history.size() == game.history.size(), "Save/load preserves undo history")
	check(restored.undo() and restored.board[Vector2i(0, 0)].is_empty(), "Undo works after loading")
	var rng_a = EcoGame.new()
	var rng_b = EcoGame.new()
	rng_a.new_game("A", false, 1104)
	rng_b.load_dict(rng_a.to_dict())
	check(rng_a._draw_tokens(9) == rng_b._draw_tokens(9) and card_ids(rng_a._draw_tokens(5)) == card_ids(rng_b._draw_tokens(5)), "Deck and RNG continue identically after load")
	check(not restored.load_dict({"save_version": 999}), "Reject incompatible save versions")

