class_name EcoArt
extends RefCounted

const INK = Color("203b35")
const MUTED = Color("667b70")
const CREAM = Color("f7f3e8")
const PAPER = Color("fffdf6")
const GREEN = Color("31715b")
const LIGHT_GREEN = Color("dce9d7")
const GOLD = Color("d5a23f")
const TOKEN_COLORS = {
	"water": Color("64b7c9"),
	"mountain": Color("8e9698"),
	"trunk": Color("a66e44"),
	"tree": Color("5c9b62"),
	"field": Color("e4bf55"),
	"building": Color("ce7160")
}

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

static func text(canvas: CanvasItem, value: String, position: Vector2, size: int = 20, color: Color = INK) -> void:
	canvas.draw_string(font(), position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func text_center(canvas: CanvasItem, value: String, center: Vector2, size: int = 20, color: Color = INK) -> void:
	var width = font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(canvas, value, center - Vector2(width * 0.5, 0), size, color)

static func fitted_text(canvas: CanvasItem, value: String, rect: Rect2, size: int = 20, color: Color = INK, centered: bool = false) -> void:
	var actual = size
	while actual > 11 and font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > rect.size.x:
		actual -= 1
	var shown = value
	while shown.length() > 3 and font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > rect.size.x:
		shown = shown.left(shown.length() - 2) + "…"
	var x = rect.position.x
	if centered:
		x += (rect.size.x - font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x) * 0.5
	text(canvas, shown, Vector2(x, rect.position.y + actual), actual, color)

static func wrapped_text(canvas: CanvasItem, value: String, rect: Rect2, size: int = 18, color: Color = INK, line_height: float = 1.3) -> float:
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

static func leaf(canvas: CanvasItem, center: Vector2, scale: float, color: Color = GREEN) -> void:
	var points = PackedVector2Array([
		center + Vector2(0, 34) * scale,
		center + Vector2(-28, 10) * scale,
		center + Vector2(-26, -18) * scale,
		center + Vector2(0, -36) * scale,
		center + Vector2(26, -18) * scale,
		center + Vector2(28, 10) * scale
	])
	canvas.draw_colored_polygon(points, color)
	canvas.draw_line(center + Vector2(0, 28) * scale, center + Vector2(0, -24) * scale, CREAM, 3.0 * scale, true)
	canvas.draw_line(center + Vector2(0, 2) * scale, center + Vector2(-15, -10) * scale, CREAM, 2.0 * scale, true)
	canvas.draw_line(center + Vector2(0, -8) * scale, center + Vector2(14, -20) * scale, CREAM, 2.0 * scale, true)

static func token(canvas: CanvasItem, token_name: String, center: Vector2, radius: float, selected: bool = false) -> void:
	var color: Color = TOKEN_COLORS[token_name]
	hex(canvas, center + Vector2(0, radius * 0.12), radius, Color(0.08, 0.15, 0.13, 0.22))
	hex(canvas, center, radius, color, Color("fff8e9") if selected else color.darkened(0.18), 3.0 if selected else 1.5)
	var ink = Color("fff8e9")
	if token_name == "field":
		ink = Color("715627")
	if token_name == "water":
		for row in range(3):
			var y = center.y + (row - 1) * radius * 0.28
			var points = PackedVector2Array()
			for i in range(17):
				var x = center.x - radius * 0.52 + i * radius * 0.065
				points.append(Vector2(x, y + sin(i * PI / 2.0) * radius * 0.07))
			canvas.draw_polyline(points, ink, maxf(1.5, radius * 0.055), true)
	elif token_name == "mountain":
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.58, 0.38) * radius, center + Vector2(-0.1, -0.46) * radius, center + Vector2(0.22, 0.38) * radius]), ink)
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.05, 0.38) * radius, center + Vector2(0.36, -0.28) * radius, center + Vector2(0.64, 0.38) * radius]), ink.darkened(0.12))
	elif token_name == "trunk":
		canvas.draw_line(center + Vector2(-0.2, 0.42) * radius, center + Vector2(-0.1, -0.42) * radius, ink, radius * 0.18, true)
		canvas.draw_line(center + Vector2(0.18, 0.42) * radius, center + Vector2(0.08, -0.34) * radius, ink.darkened(0.15), radius * 0.16, true)
	elif token_name == "tree":
		canvas.draw_circle(center + Vector2(-0.2, -0.05) * radius, radius * 0.34, ink)
		canvas.draw_circle(center + Vector2(0.2, -0.12) * radius, radius * 0.36, ink.darkened(0.08))
		canvas.draw_circle(center + Vector2(0, -0.36) * radius, radius * 0.32, ink.lightened(0.08))
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
		canvas.draw_rect(Rect2(center + Vector2(-0.08, 0.16) * radius, Vector2(0.16, 0.28) * radius), color.darkened(0.3))

