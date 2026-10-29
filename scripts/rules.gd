class_name EcoRules
extends RefCounted

# Original Eco Masters implementation of the solo habitat mechanics.
# Token names: water, mountain, trunk, tree, field, building.
const NEIGHBORS = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1)]
const TOKEN_COUNTS = {"water": 23, "mountain": 23, "trunk": 21, "tree": 19, "field": 19, "building": 15}
const TOKEN_ORDER = ["water", "mountain", "trunk", "tree", "field", "building"]

const CARDS = [
	{"id": 1, "name": "Crocodile", "kind": "animal", "shape": "line3", "pattern": ["T2", "W", "W"], "target": 2, "scores": [4, 9, 15]},
	{"id": 2, "name": "River Otter", "kind": "animal", "shape": "tri3", "pattern": ["M1", "M1", "W"], "target": 2, "scores": [4, 10, 16]},
	{"id": 3, "name": "Manatee", "kind": "animal", "shape": "pair", "pattern": ["M3", "W"], "target": 1, "scores": [3, 6, 10, 16]},
	{"id": 4, "name": "Platypus", "kind": "animal", "shape": "line3", "pattern": ["T1", "T1", "W"], "target": 2, "scores": [5, 10, 16]},
	{"id": 5, "name": "Tree Frog", "kind": "animal", "shape": "pair", "pattern": ["T1", "W"], "target": 1, "scores": [2, 4, 6, 10, 15]},
	{"id": 6, "name": "Duck", "kind": "animal", "shape": "pair", "pattern": ["B2", "W"], "target": 1, "scores": [2, 4, 8, 13]},
	{"id": 7, "name": "Flamingo", "kind": "animal", "shape": "tri3", "pattern": ["Y", "Y", "W"], "target": 2, "scores": [4, 10, 16]},
	{"id": 8, "name": "Chameleon", "kind": "animal", "shape": "line3", "pattern": ["Y", "Y", "B2"], "target": 2, "scores": [5, 10, 16]},
	{"id": 9, "name": "Shrew", "kind": "animal", "shape": "tri3", "pattern": ["Y", "B2", "Y"], "target": 1, "scores": [5, 10, 17]},
	{"id": 10, "name": "Peacock", "kind": "animal", "shape": "tri3", "pattern": ["W", "B2", "W"], "target": 1, "scores": [5, 10, 17]},
	{"id": 11, "name": "Squirrel", "kind": "animal", "shape": "pair", "pattern": ["T3", "B2"], "target": 1, "scores": [4, 9, 15]},
	{"id": 12, "name": "Hedgehog", "kind": "animal", "shape": "tri3", "pattern": ["T2", "T2", "B2"], "target": 2, "scores": [5, 12]},
	{"id": 13, "name": "Bee", "kind": "animal", "shape": "diamond4", "pattern": ["T2", "Y", "Y", "Y"], "target": 0, "scores": [8, 18]},
	{"id": 14, "name": "Bear", "kind": "animal", "shape": "tri3", "pattern": ["M2", "M2", "T1"], "target": 2, "scores": [5, 11]},
	{"id": 15, "name": "Rabbit", "kind": "animal", "shape": "line3", "pattern": ["B2", "T1", "T1"], "target": 2, "scores": [5, 10, 17]},
	{"id": 16, "name": "Parrot", "kind": "animal", "shape": "tri3", "pattern": ["W", "W", "T2"], "target": 2, "scores": [4, 9, 14]},
	{"id": 17, "name": "Wild Boar", "kind": "animal", "shape": "pair", "pattern": ["B2", "T2"], "target": 1, "scores": [4, 8, 13]},
	{"id": 18, "name": "Koala", "kind": "animal", "shape": "pair", "pattern": ["T1", "T2"], "target": 1, "scores": [3, 6, 10, 15]},
	{"id": 19, "name": "Wolf", "kind": "animal", "shape": "tri3", "pattern": ["Y", "Y", "T3"], "target": 2, "scores": [4, 10, 16]},
	{"id": 20, "name": "Kingfisher", "kind": "animal", "shape": "tri3", "pattern": ["W", "T3", "W"], "target": 1, "scores": [5, 11, 18]},
	{"id": 21, "name": "Penguin", "kind": "animal", "shape": "tri3", "pattern": ["W", "M1", "W"], "target": 1, "scores": [4, 10, 16]},
	{"id": 22, "name": "Bat", "kind": "animal", "shape": "pair", "pattern": ["T3", "M1"], "target": 1, "scores": [3, 6, 10, 15]},
	{"id": 23, "name": "Fennec Fox", "kind": "animal", "shape": "line3", "pattern": ["Y", "M1", "M2"], "target": 2, "scores": [4, 9, 16]},
	{"id": 24, "name": "Chicken", "kind": "animal", "shape": "tri3", "pattern": ["W", "W", "M2"], "target": 2, "scores": [5, 11]},
	{"id": 25, "name": "Condor", "kind": "animal", "shape": "pair", "pattern": ["Y", "M3"], "target": 1, "scores": [5, 11]},
	{"id": 26, "name": "Meerkat", "kind": "animal", "shape": "pair", "pattern": ["Y", "M1"], "target": 1, "scores": [2, 5, 9, 14]},
	{"id": 27, "name": "Raven", "kind": "animal", "shape": "line3", "pattern": ["B2", "Y", "B2"], "target": 1, "scores": [4, 9]},
	{"id": 28, "name": "Llama", "kind": "animal", "shape": "line3", "pattern": ["M2", "Y", "Y"], "target": 2, "scores": [5, 12]},
	{"id": 29, "name": "Mountain Goat", "kind": "animal", "shape": "line3", "pattern": ["T2", "Y", "T2"], "target": 1, "scores": [5, 10, 17]},
	{"id": 30, "name": "Cow", "kind": "animal", "shape": "diamond4", "pattern": ["Y", "W", "W", "W"], "target": 0, "scores": [6, 12]},
	{"id": 31, "name": "Ladybug", "kind": "animal", "shape": "pair", "pattern": ["T1", "Y"], "target": 1, "scores": [2, 5, 8, 12, 17]},
	{"id": 32, "name": "Black Panther", "kind": "animal", "shape": "line3", "pattern": ["T2", "T2", "Y"], "target": 2, "scores": [5, 11]},
	{"id": 33, "name": "Lion", "kind": "spirit", "shape": "line3", "pattern": ["T2", "Y", "Y"], "target": 1, "scores": [0], "group": true, "rule": "10 points per field group of 3+ tokens; otherwise 2 per group."},
	{"id": 34, "name": "Butterfly", "kind": "spirit", "shape": "diamond4", "pattern": ["W", "Y", "Y", "W"], "target": 2, "scores": [0], "group": true, "rule": "5 points per field group, including single fields."},
	{"id": 35, "name": "Deer", "kind": "spirit", "shape": "line3", "pattern": ["T3", "T2", "T1"], "target": 1, "scores": [0], "group": false, "rule": "4 points per tree of height 2 or 3."},
	{"id": 36, "name": "Owl", "kind": "spirit", "shape": "tri3", "pattern": ["T1", "T1", "T3"], "target": 2, "scores": [0], "group": false, "rule": "3 points per tree of height 1 or 2; 1 per height-3 tree."},
	{"id": 37, "name": "Black Cat", "kind": "spirit", "shape": "line3", "pattern": ["B1", "T1", "B2"], "target": 2, "scores": [0], "group": true, "rule": "4 points per building group, including single buildings."},
	{"id": 38, "name": "Stork", "kind": "spirit", "shape": "line3", "pattern": ["Y", "B2", "B2"], "target": 2, "scores": [0], "group": true, "rule": "6 points per building group of 2+ buildings."},
	{"id": 39, "name": "Ram", "kind": "spirit", "shape": "pair", "pattern": ["M2", "M3"], "target": 1, "scores": [0], "group": false, "rule": "4 points per mountain of height 2 or 3."},
	{"id": 40, "name": "Marmot", "kind": "spirit", "shape": "tri3", "pattern": ["M1", "M2", "M1"], "target": 1, "scores": [0], "group": false, "rule": "3 points per mountain of height 1 or 2; 1 per height-3 mountain."},
	{"id": 41, "name": "Dragonfly", "kind": "spirit", "shape": "line3", "pattern": ["T2", "W", "T2"], "target": 1, "scores": [0], "group": true, "rule": "7 points per water group of 2+ tokens."},
	{"id": 42, "name": "Turtle", "kind": "spirit", "shape": "line3", "pattern": ["M2", "W", "W"], "target": 1, "scores": [0], "group": false, "rule": "2 points per water token."}
]

