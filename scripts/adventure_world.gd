class_name AdventureWorld
extends Node3D
## Terrain, layered planting and finite special challenges belong to the board.

var board: AdventureBoard
var bases: Dictionary = {}
var shells: Dictionary = {}
var ice: Dictionary = {}
var ice_models: Dictionary = {}
var vases: Dictionary = {}
var vase_group: int = 0
var waiting_group: bool = false
var fog: Node3D
var fog_clear_remaining: float = 0.0
var storm_remaining: float = 12.0
var flash_remaining: float = 0.0
var storm_light: DirectionalLight3D
var storm_light_energy: float = 0.0
var storm_light_color: Color
var boss: AdventureBoss
var coins: int = 0


func configure(owner_board: AdventureBoard) -> void:
	board = owner_board
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# The spawn area must meet the lawn at its own height, including the roof.
	var arrival_size := Vector3(board.lawn.cell_size * 3, 0.2, board.lawn.cell_size * board.lawn.row_count)
	var arrival_at := board.lawn.cell_to_local(2, 8) + Vector3(board.lawn.cell_size * 2, -0.1, 0)
	arrival_at.z = 0
	StageModels.box(self, "ArrivalTerrain", arrival_size, arrival_at, Color("b96342") if board.stage_number == 5 else Color("80b557"))
	for row in board.lawn.water_rows:
		StageModels.box(self, "ArrivalWater", Vector3(arrival_size.x, 0.025, board.lawn.cell_size), Vector3(arrival_at.x, arrival_at.y + 0.1, board.lawn.cell_to_local(row, 8).z), Color("5ab8c5"))
	var arrival := StaticBody3D.new()
	arrival.collision_layer = 1
	var arrival_shape := CollisionShape3D.new()
	var arrival_box := BoxShape3D.new()
	arrival_box.size = arrival_size
	arrival_shape.shape = arrival_box
	arrival.add_child(arrival_shape)
	arrival.position = arrival_at
	add_child(arrival)
	if board.stage_number == 5:
		StageModels.box(self, "RoofFascia", Vector3(board.lawn.cell_size * 9, 0.65, board.lawn.cell_size * 5), Vector3(0, -0.4, 0), Color("ba9c70"))
		for row in board.active_rows:
			for column in 3:
				board._create_plant("flower_pot", Vector2i(column, row))
	if board.stage_number == 4:
		fog = Node3D.new()
		fog.name = "Fog"
		add_child(fog)
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/materials/stage_fog.gdshader")
		var color := Color(0.77, 0.86, 0.87, float(GameConfiguration.current().section("stages").fog_opacity))
		material.set_shader_parameter("fog_color", color)
		for row in board.active_rows:
			for column in range(5, 9):
				var cloud := StageModels.sphere(fog, "FogCloud", Vector3(board.lawn.cell_size * 1.7, 2.2, board.lawn.cell_size * 1.7), board.lawn.cell_to_local(row, column) + Vector3.UP * 1.2, color)
				cloud.material_override = material
	storm_remaining = float(board.settings.storm_interval)
	if board.level_number == 40:
		storm_light = board.get_node("Sun") as DirectionalLight3D
		storm_light_energy = storm_light.light_energy
		storm_light_color = storm_light.light_color
		var rain := CPUParticles3D.new()
		rain.name = "StormRain"
		rain.amount = 180
		rain.lifetime = 1.5
		rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		rain.emission_box_extents = Vector3(board.lawn.cell_size * 4.5, 2, board.lawn.cell_size * 3)
		rain.position.y = 5
		rain.direction = Vector3(-0.15, -1, 0)
		rain.initial_velocity_min = 6
		rain.initial_velocity_max = 8
		rain.gravity = Vector3(0, -5, 0)
		var drop := BoxMesh.new()
		drop.size = Vector3(0.018, 0.38, 0.018)
		drop.material = StageModels.material(Color(0.7, 0.83, 0.94, 0.65))
		rain.mesh = drop
		rain.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(rain)
	if board.rules_mode == "vases":
		start_vase_group()
	elif board.rules_mode == "boss":
		boss = board.spawn_enemy("zomboss", 2) as AdventureBoss


func layer(kind: String) -> String:
	return "base" if kind in ["lily_pad", "flower_pot"] else ("shell" if kind == "pumpkin" else ("coffee" if kind == "coffee_bean" else "plant"))


