// 停车模式规则层 —— 严格对齐 Dart `lib/game/parking_game.dart` 与
// `lib/logic/parking_solver.dart`。
//
// 两个必须记住的语义（改规则前先看这里）：
// 1. **一步 = 选一辆车沿直线滑到「点击方向上不越过点击格」的最远位置**，
//    不是逐格移动。玩家点多远，车就走多远，中间不停。
// 2. **只有目标档的车能进停车位**，且胜利判定是「目标车车身任一格压住停车位」。
//    长条车压住一格即算停好，不要求整辆车身落在车位里。
//
// 能力（ability）在这里是「规则的一部分」：teleport 可跳任意空格，turn 让长条车
// 四向滑动，flyOver / waterWalk 可穿过障碍格。生成器不建模能力（"无能力也可解"），
// 所以求解器走纯规则分支，见 solveParking 的 comment。
import type { ParkingLevelDef, VehicleDef } from '../data/types.ts';

export type ParkingStatus = 'playing' | 'won' | 'lost';
export type ParkingFailReason = 'moves' | 'time';

/** 格子类型字符（由导出器压成字符串：r 路 / p 车位 / o 障碍 / e 入口 / x 出口） */
export type CellChar = 'r' | 'p' | 'o' | 'e' | 'x';

export interface PVehicle {
  index: number;
  tier: number;
  row: number;
  col: number;
  /** 占用格数，1 = 单格车 */
  length: number;
  /** 车身沿行方向延伸（length === 1 时无意义，按 true 存） */
  horiz: boolean;
  /** 车身任一格压住停车位 */
  parked: boolean;
}

export type ParkingEvent =
  | {
      kind: 'move';
      vi: number;
      fromR: number;
      fromC: number;
      toR: number;
      toC: number;
      parked: boolean;
    }
  | { kind: 'blocked'; vi: number }
  | { kind: 'undo'; vi: number }
  | { kind: 'won' }
  | { kind: 'lost'; reason: ParkingFailReason };

const MOVES_MAX_UNDO = 64;

export class ParkingSession {
  readonly level: ParkingLevelDef;
  /** 静态地形：grid[r][c] */
  readonly terrain: CellChar[][];
  /** 停车位坐标（生成器保证唯一；为 null 表示数据异常） */
  readonly parkingAt: { r: number; c: number } | null;
  /** 目标档车型 id */
  readonly targetTier: number;

  vehicles: PVehicle[] = [];
  moves = 0;
  elapsed = 0;
  status: ParkingStatus = 'playing';
  failReason: ParkingFailReason | null = null;
  /** 当前选中的车（UI 用，规则层不依赖） */
  selected: number | null = null;

  /** 占用表：行优先索引 → 车辆下标，-1 表示空 */
  private readonly occ: Int16Array;
  /** 每车的车身偏移（相对 anchor），按 index 索引 */
  private readonly offR: number[][] = [];
  private readonly offC: number[][] = [];
  private readonly abilities: readonly string[];
  private readonly undoStack: {
    vi: number;
    fromR: number;
    fromC: number;
    toR: number;
    toC: number;
  }[] = [];
  private events: ParkingEvent[] = [];
  private paused = false;

  constructor(level: ParkingLevelDef, vehicles: readonly VehicleDef[]) {
    this.level = level;
    this.abilities = vehicles.map((v) => v.ability ?? 'none');
    this.targetTier = level.target;

    this.terrain = level.grid.map((row) => row.split('') as CellChar[]);

    let park: { r: number; c: number } | null = null;
    for (let r = 0; r < level.rows; r++) {
      for (let c = 0; c < level.cols; c++) {
        if (this.terrain[r][c] === 'p') park = { r, c };
      }
    }
    this.parkingAt = park;

    this.occ = new Int16Array(level.rows * level.cols).fill(-1);
    this.reset();
  }

  // ── 初始化 / 重开 ─────────────────────────────────────
  reset(): void {
    this.occ.fill(-1);
    this.vehicles = [];
    this.moves = 0;
    this.elapsed = 0;
    this.status = 'playing';
    this.failReason = null;
    this.selected = null;
    this.undoStack.length = 0;
    this.events.length = 0;
    this.offR.length = 0;
    this.offC.length = 0;

    for (let i = 0; i < this.level.vehicles.length; i++) {
      const src = this.level.vehicles[i];
      const len = src.len ?? 1;
      const horiz = len === 1 ? true : src.vert !== true;
      const v: PVehicle = {
        index: i,
        tier: src.tier,
        row: src.r,
        col: src.c,
        length: len,
        horiz,
        parked: false,
      };
      this.vehicles.push(v);

      const rs: number[] = [];
      const cs: number[] = [];
      for (let k = 0; k < len; k++) {
        rs.push(horiz ? 0 : k);
        cs.push(horiz ? k : 0);
      }
      this.offR.push(rs);
      this.offC.push(cs);

      for (let k = 0; k < len; k++) {
        const r = src.r + rs[k];
        const c = src.c + cs[k];
        this.occ[r * this.level.cols + c] = i;
      }
      v.parked = this.isOnParking(v, src.r, src.c);
    }
  }