static func board_cells(side: String) -> Array:
	var cells: Array = []
	if side == "A":
		for q in range(5):
			var starts = [0, 0, -1, -1, -2]
			var ends = [4, 4, 3, 3, 2]
			for r in range(starts[q], ends[q] + 1):
				cells.append(Vector2i(q, r))
	else:
		for q in range(7):
			var starts = [0, 0, -1, -1, -2, -2, -3]
			var ends = [3, 2, 2, 1, 1, 0, 0]
			for r in range(starts[q], ends[q] + 1):
				cells.append(Vector2i(q, r))
	return cells

static func card_by_id(card_id: int) -> Dictionary:
	return CARDS[card_id - 1]

static func empty_board(side: String) -> Dictionary:
	var board = {}
	for cell in board_cells(side):
		board[cell] = []
	return board

static func can_place(board: Dictionary, cubes: Dictionary, cell: Vector2i, token: String) -> bool:
	if not board.has(cell) or cubes.has(cell):
		return false
	var stack: Array = board[cell]
	if stack.is_empty():
		return true
	var top: String = stack[-1]
	if top in ["water", "field", "tree"]:
		return false
	match token:
		"mountain":
			return top == "mountain" and stack.size() < 3
		"trunk":
			return top == "trunk" and stack.size() < 2
		"tree":
			return top == "trunk" and stack.size() <= 2
		"building":
			return top in ["mountain", "trunk", "building"] and stack.size() < 2
		_:
			return false

