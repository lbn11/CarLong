// 合成场景：布局 + 渲染 + 输入 + 动画。
//
// 只在「读状态 → 画 → 收输入」这三件事上工作，规则全部在 core/session.ts。
// 换平台、换 UI 皮肤都不动这里以下的层。
import { drawCard, drawObstacle, drawSlot } from '../art/card.ts';
import { drawSpriteBox } from '../art/sprites.ts';
import {
  chevron,
  fillRound,
  paintBackdrop,
  pill,
  roundRect,
  softBlob,
  strokeRound,
  text,
  textWidth,
  vGradient,
} from '../art/paint.ts';
import { C, css, parseColor } from '../art/theme.ts';
import { isEmptyStack } from '../core/stack.ts';
import type { SessionEvent } from '../core/session.ts';
import { MergeSession } from '../core/session.ts';
import type { VehicleDef } from '../data/types.ts';
import type { PointerEventLite, Runtime } from '../platform/runtime.ts';

interface CellAnim {
  spawn: number; // 0..1（1 = 完成）
  pulse: number;
  flash: number;
}

interface FloatText {
  str: string;
  x: number;
  y: number;
  life: number;
  max: number;
  color: string;
  size: number;
}

interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

interface Layout {
  cell: number;
  gap: number;
  boardX: number;
  boardY: number;
  boardW: number;
  boardH: number;
  deckY: number;
  deckSize: number;
  deckSlots: Rect[];
  undoBtn: Rect;
  hintBtn: Rect;
  backBtn: Rect;
  nextBtn: Rect;
}

export type { Layout as MergeLayout };

const EMOJI_FONT = '"Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif';

const easeOutBack = (t: number): number => {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
};
const easeOut = (t: number): number => 1 - Math.pow(1 - t, 3);

export class MergeScene {
  readonly rt: Runtime;
  readonly session: MergeSession;
  private readonly vehicles: readonly VehicleDef[];
  private readonly anims = new Map<string, CellAnim>();
  private floats: FloatText[] = [];
  private t = 0;
  private layout: Layout | null = null;
  private hint: { fc: number; fr: number; tc: number; tr: number } | null = null;
  private hintLife = 0;
  private endShownAt = -1;

  onExit: (() => void) | null = null;
  onNextLevel: (() => void) | null = null;
  onRestart: (() => void) | null = null;
  /** 结算回调。进度落档必须挂这里——挂在「下一关」按钮上的话，
   *  玩家通关后点返回就不算通关，是最典型的进度丢失 bug。 */
  onEnd: ((status: 'won' | 'lost') => void) | null = null;

  constructor(rt: Runtime, session: MergeSession, vehicles: readonly VehicleDef[]) {
    this.rt = rt;
    this.session = session;
    this.vehicles = vehicles;
  }

