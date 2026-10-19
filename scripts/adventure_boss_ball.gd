class_name AdventureBossBall
extends Node3D

var stage: AdventureBoard
var row: int = 0
var fire: bool = true


func _ready() -> void:
	StageModels.sphere(self, "BossBall", Vector3.ONE * 1.55, Vector3.UP * 0.8, Color("f39b43") if fire else Color("9edbe9"))
	StageModels.sphere(self, "Core", Vector3.ONE, Vector3.UP * 0.8, Color("ffe8ad") if fire else Color("e1faff"))


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion() or stage.state != AdventureBoard.State.PLAYING:
		return
	global_position.x -= float(stage.settings.boss_ball_speed) * delta
	global_position.y = stage.lawn.surface_at(global_position)
	rotate_z(delta * 2)
	var cell := stage.lawn.world_to_cell(global_position)
	if cell.x >= 0:
		stage.world_rules.clear_cell(cell)
	if global_position.x < stage.lawn.cell_to_world(row, 0).x - 2.1:
		stage._notice("僵王的%s球进入了房子！" % ("火" if fire else "冰"))
		stage._finish(false)

