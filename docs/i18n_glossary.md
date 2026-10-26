# i18n 术语表

> **本文件由 `tool/check_i18n.py --glossary` 从 `lib/l10n/*.arb` 生成，不要手改。**
> 改词条去改 arb，再跑一次脚本。

术语表存在的唯一理由：868 条文案分散在 50 个文件里，
「合成」「撤销」「提示」这类词在不同文件被翻成不同英文，玩家立刻会觉得是两个人写的。
先定死这张表，再铺开翻译。

## 通用 / 游戏术语

| key | 英文 | 中文 | 说明 |
|---|---|---|---|
| `appName` | Merge Fleet | 车水马龙 | App 名。MaterialApp.title 与商店名都用它。 |
| `ok` | OK | 好的 | 通用确认按钮 |
| `cancel` | Cancel | 取消 | 通用取消按钮 |
| `close` | Close | 关闭 | 通用关闭按钮 |
| `back` | Back | 返回 | 返回 |
| `next` | Next | 下一关 | 下一步 / 下一关 |
| `retry` | Retry | 再来一次 | 重玩本关 |
| `start` | Start | 开始 | 开始 |
| `pause` | Pause | 暂停 | 暂停 |
| `resume` | Resume | 继续 | 继续（从暂停恢复） |
| `continueLabel` | Continue | 继续 | 继续。不用 continue——Dart 关键字，gen-l10n 会生成非法 getter。 |
| `giveUp` | Give Up | 放弃 | 放弃本关 |
| `claim` | Claim | 领取 | 领取奖励 |
| `watchAd` | Watch Ad | 看广告 | 看广告。 |
| `unlock` | Unlock | 解锁 | 解锁 |
| `locked` | Locked | 未解锁 | 未解锁状态 |
| `settings` | Settings | 设置 | 设置 |
| `free` | Free | 免费 | 免费 |
| `merge` | Merge | 合成 | 合成（动词/名词）。全项目统一，不要写成 combine / fuse。 |
| `level` | Level | 关卡 | 关卡（单数） |
| `levels` | Levels | 关卡 | 关卡（复数） |
| `chapter` | Chapter | 章节 | 章节 |
| `board` | Board | 棋盘 | 棋盘 |
| `deck` | Deck | 牌堆 | 牌堆 |
| `coin` | Coin | 金币 | 金币（单数） |
| `coins` | Coins | 金币 | 金币（复数） |
| `undo` | Undo | 撤销 | 撤销一步。广告位之一，与 AdPlacement.undo 同名。 |
| `hint` | Hint | 提示 | 提示。广告位之一。 |
| `move` | Move | 步 | 步数（单数） |
| `moves` | Moves | 步 | 步数（复数） |
| `time` | Time | 时间 | 时间 / 限时 |
| `target` | Target | 目标 | 目标（要合成出的车） |
| `score` | Score | 分数 | 分数 |
| `best` | Best | 最佳 | 历史最佳 |
| `combo` | Combo | 连击 | 连击 |
| `reward` | Reward | 奖励 | 奖励 |
| `chest` | Chest | 宝箱 | 宝箱（商店里用金币抽） |
| `booster` | Booster | 道具 | 道具。不要写成 item / prop。 |
| `shop` | Shop | 商店 | 商店 |
| `collection` | Collection | 图鉴 | 车辆图鉴 |
| `achievements` | Achievements | 成就 | 成就 |
| `parking` | Parking | 停车 | 停车模式 |
| `endless` | Endless | 无尽 | 无尽模式 |
| `dailyChallenge` | Daily Challenge | 每日挑战 | 每日挑战 |
| `dailyBonus` | Daily Bonus | 每日签到 | 每日签到奖励 |
| `boss` | Boss | Boss | Boss 关的首领。专有名词，不翻译。 |
| `ice` | Ice | 冰块 | 冰块障碍 |
| `glue` | Glue | 胶水 | 胶水障碍（冻住车不能动） |
| `blackHole` | Black Hole | 黑洞 | 黑洞障碍 |
| `shield` | Shield | 护盾 | Boss 护盾 |
| `enraged` | Enraged | 狂怒 | Boss 狂怒状态 |

## 车型名

