// 关卡选择。
//
// 现在有两个模式共用一个网格：顶部 tab 切换，切过去自动滚到「当前进度」那一行
// —— 700/800 关的列表，玩家永远不会想从第 1 关开始翻。
//
// 格子不是纯数字：每关显示这一关的目标车型车模。整屏 700 个数字墙是"没有车"
// 的观感来源，玩家一眼要看得出"下一关要合成/停车的是什么"。
//
// 章节分组、难度心跳徽标、🎬 广告关角标还没接（等 Boss / 广告系统进 TS 端再补）。
import { chevron, fillRound, paintBackdrop, roundRect, softBlob, strokeRound, text } from '../art/paint.ts';
import { drawSpriteBox } from '../art/sprites.ts';
import { C, parseColor } from '../art/theme.ts';
import type { VehicleDef } from '../data/types.ts';
import type { PointerEventLite, Runtime } from '../platform/runtime.ts';

const COLS = 5;
const CELL = 56;
const GAP = 12;
const ROW_H = CELL + GAP;

export type SelectMode = 'merge' | 'parking';

/** 网格只关心「第几关」和「属于哪一章（决定色条）」 */
export interface SelectEntry {
  id: number;
  ch: number;
  /** 该关目标车型 id（决定格子里的车模） */
  target?: number;
}

export interface ModeData {
  entries: readonly SelectEntry[];
  unlocked: number;
}

export class LevelSelectScene {
  private readonly rt: Runtime;
  private readonly data: Record<SelectMode, ModeData>;
  private readonly vehicles: readonly VehicleDef[];
  private mode: SelectMode;
  private scrollY = 0;
  private dragStart: { y: number; scroll: number } | null = null;
  private moved = 0;
  private topInset = 0;
  private tabs: { mode: SelectMode; rect: { x: number; y: number; w: number; h: number } }[] = [];

  onPick: ((mode: SelectMode, id: number) => void) | null = null;
  onBack: (() => void) | null = null;
  private backRect = { x: 0, y: 0, w: 0, h: 0 };

  constructor(
    rt: Runtime,
    merge: ModeData,
    parking: ModeData,
    vehicles: readonly VehicleDef[],
    mode: SelectMode = 'merge',
  ) {
    this.rt = rt;
    this.data = { merge, parking };
    this.vehicles = vehicles;
    this.mode = mode;
    rt.onResize(() => {
      this.scrollY = Math.max(0, Math.min(this.scrollY, this.maxScroll()));
    });
  }

  private get entries(): readonly SelectEntry[] {
    return this.data[this.mode].entries;
  }

  private get unlocked(): number {
    return this.data[this.mode].unlocked;
  }

  /** tab 行底边 = 网格顶部 */
  private tabY(): number {
    return this.topInset + 74;
  }

  private gridTop(): number {
    return this.tabY() + 44;
  }

  private maxScroll(): number {
    const h = this.rt.surface.height;
    const rows = Math.ceil(this.entries.length / COLS);
    return Math.max(0, this.gridTop() + rows * ROW_H + 40 - h);
  }

  /** 当前进度的行号（第几行），用于切 tab / 首次进入时定位 */
  private currentRow(): number {
    const idx = this.entries.findIndex((e) => e.id === this.unlocked);
    return idx < 0 ? 0 : Math.floor(idx / COLS);
  }

  private scrollToCurrent(): void {
    const row = this.currentRow();
    // 目标行放在视口约 1/3 高度处：上面留两行上下文，下面留更多（继续往下打的期待）
    const target = this.gridTop() + row * ROW_H - (this.rt.surface.height - this.gridTop()) * 0.3;
    this.scrollY = Math.max(0, Math.min(target, this.maxScroll()));
  }

  switchMode(mode: SelectMode): void {
    if (mode === this.mode) return;
    this.mode = mode;
    this.scrollToCurrent();
  }

