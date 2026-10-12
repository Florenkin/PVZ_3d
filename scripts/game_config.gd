class_name GameConfiguration
extends Node
## One validated startup snapshot shared by initial and dynamically spawned entities.

const DEFAULTS = preload("res://scripts/game_config_defaults.gd")
const CONFIG_PATH = "res://config/game_config.json"
var values: Dictionary = {}
var warnings: PackedStringArray = []
var loaded_path: String = CONFIG_PATH
var emit_warnings: bool = true


static func current() -> GameConfiguration:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameConfig") as GameConfiguration


func _enter_tree() -> void:
	if values.is_empty():
		load_config()


func default_values() -> Dictionary:
	return JSON.parse_string(DEFAULTS.TEXT) as Dictionary


func load_config(path: String = CONFIG_PATH) -> void:
	loaded_path = path
	warnings.clear()
	var defaults := default_values()
	values = defaults.duplicate(true)
	if not FileAccess.file_exists(path):
		_warn("$", "文件不存在，使用内置默认值")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_warn("$", "无法读取文件，使用内置默认值")
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text().trim_prefix("\ufeff")) != OK:
		_warn("$", "JSON 第 %d 行：%s，使用内置默认值" % [parser.get_error_line(), parser.get_error_message()])
		return
	if not parser.data is Dictionary:
		_warn("$", "顶层必须为对象，使用内置默认值")
		return
	values = _validate_dictionary(parser.data, defaults, "")
	_validate_relationships(defaults)


## Tests inject isolated snapshots; the editable user file is never modified.
func use_values_for_tests(input: Dictionary) -> void:
	loaded_path = "<test fixture>"
	warnings.clear()
	var defaults := default_values()
	values = _validate_dictionary(input, defaults, "")
	_validate_relationships(defaults)


func _warn(path: String, reason: String) -> void:
	var message := "%s [%s] %s" % [loaded_path, path, reason]
	warnings.append(message)
	if emit_warnings:
		push_warning(message)


func _validate_dictionary(input: Dictionary, defaults: Dictionary, path: String) -> Dictionary:
	var result := defaults.duplicate(true)
	var allowed := defaults.duplicate(true)
	if path.begins_with("plants.types.") and path.count(".") == 2:
		allowed = default_values().plants.common.duplicate(true)
		allowed.merge(defaults, true)
	if path.begins_with("zombies.types.") and path.count(".") == 2:
		allowed = default_values().zombies.common.duplicate(true)
		allowed.merge(defaults, true)
	for key: String in input:
		var key_path := path + "." + key if not path.is_empty() else key
		if not allowed.has(key):
			_warn(key_path, "未知字段，已忽略")
			continue
		var baseline: Variant = allowed[key]
		var candidate: Variant = input[key]
		if baseline is Dictionary:
			if candidate is Dictionary:
				result[key] = _validate_dictionary(candidate, baseline, key_path)
			else:
				_warn(key_path, "必须为对象，使用默认值")
		elif _valid_value(candidate, baseline, key_path):
			result[key] = candidate.duplicate(true) if candidate is Array else candidate
		else:
			_warn(key_path, "类型或范围无效，使用默认值")
	return result


