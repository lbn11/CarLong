// 车模精灵层。
//
// App 端那些「玩具车模 3D 打光」的 PNG 是游戏的身份，早先 TS 侧直接拿
// 车型名拼路径（bicycle.png）而文件叫 bike.png，一张都加载不到，于是整块
// 退化成 emoji——玩家看到的就是「画面完全不一样、车里没有车」。
//
// 正确的文件名只有一份真源：Dart `VehicleType.sprite`，随关卡数据一起导出
// 到 `vehicles.json` 的 `sprite` 字段。这里只负责"按 sprite 名字加载/缓存/绘制"，
// 不猜文件名。
//
// 缺图不是错误：没有 sprite 或还没加载完的档位，调用方回退 emoji。
import type { Runtime } from '../platform/runtime.ts';

const BASE = 'assets/vehicles';

const images = new Map<string, any>();

/** 预加载一批车模（传 sprite 名，可含 null/undefined，会被过滤）。 */
export function preloadSprites(rt: Runtime, names: Iterable<string | null | undefined>): Promise<void> {
  const uniq = [...new Set([...names].filter((n): n is string => !!n))];
  const jobs = uniq
    .filter((n) => !images.has(n))
    .map((n) =>
      rt
        .loadImage(`${BASE}/${n}.png`)
        .then((img) => {
          images.set(n, img);
        })
        .catch((err) => {
          // 单张失败只降级成 emoji，不阻塞启动
          console.warn('[carlong] 车模缺失', n, err);
        }),
    );
  return Promise.all(jobs).then(() => undefined);
}

export function spriteOf(name: string | null | undefined): any | undefined {
  return name ? images.get(name) : undefined;
}

export function spriteCount(): number {
  return images.size;
}

/**
 * 把车模画进 (x, y, w, h) 这个矩形，等比缩放不拉伸。
 *
 * `rotateQuarter` 用于停车模式的竖车：车模是侧视图（车头朝右），
 * 转 90° 后车头朝下，正好贴合竖向车身长条。
 * 返回 false 表示没有可用图片——调用方应该退回 emoji。
 */
export function drawSpriteFit(
  ctx: CanvasRenderingContext2D,
  name: string | null | undefined,
  x: number,
  y: number,
  w: number,
  h: number,
  opts: { rotateQuarter?: boolean; alpha?: number; stretch?: boolean } = {},
): boolean {
  const img = spriteOf(name);
  if (!img || !img.width || !img.height) return false;

  const rotate = opts.rotateQuarter === true;
  // 旋转后可用框的长宽互换
  const bw = rotate ? h : w;
  const bh = rotate ? w : h;

  ctx.save();
  if (opts.alpha !== undefined) ctx.globalAlpha = opts.alpha;
  ctx.translate(x + w / 2, y + h / 2);
  if (rotate) ctx.rotate(Math.PI / 2);

  if (opts.stretch) {
    // 停车车身是「沿轴拉长的长条」。车模图是 1:1 方图，但车身只占其中
    // 横向一条（约 80% 宽 × 45% 高）——按方图比例 contain 会让 2 格车
    // 只剩 1/3 长像贴纸。这里改成「按车身实际占比 contain」，
    // 效果是等比放大 1.2~2 倍、填满长条，且不变形。
    const FILL_W = 0.8;
    const FILL_H = 0.45;
    // 收缩系数：与 App 端 `_SpriteBodyPainter._inset` 保持一致，车身别贴边
    const s = Math.min(bw / (img.width * FILL_W), bh / (img.height * FILL_H)) * 0.83;
    const dw = img.width * s;
    const dh = img.height * s;
    ctx.drawImage(img, -dw / 2, -dh / 2, dw, dh);
  } else {
    const scale = Math.min(bw / img.width, bh / img.height);
    const dw = img.width * scale;
    const dh = img.height * scale;
    ctx.drawImage(img, -dw / 2, -dh / 2, dw, dh);
  }
  ctx.restore();
  return true;
}

/**
 * 卡面/图标用：以 (cx, cy) 为中心，按方框 `box` 画一张车模。
 * 车模是 1:1 透明方图、车身横卧居中，所以直接按方框等比画即可。
 */
export function drawSpriteBox(
  ctx: CanvasRenderingContext2D,
  name: string | null | undefined,
  cx: number,
  cy: number,
  box: number,
  alpha?: number,
): boolean {
  const img = spriteOf(name);
  if (!img || !img.width || !img.height) return false;
  ctx.save();
  if (alpha !== undefined) ctx.globalAlpha = alpha;
  // 图里车身只占方框中间横向一条（约 78% 宽），放大一点才撑满视觉面积；
  // 1.42 时车身宽 ≈ 卡面的 72%，与 App 端 emoji 的观感接近。
  // 超出的部分都是透明留白，压不到邻格。
  const s = box * 1.42;
  ctx.drawImage(img, cx - s / 2, cy - s / 2, s, s);
  ctx.restore();
  return true;
}
