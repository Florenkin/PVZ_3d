# 游戏数值配置说明

编辑本目录的 `game_config.json`，保存后停止游戏，再按 Godot **F5** 启动。游戏在启动时读取一次；运行中生成的僵尸、豌豆和掉落物使用该次启动的配置。**R** 重置交战，不重新读取文件。无需运行 Python 或重新生成模型。

文件为 UTF-8 JSON，不支持注释、尾随逗号。可以省略字段，省略部分使用内置默认值。未知字段会提示并忽略；无效字段会提示并回退。整个文件缺失、无法读取或格式错误时使用全部默认值，游戏仍可运行。提示在 Godot 的输出/调试面板中，包含文件、字段路径或解析行号。程序不会自动覆盖或修复你的 JSON。

## 主界面与冒险五个大关

项目默认入口是 `scenes/game.tscn`，主菜单提供演示和冒险。冒险实现 **1-1～5-10 共 50 关**：前院/屋顶 5×9，泳池/浓雾 6×9 且中间两行水路，4-5 是五行夜晚前院；前四关开放 1/3/3/5 行。关卡数据见 `scripts/adventure_levels.gd`，不受旧 `placements` 或演示扩容影响。1-5 保龄球，2-5 打僵尸，3-5 小僵尸，4-5 三组罐子，4-10 暴风雨，5-5 蹦极闪电战，5-10 僵王；夜晚禁止天降阳光。

根对象的 `adventure` 配置冒险经济、卡牌冷却、特殊玩法和计时；植物的费用、HP、伤害与射击间隔来自 `stages.plants`，僵尸的本体、头甲、盾牌、移速倍率和啃食来自 `stages.zombies`。共用 `plants.common.pea_speed`、`zombies.common.walk_speed`、受击/物理、`lawn.cell_size` 与格子几何、`sun.fall_speed`/`lifetime`。演示的 `respawn` 开关不会使冒险死亡实体自动补回。

| 字段（在 `adventure` 下） | 默认值 | 含义 / 有效范围 |
| --- | --- | --- |
| `initial_sun_tutorial` / `initial_sun` | 150 / 50 | 1-1 / 其余常规关初始阳光，非负整数；保龄球、传送带、打僵尸初始为 0 |
| `first_wave_delay` | 18 | 白天首波等待秒数（1-2 除外），>0；1-1 等第一株豌豆种下再计时 |
| `sunflower_tutorial_delay` | 50 | 1-2 首波等待秒数，>0 |
| `wave_interval` / `wave_interval_range` | 25 / 6 | 后续波次最大等待为基础秒数加 `[0, range]` 随机秒数；基础 >0，范围 ≥0 |
| `minimum_wave_gap` | 4 | 场上与当前出场队列清空后，允许提前进入下一波的最少等待，>0 且 ≤ `wave_interval` |
| `flag_warning_duration` | 5 | 最后一大波提示后等待秒数，>0；1-1 没有旗帜末波 |
| `sun_first_min` / `sun_first_max` | 4.25 / 7 | 第一次天空阳光等待范围，均 >0，min ≤ max |
| `sun_base_interval` | 4.25 | 后续天空阳光基础间隔，>0 秒 |
| `sun_interval_growth` | 0.1 | 每次生成后增加的间隔，≥0 秒 |
| `sun_max_interval` | 9.5 | 增长后的基础间隔上限，>0 且 ≥ `sun_base_interval` |
| `sun_interval_jitter` | 2.75 | 每次间隔额外随机 `[0, jitter]`，≥0 秒 |
| `sun_value` | 25 | 天空中阳光点数，正整数；向日葵产 25 点 |
| `sun_radius` | 0.46 | 阳光模型与点击球半径，>0 世界单位 |
| `cherry_fuse` | 1.2 | 樱桃种下后引爆秒数，>0；伤害来自 `stages.plants.cherry_bomb.damage` |
| `mower_speed` | 8 | 一次性割草机的向右扫场速度，>0 单位/秒 |
| `night_first_wave_delay` | 35 | 夜晚首波准备时间，>0 秒 |
| `conveyor_interval` | 4 | 保龄球/传送带每张库存的补给间隔，>0 秒 |
| `conveyor_capacity` | 10 | 保龄球/传送带最多库存张数，1～16 整数 |
| `bowling_speed` | 8 | 滚动坚果向前速度，>0 世界单位/秒 |
| `bowling_damage` | 400 | 普通坚果单次命中伤害，正整数 HP；不绕过盾牌，之后弹向相邻行 |
| `bowling_explosion_damage` | 1800 | 红坚果接触爆炸伤害，正整数 HP，约 3×3 格范围 |
| `whack_damage` | 500 | 木锤每次命中伤害，正整数 HP；按真实护甲/盾牌结算 |
| `whack_sun_value` | 25 | 打僵尸击杀后掉落阳光价值，正整数 |
| `grave_eat_time` | 4 | 墓碑吞噬者清除其所在墓碑并消失的时间，>0 秒 |
| `mine_arm_time` | 15 | 土豆雷种下到能够接触引爆的等待，>0 秒 |
| `mushroom_fuse` | 1 | 清醒的寒冰菇/毁灭菇种下到爆发的时间，>0 秒 |
| `crater_lifetime` | 180 | 毁灭菇弹坑阻止种植的时间，>0 秒 |
| `pool_first_wave_delay` | 30 | 白天泳池首波准备，>0 秒 |
| `roof_first_wave_delay` | 45 | 白天屋顶首波准备，>0 秒；5-10 是独立 Boss 流程 |
| `ice_lifetime` | 30 | 冰车冰道阻止种植的时间，>0 秒，辣椒可提前清除 |
| `squash_windup` | 0.8 | 倭瓜找到目标后起跳到砸落的时间，>0 秒 |
| `blover_duration` | 25 | 三叶草使浓雾消失的时间，>0 秒 |
| `storm_interval` / `storm_flash_duration` | 12 / 2 | 4-10 两次闪电间隔 / 全场照亮时长，均 >0 秒 |
| `mini_scale` / `mini_health_multiplier` / `mini_speed_multiplier` | 0.5 / 0.5 / 1.5 | 3-5 模型及碰撞 / 各层生命 / 移速倍率，均 >0；生命取整且本体至少 1 HP |
| `boss_attack_interval` | 20 | 僵王推进攻击序列的间隔，>0 秒，给传送带补回防线的时间 |
| `boss_head_interval` / `boss_head_duration` | 18 / 9 | 闭头后下次伸头的等待 / 伸头时长，均 >0 秒；首次伸头当前固定 3 秒 |
| `boss_ball_speed` | 3.2 | 冰火球向左速度，>0 世界单位/秒 |
| `card_cooldowns.peashooter` / `sunflower` | 7.5 / 7.5 | 种植后卡牌冷却，均 >0 秒 |
| `card_cooldowns.cherry_bomb` / `wall_nut` | 50 / 30 | 樱桃 / 坚果种植后卡牌冷却，均 >0 秒 |
| `card_cooldowns.potato_mine` / `hypno_shroom` | 30 / 30 | 土豆雷 / 魅惑菇冷却，均 >0 秒 |
| `card_cooldowns.snow_pea` / `chomper` / `repeater` | 均 7.5 | 寒冰 / 大嘴花 / 双发冷却，均 >0 秒 |
| `card_cooldowns.puff_shroom` / `sun_shroom` / `fume_shroom` | 均 7.5 | 小喷 / 阳光 / 大喷冷却，均 >0 秒 |
| `card_cooldowns.grave_buster` / `scaredy_shroom` / `lily_pad` | 均 7.5 | 墓碑吞噬者 / 胆小菇 / 睡莲冷却，均 >0 秒 |
| `card_cooldowns.ice_shroom` / `doom_shroom` | 均 50 | 寒冰菇 / 毁灭菇冷却，均 >0 秒 |
| `card_cooldowns.squash` / `tangle_kelp` / `tall_nut` / `sea_shroom` / `plantern` / `pumpkin` / `marigold` | 均 30 | 后续对应卡牌冷却，均 >0 秒 |
| `card_cooldowns.jalapeno` | 50 | 火爆辣椒卡牌冷却，>0 秒 |
| `card_cooldowns.threepeater` / `spikeweed` / `torchwood` / `cactus` / `blover` / `split_pea` / `starfruit` / `magnet_shroom` | 均 7.5 | 后续对应卡牌冷却，均 >0 秒 |
| `card_cooldowns.cabbage_pult` / `flower_pot` / `kernel_pult` / `coffee_bean` / `garlic` / `umbrella_leaf` / `melon_pult` | 均 7.5 | 屋顶对应卡牌冷却，均 >0 秒 |

