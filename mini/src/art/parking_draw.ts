// 停车模式的美术层。
//
// 与合成模式的差别：合成里的「卡」是抽象棋子，停车里的车是**实物**
// （占地更多、有轮子、能滑很长一段）。所以这里不复用 `drawCard`：
// 车身用更饱和的身份色 + 车轮 + 车顶高光，一眼能看出"这是辆车"，
// 否则玩家会把停车模式当成滑块解谜的色块。
import { fillRound, roundRect, strokeRound, text, textWidth } from './paint.ts';
import { drawSpriteFit } from './sprites.ts';
import { lerpColor, parseColor, rgba } from './theme.ts';

const EMOJI_FONT = '"Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif';

/** 停车场地面 / 车位 / 障碍 / 出入口 */
export function drawParkCell(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  size: number,
  kind: string,
  t: number,
  tierColor: string,
): void {
  const r = size * 0.1;
  if (kind === 'p') {
    // 车位：车型色虚线框 + 幽灵 🅿，呼吸提示「这里就是目标」
    const pulse = 0.5 + 0.5 * Math.sin(t * 2.4);
    fillRound(ctx, x, y, size, size, r, rgba(parseColor(tierColor), 0.1 + 0.06 * pulse));
    ctx.save();
    ctx.setLineDash([size * 0.11, size * 0.08]);
    strokeRound(ctx, x + 1, y + 1, size - 2, size - 2, r, rgba(parseColor(tierColor), 0.75), Math.max(1.5, size * 0.035));
    ctx.restore();
    text(ctx, '🅿', x + size / 2, y + size / 2, size * 0.42, rgba(parseColor(tierColor), 0.5 + 0.2 * pulse), {
      family: EMOJI_FONT,
    });
    return;
  }

  if (kind === 'o') {
    // 石墩：与合成模式的 block 同源视觉，但更扁平（占格不透背景）
    fillRound(ctx, x, y, size, size, r, '#D7D1E2');
    strokeRound(ctx, x, y, size, size, r, 'rgba(255,255,255,0.7)', Math.max(1, size * 0.02));
    const cx = x + size / 2;
    const cy = y + size / 2 + size * 0.02;
    const rad = size * 0.29;
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
    ctx.fillStyle = '#9A92AE';
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(cx - 0.72 * rad, cy - 0.2 * rad);
    ctx.lineTo(cx - 0.34 * rad, cy - 0.72 * rad);
    ctx.lineTo(cx + 0.16 * rad, cy - 0.06 * rad);
    ctx.lineTo(cx - 0.26 * rad, cy + 0.2 * rad);
    ctx.closePath();
    ctx.fillStyle = 'rgba(255,255,255,0.55)';
    ctx.fill();
    return;
  }

  if (kind === 'e' || kind === 'x') {
    // 出入口：深色斜纹 + 箭头。视觉上必须"不像可走的路"，
    // 因为规则里它们确实不可通行（玩家踩过一次就会记住）。
    fillRound(ctx, x, y, size, size, r, '#D8D2E4');
    ctx.save();
    roundRect(ctx, x, y, size, size, r);
    ctx.clip();
    ctx.strokeStyle = 'rgba(255,255,255,0.7)';
    ctx.lineWidth = Math.max(2, size * 0.08);
    for (let i = -1; i < 3; i++) {
      ctx.beginPath();
      ctx.moveTo(x + i * size * 0.5, y + size);
      ctx.lineTo(x + i * size * 0.5 + size, y);
      ctx.stroke();
    }
    ctx.restore();
    text(ctx, kind === 'e' ? '⬇' : '⬆', x + size / 2, y + size / 2, size * 0.32, '#8A82A0', { family: EMOJI_FONT });
    return;
  }

  // 路面：比背景亮一档的"地坪"，靠内阴影表达凹陷
  fillRound(ctx, x, y, size, size, r, 'rgba(255,255,255,0.72)');
  ctx.save();
  roundRect(ctx, x, y, size, size, r);
  ctx.clip();
  const g = ctx.createLinearGradient(x, y, x, y + size * 0.45);
  g.addColorStop(0, 'rgba(50,50,78,0.055)');
  g.addColorStop(1, 'rgba(50,50,78,0)');
  ctx.fillStyle = g;
  ctx.fillRect(x, y, size, size * 0.45);
  ctx.restore();
}

export interface ParkCarOpts {
  icon: string;
  /** 3D 车模 PNG 名；没有的档位回退 icon */
  sprite?: string | null;
  target: boolean;
  selected: boolean;
  /** 车身沿行方向延伸 */
  horiz: boolean;
  alpha?: number;
  /** 弹出动画进度 0..1（1 = 已就位） */
  pop?: number;
}