func _valid_value(value: Variant, baseline: Variant, path: String) -> bool:
	var key := path.get_slice(".", path.count("."))
	if baseline is bool:
		return value is bool
	if baseline is Array:
		if not value is Array or value.size() != baseline.size():
			return false
		for number: Variant in value:
			if not _is_number(number):
				return false
		if key.ends_with("color"):
			for number: float in value:
				if number < 0.0 or number > 1.0:
					return false
		if key == "scale" or key.ends_with("size"):
			for number: float in value:
				if number <= 0.0:
					return false
		if key == "movement_bounds" and (value[2] <= 0 or value[3] <= 0):
			return false
		return true
	if not _is_number(value):
		return false
	if key in ["version", "rows", "columns", "row", "column", "pea_damage", "maximum_health", "burst_size", "armor_drop_health", "hand_drop_health", "newspaper_drop_health", "window_width", "window_height", "minimum_width", "minimum_height", "viewport_width", "viewport_height", "medium_value", "initial_value"] and float(value) != floor(float(value)):
		return false
	if path.begins_with("sun.") and key in ["spawn_interval", "medium_value", "fall_speed"]:
		return value > 0
	if key == "version":
		return value == 1
	if key == "anger_pause_duration":
		return value > 0
	if key == "enraged_speed_multiplier":
		return value > 1
	if key in ["rows", "columns", "row", "column", "burst_size"]:
		return value >= 1 and value <= 64
	if key in ["recoil_degrees", "maximum_recoil_degrees", "vault_lean_degrees"]:
		return value >= 0 and value <= 30
	if key in ["slow_multiplier", "frost_color_strength", "pole_release_fraction", "bounce", "friction"]:
		return value >= 0 and value <= 1
	if key == "fov":
		return value > 1 and value < 179
	if key == "pitch_limit_degrees":
		return value > 0 and value < 90
	if key == "door_open_degrees":
		return value >= 90 and value <= 170
	if path.begins_with("house.") and key in ["depth", "wall_thickness", "roof_rise", "door_trigger_distance", "door_speed_degrees"]:
		return value > 0
	if key in ["maximum_health", "shot_interval", "burst_spacing", "recoil_recovery_time", "knockback_deceleration", "maximum_walk_distance", "respawn_delay", "prepare_time", "vault_height", "landing_clearance", "pole_length", "pole_radius", "gravity", "mass", "lifetime", "cell_size", "tile_width", "tile_thickness", "scale", "font_scale", "radius", "height", "inner_radius", "outer_radius", "maximum_distance", "minimum_size", "maximum_size", "distance", "size", "near", "far", "lane_spread_distance", "target_lane_tolerance", "vault_trigger_distance", "zoom_in_factor", "zoom_out_factor"] or key.ends_with("width") or key.ends_with("height") and key != "surface_height" and key != "ground_height" and key != "walk_bob_height" and key != "lift_height":
		return value > 0
	if key in ["yaw_degrees", "newspaper_yaw_degrees", "pitch_degrees", "minimum_pitch_degrees", "maximum_pitch_degrees", "surface_height", "ground_height", "spin_x_min", "spin_x_max", "spin_y", "spin_z", "offset_z"]:
		return true
	return value >= 0


