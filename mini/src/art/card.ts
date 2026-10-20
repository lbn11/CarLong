// 卡面绘制 —— 视觉规格 1:1 对齐 Flutter 侧 `StackSprite`：
// 圆角 0.14·size / 身份色渐变 lerp 白 0.66→0.82 / 顶部高光 / 同色投影 /
// 右上角能力徽章 / 右下角 x2 徽章 / 特殊卡（万能虹环·炸弹橙环）。
import type { VehicleDef } from '../data/types.ts';
import type { Stack } from '../core/stack.ts';
import {
  cardGradient,
  fillRound,
  roundRect,
  strokeRound,
  text,
  textWidth,
  vGradient,
  type Ctx,
} from './paint.ts';
import { css, deepen, lerpColor, parseColor, rgba } from './theme.ts';

const EMOJI_FONT = '"Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif';

export interface CardOpts {
  /** 选中：金环 + 抬起阴影 */
  selected?: boolean;
  /** 可合并提示：细环 */
  mergeHint?: boolean;
  /** 缩放（动画用，绕中心） */
  scale?: number;
  /** 透明度 */
  alpha?: number;
  /** 短暂白色闪光（合并瞬间） */
  flash?: number;
}

/** 画一张牌（含投影）。x,y 为左上角，size 为边长。 */
export function drawCard(
  ctx: Ctx,
  x: number,
  y: number,
  size: number,
  stack: Stack,
  vehicle: VehicleDef | undefined,
  opts: CardOpts = {},
): void {
  const scale = opts.scale ?? 1;
  const alpha = opts.alpha ?? 1;
  if (alpha <= 0.01) return;

  const cx = x + size / 2;
  const cy = y + size / 2;

  ctx.save();
  if (opts.alpha !== undefined) ctx.globalAlpha = alpha;

  if (scale !== 1) {
    ctx.translate(cx, cy);
    ctx.scale(scale, scale);
    ctx.translate(-cx, -cy);
  }

  const r = size * 0.14;
  const tierColor = vehicle?.color ?? '#9E9E9E';
  const isSpecial = stack.isWildcard || stack.isBomb;

  // ── 投影：普通车用身份色，特殊卡用中性色（与 Flutter 一致）──
  const shadowColor = isSpecial ? 'rgba(50,50,78,0.16)' : rgba(parseColor(tierColor), 0.22);
  fillRound(ctx, x, y + 3.5, size, size, r, shadowColor);

  // ── 卡面 ──
  if (isSpecial) {
    ctx.fillStyle = vGradient(ctx, x, y, size, [
      { at: 0, color: '#2A313C' },
      { at: 1, color: '#161B22' },
    ]);
  } else {
    ctx.fillStyle = cardGradient(ctx, x, y, size, tierColor);
  }
  roundRect(ctx, x, y, size, size, r);
  ctx.fill();

  // ── 顶部高光（覆盖上 60%，圆角随卡面包容）──
  ctx.save();
  roundRect(ctx, x, y, size, size, r);
  ctx.clip();
  const gloss = ctx.createLinearGradient(x, y, x, y + size * 0.6);
  gloss.addColorStop(0, 'rgba(255,255,255,0.32)');
  gloss.addColorStop(0.45, 'rgba(255,255,255,0.08)');
  gloss.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = gloss;
  ctx.fillRect(x, y, size, size * 0.6);
  ctx.restore();

  // ── 图标 ──
  drawIcon(ctx, x, y, size, stack, vehicle);
  drawAbilityBadge(ctx, x, y, size, vehicle);

  // ── 边框 / 特殊环 ──
  if (stack.isWildcard) {
    // 彩虹环：沿卡片圆角描边（早期版本用整圆 arc，环会冲出卡角破坏形状）
    const ring = ctx.createLinearGradient(x, y, x + size, y + size);
    ring.addColorStop(0, '#FF5252');
    ring.addColorStop(0.3, '#FFCA28');
    ring.addColorStop(0.6, '#42A5F5');
    ring.addColorStop(1, '#AB47BC');
    ctx.strokeStyle = ring;
    ctx.lineWidth = Math.max(2, size * 0.035);
    roundRect(ctx, x, y, size, size, r);
    ctx.stroke();
    strokeRound(ctx, x, y, size, size, r, 'rgba(255,255,255,0.45)', Math.max(1, size * 0.012));
  } else if (stack.isBomb) {
    strokeRound(ctx, x, y, size, size, r, '#FF7043', Math.max(2, size * 0.03));
  } else if (opts.selected) {
    strokeRound(ctx, x, y, size, size, r, '#FFC24B', Math.max(2.5, size * 0.045));
  } else {
    strokeRound(ctx, x, y, size, size, r, rgba(parseColor(tierColor), 0.6), Math.max(1, size * 0.012));
  }

  // 可合并提示环
  if (opts.mergeHint) {
    strokeRound(ctx, x - 3, y - 3, size + 6, size + 6, r + 2, 'rgba(76,194,255,0.85)', Math.max(1.5, size * 0.02));
  }

  // ── x2 徽章 ──
  if (stack.count === 2) {
    const w = size * 0.44;
    const h = w * 0.5;
    const bx = x + size * 0.74 - w / 2;
    const by = y + size * 0.86 - h / 2;
    const top = lerpColor(tierColor, '#FFFFFF', 0.15);
    const bot = deepen(parseColor(tierColor), 0.12);
    ctx.fillStyle = vGradient(ctx, bx, by, h, [
      { at: 0, color: rgba(top) },
      { at: 1, color: rgba(bot) },
    ]);
    roundRect(ctx, bx, by, w, h, h / 2);
    ctx.fill();
    text(ctx, '×2', bx + w / 2, by + h / 2 + 0.5, h * 0.66, '#FFFFFF', { weight: 800 });
  }

  // ── 合并闪光 ──
  if (opts.flash && opts.flash > 0.01) {
    fillRound(ctx, x, y, size, size, r, `rgba(255,255,255,${(0.45 * opts.flash).toFixed(3)})`);
  }

  // ── 冰封 / 胶水覆盖 ──
  if (stack.frozen > 0) {
    fillRound(ctx, x, y, size, size, r, 'rgba(179,229,252,0.55)');
    strokeRound(ctx, x, y, size, size, r, 'rgba(255,255,255,0.9)', Math.max(1.5, size * 0.025));
    drawFrozenDots(ctx, x, y, size, stack.frozen);
  } else if (stack.glueT > 0) {
    fillRound(ctx, x, y, size, size, r, 'rgba(255,193,7,0.5)');
    strokeRound(ctx, x, y, size, size, r, 'rgba(255,224,130,0.9)', Math.max(1.5, size * 0.025));
    text(ctx, '🍯', x + size * 0.72, y + size * 0.28, size * 0.34, '#FFFFFF', { family: EMOJI_FONT });
  }

  ctx.restore();
}