/** 车辆本体：车身 + 车轮 + 车顶高光 + 车型图标 */
export function drawParkCar(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  tierColor: string,
  opts: ParkCarOpts,
): void {
  const alpha = opts.alpha ?? 1;
  const pop = opts.pop ?? 1;
  const r = Math.min(w, h) * 0.22;

  ctx.save();
  ctx.globalAlpha = alpha;
  if (pop < 1) {
    const cx = x + w / 2;
    const cy = y + h / 2;
    const s = 0.86 + 0.14 * pop;
    ctx.translate(cx, cy);
    ctx.scale(s, s);
    ctx.translate(-cx, -cy);
  }

  const lift = opts.selected ? 3 : 0;

  // 投影：选中时更强、更远，制造「抬起来了」的观感
  fillRound(ctx, x + 1, y + 3 + lift, w - 2, h, r, opts.selected ? 'rgba(50,50,78,0.24)' : 'rgba(50,50,78,0.15)');
  fillRound(ctx, x, y - lift, w, h, r, 'rgba(50,50,78,0.1)');

  // 车轮：沿长轴两端各一组。横车在上下边，纵车在左右边。
  const wheelW = opts.horiz ? Math.min(w * 0.18, h * 0.26) : Math.min(h * 0.18, w * 0.26);
  const wheelH = Math.min(h, w) * 0.13;
  ctx.fillStyle = 'rgba(43,36,64,0.75)';
  const along = opts.horiz ? w : h;
  const positions = along > Math.min(w, h) * 1.6 ? [0.2, 0.8] : [0.28, 0.72];
  for (const p of positions) {
    if (opts.horiz) {
      const wx = x + w * p - wheelW / 2;
      fillRound(ctx, wx, y - lift - wheelH * 0.35, wheelW, wheelH, wheelH * 0.4, 'rgba(43,36,64,0.7)');
      fillRound(ctx, wx, y - lift + h - wheelH * 0.65, wheelW, wheelH, wheelH * 0.4, 'rgba(43,36,64,0.7)');
    } else {
      const wy = y + h * p - wheelW / 2 - lift;
      fillRound(ctx, x - wheelH * 0.35, wy, wheelH, wheelW, wheelH * 0.4, 'rgba(43,36,64,0.7)');
      fillRound(ctx, x + w - wheelH * 0.65, wy, wheelH, wheelW, wheelH * 0.4, 'rgba(43,36,64,0.7)');
    }
  }

  // 车身：饱和身份色渐变（比合成卡片深——实物车不该是粉彩）
  const top = lerpColor(tierColor, '#FFFFFF', 0.34);
  const bot = lerpColor(tierColor, '#1A1630', 0.16);
  const g = ctx.createLinearGradient(x, y - lift, x, y - lift + h);
  g.addColorStop(0, rgba(top));
  g.addColorStop(0.55, rgba(parseColor(tierColor)));
  g.addColorStop(1, rgba(bot));
  ctx.fillStyle = g;
  roundRect(ctx, x, y - lift, w, h, r);
  ctx.fill();

  // 车顶高光条：沿长轴的窄亮带，让车身有圆柱体积感
  ctx.save();
  roundRect(ctx, x, y - lift, w, h, r);
  ctx.clip();
  const isH = opts.horiz;
  const hl = ctx.createLinearGradient(
    isH ? x : x,
    isH ? y - lift : y - lift,
    isH ? x : x + w,
    isH ? y - lift + h * 0.55 : y - lift,
  );
  hl.addColorStop(0, 'rgba(255,255,255,0.42)');
  hl.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = hl;
  ctx.fillRect(x, y - lift, w, h);
  // 底部反光
  ctx.fillStyle = 'rgba(255,255,255,0.16)';
  if (isH) ctx.fillRect(x, y - lift + h * 0.78, w, h * 0.22);
  else ctx.fillRect(x + w * 0.78, y - lift, w * 0.22, h);
  ctx.restore();

  // 描边：目标车用白色 + 车型色双环（一眼认出"我要把它开进去"）
  if (opts.target) {
    strokeRound(ctx, x - 1.5, y - lift - 1.5, w + 3, h + 3, r + 1.5, 'rgba(255,255,255,0.95)', Math.max(2, Math.min(w, h) * 0.055));
    strokeRound(ctx, x, y - lift, w, h, r, rgba(parseColor(tierColor), 0.85), Math.max(1, Math.min(w, h) * 0.02));
  } else {
    strokeRound(ctx, x, y - lift, w, h, r, 'rgba(255,255,255,0.5)', Math.max(1, Math.min(w, h) * 0.025));
  }

  // 图标：优先贴真实车模（竖车转 90°，车头朝下），没有则退回 emoji。
  // 车模是侧视图，等比放进车身内不拉伸——宁可小一圈，也不要变形。
  const box = Math.min(w, h) * (along > Math.min(w, h) * 1.6 ? 0.5 : 0.6);
  const pad = Math.min(w, h) * 0.1;
  const placed = drawSpriteFit(
    ctx,
    opts.sprite,
    x + pad,
    y - lift + pad,
    w - pad * 2,
    h - pad * 2,
    { rotateQuarter: !opts.horiz, stretch: true },
  );
  if (!placed) {
    text(ctx, opts.icon, x + w / 2, y - lift + h / 2, box, '#FFFFFF', { family: EMOJI_FONT });
  }

  // 选中环：外扩一圈虚线，跟"可达箭头"同一色系
  if (opts.selected) {
    ctx.save();
    ctx.setLineDash([5, 4]);
    strokeRound(ctx, x - 4, y - lift - 4, w + 8, h + 8, r + 4, 'rgba(76,194,255,0.95)', 2);
    ctx.restore();
  }
  ctx.restore();
}

