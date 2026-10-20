// 宿主抽象层。
//
// 小游戏端和 Web 端的差异只有五件事：拿画布、读文件、存存档、收触摸、
// 拿到帧回调。全部收敛到这一个接口，上层（core / art / ui）不允许出现
// `wx.` 或 `document.`。
import { host, isMiniGame, type Host } from './env.ts';

export interface Surface {
  /** 真实 canvas 对象（web: HTMLCanvasElement / wx: Canvas） */
  canvas: any;
  ctx: CanvasRenderingContext2D;
  /** 逻辑宽高（CSS px / 小游戏 screenWidth） */
  width: number;
  height: number;
  dpr: number;
}

export interface SafeArea {
  top: number;
  bottom: number;
}

export interface Runtime {
  host: Host;
  surface: Surface;
  safeArea: SafeArea;
  storage: {
    get(key: string): string | null;
    set(key: string, value: string): void;
    remove(key: string): void;
  };
  /** 读文本文件（关卡 JSON） */
  loadText(path: string): Promise<string>;
  /**
   * 读图片（车模 PNG）。返回宿主原生 image 对象，可直接喂给 drawImage。
   * 加载失败不 reject 成致命错误——车模是装饰，缺一张应该退回 emoji 而不是崩。
   */
  loadImage(path: string): Promise<any>;
  /** 帧回调，参数为毫秒时间戳 */
  raf(cb: (t: number) => void): void;
  /** 尺寸变化（web 旋转/缩放；小游戏仅 onWindowResize） */
  onResize(cb: () => void): void;
  /** 触摸/鼠标按下抬起，坐标已换算为逻辑像素 */
  onPointer(cb: (e: PointerEventLite) => void): void;
}

export interface PointerEventLite {
  type: 'down' | 'move' | 'up';
  x: number;
  y: number;
}

declare const wx: any;

