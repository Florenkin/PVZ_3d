extends SceneTree
## Capture actual rendered stage scenes; run without --headless.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var switcher := load("res://scenes/adventure.tscn").instantiate() as StageSwitcher
	root.add_child(switcher)
	for number in range(1, 6):
		switcher.switch_stage(number)
		var demo := switcher.current_demo as StageDemo
		demo._set_overview(true)
		for actor: Node in demo.get_node("Plants").get_children() + demo.get_node("Enemies").get_children():
			actor.set_physics_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://artifacts/stage_%d.png" % number)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if root.get_texture().get_image().save_png(path) != OK:
			quit(1)
			return
		print("Stage capture: " + path)
		if number == 5:
			demo._set_sidebar(true)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/stage_roster.png"))
	switcher.queue_free()
	for frame in 10:
		await process_frame
		await RenderingServer.frame_post_draw
	quit()
