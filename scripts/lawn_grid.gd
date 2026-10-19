class_name LawnGrid
extends Node3D
## Five rows run along Z; nine columns run along X. Plants face +X.

const ROW_COUNT: int = 5
const COLUMN_COUNT: int = 9
const CELL_SIZE: float = 2.4
const SURFACE_HEIGHT: float = 0.025


var row_count: int = 5
var column_count: int = 9
var cell_size: float = 2.4
var surface_height: float = 0.025
@export var row_count_override: int = 0
@export var column_count_override: int = 0
const TILE_SCENE = preload("res://scenes/terrain/grass_tile.tscn")


func _enter_tree() -> void:
	var params := GameConfiguration.current().section("lawn")
	row_count = row_count_override if row_count_override > 0 else int(params.rows)
	column_count = column_count_override if column_count_override > 0 else int(params.columns)
	cell_size = params.cell_size
	surface_height = params.surface_height
	var tiles := get_node("Tiles")
	for tile: Node in tiles.get_children():
		tiles.remove_child(tile)
		tile.queue_free()
	for row in row_count:
		for column in column_count:
			var tile := TILE_SCENE.instantiate() as GrassTile
			tile.name = "Tile_R%d_C%d" % [row + 1, column + 1]
			tile.grid_coordinates = Vector2i(column, row)
			tile.alternate_shade = (row + column) % 2 == 1
			tile.position = cell_to_local(row, column) - Vector3.UP * surface_height
			tiles.add_child(tile)


func is_valid_cell(row: int, column: int) -> bool:
	return row >= 0 and row < row_count and column >= 0 and column < column_count


func get_tile(row: int, column: int) -> GrassTile:
	if not is_valid_cell(row, column):
		return null
	return get_node("Tiles/Tile_R%d_C%d" % [row + 1, column + 1]) as GrassTile


func cell_to_local(row: int, column: int) -> Vector3:
	return Vector3(
		(column - (column_count - 1) * 0.5) * cell_size,
		surface_height,
		(row - (row_count - 1) * 0.5) * cell_size
	)


func cell_to_world(row: int, column: int) -> Vector3:
	return to_global(cell_to_local(row, column))


## Returns (column, row). Outside the lawn, return (-1, -1).
func world_to_cell(world_position: Vector3) -> Vector2i:
	var local_position := to_local(world_position)
	var column := int(floor(local_position.x / cell_size + column_count * 0.5))
	var row := int(floor(local_position.z / cell_size + row_count * 0.5))
	if not is_valid_cell(row, column):
		return Vector2i(-1, -1)
	return Vector2i(column, row)