func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _validate_relationships(defaults: Dictionary) -> void:
	var house: Dictionary = values.house
	if house.width <= house.door_width + house.wall_thickness * 2.0 or house.depth <= house.wall_thickness * 2.0 or house.wall_height <= house.door_height + 0.15 or house.door_height < 2.0 or house.door_width < 1.0:
		_warn("house", "房屋尺寸或门洞尺寸冲突，使用默认房屋参数")
		values.house = defaults.house.duplicate(true)
	var layout_ok: bool = values.lawn.tile_width <= values.lawn.cell_size
	for placement: Dictionary in values.placements.values():
		layout_ok = layout_ok and placement.row <= values.lawn.rows and placement.column <= values.lawn.columns
	if not layout_ok:
		_warn("lawn / placements", "格子尺寸或放置坐标冲突，草坪与放置位置整体使用默认值")
		values.lawn = defaults.lawn.duplicate(true)
		values.placements = defaults.placements.duplicate(true)
	if values.cameras.first_person.near >= values.cameras.first_person.far:
		_warn("cameras.first_person", "near 必须小于 far，使用默认值")
		values.cameras.first_person = defaults.cameras.first_person.duplicate(true)
	if values.cameras.orbit.minimum_size > values.cameras.orbit.maximum_size or values.cameras.orbit.minimum_pitch_degrees >= values.cameras.orbit.maximum_pitch_degrees:
		_warn("cameras.orbit", "相机范围冲突，使用默认值")
		values.cameras.orbit = defaults.cameras.orbit.duplicate(true)
	if values.display.minimum_width > values.display.window_width or values.display.minimum_height > values.display.window_height:
		_warn("display", "窗口最小尺寸超过窗口尺寸，使用默认值")
		values.display = defaults.display.duplicate(true)
	if values.dave.boundary_inset >= minf(values.lawn.rows, values.lawn.columns) * float(values.lawn.cell_size) * 0.5:
		_warn("dave.boundary_inset", "移动边界缩进超过草坪范围，使用 0")
		values.dave.boundary_inset = 0.0
	for model_key: String in values.models:
		for part_path: String in values.models[model_key].parts:
			var part: Dictionary = values.models[model_key].parts[part_path]
			if not part.has("mesh_dimensions"):
				continue
			var dims: Dictionary = part.mesh_dimensions
			var baseline: Dictionary = defaults.models[model_key].parts[part_path].mesh_dimensions
			if dims.has("radius") and dims.has("height") and baseline.height >= baseline.radius * 2.0 and dims.height < dims.radius * 2.0:
				_warn("models." + model_key + ".parts." + part_path + ".mesh_dimensions", "球体/胶囊高度必须至少为半径的两倍，使用默认尺寸")
				part.mesh_dimensions = defaults.models[model_key].parts[part_path].mesh_dimensions.duplicate(true)
			if dims.has("inner_radius") and dims.has("outer_radius") and dims.inner_radius >= dims.outer_radius:
				_warn("models." + model_key + ".parts." + part_path + ".mesh_dimensions", "内半径必须小于外半径，使用默认尺寸")
				part.mesh_dimensions = defaults.models[model_key].parts[part_path].mesh_dimensions.duplicate(true)
	for kind: String in values.physics.parts:
		var part: Dictionary = values.physics.parts[kind]
		if part.has("spin_x_min") and part.spin_x_min > part.spin_x_max:
			_warn("physics.parts." + kind, "旋转速度上下限冲突，使用默认值")
			values.physics.parts[kind] = defaults.physics.parts[kind].duplicate(true)


func section(path: String) -> Dictionary:
	if values.is_empty():
		load_config()
	var result: Variant = values
	for key: String in path.split("."):
		if not result is Dictionary or not result.has(key):
			return {}
		result = result[key]
	return result.duplicate(true) if result is Dictionary else {}


func entity_key(node: Node) -> String:
	return node.scene_file_path.get_file().get_basename()


func entity_stats(key: String) -> Dictionary:
	var group := "plants" if section("plants.types").has(key) else "zombies"
	if section(group + ".types").has(key):
		var stats := section(group + ".common")
		stats.merge(section(group + ".types." + key), true)
		return stats
	if key == "crazy_dave":
		return section("dave")
	if key == "main":
		return section("respawn")
	return {}


func apply_entity(node: Node, key: String = "") -> void:
	if node.has_meta("config_applied"):
		return
	if key.is_empty():
		key = entity_key(node)
	var properties: Dictionary = {}
	for item: Dictionary in node.get_property_list():
		properties[item.name] = true
	var stats := entity_stats(key)
	for field: String in stats:
		if properties.has(field) and field != "movement_bounds":
			node.set(field, stats[field])
	apply_model(node as Node3D, key)
	node.set_meta("config_applied", true)


func vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


func color(value: Array) -> Color:
	return Color(value[0], value[1], value[2], value[3])


