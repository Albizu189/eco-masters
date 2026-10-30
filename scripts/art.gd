class_name EcoArt
extends RefCounted

static var INK = Color("203b35")
static var MUTED = Color("667b70")
static var CREAM = Color("f7f3e8")
static var PAPER = Color("fffdf6")
static var GREEN = Color("31715b")
static var LIGHT_GREEN = Color("dce9d7")
static var GOLD = Color("b47b16")

# Okabe–Ito-inspired hues remain separable under common color-vision deficiencies.
# Terrain silhouettes and internal marks provide a second, non-color cue.
const TOKEN_COLORS = {
	"water": Color("56b4e9"),
	"mountain": Color("858585"),
	"trunk": Color("9b6748"),
	"tree": Color("009e73"),
	"field": Color("f0d54a"),
	"building": Color("d55e00")
}

static func set_dark_mode(enabled: bool) -> void:
	if enabled:
		INK = Color("edf4ef")
		MUTED = Color("adbbb3")
		CREAM = Color("12211e")
		PAPER = Color("20312b")
		GREEN = Color("75c9a3")
		LIGHT_GREEN = Color("29473b")
		GOLD = Color("e4b85c")
	else:
		INK = Color("203b35")
		MUTED = Color("667b70")
		CREAM = Color("f7f3e8")
		PAPER = Color("fffdf6")
		GREEN = Color("31715b")
		LIGHT_GREEN = Color("dce9d7")
		GOLD = Color("b47b16")

static func text(canvas: CanvasItem, font: Font, value: String, position: Vector2, size: int, color: Color = Color("203b35"), width: float = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if value.is_empty():
		return
	if color == Color("203b35"):
		color = INK
	canvas.draw_string(font, position, value, align, width, size, color)

static func panel(canvas: CanvasItem, rect: Rect2, color: Color = Color("fffdf6"), radius: float = 16, shadow: bool = true) -> void:
	if color == Color("fffdf6"):
		color = PAPER
	if shadow:
		_round_rect(canvas, Rect2(rect.position + Vector2(0, 4), rect.size), Color(0.08, 0.14, 0.12, 0.12), radius)
	_round_rect(canvas, rect, color, radius)

static func outline(canvas: CanvasItem, rect: Rect2, color: Color, radius: float = 16, thickness: float = 2) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(int(thickness))
	style.set_corner_radius_all(int(radius))
	canvas.draw_style_box(style, rect)

static func _round_rect(canvas: CanvasItem, rect: Rect2, color: Color, radius: float) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	canvas.draw_style_box(style, rect)

static func hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func hex(canvas: CanvasItem, center: Vector2, radius: float, fill: Color, border: Color = Color.TRANSPARENT, thickness: float = 1.5) -> void:
	var points = hex_points(center, radius)
	canvas.draw_colored_polygon(points, fill)
	if border.a > 0:
		points.append(points[0])
		canvas.draw_polyline(points, border, thickness, true)

static func token(canvas: CanvasItem, kind: String, center: Vector2, radius: float, muted: bool = false) -> void:
	var color: Color = TOKEN_COLORS.get(kind, Color("b0b0a8"))
	if muted:
		color = color.darkened(0.25)
	hex(canvas, center, radius, color, color.darkened(0.24), maxf(1.2, radius * 0.055))
	var ink = Color("203b35") if kind in ["water", "field", "mountain"] else Color("fffdf6")
	if kind == "water":
		for offset in [-0.22, 0.18]:
			var y = center.y + radius * offset
			canvas.draw_arc(center + Vector2(0, offset * radius), radius * 0.42, 0.15, PI - 0.15, 18, ink, maxf(1.2, radius * 0.06), true)
			canvas.draw_line(center + Vector2(-radius * 0.4, y), center + Vector2(radius * 0.4, y), Color(ink, 0.45), maxf(1.0, radius * 0.035), true)
	elif kind == "mountain":
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.52, 0.35) * radius, center + Vector2(-0.1, -0.42) * radius, center + Vector2(0.18, 0.02) * radius, center + Vector2(0.38, -0.22) * radius, center + Vector2(0.62, 0.35) * radius]), ink)
		canvas.draw_polyline(PackedVector2Array([center + Vector2(-0.28, -0.13) * radius, center + Vector2(-0.1, -0.42) * radius, center + Vector2(0.08, -0.13) * radius]), Color("fffdf6"), maxf(1.0, radius * 0.05), true)
	elif kind == "trunk":
		canvas.draw_line(center + Vector2(-0.28, -0.48) * radius, center + Vector2(-0.28, 0.48) * radius, ink, radius * 0.18, true)
		canvas.draw_line(center + Vector2(0.23, -0.48) * radius, center + Vector2(0.23, 0.48) * radius, ink, radius * 0.18, true)
		canvas.draw_line(center + Vector2(-0.08, -0.12) * radius, center + Vector2(0.42, -0.4) * radius, ink, radius * 0.12, true)
	elif kind == "tree":
		canvas.draw_line(center + Vector2(0, 0.15) * radius, center + Vector2(0, 0.48) * radius, ink, radius * 0.12, true)
		for data in [[0.0, -0.28, 0.3], [-0.23, -0.02, 0.27], [0.23, -0.02, 0.27]]:
			canvas.draw_circle(center + Vector2(data[0], data[1]) * radius, data[2] * radius, ink)
	elif kind == "field":
		for x in [-0.28, 0.0, 0.28]:
			canvas.draw_line(center + Vector2(x, 0.42) * radius, center + Vector2(x * 0.65, -0.38) * radius, ink, maxf(1.1, radius * 0.055), true)
			canvas.draw_circle(center + Vector2(x * 0.65, -0.36) * radius, radius * 0.08, ink)
	elif kind == "building":
		canvas.draw_rect(Rect2(center + Vector2(-0.37, -0.08) * radius, Vector2(0.74, 0.52) * radius), ink)
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.48, -0.08) * radius, center + Vector2(0, -0.48) * radius, center + Vector2(0.48, -0.08) * radius]), ink)
		canvas.draw_rect(Rect2(center + Vector2(-0.09, 0.12) * radius, Vector2(0.18, 0.32) * radius), color)

