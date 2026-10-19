extends SceneTree
## Capture actual imported bone playback and three real demo combat states.

const OUTPUT := "res://assets/3D/imported_zombie/previews/"
const FRAMES := "res://artifacts/imported_zombie/frames/"


func _initialize() -> void:
	_capture.call_deferred()


func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _save(path: String) -> void:
	await _frame()
	assert(root.get_texture().get_image().save_png(path) == OK)


func _capture() -> void:
	create_timer(90.0).timeout.connect(func(): quit(1))
	DirAccess.make_dir_recursive_absolute(FRAMES)
	root.size = Vector2i(640, 800)
	root.msaa_3d = Viewport.MSAA_4X
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.15,.17,.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.8,.83,.85)
	environment.ambient_light_energy = .6
	var env_node := WorldEnvironment.new()
	env_node.environment = environment
	world.add_child(env_node)
	for params in [[Vector3(-3,5,-4),.8,Color(1,.94,.88)],[Vector3(4,3,-1),.35,Color(.85,.92,1)]]:
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.position = params[0]
		light.look_at(Vector3(0,.8,0))
		light.light_energy = params[1]
		light.light_color = params[2]
	var floor_object := MeshInstance3D.new()
	floor_object.mesh = PlaneMesh.new()
	floor_object.mesh.size = Vector2(200,200)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(.24,.27,.28)
	floor_material.roughness = .95
	floor_object.material_override = floor_material
	world.add_child(floor_object)
	var visual := DemoZombieVisual.new()
	visual.scale = Vector3.ONE * DemoZombieVisual.MODEL_HEIGHT
	visual.rotation.y = PI
	world.add_child(visual)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.7
	camera.position = Vector3(2.8,2.1,-4.5)
	camera.look_at(Vector3(0,.85,.35))
	camera.current = true
	for clip: StringName in [&"Walk", &"Eat", &"Fall"]:
		visual.player.stop()
		visual.player.play(visual.clip_names[clip], 0.0)
		visual.player.speed_scale = 1
		visual.player.advance(0)
		var count := 22 if clip == &"Walk" else (24 if clip == &"Eat" else 37)
		for index in count:
			if index > 0:
				visual.player.advance(.05)
			await _save(FRAMES + String(clip).to_lower() + "_%03d.png" % index)
			if index == (count-1 if clip == &"Fall" else 6):
				await _save(OUTPUT + "godot_" + String(clip).to_lower() + ".png")
	root.remove_child(world)
	world.queue_free()
	await process_frame
	root.size = Vector2i(1280,800)
	var demo := load("res://scenes/stages/day.tscn").instantiate() as StageDemo
	demo.auto_respawn_enabled = false
	root.add_child(demo)
	demo._dave.set_physics_process(false)
	demo._sun_system._timer.stop()
	var actor: StageZombie
	for enemy: StageZombie in demo.get_node("Enemies").get_children():
		if enemy.enemy_kind == "zombie":
			actor = enemy
		else:
			enemy.set_physics_process(false)
	for plant: StagePlant in demo.get_node("Plants").get_children():
		plant.set_physics_process(false)
	actor.set_spawn(demo.lawn.cell_to_world(0,9),PI*.5)
	demo._set_overview(true)
	demo._orbit.default_size = 3.9
	demo._orbit.minimum_size = 2.0
	demo._orbit.default_yaw = -1.0
	demo._orbit.default_pitch = .24
	demo._orbit.distance = 8
	demo._orbit.target = actor.global_position + Vector3(0,.95,0)
	demo._orbit.reset_view()
	for i in 12:
		await physics_frame
	await _save(OUTPUT + "demo_walk.png")
	var victim := demo.get_node("Plants").get_child(0) as StagePlant
	victim.global_position = actor.global_position + Vector3.LEFT * .85
	victim.display_only = false
	for i in 18:
		await physics_frame
	await _save(OUTPUT + "demo_eat.png")
	actor.take_damage(actor.health,Vector3.RIGHT)
	for i in 116:
		await physics_frame
	await _save(OUTPUT + "demo_fall.png")
	print("CAPTURE PASSED: actual Walk/Eat/Fall skin frames and day-demo walk/bite/death screenshots")
	demo.queue_free()
	quit()