天空每次等待为 `min(sun_max_interval, sun_base_interval + 已生成数量 × sun_interval_growth) + 随机抖动`。三组区间冲突（首阳光、增长上限、最小波间隔）时 `adventure` 整组回退到默认值并报告路径，单项类型/范围错误只回退该项。

冒险使用 `dave` 与 `cameras.first_person` 的移动、灵敏度、腰部高度和相机配置。`derive_bounds_from_lawn` 开启时按实际 5×9 或 6×9 场地与 `boundary_inset` 计算移动边界，不受演示扩容影响；关闭时保留手动 `movement_bounds`，是否限制移动仍由 `restrict_to_lawn` 决定。空手右键打开暂停选择面板，点击卡牌或在面板内按 1–9 选择前九张，其他卡牌点击选择；准星瞄准草坪格后左键使用。滚轮切换空手/已解锁的铲子，打僵尸另外提供木锤，S 为后退。手持植物当前固定缩为 0.32 倍，落点模型 Alpha 不透明度为 0.45；这两个显示常量不是 JSON 字段。

免费供应关不使用 `card_cooldowns` 或阳光费用，成功使用才扣一张库存；取消选择和无效位置不扣库存。满库存时停止补给计时，选择/暂停时也冻结。夜晚的剩余墓碑在末波出怪；墓碑吞噬者只清除种植所在格。阳光菇当前 120 秒成长，从 15 改为每次 25 阳光；寒冰菇当前冻结 4 秒、后续减速 20 秒；这两种能力的时长沿用现有实现常量。毁灭菇范围当前为三个格距的圆形区域，并清除附近墓碑。

冒险种植成功才扣费；冷却、占用、场外、未开放行、未解锁或余额不足的操作不扣费。选择植物与暂停同时停止卡牌冷却、阳光产生/落下、波次、交战、刚体掉落、特效和戴夫移动。R 重试会用当前启动快照重建空场地、初始余额与割草机；不会重新读取 JSON。死亡的植物/僵尸不刷新，避免演示逻辑干扰胜负。

