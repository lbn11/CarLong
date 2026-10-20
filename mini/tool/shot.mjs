// 无头截图：用本机 Chrome 打开预览页，按脚本点几下再截图。
//
// 用途是「改完能自己看见效果」，不是自动化测试——所以它只做三件事：
// 打开、模拟触摸、落图。断言留给 test/。
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

// LEVEL=N 时把存档进度推到第 N 关，冷启动会直接进这一关（验收高难度关/障碍关用）
const LEVEL = Number(process.env.LEVEL ?? 0);
if (LEVEL > 0) {
  await page.evaluate((lv) => {
    localStorage.setItem('carlong.progress.v1', JSON.stringify({ unlocked: lv }));
  }, LEVEL);
  await page.reload({ waitUntil: 'networkidle' });
}
await page.waitForTimeout(600);

// 冷启动直接进当前关，先落一张初始图
await page.screenshot({ path: `${OUT}/01_start.png` });

// 点牌堆出牌：坐标直接读场景布局，不在工具侧复算公式
// （复算副本一旦和真实布局漂移，表现就是「点了没反应」）。
const deckPos = await page.evaluate(() => {
  const scene = globalThis.__carlong?.app?.activeScene;
  const l = scene?.layoutForDebug?.();
  if (!l) return null;
  return l.deckSlots.map((s) => ({ x: s.x + s.w / 2, y: s.y + s.h / 2 }));
});
if (!deckPos) throw new Error('拿不到布局：场景未就绪');
const deck = deckPos[0];
for (let i = 0; i < 6; i++) {
  await page.mouse.click(deck.x, deck.y);
  await page.waitForTimeout(160);
}
await page.screenshot({ path: `${OUT}/02_dealt.png` });

// 点棋盘上的同档卡尝试合并：布局坐标从场景读，车的位置从 session 读
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
        count: st.count,
        x: l.boardX + c * (l.cell + l.gap) + l.cell / 2,
        y: l.boardY + r * (l.cell + l.gap) + l.cell / 2,
      });
    }
  }
  return { cells };
});

if (cellPos) {
  // 找一对同档，点它们合成
  const byTier = new Map();
  for (const c of cellPos.cells) {
    if (!byTier.has(c.tier)) byTier.set(c.tier, []);
    byTier.get(c.tier).push(c);
  }
  const pair = [...byTier.values()].find((arr) => arr.length >= 2);
  if (pair) {
    await page.mouse.click(pair[0].x, pair[0].y);
    await page.waitForTimeout(120);
    await page.screenshot({ path: `${OUT}/03_selected.png` });
    await page.mouse.click(pair[1].x, pair[1].y);
    await page.waitForTimeout(400);
    await page.screenshot({ path: `${OUT}/04_merged.png` });
  } else {
    await page.screenshot({ path: `${OUT}/04_merged.png` });
  }
}

// AUTO=1：在页内把这一关打完（自动出牌 + 自动合并），用于验证结算面板。
if (process.env.AUTO === '1') {
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
      // 优先：炸弹对炸弹；否则任意同档一对
      let pair = null;
      for (const a of cells) {
        if (a.bomb) {
          const b = cells.find((x) => x.bomb && (x.c !== a.c || x.r !== a.r));
          if (b) { pair = [a, b]; break; }
        }
      }
      if (!pair) {
        outer: for (let i = 0; i < cells.length; i++) {
          for (let j = i + 1; j < cells.length; j++) {
            if (!cells[i].bomb && !cells[i].wild && !cells[j].bomb && !cells[j].wild && cells[i].tier === cells[j].tier) {
              pair = [cells[i], cells[j]];
              break outer;
            }
          }
        }
      }
      // 万能卡也拿来找普通卡合
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
    return { status: s.status, produced: s.board.producedCount, merges: s.board.totalMerges, maxCombo: s.maxCombo, deck: s.deck.length };
  });
  await page.waitForTimeout(700);
  await page.screenshot({ path: `${OUT}/06_end.png` });
  console.log('AUTO:', JSON.stringify(result));
}

// 状态快照
const state = await page.evaluate(() => {
  const s = globalThis.__carlong?.app?.activeSession;
  if (!s) return null;
  return {
    id: s.level.id,
    name: s.level.name,
    deck: s.deck.length,
    produced: s.board.producedCount,
    merges: s.board.totalMerges,
    combo: s.maxCombo,
    status: s.status,
    tiles: s.board.tileCount,
  };
});

// 再截一张关卡选择页（点返回）
const back = { x: 30, y: 8 + 6 + 17 };
await page.mouse.click(back.x, back.y);
await page.waitForTimeout(400);
await page.screenshot({ path: `${OUT}/05_select.png` });

console.log(JSON.stringify({ state, logs }, null, 2));
await browser.close();