  private isOnParking(v: PVehicle, row: number, col: number): boolean {
    const park = this.parkingAt;
    if (!park) return false;
    for (let k = 0; k < v.length; k++) {
      if (row + this.offR[v.index][k] === park.r && col + this.offC[v.index][k] === park.c) {
        return true;
      }
    }
    return false;
  }

  private isTarget(v: PVehicle): boolean {
    return v.tier === this.targetTier;
  }

  private abilityOf(tier: number): string {
    return this.abilities[tier] ?? 'none';
  }

  // ── 查询 ─────────────────────────────────────────────
  get rows(): number {
    return this.level.rows;
  }

  get cols(): number {
    return this.level.cols;
  }

  get movesLeft(): number | null {
    return this.level.moves === null ? null : this.level.moves - this.moves;
  }

  get timeLeft(): number | null {
    return this.level.time === null ? null : Math.max(0, this.level.time - this.elapsed);
  }

  get canUndo(): boolean {
    return this.undoStack.length > 0 && this.status === 'playing';
  }

  get targetVehicle(): PVehicle | undefined {
    return this.vehicles.find((v) => v.tier === this.targetTier);
  }

  vehicleAt(row: number, col: number): PVehicle | null {
    if (row < 0 || row >= this.rows || col < 0 || col >= this.cols) return null;
    const idx = this.occ[row * this.cols + col];
    return idx >= 0 ? this.vehicles[idx] : null;
  }

  cellAt(row: number, col: number): CellChar {
    return this.terrain[row][col];
  }

  /** 目标车是否已停好（any 语义，不赌目标车唯一） */
  get won(): boolean {
    return this.vehicles.some((v) => v.tier === this.targetTier && v.parked);
  }

  // ── 移动 ─────────────────────────────────────────────
  /** 能否把第 vi 辆车放到 anchor(row,col)。只校验目标位置，不校验路径
   *  —— 滑动是连续逐格，目标位置合法即路径中间态也合法。 */
  canMoveTo(vi: number, row: number, col: number): boolean {
    if (this.status !== 'playing') return false;
    const v = this.vehicles[vi];
    if (!v || v.parked) return false;
    if (row < 0 || row >= this.rows || col < 0 || col >= this.cols) return false;

    const ab = this.abilityOf(v.tier);
    const offR = this.offR[vi];
    const offC = this.offC[vi];

    if (ab === 'teleport') {
      // 跳跃：忽略滑动方向，只要求落点合法
      for (let k = 0; k < offR.length; k++) {
        const r = row + offR[k];
        const c = col + offC[k];
        if (r < 0 || r >= this.rows || c < 0 || c >= this.cols) return false;
        const t = this.terrain[r][c];
        if (t !== 'r' && t !== 'p') return false;
        const o = this.occ[r * this.cols + c];
        if (o >= 0 && o !== vi) return false;
        if (t === 'p' && !this.isTarget(v)) return false;
      }
      return true;
    }

    // 必须沿直线：长条车仅沿车身轴
    if (row !== v.row && col !== v.col) return false;
    if (v.length > 1) {
      if (v.horiz && row !== v.row) return false;
      if (!v.horiz && col !== v.col) return false;
    }

    for (let k = 0; k < offR.length; k++) {
      const r = row + offR[k];
      const c = col + offC[k];
      if (r < 0 || r >= this.rows || c < 0 || c >= this.cols) return false;
      const t = this.terrain[r][c];
      if (t !== 'r' && t !== 'p') {
        // flyOver / waterWalk / amphibious 可穿过障碍（石墩 / 水坑）
        if (ab === 'flyOver' && t === 'o') continue;
        if ((ab === 'waterWalk' || ab === 'amphibious') && t === 'o') continue;
        return false;
      }
      const o = this.occ[r * this.cols + c];
      if (o >= 0 && o !== vi) return false;
      // 停车位只有目标档的车能进
      if (t === 'p' && !this.isTarget(v)) return false;
    }
    return true;
  }

