// 停车模式场景：布局 / 渲染 / 输入 / 结算。
//
// 交互沿用 Dart 侧 `ParkingGame.slideTo` 的语义：点一下车选中，再点同一条
// 线上的任意格 → 车朝那个方向滑到「不越过点击格」的最远位置。点得越远滑得越远。
// 这个语义不直观，所以选中后必须画出**可达终点的箭头**——否则玩家点完只能靠猜。
import {
  chevron,
  fillRound,
  paintBackdrop,
  pill,
  roundRect,
  softBlob,
  text,
  textWidth,
  vGradient,
} from '../art/paint.ts';
import { ABILITY_LABEL } from '../art/card.ts';
import { drawGhostCar, drawParkCar, drawParkCell, drawReachHint, drawReachTrail } from '../art/parking_draw.ts';
import { C, css, parseColor } from '../art/theme.ts';
import { ParkingSession, solveParking, type ParkingEvent, type PVehicle } from '../core/parking.ts';
import type { ParkingLevelDef, VehicleDef } from '../data/types.ts';
import type { PointerEventLite, Runtime } from '../platform/runtime.ts';

const EMOJI_FONT = '"Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif';
const SLIDE_TIME = 0.16;

interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

interface FloatText {
  str: string;
  x: number;
  y: number;
  color: string;
  size: number;
  life: number;
  max: number;
}

interface SlideAnim {
  fromR: number;
  fromC: number;
  t: number;
}

interface Layout {
  cell: number;
  gap: number;
  boardX: number;
  boardY: number;
  boardW: number;
  boardH: number;
  goalY: number;
  backBtn: Rect;
  nextBtn: Rect;
  undoBtn: Rect;
  hintBtn: Rect;
}

const easeOut = (t: number): number => 1 - Math.pow(1 - t, 3);
const easeOutBack = (t: number): number => {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
};

export class ParkingScene {
  readonly rt: Runtime;
  readonly session: ParkingSession;
  private readonly vehicles: readonly VehicleDef[];
  private readonly slides = new Map<number, SlideAnim>();
  private floats: FloatText[] = [];
  private press: { x: number; y: number } | null = null;
  private t = 0;
  private layout: Layout | null = null;
  private endShownAt = -1;
  private hint: { vi: number; toR: number; toC: number; life: number } | null = null;
  private solving = false;

  onExit: (() => void) | null = null;
  onNextLevel: (() => void) | null = null;
  onRestart: (() => void) | null = null;
  onEnd: ((status: 'won' | 'lost') => void) | null = null;

  constructor(rt: Runtime, session: ParkingSession, vehicles: readonly VehicleDef[]) {
    this.rt = rt;
    this.session = session;
    this.vehicles = vehicles;
  }

  private get level(): ParkingLevelDef {
    return this.session.level;
  }

  private tierColor(tier: number): string {
    return this.vehicles[tier]?.color ?? '#9E9E9E';
  }

  private tierIcon(tier: number): string {
    return this.vehicles[tier]?.icon ?? '🚗';
  }