  // ── 布局 ─────────────────────────────────────────────
  private computeLayout(w: number, h: number): Layout {
    const pad = Math.max(12, w * 0.04);
    const safeTop = this.rt.safeArea.top;
    const safeBottom = this.rt.safeArea.bottom;
    const headerTop = safeTop + 12;
    const headerH = 46;
    const goalTop = headerTop + headerH + 4;
    const goalH = 34;
    const bottomBarH = 52;
    const bottomBarTop = h - safeBottom - bottomBarH;

    const contentTop = goalTop + goalH + 12;
    const availW = w - pad * 2;
    const { cols, rows } = this.session.level;
    const gap = Math.max(5, Math.min(10, w * 0.016));

    // 先按宽度定 cell 上界，再按「棋盘 + 牌堆」总高反推高度上界。
    // 牌堆紧贴棋盘下方（不贴屏幕底）——贴底会让小棋盘关出现大段断层。
    const cellW = (availW - gap * (cols - 1)) / cols;
    const deckGuess = Math.min(cellW * 0.96, (availW - 32) / 3.9);
    const cellH = (bottomBarTop - contentTop - deckGuess - 30 - gap * (rows - 1)) / rows;
    const cell = Math.max(28, Math.min(cellW, cellH, 96));

    const boardW = cols * cell + gap * (cols - 1);
    const boardH = rows * cell + gap * (rows - 1);
    const deckSize = Math.min(cell * 0.96, (availW - 32) / 3.9);
    const deckGap = 26;

    // 棋盘 + 牌堆作为一个整体垂直居中于「目标条 → 底部工具条」之间，
    // 多出来的空间均分到上下，而不是全部堆在棋盘上方。
    const totalH = boardH + deckGap + deckSize;
    const startY = contentTop + Math.max(0, (bottomBarTop - contentTop - totalH) / 2);

    const boardX = (w - boardW) / 2;
    const boardY = startY;
    const deckY = boardY + boardH + deckGap;
    const totalDeckW = deckSize * 3 + 24;
    const deckStartX = (w - totalDeckW) / 2 + deckSize / 2;
    const deckSlots: Rect[] = [0, 1, 2].map((i) => ({
      x: deckStartX + i * (deckSize + 12) - deckSize / 2,
      y: deckY,
      w: deckSize,
      h: deckSize,
    }));

    const btnH = 38;
    const btnW = Math.min(120, (w - pad * 3) / 2);
    const barY = bottomBarTop + 6;
    return {
      cell,
      gap,
      boardX,
      boardY,
      boardW,
      boardH,
      deckY,
      deckSize,
      deckSlots,
      undoBtn: { x: pad, y: barY, w: btnW, h: btnH },
      hintBtn: { x: w - pad - btnW, y: barY, w: btnW, h: btnH },
      backBtn: { x: pad, y: headerTop + 6, w: 34, h: 34 },
      nextBtn: { x: w - pad - 34, y: headerTop + 6, w: 34, h: 34 },
    };
  }

  private cellRect(l: Layout, col: number, row: number): Rect {
    return {
      x: l.boardX + col * (l.cell + l.gap),
      y: l.boardY + row * (l.cell + l.gap),
      w: l.cell,
      h: l.cell,
    };
  }

  /**
   * 当前帧布局（调试/截图工具用）。
   * 工具侧必须读这里而不是自己复算——布局公式一旦改动，复算的副本会
   * 静默算错点击坐标，表现为「点了没反应」，排查成本极高。
   */
  layoutForDebug(): Layout | null {
    return this.layout;
  }