`GameProgress` 保存进度到 `user://adventure_progress.json`，该文件不是项目数值配置。全部 50 关默认开放，无需更改 JSON 或存档，可在菜单或命令行任意选择。格式版本仍为 1，新增 `completed_levels` 数组记录实际通关的编号，`completed_level` 保留从 1-1 开始连续完成的范围；旧文件缺少数组时自动迁移其前 N 关完成记录。跳关、重玩不会虚增其他关卡的完成状态，失败/退出不增加记录，无效编号被拒绝。1-5 起直接有铲子，前四个教学关仍在完成 1-4 后提供；通关 2-4 或更后面的关卡后开放图鉴，按最高通关关卡展示内容。5-10 获得奖杯，实际累计完成 50 关才标记冒险全部完成。命令行 `-- --level=1`～`50` 或 `-- --level=5-10` 直接进关，`-- --mode=demo` 直接进入演示。

验证入口：[adventure_test.gd](../tests/adventure_test.gd) 与 [adventure_hand_test.gd](../tests/adventure_hand_test.gd) 验证原有输入、事务、物理暂停与右手；[adventure_expansion_test.gd](../tests/adventure_expansion_test.gd) 验证扩展关卡、特殊规则、夜晚、存档与图鉴。[adventure_playthrough_test.gd](../tests/adventure_playthrough_test.gd) 和 [adventure_expansion_playthrough_test.gd](../tests/adventure_expansion_playthrough_test.gd) 分别使用真实资源完整挑战前四关及新增十六关。测试不覆盖真实存档。

[adventure_campaign_test.gd](../tests/adventure_campaign_test.gd) 检查后三十关、叠放、水路、坡面、浓雾、罐子、僵王和五十关存档；[adventure_campaign_playthrough_test.gd](../tests/adventure_campaign_playthrough_test.gd) 用默认资源/冷却/供应挑战 3-1～5-10。

底座、顶部和南瓜各有独立生命。水路陆生植物需要睡莲，屋顶需要花盆；屋顶当前预置前三列 15 个花盆，这些摆放常量不在 JSON。铲顶部保留底座，底座死亡移除同格上层。咖啡豆用现有 `stages.plants.coffee_bean.attack_interval`（1.5 秒）定点唤醒；南瓜与保护伞使用现有 HP、费用与覆盖常量。蹦极当前六秒结束一次访问，未保护时偷走目标格或在 5-5 空投敌人；金盏花产生的金币仅属于当前关，不写入进度或开放商店。

砸罐子使用固定三组 15/20/25 罐及专用内容，不使用普通波次或自动补给；每组清空后暂停等待继续。僵王本体使用 `stages.zombies.zomboss.body_health`（40000 HP），闭头免伤、伸头可被所有行投手命中。攻击序列包括召唤、交替冰火球、蹦极、踩踏和房车；寒冰菇消除火球、同路辣椒消除冰球。特殊关卡供应权重与候选写在 `AdventureLevels`，对应 3D 适配范围见 README。

## 演示手持道具

五个大关与 0 键原演示共用 `demo_tools`。进入场景默认空手，滚轮循环切换空手/铲子，右手持铲，空手时收在背部；铲子右键移除植物，M 全景/模型视角使用 Ctrl＋滚轮缩放。

| 字段 | 默认值 | 含义 / 有效范围 |
| --- | --- | --- |
| `demo_tools.shovel_reach` | 4.8 | 戴夫视角从相机沿瞄准射线的最大作用距离，>0 世界单位；非数值、非有限值或 ≤0 回退默认值 |

全景/模型视角使用镜头远裁剪距离进行鼠标选取；所有视角均检查墙体、地面和僵尸遮挡。Tab 侧栏打开时禁用道具输入。手动铲除不触发 `stages.plant_respawn_delay`，不退阳光；R 与场景切换恢复固定阵容，R 同时恢复空手。冒险模式的卡牌/铲子逻辑不使用此字段。

相关默认值在 `scripts/game_config_defaults.gd`，范围校验在 `scripts/game_config.gd`；[demo_tools_test.gd](../tests/demo_tools_test.gd) 验证错误值回退、实际输入、射线距离/遮挡、移除与恢复、缩放、左键收集阳光及模式清理。

## 五个大关的配置

从主界面点击“演示模式”，进入 `scenes/adventure.tscn`。**1–5** 切换白天、夜晚、泳池、浓雾、屋顶；**0** 进入原演示。根对象的 `stages` 管理大关演示，下面原有 `plants`、`zombies`、`placements` 的类型数值与固定位置说明针对 0 键原演示。演示大关共用 `lawn.cell_size`/草坪几何、`plants.common.pea_speed`、`zombies.common.walk_speed` 与受击参数、物理、戴夫、房屋和通用阳光参数。

| 字段（在 `stages` 下） | 默认值 | 含义 / 有效范围 |
| --- | --- | --- |
| `start_stage` | 1 | 启动大关，1～5 整数；命令行 `-- --stage=0` 可临时进入原演示 |
| `plant_columns` | 4 | 左侧植物占用列数，2～6 整数；第 1 列预留给戴夫 |
| `minimum_rows` | 6 | 场地最少行数，6～20 整数；累计植物过多时自动扩行 |
| `board_columns` | 13 | 场地总列数，9～32 整数；必须 ≥ `plant_columns + 6` |
| `plant_respawn_delay` | 8 | 植物死亡/使用后恢复展示的等待秒数，>0；不是原版卡牌冷却 |
| `sun_value` | 25 | 新大关天空中阳光点数，正整数；植物产阳光使用原版 15/25 点 |
| `fog_opacity` | 0.42 | 浓雾透明度，0～0.8，0 表示透明 |
| `label_font_size` | 26 | 模型上方中文/血量标签字号，12～60 整数 |

