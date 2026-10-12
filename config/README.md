# 游戏数值配置说明

编辑本目录的 `game_config.json`，保存后停止游戏，再按 Godot **F5** 启动。游戏在启动时读取一次；运行中生成的僵尸、豌豆和掉落物使用该次启动的配置。**R** 重置交战，不重新读取文件。无需运行 Python 或重新生成模型。

文件为 UTF-8 JSON，不支持注释、尾随逗号。可以省略字段，省略部分使用内置默认值。未知字段会提示并忽略；无效字段会提示并回退。整个文件缺失、无法读取或格式错误时使用全部默认值，游戏仍可运行。提示在 Godot 的输出/调试面板中，包含文件、字段路径或解析行号。程序不会自动覆盖或修复你的 JSON。

## 最常调整的位置

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
