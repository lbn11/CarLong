// 应用壳：加载数据 → 选关（双模式）⇄ 单关，主循环。
import { MergeSession } from './core/session.ts';
import { ParkingSession } from './core/parking.ts';
import type {
  MergeDataFile,
  MergeLevelDef,
  ParkingDataFile,
  ParkingLevelDef,
  VehicleDataFile,
  VehicleDef,
} from './data/types.ts';
import type { PointerEventLite, Runtime } from './platform/runtime.ts';
import { LevelSelectScene, type SelectEntry, type SelectMode } from './ui/level_select.ts';
import { MergeScene } from './ui/merge_scene.ts';
import { ParkingScene } from './ui/parking_scene.ts';

interface Scene {
  update(dt: number): void;
  render(): void;
  onPointer?(e: PointerEventLite): void;
}

const PROGRESS_KEY = 'carlong.progress.v2';
/** 旧存档键：只有合并模式时写的 `{unlocked}`，读到就迁移过来 */
const LEGACY_PROGRESS_KEY = 'carlong.progress.v1';

/**
 * 存档。两个模式各记各的解锁进度——合成打到 300 关的人第一次开停车，
 * 不应该被丢到第 1 关之外，但也不该直接给 300。
 */
interface Progress {
  mergeUnlocked: number;
  parkingUnlocked: number;
}

export class App {
  private readonly rt: Runtime;
  private readonly mergeLevels: readonly MergeLevelDef[];
  private readonly parkingLevels: readonly ParkingLevelDef[];
  private readonly vehicles: readonly VehicleDef[];
  private readonly mergeEntries: readonly SelectEntry[];
  private readonly parkingEntries: readonly SelectEntry[];
  private scene: Scene;
  private mergeScene: MergeScene | null = null;
  private parkingScene: ParkingScene | null = null;
  private progress: Progress;
  private lastT = 0;
  private running = false;

  constructor(
    rt: Runtime,
    mergeData: MergeDataFile,
    parkingData: ParkingDataFile,
    vehicleData: VehicleDataFile,
  ) {
    this.rt = rt;
    this.mergeLevels = mergeData.levels;
    this.parkingLevels = parkingData.levels;
    this.vehicles = vehicleData.vehicles;
    this.mergeEntries = mergeData.levels.map((l) => ({ id: l.id, ch: l.ch }));
    this.parkingEntries = parkingData.levels.map((l) => ({
      id: l.id,
      ch: parkingData.chapters.find((c) => l.id >= c.startId && (c.endId === undefined || l.id <= c.endId))?.tier ?? 0,
    }));
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
        const p = JSON.parse(raw) as Partial<Progress>;
        return {
          mergeUnlocked: Math.max(1, p.mergeUnlocked ?? 1),
          parkingUnlocked: Math.max(1, p.parkingUnlocked ?? 1),
        };
      } catch {
        /* 存档损坏就当新档 */
      }
    }
    const legacy = this.rt.storage.get(LEGACY_PROGRESS_KEY);
    if (legacy) {
      try {
        const p = JSON.parse(legacy) as { unlocked?: number };
        return { mergeUnlocked: Math.max(1, p.unlocked ?? 1), parkingUnlocked: 1 };
      } catch {
        /* ignore */
      }
    }
    return { mergeUnlocked: 1, parkingUnlocked: 1 };
  }

  private saveProgress(): void {
    this.rt.storage.set(PROGRESS_KEY, JSON.stringify(this.progress));
  }

  private makeSelect(): LevelSelectScene {
    const s = new LevelSelectScene(
      this.rt,
      { entries: this.mergeEntries, unlocked: this.progress.mergeUnlocked },
      { entries: this.parkingEntries, unlocked: this.progress.parkingUnlocked },
    );
    s.onPick = (mode, id) => this.startLevel(mode, id);
    return s;
  }

  private mergeById(id: number): MergeLevelDef | undefined {
    return this.mergeLevels.find((l) => l.id === id);
  }

  private parkingById(id: number): ParkingLevelDef | undefined {
    return this.parkingLevels.find((l) => l.id === id);
  }

  private startLevel(mode: SelectMode, id: number): void {
    this.mergeScene = null;
    this.parkingScene = null;
    if (mode === 'merge') this.startMergeLevel(id);
    else this.startParkingLevel(id);
  }

  private backToSelect(): void {
    this.mergeScene = null;
    this.parkingScene = null;
    this.scene = this.makeSelect();
  }

  private startMergeLevel(id: number): void {
    const lv = this.mergeById(id);
    if (!lv) return;
    const session = new MergeSession(lv, this.vehicles);
    const scene = new MergeScene(this.rt, session, this.vehicles);
    scene.onExit = () => this.backToSelect();
    scene.onRestart = () => this.startLevel('merge', id);
    scene.onEnd = (status) => {
      // 通关即落档，不依赖玩家点「下一关」
      if (status === 'won') {
        this.progress.mergeUnlocked = Math.max(
          this.progress.mergeUnlocked,
          Math.min(id + 1, this.mergeLevels.length),
        );
        this.saveProgress();
      }
    };
    scene.onNextLevel = () => this.startLevel('merge', Math.min(id + 1, this.mergeLevels.length));
    this.mergeScene = scene;
    this.scene = scene;
  }

  private startParkingLevel(id: number): void {
    const lv = this.parkingById(id);
    if (!lv) return;
    const session = new ParkingSession(lv, this.vehicles);
    const scene = new ParkingScene(this.rt, session, this.vehicles);
    scene.onExit = () => this.backToSelect();
    scene.onRestart = () => this.startLevel('parking', id);
    scene.onEnd = (status) => {
      if (status === 'won') {
        this.progress.parkingUnlocked = Math.max(
          this.progress.parkingUnlocked,
          Math.min(id + 1, this.parkingLevels.length),
        );
        this.saveProgress();
      }
    };
    scene.onNextLevel = () => this.startLevel('parking', Math.min(id + 1, this.parkingLevels.length));
    this.parkingScene = scene;
    this.scene = scene;
  }

  start(): void {
    this.running = true;
    // 冷启动进选关页：现在有两个模式，必须让玩家选一个（以前只有一个模式，
    // 才特意跳过选关直接进关）。选关页已经会自动滚到当前进度那一行。
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
    return this.mergeScene?.session ?? null;
  }

  get activeParking(): ParkingSession | null {
    return this.parkingScene?.session ?? null;
  }

  /** 供截图工具/调试读取当前场景（拿布局坐标、触发操作） */
  get activeScene(): MergeScene | null {
    return this.mergeScene;
  }

  get activeParkingScene(): ParkingScene | null {
    return this.parkingScene;
  }

  /** 调试用：直接跳到某个模式的某一关（截图/验收脚本需要） */
  debugStart(mode: SelectMode, id: number): void {
    this.startLevel(mode, id);
  }
}
