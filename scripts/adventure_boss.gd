class_name AdventureBoss
extends AdventureZombie
## Finite boss life; exposes its head, summons, launches counterable balls and attacks the roof.

var exposed: bool = false
var head_remaining: float = 0.0
var head_wait: float = 3.0
var attack_remaining: float = 6.0
var attack_count: int = 0


func _ready() -> void:
	super._ready()
	attack_remaining = float(stage.settings.boss_attack_interval)
	head_wait = 3.0
	StageModels.label(self, "僵王博士", Vector3.UP * 5.1, Color("ffd994"))


func receive_hit(amount: int, direction: Vector3, bypass_shield: bool = false, burn: bool = false) -> void:
	if exposed:
		super.receive_hit(amount, direction, bypass_shield, burn)


func is_hidden_target() -> bool:
	return not exposed


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_update_slow(delta)
	_update_hit_effect(delta)
	if _freeze_remaining > 0:
		_freeze_remaining = maxf(0, _freeze_remaining - delta)
		return
	if exposed:
		head_remaining -= delta
		if head_remaining <= 0:
			exposed = false
			head_wait = float(stage.settings.boss_head_interval)
			stage._notice("僵王收起了头，准备下一轮攻击。")
	else:
		head_wait -= delta
		if head_wait <= 0:
			exposed = true
			head_remaining = float(stage.settings.boss_head_duration)
			stage._notice("僵王伸头！投手集中攻击！", 5)
	_visuals.position.y = _visuals_rest.origin.y + (0 if exposed else 1.5)
	attack_remaining -= delta
	if attack_remaining <= 0:
		attack_remaining += float(stage.settings.boss_attack_interval)
		attack()


func attack() -> void:
	attack_count += 1
	var row: int = stage._random.randi_range(0, 4)
	match attack_count % 6:
		1, 2:
			var roster := AdventureLevels.BOSS_SUMMONS
			var kind: String = roster[stage._random.randi_range(0, mini(roster.size() - 1, attack_count / 2 + 2))]
			if stage.hostile_enemies().size() < 18:
				stage.spawn_enemy(kind, row)
		3:
			var ball := AdventureBossBall.new()
			ball.stage = stage
			ball.row = row
			ball.fire = (attack_count / 6) % 2 == 0
			ball.position = stage.lawn.cell_to_local(row, 8)
			stage.projectiles.add_child(ball)
			stage._notice("%s球来袭！用%s消除。" % ["火" if ball.fire else "冰", "寒冰菇" if ball.fire else "同路火爆辣椒"], 5)
		4:
			for lane in [row, (row + 2) % 5]:
				stage.spawn_enemy("bungee_zombie", lane)
		5:
			for column in [7, 8]:
				stage.world_rules.clear_cell(Vector2i(column, row))
			stage.effect(stage.lawn.cell_to_world(row, 7), Color("b89b7c"), 1.8)
			stage._notice("僵王踩踏了前排！", 3)
		0:
			var column: int = stage._random.randi_range(2, 6)
			for lane in range(maxi(0, row - 1), mini(5, row + 2)):
				for at in range(maxi(0, column - 1), mini(9, column + 2)):
					stage.world_rules.clear_cell(Vector2i(at, lane))
			stage.effect(stage.lawn.cell_to_world(row, column), Color("b98971"), 3.2)
			stage._notice("僵王砸下房车！补回花盆和防线。", 5)
