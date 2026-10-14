class_name GameUI
extends RefCounted
## Shared readable panels and keyboard-focus styles for menus and adventure HUD.

const INK := Color("edf4dc")
const MUTED := Color("b9c7ab")
const GREEN := Color("4d7138")
const GOLD := Color("e6c574")


static func style(color: Color, border: Color = Color("577044"), radius: int = 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


static func panel(parent: Node, color: Color = Color(0.09, 0.15, 0.10, 0.96)) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", style(color))
	parent.add_child(result)
	return result


static func label(parent: Node, value: String, font_size: int = 20, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


static func button(parent: Node, value: String, action: Callable, color: Color = GREEN, minimum: Vector2 = Vector2(140, 48)) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size = minimum
	result.add_theme_font_size_override("font_size", 20)
	result.add_theme_color_override("font_color", INK)
	result.add_theme_color_override("font_disabled_color", Color("83917b"))
	result.add_theme_stylebox_override("normal", style(color))
	result.add_theme_stylebox_override("hover", style(color.lightened(0.10), GOLD))
	result.add_theme_stylebox_override("pressed", style(color.darkened(0.12), GOLD))
	result.add_theme_stylebox_override("disabled", style(Color("26372a"), Color("3e4b36")))
	result.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), GOLD))
	result.pressed.connect(action)
	parent.add_child(result)
	return result


static func full_rect(parent: Node) -> Control:
	var result := Control.new()
	parent.add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