function drawIcon(
  ctx: Ctx,
  x: number,
  y: number,
  size: number,
  stack: Stack,
  vehicle: VehicleDef | undefined,
): void {
  const box = size * 0.62;
  const cx = x + size / 2;
  const cy = y + size / 2;
  if (stack.isWildcard) {
    drawWildcardIcon(ctx, cx, cy, box);
  } else if (stack.isBomb) {
    drawBombIcon(ctx, cx, cy, box);
  } else {
    const icon = vehicle?.icon ?? '🚗';
    text(ctx, icon, cx, cy + box * 0.04, box, '#FFFFFF', { family: EMOJI_FONT });
  }
}

/** 万能卡：四色星芒圆盘 */
function drawWildcardIcon(ctx: Ctx, cx: number, cy: number, box: number): void {
  const r = box * 0.44;
  const g = ctx.createLinearGradient(cx - r, cy - r, cx + r, cy + r);
  g.addColorStop(0, '#FF5252');
  g.addColorStop(0.35, '#FFCA28');
  g.addColorStop(0.7, '#42A5F5');
  g.addColorStop(1, '#AB47BC');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(255,255,255,0.85)';
  ctx.lineWidth = Math.max(1.5, box * 0.04);
  ctx.stroke();
  // 中心星形
  ctx.fillStyle = 'rgba(255,255,255,0.95)';
  ctx.beginPath();
  const spikes = 5;
  const outer = r * 0.58;
  const inner = outer * 0.45;
  for (let i = 0; i < spikes * 2; i++) {
    const rad = i % 2 === 0 ? outer : inner;
    const a = -Math.PI / 2 + (Math.PI / spikes) * i;
    const px = cx + Math.cos(a) * rad;
    const py = cy + Math.sin(a) * rad;
    if (i === 0) ctx.moveTo(px, py);
    else ctx.lineTo(px, py);
  }
  ctx.closePath();
  ctx.fill();
}