植物列数与总列数冲突时，两项一起回退到默认值并报告原因。行数为陆地植物数量除以 `plant_columns` 向上取整，并与 `minimum_rows` 取较大值；泳池/浓雾额外预留中央两行水道。默认五个大关依次为 **6×13、6×13、8×13、10×13、10×13**。新大关在运行时自动布局，不读取 `placements` 的旧固定坐标。

`stages.plants` 以 `stage_catalog.gd` 中的 40 个基础植物键名为索引，例如 `peashooter`、`wall_nut`、`melon_pult`。初始化费用、HP 与主要伤害来源见 [plan.md](../plan.md)。

| 字段（在 `stages.plants.类型` 下） | 含义 / 有效范围 |
| --- | --- |
| `sun_cost` | 标签显示的原版阳光费用，非负整数；当前不实际扣费 |
| `maximum_health` | 初始化生命，正整数；普通植物 300、坚果/南瓜 4000、高坚果 8000 |
| `damage` | 攻击基础伤害，非负整数；豌豆 20、卷心菜 40、西瓜 80，爆炸类通常 1800 |
| `attack_interval` | 演示攻击/能力轮次秒数，>0；射手通常 1.5、投手 3、生产 24；大嘴花该值为吞食后的消化时长，默认 42 |
| `range_cells` | 检测距离（格），>0；世界距离乘以 `lawn.cell_size`，短射程蘑菇默认 3、大喷菇 4 |

特殊能力有单独规则：玉米普通伤害 20、25% 黄油伤害 40 并定身 4 秒；土豆雷准备 15 秒；寒冰豌豆减速 50% 持续 10 秒；三线展开 3.6 世界单位；双发/裂荚连射间隔 0.18 秒。白天蘑菇睡眠，咖啡豆自动寻找睡眠对象。功能型植物和瞬发植物用自动触发与恢复展示演示，不代表原版种植时序。

`stages.zombies` 以 `stage_catalog.gd` 中的 26 个僵尸键名为索引。新大关拆分本体、头甲和盾牌：路障 **270+370=640**、铁桶 **270+1100=1370**、读报 **270+150=420**、橄榄球 **270+1400=1670**、铁门 **270+1100=1370**；巨人本体 **3000**、僵王本体 **40000**。这是原版初始化值；旧演示仍使用普通 200、路障 570、铁桶 1370、读报 350。

| 字段（在 `stages.zombies.类型` 下） | 含义 / 有效范围 |
| --- | --- |
| `body_health` | 本体生命，正整数 |
| `helmet_health` / `shield_health` | 头甲 / 盾牌生命，非负整数；总生命为三项之和 |
| `speed_multiplier` | 相对 `zombies.common.walk_speed` 的移速倍率，≥0；静止机甲/蹦极使用 0 |
| `bite_damage_per_second` | 普通啃食每秒伤害，≥0，默认 100 HP/秒；寒冰减速时减半 |
| `ability_interval` | 舞王召唤、投石车/简化僵王等能力周期，>0 秒，默认 8；小丑使用 8～16 秒随机引爆，冰车另按短周期铺冰 |

普通弹体依次损伤盾牌、头甲、本体；抛物线/穿透/背向弹体绕过盾牌。各层血量耗尽后隐藏或掉落装备，本体归零触发当前项目的即时死亡与尸体流程；没有模拟原版脱头后继续行走的衰减。大关读报损失盾牌后停步 1 秒、移速乘以 3.3，0 键原演示继续使用原先 2 倍规则。

`respawn.auto_respawn_enabled` 及 `respawn.respawn_delay` 共用：开关控制大关植物/僵尸是否自动补回，僵尸等待默认 1 秒，植物等待由 `stages.plant_respawn_delay` 指定。R 使用启动快照重建当前场景；切换释放整棵旧场景树。夜晚与浓雾强制关闭天降阳光，但仍能收集植物阳光；其夜间光照与屋顶/雾的初始全景范围按场景设定。运行时的金币、阳光与临时能力状态在切换时清空。

可运行 `tests/stages_test.gd` 检查字段容错、累计名单、放置、输入与生命分层，`tests/stages_stability_test.gd` 检查五个大关各 90 秒自动交战后的状态与重置。实机图可用 `tools/capture_stages.gd` 在非 headless 模式生成。

## 原演示最常调整的位置

