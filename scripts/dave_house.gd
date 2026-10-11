@tool
class_name DaveHouse
extends Node3D
## An independent, walkable suburban house. Front is +X, facing the lawn.

var settings: Dictionary = {}
var _structure: Node3D
var _door: AnimatableBody3D
var _door_angle: float = 0.0
var _close_remaining: float = 0.0
var _materials: Dictionary = {}
var _apron_width: float = 12.0
var _apron_front: float = 1.92
var door_is_open: bool = false


func _ready() -> void:
	var config: GameConfiguration
	if Engine.is_editor_hint():
		# Editor preview uses the same validated file, without requiring an autoload.
		config = GameConfiguration.new()
		config.emit_warnings = false
		config.load_config()
	else:
		config = GameConfiguration.current()
	settings = config.section("house")
	var lawn := config.section("lawn")
	_apron_width = maxf(settings.width + settings.apron_margin * 2.0, lawn.rows * lawn.cell_size)
	_apron_front = float(settings.front_gap) + 0.12
	position = Vector3(-lawn.columns * lawn.cell_size * 0.5 - settings.front_gap, lawn.surface_height, settings.offset_z)
	if Engine.is_editor_hint():
		config.free()
	_build()
	set_physics_process(not Engine.is_editor_hint() and settings.enabled)
	if not Engine.is_editor_hint():
		add_to_group("dave_houses")