/** 炸弹卡：深色圆 + 引信 */
function drawBombIcon(ctx: Ctx, cx: number, cy: number, box: number): void {
  const r = box * 0.4;
  fillRound(ctx, cx - r, cy - r * 0.85, r * 2, r * 1.85, r, '#1A1E24');
  // 高光
  ctx.fillStyle = 'rgba(255,255,255,0.28)';
  ctx.beginPath();
  ctx.ellipse(cx - r * 0.35, cy - r * 0.4, r * 0.28, r * 0.18, -0.5, 0, Math.PI * 2);
  ctx.fill();
  // 引信 + 火花
  ctx.strokeStyle = '#FFB74D';
  ctx.lineWidth = Math.max(1.5, box * 0.045);
  ctx.setLineDash([]);
  ctx.beginPath();
  ctx.moveTo(cx + r * 0.25, cy - r * 0.75);
  ctx.quadraticCurveTo(cx + r * 0.75, cy - r * 1.1, cx + r * 0.5, cy - r * 1.45);
  ctx.stroke();
  ctx.fillStyle = '#FF7043';
  ctx.beginPath();
  ctx.arc(cx + r * 0.5, cy - r * 1.5, box * 0.09, 0, Math.PI * 2);
  ctx.fill();
}

function drawFrozenDots(ctx: Ctx, x: number, y: number, size: number, layers: number): void {
  const dotR = size * 0.045;
  const gap = dotR * 2.6;
  const totalW = gap * (Math.min(layers, 3) - 1);
  for (let i = 0; i < Math.min(layers, 3); i++) {
    ctx.fillStyle = 'rgba(255,255,255,0.95)';
    ctx.beginPath();
    ctx.arc(x + size / 2 - totalW / 2 + gap * i, y + size * 0.82, dotR, 0, Math.PI * 2);
    ctx.fill();
  }
}

/** 能力徽章文案（对应 Dart `SpecialAbility.label`） */
export const ABILITY_LABEL: Record<string, string> = {
  turn: '转弯',
  flyOver: '飞越',
  breakIce: '破冰',
  breakChain: '解锁',
  clearRock: '清石',
  waterWalk: '水上',
  railOnly: '轨道',
  teleport: '传送',
  pickup: '搬运',
  sonar: '侦察',
  vertical: '垂起',
  amphibious: '两栖',
  tow: '拖拽',
  carry: '装载',
  warp: '曲速',
};

/** 右上角能力徽章（非 none 时）。小卡上字号收敛，否则会盖住车模 */
export function drawAbilityBadge(ctx: Ctx, x: number, y: number, size: number, vehicle: VehicleDef | undefined): void {
  const ability = vehicle?.ability ?? 'none';
  if (!ability || ability === 'none') return;
  const label = ABILITY_LABEL[ability] ?? ability;
  const fontSize = Math.max(7.5, size * 0.125);
  const tw = textWidth(ctx, label, fontSize, 700);
  const padX = fontSize * 0.3;
  const padY = fontSize * 0.16;
  const w = tw + padX * 2;
  const h = fontSize + padY * 2;
  const px = x + size - w / 2 - 3;
  const py = y + h / 2 + 3;
  fillRound(ctx, px - w / 2, py - h / 2, w, h, h / 2, 'rgba(26,30,36,0.72)');
  text(ctx, label, px, py + 0.5, fontSize, '#FFFFFF', { weight: 700 });
}

/** 空槽位（棋盘格背景） */
export function drawSlot(ctx: Ctx, x: number, y: number, size: number): void {
  const r = size * 0.14;
  fillRound(ctx, x, y, size, size, r, 'rgba(255,255,255,0.55)');
  strokeRound(ctx, x, y, size, size, r, css('#EDE6F2'), 1);
  // 顶部内高光，让槽位有"凹陷"感
  ctx.save();
  roundRect(ctx, x, y, size, size, r);
  ctx.clip();
  const g = ctx.createLinearGradient(x, y, x, y + size * 0.4);
  g.addColorStop(0, 'rgba(50,50,78,0.05)');
  g.addColorStop(1, 'rgba(50,50,78,0)');
  ctx.fillStyle = g;
  ctx.fillRect(x, y, size, size * 0.4);
  ctx.restore();
}