func apply_model(root: Node3D, key: String) -> void:
	var model := section("models." + key)
	if root == null or model.is_empty():
		return
	var original_bounds := model_bounds(root)
	var part_bounds: Dictionary = {}
	for path: String in ["Visuals", "Visuals/Torso", "Visuals/Legs", "Visuals/Head", "Visuals/Head/Cone", "Visuals/Head/Bucket", "Visuals/Newspaper", "Visuals/Arms/LeftHandAssembly", "Visuals/Arms/RightHandAssembly"]:
		var source := root.get_node_or_null(path) as Node3D
		if source != null:
			part_bounds[source] = model_bounds(source).size
	for path: String in model.parts:
		var part := root.get_node_or_null(path) as Node3D
		if part == null:
			continue
		var spec: Dictionary = model.parts[path]
		part.position = vector(spec.position)
		part.rotation_degrees = vector(spec.rotation_degrees)
		part.scale = vector(spec.scale)
		if part is MeshInstance3D:
			if part.mesh != null:
				part.mesh = part.mesh.duplicate(true)
				for field: String in spec.get("mesh_dimensions", {}):
					part.mesh.set(field, spec.mesh_dimensions[field])
			if spec.has("color") and part.material_override is StandardMaterial3D:
				part.material_override = part.material_override.duplicate(true)
				part.material_override.albedo_color = color(spec.color)
	var overall := float(model.scale)
	for child: Node in root.get_children():
		if child is Node3D and not child is CollisionShape3D and child.name != "WaistMount":
			child.position *= overall
			child.scale *= overall
	# Physics roots and collision nodes remain unit scale.
	for collider: Node in root.find_children("*", "CollisionShape3D", true, false):
		if collider.get_parent() == root or key == "wall_nut":
			collider.shape = collider.shape.duplicate(true)
			collider.position *= overall
			scale_shape(collider.shape, Vector3.ONE * overall)
	root.set_meta("model_scale", overall)
	for source: Node3D in part_bounds:
		var before: Vector3 = part_bounds[source]
		var after := model_bounds(source).size
		var ratio := Vector3.ONE
		for axis in 3:
			if before[axis] > 0.0001:
				ratio[axis] = after[axis] / before[axis]
		source.set_meta("config_bounds_ratio", ratio)
	# Resize the standing capsule to the configured visual bounds.
	var collision := root.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		var bounds := model_bounds(root)
		collision.shape.radius *= maxf(bounds.size.x, bounds.size.z) / maxf(maxf(original_bounds.size.x, original_bounds.size.z) * overall, 0.001)
		collision.shape.height = maxf(collision.shape.height / overall * bounds.end.y / maxf(original_bounds.end.y, 0.001), collision.shape.radius * 2.0)
		collision.position.y = collision.shape.height * 0.5
	if key == "wall_nut":
		var nut_collision := root.get_node("PlantBody/CollisionShape3D") as CollisionShape3D
		var bounds := model_bounds(root)
		nut_collision.shape.radius *= maxf(bounds.size.x, bounds.size.z) / maxf(maxf(original_bounds.size.x, original_bounds.size.z) * overall, 0.001)
		nut_collision.shape.height *= bounds.end.y / maxf(original_bounds.end.y * overall, 0.001)
		nut_collision.position.y = nut_collision.shape.height * 0.5


func model_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.visible:
			continue
		if root.name == "Visuals" or root is CharacterBody3D:
			var ancestor := mesh.get_parent()
			var accessory := false
			while ancestor != root and ancestor != null:
				accessory = accessory or ancestor.name in ["Pole", "Cone", "Bucket", "Newspaper"]
				ancestor = ancestor.get_parent()
			if accessory:
				continue
		var local: Transform3D = root.global_transform.affine_inverse() * mesh.global_transform if root.is_inside_tree() and mesh.is_inside_tree() else _relative_transform(root, mesh)
		var box: AABB = local * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != root and parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result


func scale_shape(shape: Shape3D, size: Vector3) -> void:
	if shape is BoxShape3D:
		shape.size *= size
	elif shape is CapsuleShape3D or shape is CylinderShape3D:
		shape.radius *= maxf(size.x, size.z)
		shape.height *= size.y
	elif shape is SphereShape3D:
		shape.radius *= maxf(size.x, maxf(size.y, size.z))
	elif shape is ConvexPolygonShape3D:
		var points: PackedVector3Array = shape.points
		for index in points.size():
			points[index] *= size
		shape.points = points