  /**
   * 点击式滑动：朝点击格方向滑到「不越过点击格」的最远可达位置。
   * 长条车车头对齐点击格（右/下方向时 anchor 要回退 length-1）。
   */
  slideTo(vi: number, tapRow: number, tapCol: number): boolean {
    if (this.status !== 'playing') return false;
    const v = this.vehicles[vi];
    if (!v || v.parked) return false;
    const canTurn = this.abilityOf(v.tier) === 'turn';
    const canH = v.length === 1 || v.horiz;
    const canV = v.length === 1 || !v.horiz;

    if ((canH || canTurn) && tapRow === v.row && tapCol !== v.col) {
      const dir = tapCol > v.col ? 1 : -1;
      const desired = v.length > 1 && dir > 0 ? tapCol - (v.length - 1) : tapCol;
      let best = v.col;
      let c = v.col + dir;
      while (desired > v.col ? c <= desired : c >= desired) {
        if (!this.canMoveTo(vi, v.row, c)) break;
        best = c;
        c += dir;
      }
      if (best === v.col) return false;
      return this.moveVehicle(vi, v.row, best);
    }

    if ((canV || canTurn) && tapCol === v.col && tapRow !== v.row) {
      const dir = tapRow > v.row ? 1 : -1;
      const desired = v.length > 1 && dir > 0 ? tapRow - (v.length - 1) : tapRow;
      let best = v.row;
      let r = v.row + dir;
      while (desired > v.row ? r <= desired : r >= desired) {
        if (!this.canMoveTo(vi, r, v.col)) break;
        best = r;
        r += dir;
      }
      if (best === v.row) return false;
      return this.moveVehicle(vi, best, v.col);
    }
    return false;
  }

  /** 直接落点（teleport 车 / 点击格本身可达时走这条） */
  jumpTo(vi: number, row: number, col: number): boolean {
    if (!this.canMoveTo(vi, row, col)) return false;
    if (row === this.vehicles[vi].row && col === this.vehicles[vi].col) return false;
    return this.moveVehicle(vi, row, col);
  }

  /** 执行移动。调用方必须先校验 canMoveTo（与 Dart 同结构）。 */
  moveVehicle(vi: number, row: number, col: number): boolean {
    if (!this.canMoveTo(vi, row, col)) return false;
    const v = this.vehicles[vi];
    const fromR = v.row;
    const fromC = v.col;

    this.undoStack.push({ vi, fromR, fromC, toR: row, toC: col });
    if (this.undoStack.length > MOVES_MAX_UNDO) this.undoStack.shift();

    this.vacate(vi, fromR, fromC);
    v.row = row;
    v.col = col;
    v.parked = this.isOnParking(v, row, col);
    this.occupy(vi, row, col);

    this.moves++;
    this.emit({
      kind: 'move',
      vi,
      fromR,
      fromC,
      toR: row,
      toC: col,
      parked: v.parked,
    });

    this.checkWin();
    if (this.status === 'playing') this.checkLose();
    return true;
  }

  private vacate(vi: number, row: number, col: number): void {
    for (let k = 0; k < this.offR[vi].length; k++) {
      const r = row + this.offR[vi][k];
      const c = col + this.offC[vi][k];
      if (r < 0 || r >= this.rows || c < 0 || c >= this.cols) continue;
      this.occ[r * this.cols + c] = -1;
    }
  }

  private occupy(vi: number, row: number, col: number): void {
    for (let k = 0; k < this.offR[vi].length; k++) {
      const r = row + this.offR[vi][k];
      const c = col + this.offC[vi][k];
      this.occ[r * this.cols + c] = vi;
    }
  }

  private checkWin(): void {
    if (this.status !== 'playing') return;
    if (!this.won) return;
    this.status = 'won';
    this.selected = null;
    this.emit({ kind: 'won' });
  }

  /** 判负：限步耗尽且无目标车停好；限时归零。死局不判负（玩家可撤销）。 */
  private checkLose(): void {
    if (this.status !== 'playing') return;
    const limit = this.level.moves;
    if (limit !== null && this.moves >= limit) {
      const targets = this.vehicles.filter((v) => v.tier === this.targetTier);
      if (targets.length && targets.some((v) => v.parked)) return;
      this.status = 'lost';
      this.failReason = 'moves';
      this.selected = null;
      this.emit({ kind: 'lost', reason: 'moves' });
    }
  }

