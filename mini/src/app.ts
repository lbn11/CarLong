// 应用壳：加载数据 → 选关 ⇄ 单关，主循环。
import { MergeSession } from './core/session.ts';
import type { MergeDataFile, MergeLevelDef, VehicleDataFile, VehicleDef } from './data/types.ts';
import type { PointerEventLite, Runtime } from './platform/runtime.ts';
import { LevelSelectScene } from './ui/level_select.ts';
import { MergeScene } from './ui/merge_scene.ts';

interface Scene {
  update(dt: number): void;
  render(): void;
  onPointer?(e: PointerEventLite): void;
}

const PROGRESS_KEY = 'carlong.progress.v1';

/** 存档：目前只有「已解锁到第几关」。后续金币/星级/Boss 徽章都走这里。 */
interface Progress {
  unlocked: number;
}

export class App {
  private readonly rt: Runtime;
  private readonly levels: readonly MergeLevelDef[];
  private readonly vehicles: readonly VehicleDef[];
  private scene: Scene;
  private current: MergeScene | null = null;
  private progress: Progress;
  private lastT = 0;
  private running = false;

  constructor(rt: Runtime, mergeData: MergeDataFile, vehicleData: VehicleDataFile) {
    this.rt = rt;
    this.levels = mergeData.levels;
    this.vehicles = vehicleData.vehicles;
    this.progress = this.loadProgress();
    this.scene = this.makeSelect();

    rt.onPointer((e) => this.scene.onPointer?.(e));
    rt.onResize(() => {
      /* 布局每帧按当前尺寸重算，无需缓存 */
    });
  }

  private loadProgress(): Progress {
    const raw = this.rt.storage.get(PROGRESS_KEY);
    if (raw) {
      try {
        const p = JSON.parse(raw) as Progress;
        if (typeof p.unlocked === 'number') return { unlocked: Math.max(1, p.unlocked) };
      } catch {
        /* 存档损坏就当新档 */
      }
    }
    return { unlocked: 1 };
  }

  private saveProgress(): void {
    this.rt.storage.set(PROGRESS_KEY, JSON.stringify(this.progress));
  }

  private makeSelect(): LevelSelectScene {
    const s = new LevelSelectScene(this.rt, this.levels, this.progress.unlocked);
    s.onPick = (id) => this.startLevel(id);
    return s;
  }

  private levelById(id: number): MergeLevelDef | undefined {
    return this.levels.find((l) => l.id === id);
  }

  private startLevel(id: number): void {
    const lv = this.levelById(id);
    if (!lv) return;
    const session = new MergeSession(lv, this.vehicles);
    const scene = new MergeScene(this.rt, session, this.vehicles);
    scene.onExit = () => {
      this.current = null;
      this.scene = this.makeSelect();
    };
    scene.onRestart = () => this.startLevel(id);
    scene.onEnd = (status) => {
      // 通关即落档，不依赖玩家点「下一关」
      if (status === 'won') {
        this.progress.unlocked = Math.max(
          this.progress.unlocked,
          Math.min(id + 1, this.levels.length),
        );
        this.saveProgress();
      }
    };
    scene.onNextLevel = () => {
      this.startLevel(Math.min(id + 1, this.levels.length));
    };
    this.current = scene;
    this.scene = scene;
  }

  start(): void {
    this.running = true;
    // 冷启动直接进「当前进度」那一关，比先进空选关页更快进入玩法
    this.startLevel(Math.min(this.progress.unlocked, this.levels.length));
    const loop = (t: number) => {
      if (!this.running) return;
      const dt = this.lastT ? Math.min(0.05, (t - this.lastT) / 1000) : 0.016;
      this.lastT = t;
      const { ctx, dpr, width, height } = this.rt.surface;
      // 每帧重置变换：save/restore 一旦不平衡，后面所有帧都会漂
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, width, height);
      this.scene.update(dt);
      this.scene.render();
      this.rt.raf(loop);
    };
    this.rt.raf(loop);
  }

  stop(): void {
    this.running = false;
  }

  /** 供调试面板/测试读取 */
  get activeSession(): MergeSession | null {
    return this.current?.session ?? null;
  }

  /** 供截图工具/调试读取当前场景（拿布局坐标、触发操作） */
  get activeScene(): MergeScene | null {
    return this.current;
  }
}
