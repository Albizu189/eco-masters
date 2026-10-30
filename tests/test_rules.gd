extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const State = preload("res://scripts/game_state.gd")
var failures = 0
var checks = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func spec_stack(spec: String) -> Array:
	match spec:
		"W": return ["water"]
		"Y": return ["field"]
		"T1": return ["tree"]
		"T2": return ["trunk", "tree"]
		"T3": return ["trunk", "trunk", "tree"]
		"M1": return ["mountain"]
		"M2": return ["mountain", "mountain"]
		"M3": return ["mountain", "mountain", "mountain"]
		"B1": return ["building"]
		"B2": return ["mountain", "building"]
	return []

func _init() -> void:
	run_tests()
	run_v11_state_tests()
	print("Eco Masters rules: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func run_tests() -> void:
	check(Rules.board_cells("A").size() == 25, "Side A has 25 cells")
	check(Rules.board_cells("B").size() == 25, "Side B has 25 cells")
	var board = Rules.empty_board("A")
	var cubes = {}
	var c = Vector2i(0, 0)
	check(Rules.can_place(board, cubes, c, "water"), "Water on empty")
	board[c] = ["water"]
	check(not Rules.can_place(board, cubes, c, "mountain"), "Water cannot be stacked")
	board[c] = ["mountain"]
	check(Rules.can_place(board, cubes, c, "mountain"), "Mountain on mountain")
	board[c] = ["mountain", "mountain", "mountain"]
	check(not Rules.can_place(board, cubes, c, "mountain"), "Mountain height cap")
	board[c] = ["trunk"]
	check(Rules.can_place(board, cubes, c, "tree"), "Foliage on one trunk")
	board[c] = ["trunk", "trunk"]
	check(Rules.can_place(board, cubes, c, "tree"), "Foliage on two trunks")
	check(not Rules.can_place(board, cubes, c, "trunk"), "Trunk height cap")
	board[c] = ["building"]
	check(Rules.can_place(board, cubes, c, "building"), "Building second level")
	board[c] = ["building", "building"]
	check(not Rules.can_place(board, cubes, c, "building"), "Building height cap")
	board[c] = []
	cubes[c] = 1
	check(not Rules.can_place(board, cubes, c, "field"), "Animal cube blocks placement")
	cubes.clear()
	for spec in ["W", "Y", "T1", "T2", "T3", "M1", "M2", "M3", "B1", "B2"]:
		check(Rules.matches_spec(spec_stack(spec), spec), "Exact habitat spec " + spec)
	check(not Rules.matches_spec(["mountain", "mountain"], "M3"), "Mountain height must be exact")
	check(not Rules.matches_spec(["tree"], "T2"), "Tree height must be exact")
	# Every habitat card, every rotation, using an unconstrained test board.
	for card in Rules.CARDS:
		var offsets = Rules.shape_offsets(card.shape)
		for rotation in range(6):
			board.clear()
			for q in range(-5, 6):
				for r in range(-5, 6):
					board[Vector2i(q, r)] = []
			for i in range(offsets.size()):
				board[offsets[i]] = spec_stack(card.pattern[i])
			var targets = Rules.valid_cube_cells(card, board, cubes)
			check(targets.has(offsets[int(card.target)]), "Card %d rotation %d" % [int(card.id), rotation])
			for i in range(offsets.size()):
				offsets[i] = Rules.rotate_cell(offsets[i])
	# Terrain scoring.
	board = Rules.empty_board("A")
	board[Vector2i(0, 0)] = ["tree"]
	board[Vector2i(0, 1)] = ["trunk", "tree"]
	board[Vector2i(0, 2)] = ["trunk", "trunk", "tree"]
	board[Vector2i(1, 0)] = ["trunk"]
	var score = Rules.score_game(board, "A", [], {})
	check(score.trees == 11, "Trees score 1 + 3 + 7")
	board = Rules.empty_board("A")
	board[Vector2i(0, 0)] = ["mountain"]
	check(Rules.score_game(board, "A", [], {}).mountains == 0, "Isolated mountain scores zero")
	board[Vector2i(1, 0)] = ["mountain", "mountain"]
	check(Rules.score_game(board, "A", [], {}).mountains == 4, "Connected mountains score 1 + 3")
	board[Vector2i(0, 1)] = ["field"]
	board[Vector2i(0, 2)] = ["field"]
	check(Rules.score_game(board, "A", [], {}).fields == 5, "One field group scores five")
	board = Rules.empty_board("A")
	board[Vector2i(0, 0)] = ["water"]
	board[Vector2i(1, 0)] = ["water"]
	board[Vector2i(2, 0)] = ["water"]
	check(Rules.score_game(board, "A", [], {}).water == 5, "River of three scores five")
	board[Vector2i(3, 0)] = ["tree"]
	board[Vector2i(3, 1)] = ["field"]
	check(Rules.score_game(board, "B", [], {}).water == 5, "Side B separate land area scores five")
	board = Rules.empty_board("A")
	board[Vector2i(0, 0)] = ["mountain", "building"]
	board[Vector2i(1, 0)] = ["water"]
	board[Vector2i(0, 1)] = ["field"]
	board[Vector2i(-1, 0)] = ["tree"]
	check(Rules.score_game(board, "A", [], {}).buildings == 5, "Building beside three colors")
	# Animal ladder and sun conversion.
	var animal = Rules.card_by_id(5).duplicate(true)
	animal["cubes"] = 3
	score = Rules.score_game(Rules.empty_board("A"), "A", [animal], {})
	check(score.animals == 6 and score.total == 6, "Animal score ladder")
	check(score.base_suns == 0 and score.suns == 3, "Side A and no-spirit sun bonuses")
	board = Rules.empty_board("A")
	for i in range(5):
		board[Vector2i(0, i)] = ["trunk", "trunk", "tree"]
	score = Rules.score_game(board, "A", [], {})
	check(score.total == 35 and score.base_suns == 0, "Below first sun threshold")
	board[Vector2i(1, 0)] = ["trunk", "trunk", "tree"]
	score = Rules.score_game(board, "A", [], {})
	check(score.total == 42 and score.base_suns == 1, "Forty points earns one sun")
	# Solo state and deterministic market.
	var state = State.new()
	state.new_game("A", true, 12345)
	check(state.bag.size() == 111 and state.market.size() == 3, "Initial pouch and market")
	check(state.deck.size() == 29 and state.faceup.size() == 3, "Initial animal deck")
	check(state.spirit_options.size() == 2, "Two spirit choices")
	check(state.choose_spirit(0) and state.active_count() == 1, "Spirit occupies active slot")
	check(state.select_market(0), "Select market group")
	for i in range(3):
		var placed = false
		for cell in state.board.keys():
			if Rules.can_place(state.board, state.cubes, cell, state.selected_tokens[0]):
				state.place_token(cell, 0)
				placed = true
				break
		check(placed, "Place initial token %d" % i)
	check(state.end_turn() and state.bag.size() == 102 and state.market.size() == 3, "Turn refresh discards six and draws nine")

func card_ids(cards: Array) -> Array:
	var ids: Array = []
	for card in cards:
		ids.append(int(card.get("id", 0)) if card is Dictionary else 0)
	return ids

func run_v11_state_tests() -> void:
	# Token placement and market selection are reversible within the turn.
	var state = State.new()
	state.new_game("A", false, 8101)
	check(state.select_market(0) and state.history.size() == 1, "Market selection creates undo history")
	var cell = Vector2i(-1, 0)
	while not Rules.can_place(state.board, state.cubes, cell, state.selected_tokens[0]):
		cell = state.board.keys()[state.board.keys().find(cell) + 1]
	var token = state.selected_tokens[0]
	check(not state.place_token(cell, 0).is_empty() and state.board[cell] == [token], "Token placement changes board")
	check(state.undo() and state.board[cell].is_empty() and state.selected_tokens.size() == 3, "Undo restores token and board")
	check(state.undo() and state.selected_group == -1 and state.history.is_empty(), "Undo can reverse market selection")
	check(not state.undo(), "Undo stops at start of turn")

	# Drafting and refreshing restore both cards and deck order.
	state.new_game("B", false, 8102)
	var old_faceup = state.faceup.duplicate(true)
	var old_deck = state.deck.duplicate(true)
	check(state.draft_card(1) and state.acquired.size() == 1 and state.drafted, "Draft records active card")
	check(state.undo() and state.acquired.is_empty() and not state.drafted and state.faceup == old_faceup and state.deck == old_deck, "Draft undo restores face-up cards and deck")
	var old_card = state.faceup[2].duplicate(true)
	check(state.refresh_card(2) and state.refreshed and state.faceup[2] != old_card, "Face-up refresh changes card")
	check(state.undo() and not state.refreshed and state.faceup[2] == old_card and state.deck == old_deck, "Refresh undo restores card and deck")

	# Build an exact habitat, then verify cube undo and live card points.
	state.new_game("A", false, 8103)
	var animal = Rules.card_by_id(1).duplicate(true)
	animal["cubes"] = 0
	state.acquired = [animal]
	var offsets = Rules.shape_offsets(animal.shape)
	for i in range(offsets.size()):
		state.board[offsets[i]] = spec_stack(animal.pattern[i])
	var target = offsets[int(animal.target)]
	check(state.available_cube_cells(int(animal.id)).has(target), "Exact test habitat accepts animal cube")
	check(state.card_points(animal) == 0, "Incomplete animal starts at zero points")
	check(state.place_cube(int(animal.id), target) and state.cubes[target] == int(animal.id), "Animal cube occupies target")
	check(state.card_points(animal) == int(animal.scores[0]) and int(state.score().animals) == int(animal.scores[0]), "Live card and total animal points update")
	check(state.undo() and state.cubes.is_empty() and int(state.card_instance(int(animal.id)).cubes) == 0, "Cube undo removes occupancy and cube")
	check(state.card_points(state.card_instance(int(animal.id))) == 0 and int(state.score().animals) == 0, "Undo recalculates card and total points")

	# Ending a turn starts a new undo boundary.
	state.new_game("A", false, 8104)
	state.select_market(0)
	for i in range(3):
		var placed = false
		for candidate in state.board.keys():
			if Rules.can_place(state.board, state.cubes, candidate, state.selected_tokens[0]):
				state.place_token(candidate, 0)
				placed = true
				break
		check(placed, "Undo boundary token placement %d" % i)
	check(state.end_turn() and state.turn == 2 and state.history.is_empty(), "End turn clears current-turn history")
	check(not state.can_undo() and not state.undo(), "Previous turn cannot be undone")

	# JSON persistence preserves the complete state, RNG, and saved undo stack.
	state.new_game("B", false, 8105)
	state.select_market(2)
	var saved_text = JSON.stringify(state.to_dict())
	var parsed = JSON.parse_string(saved_text)
	var restored = State.new()
	check(parsed is Dictionary and restored.load_dict(parsed), "Versioned JSON save loads")
	var same_state = restored.side == state.side and restored.board == state.board and restored.cubes == state.cubes and restored.bag == state.bag and restored.market == state.market and restored.selected_tokens == state.selected_tokens and restored.selected_group == state.selected_group and restored.turn == state.turn and restored.drafted == state.drafted and restored.refreshed == state.refreshed and restored.ended == state.ended and restored.end_reason == state.end_reason and restored.rng.state == state.rng.state
	same_state = same_state and card_ids(restored.deck) == card_ids(state.deck) and card_ids(restored.faceup) == card_ids(state.faceup) and card_ids(restored.acquired) == card_ids(state.acquired) and card_ids(restored.spirit_options) == card_ids(state.spirit_options)
	check(same_state, "Save/load preserves complete gameplay snapshot")
	check(restored.history.size() == state.history.size() and restored.can_undo(), "Save/load preserves undo history")
	check(restored.undo() and restored.selected_group == -1, "Loaded game can undo saved action")
	check(not restored.load_dict({"save_version": 1}), "Incompatible save version is rejected")

	# Both instances must draw the same next card after restoration.
	state.new_game("A", false, 8106)
	restored = State.new()
	restored.load_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	check(state.refresh_card(0) and restored.refresh_card(0), "Saved RNG allows matching refresh")
	check(card_ids(state.faceup) == card_ids(restored.faceup) and card_ids(state.deck) == card_ids(restored.deck) and state.rng.state == restored.rng.state, "Deck and RNG continue identically after load")