  // ── 撤销 ─────────────────────────────────────────────
  undo(): boolean {
    const a = this.undoStack.pop();
    if (!a || this.status !== 'playing') return false;
    this.vacate(a.vi, a.toR, a.toC);
    const v = this.vehicles[a.vi];
    v.row = a.fromR;
    v.col = a.fromC;
    v.parked = this.isOnParking(v, a.fromR, a.fromC);
    this.occupy(a.vi, a.fromR, a.fromC);
    this.moves = Math.max(0, this.moves - 1);
    this.selected = a.vi;
    this.emit({ kind: 'undo', vi: a.vi });
    return true;
  }

  /** 还有没有任何一步可走（死局提示用，不判负） */
  get hasAnyMove(): boolean {
    for (const v of this.vehicles) {
      if (v.parked) continue;
      if (
        this.canMoveTo(v.index, v.row, v.col + 1) ||
        this.canMoveTo(v.index, v.row, v.col - 1) ||
        this.canMoveTo(v.index, v.row + 1, v.col) ||
        this.canMoveTo(v.index, v.row - 1, v.col)
      ) {
        return true;
      }
    }
    return false;
  }

  get isDeadlocked(): boolean {
    return this.status === 'playing' && !this.hasAnyMove;
  }

  // ── 计时 ─────────────────────────────────────────────
  tick(dt: number): void {
    if (this.status !== 'playing' || this.paused) return;
    this.elapsed += dt;
    const limit = this.level.time;
    if (limit !== null && this.elapsed >= limit) {
      this.status = 'lost';
      this.failReason = 'time';
      this.selected = null;
      this.emit({ kind: 'lost', reason: 'time' });
    }
  }

  setPaused(p: boolean): void {
    this.paused = p;
  }

  // ── 事件 ─────────────────────────────────────────────
  private emit(e: ParkingEvent): void {
    this.events.push(e);
  }

  drainEvents(): ParkingEvent[] {
    const out = this.events;
    this.events = [];
    return out;
  }

  /** 选中/取消（只影响 UI，不动规则） */
  toggleSelect(vi: number): void {
    if (this.status !== 'playing') return;
    const v = this.vehicles[vi];
    if (!v || v.parked) return;
    this.selected = this.selected === vi ? null : vi;
  }

  /**
   * 选中车在当前局面下「能滑到的 anchor 范围」——给 UI 画方向箭头用。
   * 返回每根轴上的最远可达 anchor（-1 表示不可动）。
   */
  reachOf(vi: number): { left: number; right: number; up: number; down: number } {
    const v = this.vehicles[vi];
    const out = { left: -1, right: -1, up: -1, down: -1 };
    if (!v || v.parked || this.status !== 'playing') return out;
    const canTurn = this.abilityOf(v.tier) === 'turn';
    const canH = v.length === 1 || v.horiz;
    const canV = v.length === 1 || !v.horiz;

    if (canH || canTurn) {
      let c = v.col + 1;
      while (this.canMoveTo(vi, v.row, c)) {
        out.right = c;
        c++;
      }
      c = v.col - 1;
      while (this.canMoveTo(vi, v.row, c)) {
        out.left = c;
        c--;
      }
    }
    if (canV || canTurn) {
      let r = v.row + 1;
      while (this.canMoveTo(vi, r, v.col)) {
        out.down = r;
        r++;
      }
      r = v.row - 1;
      while (this.canMoveTo(vi, r, v.col)) {
        out.up = r;
        r--;
      }
    }
    return out;
  }
}

// ── 求解器 ─────────────────────────────────────────────
// 只为两件事存在：验收（对齐 Dart 导出的 minMoves）与「提示」按钮。
// **不建模车型能力** —— 与 Dart ParkingSolver 一致，生成关保证「无能力也可解」。

export interface PSolveMove {
  vi: number;
  fromR: number;
  fromC: number;
  toR: number;
  toC: number;
}

