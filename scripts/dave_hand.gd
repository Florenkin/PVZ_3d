class_name DaveHand
extends Node3D
## One right hand for plants and tools; the same shovel is stowed on Dave's back.

var hand: Node3D
var back: Node3D
var shovel: Node3D
var held_plant: Node3D
var _dave: CrazyDave
var _shovel_unlocked: bool = false
var _age: float = 0.0
var _swing: float = 0.0


func configure(dave: CrazyDave, shovel_unlocked: bool) -> void:
	_dave = dave
	_shovel_unlocked = shovel_unlocked


func _ready() -> void:
	hand = Node3D.new()
	hand.name = "RightHand"
	_dave.camera.add_child(hand)
	StageModels.sphere(hand, "Palm", Vector3(0.18, 0.12, 0.20), Vector3(0, 0, 0), Color("efd0a0"))
	StageModels.sphere(hand, "Thumb", Vector3(0.07, 0.08, 0.15), Vector3(-0.09, 0.035, -0.025), Color("e8bd8e"))
	StageModels.box(hand, "Sleeve", Vector3(0.20, 0.18, 0.25), Vector3(0.04, -0.10, 0.17), Color("e6e7d0"))
	_set_render_layer(hand, 4)
	_dave.camera.cull_mask |= 4
	back = Node3D.new()
	back.name = "BackToolMount"
	_dave.get_node("Visuals").add_child(back)
	back.position = Vector3(0.16, 1.04, 0.28)
	back.rotation_degrees.z = -24
	shovel = Node3D.new()
	shovel.name = "Shovel"
	back.add_child(shovel)
	_build_shovel()
	equip("")
	_update_pose(0.0)


func equip(kind: String) -> void:
	_swing = 0.0
	if is_instance_valid(held_plant):
		held_plant.hide()
		held_plant.queue_free()
		held_plant = null
	if not kind.is_empty() and kind != "shovel":
		held_plant = Node3D.new()
		held_plant.name = "HeldPlant"
		hand.add_child(held_plant)
		StageModels.plant(held_plant, kind)
		held_plant.scale = Vector3.ONE * (0.75 if kind == "hammer" else 0.32)
		held_plant.position = Vector3(0, 0.065, -0.025)
		held_plant.rotation.y = 0.45
		_set_render_layer(held_plant, 4)
	var mount := hand if kind == "shovel" else back
	if shovel.get_parent() != mount:
		shovel.reparent(mount, false)
	shovel.position = Vector3(0, 0.12, -0.02) if kind == "shovel" else Vector3.ZERO
	shovel.rotation_degrees = Vector3(-12, -14, -18) if kind == "shovel" else Vector3.ZERO
	shovel.scale = Vector3.ONE * (0.75 if kind == "shovel" else 1.0)
	shovel.visible = _shovel_unlocked
	_set_render_layer(shovel, 4 if kind == "shovel" else 2)


func swing() -> void:
	_swing = 0.28


func _process(delta: float) -> void:
	_update_pose(delta)


func _update_pose(delta: float) -> void:
	_age += delta
	_swing = maxf(0.0, _swing - delta)
	hand.visible = _dave.first_person_active and not _dave.interface_open
	var movement := minf(Vector2(_dave.velocity.x, _dave.velocity.z).length(), 1.0)
	hand.position = Vector3(0.43, -0.34 + sin(_age * 8.0) * 0.012 * movement, -0.85)
	hand.rotation.x = deg_to_rad(sin(_swing / 0.28 * PI) * 28)


func _set_render_layer(model: Node3D, layer: int) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = layer
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_shovel() -> void:
	StageModels.box(shovel, "Blade", Vector3(0.30, 0.31, 0.055), Vector3(0, 0.48, 0), Color("bdc8cd"))
	StageModels.sphere(shovel, "BladeTip", Vector3(0.30, 0.15, 0.055), Vector3(0, 0.64, 0), Color("bdc8cd"))
	StageModels.box(shovel, "BladeRib", Vector3(0.035, 0.27, 0.072), Vector3(0, 0.47, 0), Color("e5eef0"))
	StageModels.cylinder(shovel, "Shaft", 0.033, 0.70, Vector3(0, -0.02, 0), Color("b77d42"))
	StageModels.cylinder(shovel, "Socket", 0.052, 0.16, Vector3(0, 0.29, 0), Color("899ba2"))
	for side: float in [-1, 1]:
		StageModels.box(shovel, "HandleSide", Vector3(0.045, 0.18, 0.055), Vector3(side * 0.095, -0.42, 0), Color("765332"))
	StageModels.box(shovel, "HandleGrip", Vector3(0.23, 0.052, 0.065), Vector3(0, -0.51, 0), Color("b77d42"))
	StageModels.box(shovel, "HandleNeck", Vector3(0.20, 0.035, 0.055), Vector3(0, -0.33, 0), Color("765332"))


func _exit_tree() -> void:
	if is_instance_valid(hand):
		hand.queue_free()
	if is_instance_valid(back):
		back.queue_free()