static func board_cell(canvas: CanvasItem, center: Vector2, radius: float, stack: Array, cube_card: int, highlighted: bool, valid: bool) -> void:
	if highlighted:
		hex(canvas, center, radius + 4, Color("e9bd56"))
	var fill = Color("e6eddf") if stack.is_empty() else Color("d9e5d2")
	if not valid and stack.is_empty():
		fill = Color("eceee7")
	hex(canvas, center, radius, fill, Color("b9c9b4"), 1.2)
	for i in range(stack.size()):
		var offset = Vector2(0, (stack.size() - 1) * radius * 0.1 - i * radius * 0.2)
		token(canvas, stack[i], center + offset, radius * 0.82)
	if cube_card > 0:
		canvas.draw_circle(center + Vector2(radius * 0.48, -radius * 0.48), radius * 0.24, PAPER)
		canvas.draw_circle(center + Vector2(radius * 0.48, -radius * 0.48), radius * 0.17, GOLD)
	if valid:
		hex(canvas, center, radius * 0.93, Color(1, 1, 1, 0.04), GREEN, 3.0)

static func habitat_stack(canvas: CanvasItem, spec: String, center: Vector2, radius: float) -> void:
	# Draw real stacked components rather than white-on-white T2/T3/M2/M3 text.
	var pieces: Array = []
	match spec:
		"T2": pieces = ["trunk", "tree"]
		"T3": pieces = ["trunk", "trunk", "tree"]
		"M2": pieces = ["mountain", "mountain"]
		"M3": pieces = ["mountain", "mountain", "mountain"]
		"B2": pieces = ["trunk", "building"]
		_: pieces = [spec]
	var spacing = radius * 0.48
	for i in range(pieces.size()):
		var p = center + Vector2(0, (pieces.size() - 1) * spacing * 0.5 - i * spacing)
		token(canvas, pieces[i], p, radius)
	for i in range(pieces.size()):
		canvas.draw_circle(center + Vector2(radius * 1.08, (i - (pieces.size() - 1) * 0.5) * radius * 0.34), maxf(1.4, radius * 0.10), INK)