export function solveParking(
  level: ParkingLevelDef,
  opts: { maxStates?: number } = {},
): PSolveMove[] | null {
  const maxStates = opts.maxStates ?? 200000;
  const rows = level.rows;
  const cols = level.cols;
  const keySize = rows * cols;

  let pr = -1;
  let pc = -1;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      if (level.grid[r][c] === 'p') {
        pr = r;
        pc = c;
      }
    }
  }
  if (pr < 0) return null;

  let targetIdx = -1;
  for (let i = 0; i < level.vehicles.length; i++) {
    if (level.vehicles[i].tier === level.target) {
      targetIdx = i;
      break;
    }
  }
  if (targetIdx < 0) return null;

  const n = level.vehicles.length;
  const offR: number[][] = [];
  const offC: number[][] = [];
  const canHoriz: boolean[] = [];
  const canVert: boolean[] = [];
  for (let i = 0; i < n; i++) {
    const s = level.vehicles[i];
    const len = s.len ?? 1;
    const horiz = len === 1 ? true : s.vert !== true;
    canHoriz.push(len === 1 || horiz);
    canVert.push(len === 1 || !horiz);
    const rs: number[] = [];
    const cs: number[] = [];
    for (let k = 0; k < len; k++) {
      rs.push(horiz ? 0 : k);
      cs.push(horiz ? k : 0);
    }
    offR.push(rs);
    offC.push(cs);
  }

  const passable = new Uint8Array(keySize);
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const t = level.grid[r][c];
      passable[r * cols + c] = t === 'r' || t === 'p' ? 1 : 0;
    }
  }

  const start: number[] = [];
  for (const s of level.vehicles) {
    start.push(s.r, s.c);
  }

  const wins = (coords: number[]): boolean => {
    const r = coords[targetIdx * 2];
    const c = coords[targetIdx * 2 + 1];
    for (let k = 0; k < offR[targetIdx].length; k++) {
      if (r + offR[targetIdx][k] === pr && c + offC[targetIdx][k] === pc) return true;
    }
    return false;
  };
  if (wins(start)) return [];

  const occ = new Int16Array(keySize);
  const fillOcc = (coords: number[], skip: number): void => {
    occ.fill(-1);
    for (let i = 0; i < n; i++) {
      if (i === skip) continue;
      const r = coords[i * 2];
      const c = coords[i * 2 + 1];
      for (let k = 0; k < offR[i].length; k++) {
        occ[(r + offR[i][k]) * cols + (c + offC[i][k])] = i;
      }
    }
  };

  const enc = (coords: number[]): string => coords.join(',');

  const queue: number[][] = [start];
  let head = 0;
  const visited = new Set<string>([enc(start)]);
  const parent = new Map<string, string>();
  const moveOf = new Map<string, PSolveMove>();

  let states = 0;
  while (head < queue.length) {
    const coords = queue[head++];
    states++;
    if (states > maxStates) return null;
    fillOcc(coords, -1);
    const curKey = enc(coords);

    for (let vi = 0; vi < n; vi++) {
      const r0 = coords[vi * 2];
      const c0 = coords[vi * 2 + 1];
      // 腾出本车占格
      for (let k = 0; k < offR[vi].length; k++) {
        occ[(r0 + offR[vi][k]) * cols + (c0 + offC[vi][k])] = -1;
      }
      const dirs: [number, number][] = [];
      if (canHoriz[vi]) dirs.push([0, 1], [0, -1]);
      if (canVert[vi]) dirs.push([1, 0], [-1, 0]);

      for (const [dr, dc] of dirs) {
        let nr = r0 + dr;
        let nc = c0 + dc;
        while (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          let ok = true;
          let hitsParking = false;
          for (let k = 0; k < offR[vi].length; k++) {
            const br = nr + offR[vi][k];
            const bc = nc + offC[vi][k];
            if (br < 0 || br >= rows || bc < 0 || bc >= cols) {
              ok = false;
              break;
            }
            const idx = br * cols + bc;
            if (!passable[idx] || occ[idx] >= 0) {
              ok = false;
              break;
            }
            if (vi !== targetIdx && br === pr && bc === pc) {
              ok = false;
              break;
            }
            if (vi === targetIdx && br === pr && bc === pc) hitsParking = true;
          }
          if (!ok) break;

          const next = coords.slice();
          next[vi * 2] = nr;
          next[vi * 2 + 1] = nc;
          const key = enc(next);
          if (!visited.has(key)) {
            visited.add(key);
            parent.set(key, curKey);
            moveOf.set(key, { vi, fromR: r0, fromC: c0, toR: nr, toC: nc });
            if (hitsParking) {
              // 回溯
              const path: PSolveMove[] = [];
              let cur = key;
              while (cur !== enc(start)) {
                const mv = moveOf.get(cur);
                if (!mv) break;
                path.push(mv);
                cur = parent.get(cur)!;
              }
              path.reverse();
              return path;
            }
            queue.push(next);
          }
          nr += dr;
          nc += dc;
        }
      }
      // 恢复本车占格
      for (let k = 0; k < offR[vi].length; k++) {
        occ[(r0 + offR[vi][k]) * cols + (c0 + offC[vi][k])] = vi;
      }
    }
  }
  return null;
}

/** 最短步数；无解返回 null */
export function minMovesOf(level: ParkingLevelDef, maxStates?: number): number | null {
  return solveParking(level, maxStates === undefined ? {} : { maxStates })?.length ?? null;
}
