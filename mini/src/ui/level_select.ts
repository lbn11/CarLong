// 关卡选择。第一版只做「能滑、能点、能看到进度」，视觉在下一轮迭代补
// （章节分组、难度心跳徽标、🎬 广告关角标都要等 Boss/广告系统接进来）。
import { fillRound, paintBackdrop, roundRect, softBlob, strokeRound, text } from '../art/paint.ts';
import { C, parseColor } from '../art/theme.ts';
import type { MergeLevelDef } from '../data/types.ts';
import type { PointerEventLite, Runtime } from '../platform/runtime.ts';

const COLS = 5;
const CELL = 56;
const GAP = 12;
const ROW_H = CELL + GAP;

export class LevelSelectScene {
  private readonly rt: Runtime;
  private readonly levels: readonly MergeLevelDef[];
  private readonly unlocked: number;
  private scrollY = 0;
  private dragStart: { y: number; scroll: number } | null = null;
  private moved = 0;
  private topInset = 0;

  onPick: ((id: number) => void) | null = null;

  constructor(rt: Runtime, levels: readonly MergeLevelDef[], unlocked: number) {
    this.rt = rt;
    this.levels = levels;
    this.unlocked = unlocked;
    rt.onResize(() => {
      this.scrollY = Math.max(0, Math.min(this.scrollY, this.maxScroll()));
    });
  }

  private gridTop(): number {
    return this.topInset + 96;
  }

  private maxScroll(): number {
    const h = this.rt.surface.height;
    const rows = Math.ceil(this.levels.length / COLS);
    return Math.max(0, this.gridTop() + rows * ROW_H + 40 - h);
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
      // 点击命中
      const col = Math.floor((e.x - this.gridX()) / (CELL + GAP));
      const row = Math.floor((e.y - this.gridTop() + this.scrollY) / ROW_H);
      if (col < 0 || col >= COLS || row < 0) return;
      const cellX = this.gridX() + col * (CELL + GAP);
      const cellY = this.gridTop() + row * ROW_H - this.scrollY;
      if (e.x > cellX + CELL || e.y > cellY + CELL) return;
      const idx = row * COLS + col;
      const lv = this.levels[idx];
      if (lv && lv.id <= this.unlocked) this.onPick?.(lv.id);
    }
  }

  private gridX(): number {
    const w = this.rt.surface.width;
    const total = COLS * CELL + (COLS - 1) * GAP;
    return (w - total) / 2;
  }

  update(dt: number): void {
    void dt;
    this.topInset = this.rt.safeArea.top;
  }

  render(): void {
    const { width: w, height: h, ctx } = this.rt.surface;
    paintBackdrop(ctx, w, h);
    softBlob(ctx, w * 0.85, h * 0.12, w * 0.5, parseColor(C.taro), 0.16);
    softBlob(ctx, w * 0.1, h * 0.7, w * 0.5, parseColor(C.aqua), 0.14);

    // 标题
    text(ctx, '选择关卡', w / 2, this.topInset + 34, 22, C.ink1, { weight: 800 });
    text(ctx, `已解锁 ${Math.min(this.unlocked, this.levels.length)} / ${this.levels.length}`, w / 2, this.topInset + 60, 12, C.ink3, {
      weight: 700,
    });

    const gx = this.gridX();
    const top = this.gridTop();
    const rows = Math.ceil(this.levels.length / COLS);
    const firstRow = Math.max(0, Math.floor((this.scrollY - top + this.topInset) / ROW_H) - 1);
    const lastRow = Math.min(rows - 1, Math.ceil((this.scrollY + h) / ROW_H));

    for (let row = firstRow; row <= lastRow; row++) {
      const y = top + row * ROW_H - this.scrollY;
      for (let col = 0; col < COLS; col++) {
        const idx = row * COLS + col;
        const lv = this.levels[idx];
        if (!lv) break;
        const x = gx + col * (CELL + GAP);
        const locked = lv.id > this.unlocked;
        const isCurrent = lv.id === this.unlocked;

        if (locked) {
          fillRound(ctx, x, y, CELL, CELL, 16, 'rgba(255,255,255,0.38)');
          text(ctx, '🔒', x + CELL / 2, y + CELL / 2, 20, '#FFFFFF');
        } else {
          fillRound(ctx, x, y + 3, CELL, CELL, 16, 'rgba(50,50,78,0.10)');
          fillRound(ctx, x, y, CELL, CELL, 16, '#FFFFFF');
          // 章节色条（与 Flutter 选关页的彩虹循环同思路）
          const hue = ['#FF7A5C', '#FFC24B', '#3ED598', '#4CC2FF', '#A78BFA'][lv.ch % 5];
          ctx.fillStyle = hue;
          roundRect(ctx, x + 10, y + 8, CELL - 20, 3, 1.5);
          ctx.fill();
          text(ctx, `${lv.id}`, x + CELL / 2, y + CELL / 2 + 3, 17, C.ink1, { weight: 800 });
          if (isCurrent) {
            strokeRound(ctx, x - 2, y - 2, CELL + 4, CELL + 4, 18, C.coral, 2.5);
          }
        }
      }
    }

    // 顶部渐隐，避免滚动时内容顶到标题
    const fade = ctx.createLinearGradient(0, top - 18, 0, top + 6);
    fade.addColorStop(0, 'rgba(252,243,234,1)');
    fade.addColorStop(1, 'rgba(252,243,234,0)');
    ctx.fillStyle = fade;
    ctx.fillRect(0, top - 18, w, 24);
  }
}
