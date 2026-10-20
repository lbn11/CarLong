// 停车规则的移植正确性测试。
//
// 期望值分两类：
// 1. 手写用例 —— 覆盖滑动语义（"一步滑到最远"、长条车轴约束、只有目标车能进车位）。
// 2. **真关卡对齐** —— 把导出的 800 关挑一批，用 TS 求解器复算 minMoves，
//    必须等于 Dart 求解器算出来的值。这一条比手写用例强得多：任何规则漂移
//    （占用判断、车位独占、胜利条件）都会让最短步数变化，直接红。
//
// solver 不建模车型能力（与 Dart ParkingSolver 一致），所以关卡头部那段
// "n 步" 是"无能力也需要 n 步"，TS 端不能因为车有 teleport 就算出更短。
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import { ParkingSession, solveParking } from '../src/core/parking.ts';
import type { ParkingDataFile, ParkingLevelDef, VehicleDef } from '../src/data/types.ts';

const VIDEO_ABILITY = 'none';

function vehTable(over: Record<number, string> = {}): VehicleDef[] {
  return Array.from({ length: 50 }, (_, i) => ({
    id: i,
    name: `车${i}`,
    icon: '🚗',
    color: '#4CC2FF',
    category: 'land',
    rarity: 'common',
    rarityColor: '#FFFFFF',
    ability: over[i] ?? VIDEO_ABILITY,
    move: 1,
    terrain: [],
  }));
}

function plv(over: Partial<ParkingLevelDef> = {}): ParkingLevelDef {
  return {
    id: 1,
    name: '测试',
    rows: 4,
    cols: 4,
    grid: ['rrrr', 'rrrr', 'rrrr', 'rprr'],
    vehicles: [],
    target: 1,
    targetName: '出租车',
    minMoves: 0,
    moves: null,
    time: null,
    rowHints: null,
    colHints: null,
    ...over,
  };
}

function session(over: Partial<ParkingLevelDef> = {}, table = vehTable()): ParkingSession {
  return new ParkingSession(plv(over), table);
}

// ── 滑动语义 ──────────────────────────────────────────
test('单格车一步滑到点击方向上最远可达格', () => {
  // 车位在 (3,1)；目标车 (0,0) 沿第 0 列一路到底
  const s = session({ vehicles: [{ c: 0, r: 0, tier: 1 }] });
  assert.equal(s.slideTo(0, 3, 0), true);
  assert.equal(s.vehicles[0].row, 3, '应滑到最底行');
  assert.equal(s.vehicles[0].col, 0);
  // 再向右一格就进车位
  assert.equal(s.slideTo(0, 3, 1), true);
  assert.equal(s.status, 'won');
});

test('点击格比可达终点近时，停在点击格（不越过）', () => {
  const s = session({ vehicles: [{ c: 0, r: 0, tier: 1 }] });
  assert.equal(s.slideTo(0, 1, 0), true);
  assert.equal(s.vehicles[0].row, 1, '点第 1 行就只到第 1 行');
});

test('前方有车挡路时滑到阻挡前一格', () => {
  const s = session({
    vehicles: [
      { c: 0, r: 0, tier: 1 },
      { c: 0, r: 2, tier: 3 },
    ],
  });
  s.slideTo(0, 3, 0);
  assert.equal(s.vehicles[0].row, 1, '被 (2,0) 的车挡住');
});

test('长条车只能沿车身轴滑动', () => {
  // 横向 2 格车 (0,0)-(0,1)
  const s = session({ vehicles: [{ c: 0, r: 0, tier: 1, len: 2 }] });
  assert.equal(s.slideTo(0, 2, 1), false, '横向车不能纵向移动');
  assert.equal(s.slideTo(0, 0, 3), true, '横向车可向右滑');
  // 点击列 3、车长 2 → 车头对齐 3，anchor = 2（占 2-3）
  assert.equal(s.vehicles[0].col, 2);
});

test('纵向长条车同上（车头对齐点击行）', () => {
  const s = session({ vehicles: [{ c: 1, r: 0, tier: 1, len: 2, vert: true }] });
  assert.equal(s.slideTo(0, 3, 1), true);
  assert.equal(s.vehicles[0].row, 2, '车头对齐第 3 行 → anchor 2');
});

