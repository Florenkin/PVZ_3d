extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	create_timer(30.0).timeout.connect(func(): quit(1))
	root.size = Vector2i(1050, 1400)
	root.msaa_3d = Viewport.MSAA_4X
	var world := Node3D.new()
	root.add_child(world)
	var asset := (load("res://conehead_zombie.glb") as PackedScene).instantiate()
	world.add_child(asset)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.25, .25, .24)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.65, .67, .70)
	environment.ambient_light_energy = .5
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	for setup in [[Vector3(-3, 5, 4), .85, Color(1, .94, .86)], [Vector3(3, 3, 4), .45, Color(.87, .93, 1)], [Vector3(1, 5, -3), .65, Color(1, .95, .88)]]:
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.position = setup[0]
		light.look_at(Vector3(0, 1.6, 0))
		light.light_energy = setup[1]
		light.light_color = setup[2]
		# Neutral material inspection; no shadow bias or map aliasing in the view.
		light.shadow_enabled = false
	var floor_object := MeshInstance3D.new()
	floor_object.mesh = PlaneMesh.new()
	floor_object.mesh.size = Vector2(200, 200)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(.35, .34, .32)
	floor_material.roughness = .92
	floor_object.material_override = floor_material
	world.add_child(floor_object)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.75
	camera.position = Vector3(3.5, 2.45, 7)
	camera.look_at(Vector3(.03, 1.65, 0))
	camera.current = true
	for frame in range(16):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null and image.get_width() == 1050)
	assert(image.save_png("res://godot_preview.png") == OK)
	print("CONEHEAD GODOT RENDER PASSED: 1050 x 1400, Compatibility")
	world.queue_free()
	quit()
