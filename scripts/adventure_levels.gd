class_name AdventureLevels
extends RefCounted
## First-time PC adventure layout, rewards and wave budgets, expressed in 3D.

const LEVEL_COUNT: int = 50
const ROWS: Array = [[2], [1, 2, 3], [1, 2, 3], [0, 1, 2, 3, 4]]
const WAVE_COUNTS: Array[int] = [4, 6, 8, 10, 8, 10, 20, 10, 20, 20, 10, 20, 10, 20, 10, 10, 20, 10, 20, 20,
	10, 20, 20, 30, 20, 20, 30, 20, 30, 30, 10, 20, 10, 20, 20, 10, 20, 10, 20, 20, 10, 20, 20, 30, 20, 20, 30, 20, 30, 30]
const PLANTS: Array[String] = ["peashooter", "sunflower", "cherry_bomb", "wall_nut"]
const REWARDS: Array[String] = [
	"sunflower", "cherry_bomb", "wall_nut", "shovel", "potato_mine", "snow_pea", "chomper", "repeater", "note", "puff_shroom",
	"sun_shroom", "fume_shroom", "grave_buster", "almanac", "hypno_shroom", "scaredy_shroom", "ice_shroom", "doom_shroom", "note", "lily_pad",
	"squash", "threepeater", "tangle_kelp", "shop_key", "jalapeno", "spikeweed", "torchwood", "tall_nut", "note", "sea_shroom",
	"plantern", "cactus", "blover", "taco", "split_pea", "starfruit", "pumpkin", "magnet_shroom", "note", "cabbage_pult",
	"flower_pot", "kernel_pult", "coffee_bean", "watering_can", "garlic", "umbrella_leaf", "marigold", "melon_pult", "note", "silver_sunflower"
]
const TITLES: Array[String] = [
	"第一道防线", "阳光与向日葵", "路障来袭", "守住整个庭院", "坚果保龄球", "撑杆越过防线", "寒冰防线", "铁桶来袭", "白天最后的布阵", "白天传送带",
	"夜幕与小喷菇", "阳光菇的成长", "铁门与穿盾", "清除墓碑", "打僵尸", "橄榄球冲锋", "胆小菇的防线", "舞王登场", "夜晚最后的布阵", "夜晚传送带",
	"泳池与睡莲", "水陆防线", "潜水来袭", "保护泳池", "小僵尸大麻烦", "冰车与雪橇", "地刺破冰", "海豚跃过防线", "泳池总攻前夜", "泳池传送带",
	"浓雾与小丑", "照亮防线", "气球来袭", "吹散迷雾", "三组砸罐子", "矿工绕后", "杨桃交叉火力", "跳跳来袭", "浓雾最后的布阵", "暴风雨之夜",
	"屋顶与投手", "花盆阵线", "梯子来袭", "白天唤醒蘑菇", "蹦极闪电战", "投石车来袭", "保护后排", "巨人与小鬼", "屋顶最后的布阵", "僵王博士"
]
const HINTS: Array[String] = [
	"空手右键选择豌豆，瞄准中间草坪左键种植。选择期间世界暂停。",
	"先种向日葵增加阳光收入，再给三条路径补上豌豆射手。",
	"路障更耐打。增加同路火力，或用樱桃炸弹清除附近僵尸。",
	"五条路径都需要保护。把坚果放在射手前方，争取输出时间。",
	"右键选择传送带上的坚果，在左侧三列左键投出；红坚果接触后爆炸。",
	"撑杆会越过第一株植物。用便宜的土豆雷消耗跳跃，保护后方火力。",
	"寒冰射手能减速。土豆雷需要 15 秒准备，先建立阳光收入。",
	"铁桶非常耐打。寒冰拖延时间，大嘴花可吞掉近处的铁桶僵尸。",
	"双发射手提高同路输出。撑杆与铁桶混合来袭，保护后方射手。",
	"传送带免费供应植物；种下才消耗一张，右键选择已有的供应。",
	"夜晚没有天降阳光。小喷菇免费但射程短，向日葵仍能生产阳光。",
	"阳光菇只需 25 阳光，成长后每次产 25；用免费小喷菇先守住防线。",
	"大喷菇的孢子能穿过铁门盾牌，并击中同路的多个僵尸。",
	"墓碑占据格子，末波会冒出僵尸；把墓碑吞噬者种在墓碑上清除它。",
	"右手持锤，左键敲僵尸。空手右键可选择炸弹、土豆雷和墓碑吞噬者。",
	"橄榄球又快又耐打。让它吃下魅惑菇，转身攻击其他僵尸。",
	"胆小菇射程远，但近处有僵尸时停止攻击；让坚果和前排蘑菇挡住敌人。",
	"舞王会补召四个方向的伴舞。寒冰菇冻结全场，为清除舞王争取时间。",
	"毁灭菇清除大范围敌人和墓碑，但会留下暂时不能种植的弹坑。",
	"夜晚传送带供应蘑菇与墓碑吞噬者；优先补足火力，清除墓碑。",
	"水路先放睡莲，再把陆生植物种在上面。水路也需要防守。",
	"倭瓜可清除近处强敌；水陆六行都需要阳光与火力。",
	"潜水时普通弹体无法命中；靠近植物会浮出水面。",
	"三线射手覆盖相邻路径，缠绕海草可直接种在水里。",
	"免费传送带供应植物；僵尸缩小且加快，先补睡莲和水路火力。",
	"冰车会碾压植物并留下冰道，雪橇小队沿冰道出场。",
	"地刺能扎破冰车，火爆辣椒清除整条路径的敌人和冰道。",
	"海豚会越过第一株植物；高坚果能阻止跳跃。",
	"火炬强化豌豆，高坚果保护水路；留意车辆和海豚。",
	"泳池传送带免费供应睡莲、多路射手、海草和防御植物。",
	"夜晚水路可以直接种海蘑菇；浓雾遮挡右侧，小丑可能炸毁植物。",
	"路灯花照亮周围迷雾；保护它并补足水路火力。",
	"气球越过地面防线；仙人掌可扎破气球，让它落地。",
	"三叶草吹走气球，并暂时清除全部浓雾。",
	"空手或持铲时左键砸罐子，释放植物卡或僵尸；逐组清空三组。",
	"矿工会从后排现身，裂荚射手能同时向前后攻击。",
	"杨桃向五个方向发射；南瓜可套在已有植物外保护它。",
	"高坚果阻止跳跳，磁力菇能移除金属装备。",
	"保住反空防线与水路，避免气球绕过地面火力。",
	"闪电短暂照亮全场；免费传送带供应睡莲、仙人掌、豌豆、小喷和樱桃。",
	"屋顶预先放好前三列花盆；卷心菜抛射可以越过坡面。",
	"先放花盆再种植物；平射豌豆会被前段坡面挡住。",
	"梯子能跨越坚果；抛射攻击绕过梯子盾牌。",
	"咖啡豆必须放在睡眠蘑菇上，唤醒这株蘑菇；末波留意蹦极。",
	"免费供应花盆、大嘴花、南瓜和樱桃；蹦极会偷植物或空投敌人。",
	"投石车攻击后排；叶子保护伞能挡住空投与投掷。",
	"大蒜使普通啃食僵尸换到相邻陆路，保护伞覆盖周围九格。",
	"巨人重击植物，半血时扔出小鬼；用爆炸和投手集火。",
	"西瓜投手造成溅射，保住花盆与后排防线。",
	"僵王伸头时集火。寒冰菇消除火球，火爆辣椒消除同路冰球；注意房车与空投。"
]
const ENEMIES: Array = [
	["zombie"], ["zombie"], ["zombie", "conehead_zombie"], ["zombie", "conehead_zombie"], ["zombie", "conehead_zombie"],
	["zombie", "conehead_zombie", "pole_vaulting_zombie"], ["zombie", "conehead_zombie", "pole_vaulting_zombie"],
	["zombie", "conehead_zombie", "buckethead_zombie"], ["zombie", "conehead_zombie", "pole_vaulting_zombie", "buckethead_zombie"], ["zombie", "conehead_zombie", "pole_vaulting_zombie", "buckethead_zombie"],
	["zombie", "newspaper_zombie"], ["zombie", "conehead_zombie", "buckethead_zombie", "newspaper_zombie"], ["zombie", "conehead_zombie", "screen_door_zombie"],
	["zombie", "conehead_zombie", "pole_vaulting_zombie", "screen_door_zombie"], ["zombie", "conehead_zombie", "buckethead_zombie"], ["zombie", "conehead_zombie", "football_zombie"],
	["zombie", "conehead_zombie", "screen_door_zombie", "football_zombie"], ["zombie", "conehead_zombie", "dancing_zombie"],
	["zombie", "conehead_zombie", "screen_door_zombie", "dancing_zombie"], ["zombie", "conehead_zombie", "screen_door_zombie", "football_zombie", "dancing_zombie"],
	["zombie", "conehead_zombie"], ["zombie", "conehead_zombie", "buckethead_zombie", "newspaper_zombie", "football_zombie"],
	["zombie", "conehead_zombie", "snorkel_zombie"], ["zombie", "conehead_zombie", "pole_vaulting_zombie", "buckethead_zombie", "newspaper_zombie", "snorkel_zombie"],
	["zombie", "conehead_zombie", "football_zombie", "snorkel_zombie"], ["zombie", "conehead_zombie", "zomboni", "bobsled_team"],
	["zombie", "conehead_zombie", "buckethead_zombie", "snorkel_zombie", "zomboni", "bobsled_team"], ["zombie", "conehead_zombie", "dolphin_rider"],
	["zombie", "conehead_zombie", "pole_vaulting_zombie", "buckethead_zombie", "zomboni", "bobsled_team", "dolphin_rider"], ["zombie", "conehead_zombie", "buckethead_zombie", "snorkel_zombie", "zomboni", "bobsled_team", "dolphin_rider"],
	["zombie", "conehead_zombie", "jack_in_the_box"], ["zombie", "conehead_zombie", "football_zombie", "jack_in_the_box"],
	["zombie", "conehead_zombie", "balloon_zombie"], ["zombie", "conehead_zombie", "dolphin_rider", "balloon_zombie"],
	["zombie", "buckethead_zombie", "football_zombie", "dancing_zombie", "jack_in_the_box"], ["zombie", "conehead_zombie", "digger_zombie"],
	["zombie", "conehead_zombie", "buckethead_zombie", "jack_in_the_box", "digger_zombie"], ["zombie", "conehead_zombie", "pogo_zombie"],
	["zombie", "conehead_zombie", "buckethead_zombie", "balloon_zombie", "pogo_zombie"], ["zombie", "conehead_zombie", "buckethead_zombie", "jack_in_the_box", "balloon_zombie", "digger_zombie", "pogo_zombie"],
	["zombie", "conehead_zombie", "bungee_zombie"], ["zombie", "conehead_zombie", "pole_vaulting_zombie", "buckethead_zombie", "bungee_zombie"],
	["zombie", "conehead_zombie", "ladder_zombie"], ["zombie", "conehead_zombie", "football_zombie", "pogo_zombie", "ladder_zombie"],
	["zombie", "conehead_zombie", "buckethead_zombie", "ladder_zombie", "bungee_zombie"], ["zombie", "conehead_zombie", "catapult_zombie"],
	["zombie", "conehead_zombie", "bungee_zombie", "ladder_zombie", "catapult_zombie"], ["zombie", "conehead_zombie", "gargantuar"],
	["zombie", "conehead_zombie", "buckethead_zombie", "jack_in_the_box", "bungee_zombie", "ladder_zombie", "catapult_zombie", "gargantuar"], ["zomboss"]
]
const POINTS: Dictionary = {"zombie": 1, "conehead_zombie": 2, "pole_vaulting_zombie": 2, "buckethead_zombie": 4, "newspaper_zombie": 2, "screen_door_zombie": 4, "football_zombie": 4, "dancing_zombie": 4,
	"snorkel_zombie": 2, "zomboni": 4, "bobsled_team": 4, "dolphin_rider": 3, "jack_in_the_box": 3, "balloon_zombie": 2, "digger_zombie": 3, "pogo_zombie": 3,
	"bungee_zombie": 3, "ladder_zombie": 3, "catapult_zombie": 4, "gargantuar": 5}
