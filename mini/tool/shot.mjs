// 无头截图：用本机 Chrome 打开预览页，按脚本点几下再截图。
//
// 用途是「改完能自己看见效果」，不是自动化测试——所以它只做三件事：
// 打开、模拟触摸、落图。断言留给 test/。
//
// 用法：
//   node tool/shot.mjs                     合成模式，第 1 关
//   MODE=parking LEVEL=40 node tool/shot.mjs   停车模式，第 40 关
//   AUTO=1 MODE=parking LEVEL=1 ...            自动通关，验收结算面板
//
// playwright-core 来自 WorkBuddy 的共享 node_modules（不污染本项目依赖），
// 因此走绝对路径动态 import：ESM 的 NODE_PATH 不生效，import 目录也不合规。
import fs from 'node:fs';

const PW =
  process.env.PW_MODULE ??
  '/Users/apple/.workbuddy/binaries/node/workspace/node_modules/playwright-core/index.mjs';
const { chromium } = await import(PW);

const URL_BASE = process.env.URL ?? 'http://127.0.0.1:58880/';
const OUT = process.env.OUT ?? '/tmp/carlong_mini';
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const MODE = process.env.MODE === 'parking' ? 'parking' : 'merge';
const LEVEL = Number(process.env.LEVEL ?? 1);
const AUTO = process.env.AUTO === '1';

fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({ executablePath: CHROME, headless: true });
const page = await browser.newPage({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  isMobile: true,
  hasTouch: true,
});

const logs = [];
page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));

await page.goto(URL_BASE, { waitUntil: 'networkidle' });
await page.waitForTimeout(700);

// 冷启动进选关页（两个模式必须让玩家选）
await page.screenshot({ path: `${OUT}/01_select.png` });

// 进关：走 app.debugStart，不依赖存档推进（否则每次验收都要先改 localStorage）
await page.evaluate(
  ([mode, id]) => globalThis.__carlong.app.debugStart(mode, id),
  [MODE, LEVEL],
);
await page.waitForTimeout(450);
await page.screenshot({ path: `${OUT}/02_level.png` });

if (MODE === 'merge') {
  await shotMerge();
} else {
  await shotParking();
}

async function shotMerge() {
  // 点牌堆出牌：坐标直接读场景布局，不在工具侧复算公式
  const deckPos = await page.evaluate(() => {
    const l = globalThis.__carlong?.app?.activeScene?.layoutForDebug?.();
    if (!l) return null;
    return l.deckSlots.map((s) => ({ x: s.x + s.w / 2, y: s.y + s.h / 2 }));
  });
  if (!deckPos) throw new Error('拿不到布局：合成场景未就绪');
  for (let i = 0; i < 6; i++) {
    await page.mouse.click(deckPos[0].x, deckPos[0].y);
    await page.waitForTimeout(150);
  }
  await page.screenshot({ path: `${OUT}/03_dealt.png` });

  const cellPos = await page.evaluate(() => {
    const g = globalThis.__carlong;
    const s = g?.app?.activeSession;
    const l = g?.app?.activeScene?.layoutForDebug?.();
    if (!s || !l) return null;
    const cells = [];
    for (let c = 0; c < s.level.cols; c++) {
      for (let r = 0; r < s.level.rows; r++) {
        const st = s.board.at(c, r);
        if (!st) continue;
        cells.push({
          c,
          r,
          tier: st.tier,
          x: l.boardX + c * (l.cell + l.gap) + l.cell / 2,
          y: l.boardY + r * (l.cell + l.gap) + l.cell / 2,
        });
      }
    }
    return { cells };
  });

  if (cellPos) {
    const byTier = new Map();
    for (const c of cellPos.cells) {
      if (!byTier.has(c.tier)) byTier.set(c.tier, []);
      byTier.get(c.tier).push(c);
    }
    const pair = [...byTier.values()].find((arr) => arr.length >= 2);
    if (pair) {
      await page.mouse.click(pair[0].x, pair[0].y);
      await page.waitForTimeout(120);
      await page.mouse.click(pair[1].x, pair[1].y);
      await page.waitForTimeout(380);
      await page.screenshot({ path: `${OUT}/04_merged.png` });
    }
  }

  if (AUTO) {
    const result = await page.evaluate(() => {
      const s = globalThis.__carlong.app.activeSession;
      const snap = () => {
        const out = [];
        for (let c = 0; c < s.level.cols; c++) {
          for (let r = 0; r < s.level.rows; r++) {
            const st = s.board.at(c, r);
            if (st) out.push({ c, r, tier: st.tier, bomb: st.isBomb, wild: st.isWildcard });
          }
        }
        return out;
      };
      let guard = 0;
      while (s.status === 'playing' && guard++ < 600) {
        const cells = snap();
        let pair = null;
        for (const a of cells) {
          if (a.bomb) {
            const b = cells.find((x) => x.bomb && (x.c !== a.c || x.r !== a.r));
            if (b) {
              pair = [a, b];
              break;
            }
          }
        }
        if (!pair) {
          outer: for (let i = 0; i < cells.length; i++) {
            for (let j = i + 1; j < cells.length; j++) {
              if (
                !cells[i].bomb &&
                !cells[i].wild &&
                !cells[j].bomb &&
                !cells[j].wild &&
                cells[i].tier === cells[j].tier
              ) {
                pair = [cells[i], cells[j]];
                break outer;
              }
            }
          }
        }
        if (!pair) {
          const w = cells.find((x) => x.wild);
          const n = cells.find((x) => !x.wild && !x.bomb);
          if (w && n) pair = [w, n];
        }
        if (pair) {
          s.tapCell(pair[0].c, pair[0].r);
          s.tapCell(pair[1].c, pair[1].r);
        } else {
          s.draw();
        }
      }
      return { status: s.status, produced: s.board.producedCount, merges: s.board.totalMerges, deck: s.deck.length };
    });
    await page.waitForTimeout(700);
    await page.screenshot({ path: `${OUT}/06_end.png` });
    console.log('AUTO:', JSON.stringify(result));
  }
}

