// 纯逻辑棋盘 —— 1:1 移植自 Flutter 侧 `lib/logic/board_logic.dart`。
//
// 移植纪律：**任何规则改动必须先改 Dart 再改这里**，两边行为必须逐字节
// 等价（同一关同一操作序列要得出同一结果）。因此这里的注释保留 Dart 侧
// 的设计理由，不重写。
//
// 不依赖任何渲染 / DOM / 平台 API，可以直接在 node 里单测。
import type { MergeLevelDef, ObstacleKind } from '../data/types.ts';
import { Rng } from './rng.ts';
import { copyStack, isEmptyStack, isLocked, makeStack, type Stack } from './stack.ts';

export interface Obstacle {
  type: ObstacleKind;
  col: number;
  row: number;
  /** 冰块剩余层数；其余类型忽略 */
  layers: number;
  removed: boolean;
}

export const obstacleActive = (o: Obstacle): boolean =>
  !o.removed && (o.type !== 'ice' || o.layers > 0);

export interface MoveResult {
  valid: boolean;
  upgraded: boolean;
  upgradeAt: { col: number; row: number } | null;
  producedTarget: boolean;
  meltedIce: { col: number; row: number }[];
  teleported: boolean;
  detonated: boolean;
  detonatedAt: { col: number; row: number } | null;
  detonatedCells: { col: number; row: number }[];
  /** 被黑洞吞掉（阶段二 Boss 用） */
  swallowed: boolean;
}

const EMPTY_RESULT: MoveResult = {
  valid: false,
  upgraded: false,
  upgradeAt: null,
  producedTarget: false,
  meltedIce: [],
  teleported: false,
  detonated: false,
  detonatedAt: null,
  detonatedCells: [],
  swallowed: false,
};

export interface BoardSnapshot {
  grid: (Stack | null)[];
  producedCount: number;
  totalMerges: number;
  obstacles: Obstacle[];
  fogFlags: boolean[];
}

const NEIGHBORS: readonly [number, number][] = [
  [1, 0],
  [-1, 0],
  [0, 1],
  [0, -1],
];

export class Board {
  readonly level: MergeLevelDef;
  readonly cols: number;
  readonly rows: number;
  private readonly rng: Rng;
  private grid: (Stack | null)[];
  private obstacles: Obstacle[];
  private spawnWeightsArr: number[];
  private teleportPair = new Map<number, number>();
  private fogFlags: boolean[];
  private holes = new Map<number, number>(); // 索引 -> 剩余秒数
  private possibleMoveCache: boolean | null = null;
  /** 各档车的特殊能力（下标 = 车型 id），由车型表注入 */
  private readonly abilities: readonly string[];

  producedCount = 0;
  totalMerges = 0;

  constructor(level: MergeLevelDef, rng: Rng, abilities: readonly string[]) {
    this.level = level;
    this.cols = level.cols;
    this.rows = level.rows;
    this.rng = rng;
    this.abilities = abilities;
    this.grid = new Array(level.cols * level.rows).fill(null);
    this.spawnWeightsArr = level.spawn.slice();
    this.fogFlags = new Array(level.cols * level.rows).fill(false);
    this.obstacles = (level.obs ?? []).map((o) => ({
      type: o.type,
      col: o.c,
      row: o.r,
      layers: o.l ?? 2,
      removed: false,
    }));

    const ports: number[] = [];
    for (const o of this.obstacles) {
      if (o.type === 'teleport' && !o.removed) ports.push(this.idx(o.col, o.row));
    }
    for (let i = 0; i + 1 < ports.length; i += 2) {
      this.teleportPair.set(ports[i], ports[i + 1]);
      this.teleportPair.set(ports[i + 1], ports[i]);
    }
  }

  private idx(col: number, row: number): number {
    return row * this.cols + col;
  }

  at(col: number, row: number): Stack | null {
    if (col < 0 || col >= this.cols || row < 0 || row >= this.rows) return null;
    return this.grid[this.idx(col, row)];
  }

