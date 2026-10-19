extends Node3D
## A quiet, live 3D garden for the main menu, without demo combat or timers.

var _time: float = 0.0
var _flowers: Array[Node3D] = []


func _enter_tree() -> void:
	GameConfiguration.current().apply_scene(self)
	$LawnGrid.row_count_override = 3
	$LawnGrid.column_count_override = 5


func _ready() -> void:
	$LawnGrid.position = Vector3(4.0, 0, 0)
	$Camera3D.position = Vector3(17, 15, 24)
	$Camera3D.look_at(Vector3(0, 0, -0.5))
	$Camera3D.make_current()
	$House.position = Vector3(-7.8, 0.025, -2)
	for index in 4:
		var model := Node3D.new()
		model.name = "GardenPlant%d" % index
		$Decor.add_child(model)
		model.position = Vector3(3.0 + index % 2 * 3.2, 0.025, -1.8 + index / 2 * 3.6)
		model.scale = Vector3.ONE * 1.35
		StageModels.plant(model, AdventureLevels.PLANTS[index])
		_flowers.append(model)
	for index in 7:
		var fence := StageModels.box($Decor, "Picket", Vector3(0.3, 1.3, 0.12), Vector3(0.5 + index * 1.6, 0.5, -4.2), Color("e6dab8"))
		StageModels.cylinder(fence, "Point", 0.21, 0.3, Vector3(0, 0.8, 0), Color("e6dab8"), 0.0)
	StageModels.box($Decor, "FenceRail", Vector3(11, 0.12, 0.08), Vector3(5.3, 0.85, -4.2), Color("dac9a3"))
	StageModels.box($Decor, "FenceRail", Vector3(11, 0.12, 0.08), Vector3(5.3, 0.28, -4.2), Color("dac9a3"))


func _process(delta: float) -> void:
	_time += delta
	for index in _flowers.size():
		_flowers[index].rotation.z = sin(_time * 1.2 + index) * 0.035
