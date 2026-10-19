class_name StageModels
extends RefCounted
## Procedural, distinct models for the adventure showcase; reuse authored meshes.

static var _materials: Dictionary = {}
const ORIGINAL_PLANTS: Dictionary = {
	"peashooter": "peashooter", "repeater": "repeater", "snow_pea": "snow_pea", "threepeater": "threepeater", "wall_nut": "wall_nut", "tall_nut": "wall_nut"
}


static func material(color: Color, glowing: bool = false) -> StandardMaterial3D:
	var key := color.to_html() + str(glowing)
	if not _materials.has(key):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.7
		if color.a < 1.0:
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if glowing:
			result.emission_enabled = true
			result.emission = color
			result.emission_energy_multiplier = 1.3
		_materials[key] = result
	return _materials[key]


static func mesh(parent: Node3D, node_name: String, shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = node_name
	result.mesh = shape
	result.position = at
	result.material_override = material(color)
	parent.add_child(result, true)
	return result


static func sphere(parent: Node3D, node_name: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 20
	shape.rings = 12
	var result := mesh(parent, node_name, shape, at, color)
	result.scale = size
	return result


static func box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, node_name, shape, at, color)


static func cylinder(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, color: Color, top: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0.0 else top
	shape.height = height
	shape.radial_segments = 20
	return mesh(parent, node_name, shape, at, color)


static func ring(parent: Node3D, node_name: String, radius: float, thickness: float, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius + thickness
	shape.rings = 24
	shape.ring_segments = 12
	return mesh(parent, node_name, shape, at, color)


static func label(parent: Node3D, text: String, at: Vector3, color: Color = Color.WHITE) -> Label3D:
	var result := Label3D.new()
	result.text = text
	result.position = at
	result.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	result.font_size = int(GameConfiguration.current().section("stages").label_font_size)
	result.pixel_size = 0.009
	result.modulate = color
	result.outline_size = 5
	result.no_depth_test = false
	parent.add_child(result, true)
	return result


static func eyes(parent: Node3D, center: Vector3, half_width: float = 0.19) -> void:
	for sign_value: float in [-1.0, 1.0]:
		var p := center + Vector3(0, 0.04, sign_value * half_width)
		sphere(parent, "Eye", Vector3(0.065, 0.17, 0.11), p, Color("20352a"))
		sphere(parent, "EyeGlint", Vector3(0.025, 0.045, 0.035), p + Vector3(0.033, 0.04, -0.017), Color("fffbe7"))


static func leaves(parent: Node3D) -> void:
	for index in 4:
		var angle := index * PI * 0.5 + 0.35
		var leaf := sphere(parent, "Leaf", Vector3(0.75, 0.11, 0.28), Vector3(cos(angle) * 0.28, 0.08, sin(angle) * 0.28), Color("549846"))
		leaf.rotation.y = -angle


static func stem(parent: Node3D, height: float = 0.85) -> void:
	leaves(parent)
	cylinder(parent, "Stem", 0.09, height, Vector3(0, height * 0.5, 0), Color("4e963f"))


static func copy_original_plant(parent: Node3D, kind: String) -> void:
	var original := load("res://scenes/plants/" + ORIGINAL_PLANTS[kind] + ".tscn") as PackedScene
	var source := original.instantiate() as Node3D
	GameConfiguration.current().apply_entity(source, ORIGINAL_PLANTS[kind])
	for child: Node in source.get_children():
		if child is CollisionObject3D:
			continue
		source.remove_child(child)
		child.owner = null
		parent.add_child(child)
	source.free()
	if kind == "tall_nut":
		parent.scale.y = 1.8


static func plant(parent: Node3D, kind: String) -> void:
	if kind in ["bowling_nut", "explosive_nut"]:
		copy_original_plant(parent, "wall_nut")
		if kind == "explosive_nut":
			for part: MeshInstance3D in parent.find_children("*", "MeshInstance3D", true, false):
				var source := part.get_active_material(0) as StandardMaterial3D
				if source != null and source.albedo_color.r > 0.2 and source.albedo_color.g > 0.15:
					var red := source.duplicate() as StandardMaterial3D
					red.albedo_color = Color("be4739")
					part.material_override = red
		return
	if kind == "hammer":
		box(parent, "HammerHead", Vector3(0.47, 0.24, 0.24), Vector3(0, 0.52, 0), Color("af7546"))
		cylinder(parent, "HammerShaft", 0.045, 0.72, Vector3(0, 0.08, 0), Color("d3a25f"))
		for side: float in [-1, 1]:
			box(parent, "HammerCap", Vector3(0.06, 0.26, 0.26), Vector3(side * 0.24, 0.52, 0), Color("6e5340"))
		return
	if ORIGINAL_PLANTS.has(kind):
		copy_original_plant(parent, kind)
		return
	if kind in StageCatalog.MUSHROOMS:
		mushroom(parent, kind)
		return
	match kind:
		"sunflower", "marigold":
			flower(parent, kind == "marigold")
		"cherry_bomb":
			for sign_value: float in [-1, 1]:
				sphere(parent, "Cherry", Vector3(0.66, 0.72, 0.66), Vector3(0, 0.38, sign_value * 0.32), Color("d83f3c"))
				var twig := cylinder(parent, "Twig", 0.037, 0.55, Vector3(0, 0.91, sign_value * 0.18), Color("699846"))
				twig.rotation.x = sign_value * 0.4
			eyes(parent, Vector3(0.31, 0.45, 0), 0.36)
			cylinder(parent, "Fuse", 0.025, 0.28, Vector3(0, 1.27, 0), Color("695033"))
			sphere(parent, "Spark", Vector3.ONE * 0.14, Vector3(0, 1.45, 0), Color("ffc337"))
		"potato_mine":
			sphere(parent, "Potato", Vector3(1.0, 0.50, 0.78), Vector3(0, 0.23, 0), Color("c79b65"))
			eyes(parent, Vector3(0.46, 0.24, 0))
			cylinder(parent, "Trigger", 0.055, 0.23, Vector3(0, 0.54, 0), Color("777c6b"))
			sphere(parent, "RedLight", Vector3(0.19, 0.15, 0.19), Vector3(0, 0.70, 0), Color("d83937"))
		"chomper":
			stem(parent)
			sphere(parent, "Jaw", Vector3(1.12, 0.43, 0.82), Vector3(0.15, 0.99, 0), Color("8d57ae"))
			sphere(parent, "UpperJaw", Vector3(1.16, 0.60, 0.84), Vector3(0.09, 1.45, 0), Color("b571c0"))
			for z: float in [-0.27, 0, 0.27]:
				cylinder(parent, "Tooth", 0.07, 0.22, Vector3(0.48, 1.24, z), Color("fff8db"), 0.0)
			eyes(parent, Vector3(0.43, 1.56, 0), 0.26)
		"grave_buster":
			box(parent, "GraveEater", Vector3(0.8, 0.65, 0.75), Vector3(0, 0.39, 0), Color("7c6a43"))
			for i in 7:
				var branch := cylinder(parent, "Root", 0.09, 0.55, Vector3(-0.25 + (i % 3) * 0.25, 0.65, (i / 3.0 - 1) * 0.25), Color("8d793e"), 0.02)
				branch.rotation.z = -0.4 + i * 0.12
			eyes(parent, Vector3(0.42, 0.48, 0))
		"lily_pad":
			sphere(parent, "Pad", Vector3(1.5, 0.10, 1.35), Vector3(0, 0.09, 0), Color("5a9d49"))
			box(parent, "Notch", Vector3(0.36, 0.035, 0.06), Vector3(0.58, 0.14, 0), Color("376c3c"))
		"squash":
			leaves(parent)
			sphere(parent, "Squash", Vector3(1.08, 1.35, 0.97), Vector3(0, 0.71, 0), Color("8bc55c"))
			eyes(parent, Vector3(0.51, 0.88, 0), 0.24)
			for z: float in [-0.23, 0.23]:
				var brow := box(parent, "Brow", Vector3(0.08, 0.07, 0.25), Vector3(0.52, 1.01, z), Color("426936"))
				brow.rotation.x = signf(z) * 0.25
		"tangle_kelp":
			for i in 7:
				var strand := cylinder(parent, "Kelp", 0.055, 0.5 + (i % 3) * 0.2, Vector3((i % 3 - 1) * 0.20, 0.4, (i / 3.0 - 1) * 0.19), Color("417e3c"), 0.018)
				strand.rotation.z = sin(i * 1.7) * 0.5
		"jalapeno":
			leaves(parent)
			var pepper := sphere(parent, "Pepper", Vector3(0.6, 1.35, 0.56), Vector3(0, 0.73, 0), Color("df4435"))
			pepper.rotation.z = -0.25
			cylinder(parent, "PepperStem", 0.06, 0.28, Vector3(0.15, 1.45, 0), Color("549642"))
			eyes(parent, Vector3(0.28, 0.96, 0))
		"spikeweed":
			sphere(parent, "Mat", Vector3(1.2, 0.20, 0.9), Vector3(0, 0.1, 0), Color("74614a"))
			for i in 9:
				cylinder(parent, "Spike", 0.085, 0.45, Vector3((i % 3 - 1) * 0.38, 0.3, (i / 3 - 1) * 0.28), Color("d9c89b"), 0.0)
		"torchwood":
			cylinder(parent, "Trunk", 0.39, 1.05, Vector3(0, 0.53, 0), Color("93623c"), 0.30)
			eyes(parent, Vector3(0.38, 0.63, 0))
			for i in 5:
				sphere(parent, "Flame", Vector3(0.28, 0.62 + (i % 2) * 0.18, 0.28), Vector3(sin(i * 2.4) * 0.18, 1.2, cos(i * 2.4) * 0.18), Color("ffab36"))
		"plantern":
			stem(parent, 0.25)
			box(parent, "Lamp", Vector3(0.57, 0.68, 0.57), Vector3(0, 0.67, 0), Color("ebda67")).material_override = material(Color("ffdd73"), true)
			for x: float in [-0.32, 0.32]:
				for z: float in [-0.32, 0.32]:
					cylinder(parent, "LampFrame", 0.035, 0.85, Vector3(x, 0.67, z), Color("416b44"))
			cylinder(parent, "LampRoof", 0.50, 0.30, Vector3(0, 1.13, 0), Color("427b45"), 0.0)
			var light := OmniLight3D.new()
			light.position.y = 0.7
			light.light_color = Color("ffdc79")
			light.light_energy = 1.4
			light.omni_range = 5.0
			parent.add_child(light)
		"cactus":
			leaves(parent)
			cylinder(parent, "CactusBody", 0.25, 1.32, Vector3(0, 0.71, 0), Color("70a951"))
			sphere(parent, "CactusTop", Vector3(0.50, 0.50, 0.50), Vector3(0, 1.37, 0), Color("70a951"))
			for z: float in [-0.45, 0.45]:
				var arm := cylinder(parent, "CactusArm", 0.11, 0.65, Vector3(0, 0.78, z), Color("5e9747"))
				arm.rotation.x = signf(z) * 0.6
			for i in 12:
				var thorn := cylinder(parent, "Thorn", 0.025, 0.12, Vector3(cos(i) * 0.25, 0.32 + (i % 4) * 0.3, sin(i) * 0.25), Color("f2dfab"), 0.0)
				thorn.rotation.z = PI * 0.5
			eyes(parent, Vector3(0.255, 1.04, 0), 0.13)
		"blover":
			stem(parent, 0.55)
			for i in 4:
				var angle := i * PI * 0.5
				sphere(parent, "CloverLeaf", Vector3(0.12, 0.60, 0.60), Vector3(0, 0.95 + cos(angle) * 0.25, sin(angle) * 0.25), Color("79b65c"))
			eyes(parent, Vector3(0.1, 0.97, 0))
		"split_pea":
			copy_original_plant(parent, "peashooter")
			var source := (load("res://scenes/plants/peashooter.tscn") as PackedScene).instantiate()
			var head := source.get_node("Head") as Node3D
			source.remove_child(head)
			head.owner = null
			head.rotation.y = PI
			head.position.x = -0.38
			head.scale *= 0.85
			parent.add_child(head)
			source.free()
		"starfruit":
			stem(parent, 0.30)
			for i in 5:
				var angle := -PI * 0.5 + i * TAU / 5.0
				var point := cylinder(parent, "StarPoint", 0.25, 0.65, Vector3(0, 0.77 + cos(angle) * 0.34, sin(angle) * 0.34), Color("efcf4e"), 0.0)
				point.rotation.x = -angle
			sphere(parent, "StarCenter", Vector3(0.35, 0.66, 0.66), Vector3(0, 0.77, 0), Color("ffe779"))
			eyes(parent, Vector3(0.18, 0.86, 0))
		"pumpkin":
			for i in 10:
				var angle := i * TAU / 10.0
				sphere(parent, "PumpkinRib", Vector3(0.42, 0.69, 0.42), Vector3(cos(angle) * 0.41, 0.36, sin(angle) * 0.41), Color("dd8a36"))
			ring(parent, "PumpkinRim", 0.46, 0.08, Vector3(0, 0.69, 0), Color("f7ac41"))
			eyes(parent, Vector3(0.63, 0.39, 0), 0.27)
		"cabbage_pult", "kernel_pult", "melon_pult":
			pult(parent, kind)
		"flower_pot":
			cylinder(parent, "Pot", 0.33, 0.52, Vector3(0, 0.28, 0), Color("b26b46"), 0.49)
			cylinder(parent, "Soil", 0.43, 0.04, Vector3(0, 0.56, 0), Color("594730"))
			ring(parent, "PotLip", 0.46, 0.07, Vector3(0, 0.57, 0), Color("d78b5c"))
			eyes(parent, Vector3(0.40, 0.34, 0), 0.14)
		"coffee_bean":
			var bean := sphere(parent, "CoffeeBean", Vector3(0.84, 0.66, 0.58), Vector3(0, 0.45, 0), Color("885337"))
			bean.rotation.z = 0.4
			box(parent, "BeanSeam", Vector3(0.018, 0.44, 0.027), Vector3(0.38, 0.47, 0), Color("4e3429"))
			eyes(parent, Vector3(0.40, 0.50, 0), 0.13)
		"garlic":
			for z: float in [-0.24, 0.0, 0.24]:
				sphere(parent, "GarlicClove", Vector3(0.70, 0.88, 0.50), Vector3(0, 0.46, z), Color("f1e7bc"))
			cylinder(parent, "GarlicTip", 0.14, 0.44, Vector3(0, 0.95, 0), Color("e8dfba"), 0.02)
			eyes(parent, Vector3(0.35, 0.60, 0))
		"umbrella_leaf":
			stem(parent)
			for i in 6:
				var angle := i * TAU / 6.0
				var leaf := sphere(parent, "UmbrellaLeaf", Vector3(0.91, 0.13, 0.56), Vector3(cos(angle) * 0.36, 1.05, sin(angle) * 0.36), Color("63a849"))
				leaf.rotation.y = -angle
			eyes(parent, Vector3(0.42, 1.11, 0))


static func flower(parent: Node3D, orange: bool) -> void:
	stem(parent)
	for i in 12:
		var angle := i * TAU / 12.0
		var petal := sphere(parent, "Petal", Vector3(0.15, 0.56, 0.28), Vector3(0, 1.21 + cos(angle) * 0.46, sin(angle) * 0.46), Color("e79336") if orange else Color("f1ca48"))
		petal.rotation.x = -angle
	var center := Vector3(0.13, 1.21, 0)
	sphere(parent, "FlowerFace", Vector3(0.28, 0.69, 0.69), center, Color("d0953d") if orange else Color("a87839"))
	eyes(parent, center + Vector3(0.145, 0.06, 0))
	var mouth := ring(parent, "Smile", 0.11, 0.012, center + Vector3(0.15, -0.13, 0), Color("533c28"))
	mouth.rotation.z = PI * 0.5


static func mushroom(parent: Node3D, kind: String) -> void:
	var cap_color := Color("b897ba")
	var width := 1.0
	var height := 0.62
	match kind:
		"sun_shroom": cap_color = Color("e6ce58"); width = 0.74
		"fume_shroom": cap_color = Color("9b72aa"); width = 1.35; height = 0.9
		"hypno_shroom": cap_color = Color("dd69bb")
		"scaredy_shroom": cap_color = Color("d2ad95"); height = 1.18; width = 0.85
		"ice_shroom": cap_color = Color("87cbdf"); width = 1.10
		"doom_shroom": cap_color = Color("5b477a"); width = 1.45; height = 0.85
		"sea_shroom": cap_color = Color("66b7bc"); width = 0.94
		"magnet_shroom": cap_color = Color("a7576b"); width = 0.78
	cylinder(parent, "MushroomStem", width * 0.20, height * 0.7, Vector3(0, height * 0.35, 0), Color("e8dac7"))
	sphere(parent, "MushroomCap", Vector3(width, 0.42, width), Vector3(0, height, 0), cap_color)
	eyes(parent, Vector3(width * 0.22, height * 0.56, 0), width * 0.14)
	for i in 7:
		var angle := i * TAU / 7.0
		sphere(parent, "CapSpot", Vector3(0.14, 0.038, 0.14), Vector3(cos(angle) * width * 0.27, height + 0.17, sin(angle) * width * 0.27), cap_color.lightened(0.35))
	if kind in ["puff_shroom", "sea_shroom", "fume_shroom", "scaredy_shroom"]:
		var tube := cylinder(parent, "SporeMouth", width * 0.13, 0.27, Vector3(width * 0.27, height * 0.48, 0), cap_color)
		tube.rotation.z = PI * 0.5
	if kind == "hypno_shroom":
		for i in 3:
			ring(parent, "HypnoRing", 0.13 + i * 0.10, 0.025, Vector3(0, height + 0.19, 0), Color("78d8ba") if i % 2 else Color("f7d98c"))
	if kind == "ice_shroom":
		for i in 6:
			var crystal := cylinder(parent, "Crystal", 0.075, 0.48, Vector3(cos(i) * 0.25, height + 0.23, sin(i) * 0.25), Color("b9eff7"), 0.0)
			crystal.rotation.z = sin(i) * 0.65
	if kind == "magnet_shroom":
		box(parent, "MagnetBase", Vector3(0.14, 0.11, 0.47), Vector3(0, height + 0.12, 0), Color("cc4b56"))
		for z: float in [-0.20, 0.20]:
			box(parent, "MagnetArm", Vector3(0.14, 0.35, 0.11), Vector3(0, height + 0.30, z), Color("cc4b56"))
			box(parent, "MagnetTip", Vector3(0.14, 0.10, 0.11), Vector3(0, height + 0.52, z), Color("d6dbd4"))


static func pult(parent: Node3D, kind: String) -> void:
	leaves(parent)
	sphere(parent, "PultBase", Vector3(0.75, 0.47, 0.74), Vector3(0, 0.29, 0), Color("658d41"))
	var arm := cylinder(parent, "ThrowingArm", 0.075, 0.93, Vector3(0.12, 0.65, 0), Color("6c9445"))
	arm.rotation.z = -0.65
	var at := Vector3(0.42, 1.01, 0)
	if kind == "cabbage_pult":
		for i in 6:
			var angle := i * TAU / 6.0
			sphere(parent, "CabbageLeaf", Vector3(0.49, 0.53, 0.40), at + Vector3(cos(angle) * 0.10, 0, sin(angle) * 0.10), Color("91c164") if i % 2 else Color("78ad53"))
	elif kind == "kernel_pult":
		sphere(parent, "CornCob", Vector3(0.43, 0.77, 0.43), at, Color("eaca57"))
		for r in 5:
			for c in 6:
				var angle := c * TAU / 6.0
				sphere(parent, "Kernel", Vector3.ONE * 0.12, at + Vector3(cos(angle) * 0.19, -0.24 + r * 0.12, sin(angle) * 0.19), Color("ffdd64"))
		box(parent, "Butter", Vector3(0.28, 0.10, 0.22), Vector3(-0.16, 0.54, 0), Color("ffe9a0"))
	else:
		sphere(parent, "Watermelon", Vector3(0.91, 0.64, 0.68), at, Color("578b45"))
		for i in 7:
			var stripe := ring(parent, "MelonStripe", 0.28, 0.018, at + Vector3(-0.30 + i * 0.10, 0, 0), Color("9cb75c"))
			stripe.rotation.z = PI * 0.5
	eyes(parent, Vector3(0.32, 0.35, 0), 0.20)


static func clothes(visuals: Node3D, color: Color) -> void:
	for item: MeshInstance3D in visuals.find_children("*", "MeshInstance3D", true, false):
		if "Jacket" in item.name or "Sleeve" in item.name or "Jeans" in item.name:
			item.material_override = material(color)


static func enemy(actor: Node3D, kind: String) -> Node3D:
	var visuals := actor.get_node("Visuals") as Node3D
	var props := Node3D.new()
	props.name = "StageTraits"
	visuals.add_child(props)
	match kind:
		"flag_zombie":
			cylinder(props, "FlagPole", 0.025, 2.0, Vector3(0.45, 1.10, -0.35), Color("79583d"))
			box(props, "Flag", Vector3(0.62, 0.42, 0.035), Vector3(0.75, 1.90, -0.35), Color("c85049"))
		"screen_door_zombie":
			box(props, "Shield", Vector3(0.90, 1.55, 0.08), Vector3(0, 0.92, -0.70), Color("85968b"))
			for i in 7:
				box(props, "DoorMesh", Vector3(0.82, 0.014, 0.02), Vector3(0, 0.37 + i * 0.18, -0.752), Color("bfc4b9"))
			for x: float in [-0.30, 0, 0.30]:
				box(props, "DoorBar", Vector3(0.015, 1.35, 0.02), Vector3(x, 0.94, -0.752), Color("bfc4b9"))
		"football_zombie":
			clothes(visuals, Color("b74443"))
			sphere(props, "Helmet", Vector3(0.89, 0.72, 0.88), Vector3(0, 1.64, 0.04), Color("ba4947"))
			box(props, "HelmetGrille", Vector3(0.72, 0.13, 0.08), Vector3(0, 1.47, -0.45), Color("c6ccc9"))
			box(props, "ShoulderPads", Vector3(0.95, 0.22, 0.50), Vector3(0, 1.20, 0), Color("cc6660"))
		"dancing_zombie", "backup_dancer":
			clothes(visuals, Color("f096aa") if kind == "dancing_zombie" else Color("b86266"))
			if kind == "dancing_zombie":
				sphere(props, "Afro", Vector3(0.94, 0.62, 0.79), Vector3(0, 1.90, 0), Color("573d30"))
				box(props, "Sunglasses", Vector3(0.51, 0.09, 0.045), Vector3(0, 1.63, -0.38), Color("293b36"))
		"ducky_tube_zombie", "dolphin_rider":
			if kind == "ducky_tube_zombie":
				ring(props, "SwimRing", 0.59, 0.15, Vector3(0, 0.62, 0), Color("ecc759"))
				sphere(props, "Duck", Vector3(0.34, 0.39, 0.34), Vector3(0, 0.91, -0.55), Color("f4d56c"))
				box(props, "DuckBeak", Vector3(0.18, 0.09, 0.20), Vector3(0, 0.89, -0.76), Color("de8b43"))
			else:
				sphere(props, "Dolphin", Vector3(0.64, 0.54, 1.72), Vector3(0, 0.33, -0.30), Color("8cbbcd"))
				sphere(props, "DolphinNose", Vector3(0.21, 0.21, 0.62), Vector3(0, 0.40, -1.15), Color("8cbbcd"))
				var fin := cylinder(props, "Fin", 0.18, 0.43, Vector3(0, 0.72, -0.28), Color("69a1b6"), 0.0)
				fin.rotation.x = -0.4
		"snorkel_zombie":
			box(props, "Mask", Vector3(0.53, 0.24, 0.13), Vector3(0, 1.64, -0.38), Color("779fbc"))
			cylinder(props, "Snorkel", 0.045, 0.65, Vector3(0.32, 1.85, -0.31), Color("dcb74a"))
			for x: float in [-0.18, 0.18]:
				box(props, "Flipper", Vector3(0.27, 0.065, 0.58), Vector3(x, 0.07, -0.36), Color("aeb966"))
		"zomboni", "catapult_zombie":
			vehicle(props, kind == "catapult_zombie")
		"bobsled_team":
			clothes(visuals, Color("6777ad"))
			if not actor.get_meta("summoned", false):
				box(props, "Sled", Vector3(0.95, 0.22, 3.25), Vector3(0, 0.20, 0.92), Color("8eabc8"))
				for x: float in [-0.44, 0.44]:
					box(props, "Runner", Vector3(0.065, 0.07, 3.45), Vector3(x, 0.06, 0.92), Color("c0c9cd"))
		"jack_in_the_box":
			clothes(visuals, Color("9672ad"))
			box(props, "JackBox", Vector3(0.47, 0.42, 0.38), Vector3(0, 0.98, -0.65), Color("d18a46"))
			box(props, "BoxStar", Vector3(0.16, 0.16, 0.025), Vector3(0, 0.98, -0.86), Color("e9dc77"))
			for i in 3:
				var cone := cylinder(props, "JesterHat", 0.14, 0.5, Vector3(-0.28 + i * 0.28, 1.95, 0), Color("ce6658") if i % 2 else Color("dfb34e"), 0)
				cone.rotation.z = (i - 1) * 0.45
		"balloon_zombie":
			sphere(props, "Balloon", Vector3(1.03, 1.35, 1.03), Vector3(0, 3.48, 0.12), Color("d56361"))
			cylinder(props, "BalloonString", 0.012, 1.86, Vector3(0.03, 2.12, 0.1), Color("e5dfc8"))
		"digger_zombie":
			cylinder(props, "MiningHelmet", 0.38, 0.22, Vector3(0, 1.89, 0), Color("d4b447"))
			sphere(props, "HeadLamp", Vector3(0.15, 0.15, 0.08), Vector3(0, 1.86, -0.38), Color("faf3b2"))
			var handle := cylinder(props, "PickHandle", 0.035, 1.20, Vector3(0.42, 0.86, -0.40), Color("7d543b"))
			handle.rotation.z = 0.65
			box(props, "PickHead", Vector3(0.64, 0.10, 0.12), Vector3(0.10, 1.35, -0.40), Color("a3aaa3"))
		"pogo_zombie":
			cylinder(props, "PogoPole", 0.05, 1.65, Vector3(0, 0.88, -0.52), Color("ba8164"))
			box(props, "PogoStep", Vector3(0.68, 0.07, 0.15), Vector3(0, 0.28, -0.52), Color("898e83"))
		"yeti_zombie":
			clothes(visuals, Color("e7e8dd"))
			for p: Vector3 in [Vector3(-0.35, 1.10, 0), Vector3(0.35, 1.10, 0), Vector3(0, 1.87, 0.13)]:
				sphere(props, "Fur", Vector3.ONE * 0.62, p, Color("eeeede"))
		"bungee_zombie":
			clothes(visuals, Color("b77552"))
			cylinder(props, "BungeeRope", 0.024, 4.2, Vector3(0, 3.78, 0.07), Color("d9c898"))
			box(props, "Harness", Vector3(0.66, 0.07, 0.43), Vector3(0, 1.14, 0), Color("6a5440"))
		"ladder_zombie":
			for x: float in [-0.32, 0.32]:
				box(props, "LadderSide", Vector3(0.07, 1.85, 0.08), Vector3(x, 0.98, -0.68), Color("d0b889"))
			for i in 7:
				box(props, "LadderRung", Vector3(0.67, 0.055, 0.07), Vector3(0, 0.27 + i * 0.23, -0.68), Color("d0b889"))
		"gargantuar":
			visuals.scale = Vector3.ONE * 2.0
			clothes(visuals, Color("706e57"))
			var club := cylinder(props, "Club", 0.13, 1.75, Vector3(0.52, 0.84, -0.60), Color("856043"))
			club.rotation.x = 0.30
			box(props, "ClubHead", Vector3(0.47, 0.42, 0.45), Vector3(0.52, 1.62, -0.85), Color("927047"))
			sphere(props, "CarriedImp", Vector3(0.42, 0.42, 0.42), Vector3(0, 1.18, 0.48), Color("87a276"))
		"imp":
			visuals.scale = Vector3.ONE * 0.58
			clothes(visuals, Color("ae6a54"))
		"zomboss":
			for child: Node3D in [visuals.get_node("Torso"), visuals.get_node("Arms"), visuals.get_node("Legs"), visuals.get_node("Head")]:
				child.hide()
			box(props, "MechBody", Vector3(2.25, 2.0, 1.50), Vector3(0, 2.06, 0), Color("688c9d"))
			sphere(props, "MechHead", Vector3(2.05, 1.20, 1.46), Vector3(0, 3.56, -0.08), Color("829eab"))
			box(props, "Cockpit", Vector3(1.17, 0.53, 0.10), Vector3(0, 3.45, -0.77), Color("4a646a"))
			sphere(props, "Pilot", Vector3(0.48, 0.40, 0.25), Vector3(0, 3.52, -0.85), Color("8ca281"))
			for x: float in [-1.10, 1.10]:
				cylinder(props, "Piston", 0.21, 1.52, Vector3(x, 0.95, 0), Color("bbc2bd"))
				box(props, "MechFoot", Vector3(0.79, 0.29, 1.17), Vector3(x, 0.19, -0.19), Color("668393"))
				box(props, "MechArm", Vector3(0.65, 1.13, 0.61), Vector3(x * 1.24, 2.23, -0.10), Color("7798a7"))
	return props


static func vehicle(parent: Node3D, catapult: bool) -> void:
	box(parent, "VehicleBody", Vector3(1.3, 0.66, 1.90), Vector3(0, 0.55, -0.30), Color("a97554") if catapult else Color("b5c7cf"))
	for x: float in [-0.65, 0.65]:
		for z: float in [-0.86, 0.38]:
			var wheel := cylinder(parent, "Wheel", 0.26, 0.14, Vector3(x, 0.23, z), Color("384742"))
			wheel.rotation.z = PI * 0.5
	if catapult:
		var arm := cylinder(parent, "CatapultArm", 0.065, 1.85, Vector3(0, 1.25, 0.08), Color("917045"))
		arm.rotation.x = 0.45
		sphere(parent, "Basketball", Vector3.ONE * 0.36, Vector3(0, 2.11, 0.43), Color("d48543"))
	else:
		box(parent, "IceBlade", Vector3(1.50, 0.14, 0.20), Vector3(0, 0.16, -1.24), Color("7baac0"))
		box(parent, "Windshield", Vector3(1.12, 0.41, 0.07), Vector3(0, 1.13, -0.82), Color("8bc5d2"))