static func pattern(canvas: CanvasItem, card: Dictionary, rect: Rect2, show_target: bool = true) -> void:
	if card.is_empty():
		return
	var cells: Array = card.pattern
	var min_q = 99
	var max_q = -99
	var min_r = 99
	var max_r = -99
	for cell in cells:
		min_q = mini(min_q, cell.x)
		max_q = maxi(max_q, cell.x)
		min_r = mini(min_r, cell.y)
		max_r = maxi(max_r, cell.y)
	var span = Vector2(max_q - min_q + 1, max_r - min_r + 1)
	var radius = minf(rect.size.x / (span.x * 2.0 + 1.0), rect.size.y / (span.y * 1.8 + 0.6))
	radius = minf(radius, 23)
	var center = rect.get_center()
	for i in range(cells.size()):
		var cell: Vector2i = cells[i]
		var p = center + Vector2((cell.x - (min_q + max_q) * 0.5) * sqrt(3) * radius + (cell.y - (min_r + max_r) * 0.5) * sqrt(3) * 0.5 * radius, (cell.y - (min_r + max_r) * 0.5) * 1.5 * radius)
		habitat_stack(canvas, card.pattern[i].spec, p, radius * 0.83)
		if show_target and i == int(card.target):
			# A ring alone marks the cube target; no arrow or extra pointer.
			canvas.draw_arc(p, radius * 1.04, 0, TAU, 32, GOLD, maxf(2.2, radius * 0.16), true)

