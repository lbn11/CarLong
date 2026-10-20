// 关卡数据的类型定义 —— 对应 `shared/levels/*.json`。
//
// 这些文件由 Flutter 侧 `tool/export_levels.dart` 生成，是跨端唯一真源。
// 任何字段改动都必须先在 Dart 侧改导出器，再重新导出；TS 侧只读不改。

export type GoalKind = 'produce' | 'clearBoard';
export type ObstacleKind = 'ice' | 'lock' | 'block' | 'teleport';
export type VehicleCategoryName =
  | 'land'
  | 'heavy'
  | 'rail'
  | 'maritime'
  | 'air'
  | 'space';

export interface VehicleDef {
  id: number;
  name: string;
  icon: string;
  /** #AARRGGBB */
  color: string;
  category: VehicleCategoryName;
  rarity: 'common' | 'rare' | 'epic' | 'legendary';
  rarityColor: string;
  ability: string;
  abilityLabel?: string;
  move: number;
  terrain: string[];
}

export interface ObstacleDef {
  type: ObstacleKind;
  c: number;
  r: number;
  /** 冰块层数（生成器默认 2） */
  l?: number;
}

export interface MergeLevelDef {
  id: number;
  name: string;
  cols: number;
  rows: number;
  /** 牌堆总张数 */
  stock: number;
  goal: GoalKind;
  /** 目标车型 id（clearBoard 时为最高档，仅作展示） */
  target: number;
  targetName: string;
  /** 目标产出数量 */
  count: number;
  /** 高等级偏置 */
  bias: number;
  /** 出生权重（下标 = 车型 id，值 = 权重）；已按目标档位截断 */
  span?: number;
  spawn: number[];
  par: number | null;
  /** 难度相位 0..4 */
  phase: number;
  /** 章节索引 */
  ch: number;
  ad?: boolean;
  wild?: number;
  bombs?: number;
  obs?: ObstacleDef[];
  moves?: number | null;
  time?: number | null;
  clearLimit?: number;
  fog?: number;
  bossSpec?: BossSpecDef;
  bossKey?: string;
}

export interface BossSpecDef {
  hp: number;
  attackInterval: number;
  firstAttack: number;
  [k: string]: unknown;
}

export interface VehicleSpawnDef {
  c: number;
  r: number;
  tier: number;
  len?: number;
  vert?: boolean;
}

export interface ParkingLevelDef {
  id: number;
  name: string;
  rows: number;
  cols: number;
  /** 每行一个字符串：e=空 r=路 p=停车位 w=水 b=障碍 */
  grid: string[];
  vehicles: VehicleSpawnDef[];
  target: number;
  targetName: string;
  minMoves: number;
  moves: number | null;
  time: number | null;
  rowHints: (number | null)[] | null;
  colHints: (number | null)[] | null;
}

export interface ChapterDef {
  title: string;
  subtitle: string;
  startId: number;
}

export interface MergeDataFile {
  schema: number;
  mode: 'merge';
  count: number;
  chapters: ChapterDef[];
  phases: string[];
  levels: MergeLevelDef[];
}

export interface ParkingDataFile {
  schema: number;
  mode: 'parking';
  count: number;
  chapters: ChapterDef[];
  phases: string[];
  levels: ParkingLevelDef[];
}

export interface VehicleDataFile {
  schema: number;
  count: number;
  categories: { name: string; label: string }[];
  rarities: { name: string; label: string; color: string }[];
  abilities: { name: string; label: string }[];
  vehicles: VehicleDef[];
}
