class_name AdventureProgress
extends Node
## All levels are playable; save individual victories and migrate old prefix saves.

signal changed
const SAVE_PATH: String = "user://adventure_progress.json"
var _completed_levels: Array[int] = []
var _completed_prefix: int = 0
var completed_level: int:
	get:
		return _completed_prefix
	set(value):
		_completed_prefix = clampi(value, 0, AdventureLevels.LEVEL_COUNT)
		_completed_levels.assign(range(1, _completed_prefix + 1))
var memory_only: bool = false


static func current() -> AdventureProgress:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameProgress") as AdventureProgress


func _ready() -> void:
	load_progress()


func unlocked_level() -> int:
	return AdventureLevels.LEVEL_COUNT


func recommended_level() -> int:
	return mini(AdventureLevels.LEVEL_COUNT, _completed_prefix + 1)


func has_completed(number: int) -> bool:
	return number in _completed_levels


func completed_count() -> int:
	return _completed_levels.size()


func highest_completed_level() -> int:
	return _completed_levels[-1] if not _completed_levels.is_empty() else 0


func _update_prefix() -> void:
	_completed_levels.sort()
	_completed_prefix = 0
	while has_completed(_completed_prefix + 1):
		_completed_prefix += 1


func can_play(number: int) -> bool:
	return number >= 1 and number <= unlocked_level()


func complete(number: int) -> void:
	if not can_play(number) or has_completed(number):
		return
	_completed_levels.append(number)
	_update_prefix()
	changed.emit()
	if not memory_only:
		save_progress()


func load_progress(path: String = SAVE_PATH) -> void:
	completed_level = 0
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version", 0) != 1:
		return
	var value: Variant = data.get("completed_level", 0)
	if (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= AdventureLevels.LEVEL_COUNT:
		if not data.has("completed_levels"):
			completed_level = int(value)
			return
		if not data.completed_levels is Array:
			return
		var restored: Array[int] = []
		for number: Variant in data.completed_levels:
			if not (number is int or number is float) or not is_finite(float(number)) or float(number) != floor(float(number)) or number < 1 or number > AdventureLevels.LEVEL_COUNT:
				return
			if not int(number) in restored:
				restored.append(int(number))
		_completed_levels = restored
		_update_prefix()


func save_progress(path: String = SAVE_PATH) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("冒险进度暂时无法保存：" + error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "completed_level": completed_level, "completed_levels": _completed_levels}))
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error != OK:
		push_warning("冒险进度保存失败：" + error_string(error))
	return error