static func animal_icon(canvas: CanvasItem, card_id: int, center: Vector2, radius: float, color: Color = Color("31715b")) -> void:
	if color == Color("31715b"):
		color = GREEN
	var ink = color
	var thin = maxf(1.3, radius * 0.10)
	var p = center
	var r = radius
	match card_id:
		1: # Bee
			canvas.draw_circle(p, r * 0.35, ink)
			canvas.draw_arc(p + Vector2(-0.35, -0.1) * r, r * 0.42, PI, TAU, 16, ink, thin, true)
			canvas.draw_arc(p + Vector2(0.35, -0.1) * r, r * 0.42, PI, TAU, 16, ink, thin, true)
			canvas.draw_line(p + Vector2(-0.28, -0.05) * r, p + Vector2(0.28, -0.05) * r, PAPER, thin, true)
		2, 9, 19: # Butterflies
			for side in [-1, 1]:
				canvas.draw_circle(p + Vector2(side * 0.38, -0.18) * r, r * 0.36, ink)
				canvas.draw_circle(p + Vector2(side * 0.28, 0.32) * r, r * 0.25, ink)
			canvas.draw_line(p + Vector2(0, -0.55) * r, p + Vector2(0, 0.55) * r, ink, thin * 1.5, true)
		3: # Jay
			_bird(canvas, p, r, ink, thin)
		4, 34: # Rabbit / hare
			canvas.draw_circle(p + Vector2(0, 0.2) * r, r * 0.48, ink)
			for side in [-1, 1]:
				canvas.draw_line(p + Vector2(side * 0.24, -0.05) * r, p + Vector2(side * 0.34, -0.82) * r, ink, r * 0.22, true)
			canvas.draw_circle(p + Vector2(0.17, 0.10) * r, r * 0.07, PAPER)
		5: # Badger
			canvas.draw_arc(p, r * 0.65, 0, PI, 20, ink, r * 0.45, true)
			canvas.draw_line(p + Vector2(0, -0.58) * r, p + Vector2(0, 0.52) * r, PAPER, thin * 1.4, true)
		6: # Frog
			canvas.draw_circle(p, r * 0.48, ink)
			for side in [-1, 1]:
				canvas.draw_circle(p + Vector2(side * 0.34, -0.38) * r, r * 0.22, ink)
				canvas.draw_circle(p + Vector2(side * 0.34, -0.40) * r, r * 0.06, PAPER)
		7: # Dragonfly
			canvas.draw_line(p + Vector2(0, -0.65) * r, p + Vector2(0, 0.65) * r, ink, thin, true)
			for side in [-1, 1]:
				canvas.draw_line(p + Vector2(side * 0.08, -0.2) * r, p + Vector2(side * 0.72, -0.48) * r, ink, r * 0.20, true)
				canvas.draw_line(p + Vector2(side * 0.08, 0.1) * r, p + Vector2(side * 0.65, 0.32) * r, ink, r * 0.18, true)
		8, 20, 29: # Fox / squirrel
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.62, -0.55) * r, p + Vector2(-0.18, -0.38) * r, p + Vector2(0.18, -0.38) * r, p + Vector2(0.62, -0.55) * r, p + Vector2(0.42, 0.48) * r, p + Vector2(-0.42, 0.48) * r]), ink)
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.28, 0.08) * r, p + Vector2(0.28, 0.08) * r, p + Vector2(0, 0.45) * r]), PAPER)
		10: # Hedgehog
			canvas.draw_arc(p, r * 0.68, PI, TAU, 18, ink, r * 0.45, true)
			for x in [-0.45, -0.15, 0.15, 0.45]:
				canvas.draw_line(p + Vector2(x, -0.45) * r, p + Vector2(x * 1.2, -0.82) * r, ink, thin, true)
			canvas.draw_circle(p + Vector2(0.48, 0.05) * r, r * 0.10, ink)
		11: # Heron
			canvas.draw_line(p + Vector2(-0.2, 0.55) * r, p + Vector2(0.1, -0.25) * r, ink, r * 0.20, true)
			canvas.draw_circle(p + Vector2(0.12, -0.42) * r, r * 0.25, ink)
			canvas.draw_line(p + Vector2(0.30, -0.42) * r, p + Vector2(0.78, -0.32) * r, ink, thin, true)
		12, 24: # Trout / salmon
			_fish(canvas, p, r, ink)
		13: # Lynx
			_cat(canvas, p, r, ink, true)
		14, 40: # Ladybird / firefly
			canvas.draw_circle(p, r * 0.55, ink)
			canvas.draw_line(p + Vector2(0, -0.5) * r, p + Vector2(0, 0.5) * r, PAPER, thin, true)
			for side in [-1, 1]:
				canvas.draw_circle(p + Vector2(side * 0.25, 0.05) * r, r * 0.08, PAPER)
		15: # Beaver
			canvas.draw_circle(p, r * 0.48, ink)
			canvas.draw_rect(Rect2(p + Vector2(-0.18, 0.22) * r, Vector2(0.36, 0.35) * r), PAPER)
		16: # Woodpecker
			_bird(canvas, p, r, ink, thin)
			canvas.draw_line(p + Vector2(-0.2, -0.5) * r, p + Vector2(0.2, -0.5) * r, GOLD, r * 0.16, true)
		17: # Otter
			canvas.draw_circle(p, r * 0.5, ink)
			canvas.draw_arc(p + Vector2(-0.35, 0.25) * r, r * 0.6, 0, PI * 1.4, 20, ink, r * 0.18, true)
		18: # Osprey
			_bird(canvas, p, r, ink, thin)
			canvas.draw_line(p + Vector2(-0.45, 0.1) * r, p + Vector2(0.45, 0.1) * r, PAPER, thin, true)
		21: # Owl
			canvas.draw_circle(p, r * 0.55, ink)
			for side in [-1, 1]:
				canvas.draw_circle(p + Vector2(side * 0.23, -0.08) * r, r * 0.18, PAPER)
				canvas.draw_circle(p + Vector2(side * 0.23, -0.08) * r, r * 0.06, ink)
		22: # Stag
			canvas.draw_rect(Rect2(p + Vector2(-0.3, -0.1) * r, Vector2(0.6, 0.65) * r), ink)
			for side in [-1, 1]:
				canvas.draw_polyline(PackedVector2Array([p + Vector2(side * 0.18, -0.05) * r, p + Vector2(side * 0.45, -0.65) * r, p + Vector2(side * 0.72, -0.8) * r]), ink, thin, true)
		23: # Wildcat
			_cat(canvas, p, r, ink, false)
		25: # Bat
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.8, -0.35) * r, p + Vector2(-0.3, -0.1) * r, p + Vector2(0, -0.45) * r, p + Vector2(0.3, -0.1) * r, p + Vector2(0.8, -0.35) * r, p + Vector2(0.45, 0.4) * r, p + Vector2(0, 0.18) * r, p + Vector2(-0.45, 0.4) * r]), ink)
		26: # Mole
			canvas.draw_arc(p, r * 0.65, 0, PI, 20, ink, r * 0.5, true)
			canvas.draw_circle(p + Vector2(0, 0.15) * r, r * 0.12, GOLD)
		27: # Turtle
			canvas.draw_circle(p, r * 0.48, ink)
			canvas.draw_circle(p + Vector2(0.62, 0) * r, r * 0.18, ink)
			canvas.draw_polyline(PackedVector2Array([p + Vector2(-0.35, 0) * r, p + Vector2(0.35, 0) * r]), PAPER, thin, true)
		28: # Wolf
			_cat(canvas, p, r, ink, true)
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.22, 0.1) * r, p + Vector2(0.22, 0.1) * r, p + Vector2(0, 0.5) * r]), PAPER)
		30: # Boar
			canvas.draw_circle(p, r * 0.52, ink)
			canvas.draw_circle(p + Vector2(0, 0.2) * r, r * 0.28, MUTED)
			for side in [-1, 1]:
				canvas.draw_arc(p + Vector2(side * 0.3, 0.28) * r, r * 0.22, 0, PI, 12, PAPER, thin, true)
		31: # Vulture
			_bird(canvas, p, r, ink, thin)
			canvas.draw_arc(p, r * 0.72, PI * 1.15, PI * 1.85, 18, ink, thin, true)
		32: # Bear
			canvas.draw_circle(p, r * 0.52, ink)
			for side in [-1, 1]:
				canvas.draw_circle(p + Vector2(side * 0.42, -0.38) * r, r * 0.22, ink)
			canvas.draw_circle(p + Vector2(0, 0.18) * r, r * 0.22, MUTED)
		33, 36, 37, 41: # Sun / spirit
			canvas.draw_circle(p, r * 0.34, ink)
			for i in range(8):
				var direction = Vector2.from_angle(i * TAU / 8)
				canvas.draw_line(p + direction * r * 0.52, p + direction * r * 0.82, ink, thin, true)
		35, 42: # Rain / cloud
			for x in [-0.28, 0.0, 0.28]:
				canvas.draw_circle(p + Vector2(x, -0.1) * r, r * 0.32, ink)
			for x in [-0.35, 0.0, 0.35]:
				canvas.draw_line(p + Vector2(x, 0.35) * r, p + Vector2(x - 0.1, 0.68) * r, ink, thin, true)
		38: # Mountain spirit
			canvas.draw_polyline(PackedVector2Array([p + Vector2(-0.75, 0.5) * r, p + Vector2(-0.1, -0.65) * r, p + Vector2(0.25, 0.05) * r, p + Vector2(0.48, -0.3) * r, p + Vector2(0.8, 0.5) * r]), ink, thin * 1.4, true)
		39: # River spirit
			for y in [-0.35, 0.0, 0.35]:
				canvas.draw_arc(p + Vector2(0, y) * r, r * 0.65, 0.15, PI - 0.15, 20, ink, thin, true)
		_:
			_leaf(canvas, p, r, ink)