func planting_error(kind: String, cell: Vector2i) -> String:
	if vases.has(cell):
		return "先砸开这个格子的罐子。"
	if ice.has(cell) and kind != "jalapeno":
		return "冰道尚未融化；火爆辣椒可清除。"
	var water := cell.y in board.lawn.water_rows
	if kind == "lily_pad":
		return "睡莲只能种在水里。" if not water else ("这里已有睡莲。" if bases.has(cell) or board._occupied.has(cell) else "")
	if kind == "flower_pot":
		return "花盆不能放在水里。" if water else ("这里已有植物或底座。" if bases.has(cell) or board._occupied.has(cell) else "")
	if kind in ["sea_shroom", "tangle_kelp"] and not water:
		return "这种植物只能直接种在水里。"
	if water and kind not in ["sea_shroom", "tangle_kelp"] and not bases.has(cell):
		return "先在水里放睡莲。"
	if water and kind in ["spikeweed", "potato_mine", "grave_buster"]:
		return "这种植物不能种在水路。"
	if board.stage_number == 5 and kind in ["spikeweed", "tangle_kelp", "lily_pad", "sea_shroom"]:
		return "这种植物不能种在屋顶。"
	if board.stage_number == 5 and not bases.has(cell):
		return "先放花盆，再种植物。"
	if kind == "pumpkin":
		return "这个格子已经有南瓜。" if shells.has(cell) else ""
	if kind == "coffee_bean":
		var plant := board._occupied.get(cell) as AdventurePlant
		return "咖啡豆必须放在睡眠蘑菇上。" if not is_instance_valid(plant) or not plant.sleeping else ""
	return "这个格子已经有植物了。" if board._occupied.has(cell) else ""


func register_plant(cell: Vector2i, plant: AdventurePlant) -> void:
	match layer(plant.plant_kind):
		"base": bases[cell] = plant
		"shell": shells[cell] = plant
		"coffee": pass
		_: board._occupied[cell] = plant


func remove_plant(cell: Vector2i, plant: AdventurePlant) -> void:
	if bases.get(cell) == plant:
		bases.erase(cell)
		for upper in [board._occupied.get(cell), shells.get(cell)]:
			if is_instance_valid(upper):
				upper._consume()
	elif shells.get(cell) == plant:
		shells.erase(cell)
	elif board._occupied.get(cell) == plant:
		board._occupied.erase(cell)


func shovel_target(cell: Vector2i) -> AdventurePlant:
	return board._occupied.get(cell, shells.get(cell, bases.get(cell))) as AdventurePlant


func clear_cell(cell: Vector2i) -> void:
	for plant in [shells.get(cell), board._occupied.get(cell), bases.get(cell)]:
		if is_instance_valid(plant):
			plant._consume()


func update(delta: float) -> void:
	for cell: Vector2i in ice.keys():
		ice[cell] -= delta
		if float(ice[cell]) <= 0:
			ice_models[cell].queue_free()
			ice_models.erase(cell)
			ice.erase(cell)
	fog_clear_remaining = maxf(0, fog_clear_remaining - delta)
	if is_instance_valid(fog):
		flash_remaining = maxf(0, flash_remaining - delta)
		if board.level_number == 40:
			storm_remaining -= delta
			if storm_remaining <= 0:
				storm_remaining += float(board.settings.storm_interval)
				flash_remaining = float(board.settings.storm_flash_duration)
				board.effect(board.lawn.cell_to_world(2, 6) + Vector3.UP * 3, Color.WHITE, 4)
			storm_light.light_energy = 2.2 if flash_remaining > 0 else storm_light_energy
			storm_light.light_color = Color("eef5ff") if flash_remaining > 0 else storm_light_color
		fog.visible = fog_clear_remaining <= 0 and flash_remaining <= 0
		for cloud: Node3D in fog.get_children():
			cloud.visible = true
			for plant: StagePlant in board.live_plants():
				if plant.plant_kind == "plantern" and absf(plant.global_position.x - cloud.global_position.x) <= board.lawn.cell_size * 2.5 and absf(plant.global_position.z - cloud.global_position.z) <= board.lawn.cell_size * 2.5:
					cloud.hide()
					break
	if board.rules_mode == "vases" and vases.is_empty() and board.hostile_enemies().is_empty() and not waiting_group:
		if vase_group == 3:
			board._finish(true)
		else:
			waiting_group = true
			board.state = AdventureBoard.State.PAUSED
			board._set_combat_processing(false)
			var column := board._overlay_column("第 %d 组完成" % vase_group, "下一组将重新布置罐子与防线。")
			GameUI.button(column, "继续第 %d 组" % (vase_group + 1), start_vase_group)
			GameUI.button(column, "返回主界面", func() -> void: board.menu_requested.emit())