const DAY_CONVEYOR: Array[String] = ["peashooter", "cherry_bomb", "wall_nut", "repeater", "snow_pea", "chomper", "potato_mine"]
const NIGHT_CONVEYOR: Array[String] = ["grave_buster", "ice_shroom", "doom_shroom", "hypno_shroom", "scaredy_shroom", "fume_shroom", "puff_shroom"]
const SUPPLIES: Dictionary = {
	25: ["lily_pad", "wall_nut", "peashooter", "cherry_bomb"],
	30: ["lily_pad", "squash", "threepeater", "tangle_kelp", "jalapeno", "spikeweed", "torchwood", "tall_nut"],
	35: ["peashooter", "squash", "snow_pea", "hypno_shroom"],
	40: ["lily_pad", "cactus", "peashooter", "puff_shroom", "cherry_bomb"],
	45: ["flower_pot", "chomper", "pumpkin", "cherry_bomb"],
	50: ["flower_pot", "melon_pult", "jalapeno", "cabbage_pult", "kernel_pult", "ice_shroom"]
}
const SUPPLY_WEIGHTS: Dictionary = {25: [25, 15, 25, 35], 30: [25, 5, 25, 5, 10, 10, 10, 10], 40: [30, 10, 20, 15, 25], 45: [50, 25, 15, 10], 50: [55, 10, 12, 10, 5, 8]}
const BOSS_SUMMONS: Array[String] = ["zombie", "conehead_zombie", "buckethead_zombie", "pole_vaulting_zombie", "newspaper_zombie", "screen_door_zombie", "football_zombie", "jack_in_the_box", "ladder_zombie", "zomboni", "catapult_zombie", "pogo_zombie", "gargantuar"]