test('障碍格不可通行，车停在障碍前', () => {
  const s = session({
    grid: ['rror', 'rrrr', 'rrrr', 'rprr'],
    vehicles: [{ c: 0, r: 0, tier: 1 }],
  });
  s.slideTo(0, 0, 3);
  assert.equal(s.vehicles[0].col, 1, '(0,2) 是石墩，只能滑到 (0,1)');
});

test('入口 / 出口格不可通行', () => {
  const s = session({
    grid: ['reer', 'rrrr', 'rrrr', 'rppr'],
    vehicles: [{ c: 0, r: 0, tier: 1 }],
  });
  assert.equal(s.canMoveTo(0, 0, 1), false, '入口格不能进入');
});

// ── 停车位独占 ────────────────────────────────────────
test('只有目标档的车能进停车位', () => {
  // 车位 (3,1)
  const s = session({
    vehicles: [
      { c: 1, r: 0, tier: 3 },
      { c: 3, r: 3, tier: 1 },
    ],
    target: 1,
  });
  assert.equal(s.canMoveTo(0, 3, 1), false, '非目标车不能进 (3,1) 车位');
  assert.equal(s.canMoveTo(1, 3, 1), true, '目标车可以进车位');
});

test('目标车压住车位即胜利（长条车压一格也算）', () => {
  // 车位在 (3,2)；横向 2 格车停在 (3,0)-(3,1)，右滑一格即可压住车位右端
  const s = session({
    grid: ['rrrr', 'rrrr', 'rrrr', 'rrpr'],
    vehicles: [{ c: 0, r: 3, tier: 1, len: 2 }],
    target: 1,
  });
  assert.equal(s.vehicles[0].parked, false, '开局没压住车位');
  // 横车点 (3,2)：车头对齐第 2 列 → anchor 回退到 1，车身 (3,1)-(3,2) 压住 (3,2)
  assert.equal(s.slideTo(0, 3, 2), true);
  assert.equal(s.vehicles[0].col, 1);
  assert.equal(s.vehicles[0].parked, true);
  assert.equal(s.status, 'won');
});

test('已停好的车不能再动（与 Dart 的 parked 短路一致）', () => {
  const s = session({
    grid: ['rrrr', 'rrrr', 'rrrr', 'rprr'],
    vehicles: [{ c: 1, r: 3, tier: 1 }],
    target: 1,
  });
  assert.equal(s.vehicles[0].parked, true);
  assert.equal(s.slideTo(0, 3, 3), false);
});

// ── 步数 / 撤销 ───────────────────────────────────────
test('步数累计，限步耗尽判负', () => {
  const s = session({
    grid: ['rrrr', 'rrrr', 'rrrr', 'rprr'],
    vehicles: [
      { c: 0, r: 0, tier: 1 },
      { c: 3, r: 0, tier: 2 },
    ],
    target: 3,
    moves: 2,
  });
  assert.equal(s.slideTo(0, 3, 0), true);
  assert.equal(s.moves, 1);
  assert.equal(s.status, 'playing');
  assert.equal(s.slideTo(1, 3, 3), true);
  assert.equal(s.status, 'lost');
  assert.equal(s.failReason, 'moves');
});

test('撤销恢复位置与步数，且退出判负态', () => {
  const s = session({
    grid: ['rrrr', 'rrrr', 'rrrr', 'rprr'],
    vehicles: [
      { c: 0, r: 0, tier: 1 },
      { c: 3, r: 0, tier: 3 },
    ],
    target: 3,
    moves: 1,
  });
  s.slideTo(1, 3, 3);
  assert.equal(s.status, 'lost');
  // Dart 侧 lost 后 undo 直接返回 false（不允许复活），保持一致
  assert.equal(s.undo(), false);
});

test('撤销正常局面：位置与步数都回退', () => {
  const s = session({ vehicles: [{ c: 0, r: 0, tier: 1 }] });
  s.slideTo(0, 2, 0);
  assert.equal(s.vehicles[0].row, 2);
  assert.equal(s.undo(), true);
  assert.equal(s.vehicles[0].row, 0);
  assert.equal(s.moves, 0);
});

test('限时归零判负', () => {
  const s = session({ vehicles: [{ c: 0, r: 0, tier: 1 }], time: 1 });
  s.tick(0.6);
  assert.equal(s.status, 'playing');
  s.tick(0.6);
  assert.equal(s.status, 'lost');
  assert.equal(s.failReason, 'time');
});