func _build() -> void:
	var previous := get_node_or_null("Structure")
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	_materials.clear()
	_structure = Node3D.new()
	_structure.name = "Structure"
	add_child(_structure)
	_structure.owner = self
	visible = settings.enabled
	if not settings.enabled:
		return
	var wall := _material("wall", settings.wall_color)
	var trim := _material("trim", settings.trim_color)
	var roof := _material("roof", settings.roof_color)
	var tile := _material("tile", settings.roof_tile_color)
	var brick := _material("brick", settings.brick_color)
	var dark := _material("dark", [0.19, 0.23, 0.21, 1.0])
	var glass := _material("glass", settings.window_color, 0.18)
	var wood := _material("wood", settings.wood_color)
	var cream := _material("cream", [0.95, 0.91, 0.75, 1.0])
	var grass := _material("grass", [0.43, 0.63, 0.30, 1.0])
	var concrete := _material("concrete", [0.78, 0.78, 0.67, 1.0])
	var depth := float(settings.depth)
	var width := float(settings.width)
	var height := float(settings.wall_height)
	var thickness := float(settings.wall_thickness)
	var door_width := float(settings.door_width)
	var door_height := float(settings.door_height)
	# A single flat collision surface joins the lawn, porch and house floor.
	var apron_depth: float = depth + settings.apron_margin + _apron_front
	var apron_x: float = (_apron_front - depth - settings.apron_margin) * 0.5
	_box("GardenGround", _structure, Vector3(apron_depth, 0.22, _apron_width), Vector3(apron_x, -0.115, 0), grass)
	_solid("GardenFloor", Vector3(apron_depth, 0.20, _apron_width), Vector3(apron_x, -0.10, 0))
	_box("InteriorFloor", _structure, Vector3(depth, 0.14, width), Vector3(-depth * 0.5, -0.067, 0), wood)
	for index in range(int(ceil(width / 0.55))):
		var z := -width * 0.5 + index * 0.55
		_box("Floorboard%d" % index, _structure, Vector3(depth - 0.3, 0.003, 0.012), Vector3(-depth * 0.5, 0.005, z), dark)
	_box("PorchFloor", _structure, Vector3(settings.porch_depth + 0.2, 0.14, door_width + 1.7), Vector3(settings.porch_depth * 0.5, -0.065, 0), concrete)
	_box("EntranceWalk", _structure, Vector3(_apron_front, 0.08, door_width + 0.2), Vector3(_apron_front * 0.5, -0.035, 0), concrete)
	for index in 3:
		_box("WalkJoint%d" % index, _structure, Vector3(0.015, 0.008, door_width + 0.2), Vector3(_apron_front * (index + 1) / 4.0, 0.010, 0), dark)
	# Doorway is genuinely cut out: two wall sections and a header, no hidden wall.
	var side_width := (width - door_width) * 0.5
	for side: float in [-1.0, 1.0]:
		var z := side * (door_width + side_width) * 0.5
		_wall("Front" + ("Left" if side < 0 else "Right"), Vector3(thickness, height, side_width), Vector3(0, height * 0.5, z), wall)
		_box("FrontBrick%d" % int(side), _structure, Vector3(thickness + 0.04, 0.52, side_width), Vector3(0.012, 0.26, z), brick)
		_wall("Side" + ("Left" if side < 0 else "Right"), Vector3(depth, height, thickness), Vector3(-depth * 0.5, height * 0.5, side * width * 0.5), wall)
		_box("SideBrick%d" % int(side), _structure, Vector3(depth, 0.52, thickness + 0.04), Vector3(-depth * 0.5, 0.26, side * width * 0.5), brick)
		for index in 5:
			_box("Siding%d_%d" % [int(side), index], _structure, Vector3(depth - 0.2, 0.024, 0.028), Vector3(-depth * 0.5, 0.75 + index * 0.46, side * (width * 0.5 + thickness * 0.5 + 0.018)), trim)
		_window("FrontWindow%d" % int(side), Vector3(thickness * 0.5 + 0.045, 1.92, side * width * 0.325), 1.5, 1.6, trim, glass, wood)
		for x: float in [0.0, -depth]:
			_box("Corner_%d_%d" % [int(side), int(x)], _structure, Vector3(thickness + 0.11, height + 0.06, thickness + 0.11), Vector3(x, height * 0.5, side * width * 0.5), trim)
	_wall("BackWall", Vector3(thickness, height, width), Vector3(-depth, height * 0.5, 0), wall)
	_wall("DoorHeader", Vector3(thickness, height - door_height, door_width), Vector3(0, (height + door_height) * 0.5, 0), wall)
	_wall("Ceiling", Vector3(depth, 0.12, width), Vector3(-depth * 0.5, height + 0.04, 0), cream)
	_roof(depth, width, height, roof, tile, trim, wall)
	_chimney(depth, width, height, brick, trim, dark)
	# Entrance frame and leaf. Its real collider rotates with the visible door.
	for side: float in [-1.0, 1.0]:
		_box("DoorFrame%d" % int(side), _structure, Vector3(0.21, door_height + 0.08, 0.16), Vector3(0.035, door_height * 0.5, side * (door_width * 0.5 + 0.03)), trim)
	_box("DoorLintel", _structure, Vector3(0.21, 0.16, door_width + 0.25), Vector3(0.035, door_height + 0.03, 0), trim)
	_door = AnimatableBody3D.new()
	_door.name = "FrontDoor"
	_door.position = Vector3(0.045, 0, -door_width * 0.5)
	_door.collision_layer = 1
	_door.collision_mask = 2 | 4 | 16
	_door.sync_to_physics = true
	_structure.add_child(_door)
	_door.owner = self
	_box("DoorLeaf", _door, Vector3(0.09, door_height - 0.10, door_width - 0.10), Vector3(0, door_height * 0.5, door_width * 0.5), wood)
	_collider(_door, Vector3(0.09, door_height - 0.10, door_width - 0.10), Vector3(0, door_height * 0.5, door_width * 0.5))
	for y: float in [door_height * 0.28, door_height * 0.72]:
		_box("Inset%d" % int(y * 100), _door, Vector3(0.018, door_height * 0.25, door_width * 0.64), Vector3(0.055, y, door_width * 0.5), cream)
	_sphere("DoorHandle", _door, Vector3(0.075, 0.045, 0.045), Vector3(0.11, 1.12, door_width - 0.20), _material("brass", [0.84, 0.65, 0.26, 1.0], 0.3))
	_box("PorchCanopy", _structure, Vector3(settings.porch_depth + 0.5, 0.15, door_width + 1.9), Vector3(settings.porch_depth * 0.5, door_height + 0.24, 0), roof)
	for side: float in [-1.0, 1.0]:
		_wall("PorchPost%d" % int(side), Vector3(0.13, door_height + 0.13, 0.13), Vector3(settings.porch_depth - 0.12, (door_height + 0.13) * 0.5, side * (door_width * 0.5 + 0.63)), trim)
		_planter(Vector3(0.60, 0, side * (width * 0.5 - 0.7)), brick)
	_sign(Vector3(settings.porch_depth + 0.32, door_height + 0.23, 0), "DAVE'S HOUSE", 0.14, trim)
	_furnish(depth, width, wood, cream, brick)
	var light := OmniLight3D.new()
	light.name = "InteriorLight"
	light.position = Vector3(-depth * 0.48, height - 0.45, 0)
	light.light_color = Color(1.0, 0.89, 0.69)
	light.light_energy = settings.interior_light_energy
	light.omni_range = maxf(depth, width)
	light.shadow_enabled = false
	_structure.add_child(light)
	light.owner = self
	_box("LampShade", _structure, Vector3(0.62, 0.16, 0.62), light.position + Vector3.UP * 0.12, cream)


