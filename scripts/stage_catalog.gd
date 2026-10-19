class_name StageCatalog
extends RefCounted
## Adventure rewards are cumulative; shop purchases are not automatic unlocks.

const PLANT_ORDER: Array[String] = [
	"peashooter", "sunflower", "cherry_bomb", "wall_nut", "potato_mine", "snow_pea", "chomper", "repeater", "puff_shroom",
	"sun_shroom", "fume_shroom", "grave_buster", "hypno_shroom", "scaredy_shroom", "ice_shroom", "doom_shroom", "lily_pad",
	"squash", "threepeater", "tangle_kelp", "jalapeno", "spikeweed", "torchwood", "tall_nut", "sea_shroom",
	"plantern", "cactus", "blover", "split_pea", "starfruit", "pumpkin", "magnet_shroom", "cabbage_pult",
	"flower_pot", "kernel_pult", "coffee_bean", "garlic", "umbrella_leaf", "marigold", "melon_pult"
]
const PLANT_COUNTS: Array[int] = [9, 17, 25, 33, 40]
const PLANT_NAMES: Array[String] = [
	"豌豆射手", "向日葵", "樱桃炸弹", "坚果", "土豆雷", "寒冰射手", "大嘴花", "双发射手", "小喷菇",
	"阳光菇", "大喷菇", "墓碑吞噬者", "魅惑菇", "胆小菇", "寒冰菇", "毁灭菇", "睡莲",
	"倭瓜", "三线射手", "缠绕海草", "火爆辣椒", "地刺", "火炬树桩", "高坚果", "海蘑菇",
	"路灯花", "仙人掌", "三叶草", "裂荚射手", "杨桃", "南瓜", "磁力菇", "卷心菜投手",
	"花盆", "玉米投手", "咖啡豆", "大蒜", "叶子保护伞", "金盏花", "西瓜投手"
]
const STAGE_NAMES: Array[String] = ["白天前院", "夜晚前院", "白天泳池", "夜晚浓雾", "屋顶"]
const STAGE_PATHS: Array[String] = [
	"res://scenes/stages/day.tscn", "res://scenes/stages/night.tscn", "res://scenes/stages/pool.tscn",
	"res://scenes/stages/fog.tscn", "res://scenes/stages/roof.tscn"
]
const ENEMY_NAMES: Dictionary = {
	"zombie": "普通僵尸", "flag_zombie": "旗帜僵尸", "conehead_zombie": "路障僵尸", "pole_vaulting_zombie": "撑杆僵尸", "buckethead_zombie": "铁桶僵尸",
	"newspaper_zombie": "读报僵尸", "screen_door_zombie": "铁门僵尸", "football_zombie": "橄榄球僵尸", "dancing_zombie": "舞王僵尸", "backup_dancer": "伴舞僵尸",
	"ducky_tube_zombie": "救生圈僵尸", "snorkel_zombie": "潜水僵尸", "zomboni": "冰车僵尸", "bobsled_team": "雪橇小队", "dolphin_rider": "海豚骑士",
	"jack_in_the_box": "小丑僵尸", "balloon_zombie": "气球僵尸", "digger_zombie": "矿工僵尸", "pogo_zombie": "跳跳僵尸", "yeti_zombie": "雪人（二周目）",
	"bungee_zombie": "蹦极僵尸", "ladder_zombie": "梯子僵尸", "catapult_zombie": "投石车僵尸", "gargantuar": "巨人僵尸", "imp": "小鬼僵尸", "zomboss": "僵王机甲"
}
const ENEMIES: Array = [
	["zombie", "flag_zombie", "conehead_zombie", "pole_vaulting_zombie", "buckethead_zombie"],
	["zombie", "flag_zombie", "conehead_zombie", "pole_vaulting_zombie", "buckethead_zombie", "newspaper_zombie", "screen_door_zombie", "football_zombie", "dancing_zombie", "backup_dancer"],
	["zombie", "flag_zombie", "conehead_zombie", "pole_vaulting_zombie", "buckethead_zombie", "newspaper_zombie", "football_zombie", "ducky_tube_zombie", "snorkel_zombie", "zomboni", "bobsled_team", "dolphin_rider"],
	["zombie", "flag_zombie", "conehead_zombie", "buckethead_zombie", "football_zombie", "ducky_tube_zombie", "dolphin_rider", "jack_in_the_box", "balloon_zombie", "digger_zombie", "pogo_zombie", "dancing_zombie", "backup_dancer", "yeti_zombie"],
	["zombie", "flag_zombie", "conehead_zombie", "pole_vaulting_zombie", "buckethead_zombie", "newspaper_zombie", "screen_door_zombie", "football_zombie", "jack_in_the_box", "pogo_zombie", "bungee_zombie", "ladder_zombie", "catapult_zombie", "gargantuar", "imp", "zomboni", "zomboss"]
]
const AQUATIC: Array[String] = ["lily_pad", "tangle_kelp", "sea_shroom"]
const WATER_ENEMIES: Array[String] = ["ducky_tube_zombie", "snorkel_zombie", "dolphin_rider"]
const MUSHROOMS: Array[String] = ["puff_shroom", "sun_shroom", "fume_shroom", "hypno_shroom", "scaredy_shroom", "ice_shroom", "doom_shroom", "sea_shroom", "magnet_shroom"]


static func plants_for_stage(number: int) -> Array[String]:
	return PLANT_ORDER.slice(0, PLANT_COUNTS[clampi(number, 1, 5) - 1])


static func enemies_for_stage(number: int) -> Array:
	return ENEMIES[clampi(number, 1, 5) - 1].duplicate()


static func plant_name(kind: String) -> String:
	if kind in ["bowling_nut", "explosive_nut", "hammer"]:
		return {"bowling_nut": "滚动坚果", "explosive_nut": "爆炸坚果", "hammer": "木锤"}[kind]
	var index := PLANT_ORDER.find(kind)
	return PLANT_NAMES[index] if index >= 0 else kind


static func is_night(number: int) -> bool:
	return number in [2, 4]


static func has_pool(number: int) -> bool:
	return number in [3, 4]
