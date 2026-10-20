// 一局合成的运行时状态（不含任何渲染）。
//
// 对应 Flutter 侧 `MergeGame` 里的规则部分：牌堆、出牌、选中/移动、
// 目标推进、限步限时、死局判定、撤销。渲染层只读这里的状态并喂输入。
import type { MergeLevelDef, VehicleDef } from '../data/types.ts';
import { Board } from './board.ts';
import { Rng, seedOf } from './rng.ts';
import { isEmptyStack, isLocked, type Cell } from './stack.ts';

export type SessionStatus = 'playing' | 'won' | 'lost';
export type FailReason = 'moves' | 'time' | 'deadEnd' | 'full';
export type SessionEvent =
  | { type: 'draw'; tier: number; at: Cell }
  | { type: 'move'; from: Cell; to: Cell }
  | { type: 'swap'; from: Cell; to: Cell }
  | { type: 'merge'; tier: number; at: Cell; combo: number }
  | { type: 'produced'; at: Cell; count: number }
  | { type: 'melt'; cells: Cell[] }
  | { type: 'detonate'; at: Cell; cells: Cell[] }
  | { type: 'teleport' }
  | { type: 'undo' }
  | { type: 'blocked'; reason: string }
  | { type: 'end'; status: SessionStatus; reason?: FailReason };

interface UndoSnapshot {
  board: ReturnType<Board['snapshot']>;
  deck: number[];
  movesLeft: number | null;
  timeLeft: number | null;
}

const COMBO_WINDOW = 1.6;
const MAX_UNDO = 8;

export class MergeSession {
  readonly level: MergeLevelDef;
  readonly vehicles: readonly VehicleDef[];
  readonly board: Board;

  deck: number[] = [];
  status: SessionStatus = 'playing';
  failReason: FailReason | null = null;

  movesLeft: number | null;
  timeLeft: number | null;

  /** 当前选中格（tap-tap 交互） */
  selected: Cell | null = null;

  combo = 0;
  maxCombo = 0;
  private comboTimer = 0;

  /** 本次操作要播的动画事件，UI 每帧取走 */
  readonly events: SessionEvent[] = [];
  private undoStack: UndoSnapshot[] = [];

  constructor(level: MergeLevelDef, vehicles: readonly VehicleDef[]) {
    this.level = level;
    this.vehicles = vehicles;
    const abilities = vehicles.map((v) => v.ability);
    const rng = new Rng(seedOf(level.id, 1));
    this.board = new Board(level, rng, abilities);
    this.movesLeft = level.moves ?? null;
    this.timeLeft = level.time ?? null;

    // 开局垫底：对齐 Dart `MergeGame.onLoad` —— 先铺几张随机车，让玩家一进场
    // 就能合成，而不是面对 12 个空格子（曾因此被当成"游戏里没有车"）。
    const seedCount = Math.max(1, Math.min(4, Math.floor((level.cols * level.rows) / 4)));
    for (let i = 0; i < seedCount; i++) {
      if (!this.board.placeTier(this.board.randomTier())) break;
    }

    // 开局特化卡
    for (let i = 0; i < (level.wild ?? 0); i++) this.board.placeWildcard();
    for (let i = 0; i < (level.bombs ?? 0); i++) this.board.placeBomb();

    // 牌堆一次性生成（与 Dart 侧一致：开局定死整副牌，不是边玩边抽）
    for (let i = 0; i < level.stock; i++) this.deck.push(this.board.randomTier());

    // 极端配置（如 stock=0）开局就该定胜负，不要等到玩家点第一下
    this.checkGoalNow();
  }

  // ── 查询 ──────────────────────────────────────────────
  get stockLeft(): number {
    return this.deck.length;
  }

  /** 牌堆顶部 3 张预览 */
  get preview(): number[] {
    return this.deck.slice(0, 3);
  }

  get canUndo(): boolean {
    return this.undoStack.length > 0 && this.status === 'playing';
  }

  get targetTier(): VehicleDef | undefined {
    return this.vehicles[this.level.target];
  }

  /** 目标进度 0..1 */
  get goalProgress(): number {
    if (this.level.goal === 'clearBoard') {
      const limit = this.level.clearLimit ?? 0;
      if (this.deck.length > 0) return 0;
      // 清道夫关：牌堆抽完才开始结算残留，之前按抽牌进度展示
      return this.board.tileCount <= limit ? 1 : 0.5;
    }
    return Math.min(1, this.board.producedCount / Math.max(1, this.level.count));
  }

  // ── 操作 ──────────────────────────────────────────────
  /** 点牌堆：直接出牌到智能落点（一键出牌，不做两段式） */
  draw(index = 0): boolean {
    if (this.status !== 'playing') return false;
    if (!this.deck.length) {
      this.emit({ type: 'blocked', reason: '牌堆空了' });
      return false;
    }
    if (this.board.isFull) {
      this.emit({ type: 'blocked', reason: '棋盘满了，先合成腾位置' });
      return false;
    }
    this.pushUndo();
    const i = Math.max(0, Math.min(index, this.deck.length - 1));
    const tier = this.deck.splice(i, 1)[0];
    const cell = this.board.placeTierSmart(tier);
    if (!cell) {
      this.deck.splice(i, 0, tier);
      this.emit({ type: 'blocked', reason: '落不下牌' });
      return false;
    }
    this.emit({ type: 'draw', tier, at: cell });
    this.consumeMove();
    this.checkGoalNow();
    return true;
  }