  obstacleAt(col: number, row: number): Obstacle | null {
    for (const o of this.obstacles) {
      if (o.col === col && o.row === row && obstacleActive(o)) return o;
    }
    return null;
  }

  get allObstacles(): readonly Obstacle[] {
    return this.obstacles;
  }

  holeAt(col: number, row: number): boolean {
    return this.holes.has(this.idx(col, row));
  }

  private usable(col: number, row: number): boolean {
    return this.obstacleAt(col, row) === null && !this.holeAt(col, row);
  }

  private invalidate(): void {
    this.possibleMoveCache = null;
  }

  placeAt(col: number, row: number, data: Stack): void {
    this.grid[this.idx(col, row)] = data;
    this.invalidate();
  }

  /** 占格总数（不含空堆） */
  get tileCount(): number {
    let n = 0;
    for (const s of this.grid) if (s && !isEmptyStack(s)) n++;
    return n;
  }

  get isFull(): boolean {
    for (let c = 0; c < this.cols; c++) {
      for (let r = 0; r < this.rows; r++) {
        if (isEmptyStack(this.grid[this.idx(c, r)]) && this.usable(c, r)) return false;
      }
    }
    return true;
  }

  get isEmpty(): boolean {
    return this.tileCount === 0;
  }

  get isTargetReached(): boolean {
    return this.producedCount >= this.level.count;
  }

  /**
   * 智能落点：优先放在同等级普通卡的四邻空格（为下一步合成铺路），
   * 其次万能卡邻格，都没有则退回随机空格。满盘返回 null。
   */
  placeTierSmart(tier: number): { col: number; row: number } | null {
    if (this.isFull) return null;
    const empties: { col: number; row: number }[] = [];
    const nextToSame: { col: number; row: number }[] = [];
    const nextToWild: { col: number; row: number }[] = [];
    for (let c = 0; c < this.cols; c++) {
      for (let r = 0; r < this.rows; r++) {
        const s = this.grid[this.idx(c, r)];
        if (isEmptyStack(s) && this.usable(c, r)) {
          empties.push({ col: c, row: r });
          for (const [dc, dr] of NEIGHBORS) {
            const nc = c + dc;
            const nr = r + dr;
            if (nc < 0 || nc >= this.cols || nr < 0 || nr >= this.rows) continue;
            const adj = this.grid[this.idx(nc, nr)];
            if (isEmptyStack(adj)) continue;
            if (!adj!.isBomb && adj!.tier === tier) {
              nextToSame.push({ col: c, row: r });
              break;
            }
            if (adj!.isWildcard) {
              nextToWild.push({ col: c, row: r });
              break;
            }
          }
        }
      }
    }
    const pool = nextToSame.length ? nextToSame : nextToWild.length ? nextToWild : empties;
    if (!pool.length) return null;
    const cell = pool[this.rng.int(pool.length)];
    this.grid[this.idx(cell.col, cell.row)] = makeStack(tier);
    this.invalidate();
    return cell;
  }

  /**
   * 在随机空格放入指定档位（纯随机，不做智能落点）。
   * 对齐 Dart `BoardLogic.placeTier`：开局垫底车辆用它，保证与 App 端同序。
   */
  placeTier(tier: number): { col: number; row: number } | null {
    const cell = this.randomEmptyCell();
    if (!cell) return null;
    this.grid[this.idx(cell.col, cell.row)] = makeStack(tier);
    this.invalidate();
    return cell;
  }

  /** 在随机空格放一张万能卡；满盘返回 null */
  placeWildcard(): { col: number; row: number } | null {
    const cell = this.randomEmptyCell();
    if (!cell) return null;
    this.grid[this.idx(cell.col, cell.row)] = makeStack(0, { isWildcard: true });
    this.invalidate();
    return cell;
  }