async function shotParking() {
  const info = await page.evaluate(() => {
    const app = globalThis.__carlong.app;
    const s = app.activeParking;
    if (!s) return null;
    const target = s.targetVehicle;
    // 目标车可能一开局被堵死（高难关常态）——那就挑一辆能动车的演示交互，
    // 否则截图工具在深层关卡上什么都点不动。
    const mover = s.vehicles.find((v) => {
      const r = s.reachOf(v.index);
      return r.left >= 0 || r.right >= 0 || r.up >= 0 || r.down >= 0;
    });
    const pick = target && (() => {
      const r = s.reachOf(target.index);
      return r.left >= 0 || r.right >= 0 || r.up >= 0 || r.down >= 0;
    })()
      ? target
      : (mover ?? target);
    const reach = pick ? s.reachOf(pick.index) : null;
    return {
      pick: pick?.index ?? -1,
      pickTier: pick?.tier ?? -1,
      id: s.level.id,
      name: s.level.name,
      grid: s.level.grid,
      target: target?.index ?? -1,
      targetTier: s.level.target,
      minMoves: s.level.minMoves,
      movesLimit: s.level.moves,
      reach,
    };
  });
  if (!info) throw new Error('拿不到停车会话');
  console.log('PARKING:', JSON.stringify(info));

  if (info.pick < 0) return;

  // 点一辆能动的车 → 选中（应出现虚线环 + 可达箭头）
  const car = await page.evaluate(
    (vi) => globalThis.__carlong.app.activeParkingScene.carRectForDebug(vi),
    info.pick,
  );
  await page.mouse.click(car.x + car.w / 2, car.y + car.h / 2);
  await page.waitForTimeout(260);
  await page.screenshot({ path: `${OUT}/03_selected.png` });

  // 点最远可达格 → 车滑过去
  const reach = info.reach;
  let dest = null;
  if (reach) {
    if (reach.down >= 0) dest = { r: reach.down, c: 0 };
    else if (reach.right >= 0) dest = { r: 0, c: reach.right };
    else if (reach.up >= 0) dest = { r: reach.up, c: 0 };
    else if (reach.left >= 0) dest = { r: 0, c: reach.left };
  }
  if (dest) {
    const center = await page.evaluate(
      ([r, c, vi]) => {
        const app = globalThis.__carlong.app;
        const s = app.activeParking;
        const v = s.vehicles[vi];
        // 目标格要落在该车能滑的轴上：横车看列，纵车看行
        const row = v.horiz ? v.row : r;
        const col = v.horiz ? c : v.col;
        return app.activeParkingScene.cellCenterForDebug(row, col);
      },
      [dest.r, dest.c, info.pick],
    );
    await page.mouse.click(center.x, center.y);
    await page.waitForTimeout(420);
    await page.screenshot({ path: `${OUT}/04_moved.png` });
  }

  if (AUTO) {
    const result = await page.evaluate(() => {
      const app = globalThis.__carlong.app;
      const s = app.activeParking;
      const path = globalThis.__carlong.solveParking(s.level);
      if (!path) return { status: s.status, error: '无解' };
      for (const mv of path) {
        if (!s.moveVehicle(mv.vi, mv.toR, mv.toC)) break;
      }
      return { status: s.status, moves: s.moves, best: s.level.minMoves };
    });
    await page.waitForTimeout(700);
    await page.screenshot({ path: `${OUT}/06_end.png` });
    console.log('AUTO:', JSON.stringify(result));
  }
}

// 返回选关页
const state = await page.evaluate(() => {
  const app = globalThis.__carlong?.app;
  const p = app?.activeParking;
  const m = app?.activeSession;
  return p
    ? { mode: 'parking', id: p.level.id, status: p.status, moves: p.moves, best: p.level.minMoves }
    : m
      ? { mode: 'merge', id: m.level.id, status: m.status, merges: m.board.totalMerges }
      : null;
});
await page.evaluate(() => {
  const app = globalThis.__carlong.app;
  if (app.activeParking) app.activeParkingScene.onExit?.();
  else app.activeScene?.onExit?.();
});
await page.waitForTimeout(420);
await page.screenshot({ path: `${OUT}/05_select.png` });

console.log(JSON.stringify({ state, logs }, null, 2));
await browser.close();
