class_name EcoArt
extends RefCounted

static var INK = Color("203b35")
static var MUTED = Color("667b70")
static var CREAM = Color("f7f3e8")
static var PAPER = Color("fffdf6")
static var GREEN = Color("31715b")
static var LIGHT_GREEN = Color("dce9d7")
static var GOLD = Color("b47b16")

# Okabe–Ito-inspired hues plus a different silhouette for every token.
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
		INK = Color("edf4ec")
		MUTED = Color("b1c2b8")
		CREAM = Color("14201d")
		PAPER = Color("202d29")
		GREEN = Color("78d6ad")
		LIGHT_GREEN = Color("29483c")
		GOLD = Color("f2c45c")
	else:
		INK = Color("203b35")
		MUTED = Color("667b70")
		CREAM = Color("f7f3e8")
		PAPER = Color("fffdf6")
		GREEN = Color("31715b")
		LIGHT_GREEN = Color("dce9d7")
		GOLD = Color("b47b16")

static func font() -> Font:
	return ThemeDB.fallback_font

static func hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for index in range(6):
		var angle = deg_to_rad(index * 60.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func hex(canvas: CanvasItem, center: Vector2, radius: float, color: Color, border: Color = Color.TRANSPARENT, width: float = 2.0) -> void:
	var points = hex_points(center, radius)
	canvas.draw_colored_polygon(points, color)
	if border.a > 0.0:
		points.append(points[0])
		canvas.draw_polyline(points, border, width, true)

static func rounded(canvas: CanvasItem, rect: Rect2, color: Color, radius: int = 14, border: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	canvas.draw_style_box(style, rect)

static func text(canvas: CanvasItem, value: String, position: Vector2, size: int = 20, color: Color = Color("203b35")) -> void:
	canvas.draw_string(font(), position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func text_center(canvas: CanvasItem, value: String, center: Vector2, size: int = 20, color: Color = Color("203b35")) -> void:
	var width = font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(canvas, value, center - Vector2(width * 0.5, 0), size, color)

static func fitted_text(canvas: CanvasItem, value: String, rect: Rect2, size: int = 20, color: Color = Color("203b35"), centered: bool = false) -> void:
	var actual = size
	while actual > 10 and font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > rect.size.x:
		actual -= 1
	var shown = value
	while shown.length() > 3 and font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > rect.size.x:
		shown = shown.left(shown.length() - 2) + "…"
	var x = rect.position.x
	if centered:
		x += (rect.size.x - font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x) * 0.5
	text(canvas, shown, Vector2(x, rect.position.y + actual), actual, color)

static func wrapped_text(canvas: CanvasItem, value: String, rect: Rect2, size: int = 18, color: Color = Color("203b35"), line_height: float = 1.3) -> float:
	var words = value.split(" ")
	var lines: Array = []
	var line = ""
	for word in words:
		var candidate = word if line.is_empty() else line + " " + word
		if font().get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty():
		lines.append(line)
	var y = rect.position.y + size
	for item in lines:
		if y > rect.end.y:
			break
		text(canvas, item, Vector2(rect.position.x, y), size, color)
		y += size * line_height
	return y

static func leaf(canvas: CanvasItem, center: Vector2, scale: float, color: Color = Color("31715b")) -> void:
	var points = PackedVector2Array([
		center + Vector2(0, 34) * scale,
		center + Vector2(-28, 10) * scale,
		center + Vector2(-26, -18) * scale,
		center + Vector2(0, -36) * scale,
		center + Vector2(26, -18) * scale,
		center + Vector2(28, 10) * scale
	])
	canvas.draw_colored_polygon(points, color)
	var vein = Color("f7f3e8")
	canvas.draw_line(center + Vector2(0, 28) * scale, center + Vector2(0, -24) * scale, vein, 3.0 * scale, true)
	canvas.draw_line(center + Vector2(0, 2) * scale, center + Vector2(-15, -10) * scale, vein, 2.0 * scale, true)
	canvas.draw_line(center + Vector2(0, -8) * scale, center + Vector2(14, -20) * scale, vein, 2.0 * scale, true)

static func token(canvas: CanvasItem, token_name: String, center: Vector2, radius: float, selected: bool = false) -> void:
	var color: Color = TOKEN_COLORS[token_name]
	hex(canvas, center + Vector2(0, radius * 0.12), radius, Color(0.03, 0.07, 0.06, 0.3))
	hex(canvas, center, radius, color, Color("fff4cf") if selected else color.darkened(0.38), 3.0 if selected else 1.8)
	var ink = Color("fffdf4")
	if token_name in ["field", "water"]:
		ink = Color("183f4b")
	if token_name == "water":
		for row in range(3):
			var y = center.y + (row - 1) * radius * 0.28
			var points = PackedVector2Array()
			for i in range(17):
				var x = center.x - radius * 0.52 + i * radius * 0.065
				points.append(Vector2(x, y + sin(i * PI / 2.0) * radius * 0.07))
			canvas.draw_polyline(points, ink, maxf(1.5, radius * 0.065), true)
	elif token_name == "mountain":
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.58, 0.38) * radius, center + Vector2(-0.1, -0.46) * radius, center + Vector2(0.22, 0.38) * radius]), ink)
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.05, 0.38) * radius, center + Vector2(0.36, -0.28) * radius, center + Vector2(0.64, 0.38) * radius]), ink.darkened(0.16))
		canvas.draw_polyline(PackedVector2Array([center + Vector2(-0.28, -0.12) * radius, center + Vector2(-0.1, -0.46) * radius, center + Vector2(0.05, -0.16) * radius]), color.darkened(0.28), maxf(1.0, radius * 0.06), true)
	elif token_name == "trunk":
		canvas.draw_line(center + Vector2(-0.2, 0.42) * radius, center + Vector2(-0.1, -0.42) * radius, ink, radius * 0.18, true)
		canvas.draw_line(center + Vector2(0.18, 0.42) * radius, center + Vector2(0.08, -0.34) * radius, ink.darkened(0.15), radius * 0.16, true)
		canvas.draw_line(center + Vector2(-0.14, 0.02) * radius, center + Vector2(-0.38, -0.18) * radius, ink, radius * 0.09, true)
	elif token_name == "tree":
		canvas.draw_circle(center + Vector2(-0.2, -0.05) * radius, radius * 0.34, ink)
		canvas.draw_circle(center + Vector2(0.2, -0.12) * radius, radius * 0.36, ink.darkened(0.12))
		canvas.draw_circle(center + Vector2(0, -0.36) * radius, radius * 0.32, ink.lightened(0.08))
		canvas.draw_line(center + Vector2(0, 0.05) * radius, center + Vector2(0, 0.45) * radius, ink, radius * 0.09, true)
	elif token_name == "field":
		for offset in [-0.28, 0.0, 0.28]:
			canvas.draw_line(center + Vector2(offset, 0.4) * radius, center + Vector2(offset * 0.7, -0.38) * radius, ink, radius * 0.055, true)
			for j in range(3):
				var p = center + Vector2(offset * 0.7, (-0.28 + j * 0.16)) * radius
				canvas.draw_circle(p + Vector2(-0.08, 0) * radius, radius * 0.07, ink)
				canvas.draw_circle(p + Vector2(0.08, 0.04) * radius, radius * 0.07, ink)
	elif token_name == "building":
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.45, -0.02) * radius, center + Vector2(0, -0.46) * radius, center + Vector2(0.45, -0.02) * radius]), ink)
		canvas.draw_rect(Rect2(center + Vector2(-0.32, -0.02) * radius, Vector2(0.64, 0.46) * radius), ink)
		canvas.draw_rect(Rect2(center + Vector2(-0.08, 0.16) * radius, Vector2(0.16, 0.28) * radius), color.darkened(0.38))