  /** 在随机空格放一张炸弹卡；满盘返回 null */
  placeBomb(): { col: number; row: number } | null {
    const cell = this.randomEmptyCell();
    if (!cell) return null;
    this.grid[this.idx(cell.col, cell.row)] = makeStack(0, { isBomb: true });
    this.invalidate();
    return cell;
  }

  private randomEmptyCell(): { col: number; row: number } | null {
    if (this.isFull) return null;
    const empties: { col: number; row: number }[] = [];
    for (let c = 0; c < this.cols; c++) {
      for (let r = 0; r < this.rows; r++) {
        if (isEmptyStack(this.grid[this.idx(c, r)]) && this.usable(c, r)) {
          empties.push({ col: c, row: r });
        }
      }
    }
    if (!empties.length) return null;
    return empties[this.rng.int(empties.length)];
  }

  /**
   * 把 (fc,fr) 的卡移动到 (tc,tr)。
   *  - 目标为空：移动
   *  - 目标同等级：合并（够 3 升级）
   *  - 目标不同等级：交换
   *  - 目标格有生效障碍：不可进入（冰块需在相邻格合成融化）
   *  - 目标格是传送门：从配对出口出现
   *  - 万能卡可与任意卡合并；炸弹只与炸弹合并
   */
  move(fc: number, fr: number, tc: number, tr: number): MoveResult {
    this.invalidate();
    const from = this.at(fc, fr);
    if (!from || (fc === tc && fr === tr)) return EMPTY_RESULT;
    if (isLocked(from)) return EMPTY_RESULT;

    let teleported = false;
    const exit = this.teleportPair.get(this.idx(tc, tr));
    if (exit !== undefined) {
      tc = exit % this.cols;
      tr = Math.floor(exit / this.cols);
      teleported = true;
    }
    if (fc === tc && fr === tr) return EMPTY_RESULT;

    if (this.holeAt(tc, tr)) {
      this.grid[this.idx(fc, fr)] = null;
      return { ...EMPTY_RESULT, valid: true, swallowed: true, teleported };
    }

    if (!this.usable(tc, tr)) {
      // flyOver 能力：忽略障碍物，允许降落
      const moverAbility = this.abilityOf(from.tier);
      if (moverAbility === 'flyOver') {
        // 允许
      } else if (!teleported || this.obstacleAt(tc, tr)?.type !== 'teleport') {
        return EMPTY_RESULT;
      }
    }

    const target = this.grid[this.idx(tc, tr)];
    if (target && isLocked(target)) return EMPTY_RESULT;
    if (!target) {
      this.grid[this.idx(tc, tr)] = from;
      this.grid[this.idx(fc, fr)] = null;
      this.invalidate();
      return { ...EMPTY_RESULT, valid: true, teleported };
    }

    // 炸弹：只与炸弹合并，集满 3 引爆
    if (from.isBomb || target.isBomb) {
      if (from.isBomb && target.isBomb) {
        target.count += from.count;
        this.grid[this.idx(fc, fr)] = null;
        this.totalMerges++;
        if (target.count >= 3) {
          const cleared = this.detonateBomb(tc, tr);
          this.invalidate();
          return {
            ...EMPTY_RESULT,
            valid: true,
            detonated: true,
            detonatedAt: { col: tc, row: tr },
            detonatedCells: cleared,
            teleported,
          };
        }
        this.invalidate();
        return { ...EMPTY_RESULT, valid: true, teleported };
      }
      // 炸弹与普通卡：交换
      this.grid[this.idx(tc, tr)] = from;
      this.grid[this.idx(fc, fr)] = target;
      this.invalidate();
      return { ...EMPTY_RESULT, valid: true, teleported };
    }

    // 万能卡：与任意卡片合并（等效为该等级 1 张）
    if (from.isWildcard || target.isWildcard) {
      if (from.isWildcard && target.isWildcard) {
        target.count += from.count;
        this.grid[this.idx(fc, fr)] = null;
      } else if (from.isWildcard) {
        target.count += 1;
        this.grid[this.idx(fc, fr)] = null;
      } else {
        target.tier = from.tier;
        target.isWildcard = false;
        target.count += from.count;
        this.grid[this.idx(fc, fr)] = null;
      }
      return this.completeMerge(target, tc, tr, teleported);
    }

    if (target.tier === from.tier) {
      target.count += from.count;
      this.grid[this.idx(fc, fr)] = null;
      return this.completeMerge(target, tc, tr, teleported);
    }

    // 交换
    this.grid[this.idx(tc, tr)] = from;
    this.grid[this.idx(fc, fr)] = target;
    this.invalidate();
    return { ...EMPTY_RESULT, valid: true, teleported };
  }