func configure_projectile(pea: Node3D) -> void:
	if pea.has_meta("projectile_config_applied"):
		return
	var params := section("projectiles")
	pea.set("maximum_distance", params.maximum_distance)
	for mesh: MeshInstance3D in pea.find_children("*", "MeshInstance3D", true, false):
		mesh.mesh = mesh.mesh.duplicate(true)
		if mesh.mesh is SphereMesh:
			mesh.mesh.radius = params.radius
			mesh.mesh.height = params.radius * 2.0
		if mesh.material_override is StandardMaterial3D:
			mesh.material_override = mesh.material_override.duplicate(true)
			mesh.material_override.albedo_color = color(params.snow_color if entity_key(pea) == "snow_pea" else params.color)
	var collider := pea.get_node("CollisionShape3D") as CollisionShape3D
	collider.shape = collider.shape.duplicate(true)
	(collider.shape as SphereShape3D).radius = params.radius
	pea.set_meta("projectile_config_applied", true)


func configure_debris(part: RigidBody3D, kind: String) -> void:
	var params := section("physics.debris")
	params.merge(section("physics.parts." + kind), true)
	part.mass = params.mass
	part.set("lifetime", params.lifetime)
	part.linear_damp = params.linear_damp
	part.angular_damp = params.angular_damp
	part.physics_material_override.friction = params.friction
	part.physics_material_override.bounce = params.bounce


func apply_scene(root: Node3D) -> void:
	apply_entity(root, "main")
	var env := section("environment")
	var sun := root.get_node("Sun") as DirectionalLight3D
	var fill := root.get_node("SoftFill") as DirectionalLight3D
	sun.light_energy = env.sun_energy
	fill.light_energy = env.fill_energy
	sun.light_color = color(env.sun_color)
	fill.light_color = color(env.fill_color)
	sun.rotation_degrees = vector(env.sun_rotation_degrees)
	fill.rotation_degrees = vector(env.fill_rotation_degrees)
	sun.shadow_blur = env.shadow_blur
	sun.shadow_bias = env.shadow_bias
	sun.directional_shadow_max_distance = env.shadow_distance
	# Environment settings are global to this game's startup snapshot. Keep the
	# original sky resource so renderer-owned cached textures are not duplicated.
	var environment := (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	environment.ambient_light_color = color(env.ambient_color)
	environment.ambient_light_energy = env.ambient_energy
	var sky := environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = color(env.sky_top_color)
	sky.sky_horizon_color = color(env.sky_horizon_color)
	sky.ground_horizon_color = color(env.sky_horizon_color)
	sky.ground_bottom_color = color(env.ground_bottom_color)
	(root.get_node("WorldEnvironment") as WorldEnvironment).environment = environment
	var backdrop := root.get_node("Backdrop") as MeshInstance3D
	backdrop.mesh = backdrop.mesh.duplicate(true)
	(backdrop.mesh as PlaneMesh).size = Vector2.ONE * env.ground_size
	backdrop.material_override = backdrop.material_override.duplicate(true)
	backdrop.material_override.albedo_color = color(env.backdrop_color)
	root.get_node("BackgroundGround").position.y = env.ground_height
	backdrop.position.y = env.ground_height + 0.125
	var ground := root.get_node("BackgroundGround/CollisionShape3D") as CollisionShape3D
	ground.shape = ground.shape.duplicate(true)
	ground.shape.size = Vector3(env.ground_size, 0.25, env.ground_size)
	PhysicsServer3D.area_set_param(root.get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, section("physics").gravity)
	var display := section("display")
	var window := root.get_window()
	window.min_size = Vector2i(display.minimum_width, display.minimum_height)
	window.content_scale_size = Vector2i(display.viewport_width, display.viewport_height)
	if DisplayServer.get_name() != "headless":
		window.size = Vector2i(display.window_width, display.window_height)
