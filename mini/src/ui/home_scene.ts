// 首页。
//
// 为什么要它：小游戏冷启动直接甩一张 700 格的关卡墙，第一眼是"打不开的
// 数字表"，跟 App 端的糖果风首页完全不是同一个游戏——玩家（和做游戏的
// 人）第一反应都是"画面怎么全变了、车里没有车"。首页承担三件事：
//   1. 报出游戏名字与气质（车水马龙 / 慢慢攒车队）
//   2. 一个明确的"继续玩"入口（Hero 卡，带目标车型车模）
//   3. 两个模式的入口，各自带进度
import { chevron, fillRound, paintBackdrop, pill, roundRect, softBlob, strokeRound, text } from '../art/paint.ts';
import { drawSpriteBox } from '../art/sprites.ts';
import { C, css, parseColor } from '../art/theme.ts';
import type { VehicleDef } from '../data/types.ts';
import type { PointerEventLite, Runtime } from '../platform/runtime.ts';
import type { SelectMode } from './level_select.ts';

export interface HomeProgress {
  mergeUnlocked: number;
  mergeTotal: number;
  parkingUnlocked: number;
  parkingTotal: number;
  /** Hero 卡展示的：下一次要挑战的合成关目标车型与章节名 */
  targetTier?: number;
  chapterTitle: string;
  levelName: string;
}

interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export class HomeScene {
  private readonly rt: Runtime;
  private readonly vehicles: readonly VehicleDef[];
  private readonly progress: HomeProgress;
  private tapTargets: { rect: Rect; action: () => void }[] = [];
  private t = 0;

  onPlay: ((mode: SelectMode) => void) | null = null;
  onOpenSelect: ((mode: SelectMode) => void) | null = null;

  constructor(rt: Runtime, vehicles: readonly VehicleDef[], progress: HomeProgress) {
    this.rt = rt;
    this.vehicles = vehicles;
    this.progress = progress;
  }

  update(dt: number): void {
    this.t += dt;
  }

  onPointer(e: PointerEventLite): void {
    if (e.type !== 'up') return;
    for (const t of this.tapTargets) {
      const r = t.rect;
      if (e.x >= r.x && e.x <= r.x + r.w && e.y >= r.y && e.y <= r.y + r.h) {
        t.action();
        return;
      }
    }
  }

  render(): void {
    const { width: w, height: h, ctx } = this.rt.surface;
    paintBackdrop(ctx, w, h);
    softBlob(ctx, w * 0.86, h * 0.1, w * 0.55, parseColor(C.lemon), 0.2);
    softBlob(ctx, w * 0.1, h * 0.62, w * 0.5, parseColor(C.aqua), 0.16);
    this.tapTargets = [];

    const pad = Math.max(16, w * 0.05);
    const top = this.rt.safeArea.top + 18;

    // ── 品牌标题（渐变字）──
    const titleGrad = ctx.createLinearGradient(pad, top, pad + 180, top + 40);
    titleGrad.addColorStop(0, '#FF7A5C');
    titleGrad.addColorStop(0.5, '#FF5FA2');
    titleGrad.addColorStop(1, '#8B7CF6');
    ctx.save();
    ctx.fillStyle = titleGrad;
    ctx.font = '800 34px "Nunito","PingFang SC","Noto Sans SC",sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText('车水马龙', pad, top + 18);
    ctx.restore();
    text(ctx, '随手玩两把，慢慢攒车队', pad, top + 46, 12.5, C.ink3, { align: 'left', weight: 700 });

    // ── Hero 卡：继续挑战 ──
    const heroY = top + 66;
    const heroH = 150;
    const heroW = w - pad * 2;
    fillRound(ctx, pad, heroY + 5, heroW, heroH, 24, 'rgba(255,150,80,0.20)');
    const heroGrad = ctx.createLinearGradient(pad, heroY, pad + heroW, heroY + heroH);
    heroGrad.addColorStop(0, '#FFF3E0');
    heroGrad.addColorStop(0.55, '#FFE6C7');
    heroGrad.addColorStop(1, '#FFD9B0');
    ctx.fillStyle = heroGrad;
    roundRect(ctx, pad, heroY, heroW, heroH, 24);
    ctx.fill();
    strokeRound(ctx, pad, heroY, heroW, heroH, 24, 'rgba(255,171,91,0.55)', 1.5);

    // 右上角车型装饰：让首屏第一眼就有一辆车
    drawSpriteBox(ctx, this.vehicles[this.progress.targetTier ?? 0]?.sprite, pad + heroW - 62, heroY + 40, 64);

    pill(ctx, pad + 16 + 34, heroY + 26, '启程时刻', 11, C.coral, '#FFFFFF');

    text(ctx, this.progress.chapterTitle, pad + 18, heroY + 58, 24, C.ink1, { align: 'left', weight: 800 });
    const target = this.vehicles[this.progress.targetTier ?? 0];
    const goalLine = `目标：合成 ${target?.name ?? '目标车'} ×1`;
    text(ctx, goalLine, pad + 18, heroY + 84, 12.5, C.ink2, { align: 'left', weight: 700 });

    // 进度条
    const barW = heroW * 0.52;
    const barY = heroY + 106;
    fillRound(ctx, pad + 18, barY, barW, 7, 3.5, 'rgba(255,255,255,0.75)');
    const ratio = Math.min(1, (this.progress.mergeUnlocked - 1) / Math.max(1, this.progress.mergeTotal));
    if (ratio > 0.001) {
      fillRound(ctx, pad + 18, barY, Math.max(7, barW * ratio), 7, 3.5, C.coral);
    }
    text(
      ctx,
      `${this.progress.mergeUnlocked - 1} / ${this.progress.mergeTotal} 关`,
      pad + 18,
      barY + 22,
      11,
      C.ink3,
      { align: 'left', weight: 700 },
    );

    // 开始游戏按钮
    const btnW = 108;
    const btnH = 42;
    const btnX = pad + heroW - btnW - 16;
    const btnY = heroY + heroH - btnH - 16;
    fillRound(ctx, btnX, btnY + 3, btnW, btnH, btnH / 2, 'rgba(230,110,40,0.35)');
    const btnGrad = ctx.createLinearGradient(btnX, btnY, btnX, btnY + btnH);
    btnGrad.addColorStop(0, '#FFB067');
    btnGrad.addColorStop(1, '#FF8A3D');
    ctx.fillStyle = btnGrad;
    roundRect(ctx, btnX, btnY, btnW, btnH, btnH / 2);
    ctx.fill();
    text(ctx, '开始游戏', btnX + btnW / 2 - 8, btnY + btnH / 2, 14, '#FFFFFF', { weight: 800 });
    chevron(ctx, btnX + btnW - 22, btnY + btnH / 2, 8, 1, '#FFFFFF', 2.2);
    this.tapTargets.push({ rect: { x: btnX, y: btnY, w: btnW, h: btnH }, action: () => this.onPlay?.('merge') });

    // ── 模式卡 2×2 ──
    const gridY = heroY + heroH + 16;
    const gap = 12;
    const cardW = (heroW - gap) / 2;
    const cardH = 104;

    this.modeCard(ctx, pad, gridY, cardW, cardH, {
      emoji: '🚗',
      sprite: 'car',
      title: '合成模式',
      sub: `第 ${this.progress.mergeUnlocked} 关 · 共 ${this.progress.mergeTotal} 关`,
      color: C.coral,
      onTap: () => this.onPlay?.('merge'),
      onMore: () => this.onOpenSelect?.('merge'),
    });
    this.modeCard(ctx, pad + cardW + gap, gridY, cardW, cardH, {
      emoji: '🅿',
      sprite: 'bus',
      title: '停车模式',
      sub: `第 ${this.progress.parkingUnlocked} 关 · 共 ${this.progress.parkingTotal} 关`,
      color: C.mint,
      onTap: () => this.onPlay?.('parking'),
      onMore: () => this.onOpenSelect?.('parking'),
    });

    // ── 全部关卡（宽条）──
    const allY = gridY + cardH + 12;
    const allH = 62;
    fillRound(ctx, pad, allY + 3, heroW, allH, 20, 'rgba(50,50,78,0.08)');
    fillRound(ctx, pad, allY, heroW, allH, 20, 'rgba(255,255,255,0.92)');
    fillRound(ctx, pad + 14, allY + 13, 36, 36, 12, css(C.sky, 0.18));
    text(ctx, '🗂', pad + 32, allY + 31, 18, '#FFFFFF');
    text(ctx, '全部关卡', pad + 60, allY + 24, 14.5, C.ink1, { align: 'left', weight: 800 });
    text(ctx, '看章节、挑关卡', pad + 60, allY + 42, 11.5, C.ink3, { align: 'left', weight: 700 });
    chevron(ctx, pad + heroW - 24, allY + allH / 2, 9, 1, C.ink3, 2);
    this.tapTargets.push({ rect: { x: pad, y: allY, w: heroW, h: allH }, action: () => this.onOpenSelect?.('merge') });

    // ── 车队收藏（图鉴入口 + 首屏必须"看见车"）──
    const colY = allY + allH + 20;
    text(ctx, '我的车队', pad, colY, 14.5, C.ink1, { align: 'left', weight: 800 });
    const unlockedTier = this.progress.targetTier ?? 0;
    text(
      ctx,
      `${Math.min(unlockedTier + 1, this.vehicles.length)} / ${this.vehicles.length}`,
      pad + heroW,
      colY,
      11.5,
      C.ink3,
      { align: 'right', weight: 700 },
    );

    const slotN = 6;
    const slotGap = 8;
    const slotW = (heroW - slotGap * (slotN - 1)) / slotN;
    const slotH = slotW * 1.12;
    const slotY = colY + 16;
    for (let i = 0; i < slotN; i++) {
      const v = this.vehicles[i];
      if (!v) break;
      const sx = pad + i * (slotW + slotGap);
      fillRound(ctx, sx, slotY, slotW, slotH, 14, 'rgba(255,255,255,0.85)');
      const locked = i > unlockedTier;
      const drew = drawSpriteBox(ctx, v.sprite, sx + slotW / 2, slotY + slotH / 2, slotW * 0.62, locked ? 0.3 : 1);
      if (!drew) {
        text(ctx, v.icon, sx + slotW / 2, slotY + slotH / 2, slotW * 0.5, locked ? 'rgba(120,110,140,0.35)' : '#FFFFFF');
      }
      if (locked) {
        fillRound(ctx, sx, slotY, slotW, slotH, 14, 'rgba(255,255,255,0.62)');
        text(ctx, '🔒', sx + slotW / 2, slotY + slotH / 2, slotW * 0.34, '#FFFFFF');
      }
    }

    text(ctx, 'v0.1 · 小游戏预览版', w / 2, h - this.rt.safeArea.bottom - 18, 10.5, C.ink3, { weight: 700 });
  }

  private modeCard(
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    w: number,
    h: number,
    o: {
      emoji: string;
      sprite?: string | null;
      title: string;
      sub: string;
      color: string;
      onTap: () => void;
      onMore: () => void;
    },
  ): void {
    fillRound(ctx, x, y + 4, w, h, 20, 'rgba(50,50,78,0.09)');
    const g = ctx.createLinearGradient(x, y, x + w, y + h);
    g.addColorStop(0, 'rgba(255,255,255,0.97)');
    g.addColorStop(1, css(o.color, 0.16));
    ctx.fillStyle = g;
    roundRect(ctx, x, y, w, h, 20);
    ctx.fill();
    strokeRound(ctx, x, y, w, h, 20, css(o.color, 0.3), 1.2);

    // 车模本身就带车型色，底衬用白半透明才不会"红车压红底"
    fillRound(ctx, x + 12, y + 12, 34, 34, 11, 'rgba(255,255,255,0.9)');
    if (!drawSpriteBox(ctx, o.sprite, x + 29, y + 29, 26)) {
      text(ctx, o.emoji, x + 29, y + 30, 17, '#FFFFFF');
    }

    text(ctx, o.title, x + 12, y + 64, 14.5, C.ink1, { align: 'left', weight: 800 });
    text(ctx, o.sub, x + 12, y + 84, 10.5, C.ink3, { align: 'left', weight: 700 });

    // 右下角 ▶：直接进当前关；点卡片其它位置 = 打开选关
    fillRound(ctx, x + w - 34, y + h - 34, 24, 24, 12, css(o.color, 0.9));
    chevron(ctx, x + w - 22, y + h - 22, 7, 1, '#FFFFFF', 2);
    this.tapTargets.push({ rect: { x: x + w - 40, y: y + h - 40, w: 32, h: 32 }, action: o.onTap });
    this.tapTargets.push({ rect: { x, y, w, h }, action: o.onMore });
  }
}