  onPointer(e: PointerEventLite): void {
    if (e.type === 'down') {
      this.dragStart = { y: e.y, scroll: this.scrollY };
      this.moved = 0;
    } else if (e.type === 'move' && this.dragStart) {
      const dy = e.y - this.dragStart.y;
      this.moved = Math.max(this.moved, Math.abs(dy));
      this.scrollY = Math.max(0, Math.min(this.dragStart.scroll - dy, this.maxScroll()));
    } else if (e.type === 'up') {
      const start = this.dragStart;
      this.dragStart = null;
      if (!start || this.moved > 8) return;

      for (const tab of this.tabs) {
        const r = tab.rect;
        if (e.x >= r.x && e.x <= r.x + r.w && e.y >= r.y && e.y <= r.y + r.h) {
          this.switchMode(tab.mode);
          return;
        }
      }

      const b = this.backRect;
      if (e.x >= b.x && e.x <= b.x + b.w && e.y >= b.y && e.y <= b.y + b.h) {
        this.onBack?.();
        return;
      }

      const col = Math.floor((e.x - this.gridX()) / (CELL + GAP));
      const row = Math.floor((e.y - this.gridTop() + this.scrollY) / ROW_H);
      if (col < 0 || col >= COLS || row < 0) return;
      const cellX = this.gridX() + col * (CELL + GAP);
      const cellY = this.gridTop() + row * ROW_H - this.scrollY;
      if (e.x > cellX + CELL || e.y > cellY + CELL) return;
      const idx = row * COLS + col;
      const entry = this.entries[idx];
      if (entry && entry.id <= this.unlocked) this.onPick?.(this.mode, entry.id);
    }
  }

  private gridX(): number {
    const w = this.rt.surface.width;
    const total = COLS * CELL + (COLS - 1) * GAP;
    return (w - total) / 2;
  }

  update(dt: number): void {
    void dt;
    const wasTop = this.topInset;
    this.topInset = this.rt.safeArea.top;
    if (wasTop === 0 && this.topInset !== 0) this.scrollToCurrent();
  }