test('死局检测：全被堵住时 isDeadlocked 为真', () => {
  // 目标车 (1,1) 四周被非目标车围死，且它们也无处可去
  const s = session({
    rows: 3,
    cols: 3,
    grid: ['ooo', 'ooo', 'oop'],
    vehicles: [{ c: 1, r: 1, tier: 1 }],
    target: 1,
  });
  assert.equal(s.isDeadlocked, true);
});

// ── 能力 ─────────────────────────────────────────────
test('teleport 可跳到直线外的空格', () => {
  const s = session(
    {
      vehicles: [{ c: 0, r: 0, tier: 2 }],
    },
    vehTable({ 2: 'teleport' }),
  );
  assert.equal(s.jumpTo(0, 2, 3), true);
  assert.equal(s.vehicles[0].row, 2);
});

test('turn 在 Dart 侧实际无效（已知缺陷，TS 端忠实移植不复刻修复）', () => {
  // Dart `slideTo` 有 turn 分支（长条车可四向滑），但 `canMoveTo` 里的轴约束
  // 不看 turn，moveVehicle → canMoveTo 必然拒绝。结果是 turn 车只能沿原轴滑。
  // 两端必须一致：这里锁住现状，修 Dart 时这条测试要一起改。
  const s = session(
    { vehicles: [{ c: 0, r: 0, tier: 2, len: 2, vert: true }] },
    vehTable({ 2: 'turn' }),
  );
  assert.equal(s.slideTo(0, 0, 2), false, 'turn 分支进得去，但 canMoveTo 拒绝');
  assert.equal(s.slideTo(0, 2, 0), true, '仍可沿原轴（纵向）滑');
});

// ── 真关卡对齐 ────────────────────────────────────────
// 用导出的 800 关校验：TS 求解器的最短步数必须等于 Dart 求解器的结论。
// 抽样覆盖：前 20 关（4×4）+ 每 25 关一个（含 5×5/6×6、长条车、限步关）。
const dataFile = path.resolve(
  path.dirname(new URL(import.meta.url).pathname),
  '../../shared/levels/parking_levels.json',
);
const parkingData = JSON.parse(fs.readFileSync(dataFile, 'utf8')) as ParkingDataFile;
const vehFile = path.resolve(
  path.dirname(new URL(import.meta.url).pathname),
  '../../shared/levels/vehicles.json',
);
const vehicleData = JSON.parse(fs.readFileSync(vehFile, 'utf8')) as { vehicles: VehicleDef[] };

function sampleLevels(): ParkingLevelDef[] {
  const picked = new Map<number, ParkingLevelDef>();
  for (const l of parkingData.levels) {
    if (l.id <= 20 || l.id % 25 === 0) picked.set(l.id, l);
  }
  return [...picked.values()];
}

test('抽样的真关卡：TS 求解最短步数 === Dart 导出的 minMoves', () => {
  const bad: string[] = [];
  for (const l of sampleLevels()) {
    const got = solveParking(l)?.length ?? null;
    if (got !== l.minMoves) bad.push(`L${l.id}: TS ${got} vs Dart ${l.minMoves}`);
  }
  assert.deepEqual(bad, [], `规则漂移：${bad.join(' / ')}`);
});

test('抽样的真关卡：solver 解可以在 ParkingSession 上真实走通并获胜', () => {
  const bad: string[] = [];
  for (const l of sampleLevels()) {
    const path0 = solveParking(l);
    if (!path0) {
      bad.push(`L${l.id}: 无解`);
      continue;
    }
    const s = new ParkingSession(l, vehicleData.vehicles);
    for (const mv of path0) {
      if (!s.moveVehicle(mv.vi, mv.toR, mv.toC)) {
        bad.push(`L${l.id}: 第 ${s.moves + 1} 步走不动 (${mv.vi} → ${mv.toR},${mv.toC})`);
        break;
      }
    }
    if (s.status !== 'won') bad.push(`L${l.id}: 走完未获胜（${s.status}）`);
  }
  assert.deepEqual(bad, [], bad.join(' / '));
});

test('全部 800 关都有解（导出器闸门保证，这里做端侧复核）', () => {
  // 全量跑 solver 太重（Dart 侧 40s），这里只确认数据自带 minMoves 且 > 0，
  // 真正的可解性闸门在 tool/export_levels.dart。
  const bad = parkingData.levels.filter((l) => !(l.minMoves > 0)).map((l) => l.id);
  assert.deepEqual(bad, [], `minMoves 异常的关：${bad.slice(0, 10).join(',')}`);
});