| key | 英文 | 中文 | 说明 |
|---|---|---|---|
| `vehicleBicycle` | Bicycle | 自行车 | 车型名。图鉴/目标车/合成方块都显示它，要短且地道。 |
| `vehicleScooter` | Scooter | 踏板车 |  |
| `vehicleSedan` | Sedan | 轿车 |  |
| `vehicleTaxi` | Taxi | 出租车 |  |
| `vehicleBus` | Bus | 巴士 |  |
| `vehicleMotorcycle` | Motorcycle | 摩托车 |  |
| `vehicleSuv` | SUV | 越野车 |  |
| `vehicleVan` | Van | 面包车 |  |
| `vehicleAmbulance` | Ambulance | 救护车 |  |
| `vehiclePolice` | Police Car | 警车 |  |
| `vehicleFiretruck` | Fire Truck | 消防车 |  |
| `vehicleLimousine` | Limousine | 豪华轿车 |  |
| `vehicleTruck` | Truck | 卡车 |  |
| `vehicleTanker` | Tanker | 油罐车 |  |
| `vehicleBulldozer` | Bulldozer | 推土机 |  |
| `vehicleCrane` | Crane | 起重机 |  |
| `vehicleExcavator` | Excavator | 挖掘机 |  |
| `vehicleDumptruck` | Dump Truck | 自卸车 |  |
| `vehicleForklift` | Forklift | 叉车 |  |
| `vehicleCementmixer` | Cement Mixer | 搅拌车 |  |
| `vehicleTram` | Tram | 有轨电车 |  |
| `vehicleLightrail` | Light Rail | 轻轨 |  |
| `vehicleSubway` | Subway | 地铁 |  |
| `vehicleHighspeed` | High-Speed Rail | 高铁 |  |
| `vehicleMaglev` | Maglev | 磁悬浮 |  |
| `vehicleMonorail` | Monorail | 单轨 |  |
| `vehicleSteam` | Steam Train | 蒸汽火车 |  |
| `vehicleHyperloop` | Hyperloop | 超级高铁 |  |
| `vehicleDinghy` | Dinghy | 小艇 |  |
| `vehicleFishing` | Fishing Boat | 渔船 |  |
| `vehicleFerry` | Ferry | 渡轮 |  |
| `vehicleSailboat` | Sailboat | 帆船 |  |
| `vehicleSpeedboat` | Speedboat | 快艇 |  |
| `vehicleBarge` | Barge | 驳船 |  |
| `vehicleWarship` | Warship | 军舰 |  |
| `vehicleCarrier` | Aircraft Carrier | 航空母舰 |  |
| `vehicleGlider` | Glider | 滑翔机 |  |
| `vehicleHelicopter` | Helicopter | 直升机 |  |
| `vehicleDrone` | Drone | 无人机 |  |
| `vehicleAirliner` | Airliner | 客机 |  |
| `vehicleFighter` | Fighter Jet | 战斗机 |  |
| `vehicleCargo` | Cargo Plane | 运输机 |  |
| `vehicleSeaplane` | Seaplane | 水上飞机 |  |
| `vehicleStealth` | Stealth Jet | 隐身飞机 |  |
| `vehicleRocket` | Rocket | 火箭 |  |
| `vehicleSpaceShuttle` | Space Shuttle | 航天飞机 |  |
| `vehicleSpaceStation` | Space Station | 空间站 |  |
| `vehicleLunar` | Lunar Rover | 月球车 |  |
| `vehicleStarship` | Starship | 星际飞船 |  |
| `vehicleWarpShip` | Warp Ship | 曲速飞船 |  |

## 稀有度

| key | 英文 | 中文 | 说明 |
|---|---|---|---|
| `rarityCommon` | Common | 普通 | 稀有度：普通 |
| `rarityRare` | Rare | 稀有 | 稀有度：稀有 |
| `rarityEpic` | Epic | 史诗 | 稀有度：史诗 |
| `rarityLegendary` | Legendary | 传说 | 稀有度：传说 |

## 车型分类

| key | 英文 | 中文 | 说明 |
|---|---|---|---|
| `catLand` | Land | 陆地 | 车型分类：陆地 |
| `catHeavy` | Heavy | 重工 | 车型分类：重工 |
| `catRail` | Rail | 轨道 | 车型分类：轨道 |
| `catMaritime` | Maritime | 船舶 | 车型分类：船舶 |
| `catAir` | Air | 航空 | 车型分类：航空 |
| `catSpace` | Space | 星际 | 车型分类：星际 |