  /** 点棋盘：先选中，再点目标格执行移动/合并 */
  tapCell(col: number, row: number): void {
    if (this.status !== 'playing') return;
    const s = this.board.at(col, row);
    const sel = this.selected;

    if (!sel) {
      if (!s || isEmptyStack(s)) return;
      if (isLocked(s)) {
        this.emit({ type: 'blocked', reason: s.frozen > 0 ? '❄ 冰封中，先在旁边合并救它' : '🍯 被粘住了，等一会儿' });
        return;
      }
      this.selected = { col, row };
      return;
    }

    if (sel.col === col && sel.row === row) {
      this.selected = null;
      return;
    }

    const from = this.board.at(sel.col, sel.row);
    if (!from || isEmptyStack(from)) {
      this.selected = null;
      return;
    }

    this.pushUndo();
    const res = this.board.move(sel.col, sel.row, col, row);
    if (!res.valid) {
      this.undoStack.pop();
      // 点到另一张卡 = 改选，而不是报错
      if (s && !isEmptyStack(s) && !isLocked(s)) {
        this.selected = { col, row };
      } else {
        this.selected = null;
        this.emit({ type: 'blocked', reason: '这一步走不了' });
      }
      return;
    }

    this.selected = null;
    if (res.teleported) this.emit({ type: 'teleport' });
    if (res.detonated) {
      this.emit({ type: 'detonate', at: res.detonatedAt ?? { col, row }, cells: res.detonatedCells });
    }
    if (res.upgraded) {
      this.bumpCombo();
      this.emit({ type: 'merge', tier: this.board.at(col, row)?.tier ?? 0, at: { col, row }, combo: this.combo });
    } else if (res.valid && !res.detonated) {
      this.resetCombo();
      this.emit({ type: 'move', from: { col: sel.col, row: sel.row }, to: { col, row } });
    }
    if (res.producedTarget) {
      this.emit({ type: 'produced', at: { col, row }, count: this.board.producedCount });
    }
    if (res.meltedIce.length) this.emit({ type: 'melt', cells: res.meltedIce });

    this.consumeMove();
    this.checkGoalNow();
  }

  /** 提示：返回建议的一步（UI 高亮用） */
  hint(): { fc: number; fr: number; tc: number; tr: number } | null {
    return this.board.hintMove();
  }

  undo(): boolean {
    if (!this.canUndo) return false;
    const snap = this.undoStack.pop()!;
    this.board.restore(snap.board);
    this.deck = snap.deck.slice();
    this.movesLeft = snap.movesLeft;
    this.timeLeft = snap.timeLeft;
    this.selected = null;
    this.resetCombo();
    this.status = 'playing';
    this.failReason = null;
    this.emit({ type: 'undo' });
    return true;
  }

  /** 每帧推进（计时 / 连消窗口 / Boss 计时） */
  tick(dt: number): void {
    if (this.comboTimer > 0) {
      this.comboTimer -= dt;
      if (this.comboTimer <= 0 && this.combo > 0) this.resetCombo();
    }
    if (this.status !== 'playing') return;
    if (this.timeLeft !== null) {
      this.timeLeft = Math.max(0, this.timeLeft - dt);
      if (this.timeLeft <= 0) this.end('lost', 'time');
    }
  }

  // ── 内部 ──────────────────────────────────────────────
  private consumeMove(): void {
    if (this.movesLeft === null) return;
    if (this.movesLeft > 0) this.movesLeft--;
    if (this.movesLeft <= 0) this.checkGoalNow();
  }

  /**
   * 达成即结算 —— 不等下一帧。
   *
   * 这是「到了关卡任务没退出」那个 bug 的修法：判定原本挂在 game loop 的
   * update 里，页面态停摆或掉帧时会延迟几秒才结算，玩家会以为没达成。
   * 改成「每次改变状态后立刻补判」。
   */
  private checkGoalNow(): void {
    if (this.status !== 'playing') return;
    if (this.level.goal === 'produce') {
      if (this.board.producedCount >= this.level.count) {
        this.end('won');
        return;
      }
    } else if (this.deck.length === 0 && this.board.tileCount <= (this.level.clearLimit ?? 0)) {
      this.end('won');
      return;
    }

    if (this.movesLeft !== null && this.movesLeft <= 0) {
      this.end('lost', 'moves');
      return;
    }
    if (this.deck.length === 0 && !this.board.hasPossibleMove) {
      this.end('lost', 'deadEnd');
    }
  }

  private end(status: SessionStatus, reason?: FailReason): void {
    if (this.status !== 'playing') return;
    this.status = status;
    this.failReason = reason ?? null;
    this.selected = null;
    this.emit({ type: 'end', status, ...(reason ? { reason } : {}) });
  }

  private bumpCombo(): void {
    this.combo = this.comboTimer > 0 ? this.combo + 1 : 1;
    this.comboTimer = COMBO_WINDOW;
    if (this.combo > this.maxCombo) this.maxCombo = this.combo;
  }

  private resetCombo(): void {
    this.combo = 0;
    this.comboTimer = 0;
  }

  private pushUndo(): void {
    this.undoStack.push({
      board: this.board.snapshot(),
      deck: this.deck.slice(),
      movesLeft: this.movesLeft,
      timeLeft: this.timeLeft,
    });
    if (this.undoStack.length > MAX_UNDO) this.undoStack.shift();
  }

  private emit(e: SessionEvent): void {
    this.events.push(e);
  }

  /** UI 取走事件（取完清空） */
  drainEvents(): SessionEvent[] {
    if (!this.events.length) return [];
    const out = this.events.slice();
    this.events.length = 0;
    return out;
  }
}