static func matches_spec(stack: Array, spec: String) -> bool:
	if stack.is_empty():
		return false
	var top: String = stack[-1]
	match spec:
		"W": return stack == ["water"]
		"Y": return stack == ["field"]
		"T1": return stack == ["tree"]
		"T2": return stack == ["trunk", "tree"]
		"T3": return stack == ["trunk", "trunk", "tree"]
		"M1": return stack == ["mountain"]
		"M2": return stack == ["mountain", "mountain"]
		"M3": return stack == ["mountain", "mountain", "mountain"]
		"B1": return stack.size() == 1 and top == "building"
		"B2": return stack.size() == 2 and top == "building"
		_: return false

static func rotate_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(-cell.y, cell.x + cell.y)

static func shape_offsets(shape: String) -> Array:
	match shape:
		"pair": return [Vector2i(0, 0), Vector2i(1, 0)]
		"line3": return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		"tri3": return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
		"diamond4": return [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]
		_: return []

static func valid_cube_cells(card: Dictionary, board: Dictionary, cubes: Dictionary) -> Array:
	var targets: Array = []
	var base = shape_offsets(card.shape)
	var offsets = base.duplicate()
	for rotation in range(6):
		for anchor in board.keys():
			var matched = true
			var target_cell = Vector2i.ZERO
			for i in range(offsets.size()):
				var cell: Vector2i = anchor + offsets[i]
				if not board.has(cell) or not matches_spec(board[cell], card.pattern[i]):
					matched = false
					break
				if i == int(card.target):
					target_cell = cell
			if matched and not cubes.has(target_cell) and not targets.has(target_cell):
				targets.append(target_cell)
		for i in range(offsets.size()):
			offsets[i] = rotate_cell(offsets[i])
	return targets

static func _groups(cells: Array) -> Array:
	var remaining = cells.duplicate()
	var groups: Array = []
	while not remaining.is_empty():
		var start = remaining.pop_back()
		var group: Array = [start]
		var queue: Array = [start]
		var index = 0
		while index < queue.size():
			var cell = queue[index]
			index += 1
			for direction in NEIGHBORS:
				var other: Vector2i = cell + direction
				if remaining.has(other):
					remaining.erase(other)
					queue.append(other)
					group.append(other)
		groups.append(group)
	return groups

static func _top_tokens(board: Dictionary, token: String) -> Array:
	var cells: Array = []
	for cell in board.keys():
		var stack: Array = board[cell]
		if not stack.is_empty() and stack[-1] == token:
			cells.append(cell)
	return cells