/** 障碍物绘制：冰 / 锁 / 石块 / 传送门 */
export function drawObstacle(
  ctx: Ctx,
  x: number,
  y: number,
  size: number,
  kind: string,
  layers: number,
  t: number,
): void {
  const r = size * 0.14;
  if (kind === 'ice') {
    // 冰层：层数越高越厚（视觉上用透明度 + 边线表达）
    const a = 0.35 + 0.2 * Math.min(layers, 3);
    fillRound(ctx, x, y, size, size, r, `rgba(129,212,250,${a.toFixed(2)})`);
    strokeRound(ctx, x, y, size, size, r, 'rgba(255,255,255,0.9)', Math.max(1.5, size * 0.025));
    // 冰裂纹
    ctx.strokeStyle = 'rgba(255,255,255,0.7)';
    ctx.lineWidth = Math.max(1, size * 0.018);
    ctx.beginPath();
    ctx.moveTo(x + size * 0.28, y + size * 0.2);
    ctx.lineTo(x + size * 0.42, y + size * 0.46);
    ctx.lineTo(x + size * 0.26, y + size * 0.68);
    ctx.moveTo(x + size * 0.62, y + size * 0.22);
    ctx.lineTo(x + size * 0.72, y + size * 0.5);
    ctx.lineTo(x + size * 0.58, y + size * 0.78);
    ctx.stroke();
    text(ctx, '❄', x + size * 0.62, y + size * 0.74, size * 0.3, 'rgba(255,255,255,0.95)', { family: EMOJI_FONT });
  } else if (kind === 'lock') {
    fillRound(ctx, x, y, size, size, r, 'rgba(120,106,140,0.9)');
    strokeRound(ctx, x, y, size, size, r, 'rgba(255,255,255,0.35)', Math.max(1, size * 0.02));
    text(ctx, '🔒', x + size / 2, y + size / 2, size * 0.5, '#FFFFFF', { family: EMOJI_FONT });
  } else if (kind === 'block') {
    fillRound(ctx, x, y, size, size, r, '#CFC9DA');
    strokeRound(ctx, x, y, size, size, r, 'rgba(255,255,255,0.5)', Math.max(1, size * 0.02));
    // 石块：不规则多边形 + 受光面（两块圆点会看成盲文）
    const cx = x + size / 2;
    const cy = y + size / 2 + size * 0.02;
    const rad = size * 0.31;
    const shape: [number, number][] = [
      [-0.92, -0.28],
      [-0.42, -0.92],
      [0.42, -0.8],
      [0.94, -0.06],
      [0.58, 0.76],
      [-0.24, 0.94],
      [-0.88, 0.46],
    ];
    ctx.beginPath();
    shape.forEach(([px, py], i) => {
      const X = cx + px * rad;
      const Y = cy + py * rad;
      if (i === 0) ctx.moveTo(X, Y);
      else ctx.lineTo(X, Y);
    });
    ctx.closePath();
    ctx.fillStyle = '#A9A2B8';
    ctx.fill();
    // 受光面
    ctx.beginPath();
    ctx.moveTo(cx - 0.72 * rad, cy - 0.2 * rad);
    ctx.lineTo(cx - 0.34 * rad, cy - 0.72 * rad);
    ctx.lineTo(cx + 0.16 * rad, cy - 0.06 * rad);
    ctx.lineTo(cx - 0.26 * rad, cy + 0.2 * rad);
    ctx.closePath();
    ctx.fillStyle = 'rgba(255,255,255,0.55)';
    ctx.fill();
  } else if (kind === 'teleport') {
    const pulse = 0.5 + 0.5 * Math.sin(t * 3);
    const g = ctx.createRadialGradient(x + size / 2, y + size / 2, 0, x + size / 2, y + size / 2, size * 0.55);
    g.addColorStop(0, `rgba(100,216,230,${0.55 + 0.25 * pulse})`);
    g.addColorStop(1, 'rgba(100,216,230,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(x + size / 2, y + size / 2, size * 0.55, 0, Math.PI * 2);
    ctx.fill();
    // 漩涡环
    ctx.strokeStyle = `rgba(76,194,255,${0.6 + 0.3 * pulse})`;
    ctx.lineWidth = Math.max(1.5, size * 0.035);
    ctx.beginPath();
    ctx.arc(x + size / 2, y + size / 2, size * 0.3, t * 2, t * 2 + Math.PI * 1.4);
    ctx.stroke();
    text(ctx, '🌀', x + size / 2, y + size / 2, size * 0.34, '#FFFFFF', { family: EMOJI_FONT });
  }
}
