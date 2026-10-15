extends SceneTree

var mesh_count := 0
var surface_count := 0
var triangles := 0
var materials: Dictionary = {}
var bounds := AABB()
var have_bounds := false
var head_bounds := AABB()
var have_head := false
var have_shin := false
var cone_parts := 0
var removable_parent := false
var errors: Array[String] = []
const TEXTURED_NAMES = ["Skin_sage_mottled", "Shin_sage_green", "Jacket_worn_brown_twill", "Lapel_brown_twill", "Trousers_indigo_denim", "Shirt_aged_ivory_cotton", "Tie_faded_brick_red", "Shoes_scuffed_brown_leather", "Eyeballs_yellowed_ivory", "Cone_worn_orange_plastic"]

func _initialize() -> void:
	_check.call_deferred()

func require(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func _check() -> void:
	create_timer(30.0).timeout.connect(func(): quit(1))
	var packed := load("res://conehead_zombie.glb") as PackedScene
	if packed == null:
		push_error("Conehead GLB did not import as PackedScene")
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	inspect(instance)
	require(mesh_count > 250, "Body mesh pieces missing")
	require(triangles > 600000, "Mesh data unexpectedly incomplete")
	require(materials.size() == 25, "Expected 25 named materials")
	require(bounds.size.y > 3.1 and bounds.size.y < 3.6, "Unexpected conehead height")
	require(bounds.size.x > 1.2 and bounds.size.x < 1.5, "Unexpected character width")
	require(have_head and have_shin, "Head or sage-green shin not found")
	require(removable_parent and cone_parts == 7, "Removable cone hierarchy incomplete")
	require(head_bounds.size.z / head_bounds.size.x > .9, "Head depth unexpectedly flattened")
	if not errors.is_empty():
		push_error(str(errors))
		quit(1)
		return
	var report := {"result": "PASS", "godot": Engine.get_version_info().string, "mesh_nodes": mesh_count, "surfaces": surface_count, "triangles": triangles, "materials": materials.size(), "dimensions_y_up_m": [bounds.size.x, bounds.size.y, bounds.size.z], "head_dimensions_y_up_m": [head_bounds.size.x, head_bounds.size.y, head_bounds.size.z], "head_depth_to_width_ratio": head_bounds.size.z / head_bounds.size.x, "green_shin_material_found": have_shin, "removable_cone_parts": cone_parts, "missing_materials": 0}
	var file := FileAccess.open("res://godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("CONEHEAD GODOT VALIDATION PASSED: ", report)
	instance.queue_free()
	quit()

func inspect(node: Node) -> void:
	if node.name == "TrafficCone_removable":
		removable_parent = true
	if node is MeshInstance3D:
		var object := node as MeshInstance3D
		require(object.mesh != null, "Missing mesh: " + str(object.name))
		if object.mesh == null:
			return
		mesh_count += 1
		if object.name.begins_with("Cone_"):
			cone_parts += 1
			require(object.get_parent().name == "TrafficCone_removable", "Cone piece outside removable root")
		var object_bounds := object.global_transform * object.get_aabb()
		bounds = bounds.merge(object_bounds) if have_bounds else object_bounds
		have_bounds = true
		if object.name.begins_with("Head_sculpt"):
			head_bounds = object_bounds
			have_head = true
		for surface in range(object.mesh.get_surface_count()):
			surface_count += 1
			var material := object.get_active_material(surface) as StandardMaterial3D
			require(material != null, "Missing material: " + str(object.name))
			if material == null:
				continue
			materials[material.resource_name] = true
			if material.resource_name == "Shin_sage_green":
				have_shin = true
			var arrays := object.mesh.surface_get_arrays(surface)
			require(arrays[Mesh.ARRAY_VERTEX].size() > 0, "Empty vertex array")
			require(arrays[Mesh.ARRAY_NORMAL].size() == arrays[Mesh.ARRAY_VERTEX].size(), "Missing vertex normals")
			require(arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size(), "Missing UVs")
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			if material.resource_name in TEXTURED_NAMES:
				require(material.albedo_texture != null, "Missing albedo: " + material.resource_name)
				require(material.normal_enabled and material.normal_texture != null, "Missing normal: " + material.resource_name)
				require(material.roughness_texture != null, "Missing roughness: " + material.resource_name)
	for child in node.get_children():
		inspect(child)
