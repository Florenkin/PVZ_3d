class_name AdventureSeedCard
extends Button

var plant_kind: String = "peashooter"
var number: int = 1
var cost: int = 100
var remaining: float = 0.0
var selected: bool = false
var supply_count: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(112, 118)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = ("按 %d 或点击放入右手" % number if number <= 9 else "点击放入右手") + "，瞄准草坪后左键使用"
	add_theme_stylebox_override("normal", GameUI.style(Color("425e36"), Color("778b54"), 9))
	add_theme_stylebox_override("hover", GameUI.style(Color("577641"), GameUI.GOLD, 9))
	add_theme_stylebox_override("pressed", GameUI.style(Color("334d2d"), GameUI.GOLD, 9))
	add_theme_stylebox_override("disabled", GameUI.style(Color("293c2b"), Color("48533b"), 9))


func _draw() -> void:
	var center := Vector2(size.x * 0.5, 35)
	var alpha := 0.45 if disabled else 1.0
	var green := Color(0.45, 0.70, 0.30, alpha)
	if plant_kind in ["peashooter", "snow_pea", "repeater", "threepeater", "split_pea", "sunflower"]:
		if plant_kind == "snow_pea":
			green = Color(0.5, 0.8, 0.95, alpha)
		draw_line(center + Vector2(0, 10), center + Vector2(0, 26), green, 5)
		draw_circle(center + Vector2(-7, 20), 6, green)
		if plant_kind != "sunflower":
			draw_circle(center, 16, green)
			draw_circle(center + Vector2(16, 1), 9, green)
			draw_circle(center + Vector2(20, 1), 5, Color(0.1, 0.23, 0.1, alpha))
			draw_circle(center + Vector2(-3, -6), 3, Color(0.1, 0.2, 0.1, alpha))
		else:
			for index in 9:
				draw_circle(center + Vector2.from_angle(index * TAU / 9) * 17, 8, Color(0.95, 0.77, 0.29, alpha))
			draw_circle(center, 14, Color(0.44, 0.28, 0.13, alpha))
			draw_circle(center + Vector2(-5, -2), 2, GameUI.INK * Color(1, 1, 1, alpha))
			draw_circle(center + Vector2(5, -2), 2, GameUI.INK * Color(1, 1, 1, alpha))
	elif plant_kind in StageCatalog.MUSHROOMS:
		draw_rect(Rect2(center + Vector2(-6, 2), Vector2(12, 25)), Color(0.88, 0.79, 0.65, alpha))
		draw_circle(center, 21, Color(0.63, 0.43, 0.72, alpha))
		for offset: Vector2 in [Vector2(-9, -4), Vector2(8, -9), Vector2(5, 7)]:
			draw_circle(center + offset, 4, Color(0.91, 0.83, 0.77, alpha))
	elif plant_kind == "grave_buster":
		draw_rect(Rect2(center - Vector2(18, 22), Vector2(36, 47)), Color(0.54, 0.44, 0.24, alpha))
		draw_line(center + Vector2(-15, 15), center + Vector2(14, -18), green, 8)
	elif plant_kind == "cherry_bomb":
		for sign_value: float in [-1, 1]:
			draw_circle(center + Vector2(sign_value * 11, 7), 13, Color(0.84, 0.28, 0.22, alpha))
			draw_line(center + Vector2(sign_value * 11, -3), center + Vector2(0, -19), green, 3)
			draw_circle(center + Vector2(sign_value * 9, 3), 2, GameUI.INK * Color(1, 1, 1, alpha))
	elif plant_kind == "lily_pad":
		draw_circle(center + Vector2(0, 5), 24, green)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, 5), center + Vector2(25, 5), center + Vector2(18, 24)]), Color(0.22, 0.38, 0.2, alpha))
	elif plant_kind in ["flower_pot", "coffee_bean"]:
		var brown := Color(0.7, 0.4, 0.22, alpha)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-21, -10), center + Vector2(21, -10), center + Vector2(14, 25), center + Vector2(-14, 25)]), brown)
		draw_rect(Rect2(center + Vector2(-24, -14), Vector2(48, 8)), Color(0.88, 0.6, 0.34, alpha))
		if plant_kind == "coffee_bean":
			draw_circle(center + Vector2(0, -5), 12, Color(0.33, 0.2, 0.13, alpha))
			draw_line(center + Vector2(-3, -14), center + Vector2(3, 3), Color(0.75, 0.55, 0.3, alpha), 3)
	elif plant_kind in ["cabbage_pult", "kernel_pult", "melon_pult"]:
		draw_line(center + Vector2(-20, 23), center + Vector2(16, -13), Color(0.52, 0.37, 0.22, alpha), 6)
		draw_rect(Rect2(center + Vector2(-25, 22), Vector2(50, 7)), green)
		draw_circle(center + Vector2(13, -10), 15, Color(0.93, 0.76, 0.27, alpha) if plant_kind == "kernel_pult" else green)
		if plant_kind == "melon_pult":
			for x in [-6, 1, 8]:
				draw_line(center + Vector2(x + 10, -22), center + Vector2(x + 10, 2), Color(0.23, 0.4, 0.2, alpha), 3)
	elif plant_kind in ["tangle_kelp", "spikeweed", "cactus", "plantern", "torchwood", "umbrella_leaf"]:
		for index in 5:
			var at := center + Vector2((index - 2) * 8, 20)
			draw_line(at, at + Vector2(sin(index * 2.0) * 8, -40), green, 5)
		if plant_kind == "plantern":
			draw_circle(center, 13, Color(0.98, 0.83, 0.34, alpha))
		elif plant_kind == "torchwood":
			draw_circle(center, 15, Color(0.97, 0.54, 0.2, alpha))
		elif plant_kind == "umbrella_leaf":
			draw_arc(center + Vector2(0, 7), 24, PI, TAU, 16, green, 10)
	elif plant_kind == "starfruit":
		var points := PackedVector2Array()
		for index in 10:
			points.append(center + Vector2.from_angle(-PI / 2 + index * PI / 5) * (25 if index % 2 == 0 else 12))
		draw_colored_polygon(points, Color(0.98, 0.8, 0.24, alpha))
	elif plant_kind == "pumpkin":
		draw_arc(center + Vector2(0, 3), 22, 0, TAU, 24, Color(0.91, 0.52, 0.22, alpha), 13)
	elif plant_kind == "jalapeno":
		draw_line(center + Vector2(-15, 19), center + Vector2(12, -14), Color(0.87, 0.23, 0.17, alpha), 16)
		draw_line(center + Vector2(12, -14), center + Vector2(17, -24), green, 5)
	else:
		draw_style_box(GameUI.style(Color(0.82, 0.23, 0.18, alpha) if plant_kind == "explosive_nut" else Color(0.70, 0.50, 0.28, alpha), Color(0.54, 0.36, 0.18, alpha), 17), Rect2(center - Vector2(17, 24), Vector2(34, 48)))
		for sign_value: float in [-1, 1]:
			draw_circle(center + Vector2(sign_value * 6, -4), 3, Color(0.12, 0.20, 0.1, alpha))
	var font := get_theme_font("font")
	var name_text := StageCatalog.plant_name(plant_kind)
	draw_string(font, Vector2((size.x - font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x) * 0.5, 83), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GameUI.INK)
	var detail := "剩 %d 张" % supply_count if supply_count >= 0 else ("%.1f 秒" % remaining if remaining > 0 else "%d 阳光" % cost)
	draw_string(font, Vector2(12, 106), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GameUI.MUTED if disabled else GameUI.GOLD)
	if number <= 9:
		draw_string(font, Vector2(8, 20), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GameUI.MUTED)
	if selected:
		draw_rect(Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4), GameUI.GOLD, false, 3)