/** 可达终点的落点提示：圆 + 指向箭头，告诉玩家「点这里会滑到那儿」 */
export function drawReachHint(
  ctx: CanvasRenderingContext2D,
  cx: number,
  cy: number,
  radius: number,
  dir: 'left' | 'right' | 'up' | 'down',
  color: string,
): void {
  const c = parseColor(color);
  const pulse = 0.5 + 0.5 * Math.sin(Date.now() / 260);
  ctx.save();
  // 底色 + 白描边：停在浅色路面或深色车身上都要能看清
  ctx.fillStyle = rgba(c, 0.34 + 0.16 * pulse);
  ctx.beginPath();
  ctx.arc(cx, cy, radius, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(255,255,255,0.95)';
  ctx.lineWidth = 2;
  ctx.stroke();

  // 箭头（三角），方向即滑动方向
  const s = radius * 0.58;
  const ang = dir === 'right' ? 0 : dir === 'left' ? Math.PI : dir === 'down' ? Math.PI / 2 : -Math.PI / 2;
  ctx.translate(cx, cy);
  ctx.rotate(ang);
  ctx.beginPath();
  ctx.moveTo(s, 0);
  ctx.lineTo(-s * 0.4, -s * 0.66);
  ctx.lineTo(-s * 0.4, s * 0.66);
  ctx.closePath();
  ctx.fillStyle = rgba(c, 1);
  ctx.fill();
  ctx.strokeStyle = 'rgba(255,255,255,0.95)';
  ctx.lineWidth = 1.5;
  ctx.lineJoin = 'round';
  ctx.stroke();
  ctx.restore();
}

/** 可达轨迹上的淡色点：暗示"整条线都能点，点哪停哪" */
export function drawReachTrail(
  ctx: CanvasRenderingContext2D,
  cx: number,
  cy: number,
  cell: number,
  color: string,
): void {
  ctx.save();
  ctx.fillStyle = rgba(parseColor(color), 0.3);
  ctx.beginPath();
  ctx.arc(cx, cy, cell * 0.09, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

/** 顶部信息 chip：图标 + 文本，返回绘制宽度 */
export function infoChip(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  label: string,
  fontSize: number,
  bg: string,
  fg: string,
  align: 'left' | 'right' = 'left',
): number {
  const tw = textWidth(ctx, label, fontSize, 800);
  const w = tw + fontSize * 1.6;
  const h = fontSize * 2;
  const left = align === 'left' ? x : x - w;
  fillRound(ctx, left, y, w, h, h / 2, bg);
  text(ctx, label, left + w / 2, y + h / 2 + 0.5, fontSize, fg, { weight: 800 });
  return w;
}

/** 车位里的目标车"幽灵"（Dart 侧 _buildParkingSlotGhost 的等价物，简化为车内轮廓） */
export function drawGhostCar(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  tierColor: string,
  pulse: number,
): void {
  const r = Math.min(w, h) * 0.22;
  ctx.save();
  ctx.globalAlpha = 0.16 + 0.1 * pulse;
  fillRound(ctx, x, y, w, h, r, rgba(parseColor(tierColor), 1));
  ctx.setLineDash([4, 4]);
  strokeRound(ctx, x, y, w, h, r, rgba(parseColor(tierColor), 0.9), 1.5);
  ctx.restore();
}