  /** 合并后的公共结算：升级判断、目标计数、融化四邻冰/冻 */
  private completeMerge(target: Stack, tc: number, tr: number, teleported: boolean): MoveResult {
    let upgraded = false;
    if (target.count >= 3) {
      upgraded = true;
      const next = target.tier + 1;
      if (next >= this.vehicleCount) {
        // 最高级：产出后清除。必须清掉——clearBoard 关的胜利条件是
        // 「牌堆空 && 残留 ≤ clearLimit」，若最高级永久占格，残堆永远
        // 无法减少，那些关将数学上不可通关。
        target.count = 0;
      } else {
        target.tier = next;
        target.count = 1;
      }
    }
    this.totalMerges++;
    let produced = false;
    if (this.level.goal === 'produce' && upgraded && target.tier === this.level.target) {
      this.producedCount++;
      produced = true;
    }
    const meltedIce = this.meltAdjacentIce(tc, tr, target.tier);
    this.meltAdjacentFrozen(tc, tr);
    this.invalidate();
    return {
      ...EMPTY_RESULT,
      valid: true,
      upgraded,
      upgradeAt: { col: tc, row: tr },
      producedTarget: produced,
      meltedIce,
      teleported,
    };
  }

  /** 炸弹引爆：清空 3×3 内卡片与冰/锁（石块与传送门保留） */
  private detonateBomb(c: number, r: number): { col: number; row: number }[] {
    const cleared: { col: number; row: number }[] = [];
    for (let dc = -1; dc <= 1; dc++) {
      for (let dr = -1; dr <= 1; dr++) {
        const nc = c + dc;
        const nr = r + dr;
        if (nc < 0 || nc >= this.cols || nr < 0 || nr >= this.rows) continue;
        if (this.grid[this.idx(nc, nr)]) {
          this.grid[this.idx(nc, nr)] = null;
          cleared.push({ col: nc, row: nr });
        }
        for (const o of this.obstacles) {
          if (o.col === nc && o.row === nr && obstacleActive(o) && (o.type === 'ice' || o.type === 'lock')) {
            o.removed = true;
            o.layers = 0;
            break;
          }
        }
      }
    }
    return cleared;
  }

  /** 合并发生在 (c,r)：四邻被冰封的车融 1 层（救它要合两次） */
  private meltAdjacentFrozen(c: number, r: number): void {
    for (const [dc, dr] of NEIGHBORS) {
      const nc = c + dc;
      const nr = r + dr;
      if (nc < 0 || nc >= this.cols || nr < 0 || nr >= this.rows) continue;
      const s = this.grid[this.idx(nc, nr)];
      if (s && s.frozen > 0) s.frozen -= 1;
    }
  }

