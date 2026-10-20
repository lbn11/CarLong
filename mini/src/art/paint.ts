// Canvas2D 绘制原语。
//
// 小游戏不支持 OffscreenCanvas 的某些特性、也没有 Flutter 的 MaskFilter
// 模糊，所以「柔和阴影」一律用半透明圆角矩形位移模拟，不用 shadowBlur
// （后者在中低端机上是主要掉帧源）。
import { css, lerpColor, rgba, type Rgba } from './theme.ts';

export type Ctx = CanvasRenderingContext2D;

export function roundRect(
  ctx: Ctx,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
): void {
  const rr = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.lineTo(x + w - rr, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + rr);
  ctx.lineTo(x + w, y + h - rr);
  ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
  ctx.lineTo(x + rr, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - rr);
  ctx.lineTo(x, y + rr);
  ctx.quadraticCurveTo(x, y, x + rr, y);
  ctx.closePath();
}

export function fillRound(
  ctx: Ctx,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
  color: string,
): void {
  ctx.fillStyle = color;
  roundRect(ctx, x, y, w, h, r);
  ctx.fill();
}

export function strokeRound(
  ctx: Ctx,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
  color: string,
  lineWidth = 1,
): void {
  ctx.strokeStyle = color;
  ctx.lineWidth = lineWidth;
  roundRect(ctx, x, y, w, h, r);
  ctx.stroke();
}

/** 纵向线性渐变填充圆角矩形 */
export function vGradient(
  ctx: Ctx,
  x: number,
  y: number,
  h: number,
  stops: { at: number; color: string }[],
): CanvasGradient {
  const g = ctx.createLinearGradient(x, y, x, y + h);
  for (const s of stops) g.addColorStop(Math.max(0, Math.min(1, s.at)), s.color);
  return g;
}

/** 卡片身份色渐变：顶部亮、底部更亮（与 Flutter lerp white 0.66/0.82 一致） */
export function cardGradient(ctx: Ctx, x: number, y: number, h: number, tierColor: string): CanvasGradient {
  const top = lerpColor(tierColor, '#FFFFFF', 0.66);
  const bot = lerpColor(tierColor, '#FFFFFF', 0.82);
  return vGradient(ctx, x, y, h, [
    { at: 0, color: rgba(top) },
    { at: 1, color: rgba(bot) },
  ]);
}

export function text(
  ctx: Ctx,
  str: string,
  x: number,
  y: number,
  size: number,
  color: string,
  opts: { align?: CanvasTextAlign; baseline?: CanvasTextBaseline; weight?: string | number; family?: string } = {},
): void {
  ctx.fillStyle = color;
  ctx.font = `${opts.weight ?? 400} ${size}px ${opts.family ?? '"Nunito","PingFang SC","Noto Sans SC",sans-serif'}`;
  ctx.textAlign = opts.align ?? 'center';
  ctx.textBaseline = opts.baseline ?? 'middle';
  ctx.fillText(str, x, y);
}

export function textWidth(ctx: Ctx, str: string, size: number, weight: string | number = 400, family?: string): number {
  ctx.font = `${weight} ${size}px ${family ?? '"Nunito","PingFang SC","Noto Sans SC",sans-serif'}`;
  return ctx.measureText(str).width;
}

/** 药丸底 + 文字（Candy 组件库的 SoftChip 视觉） */
export function pill(
  ctx: Ctx,
  cx: number,
  cy: number,
  label: string,
  fontSize: number,
  bg: string,
  fg: string,
  padX = fontSize * 0.7,
  padY = fontSize * 0.34,
): { w: number; h: number } {
  const tw = textWidth(ctx, label, fontSize, 700);
  const w = tw + padX * 2;
  const h = fontSize + padY * 2;
  fillRound(ctx, cx - w / 2, cy - h / 2, w, h, h / 2, bg);
  text(ctx, label, cx, cy + 0.5, fontSize, fg, { weight: 700 });
  return { w, h };
}

/** 圆头折线箭头。dir = 尖端朝向（-1 左 / 1 右）。 */
export function chevron(
  ctx: Ctx,
  cx: number,
  cy: number,
  size: number,
  dir: -1 | 1,
  color: string,
  lineWidth?: number,
): void {
  ctx.save();
  ctx.strokeStyle = color;
  ctx.lineWidth = lineWidth ?? Math.max(2, size * 0.18);
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  // 尾部在上/下两侧，尖端在 dir 一侧
  ctx.moveTo(cx - dir * size * 0.22, cy - size * 0.3);
  ctx.lineTo(cx + dir * size * 0.2, cy);
  ctx.lineTo(cx - dir * size * 0.22, cy + size * 0.3);
  ctx.stroke();
  ctx.restore();
}

/** 全屏背景渐变（奶油 → 粉雾 → 天空） */export function paintBackdrop(ctx: Ctx, w: number, h: number): void {
  const g = ctx.createLinearGradient(0, 0, w * 0.4, h);
  g.addColorStop(0, css('#FCF3EA'));
  g.addColorStop(0.55, css('#FDE7F1'));
  g.addColorStop(1, css('#E7F1FF'));
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);
}

/** 柔和光斑（背景装饰，营造层次而不抢主体） */
export function softBlob(ctx: Ctx, cx: number, cy: number, r: number, color: Rgba, alpha: number): void {
  const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
  g.addColorStop(0, rgba(color, alpha));
  g.addColorStop(1, rgba(color, 0));
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.fill();
}