func _roof(depth: float, width: float, height: float, roof: Material, tile: Material, trim: Material, wall: Material) -> void:
	var rise := float(settings.roof_rise)
	var half := width * 0.5 + 0.45
	var slope := atan2(rise, half)
	var length := sqrt(half * half + rise * rise)
	for side: float in [-1.0, 1.0]:
		var panel := _box("Roof%d" % int(side), _structure, Vector3(depth + 1.0, 0.16, length), Vector3(-depth * 0.5, height + rise * 0.5, side * half * 0.5), roof)
		panel.rotation.x = side * slope
		for row in 7:
			var strip := _box("TileRow%d_%d" % [int(side), row], panel, Vector3(depth + 1.01, 0.045, 0.055), Vector3(0, 0.094, -length * 0.5 + row * length / 7.0), tile)
			for index in 5:
				_box("TileJoint%d_%d_%d" % [int(side), row, index], panel, Vector3(0.022, 0.023, length / 7.0), Vector3(-depth * 0.5 + index * depth / 5.0 + (row % 2) * 0.35, 0.091, -length * 0.5 + (row + 0.5) * length / 7.0), tile)
		_box("RoofFascia%d" % int(side), _structure, Vector3(depth + 1.1, 0.18, 0.16), Vector3(-depth * 0.5, height - 0.04, side * half), trim)
	_box("RidgeCap", _structure, Vector3(depth + 1.06, 0.18, 0.23), Vector3(-depth * 0.5, height + rise + 0.07, 0), tile)
	for x: float in [0.13, -depth - 0.13]:
		var vertices := PackedVector3Array([Vector3(x, height, -width * 0.5), Vector3(x, height, width * 0.5), Vector3(x, height + rise, 0)])
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 1, 2, 0])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var gable := MeshInstance3D.new()
		gable.name = "FrontGable" if x > 0 else "BackGable"
		gable.mesh = mesh
		gable.material_override = wall
		_structure.add_child(gable)
		gable.owner = self
	_window("AtticWindow", Vector3(0.18, height + rise * 0.40, 0), 0.82, 0.85, trim, _materials.glass, _materials.wood)


func _chimney(depth: float, width: float, height: float, brick: Material, trim: Material, dark: Material) -> void:
	var center := Vector3(-depth * 0.69, height + settings.roof_rise * 0.70, -width * 0.27)
	_box("Chimney", _structure, Vector3(0.78, 1.75, 0.84), center, brick)
	for index in 7:
		_box("ChimneyMortar%d" % index, _structure, Vector3(0.80, 0.025, 0.86), center + Vector3(0, -0.76 + index * 0.23, 0), trim)
	_box("ChimneyCap", _structure, Vector3(0.96, 0.14, 1.02), center + Vector3.UP * 0.9, trim)
	_box("ChimneyOpening", _structure, Vector3(0.59, 0.02, 0.64), center + Vector3.UP * 0.98, dark)


func _window(name: String, center: Vector3, width: float, height: float, trim: Material, glass: Material, wood: Material) -> void:
	_box(name + "Glass", _structure, Vector3(0.045, height, width), center, glass)
	for side: float in [-1.0, 1.0]:
		_box(name + "Vertical%d" % int(side), _structure, Vector3(0.14, height + 0.20, 0.12), center + Vector3(0.05, 0, side * (width * 0.5 + 0.015)), trim)
		_box(name + "Horizontal%d" % int(side), _structure, Vector3(0.14, 0.12, width + 0.20), center + Vector3(0.05, side * (height * 0.5 + 0.015), 0), trim)
	_box(name + "Mullion", _structure, Vector3(0.08, height, 0.055), center + Vector3(0.074, 0, 0), trim)
	_box(name + "Crossbar", _structure, Vector3(0.08, 0.055, width), center + Vector3(0.074, 0, 0), trim)
	_box(name + "Sill", _structure, Vector3(0.34, 0.12, width + 0.34), center + Vector3(0.09, -height * 0.5 - 0.10, 0), wood)


func _planter(center: Vector3, pot: Material) -> void:
	_box("Planter", _structure, Vector3(0.75, 0.35, 0.85), center + Vector3.UP * 0.175, pot)
	var leaf := _material("foliage", [0.20, 0.49, 0.20, 1.0])
	for index in 3:
		_sphere("Bush%d" % index, _structure, Vector3(0.55, 0.45, 0.52), center + Vector3((index - 1) * 0.18, 0.47 + (index % 2) * 0.10, 0), leaf)


