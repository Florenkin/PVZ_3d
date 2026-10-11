@tool
class_name GrassTile
extends Node3D
## An independent terrain entity. No plant is owned by this scene.

const LIGHT_TURF: Material = preload("res://assets/materials/turf_light.tres")
const DARK_TURF: Material = preload("res://assets/materials/turf_dark.tres")

## Coordinates use (column, row), starting at zero.
@export var grid_coordinates: Vector2i = Vector2i(-1, -1)
@export var alternate_shade: bool = false:
	set(value):
		alternate_shade = value
		_update_turf()


func _ready() -> void:
	if not Engine.is_editor_hint():
		var params := GameConfiguration.current().section("lawn")
		var factor := Vector3(params.tile_width / 2.36, params.tile_thickness / 0.435, params.tile_width / 2.36)
		for child: Node in get_children():
			if child is Node3D and not child is StaticBody3D:
				child.scale *= factor
				child.position = child.position * factor + Vector3.UP * (params.surface_height - 0.025 * factor.y)
		var shape := get_node("GroundBody/CollisionShape3D") as CollisionShape3D
		shape.shape = shape.shape.duplicate(true)
		GameConfiguration.current().scale_shape(shape.shape, factor)
		shape.position = shape.position * factor + Vector3.UP * (params.surface_height - 0.025 * factor.y)
	_update_turf()


func _update_turf() -> void:
	var turf := get_node_or_null("Turf") as MeshInstance3D
	if turf != null:
		turf.material_override = DARK_TURF if alternate_shade else LIGHT_TURF
		if not Engine.is_editor_hint():
			turf.material_override = turf.material_override.duplicate(true)
			var params := GameConfiguration.current().section("lawn")
			turf.material_override.albedo_color = GameConfiguration.current().color(params.dark_color if alternate_shade else params.light_color)