  /** 合并后消融四邻障碍，返回完全融化/移除的格子 */
  private meltAdjacentIce(c: number, r: number, moverTier: number): { col: number; row: number }[] {
    const melted: { col: number; row: number }[] = [];
    const ability = this.abilityOf(moverTier);
    for (const [dc, dr] of NEIGHBORS) {
      const nc = c + dc;
      const nr = r + dr;
      if (nc < 0 || nc >= this.cols || nr < 0 || nr >= this.rows) continue;
      for (const o of this.obstacles) {
        if (o.col !== nc || o.row !== nr) continue;
        if (ability === 'breakIce' && o.type === 'ice' && o.layers > 0) {
          o.layers = 0;
          o.removed = true;
          melted.push({ col: nc, row: nr });
          break;
        }
        if (ability === 'breakChain' && o.type === 'lock' && !o.removed) {
          o.removed = true;
          melted.push({ col: nc, row: nr });
          break;
        }
        if (ability === 'clearRock' && o.type === 'block' && !o.removed) {
          o.removed = true;
          melted.push({ col: nc, row: nr });
          break;
        }
        if (o.type === 'ice' && o.layers > 0) {
          o.layers--;
          if (o.layers <= 0) melted.push({ col: nc, row: nr });
          break;
        }
      }
    }
    return melted;
  }

  /** 车型能力（车型表在构造时注入，board 不持有美术/文案） */
  private abilityOf(tier: number): string {
    return this.abilities[tier] ?? 'none';
  }

  get vehicleCount(): number {
    return this.abilities.length;
  }

  /** 用锤子清除指定格锁链，返回被移除的障碍 */
  removeLockAt(col: number, row: number): Obstacle | null {
    for (const o of this.obstacles) {
      if (o.col === col && o.row === row && o.type === 'lock' && !o.removed) {
        o.removed = true;
        return o;
      }
    }
    return null;
  }

  /**
   * 是否存在任意可合并操作（死局检测 / 提示）。
   * 规则必须与 move 严格一致：**格对格合并，任意两张同档车点哪都能合，
   * 不看距离、不看空格通路**。旧实现要求 BFS 通路，会把被车墙隔开的
   * 同档对误判成「无路可走」，牌堆空时直接误判负。
   */
  get hasPossibleMove(): boolean {
    if (this.possibleMoveCache !== null) return this.possibleMoveCache;
    const r = this.computePossibleMove();
    this.possibleMoveCache = r;
    return r;
  }

  private computePossibleMove(): boolean {
    let wildcards = 0;
    let bombs = 0;
    const stacksByTier = new Map<number, number>();
    let normalStacks = 0;
    for (const s of this.grid) {
      if (!s || isEmptyStack(s)) continue;
      if (isLocked(s)) continue;
      if (s.isWildcard) wildcards += s.count;
      else if (s.isBomb) bombs += s.count;
      else {
        // 数**堆数**不是 count：单堆 count=2 无法自己合自己
        stacksByTier.set(s.tier, (stacksByTier.get(s.tier) ?? 0) + 1);
        normalStacks += 1;
      }
    }
    if (wildcards >= 2) return true;
    if (bombs >= 2) return true;
    if (wildcards >= 1 && normalStacks >= 1) return true;
    for (const n of stacksByTier.values()) if (n >= 2) return true;
    return false;
  }

  /** 迷雾：本端先只做标记（阶段二随 Boss fog 一起接视觉） */
  isFogged(col: number, row: number): boolean {
    return this.fogFlags[this.idx(col, row)];
  }

  setFogged(col: number, row: number, v: boolean): void {
    this.fogFlags[this.idx(col, row)] = v;
  }

  /** 撤销快照 */
  snapshot(): BoardSnapshot {
    return {
      grid: this.grid.map((s) => (s ? copyStack(s) : null)),
      producedCount: this.producedCount,
      totalMerges: this.totalMerges,
      obstacles: this.obstacles.map((o) => ({ ...o })),
      fogFlags: this.fogFlags.slice(),
    };
  }

  restore(snap: BoardSnapshot): void {
    this.grid = snap.grid.map((s) => (s ? copyStack(s) : null));
    this.producedCount = snap.producedCount;
    this.totalMerges = snap.totalMerges;
    this.obstacles = snap.obstacles.map((o) => ({ ...o }));
    this.fogFlags = snap.fogFlags.slice();
    this.invalidate();
  }