func _furnish(depth: float, width: float, wood: Material, cream: Material, brick: Material) -> void:
	var sofa := _material("sofa", [0.40, 0.64, 0.44, 1.0])
	var z := width * 0.29
	_wall("SofaBase", Vector3(1.05, 0.42, 2.7), Vector3(-depth * 0.53, 0.25, z), sofa)
	_wall("SofaBack", Vector3(0.25, 0.95, 2.7), Vector3(-depth * 0.53 - 0.42, 0.55, z), sofa)
	for side: float in [-1.0, 1.0]:
		_box("SofaArm%d" % int(side), _structure, Vector3(1.05, 0.30, 0.22), Vector3(-depth * 0.53, 0.51, z + side * 1.25), cream)
		_box("SeatCushion%d" % int(side), _structure, Vector3(0.78, 0.18, 1.1), Vector3(-depth * 0.53 + 0.04, 0.52, z + side * 0.58), sofa)
	_wall("Table", Vector3(0.92, 0.14, 1.7), Vector3(-depth * 0.53 + 1.5, 0.66, z), wood)
	for side: float in [-1.0, 1.0]:
		_box("TableLeg%d" % int(side), _structure, Vector3(0.12, 0.64, 0.12), Vector3(-depth * 0.53 + 1.5, 0.32, z + side * 0.62), wood)
	_sphere("TacoPlate", _structure, Vector3(0.31, 0.022, 0.31), Vector3(-depth * 0.53 + 1.5, 0.745, z), cream)
	_box("Taco", _structure, Vector3(0.26, 0.11, 0.16), Vector3(-depth * 0.53 + 1.5, 0.80, z), _material("taco", [0.88, 0.65, 0.29, 1.0]))
	_wall("Bookcase", Vector3(0.45, 1.65, 2.1), Vector3(-depth + 0.40, 0.83, -width * 0.27), wood)
	for index in 5:
		_box("Book%d" % index, _structure, Vector3(0.26, 0.54, 0.15), Vector3(-depth + 0.69, 1.12, -width * 0.27 - 0.57 + index * 0.24), brick if index % 2 else cream)
	_box("Rug", _structure, Vector3(depth * 0.43, 0.015, width * 0.45), Vector3(-depth * 0.45, 0.018, 0), _material("rug", [0.80, 0.60, 0.39, 1.0]))
	_sign(Vector3(-depth + 0.16, 2.35, 0), "HOME SWEET HOME", 0.17, cream)


func _sign(center: Vector3, text: String, font_size: float, material: Material) -> void:
	var mesh := TextMesh.new()
	mesh.text = text
	mesh.font_size = 48
	mesh.pixel_size = font_size / 48.0
	mesh.depth = 0.007
	var sign := MeshInstance3D.new()
	sign.name = "Sign"
	sign.mesh = mesh
	sign.material_override = material
	sign.position = center
	sign.rotation.y = PI / 2.0
	_structure.add_child(sign)
	sign.owner = self


func _material(key: String, rgba: Array, roughness: float = 0.8) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(rgba[0], rgba[1], rgba[2], rgba[3])
	material.roughness = roughness
	_materials[key] = material
	return material


func _box(name: String, parent: Node3D, size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	node.position = center
	parent.add_child(node)
	node.owner = self
	return node


func _sphere(name: String, parent: Node3D, size: Vector3, center: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	node.scale = size
	node.position = center
	parent.add_child(node)
	node.owner = self


func _wall(name: String, size: Vector3, center: Vector3, material: Material) -> void:
	_box(name, _structure, size, center, material)
	_solid(name + "Body", size, center)


func _solid(name: String, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 2 | 4 | 16
	body.position = center
	_structure.add_child(body)
	body.owner = self
	_collider(body, size, Vector3.ZERO)


func _collider(body: CollisionObject3D, size: Vector3, center: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.name = "CollisionShape3D"
	node.shape = shape
	node.position = center
	body.add_child(node)
	node.owner = self


func get_exploration_bounds() -> Rect2:
	if settings.is_empty() or not settings.enabled:
		return Rect2()
	return Rect2(Vector2(global_position.x - settings.depth - settings.apron_margin, global_position.z - _apron_width * 0.5), Vector2(settings.depth + settings.apron_margin + _apron_front, _apron_width))


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("dave_player") as Node3D
	var nearby := false
	if player != null:
		var local := to_local(player.global_position)
		nearby = absf(local.x) <= float(settings.door_trigger_distance) and absf(local.z) <= float(settings.door_width) * 0.5 + 0.8
	if nearby:
		_close_remaining = settings.door_close_delay
	else:
		_close_remaining = maxf(0.0, _close_remaining - delta)
	door_is_open = nearby or _close_remaining > 0.0
	var target := deg_to_rad(settings.door_open_degrees) if door_is_open else 0.0
	_door_angle = move_toward(_door_angle, target, deg_to_rad(settings.door_speed_degrees) * delta)
	_door.rotation.y = _door_angle