  // ── 输入 ─────────────────────────────────────────────
  onPointer(e: PointerEventLite): void {
    if (e.type !== 'up') return;
    const l = this.layout;
    if (!l) return;
    const { x, y } = e;

    // 结算态：只认按钮
    if (this.session.status !== 'playing') {
      if (this.endShownAt >= 0 && this.t - this.endShownAt < 0.35) return;
      const w = this.rt.surface.width;
      const h = this.rt.surface.height;
      const panel = this.endPanelRect(w, h);
      const btnW = (panel.w - 36) / 2;
      const by = panel.y + panel.h - 22 - 44;
      const again: Rect = { x: panel.x + 12, y: by, w: btnW, h: 44 };
      const next: Rect = { x: panel.x + 24 + btnW, y: by, w: btnW, h: 44 };
      if (hit(again, x, y)) {
        this.onRestart?.();
      } else if (hit(next, x, y)) {
        this.onNextLevel?.();
      }
      return;
    }

    if (hit(l.backBtn, x, y)) {
      this.onExit?.();
      return;
    }
    if (hit(l.nextBtn, x, y)) {
      this.onNextLevel?.();
      return;
    }
    if (hit(l.undoBtn, x, y)) {
      if (!this.session.undo()) this.pushFloat('没有可撤销的步骤', l.undoBtn.x + l.undoBtn.w / 2, l.undoBtn.y - 14, C.ink2);
      return;
    }
    if (hit(l.hintBtn, x, y)) {
      const mv = this.session.hint();
      if (mv) {
        this.hint = mv;
        this.hintLife = 3.2;
      } else {
        this.pushFloat('暂时没有能合并的一步', l.hintBtn.x + l.hintBtn.w / 2, l.hintBtn.y - 14, C.ink2);
      }
      return;
    }

    // 牌堆
    for (let i = 0; i < l.deckSlots.length; i++) {
      if (hit(l.deckSlots[i], x, y)) {
        if (i < this.session.deck.length) this.session.draw(i);
        else this.pushFloat('牌堆空了', l.deckSlots[i].x + l.deckSize / 2, l.deckSlots[i].y - 12, C.ink2);
        this.consumeEvents();
        return;
      }
    }

    // 棋盘
    const col = Math.floor((x - l.boardX) / (l.cell + l.gap));
    const row = Math.floor((y - l.boardY) / (l.cell + l.gap));
    if (col >= 0 && col < this.session.level.cols && row >= 0 && row < this.session.level.rows) {
      const r = this.cellRect(l, col, row);
      if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
        this.hint = null;
        this.session.tapCell(col, row);
        this.consumeEvents();
      }
    }
  }

  // ── 动画事件 ─────────────────────────────────────────
  private key(col: number, row: number): string {
    return `${col},${row}`;
  }

  private animOf(col: number, row: number): CellAnim {
    const k = this.key(col, row);
    let a = this.anims.get(k);
    if (!a) {
      a = { spawn: 1, pulse: 0, flash: 0 };
      this.anims.set(k, a);
    }
    return a;
  }

  private consumeEvents(): void {
    for (const e of this.session.drainEvents()) this.handleEvent(e);
  }

  private handleEvent(e: SessionEvent): void {
    const l = this.layout;
    switch (e.type) {
      case 'draw': {
        const a = this.animOf(e.at.col, e.at.row);
        a.spawn = 0;
        break;
      }
      case 'merge': {
        const a = this.animOf(e.at.col, e.at.row);
        a.pulse = 0.0001;
        a.flash = 1;
        if (l) {
          const r = this.cellRect(l, e.at.col, e.at.row);
          if (e.combo >= 2) {
            this.pushFloat(`🔥 连消 x${e.combo}`, r.x + r.w / 2, r.y - 8, C.coralDeep, 16);
          }
        }
        break;
      }
      case 'produced': {
        if (!l) break;
        const r = this.cellRect(l, e.at.col, e.at.row);
        this.pushFloat(
          `+1 ${this.session.targetTier?.name ?? ''}  ${e.count}/${this.session.level.count}`,
          r.x + r.w / 2,
          r.y - 26,
          C.success,
          17,
        );
        break;
      }
      case 'blocked': {
        const w = this.rt.surface.width;
        this.pushFloat(e.reason, w / 2, this.rt.surface.height * 0.42, C.danger, 15);
        break;
      }
      case 'detonate': {
        if (!l) break;
        const r = this.cellRect(l, e.at.col, e.at.row);
        this.pushFloat('💥 引爆！', r.x + r.w / 2, r.y - 10, C.coral, 18);
        break;
      }
      case 'melt':
      case 'teleport':
      case 'move':
      case 'swap':
      case 'undo':
        break;
      case 'end':
        this.endShownAt = this.t;
        if (e.status !== 'playing') this.onEnd?.(e.status);
        break;
    }
  }

  private pushFloat(str: string, x: number, y: number, color: string, size = 14): void {
    this.floats.push({ str, x, y, life: 0, max: 1.1, color, size });
  }

  // ── 每帧 ─────────────────────────────────────────────
  update(dt: number): void {
    this.t += dt;
    this.session.tick(dt);
    this.consumeEvents();

    for (const [, a] of this.anims) {
      if (a.spawn < 1) a.spawn = Math.min(1, a.spawn + dt / 0.18);
      if (a.pulse > 0) {
        a.pulse += dt / 0.3;
        if (a.pulse >= 1) a.pulse = 0;
      }
      if (a.flash > 0) a.flash = Math.max(0, a.flash - dt / 0.28);
    }

    for (const f of this.floats) {
      f.life += dt;
      f.y -= dt * 26;
    }
    this.floats = this.floats.filter((f) => f.life < f.max);

    if (this.hintLife > 0) {
      this.hintLife -= dt;
      if (this.hintLife <= 0) this.hint = null;
    }
  }

  render(): void {
    const { width: w, height: h, ctx } = this.rt.surface;
    const l = this.computeLayout(w, h);
    this.layout = l;
    const s = this.session;

    paintBackdrop(ctx, w, h);
    softBlob(ctx, w * 0.12, h * 0.18, w * 0.5, parseColor(C.blossom), 0.16);
    softBlob(ctx, w * 0.9, h * 0.62, w * 0.55, parseColor(C.sky), 0.14);

    this.renderHeader(ctx, l, w);
    this.renderGoal(ctx, l, w);
    this.renderBoard(ctx, l);
    this.renderDeck(ctx, l);
    this.renderTip(ctx, l, w);
    this.renderBottomBar(ctx, l);
    this.renderFloats(ctx);
    if (s.status !== 'playing') this.renderEndPanel(ctx, w, h);
  }

  private renderHeader(ctx: CanvasRenderingContext2D, l: Layout, w: number): void {
    const s = this.session;
    // 返回
    fillRound(ctx, l.backBtn.x, l.backBtn.y, l.backBtn.w, l.backBtn.h, 12, 'rgba(255,255,255,0.75)');
    chevron(
      ctx,
      l.backBtn.x + l.backBtn.w / 2,
      l.backBtn.y + l.backBtn.h / 2,
      l.backBtn.h * 0.5,
      -1,
      C.ink1,
    );

    // 关卡名
    const title = `第 ${s.level.id} 关 · ${s.level.name}`;
    const maxW = w - l.backBtn.w * 2 - 24;
    let size = 17;
    while (textWidth(ctx, title, size, 800) > maxW && size > 11) size--;
    text(ctx, title, w / 2, l.backBtn.y + l.backBtn.h / 2, size, C.ink1, { weight: 800 });

    // 跳到下一关（方便验收，正式版会换成「关卡目标」信息）
    fillRound(ctx, l.nextBtn.x, l.nextBtn.y, l.nextBtn.w, l.nextBtn.h, 12, 'rgba(255,255,255,0.75)');
    chevron(
      ctx,
      l.nextBtn.x + l.nextBtn.w / 2,
      l.nextBtn.y + l.nextBtn.h / 2,
      l.nextBtn.h * 0.5,
      1,
      C.ink1,
    );
  }

  private renderGoal(ctx: CanvasRenderingContext2D, l: Layout, w: number): void {
    const s = this.session;
    const y = l.backBtn.y + l.backBtn.h + 12;
    const pad = Math.max(12, w * 0.04);
    const barW = w - pad * 2;

    // 限步 / 限时（右侧，先算宽再定位，避免与目标 chip 重叠）
    const clues: string[] = [];
    if (s.movesLeft !== null) clues.push(`👣 ${s.movesLeft}`);
    if (s.timeLeft !== null) clues.push(`⏱ ${Math.ceil(s.timeLeft)}`);
    let cluesW = 0;
    if (clues.length) {
      const label = clues.join('  ');
      cluesW = textWidth(ctx, label, 12, 800) + 20;
      pill(ctx, w - pad - cluesW / 2, y + 14, label, 12, 'rgba(255,255,255,0.9)', C.ink2, 10, 6);
    }

    // 目标 chip：车模 + 文字，左对齐，剩余空间不够就缩字号
    const target = s.targetTier;
    const hasSprite = !!target?.sprite;
    const iconW = hasSprite ? 28 : 0;
    const full =
      s.level.goal === 'produce'
        ? `${hasSprite ? '' : `${target?.icon ?? ''} `}${target?.name ?? ''}  ${s.board.producedCount}/${s.level.count}`
        : `🧹 清空  剩 ${s.board.tileCount}`;
    const limit = w - pad * 2 - cluesW - 8;
    let size = 14;
    let label = full;
    while (size > 10 && textWidth(ctx, label, size, 800) + 24 + iconW > limit) {
      size--;
      if (size <= 11 && s.level.goal === 'produce') {
        // 还是放不下就退化成 icon + 分数
        label = `${hasSprite ? '' : `${target?.icon ?? ''} `}${s.board.producedCount}/${s.level.count}`;
      }
    }
    const chipW = Math.min(limit, textWidth(ctx, label, size, 800) + 24 + iconW);
    fillRound(ctx, pad, y, chipW, 28, 14, 'rgba(255,255,255,0.85)');
    ctx.save();
    ctx.beginPath();
    roundRect(ctx, pad, y, chipW, 28, 14);
    ctx.clip();
    if (hasSprite) drawSpriteBox(ctx, target?.sprite, pad + 19, y + 14.5, 21);
    text(ctx, label, pad + iconW + 10, y + 14.5, size, C.ink1, { align: 'left', weight: 800 });
    ctx.restore();

    // 进度条
    const p = s.goalProgress;
    const barY = y + 33;
    fillRound(ctx, pad, barY, barW, 5, 2.5, 'rgba(43,36,64,0.08)');
    if (p > 0.001) {
      const grad = ctx.createLinearGradient(pad, 0, pad + barW, 0);
      grad.addColorStop(0, C.mint);
      grad.addColorStop(1, C.sky);
      ctx.fillStyle = grad;
      roundRect(ctx, pad, barY, Math.max(5, barW * p), 5, 2.5);
      ctx.fill();
    }
  }

  private renderBoard(ctx: CanvasRenderingContext2D, l: Layout): void {
    const s = this.session;
    const { cols, rows } = s.level;

    // 棋盘底板（白卡 + 柔和阴影，让棋盘从背景里浮起来）
    const platePad = l.gap + 4;
    fillRound(
      ctx,
      l.boardX - platePad,
      l.boardY - platePad + 3,
      l.boardW + platePad * 2,
      l.boardH + platePad * 2,
      l.cell * 0.18,
      'rgba(50,50,78,0.08)',
    );
    fillRound(
      ctx,
      l.boardX - platePad,
      l.boardY - platePad,
      l.boardW + platePad * 2,
      l.boardH + platePad * 2,
      l.cell * 0.18,
      'rgba(255,255,255,0.62)',
    );

    // 槽位 + 障碍
    for (let c = 0; c < cols; c++) {
      for (let r = 0; r < rows; r++) {
        const rc = this.cellRect(l, c, r);
        const ob = s.board.obstacleAt(c, r);
        if (ob) {
          drawObstacle(ctx, rc.x, rc.y, l.cell, ob.type, ob.layers, this.t);
        } else {
          drawSlot(ctx, rc.x, rc.y, l.cell);
        }
      }
    }

    // 卡片
    for (let c = 0; c < cols; c++) {
      for (let r = 0; r < rows; r++) {
        const st = s.board.at(c, r);
        if (!st || isEmptyStack(st)) continue;
        const rc = this.cellRect(l, c, r);
        const a = this.animOf(c, r);
        const sel = s.selected?.col === c && s.selected?.row === r;
        let scale = 1;
        if (a.spawn < 1) scale = Math.max(0.01, easeOutBack(easeOut(a.spawn)));
        if (a.pulse > 0) scale *= 1 + 0.35 * Math.sin(Math.PI * a.pulse);
        if (sel) scale *= 1.06;

        drawCard(ctx, rc.x, rc.y, l.cell, st, this.vehicles[st.tier], {
          selected: sel,
          scale,
          flash: a.flash,
        });
      }
    }

    // 提示环（画在最上层）
    if (this.hint) {
      const from = this.cellRect(l, this.hint.fc, this.hint.fr);
      const to = this.cellRect(l, this.hint.tc, this.hint.tr);
      const pulse = 0.5 + 0.5 * Math.sin(this.t * 6);
      ctx.save();
      ctx.setLineDash([6, 5]);
      ctx.strokeStyle = `rgba(76,194,255,${0.55 + 0.4 * pulse})`;
      ctx.lineWidth = 3;
      roundRect(ctx, from.x - 2, from.y - 2, from.w + 4, from.h + 4, l.cell * 0.16);
      ctx.stroke();
      roundRect(ctx, to.x - 2, to.y - 2, to.w + 4, to.h + 4, l.cell * 0.16);
      ctx.stroke();
      ctx.restore();
    }
  }

  private renderDeck(ctx: CanvasRenderingContext2D, l: Layout): void {
    const s = this.session;
    // 拖卡底座
    const padX = 8;
    const baseY = l.deckSlots[0].y - 10;
    const baseW = l.deckSlots[2].x + l.deckSize + padX - l.deckSlots[0].x + padX;
    const baseH = l.deckSize + 34;
    fillRound(ctx, l.deckSlots[0].x - padX, baseY + 3, baseW, baseH, 20, 'rgba(50,50,78,0.07)');
    fillRound(ctx, l.deckSlots[0].x - padX, baseY, baseW, baseH, 20, 'rgba(255,255,255,0.55)');

    for (let i = 0; i < 3; i++) {
      const slot = l.deckSlots[i];
      const tier = s.deck[i];
      if (tier === undefined) {
        // 空槽：虚线占位
        ctx.save();
        ctx.setLineDash([5, 4]);
        strokeRound(ctx, slot.x, slot.y, slot.w, slot.h, slot.w * 0.14, 'rgba(43,36,64,0.16)', 1.5);
        ctx.restore();
        continue;
      }
      // 牌堆三张底边对齐（以底边中心为缩放锚点），避免同心缩放造成
      // 「中间的卡浮起来」的错位感；第一张最亮 = 下一张要出的牌。
      const scale = i === 0 ? 1 : 0.94;
      const cx = slot.x + slot.w / 2;
      const bottom = slot.y + slot.h;
      ctx.save();
      ctx.globalAlpha = i === 0 ? 1 : 0.8;
      ctx.translate(cx, bottom);
      ctx.scale(scale, scale);
      ctx.translate(-cx, -bottom);
      drawCard(
        ctx,
        slot.x,
        slot.y,
        slot.w,
        { tier, count: 1, isWildcard: false, isBomb: false, frozen: 0, glueT: 0 },
        this.vehicles[tier],
      );
      ctx.restore();
    }

    // 剩余张数（放在底座内、卡下方的留白里，不压卡）
    text(
      ctx,
      `牌堆 ${s.deck.length}`,
      l.deckSlots[1].x + l.deckSize / 2,
      baseY + l.deckSize + 19,
      11,
      C.ink3,
      { weight: 700 },
    );
  }

  /** 牌堆与底部工具条之间的空档：有空间就放一句操作提示，把留白用起来 */
  private renderTip(ctx: CanvasRenderingContext2D, l: Layout, w: number): void {
    const deckBottom = l.deckSlots[0].y - 10 + l.deckSize + 34;
    const space = l.undoBtn.y - deckBottom;
    if (space < 34) return;
    text(ctx, '点牌堆出牌 · 点两张同款合成', w / 2, deckBottom + space / 2, 12, C.ink3, { weight: 700 });
  }

  private renderBottomBar(ctx: CanvasRenderingContext2D, l: Layout): void {
    const s = this.session;
    const cy = l.undoBtn.y + l.undoBtn.h / 2;

    // 撤销
    const canUndo = s.canUndo;
    fillRound(ctx, l.undoBtn.x, l.undoBtn.y, l.undoBtn.w, l.undoBtn.h, 14, canUndo ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.45)');
    text(
      ctx,
      '↩ 撤销',
      l.undoBtn.x + l.undoBtn.w / 2,
      cy,
      14,
      canUndo ? C.ink1 : C.ink3,
      { weight: 800 },
    );

    // 提示
    const grad = vGradient(ctx, l.hintBtn.x, l.hintBtn.y, l.hintBtn.h, [
      { at: 0, color: css(C.sky, 0.95) },
      { at: 1, color: css('#3BA9E8', 0.95) },
    ]);
    ctx.fillStyle = grad;
    roundRect(ctx, l.hintBtn.x, l.hintBtn.y, l.hintBtn.w, l.hintBtn.h, 14);
    ctx.fill();
    text(ctx, '💡 提示', l.hintBtn.x + l.hintBtn.w / 2, cy, 14, '#FFFFFF', { weight: 800 });
  }

  private renderFloats(ctx: CanvasRenderingContext2D): void {
    for (const f of this.floats) {
      const p = f.life / f.max;
      const alpha = p < 0.15 ? p / 0.15 : 1 - Math.max(0, (p - 0.6) / 0.4);
      const scale = p < 0.2 ? 0.8 + 0.3 * easeOutBack(p / 0.2) : 1;
      ctx.save();
      ctx.globalAlpha = Math.max(0, Math.min(1, alpha));
      ctx.translate(f.x, f.y);
      ctx.scale(scale, scale);
      // 描边让文字在任何底色上都可读
      ctx.font = `800 ${f.size}px "Nunito","PingFang SC",sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.lineWidth = 3.5;
      ctx.strokeStyle = 'rgba(255,255,255,0.92)';
      ctx.strokeText(f.str, 0, 0);
      ctx.fillStyle = f.color;
      ctx.fillText(f.str, 0, 0);
      ctx.restore();
    }
  }

  private endPanelRect(w: number, h: number): Rect {
    const pw = Math.min(w - 48, 320);
    const ph = 252;
    return { x: (w - pw) / 2, y: (h - ph) / 2, w: pw, h: ph };
  }

  private renderEndPanel(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    const s = this.session;
    const appear = Math.min(1, (this.t - this.endShownAt) / 0.28);
    if (appear <= 0) return;
    const won = s.status === 'won';

    ctx.save();
    ctx.globalAlpha = appear;
    ctx.fillStyle = 'rgba(43,36,64,0.28)';
    ctx.fillRect(0, 0, w, h);

    const p = this.endPanelRect(w, h);
    const pop = 0.9 + 0.1 * easeOutBack(appear);
    ctx.translate(p.x + p.w / 2, p.y + p.h / 2);
    ctx.scale(pop, pop);
    ctx.translate(-(p.x + p.w / 2), -(p.y + p.h / 2));

    // 面板投影 + 白底
    fillRound(ctx, p.x, p.y + 6, p.w, p.h, 24, 'rgba(50,50,78,0.16)');
    fillRound(ctx, p.x, p.y, p.w, p.h, 24, '#FFFFFF');

    // 顶部色带（用卡片自身圆角裁剪，避免色带方角突出卡片）
    ctx.save();
    roundRect(ctx, p.x, p.y, p.w, p.h, 24);
    ctx.clip();
    const bandGrad = ctx.createLinearGradient(p.x, p.y, p.x + p.w, p.y);
    bandGrad.addColorStop(0, won ? C.mint : C.coral);
    bandGrad.addColorStop(1, won ? C.sky : C.coralDeep);
    ctx.fillStyle = bandGrad;
    ctx.fillRect(p.x, p.y, p.w, 76);
    ctx.restore();

    text(ctx, won ? '🎉' : '😵', p.x + p.w / 2, p.y + 30, 34, '#FFFFFF', { family: EMOJI_FONT });
    text(ctx, won ? '通关成功' : '再试一次', p.x + p.w / 2, p.y + 62, 18, '#FFFFFF', { weight: 800 });

    // 数据
    const ty = p.y + 100;
    const rows: [string, string][] = [
      ['目标', `${s.board.producedCount}/${s.level.count} ${s.targetTier?.name ?? ''}`],
      ['合并次数', `${s.board.totalMerges}`],
      ['最大连消', s.maxCombo > 1 ? `x${s.maxCombo}` : '—'],
    ];
    for (let i = 0; i < rows.length; i++) {
      const y = ty + i * 26;
      text(ctx, rows[i][0], p.x + 22, y, 13, C.ink3, { align: 'left', weight: 700 });
      text(ctx, rows[i][1], p.x + p.w - 22, y, 13, C.ink1, { align: 'right', weight: 800 });
    }

    if (!won && s.failReason) {
      const reason =
        s.failReason === 'moves'
          ? '步数用完了'
          : s.failReason === 'time'
            ? '时间到了'
            : s.failReason === 'deadEnd'
              ? '没牌也没得合了'
              : '棋盘满了';
      text(ctx, reason, p.x + p.w / 2, p.y + p.h - 82, 12, C.danger, { weight: 700 });
    }

    // 按钮
    const btnW = (p.w - 36) / 2;
    const by = p.y + p.h - 22 - 44;
    fillRound(ctx, p.x + 12, by, btnW, 44, 16, 'rgba(43,36,64,0.06)');
    text(ctx, '再来一次', p.x + 12 + btnW / 2, by + 22, 14, C.ink2, { weight: 800 });
    const nextX = p.x + 24 + btnW;
    const g = ctx.createLinearGradient(nextX, by, nextX + btnW, by);
    g.addColorStop(0, C.coral);
    g.addColorStop(1, C.coralDeep);
    ctx.fillStyle = g;
    roundRect(ctx, nextX, by, btnW, 44, 16);
    ctx.fill();
    text(ctx, '下一关 →', nextX + btnW / 2, by + 22, 14, '#FFFFFF', { weight: 800 });
    ctx.restore();
  }
}

function hit(r: Rect, x: number, y: number): boolean {
  return x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h;
}