| 修改内容 | JSON 字段 | 初始值 |
| --- | --- | --- |
| 所有豌豆植物伤害 | `plants.common.pea_damage` | 20 |
| 所有豌豆植物攻击间隔 | `plants.common.shot_interval` | 1.5 秒 |
| 豌豆速度 | `plants.common.pea_speed` | 10 单位/秒 |
| 双发每轮颗数、颗间隔 | `plants.types.repeater.burst_size` / `burst_spacing` | 2 / 0.18 秒 |
| 机枪每轮颗数、颗间隔 | `plants.types.gatling_pea.burst_size` / `burst_spacing` | 4 / 0.18 秒 |
| 寒冰移速倍率、持续时间 | `plants.types.snow_pea.slow_multiplier` / `slow_duration` | 0.5 / 10 秒 |
| 僵尸移动速度 | `zombies.common.walk_speed` | 0.5 单位/秒 |
| 普通僵尸血量 | `zombies.common.maximum_health` | 200 |
| 路障、铁桶、撑杆、读报血量 | `zombies.types.对应类型.maximum_health` | 570 / 1370 / 500 / 350 |
| 击退初速度、衰减 | `zombies.common.knockback_speed` / `knockback_deceleration` | 1.4 / 10 |
| 死亡后刷新时间 | `respawn.respawn_delay` | 1 秒 |
| 断手、盔甲脱落血量 | `zombies.common.hand_drop_health` / `armor_drop_health` | 100 / 200 |
| 草坪行、列、格子间距 | `lawn.rows` / `columns` / `cell_size` | 5 / 9 / 2.4 |
| 坚果位置 | `placements.wall_nut.row` / `column` | 第 5 行第 8 列 |
| 戴夫腰部相机高度 | `dave.waist_height` | 0.94 单位 |
| 某实体整体大小 | `models.对应类型.scale` | 1 倍 |

`common` 为公共值，`types` 中的同名字段覆盖公共值。例如单独调整双发伤害：

```json
"repeater": {
  "burst_size": 2,
  "burst_spacing": 0.18,
  "pea_damage": 30
}
```

请把这个对象放在现有 `plants.types` 内，不要作为整份 JSON 替换。公共值的修改不会覆盖类型中明确写出的值。掉落物也遵循 `physics.debris` 公共值、`physics.parts.类型` 优先的规则。

## 单位和布局

- 时间：秒。长度：Godot 世界单位。速度：单位/秒。击退衰减、重力：单位/秒²。质量：Godot 刚体质量。角速度：弧度/秒。
- 名称带 `degrees` 的角度使用**度**；鼠标灵敏度使用弧度/像素。
- 三维数组顺序 `[X, Y, Z]`；颜色数组 `[R, G, B, A]`，各分量为 0～1。
- `placements` 的行、列从 **1** 开始。行沿 Z，列沿 X；草坪居中排列。植物默认朝向 +X，僵尸默认向 -X 行走。
- 改变行列数后，所有实体的放置坐标必须仍在范围内；否则 `lawn` 与 `placements` 整体回退到初始 5×9 布局。改变列数后可把僵尸的 `column` 改为新的最后一列。
- `tile_width` 是草坪格可见宽度/碰撞宽度，不能大于 `cell_size`；`tile_thickness` 是厚度；`surface_height` 是草皮顶面高度。间隙为 `cell_size - tile_width`。

**击退距离不是独立配置项**，它由初速度、衰减、行走和碰撞共同决定。默认 `1.4`、`10` 在 60 Hz、暂停行走且无遮挡时，单次命中实测约 **0.11 单位**。保留后仰效果、仅缩短位移时，降低 `knockback_speed`；后仰角度与恢复时间使用独立字段。

## 天降阳光

`sun` 控制独立阳光实体、自动掉落与资源余额。首次掉落在开局 10 秒后，后续每 10 秒一个；落点避开植物所在的格子。阳光从落点上方垂直下落，固定在草皮上方，不使用刚体翻滚。左键收集后立刻更新左上角余额，同一个阳光只结算一次。鼠标锁定时用中央准星瞄准，Esc 释放鼠标后直接点击；镜头查看模式也可收集，实体墙壁、坚果和僵尸会遮挡点击。

| 字段（均在 `sun` 下） | 默认值 | 含义 / 有效范围 |
| --- | --- | --- |
| `enabled` | true | 自动天降阳光开关，布尔值 |
| `spawn_interval` | 10 | 两次掉落之间的间隔，>0 秒 |
| `medium_value` | 50 | 收集中阳光获得的点数，正整数 |
| `initial_value` | 0 | 开局及 R 重置时的阳光值，非负整数 |
| `spawn_height` | 7 | 出生位置相对落点的高度，>0 世界单位 |
| `fall_speed` | 1.4 | 垂直下落速度，>0 世界单位/秒 |
| `radius` | 0.62 | 阳光尖角的最大半径，>0；运行时最多使用草坪格宽度的 40%，保证落点在格内 |
| `lifetime` | 20 | 未收集阳光落地后的存留时间，>0 秒，最后最多 3 秒淡出 |

R 清空所有阳光实体与余额，并重新开始完整掉落间隔。暂停植物摆动或打开数值侧栏不暂停阳光掉落。可用 `tests/sun_test.gd` 验证间隔、稳定落地、鼠标收集、遮挡、寿命、配置与重置。

## 战斗、动画与撑杆