static func habitat_stack(canvas: CanvasItem, spec: String, center: Vector2, radius: float) -> void:
	var stack: Array = []
	match spec:
		"W": stack = ["water"]
		"Y": stack = ["field"]
		"T1": stack = ["tree"]
		"T2": stack = ["trunk", "tree"]
		"T3": stack = ["trunk", "trunk", "tree"]
		"M1": stack = ["mountain"]
		"M2": stack = ["mountain", "mountain"]
		"M3": stack = ["mountain", "mountain", "mountain"]
		"B1": stack = ["building"]
		"B2": stack = ["trunk", "building"]
	var spacing = radius * 0.3
	for i in range(stack.size()):
		var p = center + Vector2(0, (stack.size() - 1) * spacing * 0.5 - i * spacing)
		token(canvas, stack[i], p, radius * 0.86)
	if stack.size() > 1:
		for i in range(stack.size()):
			var p = center + Vector2((i - (stack.size() - 1) * 0.5) * radius * 0.28, radius * 0.82)
			canvas.draw_circle(p, radius * 0.1, Color("fff8e7"))
			canvas.draw_arc(p, radius * 0.1, 0, TAU, 12, Color("263b35"), maxf(1.0, radius * 0.055), true)

static func cube(canvas: CanvasItem, center: Vector2, spirit: bool, scale: float = 1.0) -> void:
	var color = Color("d9f1df") if spirit else Color("f6d986")
	var rect = Rect2(center - Vector2(12, 12) * scale, Vector2(24, 24) * scale)
	rounded(canvas, rect, Color(0.1, 0.2, 0.15, 0.25), int(6 * scale))
	rounded(canvas, Rect2(rect.position - Vector2(0, 4) * scale, rect.size), color, int(6 * scale), Color("203b35"), 1)
	if spirit:
		leaf(canvas, rect.get_center() - Vector2(0, 4) * scale, 0.18 * scale, Color("31715b"))
	else:
		canvas.draw_circle(rect.get_center() - Vector2(0, 4) * scale, 4.0 * scale, Color("203b35"))