static func code(number: int) -> String:
	return "%d-%d" % [area(number), (number - 1) % 10 + 1]


static func area(number: int) -> int:
	return (number - 1) / 10 + 1


static func parse_code(value: String) -> int:
	if value.is_valid_int():
		return int(value) if int(value) in range(1, LEVEL_COUNT + 1) else 0
	var parts := value.split("-")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return 0
	var world := int(parts[0])
	var sub := int(parts[1])
	return (world - 1) * 10 + sub if world in range(1, 6) and sub in range(1, 11) else 0


static func mode(number: int) -> String:
	return {5: "bowling", 15: "whack", 25: "mini", 35: "vases", 45: "bungee", 50: "boss"}.get(number, "conveyor" if number in [10, 20, 30, 40] else "normal")


static func reward_name(number: int) -> String:
	var reward: String = REWARDS[number - 1]
	return {"shovel": "铲子", "note": "僵尸便条", "almanac": "植物与僵尸图鉴", "shop_key": "商店钥匙", "taco": "墨西哥卷饼", "watering_can": "浇水壶", "silver_sunflower": "银向日葵奖杯"}.get(reward, StageCatalog.plant_name(reward))


static func unlocked_plants(number: int) -> Array[String]:
	var result: Array[String] = ["peashooter"]
	for reward: String in REWARDS.slice(0, clampi(number - 1, 0, LEVEL_COUNT)):
		if reward in StageCatalog.PLANT_ORDER:
			result.append(reward)
	return result