| 字段 | 含义 / 有效范围 |
| --- | --- |
| `pea_damage` | 每颗伤害，非负整数；0 不造成伤害 |
| `shot_interval` | 每轮攻击间隔，>0 秒；无有效目标时重置计时 |
| `pea_speed` | 水平飞行速度，≥0 |
| `burst_size` | 双发/机枪每轮颗数，1～64 整数；机枪循环使用现有四个炮管 |
| `burst_spacing` | 同轮相邻颗间隔，>0 秒；攻击轮次不会互相重叠 |
| `slow_multiplier` / `slow_duration` | 移速倍率 0～1 / 减速秒数 ≥0；0.5 表示减速 50%，重复命中刷新，不叠加 |
| `lane_spread_distance` | 三线射手侧路豌豆完成横向展开所需前进距离，>0 |
| `recoil_degrees` | 植物单次后坐力 / 僵尸受击后仰，0～30° |
| `maximum_recoil_degrees` | 植物叠加后坐力与待机摆动的总幅度上限，0～30° |
| `recoil_recovery_time` | 植物/僵尸恢复姿势时间，>0 秒 |
| `idle_animation_enabled` / `combat_enabled` | 植物待机动画 / 战斗开关，布尔值 |
| `idle_amplitude` / `idle_speed` | 植物待机上下位移幅度 / 动画速度，≥0 |
| `idle_bend_degrees` / `idle_bend_speed` | 植物待机弯曲角度 / 频率，≥0 |
| `leaf_sway_degrees` / `leaf_sway_speed` | 叶片摆动角度 / 频率，≥0 |
| `maximum_health` | 僵尸满血，正整数；新实例和 R 使用该值 |
| `walk_speed` / `movement_enabled` / `is_ground_zombie` | 移速 ≥0 / 移动开关 / 陆地目标标记 |
| `maximum_walk_distance` | 从出生点最多行走距离，>0 |
| `knockback_speed` / `knockback_deceleration` | 击退初速度 ≥0 / 速度衰减 >0 |
| `flash_duration` | 受击闪白秒数，≥0；0 关闭闪白 |
| `armor_drop_health` / `hand_drop_health` | 盔甲 / 随机一只手脱落阈值，非负整数；生命降到 ≤ 阈值时只触发一次 |
| `walk_animation_speed` / `walk_bob_height` / `leg_swing_degrees` | 行走动画频率、身体起伏幅度、腿摆角度，≥0 |
| `frost_color` / `frost_color_strength` | 寒冰染色颜色 / 原色混合比例 0～1；闪白优先 |
| `target_lane_tolerance` | 无草坪坐标时的目标横向距离容差 / 撑杆目标横向容差，>0 |
| `auto_respawn_enabled` / `respawn_delay` | 死后自动刷新开关 / 等待秒数 >0 |
| `vault_enabled` | 撑杆跳跃开关；每只僵尸最多跳一次 |
| `vault_trigger_distance` / `vault_height` / `landing_clearance` | 起跳检测距离 / 根节点跳跃高度 / 落在植物后方距离，均 >0 |
| `prepare_time` | 撑杆落地准备时间，>0 秒 |
| `pole_length` / `pole_radius` | 杆的长度 / 物理半径，>0；杆的整体缩放还受模型参数影响 |
| `pole_release_fraction` | 在一次飞行的哪个比例释放杆，0～1 |
| `planted_tip_offset` | 杆着地点在植物前方的距离，≥0 |
| `vault_lean_degrees` / `flight_leg_degrees` | 腾空身体前倾角度（0～30°）/ 腿部摆动幅度 ≥0 |

## 读报僵尸

`zombies.types.newspaper_zombie` 继承僵尸公共配置。报纸与身体使用同一个总生命值，不额外建立报纸血量。达到阈值时只掉一次；停步期间仍可受伤，继续受击不会延长发怒计时。发怒完成后基础移速乘以加速倍率，再乘以当前寒冰倍率。直接死亡或 R 重置会取消发怒计时；死亡刷新恢复持报纸、满血和普通速度。

| 字段（在 `zombies.types.newspaper_zombie` 下） | 默认值 | 含义 / 范围 |
| --- | --- | --- |
| `maximum_health` | 350 | 总生命，正整数 |
| `newspaper_drop_health` | 200 | 生命 ≤此值时脱落报纸，非负整数 |
| `anger_pause_duration` | 1 | 脱落后的停步发怒时间，>0 秒；期间水平移动及击退位移暂停 |
| `enraged_speed_multiplier` | 2 | 发怒后的基础移速倍率，>1；默认 0.5 → 1.0 单位/秒 |

`placements.newspaper_zombie` 默认第 4 行第 9 列、朝向 90°。`models.newspaper_zombie` 支持整体缩放及报纸、眼镜、发怒眼睛等部件；报纸为 `Visuals/Newspaper`，缩放同步独立掉落碰撞。报纸、帽子和长杆不会扩大站立角色碰撞体。

报纸使用 `physics.parts.newspaper`：默认质量 **0.12**、寿命 **10 秒**、摩擦 **0.95**、反弹系数 **0.03**，其余阻尼和抛出速度沿用掉落物字段规则。N 查看读报僵尸；`cameras.enemy_view.newspaper_yaw_degrees` 默认为 **-80°**，接受任意有限角度，用于避开相邻坚果的遮挡。

当前没有啃食和失败判定，读报僵尸加速后可能走过射手，并在 `maximum_walk_distance` 范围外停止。

## 掉落物物理

`physics.gravity` 为重力加速度，>0。`physics.debris` 是公共默认值；`physics.parts` 包含 `cone`、`bucket`、`hand`、`head`、`corpse`、`corpse_arm`、`pole`、`newspaper`。

| 字段 | 含义 / 有效范围 |
| --- | --- |
| `mass` / `lifetime` | 质量 / 从脱落开始的存在秒数，均 >0 |
| `linear_damp` / `angular_damp` | 线速度 / 角速度阻尼，≥0 |
| `friction` / `bounce` | 摩擦 / 反弹系数，0～1 |
| `backward_speed` / `upward_speed` | 抛出时向后 / 向上的速度，≥0 |
| `side_speed` | 随机侧向速度幅度，≥0；断手根据左右手选方向 |
| `spin_x_min` / `spin_x_max` | 沿角色局部 X 轴的随机角速度区间，最小值 ≤ 最大值 |
| `spin_y` / `spin_z` | 绕世界竖轴 / 角色局部 Z 轴的角速度，可正负 |
| `initial_tilt_degrees` / `lift_height` | 尸体倒地时初始倾斜 / 离地抬高，≥0 |