static func pattern(canvas: CanvasItem, card: Dictionary, center: Vector2, radius: float) -> void:
	var offsets = EcoRules.shape_offsets(card.shape)
	var projected: Array = []
	var middle = Vector2.ZERO
	for cell in offsets:
		var p = Vector2(1.5 * cell.x, sqrt(3.0) * (cell.y + cell.x * 0.5)) * radius
		projected.append(p)
		middle += p
	middle /= maxf(1.0, projected.size())
	for i in range(projected.size()):
		var p: Vector2 = center + projected[i] - middle
		habitat_stack(canvas, card.pattern[i], p, radius)
		if i == int(card.target):
			# A ring alone marks the cube target; no arrow or extra pointer.
			canvas.draw_arc(p, radius * 1.04, 0, TAU, 32, GOLD, maxf(2.2, radius * 0.16), true)

static func icon_shape(canvas: CanvasItem, center: Vector2, radius: float, points: Array, color: Color) -> void:
	var shaped = PackedVector2Array()
	for point in points:
		shaped.append(center + point * radius)
	canvas.draw_colored_polygon(shaped, color)

static func icon_line(canvas: CanvasItem, center: Vector2, radius: float, points: Array, color: Color, width: float = 0.1) -> void:
	var shaped = PackedVector2Array()
	for point in points:
		shaped.append(center + point * radius)
	canvas.draw_polyline(shaped, color, maxf(1.4, radius * width), true)