// ─────────────────────────── Web ───────────────────────────
function createWebRuntime(): Runtime {
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d', { alpha: false })!;
  const app = document.getElementById('app') ?? document.body;
  canvas.style.touchAction = 'none';
  app.appendChild(canvas);

  const dpr = Math.min(window.devicePixelRatio || 1, 3);
  const surface: Surface = {
    canvas,
    ctx,
    width: 0,
    height: 0,
    dpr,
  };

  function resize(): void {
    const w = app.clientWidth || window.innerWidth;
    const h = app.clientHeight || window.innerHeight;
    surface.width = w;
    surface.height = h;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    // 每帧开头重置变换，这里只需建一次基准缩放。
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  resize();

  window.addEventListener('resize', resize);
  window.addEventListener('orientationchange', resize);

  const pointerCbs: ((e: PointerEventLite) => void)[] = [];
  const toLocal = (e: PointerEvent | MouseEvent) => {
    const r = canvas.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };
  canvas.addEventListener('pointerdown', (e) => {
    e.preventDefault();
    const p = toLocal(e);
    pointerCbs.forEach((cb) => cb({ type: 'down', ...p }));
  });
  canvas.addEventListener('pointermove', (e) => {
    if (e.buttons === 0 && e.pointerType === 'mouse') return;
    const p = toLocal(e);
    pointerCbs.forEach((cb) => cb({ type: 'move', ...p }));
  });
  canvas.addEventListener('pointerup', (e) => {
    const p = toLocal(e);
    pointerCbs.forEach((cb) => cb({ type: 'up', ...p }));
  });
  canvas.addEventListener('pointercancel', () => {
    pointerCbs.forEach((cb) => cb({ type: 'up', x: -1, y: -1 }));
  });

  return {
    host: 'web',
    surface,
    safeArea: { top: 0, bottom: 0 },
    storage: {
      get: (k) => {
        try {
          return window.localStorage.getItem(k);
        } catch {
          return null;
        }
      },
      set: (k, v) => {
        try {
          window.localStorage.setItem(k, v);
        } catch {
          /* 隐私模式忽略 */
        }
      },
      remove: (k) => {
        try {
          window.localStorage.removeItem(k);
        } catch {
          /* ignore */
        }
      },
    },
    loadText: async (path) => {
      const res = await fetch(path);
      if (!res.ok) throw new Error(`加载失败 ${path}: ${res.status}`);
      return res.text();
    },
    loadImage: (path) =>
      new Promise((resolve, reject) => {
        const img = new Image();
        img.onload = () => resolve(img);
        img.onerror = () => reject(new Error(`图片加载失败 ${path}`));
        img.src = path;
      }),
    raf: (cb) => requestAnimationFrame(cb),
    onResize: (cb) => {
      window.addEventListener('resize', cb);
      window.addEventListener('orientationchange', cb);
    },
    onPointer: (cb) => pointerCbs.push(cb),
  };
}

// ─────────────────────── 微信 / 抖音小游戏 ───────────────────────
// 两个平台的 canvas / 文件 / 触摸 API 形状基本一致（抖音提供了 wx 兼容层，
// 但主入口是 tt），差异收敛在 pick(name) 里。
function createMiniGameRuntime(): Runtime {
  const api: any = (globalThis as any).tt ?? wx;
  const canvas: any = api.createCanvas();
  const ctx = canvas.getContext('2d') as CanvasRenderingContext2D;

  const info = api.getSystemInfoSync();
  const dpr = Math.min(info.pixelRatio || 1, 3);
  const surface: Surface = { canvas, ctx, width: 0, height: 0, dpr };

  function resize(): void {
    const s = api.getSystemInfoSync();
    surface.width = s.windowWidth;
    surface.height = s.windowHeight;
    canvas.width = Math.round(s.windowWidth * dpr);
    canvas.height = Math.round(s.windowHeight * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  resize();

  const safe = info.safeArea;
  const safeArea: SafeArea = {
    top: Math.max(0, (safe?.top ?? 0) - (info.statusBarHeight ?? 0)),
    bottom: Math.max(0, (info.screenHeight ?? info.windowHeight) - (safe?.bottom ?? info.screenHeight)),
  };

  const pointerCbs: ((e: PointerEventLite) => void)[] = [];
  const pick = (t: any): PointerEventLite => ({
    type: 'move',
    x: t.clientX ?? t.x ?? 0,
    y: t.clientY ?? t.y ?? 0,
  });
  api.onTouchStart((e: any) => {
    const p = pick(e.touches[0] ?? e.changedTouches[0]);
    pointerCbs.forEach((cb) => cb({ ...p, type: 'down' }));
  });
  api.onTouchMove((e: any) => {
    const p = pick(e.touches[0] ?? e.changedTouches[0]);
    pointerCbs.forEach((cb) => cb({ ...p, type: 'move' }));
  });
  api.onTouchEnd((e: any) => {
    const t = e.changedTouches[0] ?? e.touches[0];
    const p = t ? pick(t) : { x: -1, y: -1 };
    pointerCbs.forEach((cb) => cb({ ...p, type: 'up' }));
  });

  const fs = api.getFileSystemManager();

  return {
    host,
    surface,
    safeArea,
    storage: {
      get: (k) => {
        try {
          const v = api.getStorageSync(k);
          return typeof v === 'string' && v.length ? v : null;
        } catch {
          return null;
        }
      },
      set: (k, v) => {
        try {
          api.setStorageSync(k, v);
        } catch {
          /* ignore */
        }
      },
      remove: (k) => {
        try {
          api.removeStorageSync(k);
        } catch {
          /* ignore */
        }
      },
    },
    loadText: (path) =>
      new Promise((resolve, reject) => {
        try {
          // 代码包内文件用相对路径直接读（不需要用户授权）。
          const data = fs.readFileSync(path, 'utf8');
          resolve(typeof data === 'string' ? data : new TextDecoder().decode(data));
        } catch (err) {
          reject(err);
        }
      }),
    loadImage: (path) =>
      new Promise((resolve, reject) => {
        const img = api.createImage();
        img.onload = () => resolve(img);
        img.onerror = (err: unknown) => reject(err ?? new Error(`图片加载失败 ${path}`));
        img.src = path;
      }),
    raf: (cb) => {
      // 小游戏有全局 requestAnimationFrame，部分环境挂在 canvas 上。
      const g: any = globalThis;
      (g.requestAnimationFrame ?? g.canvas?.requestAnimationFrame ?? ((f: any) => setTimeout(() => f(Date.now()), 16)))(cb);
    },
    onResize: (cb) => api.onWindowResize(() => { resize(); cb(); }),
    onPointer: (cb) => pointerCbs.push(cb),
  };
}

export function createRuntime(): Runtime {
  return isMiniGame ? createMiniGameRuntime() : createWebRuntime();
}