  // ── 布局 ─────────────────────────────────────────────
  private computeLayout(w: number, h: number): Layout {
    const pad = Math.max(12, w * 0.04);
    const safeTop = this.rt.safeArea.top;
    const safeBottom = this.rt.safeArea.bottom;
    const headerTop = safeTop + 12;
    const headerH = 46;
    const goalY = headerTop + headerH + 6;
    const bottomBarH = 52;
    const bottomBarTop = h - safeBottom - bottomBarH;

    // 目标 chip 行 + 「最优解」小字行
    const contentTop = goalY + 34 + 20 + 8;
    const availW = w - pad * 2;
    const availH = Math.max(120, bottomBarTop - contentTop - 16);

    const { cols, rows } = this.level;
    const gap = Math.max(4, Math.min(8, w * 0.014));
    const cellW = (availW - gap * (cols - 1)) / cols;
    const cellH = (availH - gap * (rows - 1)) / rows;
    const cell = Math.max(28, Math.min(cellW, cellH, 100));

    const boardW = cols * cell + gap * (cols - 1);
    const boardH = rows * cell + gap * (rows - 1);
    const boardX = (w - boardW) / 2;
    // 靠上对齐（最多留 24px）：棋盘居中会让 4×4 关卡整体下坠，
    // 玩家拇指挡住底部按钮、视线也要往下跑。
    const boardY = contentTop + Math.min(24, Math.max(0, (availH - boardH) * 0.25));

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
      goalY,
      backBtn: { x: pad, y: headerTop + 6, w: 34, h: 34 },
      nextBtn: { x: w - pad - 34, y: headerTop + 6, w: 34, h: 34 },
      undoBtn: { x: pad, y: barY, w: btnW, h: btnH },
      hintBtn: { x: w - pad - btnW, y: barY, w: btnW, h: btnH },
    };
  }

  /** 调试/截图工具读这里，不要自己复算布局（复算会漂移，表现为"点了没反应"） */
  layoutForDebug(): Layout | null {
    return this.layout;
  }

  /** 某辆车的屏幕矩形（截图工具点击用，避免在工具里复算布局） */
  carRectForDebug(vi: number): Rect | null {
    const l = this.layout;
    const v = this.session.vehicles[vi];
    if (!l || !v) return null;
    return this.carRect(l, v);
  }

  /** 格子中心的屏幕坐标 */
  cellCenterForDebug(row: number, col: number): { x: number; y: number } | null {
    const l = this.layout;
    if (!l) return null;
    const r = this.cellRect(l, row, col);
    return { x: r.x + r.w / 2, y: r.y + r.h / 2 };
  }

  private cellRect(l: Layout, row: number, col: number): Rect {
    return {
      x: l.boardX + col * (l.cell + l.gap),
      y: l.boardY + row * (l.cell + l.gap),
      w: l.cell,
      h: l.cell,
    };
  }

  private carRect(l: Layout, v: PVehicle, row = v.row, col = v.col): Rect {
    const x = l.boardX + col * (l.cell + l.gap);
    const y = l.boardY + row * (l.cell + l.gap);
    return v.horiz
      ? { x, y, w: v.length * l.cell + (v.length - 1) * l.gap, h: l.cell }
      : { x, y, w: l.cell, h: v.length * l.cell + (v.length - 1) * l.gap };
  }

  // ── 输入 ─────────────────────────────────────────────
  onPointer(e: PointerEventLite): void {
    if (e.type === 'down') {
      this.press = { x: e.x, y: e.y };
      return;
    }
    if (e.type !== 'up') return;
    const start = this.press;
    this.press = null;
    if (start && Math.hypot(e.x - start.x, e.y - start.y) > 12) return; // 拖动不算点击

    const l = this.layout;
    if (!l) return;
    const { x, y } = e;
    const s = this.session;

    if (s.status !== 'playing') {
      if (this.endShownAt >= 0 && this.t - this.endShownAt < 0.35) return;
      const w = this.rt.surface.width;
      const h = this.rt.surface.height;
      const panel = this.endPanelRect(w, h);
      const btnW = (panel.w - 36) / 2;
      const by = panel.y + panel.h - 22 - 44;
      if (hit({ x: panel.x + 12, y: by, w: btnW, h: 44 }, x, y)) {
        this.onRestart?.();
      } else if (hit({ x: panel.x + 24 + btnW, y: by, w: btnW, h: 44 }, x, y)) {
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
      if (s.undo()) this.consumeEvents();
      else this.pushFloat('没有可撤销的步骤', l.undoBtn.x + l.undoBtn.w / 2, l.undoBtn.y - 14, C.ink2);
      return;
    }
    if (hit(l.hintBtn, x, y)) {
      this.showHint();
      return;
    }

    const cell = this.cellAt(l, x, y);
    if (!cell) return;

    const hitV = s.vehicleAt(cell.r, cell.c);
    // 点已选中的车 = 取消选中
    if (hitV && s.selected === hitV.index) {
      s.selected = null;
      return;
    }

    if (s.selected !== null) {
      const vi = s.selected;
      if (s.slideTo(vi, cell.r, cell.c) || s.jumpTo(vi, cell.r, cell.c)) {
        this.consumeEvents();
        return;
      }
      // 滑不过去：点到别的车就换选，点空地就给一句提示（不静默失败）
      if (hitV) {
        if (!hitV.parked) s.selected = hitV.index;
        return;
      }
      this.pushFloat('这个方向滑不过去', x, y - 18, C.ink2, 12);
      return;
    }

    if (hitV && !hitV.parked) {
      s.selected = hitV.index;
      this.hint = null;
    }
  }

  /**
   * 点击 → 格子。用「就近取整到格中心」而不是精确矩形判定。
   *
   * 精确判定有个真实踩到的坑：格子之间有 5px 间隙，长条车的几何中心正好
   * 落在间隙里，于是「点车正中间」判定为没点到任何格 —— 表现为点了没反应。
   * 手指精度本来就不可能稳定落在 55px 的格内，所以统一归到最近的格。
   */
  private cellAt(l: Layout, x: number, y: number): { r: number; c: number } | null {
    const step = l.cell + l.gap;
    const c = Math.round((x - l.boardX - l.cell / 2) / step);
    const r = Math.round((y - l.boardY - l.cell / 2) / step);
    if (c < 0 || c >= this.level.cols || r < 0 || r >= this.level.rows) return null;
    return { r, c };
  }

  // ── 提示 ─────────────────────────────────────────────
  private showHint(): void {
    if (this.solving) return;
    const l = this.layout;
    if (!l) return;
    this.solving = true;
    // solver 是纯同步计算（抽样的 800 关里单关 5-30ms，最坏 0.3s 量级）。
    // 放到下一帧执行，先让「💡 提示」的按下反馈画出来，避免点击像卡住。
    setTimeout(() => {
      this.solving = false;
      const path = solveParking(this.level);
      if (!path || !path.length) {
        this.pushFloat('这一步已经卡死了，试试撤销', this.rt.surface.width / 2, l.undoBtn.y - 14, C.ink2, 12);
        return;
      }
      const mv = path[0];
      this.hint = { vi: mv.vi, toR: mv.toR, toC: mv.toC, life: 3 };
      this.session.selected = mv.vi;
      this.pushFloat(`需要 ${path.length} 步`, this.rt.surface.width / 2, l.goalY + 60, C.sky, 13);
    }, 0);
  }

  // ── 事件 ─────────────────────────────────────────────
  private consumeEvents(): void {
    for (const e of this.session.drainEvents()) this.handleEvent(e);
  }

  private handleEvent(e: ParkingEvent): void {
    if (e.kind === 'move') {
      this.slides.set(e.vi, { fromR: e.fromR, fromC: e.fromC, t: 0 });
      this.hint = null;
      if (e.parked) {
        this.spawnParkedBurst(e.toR, e.toC);
      } else if (this.session.isDeadlocked) {
        const l = this.layout;
        if (l) this.pushFloat('没路可走了 · 撤销试试', l.boardX + l.boardW / 2, l.boardY + l.boardH + 18, C.coralDeep, 13);
      }
    } else if (e.kind === 'won') {
      this.session.setPaused(true);
      this.endShownAt = this.t;
      this.onEnd?.('won');
    } else if (e.kind === 'lost') {
      this.session.setPaused(true);
      this.endShownAt = this.t;
      this.onEnd?.('lost');
    }
  }

  private spawnParkedBurst(row: number, col: number): void {
    const l = this.layout;
    if (!l) return;
    const r = this.cellRect(l, row, col);
    this.pushFloat('停好了！', r.x + r.w / 2, r.y - 14, C.mint, 15);
    for (let i = 0; i < 5; i++) {
      this.pushFloat('✨', r.x + r.w / 2 + (i - 2) * 12, r.y - 4, '#FFFFFF', 11);
    }
  }

  private pushFloat(str: string, x: number, y: number, color: string, size = 13, life = 1.5): void {
    this.floats.push({ str, x, y, color, size, life, max: life });
  }

  update(dt: number): void {
    this.t += dt;
    this.session.tick(dt);
    for (const [vi, a] of this.slides) {
      a.t += dt / SLIDE_TIME;
      if (a.t >= 1) this.slides.delete(vi);
    }
    for (const f of this.floats) f.life -= dt;
    this.floats = this.floats.filter((f) => f.life > 0);
    if (this.hint) {
      this.hint.life -= dt;
      if (this.hint.life <= 0) this.hint = null;
    }
  }

  // ── 渲染 ─────────────────────────────────────────────
  render(): void {
    const { width: w, height: h, ctx } = this.rt.surface;
    const l = this.computeLayout(w, h);
    this.layout = l;

    paintBackdrop(ctx, w, h);
    softBlob(ctx, w * 0.88, h * 0.14, w * 0.5, parseColor(C.aqua), 0.16);
    softBlob(ctx, w * 0.1, h * 0.66, w * 0.52, parseColor(C.mint), 0.14);

    this.renderHeader(ctx, l, w);
    this.renderGoal(ctx, l, w);
    this.renderBoard(ctx, l);
    this.renderCars(ctx, l);
    this.renderTargetCard(ctx, l, w);
    this.renderBottomBar(ctx, l);
    this.renderFloats(ctx);
    if (this.session.status !== 'playing') this.renderEndPanel(ctx, w, h);
  }

  private renderHeader(ctx: CanvasRenderingContext2D, l: Layout, w: number): void {
    fillRound(ctx, l.backBtn.x, l.backBtn.y, l.backBtn.w, l.backBtn.h, 12, 'rgba(255,255,255,0.75)');
    chevron(ctx, l.backBtn.x + l.backBtn.w / 2, l.backBtn.y + l.backBtn.h / 2, l.backBtn.h * 0.5, -1, C.ink1);

    const title = `停车 · 第 ${this.level.id} 关`;
    const maxW = w - l.backBtn.w * 2 - 24;
    let size = 17;
    while (textWidth(ctx, title, size, 800) > maxW && size > 11) size--;
    text(ctx, title, w / 2, l.backBtn.y + l.backBtn.h / 2, size, C.ink1, { weight: 800 });

    fillRound(ctx, l.nextBtn.x, l.nextBtn.y, l.nextBtn.w, l.nextBtn.h, 12, 'rgba(255,255,255,0.75)');
    chevron(ctx, l.nextBtn.x + l.nextBtn.w / 2, l.nextBtn.y + l.nextBtn.h / 2, l.nextBtn.h * 0.5, 1, C.ink1);
  }

  private renderGoal(ctx: CanvasRenderingContext2D, l: Layout, w: number): void {
    const s = this.session;
    const pad = Math.max(12, w * 0.04);

    // 右侧：步数 / 倒计时（先算宽，避免与目标 chip 挤在一起）
    const right: string[] = [];
    const left = s.movesLeft;
    if (left !== null) right.push(`👣 ${s.moves}/${this.level.moves}`);
    const tl = s.timeLeft;
    if (tl !== null) right.push(`⏱ ${Math.ceil(tl)}`);
    let rightW = 0;
    if (right.length) {
      const label = right.join('  ');
      rightW = textWidth(ctx, label, 12, 800) + 20;
      pill(ctx, w - pad - rightW / 2, l.goalY + 14, label, 12, 'rgba(255,255,255,0.9)', C.ink2, 10, 6);
    }

    // 目标 chip
    const label = `🎯 ${this.tierIcon(this.level.target)} ${this.level.targetName}`;
    const limit = w - pad * 2 - rightW - 8;
    let size = 14;
    let shown = label;
    while (size > 10 && textWidth(ctx, shown, size, 800) + 22 > limit) size--;
    const chipW = Math.min(limit, textWidth(ctx, shown, size, 800) + 22);
    fillRound(ctx, pad, l.goalY, chipW, 28, 14, 'rgba(255,255,255,0.85)');
    ctx.save();
    ctx.beginPath();
    roundRect(ctx, pad, l.goalY, chipW, 28, 14);
    ctx.clip();
    text(ctx, shown, pad + chipW / 2, l.goalY + 14.5, size, C.ink1, { weight: 800 });
    ctx.restore();

    // 最优解：给玩家一把尺子，比"你走了几步"更有意义
    // 只作为「一把尺子」展示，不做中途达标判断：
    // 玩家走了 1 步时 "1 <= 7" 会算出"已达标"，但后面还有 6 步要走，
    // 这个结论纯误导。是否完美只在结算时判。
    text(ctx, `最优解 ${this.level.minMoves} 步`, pad + 2, l.goalY + 46, 11.5, C.ink3, {
      align: 'left',
      weight: 800,
    });
  }

  private renderBoard(ctx: CanvasRenderingContext2D, l: Layout): void {
    const platePad = l.gap + 4;
    fillRound(
      ctx,
      l.boardX - platePad,
      l.boardY - platePad + 3,
      l.boardW + platePad * 2,
      l.boardH + platePad * 2,
      l.cell * 0.16,
      'rgba(50,50,78,0.09)',
    );
    fillRound(
      ctx,
      l.boardX - platePad,
      l.boardY - platePad,
      l.boardW + platePad * 2,
      l.boardH + platePad * 2,
      l.cell * 0.16,
      'rgba(255,255,255,0.72)',
    );

    const tierColor = this.tierColor(this.level.target);
    for (let r = 0; r < this.level.rows; r++) {
      for (let c = 0; c < this.level.cols; c++) {
        const rect = this.cellRect(l, r, c);
        drawParkCell(ctx, rect.x, rect.y, l.cell, this.session.cellAt(r, c), this.t, tierColor);
      }
    }

    // 车位里的目标车幽灵：告诉玩家"这辆要进去"
    const park = this.session.parkingAt;
    if (park) {
      const rect = this.cellRect(l, park.r, park.c);
      const pulse = 0.5 + 0.5 * Math.sin(this.t * 2.4);
      drawGhostCar(ctx, rect.x + l.cell * 0.18, rect.y + l.cell * 0.18, l.cell * 0.64, l.cell * 0.64, tierColor, pulse);
    }

    // 选中车的可达终点箭头
    const sel = this.session.selected;
    if (sel !== null && this.session.status === 'playing') {
      const v = this.session.vehicles[sel];
      const reach = this.session.reachOf(sel);
      const color = C.sky;
      const draw = (row: number, col: number, dir: 'left' | 'right' | 'up' | 'down'): void => {
        const rect = this.cellRect(l, row, col);
        drawReachHint(ctx, rect.x + rect.w / 2, rect.y + rect.h / 2, l.cell * 0.3, dir, color);
      };
      // 轨迹点：车身到最远格之间每一格一个淡点（该段都能点，不是只有末端）
      const trail = (row: number, col: number): void => {
        const rect = this.cellRect(l, row, col);
        drawReachTrail(ctx, rect.x + rect.w / 2, rect.y + rect.h / 2, l.cell, color);
      };
      if (reach.right >= 0) {
        for (let c = v.col + 1; c < reach.right; c++) trail(v.row, c);
        draw(v.row, reach.right, 'right');
      }
      if (reach.left >= 0) {
        for (let c = v.col - 1; c > reach.left; c--) trail(v.row, c);
        draw(v.row, reach.left, 'left');
      }
      if (reach.down >= 0) {
        for (let r = v.row + 1; r < reach.down; r++) trail(r, v.col);
        draw(reach.down, v.col, 'down');
      }
      if (reach.up >= 0) {
        for (let r = v.row - 1; r > reach.up; r--) trail(r, v.col);
        draw(reach.up, v.col, 'up');
      }
    }

    // 提示：目标车的目标落点高亮
    if (this.hint) {
      const rect = this.cellRect(l, this.hint.toR, this.hint.toC);
      ctx.save();
      ctx.setLineDash([6, 5]);
      ctx.strokeStyle = 'rgba(255,194,75,0.95)';
      ctx.lineWidth = 3;
      roundRect(ctx, rect.x - 1, rect.y - 1, rect.w + 2, rect.h + 2, l.cell * 0.12);
      ctx.stroke();
      ctx.restore();
    }
  }

  private renderCars(ctx: CanvasRenderingContext2D, l: Layout): void {
    const s = this.session;
    const selected = s.selected;
    // 选中的车最后画（压在最上层），否则长条车会被后画的车盖住一半
    const order = s.vehicles.filter((v) => v.index !== selected);
    const selV = selected === null ? null : s.vehicles[selected];
    if (selV) order.push(selV);

    for (const v of order) {
      const anim = this.slides.get(v.index);
      let rect: Rect;
      let pop = 1;
      if (anim) {
        const e = easeOut(Math.min(1, anim.t));
        const from = this.carRect(l, v, anim.fromR, anim.fromC);
        const to = this.carRect(l, v);
        rect = {
          x: from.x + (to.x - from.x) * e,
          y: from.y + (to.y - from.y) * e,
          w: to.w,
          h: to.h,
        };
        pop = 0.97 + 0.03 * e;
      } else {
        rect = this.carRect(l, v);
      }

      // 已停好：轻微呼吸放大，配合车位虚线强调"任务完成"
      if (v.parked) pop *= 1 + 0.015 * Math.sin(this.t * 3.2);

      drawParkCar(ctx, rect.x, rect.y, rect.w, rect.h, this.tierColor(v.tier), {
        icon: this.tierIcon(v.tier),
        target: v.tier === this.level.target,
        selected: v.index === selected,
        horiz: v.horiz,
        pop,
      });
    }
  }

  /**
   * 棋盘下方的「目标车卡片」。
   *
   * 存在的理由：4×4/6×6 棋盘按宽度定尺后，底部必然剩一大片空白。
   * 与其留白，不如把这一关的"主角"放大摆出来——玩家一眼知道要把哪辆
   * 车开进车位，也顺便给了能力标签一个展示位。
   */
  private renderTargetCard(ctx: CanvasRenderingContext2D, l: Layout, w: number): void {
    const top = l.boardY + l.boardH + 18;
    const bottom = l.undoBtn.y - 10;
    const cardH = 76;
    if (bottom - top < cardH + 8) return;

    const pad = Math.max(12, w * 0.04);
    const cardW = Math.min(w - pad * 2, 330);
    const x = (w - cardW) / 2;
    const y = top + (bottom - top - cardH) / 2;

    const tier = this.level.target;
    const color = this.tierColor(tier);
    const v = this.vehicles[tier];

    fillRound(ctx, x, y + 4, cardW, cardH, 20, 'rgba(50,50,78,0.10)');
    fillRound(ctx, x, y, cardW, cardH, 20, 'rgba(255,255,255,0.92)');
    // 左侧车型色竖条，让卡片与目标车同色系
    ctx.save();
    roundRect(ctx, x, y, cardW, cardH, 20);
    ctx.clip();
    fillRound(ctx, x, y, 6, cardH, 3, color);
    ctx.restore();

    // 车型图标圆底
    const iconR = 24;
    const icx = x + 22 + iconR;
    const icy = y + cardH / 2;
    fillRound(ctx, icx - iconR, icy - iconR, iconR * 2, iconR * 2, iconR, css(color, 0.16));
    text(ctx, this.tierIcon(tier), icx, icy, iconR * 1.25, '#FFFFFF', { family: EMOJI_FONT });

    const textX = icx + iconR + 14;
    text(ctx, this.level.targetName, textX, icy - 10, 15, C.ink1, { align: 'left', weight: 800 });

    const ability = v?.ability ?? 'none';
    const sub =
      ability !== 'none'
        ? `${ABILITY_LABEL[ability] ?? ability} · 把它开进车位`
        : '把它开进 🅿 车位';
    text(ctx, sub, textX, icy + 12, 11.5, C.ink3, { align: 'left', weight: 700 });

    // 右上角：目标档位徽标（长条车的身份感来自档位而非名字）
    pill(ctx, x + cardW - 34, icy, `T${tier}`, 10.5, css(color, 0.14), css(color, 1), 8, 5);
  }

  private renderBottomBar(ctx: CanvasRenderingContext2D, l: Layout): void {
    const s = this.session;
    const cy = l.undoBtn.y + l.undoBtn.h / 2;

    const canUndo = s.canUndo;
    fillRound(
      ctx,
      l.undoBtn.x,
      l.undoBtn.y,
      l.undoBtn.w,
      l.undoBtn.h,
      14,
      canUndo ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.45)',
    );
    text(ctx, '↩ 撤销', l.undoBtn.x + l.undoBtn.w / 2, cy, 14, canUndo ? C.ink1 : C.ink3, { weight: 800 });

    const grad = vGradient(ctx, l.hintBtn.x, l.hintBtn.y, l.hintBtn.h, [
      { at: 0, color: css(C.sun, 0.98) },
      { at: 1, color: css('#F0A93B', 0.98) },
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
    const ph = 268;
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

    fillRound(ctx, p.x, p.y + 6, p.w, p.h, 24, 'rgba(50,50,78,0.16)');
    fillRound(ctx, p.x, p.y, p.w, p.h, 24, '#FFFFFF');

    ctx.save();
    roundRect(ctx, p.x, p.y, p.w, p.h, 24);
    ctx.clip();
    const band = ctx.createLinearGradient(p.x, p.y, p.x + p.w, p.y);
    band.addColorStop(0, won ? C.mint : C.coral);
    band.addColorStop(1, won ? C.sky : C.coralDeep);
    ctx.fillStyle = band;
    ctx.fillRect(p.x, p.y, p.w, 76);
    ctx.restore();

    text(ctx, won ? '🅿' : '😵', p.x + p.w / 2, p.y + 32, 32, '#FFFFFF', { family: EMOJI_FONT });
    text(ctx, won ? '停车成功' : '没停进去', p.x + p.w / 2, p.y + 62, 18, '#FFFFFF', { weight: 800 });

    const best = this.level.minMoves;
    const rows: [string, string][] = [
      ['目标', this.level.targetName],
      ['用了步数', `${s.moves}`],
      ['最优解', `${best} 步${s.moves > 0 && s.moves <= best ? ' · 完美' : ''}`],
    ];
    for (let i = 0; i < rows.length; i++) {
      const y = p.y + 104 + i * 26;
      text(ctx, rows[i][0], p.x + 22, y, 13, C.ink3, { align: 'left', weight: 700 });
      text(ctx, rows[i][1], p.x + p.w - 22, y, 13, C.ink1, { align: 'right', weight: 800 });
    }

    if (!won) {
      const reason = s.failReason === 'time' ? '时间到了' : '步数用完了';
      text(ctx, reason, p.x + p.w / 2, p.y + p.h - 82, 12, C.danger, { weight: 700 });
    }

    const btnW = (p.w - 36) / 2;
    const by = p.y + p.h - 22 - 44;
    fillRound(ctx, p.x + 12, by, btnW, 44, 16, 'rgba(43,36,64,0.06)');
    text(ctx, won ? '再玩一次' : '重试', p.x + 12 + btnW / 2, by + 22, 14, C.ink2, { weight: 800 });
    const nextX = p.x + 24 + btnW;
    const g = ctx.createLinearGradient(nextX, by, nextX + btnW, by);
    g.addColorStop(0, C.coral);
    g.addColorStop(1, C.coralDeep);
    ctx.fillStyle = g;
    roundRect(ctx, nextX, by, btnW, 44, 16);
    ctx.fill();
    text(ctx, won ? '下一关 →' : '重新挑战', nextX + btnW / 2, by + 22, 14, '#FFFFFF', { weight: 800 });
    ctx.restore();
  }
}

function hit(r: Rect, x: number, y: number): boolean {
  return x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h;
}