static func animal_icon(canvas: CanvasItem, card_id: int, center: Vector2, radius: float, color: Color = Color("31715b")) -> void:
	var c = center
	var r = radius
	var w = maxf(1.4, r * 0.1)
	match card_id:
		1: # Crocodile
			EcoArt.rounded(canvas, Rect2(c + Vector2(-0.65, -0.18) * r, Vector2(1.1, 0.48) * r), color, int(r * 0.15))
			icon_shape(canvas, c, r, [Vector2(-0.65, 0.0), Vector2(-1.0, -0.3), Vector2(-0.72, 0.27)], color)
			canvas.draw_circle(c + Vector2(0.25, -0.23) * r, r * 0.12, color)
		2: # River Otter
			canvas.draw_circle(c + Vector2(0.05, -0.15) * r, r * 0.48, color)
			canvas.draw_circle(c + Vector2(-0.33, -0.5) * r, r * 0.16, color)
			canvas.draw_circle(c + Vector2(0.4, -0.48) * r, r * 0.16, color)
			canvas.draw_arc(c + Vector2(-0.35, 0.35) * r, r * 0.55, 0.1, 2.5, 20, color, w, true)
		3: # Manatee
			canvas.draw_circle(c + Vector2(0.0, -0.05) * r, r * 0.58, color)
			icon_shape(canvas, c, r, [Vector2(-0.45, 0.25), Vector2(-0.9, 0.65), Vector2(-0.35, 0.58)], color)
			icon_shape(canvas, c, r, [Vector2(0.4, 0.2), Vector2(0.8, 0.65), Vector2(0.2, 0.52)], color)
		4: # Platypus
			canvas.draw_circle(c + Vector2(-0.05, 0.05) * r, r * 0.5, color)
			icon_shape(canvas, c, r, [Vector2(0.35, -0.1), Vector2(0.95, 0.02), Vector2(0.38, 0.25)], color)
			icon_shape(canvas, c, r, [Vector2(-0.4, 0.2), Vector2(-0.9, 0.55), Vector2(-0.35, 0.55)], color)
		5: # Tree Frog
			canvas.draw_circle(c, r * 0.48, color)
			canvas.draw_circle(c + Vector2(-0.35, -0.42) * r, r * 0.22, color)
			canvas.draw_circle(c + Vector2(0.35, -0.42) * r, r * 0.22, color)
			icon_line(canvas, c, r, [Vector2(-0.35, 0.25), Vector2(-0.75, 0.65), Vector2(-0.95, 0.55)], color)
			icon_line(canvas, c, r, [Vector2(0.35, 0.25), Vector2(0.75, 0.65), Vector2(0.95, 0.55)], color)
		6: # Duck
			canvas.draw_circle(c + Vector2(-0.15, 0.22) * r, r * 0.5, color)
			canvas.draw_circle(c + Vector2(0.22, -0.36) * r, r * 0.3, color)
			icon_shape(canvas, c, r, [Vector2(0.45, -0.4), Vector2(0.95, -0.25), Vector2(0.45, -0.12)], color)
		7: # Flamingo
			canvas.draw_circle(c + Vector2(-0.15, 0.15) * r, r * 0.4, color)
			canvas.draw_arc(c + Vector2(0.28, -0.25) * r, r * 0.42, 1.4, 4.8, 20, color, w, true)
			canvas.draw_circle(c + Vector2(0.5, -0.6) * r, r * 0.16, color)
			icon_line(canvas, c, r, [Vector2(-0.05, 0.48), Vector2(-0.05, 0.95), Vector2(0.25, 0.95)], color, 0.07)
		8: # Chameleon
			canvas.draw_circle(c + Vector2(0.1, -0.05) * r, r * 0.48, color)
			canvas.draw_arc(c + Vector2(-0.45, 0.35) * r, r * 0.4, -0.2, 5.4, 24, color, w, true)
			canvas.draw_circle(c + Vector2(0.35, -0.4) * r, r * 0.14, CREAM)
		9: # Shrew
			icon_shape(canvas, c, r, [Vector2(-0.65, 0.35), Vector2(-0.4, -0.35), Vector2(0.25, -0.42), Vector2(0.95, 0.05), Vector2(0.2, 0.35)], color)
			canvas.draw_circle(c + Vector2(-0.25, -0.42) * r, r * 0.18, color)
			icon_line(canvas, c, r, [Vector2(-0.55, 0.25), Vector2(-0.95, 0.45), Vector2(-0.8, 0.7)], color, 0.07)
		10: # Peacock
			for angle in [-1.1, -0.55, 0.0, 0.55, 1.1]:
				var p = c + Vector2(sin(angle), -cos(angle)) * r * 0.45
				canvas.draw_circle(p, r * 0.3, color)
			canvas.draw_circle(c + Vector2(0, 0.35) * r, r * 0.28, color)
			icon_line(canvas, c, r, [Vector2(0, 0.15), Vector2(0.1, -0.25)], color)
		11: # Squirrel
			canvas.draw_circle(c + Vector2(0.15, 0.2) * r, r * 0.38, color)
			canvas.draw_circle(c + Vector2(0.35, -0.28) * r, r * 0.25, color)
			canvas.draw_arc(c + Vector2(-0.35, -0.05) * r, r * 0.55, -1.2, 4.5, 26, color, r * 0.22, true)
		12: # Hedgehog
			icon_shape(canvas, c, r, [Vector2(-0.85, 0.4), Vector2(-0.75, -0.15), Vector2(-0.55, -0.35), Vector2(-0.5, -0.65), Vector2(-0.25, -0.45), Vector2(0, -0.72), Vector2(0.15, -0.4), Vector2(0.45, -0.5), Vector2(0.42, -0.15), Vector2(0.85, 0.05), Vector2(0.45, 0.4)], color)
		13: # Bee
			canvas.draw_circle(c, r * 0.42, color)
			canvas.draw_circle(c + Vector2(-0.38, -0.35) * r, r * 0.3, color)
			canvas.draw_circle(c + Vector2(0.38, -0.35) * r, r * 0.3, color)
			icon_line(canvas, c, r, [Vector2(-0.18, -0.35), Vector2(-0.18, 0.35)], CREAM, 0.08)
			icon_line(canvas, c, r, [Vector2(0.18, -0.35), Vector2(0.18, 0.35)], CREAM, 0.08)
		14: # Bear
			canvas.draw_circle(c + Vector2(-0.43, -0.42) * r, r * 0.24, color)
			canvas.draw_circle(c + Vector2(0.43, -0.42) * r, r * 0.24, color)
			canvas.draw_circle(c, r * 0.62, color)
			canvas.draw_circle(c + Vector2(0, 0.2) * r, r * 0.26, CREAM)
		15: # Rabbit
			icon_shape(canvas, c, r, [Vector2(-0.42, -0.25), Vector2(-0.48, -1.0), Vector2(-0.12, -0.9), Vector2(-0.05, -0.25)], color)
			icon_shape(canvas, c, r, [Vector2(0.05, -0.25), Vector2(0.18, -1.0), Vector2(0.5, -0.88), Vector2(0.4, -0.2)], color)
			canvas.draw_circle(c + Vector2(0, 0.18) * r, r * 0.52, color)
		16: # Parrot
			icon_shape(canvas, c, r, [Vector2(-0.45, 0.75), Vector2(-0.35, -0.35), Vector2(0.15, -0.65), Vector2(0.55, -0.2), Vector2(0.25, 0.55)], color)
			canvas.draw_circle(c + Vector2(0.28, -0.45) * r, r * 0.32, color)
			icon_shape(canvas, c, r, [Vector2(0.48, -0.55), Vector2(0.9, -0.4), Vector2(0.52, -0.12)], GOLD)
		17: # Wild Boar
			canvas.draw_circle(c, r * 0.58, color)
			EcoArt.rounded(canvas, Rect2(c + Vector2(-0.4, 0.05) * r, Vector2(0.8, 0.42) * r), color, int(r * 0.15))
			icon_shape(canvas, c, r, [Vector2(-0.38, 0.25), Vector2(-0.65, 0.55), Vector2(-0.25, 0.38)], CREAM)
			icon_shape(canvas, c, r, [Vector2(0.38, 0.25), Vector2(0.65, 0.55), Vector2(0.25, 0.38)], CREAM)
		18: # Koala
			canvas.draw_circle(c + Vector2(-0.5, -0.2) * r, r * 0.34, color)
			canvas.draw_circle(c + Vector2(0.5, -0.2) * r, r * 0.34, color)
			canvas.draw_circle(c, r * 0.58, color)
			EcoArt.rounded(canvas, Rect2(c + Vector2(-0.14, -0.05) * r, Vector2(0.28, 0.45) * r), INK, int(r * 0.1))
		19: # Wolf
			icon_shape(canvas, c, r, [Vector2(-0.65, -0.75), Vector2(-0.15, -0.48), Vector2(0.15, -0.48), Vector2(0.65, -0.75), Vector2(0.52, 0.15), Vector2(0, 0.75), Vector2(-0.52, 0.15)], color)
			icon_shape(canvas, c, r, [Vector2(-0.2, 0.35), Vector2(0, 0.58), Vector2(0.2, 0.35)], CREAM)
		20: # Kingfisher
			canvas.draw_circle(c + Vector2(-0.1, 0.05) * r, r * 0.48, color)
			canvas.draw_circle(c + Vector2(0.18, -0.4) * r, r * 0.3, color)
			icon_shape(canvas, c, r, [Vector2(0.4, -0.45), Vector2(1.0, -0.3), Vector2(0.4, -0.18)], GOLD)
			icon_shape(canvas, c, r, [Vector2(-0.15, -0.6), Vector2(-0.45, -0.95), Vector2(0.05, -0.72)], color)
		21: # Penguin
			canvas.draw_circle(c, r * 0.65, color)
			canvas.draw_circle(c + Vector2(0, 0.2) * r, r * 0.4, CREAM)
			icon_shape(canvas, c, r, [Vector2(-0.12, -0.25), Vector2(0.35, -0.08), Vector2(-0.12, 0.05)], GOLD)
			icon_shape(canvas, c, r, [Vector2(-0.5, 0.55), Vector2(-0.9, 0.85), Vector2(-0.25, 0.75)], GOLD)
		22: # Bat
			icon_shape(canvas, c, r, [Vector2(0, -0.35), Vector2(-0.25, -0.65), Vector2(-0.35, -0.25), Vector2(-0.95, -0.55), Vector2(-0.7, 0.05), Vector2(-0.95, 0.45), Vector2(-0.4, 0.35), Vector2(0, 0.75), Vector2(0.4, 0.35), Vector2(0.95, 0.45), Vector2(0.7, 0.05), Vector2(0.95, -0.55), Vector2(0.35, -0.25), Vector2(0.25, -0.65)], color)
		23: # Fennec Fox
			icon_shape(canvas, c, r, [Vector2(-0.75, -1.0), Vector2(-0.12, -0.45), Vector2(0.12, -0.45), Vector2(0.75, -1.0), Vector2(0.5, 0.1), Vector2(0, 0.7), Vector2(-0.5, 0.1)], color)
		24: # Chicken
			canvas.draw_circle(c + Vector2(-0.1, 0.2) * r, r * 0.48, color)
			canvas.draw_circle(c + Vector2(0.2, -0.35) * r, r * 0.3, color)
			for x in [-0.02, 0.2, 0.4]:
				canvas.draw_circle(c + Vector2(x, -0.68) * r, r * 0.13, color)
			icon_shape(canvas, c, r, [Vector2(0.45, -0.38), Vector2(0.85, -0.22), Vector2(0.45, -0.08)], GOLD)
		25: # Condor
			icon_shape(canvas, c, r, [Vector2(-1.0, -0.35), Vector2(-0.25, -0.15), Vector2(0, -0.55), Vector2(0.25, -0.15), Vector2(1.0, -0.35), Vector2(0.75, 0.25), Vector2(0.2, 0.15), Vector2(0, 0.75), Vector2(-0.2, 0.15), Vector2(-0.75, 0.25)], color)
		26: # Meerkat
			EcoArt.rounded(canvas, Rect2(c + Vector2(-0.28, -0.2) * r, Vector2(0.56, 0.95) * r), color, int(r * 0.25))
			canvas.draw_circle(c + Vector2(0, -0.42) * r, r * 0.34, color)
			canvas.draw_arc(c + Vector2(0.45, 0.45) * r, r * 0.42, -1.2, 1.5, 18, color, w, true)
		27: # Raven
			canvas.draw_circle(c + Vector2(-0.1, 0.1) * r, r * 0.5, color)
			canvas.draw_circle(c + Vector2(0.2, -0.4) * r, r * 0.3, color)
			icon_shape(canvas, c, r, [Vector2(0.4, -0.45), Vector2(0.95, -0.25), Vector2(0.35, -0.15)], color)
			icon_shape(canvas, c, r, [Vector2(-0.4, 0.0), Vector2(-0.85, 0.75), Vector2(0.05, 0.4)], INK)
		28: # Llama
			EcoArt.rounded(canvas, Rect2(c + Vector2(-0.6, 0.05) * r, Vector2(0.85, 0.5) * r), color, int(r * 0.15))
			EcoArt.rounded(canvas, Rect2(c + Vector2(0.05, -0.65) * r, Vector2(0.28, 0.85) * r), color, int(r * 0.1))
			canvas.draw_circle(c + Vector2(0.28, -0.65) * r, r * 0.25, color)
			icon_shape(canvas, c, r, [Vector2(0.1, -0.8), Vector2(0.05, -1.05), Vector2(0.28, -0.85)], color)
		29: # Mountain Goat
			canvas.draw_circle(c + Vector2(0, 0.12) * r, r * 0.5, color)
			canvas.draw_arc(c + Vector2(-0.32, -0.3) * r, r * 0.38, 1.5, 4.8, 20, color, w, true)
			canvas.draw_arc(c + Vector2(0.32, -0.3) * r, r * 0.38, -1.65, 1.65, 20, color, w, true)
			icon_shape(canvas, c, r, [Vector2(-0.12, 0.5), Vector2(0, 0.95), Vector2(0.12, 0.5)], color)
		30: # Cow
			canvas.draw_circle(c + Vector2(0, 0.05) * r, r * 0.56, color)
			icon_line(canvas, c, r, [Vector2(-0.4, -0.35), Vector2(-0.85, -0.65), Vector2(-0.75, -0.2)], color)
			icon_line(canvas, c, r, [Vector2(0.4, -0.35), Vector2(0.85, -0.65), Vector2(0.75, -0.2)], color)
			EcoArt.rounded(canvas, Rect2(c + Vector2(-0.35, 0.15) * r, Vector2(0.7, 0.4) * r), CREAM, int(r * 0.16))
		31: # Ladybug
			canvas.draw_circle(c, r * 0.62, color)
			canvas.draw_circle(c + Vector2(0, -0.48) * r, r * 0.28, INK)
			icon_line(canvas, c, r, [Vector2(0, -0.45), Vector2(0, 0.58)], CREAM, 0.07)
			for p in [Vector2(-0.28, -0.1), Vector2(0.28, -0.1), Vector2(-0.25, 0.28), Vector2(0.25, 0.28)]:
				canvas.draw_circle(c + p * r, r * 0.09, CREAM)
		32: # Black Panther
			EcoArt.rounded(canvas, Rect2(c + Vector2(-0.55, -0.05) * r, Vector2(1.0, 0.5) * r), color, int(r * 0.2))
			canvas.draw_circle(c + Vector2(0.4, -0.25) * r, r * 0.3, color)
			icon_shape(canvas, c, r, [Vector2(0.18, -0.42), Vector2(0.25, -0.75), Vector2(0.45, -0.48)], color)
			canvas.draw_arc(c + Vector2(-0.55, 0.1) * r, r * 0.5, 1.4, 4.8, 22, color, w, true)
		33: # Lion
			canvas.draw_circle(c, r * 0.72, GOLD)
			canvas.draw_circle(c, r * 0.48, color)
			canvas.draw_circle(c + Vector2(0, 0.15) * r, r * 0.2, CREAM)
		34: # Butterfly
			for p in [Vector2(-0.4, -0.3), Vector2(0.4, -0.3), Vector2(-0.32, 0.35), Vector2(0.32, 0.35)]:
				canvas.draw_circle(c + p * r, r * 0.34, color)
			icon_line(canvas, c, r, [Vector2(0, -0.55), Vector2(0, 0.7)], INK, 0.12)
		35: # Deer
			canvas.draw_circle(c + Vector2(0, 0.2) * r, r * 0.45, color)
			for sign_value in [-1, 1]:
				icon_line(canvas, c, r, [Vector2(0.25 * sign_value, -0.1), Vector2(0.5 * sign_value, -0.75), Vector2(0.8 * sign_value, -0.95)], color, 0.08)
				icon_line(canvas, c, r, [Vector2(0.5 * sign_value, -0.65), Vector2(0.2 * sign_value, -0.9)], color, 0.08)
		36: # Owl
			icon_shape(canvas, c, r, [Vector2(-0.65, -0.6), Vector2(0, -0.4), Vector2(0.65, -0.6), Vector2(0.5, 0.65), Vector2(0, 0.85), Vector2(-0.5, 0.65)], color)
			canvas.draw_circle(c + Vector2(-0.25, -0.05) * r, r * 0.22, CREAM)
			canvas.draw_circle(c + Vector2(0.25, -0.05) * r, r * 0.22, CREAM)
		37: # Black Cat
			icon_shape(canvas, c, r, [Vector2(-0.6, -0.75), Vector2(-0.15, -0.45), Vector2(0.15, -0.45), Vector2(0.6, -0.75), Vector2(0.52, 0.4), Vector2(0, 0.7), Vector2(-0.52, 0.4)], color)
			for sign_value in [-1, 1]:
				icon_line(canvas, c, r, [Vector2(0.25 * sign_value, 0.2), Vector2(0.9 * sign_value, 0.05)], color, 0.05)
		38: # Stork
			canvas.draw_circle(c + Vector2(-0.15, 0.05) * r, r * 0.4, color)
			icon_line(canvas, c, r, [Vector2(0.05, -0.2), Vector2(0.25, -0.7), Vector2(0.45, -0.7)], color, 0.13)
			icon_shape(canvas, c, r, [Vector2(0.4, -0.75), Vector2(0.95, -0.62), Vector2(0.4, -0.52)], GOLD)
			icon_line(canvas, c, r, [Vector2(-0.1, 0.4), Vector2(-0.1, 0.95)], color, 0.06)
		39: # Ram
			canvas.draw_circle(c, r * 0.46, color)
			canvas.draw_arc(c + Vector2(-0.42, -0.05) * r, r * 0.36, 0, TAU * 0.9, 24, GOLD, r * 0.13, true)
			canvas.draw_arc(c + Vector2(0.42, -0.05) * r, r * 0.36, PI, PI + TAU * 0.9, 24, GOLD, r * 0.13, true)
		40: # Marmot
			canvas.draw_circle(c + Vector2(0, 0.15) * r, r * 0.58, color)
			canvas.draw_circle(c + Vector2(-0.35, -0.38) * r, r * 0.18, color)
			canvas.draw_circle(c + Vector2(0.35, -0.38) * r, r * 0.18, color)
			icon_shape(canvas, c, r, [Vector2(-0.15, 0.4), Vector2(0, 0.7), Vector2(0.15, 0.4)], CREAM)
		41: # Dragonfly
			for p in [Vector2(-0.42, -0.25), Vector2(0.42, -0.25), Vector2(-0.42, 0.25), Vector2(0.42, 0.25)]:
				canvas.draw_circle(c + p * r, r * 0.3, color)
			icon_line(canvas, c, r, [Vector2(0, -0.7), Vector2(0, 0.85)], INK, 0.1)
		42: # Turtle
			canvas.draw_circle(c, r * 0.52, color)
			canvas.draw_circle(c + Vector2(0.62, -0.05) * r, r * 0.2, color)
			for p in [Vector2(-0.35, -0.45), Vector2(-0.35, 0.45), Vector2(0.3, -0.45), Vector2(0.3, 0.45)]:
				canvas.draw_circle(c + p * r, r * 0.15, color)
			icon_line(canvas, c, r, [Vector2(-0.35, 0), Vector2(0.35, 0)], CREAM, 0.06)
			icon_line(canvas, c, r, [Vector2(0, -0.35), Vector2(0, 0.35)], CREAM, 0.06)

