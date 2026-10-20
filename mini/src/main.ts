// 入口：两条平台路径在这里汇合。
//
// web:    <script src="bundle.js"> → 直接用 DOM canvas
// wechat: game.js（由 build 产物改名）→ wx.createCanvas()
import { App } from './app.ts';
import { preloadSprites } from './art/sprites.ts';
import { minMovesOf, solveParking } from './core/parking.ts';
import type { MergeDataFile, ParkingDataFile, VehicleDataFile } from './data/types.ts';
import { host } from './platform/env.ts';
import { createRuntime } from './platform/runtime.ts';

async function boot(): Promise<void> {
  const rt = createRuntime();
  try {
    const [mergeRaw, parkingRaw, vehicleRaw] = await Promise.all([
      rt.loadText('levels/merge_levels.json'),
      rt.loadText('levels/parking_levels.json'),
      rt.loadText('levels/vehicles.json'),
    ]);
    const mergeData = JSON.parse(mergeRaw) as MergeDataFile;
    const parkingData = JSON.parse(parkingRaw) as ParkingDataFile;
    const vehicleData = JSON.parse(vehicleRaw) as VehicleDataFile;
    if (mergeData.count !== mergeData.levels.length) {
      throw new Error(`合成关数不一致：${mergeData.count} vs ${mergeData.levels.length}`);
    }
    if (parkingData.count !== parkingData.levels.length) {
      throw new Error(`停车关数不一致：${parkingData.count} vs ${parkingData.levels.length}`);
    }
    // 车模先到再开场：晚到的图会让第一屏"没有车"，宁可多等一两百毫秒。
    // 单张失败不阻塞（preloadSprites 内部已吞掉），缺图档位回退 emoji。
    await preloadSprites(rt, vehicleData.vehicles.map((v) => v.sprite));
    const app = new App(rt, mergeData, parkingData, vehicleData);
    app.start();
    // 挂到全局便于在控制台/开发者工具里检查（小游戏调试必备）
    // 求解器一起挂出去：截图工具要靠它自动打完停车关验收结算面板
    (globalThis as unknown as { __carlong?: unknown }).__carlong = { app, host, solveParking, minMovesOf };
  } catch (err) {
    console.error('[carlong] 启动失败', err);
    const { ctx, width, height } = rt.surface;
    ctx.fillStyle = '#FCF3EA';
    ctx.fillRect(0, 0, width, height);
    ctx.fillStyle = '#E53935';
    ctx.font = '14px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('启动失败，看控制台', width / 2, height / 2);
    ctx.fillText(String(err), width / 2, height / 2 + 22);
  }
}

void boot();