static func plants(number: int) -> Array[String]:
	if SUPPLIES.has(number):
		var result: Array[String] = []
		result.assign(SUPPLIES[number])
		return result
	match mode(number):
		"bowling": return ["bowling_nut", "explosive_nut"]
		"whack": return ["potato_mine", "cherry_bomb", "grave_buster"]
		"conveyor": return DAY_CONVEYOR.duplicate() if number == 10 else NIGHT_CONVEYOR.duplicate()
	return unlocked_plants(number)


static func rows(number: int) -> Array[int]:
	var result: Array[int] = []
	if area(number) in [3, 4] and number != 35:
		result.assign([0, 1, 2, 3, 4, 5])
		return result
	result.assign(ROWS[clampi(number, 1, 4) - 1])
	return result


static func is_night(number: int) -> bool:
	return area(number) in [2, 4] or number == 50


static func terrain(number: int) -> int:
	return 2 if number == 35 else area(number)


static func wave(number: int, index: int, random: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	if number in [35, 50]:
		return result
	if number == 15:
		for item in 3 + index / 2:
			result.append(ENEMIES[14][random.randi_range(0, mini(2, index / 3))])
		return result
	var budget := index / 3 + 1
	var final_wave := index == WAVE_COUNTS[number - 1] - 1
	if final_wave and number > 1:
		var plain_count := mini(budget, 8)
		budget = int(budget * 2.5)
		for item in plain_count:
			result.append("zombie")
			budget -= 1
		result.append("flag_zombie")
		budget -= 1
	if number >= 3 and ((number == 3 and index == WAVE_COUNTS[2] / 2) or final_wave):
		var feature: String = ENEMIES[number - 1][-1]
		result.append(feature)
		budget -= int(POINTS[feature])
	if final_wave and not "zombie" in result:
		result.append("zombie")
		budget -= 1
	while budget > 0:
		var choices: Array[String] = []
		for kind: String in ENEMIES[number - 1]:
			if int(POINTS[kind]) <= budget:
				choices.append(kind)
		var kind: String = choices[random.randi_range(0, choices.size() - 1)] if number > 4 else ("conehead_zombie" if number >= 3 and budget >= 2 and random.randf() < 0.4 else "zombie")
		result.append(kind)
		budget -= int(POINTS[kind])
	return result