static func card(canvas: CanvasItem, data: Dictionary, rect: Rect2, highlighted: bool = false, detailed: bool = false) -> void:
	var is_spirit: bool = data.kind == "spirit"
	var header = Color("78684d") if is_spirit else Color("2f6d5a")
	rounded(canvas, Rect2(rect.position + Vector2(0, 4), rect.size), Color(0.02, 0.06, 0.04, 0.22), 12)
	rounded(canvas, rect, PAPER, 12, GOLD if highlighted else MUTED, 3 if highlighted else 1)
	rounded(canvas, Rect2(rect.position, Vector2(rect.size.x, 34 if not detailed else 48)), header, 11)
	fitted_text(canvas, data.name.to_upper(), Rect2(rect.position + Vector2(9, 7), Vector2(rect.size.x - 18, 24)), 22 if detailed else 14, Color.WHITE, true)
	var badge_center = rect.position + Vector2(rect.size.x * 0.5, 61 if not detailed else 92)
	canvas.draw_circle(badge_center, 22 if not detailed else 38, LIGHT_GREEN)
	animal_icon(canvas, int(data.id), badge_center, 18 if not detailed else 31, header)
	if detailed:
		pattern(canvas, data, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.48), minf(25, rect.size.x * 0.085))
		var score_text = "Nature’s Spirit" if is_spirit else "  ·  ".join(data.scores.map(func(value): return str(value)))
		text_center(canvas, score_text, rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 42), 18, GOLD if not is_spirit else header)
	else:
		pattern(canvas, data, rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 45), minf(13, rect.size.x * 0.095))
		if not is_spirit:
			var score_text = "/".join(data.scores.map(func(value): return str(value)))
			fitted_text(canvas, score_text, Rect2(rect.position + Vector2(5, rect.size.y - 18), Vector2(rect.size.x - 10, 14)), 11, MUTED, true)