static func _bird(canvas: CanvasItem, p: Vector2, r: float, ink: Color, thin: float) -> void:
	canvas.draw_circle(p, r * 0.45, ink)
	canvas.draw_circle(p + Vector2(0.25, -0.36) * r, r * 0.28, ink)
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0.48, -0.4) * r, p + Vector2(0.85, -0.28) * r, p + Vector2(0.48, -0.18) * r]), ink)
	canvas.draw_arc(p, r * 0.28, 0, PI, 14, PAPER, thin, true)

static func _fish(canvas: CanvasItem, p: Vector2, r: float, ink: Color) -> void:
	canvas.draw_circle(p, r * 0.45, ink)
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.35, 0) * r, p + Vector2(-0.8, -0.42) * r, p + Vector2(-0.8, 0.42) * r]), ink)
	canvas.draw_circle(p + Vector2(0.2, -0.1) * r, r * 0.07, PAPER)

static func _cat(canvas: CanvasItem, p: Vector2, r: float, ink: Color, tufts: bool) -> void:
	var top = -0.78 if tufts else -0.58
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.55, top) * r, p + Vector2(-0.16, -0.38) * r, p + Vector2(0.16, -0.38) * r, p + Vector2(0.55, top) * r, p + Vector2(0.45, 0.45) * r, p + Vector2(-0.45, 0.45) * r]), ink)
	for side in [-1, 1]:
		canvas.draw_circle(p + Vector2(side * 0.2, 0) * r, r * 0.06, PAPER)

static func _leaf(canvas: CanvasItem, p: Vector2, r: float, ink: Color) -> void:
	canvas.draw_arc(p, r * 0.62, -PI * 0.7, PI * 0.65, 24, ink, r * 0.18, true)
	canvas.draw_line(p + Vector2(-0.4, 0.5) * r, p + Vector2(0.4, -0.5) * r, ink, maxf(1.2, r * 0.1), true)

static func sun(canvas: CanvasItem, center: Vector2, radius: float, color: Color = Color("e9a92f")) -> void:
	canvas.draw_circle(center, radius * 0.54, color)
	for i in range(12):
		var angle = i * TAU / 12
		var direction = Vector2(cos(angle), sin(angle))
		canvas.draw_line(center + direction * radius * 0.72, center + direction * radius, color, radius * 0.12, true)

static func leaf(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	_leaf(canvas, center, radius, color)