static func _river_diameter(waters: Array) -> int:
	var water_set = {}
	for cell in waters:
		water_set[cell] = true
	var longest = 0
	for start in waters:
		var distances = {start: 0}
		var queue: Array = [start]
		var index = 0
		while index < queue.size():
			var cell = queue[index]
			index += 1
			longest = maxi(longest, int(distances[cell]) + 1)
			for direction in NEIGHBORS:
				var other: Vector2i = cell + direction
				if water_set.has(other) and not distances.has(other):
					distances[other] = int(distances[cell]) + 1
					queue.append(other)
	return longest

static func _water_score(length: int) -> int:
	var values = [0, 0, 2, 5, 8, 11, 15]
	if length < values.size():
		return values[length]
	return 15 + (length - 6) * 4

static func _spirit_score(spirit: Dictionary, board: Dictionary, fields: Array, buildings: Array, waters: Array) -> int:
	if spirit.is_empty() or int(spirit.get("cubes", 0)) == 0:
		return 0
	var total = 0
	match int(spirit.id):
		33:
			for group in fields:
				total += 10 if group.size() >= 3 else 2
		34:
			total = fields.size() * 5
		35:
			for stack in board.values():
				if stack in [["trunk", "tree"], ["trunk", "trunk", "tree"]]:
					total += 4
		36:
			for stack in board.values():
				if stack in [["tree"], ["trunk", "tree"]]:
					total += 3
				elif stack == ["trunk", "trunk", "tree"]:
					total += 1
		37:
			total = buildings.size() * 4
		38:
			for group in buildings:
				if group.size() >= 2:
					total += 6
		39:
			for stack in board.values():
				if stack in [["mountain", "mountain"], ["mountain", "mountain", "mountain"]]:
					total += 4
		40:
			for stack in board.values():
				if stack in [["mountain"], ["mountain", "mountain"]]:
					total += 3
				elif stack == ["mountain", "mountain", "mountain"]:
					total += 1
		41:
			for group in _groups(waters):
				if group.size() >= 2:
					total += 7
		42:
			total = waters.size() * 2
	return total

static func score_game(board: Dictionary, side: String, cards: Array, spirit: Dictionary) -> Dictionary:
	var result = {"trees": 0, "mountains": 0, "fields": 0, "buildings": 0, "water": 0, "animals": 0, "spirit": 0}
	var fields = _groups(_top_tokens(board, "field"))
	var buildings = _groups(_top_tokens(board, "building"))
	var waters = _top_tokens(board, "water")
	var mountain_cells = _top_tokens(board, "mountain")
	for cell in board.keys():
		var stack: Array = board[cell]
		if stack.is_empty():
			continue
		var top: String = stack[-1]
		if top == "tree":
			result.trees += [0, 1, 3, 7][stack.size()]
		elif top == "mountain":
			var connected = false
			for direction in NEIGHBORS:
				if mountain_cells.has(cell + direction):
					connected = true
					break
			if connected:
				result.mountains += [0, 1, 3, 7][stack.size()]
		elif top == "building" and stack.size() == 2:
			var colors = {}
			for direction in NEIGHBORS:
				var other: Vector2i = cell + direction
				if board.has(other) and not board[other].is_empty():
					colors[board[other][-1]] = true
			if colors.size() >= 3:
				result.buildings += 5
	for group in fields:
		if group.size() >= 2:
			result.fields += 5
	if side == "A":
		result.water = _water_score(_river_diameter(waters))
	else:
		var lands: Array = []
		for cell in board.keys():
			var stack: Array = board[cell]
			if not stack.is_empty() and stack[-1] != "water":
				lands.append(cell)
		result.water = _groups(lands).size() * 5
	for card in cards:
		var count = clampi(int(card.get("cubes", 0)), 0, card.scores.size())
		if count > 0:
			result.animals += int(card.scores[count - 1])
	result.spirit = _spirit_score(spirit, board, fields, buildings, waters)
	var total = 0
	for key in result.keys():
		total += int(result[key])
	result.total = total
	var base_suns = 0
	var thresholds = [40, 70, 90, 110, 130, 140, 150, 160]
	for threshold in thresholds:
		if total >= threshold:
			base_suns += 1
	var configuration = 0
	if side == "A":
		configuration += 1
	if spirit.is_empty():
		configuration += 2
	elif bool(spirit.get("group", false)) and int(spirit.get("cubes", 0)) > 0:
		configuration += 1
	result.base_suns = base_suns
	result.configuration = configuration
	result.suns = base_suns + configuration
	return result