static func cube(canvas: CanvasItem, center: Vector2, spirit: bool, scale: float = 1.0) -> void:
	var color = Color("d9f1df") if spirit else Color("f6d986")
	var rect = Rect2(center - Vector2(12, 12) * scale, Vector2(24, 24) * scale)
	rounded(canvas, rect, Color(0.1, 0.2, 0.15, 0.25), int(6 * scale))
	rounded(canvas, Rect2(rect.position - Vector2(0, 4) * scale, rect.size), color, int(6 * scale), INK, 1)
	if spirit:
		leaf(canvas, rect.get_center() - Vector2(0, 4) * scale, 0.18 * scale, GREEN)
	else:
		canvas.draw_circle(rect.get_center() - Vector2(0, 4) * scale, 4.0 * scale, INK)

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
		var spec: String = card.pattern[i]
		var token_name = "water"
		if spec.begins_with("T"):
			token_name = "tree" if spec == "T1" else "trunk"
		elif spec.begins_with("M"):
			token_name = "mountain"
		elif spec.begins_with("B"):
			token_name = "building"
		elif spec == "Y":
			token_name = "field"
		var p: Vector2 = center + projected[i] - middle
		token(canvas, token_name, p, radius * 0.9)
		if spec in ["T2", "T3", "M2", "M3", "B2"]:
			text_center(canvas, spec, p + Vector2(0, 4), maxi(9, int(radius * 0.55)), Color.WHITE)
		if i == int(card.target):
			canvas.draw_circle(p + Vector2(radius * 0.52, -radius * 0.52), radius * 0.25, GOLD)
			canvas.draw_arc(p, radius * 1.03, 0, TAU, 24, GOLD, 2.0, true)

static func card(canvas: CanvasItem, data: Dictionary, rect: Rect2, highlighted: bool = false, detailed: bool = false) -> void:
	var is_spirit: bool = data.kind == "spirit"
	var header = Color("56715f") if is_spirit else Color("2f6d5a")
	rounded(canvas, Rect2(rect.position + Vector2(0, 4), rect.size), Color(0.08, 0.16, 0.12, 0.18), 12)
	rounded(canvas, rect, PAPER, 12, GOLD if highlighted else Color("d6d7c6"), 3 if highlighted else 1)
	rounded(canvas, Rect2(rect.position, Vector2(rect.size.x, 34 if not detailed else 48)), header, 11)
	fitted_text(canvas, data.name.to_upper(), Rect2(rect.position + Vector2(9, 7), Vector2(rect.size.x - 18, 24)), 22 if detailed else 14, Color.WHITE, true)
	var badge_center = rect.position + Vector2(rect.size.x * 0.5, 61 if not detailed else 92)
	canvas.draw_circle(badge_center, 22 if not detailed else 38, LIGHT_GREEN if not is_spirit else Color("e5dded"))
	var initials = data.name.left(2).to_upper()
	text_center(canvas, initials, badge_center + Vector2(0, 6), 15 if not detailed else 26, header)
	if detailed:
		pattern(canvas, data, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.48), minf(25, rect.size.x * 0.085))
		var score_text = "Nature’s Spirit" if is_spirit else "  ·  ".join(data.scores.map(func(value): return str(value)))
		text_center(canvas, score_text, rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 42), 18, GOLD if not is_spirit else header)
	else:
		pattern(canvas, data, rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 45), minf(13, rect.size.x * 0.095))
		if not is_spirit:
			var score_text = "/".join(data.scores.map(func(value): return str(value)))
			fitted_text(canvas, score_text, Rect2(rect.position + Vector2(5, rect.size.y - 18), Vector2(rect.size.x - 10, 14)), 11, MUTED, true)
