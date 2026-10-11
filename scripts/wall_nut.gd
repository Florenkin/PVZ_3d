class_name WallNut
extends Node3D
## A separate defensive plant with a collider that does not block friendly peas.


func _enter_tree() -> void:
	GameConfiguration.current().apply_entity(self)


func _ready() -> void:
	add_to_group("vaultable_plants")