  render(): void {
    const { width: w, height: h, ctx } = this.rt.surface;
    paintBackdrop(ctx, w, h);
    softBlob(ctx, w * 0.85, h * 0.12, w * 0.5, parseColor(C.taro), 0.16);
    softBlob(ctx, w * 0.1, h * 0.7, w * 0.5, parseColor(C.aqua), 0.14);

    text(ctx, '选择关卡', w / 2, this.topInset + 34, 22, C.ink1, { weight: 800 });
    text(
      ctx,
      `已解锁 ${Math.min(this.unlocked, this.entries.length)} / ${this.entries.length}`,
      w / 2,
      this.topInset + 60,
      12,
      C.ink3,
      { weight: 700 },
    );

    // 返回首页
    const backSize = 36;
    const backX = Math.max(12, w * 0.04);
    const backY = this.topInset + 18;
    this.backRect = { x: backX, y: backY, w: backSize, h: backSize };
    fillRound(ctx, backX, backY, backSize, backSize, backSize / 2, 'rgba(255,255,255,0.9)');
    chevron(ctx, backX + backSize / 2 + 1, backY + backSize / 2, 8, -1, C.ink2, 2.2);

    this.renderTabs(ctx, w);

    const gx = this.gridX();
    const top = this.gridTop();
    const rows = Math.ceil(this.entries.length / COLS);
    const firstRow = Math.max(0, Math.floor((this.scrollY - top + this.topInset) / ROW_H) - 1);
    const lastRow = Math.min(rows - 1, Math.ceil((this.scrollY + h) / ROW_H));

    for (let row = firstRow; row <= lastRow; row++) {
      const y = top + row * ROW_H - this.scrollY;
      for (let col = 0; col < COLS; col++) {
        const idx = row * COLS + col;
        const entry = this.entries[idx];
        if (!entry) break;
        const x = gx + col * (CELL + GAP);
        const locked = entry.id > this.unlocked;
        const isCurrent = entry.id === this.unlocked;

        if (locked) {
          fillRound(ctx, x, y, CELL, CELL, 16, 'rgba(255,255,255,0.38)');
          text(ctx, '🔒', x + CELL / 2, y + CELL / 2, 20, '#FFFFFF');
        } else {
          fillRound(ctx, x, y + 3, CELL, CELL, 16, 'rgba(50,50,78,0.10)');
          fillRound(ctx, x, y, CELL, CELL, 16, '#FFFFFF');
          // 章节色条（与 Flutter 选关页的彩虹循环同思路）
          const hue = this.mode === 'parking'
            ? ['#4CC2FF', '#3ED598', '#FFC24B', '#A78BFA', '#FF9EC4'][entry.ch % 5]
            : ['#FF7A5C', '#FFC24B', '#3ED598', '#4CC2FF', '#A78BFA'][entry.ch % 5];
          ctx.fillStyle = hue;
          roundRect(ctx, x + 10, y + 8, CELL - 20, 3, 1.5);
          ctx.fill();
          // 目标车型车模：格子的主角，关卡号退到右下角
          const vehicle = entry.target !== undefined ? this.vehicles[entry.target] : undefined;
          const drew = drawSpriteBox(ctx, vehicle?.sprite, x + CELL / 2, y + CELL / 2 - 4, CELL * 0.5);
          if (!drew) {
            text(ctx, vehicle?.icon ?? '🚗', x + CELL / 2, y + CELL / 2 - 3, CELL * 0.42, '#FFFFFF');
          }
          text(ctx, `${entry.id}`, x + CELL - 8, y + CELL - 11, 10.5, C.ink3, { weight: 800, align: 'right' });
          if (isCurrent) {
            strokeRound(ctx, x - 2, y - 2, CELL + 4, CELL + 4, 18, C.coral, 2.5);
            // ▶ 角标：和 Flutter 选关页一致，一眼看出"我在这"
            fillRound(ctx, x + CELL - 18, y + CELL - 18, 16, 16, 8, C.coral);
            chevron(ctx, x + CELL - 10, y + CELL - 10, 7, 1, '#FFFFFF', 1.6);
          }
        }
      }
    }

    // 顶部渐隐，避免滚动时内容顶到 tab
    const fade = ctx.createLinearGradient(0, top - 18, 0, top + 6);
    fade.addColorStop(0, 'rgba(252,243,234,1)');
    fade.addColorStop(1, 'rgba(252,243,234,0)');
    ctx.fillStyle = fade;
    ctx.fillRect(0, top - 18, w, 24);
  }

  private renderTabs(ctx: CanvasRenderingContext2D, w: number): void {
    const trackW = Math.min(w - 48, 280);
    const trackH = 36;
    const tx = (w - trackW) / 2;
    const ty = this.tabY();
    const half = trackW / 2;

    fillRound(ctx, tx, ty, trackW, trackH, trackH / 2, 'rgba(255,255,255,0.6)');

    const defs: { mode: SelectMode; label: string; color: string }[] = [
      { mode: 'merge', label: '🚗 合成', color: C.coral },
      { mode: 'parking', label: '🅿 停车', color: C.sky },
    ];
    this.tabs = defs.map((d, i) => ({
      mode: d.mode,
      rect: { x: tx + i * half, y: ty, w: half, h: trackH },
    }));

    for (let i = 0; i < defs.length; i++) {
      const d = defs[i];
      const active = this.mode === d.mode;
      const x = tx + i * half;
      if (active) {
        fillRound(ctx, x + 3, ty + 3, half - 6, trackH - 6, (trackH - 6) / 2, '#FFFFFF');
        fillRound(ctx, x + 3, ty + 3 + 1, half - 6, trackH - 6, (trackH - 6) / 2, d.color);
      }
      text(ctx, d.label, x + half / 2, ty + trackH / 2 + 0.5, 13.5, active ? '#FFFFFF' : C.ink2, { weight: 800 });
    }
  }
}