尸体随机前后倒地，飞头、断手和帽子保持各自寿命；连接在尸体上的前臂使用 `corpse_arm.lifetime`。单独调整部件不会改变其他部件。

## 模型大小、部件与颜色

`models` 下包含五种射手、坚果、戴夫和四种僵尸。`scale` 为整体倍率（>0，1 为当前大小）；`parts` 的键对应模型中的主要部件节点路径，路径应保持不变。

| 字段 | 含义 |
| --- | --- |
| `position` | 部件相对父节点的位置 `[X,Y,Z]`，可正负 |
| `rotation_degrees` | 部件相对父节点的旋转 `[X,Y,Z]`，单位为度，可正负 |
| `scale` | 部件各轴缩放 `[X,Y,Z]`，每轴 >0；值是场景中实际局部缩放，部分网格初始值本来就小于 1 |
| `mesh_dimensions` | 可编辑的原始网格尺寸；与部件、整体缩放共同作用 |
| `radius` / `height` | 网格半径 / 高度，>0；球体、胶囊高度至少是直径 |
| `top_radius` / `bottom_radius` | 圆柱/圆锥上、下半径，≥0 |
| `inner_radius` / `outer_radius` | 环形网格内、外半径，>0 且内 < 外 |
| `color` | 指定主要网格的颜色 `[R,G,B,A]`，0～1；其余装饰保持原色 |

例如调整普通豌豆头大小：`models.peashooter.parts.Head.scale`；调整三线中、侧头：`Head`、`Head/LeftHead`、`Head/RightHead`；茎为 `Stem`，茎段为 `Stem/Lower`、`Stem/Upper` 或三线射手的 `MainStalk`、`LeftBranch`、`RightBranch`。缩放父节点会带动子节点，包括炮口和眼睛。

僵尸主要部件在 `Visuals` 下；帽子为 `Visuals/Head/Cone`、`Visuals/Head/Bucket`，杆为 `Visuals/Pole`；机枪头盔为 `Head/Helmet`；戴夫锅帽为 `Visuals/Head/CookingPot`。调整会在动画初始化前应用，重置和新实例保留配置姿势。物理根节点保持单位缩放，碰撞形状及掉落部件同步调整；小装饰和网格内部顶点不单独配置。

## 戴夫、相机和显示

| 分组 / 字段 | 含义 / 有效范围 |
| --- | --- |
| `dave.movement_speed` / `mouse_sensitivity` | 移速 / 鼠标灵敏度，≥0 |
| `dave.waist_height` | 相机离角色脚底高度，>0，独立于模型整体倍率 |
| `dave.pitch_limit_degrees` | 上下视角范围，>0 且 <90° |
| `dave.restrict_to_lawn` | 是否限制在移动边界内，布尔值 |
| `dave.derive_bounds_from_lawn` | 是否自动从草坪计算边界，布尔值，默认 true |
| `dave.boundary_inset` | 自动边界相对草坪外沿的缩进，≥0，不能超过草坪半宽 |
| `dave.movement_bounds` | 手动边界 `[最小X,最小Z,宽,深]`，宽深 >0；自动边界开启时不使用 |
| `cameras.first_person.fov` | 腰部视角视野角，1～179°（不含端点） |
| `cameras.first_person.near` / `far` | 近 / 远裁剪距离，>0 且 near < far |
| `cameras.orbit.minimum_size` / `maximum_size` | 模型视角缩放范围，>0 且最小 ≤ 最大 |
| `cameras.orbit.distance` | 模型视角距目标距离，>0 |
| `cameras.orbit.yaw_sensitivity` / `pitch_sensitivity` | 拖拽水平 / 垂直灵敏度，≥0 |
| `cameras.orbit.minimum_pitch_degrees` / `maximum_pitch_degrees` | 模型视角俯仰角范围，最小 < 最大 |
| `cameras.orbit.zoom_in_factor` / `zoom_out_factor` | 滚轮缩放倍率，>0；一般分别 <1 / >1 |
| `cameras.plant_view.yaw_degrees` / `pitch_degrees` / `size` / `offset` | 植物查看视角朝向 / 俯仰 / 正交大小 >0 / 相对植物中心偏移 |
| `cameras.enemy_view` 同名字段 | 僵尸近景朝向 / 俯仰 / 正交大小；`pole_size` 为撑杆近景大小 >0 |
| `target_height` / `armor_target_height` | 普通或撑杆 / 戴帽僵尸的查看目标高度，>0 |
| `display.window_width` / `window_height` | 游戏窗口宽高，正整数像素 |
| `display.minimum_width` / `minimum_height` | 窗口最小宽高，正整数，不得超过窗口宽高 |
| `display.viewport_width` / `viewport_height` | 界面逻辑分辨率，正整数像素 |
| `ui.scale` / `font_scale` | 整体界面 / 字号倍率，>0 |
| `ui.sidebar_width` / `sidebar_margin` | Tab 右侧数值栏宽度 / 距右边缘的间距，>0 / ≥0 像素 |
| `ui.health_bar_size` / `button_size` | 血条 / 按钮最小大小 `[宽,高]`，均 >0 像素 |
| `ui.ink_color` / `muted_color` / `panel_color` | 主要文字 / 次要文字 / 面板颜色 |

