class_name StageLawn
extends LawnGrid
## The original grid API remains usable by Dave, pickups and projectiles.

var stage_number: int = 1
var water_rows: Array[int] = []


func _enter_tree() -> void:
	super._enter_tree()


func _ready() -> void:
	var width := float(GameConfiguration.current().section("lawn").tile_width)
	for row in row_count:
		for column in column_count:
			var tile := get_tile(row, column)
			if stage_number == 5:
				tile.rotation.z = atan(0.16) if column < 5 else 0.0
			var is_water := row in water_rows
			if is_water or stage_number == 5:
				(tile.get_node("GrassTufts") as Node3D).hide()
				for mesh: MeshInstance3D in tile.find_children("*", "MeshInstance3D", true, false):
					if mesh.name.begins_with("Grass") or mesh.mesh is ArrayMesh and is_water:
						mesh.hide()
					if mesh.name == "Turf" or mesh.name == "TileTop" or mesh.mesh is ArrayMesh:
						var material := StandardMaterial3D.new()
						material.albedo_color = Color("429dab") if is_water else (Color("b96342") if (column + row) % 2 else Color("c87952"))
						material.roughness = 0.3 if is_water else 0.88
						mesh.material_override = material
			if is_water:
				StageModels.box(tile, "WaterSurface", Vector3(width, 0.025, width), Vector3(0, surface_height + 0.01, 0), Color("5ab8c5"))
				for stripe in 3:
					StageModels.box(tile, "Ripple", Vector3(width * 0.38, 0.006, 0.025), Vector3(0.15, surface_height + 0.025, -0.65 + stripe * 0.60), Color("a1dbe0"))
			elif stage_number == 5:
				for stripe in 4:
					StageModels.box(tile, "RoofJoint", Vector3(width, 0.012, 0.024), Vector3(0, surface_height + 0.03, -0.85 + stripe * 0.55), Color("85412f"))


func cell_to_local(row: int, column: int) -> Vector3:
	var result := super.cell_to_local(row, column)
	if stage_number == 5:
		result.y += minf(float(column), 4.5) * cell_size * 0.16
	return result


func surface_at(position: Vector3) -> float:
	if stage_number != 5:
		return global_position.y + surface_height
	var column := (to_local(position).x / cell_size) + (column_count - 1) * 0.5
	return global_position.y + surface_height + clampf(column, 0.0, 4.5) * cell_size * 0.16
