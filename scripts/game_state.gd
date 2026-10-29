class_name EcoGame
extends RefCounted

var side = "A"
var board: Dictionary = {}
var cubes: Dictionary = {}
var bag: Array = []
var deck: Array = []
var market: Array = []
var faceup: Array = []
var acquired: Array = []
var spirit: Dictionary = {}
var spirit_options: Array = []
var spirit_enabled = true
var turn = 1
var selected_group = -1
var selected_tokens: Array = []
var drafted = false
var refreshed = false
var ended = false
var end_reason = ""
var rng = RandomNumberGenerator.new()

func new_game(board_side: String = "A", with_spirit: bool = true, seed_value: int = -1) -> void:
	side = board_side
	spirit_enabled = with_spirit
	board = EcoRules.empty_board(side)
	cubes.clear()
	bag.clear()
	deck.clear()
	market.clear()
	faceup.clear()
	acquired.clear()
	spirit.clear()
	spirit_options.clear()
	turn = 1
	selected_group = -1
	selected_tokens.clear()
	drafted = false
	refreshed = false
	ended = false
	end_reason = ""
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for token in EcoRules.TOKEN_ORDER:
		for index in range(int(EcoRules.TOKEN_COUNTS[token])):
			bag.append(token)
	_shuffle(bag)
	for card in EcoRules.CARDS:
		if card.kind == "animal":
			deck.append(card.duplicate(true))
	_shuffle(deck)
	for index in range(3):
		market.append(_draw_tokens(3))
		faceup.append(_draw_animal())
	if spirit_enabled:
		var spirits: Array = []
		for card in EcoRules.CARDS:
			if card.kind == "spirit":
				spirits.append(card.duplicate(true))
		_shuffle(spirits)
		spirit_options = [spirits.pop_back(), spirits.pop_back()]

func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temporary = items[i]
		items[i] = items[j]
		items[j] = temporary

func _draw_tokens(count: int) -> Array:
	var tokens: Array = []
	for index in range(mini(count, bag.size())):
		tokens.append(bag.pop_back())
	return tokens

func _draw_animal() -> Dictionary:
	if deck.is_empty():
		return {}
	return deck.pop_back()

func choose_spirit(index: int) -> bool:
	if not spirit_enabled or not spirit.is_empty() or index < 0 or index >= spirit_options.size():
		return false
	spirit = spirit_options[index].duplicate(true)
	spirit["cubes"] = 0
	spirit_options.clear()
	return true

func active_count() -> int:
	var count = 0
	for card in acquired:
		if int(card.cubes) < card.scores.size():
			count += 1
	if not spirit.is_empty() and int(spirit.get("cubes", 0)) == 0:
		count += 1
	return count

func can_draft(index: int) -> bool:
	return not ended and not drafted and index >= 0 and index < faceup.size() and not faceup[index].is_empty() and active_count() < 4 and (not spirit_enabled or not spirit.is_empty())

func draft_card(index: int) -> bool:
	if not can_draft(index):
		return false
	var card: Dictionary = faceup[index]
	card["cubes"] = 0
	acquired.append(card)
	faceup[index] = _draw_animal()
	drafted = true
	return true

func refresh_card(index: int) -> bool:
	if ended or drafted or refreshed or index < 0 or index >= faceup.size() or faceup[index].is_empty() or deck.is_empty():
		return false
	faceup[index] = _draw_animal()
	refreshed = true
	return true

func select_market(index: int) -> bool:
	if ended or selected_group >= 0 or index < 0 or index >= market.size():
		return false
	selected_group = index
	selected_tokens = market[index].duplicate()
	return true

func place_token(cell: Vector2i, token_index: int) -> String:
	if ended or selected_group < 0 or token_index < 0 or token_index >= selected_tokens.size():
		return ""
	var token: String = selected_tokens[token_index]
	if not EcoRules.can_place(board, cubes, cell, token):
		return ""
	board[cell].append(token)
	selected_tokens.remove_at(token_index)
	return token

func card_instance(card_id: int) -> Dictionary:
	if not spirit.is_empty() and int(spirit.id) == card_id:
		return spirit
	for card in acquired:
		if int(card.id) == card_id:
			return card
	return {}

func available_cube_cells(card_id: int) -> Array:
	var card = card_instance(card_id)
	if card.is_empty() or ended:
		return []
	if card.kind == "spirit" and int(card.get("cubes", 0)) > 0:
		return []
	if card.kind == "animal" and int(card.get("cubes", 0)) >= card.scores.size():
		return []
	return EcoRules.valid_cube_cells(card, board, cubes)

func place_cube(card_id: int, cell: Vector2i) -> bool:
	if not available_cube_cells(card_id).has(cell):
		return false
	var card = card_instance(card_id)
	card["cubes"] = int(card.get("cubes", 0)) + 1
	cubes[cell] = card_id
	return true

func empty_cells() -> int:
	var count = 0
	for stack in board.values():
		if stack.is_empty():
			count += 1
	return count

func has_legal_token_placement() -> bool:
	for token in selected_tokens:
		for cell in board.keys():
			if EcoRules.can_place(board, cubes, cell, token):
				return true
	return false

func end_turn() -> bool:
	if ended or selected_group < 0 or not selected_tokens.is_empty():
		return false
	market.clear()
	selected_group = -1
	turn += 1
	drafted = false
	refreshed = false
	if bag.size() < 9:
		ended = true
		end_reason = "The token pouch cannot refill the market."
		return true
	for index in range(3):
		market.append(_draw_tokens(3))
	if empty_cells() <= 2:
		ended = true
		end_reason = "Only two open board spaces remain."
	return true

func finish_early() -> void:
	ended = true
	end_reason = "No legal space remains for the selected tokens."

func score() -> Dictionary:
	return EcoRules.score_game(board, side, acquired, spirit)