`environment` 的 `sun_energy`、`fill_energy`、`ambient_energy` 是主光、补光和环境光强度（≥0）；对应 `*_color` 为颜色。`sun_rotation_degrees`、`fill_rotation_degrees` 为灯光旋转；`shadow_blur`、`shadow_bias`、`shadow_distance` 为阴影柔化、偏移和距离（≥0）。`backdrop_color`、`ground_size`（>0）、`ground_height` 为背景地面；`sky_top_color`、`sky_horizon_color`、`ground_bottom_color` 为天空颜色。

## 戴夫的房子

`house` 控制独立的 `scenes/environment/dave_house.tscn` 实体。房屋位于植物后方、草坪的负 X 侧，正门朝向草坪。红瓦坡屋顶、烟囱、浅色墙面和窗框参考了[原版游戏住宅图库](https://plantsvszombies.fandom.com/wiki/Player%27s_House/Gallery)，模型使用本项目的几何体搭建。

戴夫转身后可以用 WASD 走到门口；靠近时门自动向外打开，室内和室外都能触发。离开门口后延迟关门，不需要按交互键。房屋地板、门廊与草坪的碰撞顶面同高，墙、门和家具具有实体碰撞。腰部相机随戴夫一起进入室内。开启移动边界限制时，游戏自动把房屋及周围地面加入可行走范围；关闭房屋时恢复原有范围。

| 字段（均在 `house` 下） | 默认值 | 含义 / 有效范围 |
| --- | --- | --- |
| `enabled` | true | 是否显示并启用房屋、碰撞和自动门，布尔值 |
| `width` / `depth` | 9.6 / 7.6 | 沿 Z 的宽度 / 沿 X 的进深，世界单位，>0 |
| `wall_height` / `wall_thickness` | 3.3 / 0.22 | 墙高 / 墙厚，世界单位，>0 |
| `roof_rise` | 2.1 | 屋脊相对墙顶的抬高，世界单位，>0 |
| `front_gap` | 1.8 | 正门相对草坪后沿向后的距离，世界单位，≥0 |
| `offset_z` | 0 | 房屋相对草坪中心的侧向偏移，世界单位，可正负 |
| `door_width` / `door_height` | 1.8 / 2.65 | 门洞宽 / 高，世界单位，分别 ≥1 / ≥2 |
| `door_open_degrees` | 95 | 自动门打开角度，90～170° |
| `door_speed_degrees` | 150 | 门转动速度，度/秒，>0 |
| `door_trigger_distance` | 2.8 | 正门前后自动开门距离，世界单位，>0；侧向须靠近门洞 |
| `door_close_delay` | 1.2 | 离开触发区域后的关门延迟，秒，≥0 |
| `apron_margin` | 1 | 房屋后方及两侧地面的余量，世界单位，≥0 |
| `porch_depth` | 1.4 | 门廊向草坪延伸的长度，世界单位，≥0；建议小于 `front_gap` |
| `interior_light_energy` | 1.1 | 室内灯光强度，≥0 |
| `wall_color` / `trim_color` | 见 JSON | 墙面 / 窗框与檐边颜色，RGBA 各分量 0～1 |
| `roof_color` / `roof_tile_color` | 见 JSON | 屋顶 / 瓦缝与屋脊颜色，RGBA 各分量 0～1 |
| `brick_color` / `window_color` / `wood_color` | 见 JSON | 砖面 / 窗玻璃 / 木地板与门、家具颜色，RGBA 各分量 0～1 |

正门的世界 X 坐标为 `-lawn.columns × lawn.cell_size / 2 - house.front_gap`，默认 **-12.6**；脚底高度使用 `lawn.surface_height`，默认 **0.025**。房屋主体从正门向负 X 延伸，不占用植物所在的格子。

调整尺寸会同步墙体、门洞、门的碰撞、屋顶和家具摆放。宽度须大于 `door_width + 2 × wall_thickness`，进深须大于 `2 × wall_thickness`，墙高须大于 `door_height + 0.15`；冲突时 `house` 整组回退并报告原因。把戴夫模型放大后，应相应增大门洞，并保留通行余量。配置保存后重新启动游戏生效；R 仍使用本次启动的配置。

## 开发与验证

- `GameConfig` 自动加载，`GameConfiguration.current()` 获取带类型的实例，适用于游戏和独立 SceneTree 测试。
- `section(path)` 返回配置副本；`entity_stats(type)` 合并公共与类型值；`apply_entity(node)` 在入树前/入树时配置一次。显式修改实体属性应放在该调用之后，重置不会反复覆盖属性。
- 所有回归测试注入内置默认快照；`tests/config_test.gd` 另用 `user://` 临时文件验证定制配置，不修改本目录文件。
- `tools/build_assets.py` 读取同一配置，用于生成场景的战斗属性和布局预览；模型仍生成基准几何，游戏启动时再应用模型配置，避免重复缩放。可用 `--config 路径` 测试场景生成。
- `scripts/game_config_defaults.gd` 是容错用的内置初始值，不需要随日常调数值修改。
- `tests/house_test.gd` 使用真实人物控制器验证自动门、进出房屋、地面接缝、前后墙体阻挡、腰部相机与重置，以及自定义、关闭和错误房屋配置；不修改用户 JSON。

运行配置测试：

```powershell
& 'C:\indie\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path C:\PROJECT\Godot\PVZ_3d --fixed-fps 60 --script res://tests/config_test.gd
```