func add_ice(cell: Vector2i) -> void:
	if not board.lawn.is_valid_cell(cell.y, cell.x) or cell.y in board.lawn.water_rows:
		return
	ice[cell] = float(board.settings.ice_lifetime)
	if not ice_models.has(cell):
		ice_models[cell] = StageModels.box(self, "IceTrack", Vector3.ONE * board.lawn.cell_size * Vector3(0.95, 0.015, 0.95), board.lawn.cell_to_local(cell.y, cell.x) + Vector3.UP * 0.04, Color("a3d3de"))


func clear_ice(row: int) -> void:
	for cell: Vector2i in ice.keys():
		if cell.y == row:
			ice_models[cell].queue_free()
			ice_models.erase(cell)
			ice.erase(cell)


func clear_fog(duration: float) -> void:
	fog_clear_remaining = maxf(fog_clear_remaining, duration)
	if is_instance_valid(fog):
		fog.hide()


func start_vase_group() -> void:
	board.state = AdventureBoard.State.PLAYING
	board._clear_overlay()
	board._set_combat_processing(true)
	for plant: StagePlant in board.live_plants():
		plant._consume()
	board.supply.clear()
	board.select_plant("")
	vase_group += 1
	waiting_group = false
	var contents: Array[String] = []
	var groups: Array = [
		{"peashooter": 5, "squash": 5, "zombie": 4, "buckethead_zombie": 1},
		{"peashooter": 4, "snow_pea": 5, "squash": 4, "zombie": 5, "buckethead_zombie": 1, "football_zombie": 1},
		{"peashooter": 5, "snow_pea": 5, "hypno_shroom": 5, "zombie": 6, "buckethead_zombie": 2, "dancing_zombie": 1, "jack_in_the_box": 1}
	]
	for kind: String in groups[vase_group - 1]:
		for index in int(groups[vase_group - 1][kind]):
			contents.append(kind)
	for index in range(contents.size() - 1, 0, -1):
		var other := board._random.randi_range(0, index)
		var value := contents[index]
		contents[index] = contents[other]
		contents[other] = value
	var green := 0 if vase_group == 1 else vase_group
	for index in contents.size():
		var cell := Vector2i(7 - vase_group + index / 5, index % 5)
		var node := Node3D.new()
		add_child(node)
		node.position = board.lawn.cell_to_local(cell.y, cell.x)
		var is_green := green > 0 and contents[index] in StageCatalog.PLANT_ORDER
		if is_green:
			green -= 1
		StageModels.cylinder(node, "Vase", 0.43, 1.15, Vector3.UP * 0.6, Color("87a850") if is_green else Color("9b8062"), 0.56)
		StageModels.cylinder(node, "Rim", 0.43, 0.12, Vector3.UP * 1.19, Color("d7c09a"), 0.48)
		var body := StaticBody3D.new()
		body.collision_layer = 512
		body.collision_mask = 16
		body.set_meta("adventure_vase", cell)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.5
		shape.height = 1.3
		collision.shape = shape
		collision.position.y = 0.65
		body.add_child(collision)
		node.add_child(body)
		vases[cell] = {"node": node, "kind": contents[index], "green": is_green}
	board._dave.collision_mask |= 512


func break_vase(cell: Vector2i) -> bool:
	if board.state != AdventureBoard.State.PLAYING or not vases.has(cell):
		return false
	var item: Dictionary = vases[cell]
	item.node.queue_free()
	vases.erase(cell)
	board._hand.swing()
	board.effect(board.lawn.cell_to_world(cell.y, cell.x), Color("d4bda0"), 0.7)
	if item.kind in StageCatalog.PLANT_ORDER:
		board.supply.append(item.kind)
		board._notice("获得植物卡：" + StageCatalog.plant_name(item.kind))
	else:
		var enemy := board.spawn_enemy(item.kind, cell.y)
		enemy.global_position = board.lawn.cell_to_world(cell.y, cell.x)
	return true


func counter_balls(kind: String, row: int) -> void:
	for projectile: Node in board.projectiles.get_children():
		if projectile is AdventureBossBall and ((kind == "ice_shroom" and projectile.fire) or (kind == "jalapeno" and not projectile.fire and projectile.row == row)):
			board.effect(projectile.global_position, Color("cfe9ec"), 1.0)
			projectile.queue_free()