  /**
   * 移除棋盘上等级最低的一张普通卡（死局兜底 / 清道夫关）。
   * 返回被移除的格子。
   */
  removeLowest(): { col: number; row: number } | null {
    let best: { col: number; row: number; tier: number } | null = null;
    for (let c = 0; c < this.cols; c++) {
      for (let r = 0; r < this.rows; r++) {
        const s = this.grid[this.idx(c, r)];
        if (!s || isEmptyStack(s) || s.isWildcard || s.isBomb || isLocked(s)) continue;
        if (!best || s.tier < best.tier) best = { col: c, row: r, tier: s.tier };
      }
    }
    if (!best) return null;
    this.grid[this.idx(best.col, best.row)] = null;
    this.invalidate();
    return { col: best.col, row: best.row };
  }

  /** 所有可用空格（供 UI 提示） */
  emptyCells(): { col: number; row: number }[] {
    const out: { col: number; row: number }[] = [];
    for (let c = 0; c < this.cols; c++) {
      for (let r = 0; r < this.rows; r++) {
        if (isEmptyStack(this.grid[this.idx(c, r)]) && this.usable(c, r)) out.push({ col: c, row: r });
      }
    }
    return out;
  }

  /** 供渲染层只读访问（不暴露可变引用给外部逻辑） */
  forEachCell(fn: (col: number, row: number, s: Stack | null) => void): void {
    for (let c = 0; c < this.cols; c++) {
      for (let r = 0; r < this.rows; r++) fn(c, r, this.grid[this.idx(c, r)]);
    }
  }

  /** 出牌权重（截断后的数组，下标即车型 id） */
  get spawnWeights(): readonly number[] {
    return this.spawnWeightsArr;
  }

  /** 按出生权重抽一档车（与 Dart `_weightedTier` 同序列） */
  randomTier(): number {
    return this.rng.weighted(this.spawnWeightsArr);
  }

  /**
   * 提示一步：返回一个「立即能合并/引爆」的操作，供高亮与文案提示。
   * 优先级：炸弹对炸弹 → 普通卡 + 万能卡 → 任意两张同等级卡。
   */
  hintMove(): { fc: number; fr: number; tc: number; tr: number } | null {
    const pos = (i: number) => ({ c: i % this.cols, r: Math.floor(i / this.cols) });
    // 1) 任意两颗炸弹
    let firstBomb = -1;
    for (let i = 0; i < this.grid.length; i++) {
      const s = this.grid[i];
      if (s && s.isBomb && !isLocked(s)) {
        if (firstBomb < 0) firstBomb = i;
        else {
          const a = pos(firstBomb);
          const b = pos(i);
          return { fc: a.c, fr: a.r, tc: b.c, tr: b.r };
        }
      }
    }
    // 2) 万能卡 + 任意普通卡
    let firstWild = -1;
    let firstNormal = -1;
    for (let i = 0; i < this.grid.length; i++) {
      const s = this.grid[i];
      if (!s || isEmptyStack(s) || isLocked(s)) continue;
      if (s.isWildcard) {
        if (firstWild < 0) firstWild = i;
      } else if (!s.isBomb) {
        if (firstNormal < 0) firstNormal = i;
      }
    }
    if (firstWild >= 0 && firstNormal >= 0) {
      const a = pos(firstNormal);
      const b = pos(firstWild);
      return { fc: a.c, fr: a.r, tc: b.c, tr: b.r };
    }
    // 3) 任意两张同等级普通卡
    for (let i = 0; i < this.grid.length; i++) {
      const s = this.grid[i];
      if (!s || isEmptyStack(s) || s.isWildcard || s.isBomb || isLocked(s)) continue;
      for (let j = i + 1; j < this.grid.length; j++) {
        const t = this.grid[j];
        if (!t || isEmptyStack(t) || t.isWildcard || t.isBomb || isLocked(t)) continue;
        if (t.tier === s.tier) {
          const a = pos(i);
          const b = pos(j);
          return { fc: a.c, fr: a.r, tc: b.c, tr: b.r };
        }
      }
    }
    return null;
  }
}

export { EMPTY_RESULT };
