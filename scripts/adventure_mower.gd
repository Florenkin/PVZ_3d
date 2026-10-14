class_name AdventureMower
extends Node3D

var stage: Node3D
var row: int = 0
var active: bool = false
var spent: bool = false
var speed: float = 8.0


func _ready() -> void:
	StageModels.box(self, "Deck", Vector3(1.05, 0.37, 0.84), Vector3(0, 0.33, 0), Color("ac5144"))
	StageModels.box(self, "Engine", Vector3(0.48, 0.27, 0.44), Vector3(0, 0.63, 0), Color("d19b54"))
	for z: float in [-0.45, 0.45]:
		for x: float in [-0.33, 0.33]:
			var wheel := StageModels.cylinder(self, "Wheel", 0.20, 0.12, Vector3(x, 0.20, z), Color("354333"))
			wheel.rotation.x = PI * 0.5
		var handle := StageModels.cylinder(self, "Handle", 0.025, 1.2, Vector3(-0.50, 0.85, z * 0.7), Color("b3b5a2"))
		handle.rotation.z = -0.5
	StageModels.box(self, "Grip", Vector3(0.08, 0.08, 0.68), Vector3(-0.77, 1.39, 0), Color("3a4737"))


func trigger() -> void:
	if not spent:
		spent = true
		active = true


func _physics_process(delta: float) -> void:
	if not active:
		return
	var previous := global_position.x
	global_position.x += speed * delta
	for enemy: StageZombie in stage.live_enemies():
		if enemy.hypnotized or enemy.is_flying() or enemy.enemy_kind in ["zomboss", "bungee_zombie"]:
			continue
		if absf(enemy.global_position.z - global_position.z) < stage.lawn.cell_size * 0.40 and enemy.global_position.x >= previous - 1.0 and enemy.global_position.x <= global_position.x + 1.0:
			enemy.receive_hit(enemy.maximum_health, Vector3.RIGHT, true, true)
	global_position.y = stage.lawn.surface_at(global_position)
	if global_position.x > stage.lawn.cell_to_world(row, 8).x + stage.lawn.cell_size * 2:
		active = false
		hide()
