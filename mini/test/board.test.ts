// 棋盘规则的移植正确性测试。
//
// 这些用例的期望值全部来自 Flutter 侧 `board_logic.dart` 的实际行为
// （3 张升级 / 冰层按邻格合并递减 / 传送门成对改道 / 炸弹只在两炸相合
// 且累计 ≥3 时引爆）。改规则必须两边同时改，这里红了就是两端漂移。
import assert from 'node:assert/strict';
import test from 'node:test';

import { Board } from '../src/core/board.ts';
import { Rng } from '../src/core/rng.ts';
import { MergeSession } from '../src/core/session.ts';
import { makeStack } from '../src/core/stack.ts';
import type { MergeLevelDef, VehicleDef } from '../src/data/types.ts';

const NONE_ABILITIES = new Array(50).fill('none');

function lv(over: Partial<MergeLevelDef> = {}): MergeLevelDef {
  return {
    id: 1,
    name: '测试关',
    cols: 4,
    rows: 4,
    stock: 10,
    goal: 'produce',
    target: 3,
    targetName: '出租车',
    count: 1,
    bias: 0,
    spawn: [5, 8, 12],
    par: null,
    phase: 0,
    ch: 0,
    ...over,
  };
}

function board(over: Partial<MergeLevelDef> = {}, abilities: string[] = NONE_ABILITIES): Board {
  return new Board(lv(over), new Rng(12345), abilities);
}

// ── 合并与升级 ────────────────────────────────────────
test('三张同档合并升一档，升级后 count 归 1', () => {
  const b = board();
  b.placeAt(0, 0, makeStack(2, { count: 2 }));
  b.placeAt(1, 0, makeStack(2, { count: 1 }));
  const r = b.move(1, 0, 0, 0);
  assert.equal(r.valid, true);
  assert.equal(r.upgraded, true);
  const s = b.at(0, 0)!;
  assert.equal(s.tier, 3);
  assert.equal(s.count, 1);
  assert.equal(b.at(1, 0), null);
});

test('两张同档合并不升级（count=2）', () => {
  const b = board();
  b.placeAt(0, 0, makeStack(2));
  b.placeAt(1, 0, makeStack(2));
  const r = b.move(1, 0, 0, 0);
  assert.equal(r.upgraded, false);
  assert.equal(b.at(0, 0)!.count, 2);
});

test('合成到目标档计入 producedCount', () => {
  const b = board({ target: 3, count: 2 });
  b.placeAt(0, 0, makeStack(2, { count: 2 }));
  b.placeAt(1, 0, makeStack(2));
  const r = b.move(1, 0, 0, 0);
  assert.equal(r.producedTarget, true);
  assert.equal(b.producedCount, 1);
});

test('不同档位是交换不是合并', () => {
  const b = board();
  b.placeAt(0, 0, makeStack(2));
  b.placeAt(1, 0, makeStack(5));
  const r = b.move(0, 0, 1, 0);
  assert.equal(r.valid, true);
  assert.equal(r.upgraded, false);
  assert.equal(b.at(1, 0)!.tier, 2);
  assert.equal(b.at(0, 0)!.tier, 5);
});

test('最高档合并后清空该格（clearBoard 可通关的前提）', () => {
  const b = board({ goal: 'clearBoard', target: 49, count: 0, clearLimit: 0 });
  b.placeAt(0, 0, makeStack(49, { count: 2 }));
  b.placeAt(1, 0, makeStack(49));
  b.move(1, 0, 0, 0);
  assert.equal(b.at(0, 0)!.count, 0);
  assert.equal(b.tileCount, 0);
});

// ── 障碍 ──────────────────────────────────────────────
test('冰块格不可进入', () => {
  const b = board({ obs: [{ type: 'ice', c: 1, r: 0, l: 2 }] });
  b.placeAt(0, 0, makeStack(2));
  const r = b.move(0, 0, 1, 0);
  assert.equal(r.valid, false);
});

test('在冰块邻格合并，冰层 -1；融完变为可用空格', () => {
  const b = board({ obs: [{ type: 'ice', c: 1, r: 0, l: 2 }] });
  // 在 (0,1) 完成一次合并，四邻含 (1,1)? 不——要让 (0,0) 的合并邻到 (1,0)
  b.placeAt(0, 0, makeStack(2, { count: 2 }));
  b.placeAt(0, 1, makeStack(2));
  b.move(0, 1, 0, 1); // 无效操作，占位
  // 直接把 (2,0) 的卡移到 (0,0) 触发合并，四邻是 (1,0)/(1,1)... 用 (0,0) 与 (2,0) —— 格对格
  b.placeAt(2, 0, makeStack(2));
  b.move(2, 0, 0, 0);
  // (0,0) 的四邻包含 (1,0)：冰层 2 → 1
  assert.equal(b.obstacleAt(1, 0)!.layers, 1);
  assert.equal(b.obstacleAt(1, 0)!.removed, false);
});

test('石块永久占格，不进入', () => {
  const b = board({ obs: [{ type: 'block', c: 1, r: 1 }] });
  b.placeAt(0, 1, makeStack(2));
  assert.equal(b.move(0, 1, 1, 1).valid, false);
});

test('传送门成对改道：移入入口，卡出现在出口', () => {
  const b = board({
    obs: [
      { type: 'teleport', c: 0, r: 0 },
      { type: 'teleport', c: 3, r: 3 },
    ],
  });
  b.placeAt(1, 0, makeStack(4));
  const r = b.move(1, 0, 0, 0);
  assert.equal(r.valid, true);
  assert.equal(r.teleported, true);
  assert.equal(b.at(3, 3)!.tier, 4);
  assert.equal(b.at(1, 0), null);
});

test('锁链只能用锤子清，不能被合成消融', () => {
  const b = board({ obs: [{ type: 'lock', c: 1, r: 0 }] });
  b.placeAt(0, 0, makeStack(2, { count: 2 }));
  b.placeAt(1, 1, makeStack(2));
  assert.equal(b.move(1, 1, 1, 1).valid, false);
  b.placeAt(2, 0, makeStack(2));
  b.move(2, 0, 0, 0);
  assert.equal(b.obstacleAt(1, 0)?.removed ?? false, false);
  assert.ok(b.removeLockAt(1, 0));
  assert.equal(b.obstacleAt(1, 0), null);
});

// ── 特殊卡 ────────────────────────────────────────────
test('万能卡与任意档合并，按被合方档位计', () => {
  const b = board();
  b.placeAt(0, 0, makeStack(0, { isWildcard: true }));
  b.placeAt(1, 0, makeStack(7));
  b.move(0, 0, 1, 0);
  assert.equal(b.at(1, 0)!.tier, 7);
  assert.equal(b.at(1, 0)!.isWildcard, false);
  assert.equal(b.at(1, 0)!.count, 2);
});

test('两张万能卡相加后仍为万能卡', () => {
  const b = board();
  b.placeAt(0, 0, makeStack(0, { isWildcard: true }));
  b.placeAt(1, 0, makeStack(0, { isWildcard: true }));
  b.move(0, 0, 1, 0);
  assert.equal(b.at(1, 0)!.isWildcard, true);
  assert.equal(b.at(1, 0)!.count, 2);
});

test('炸弹只与炸弹合并，满 3 引爆清 3×3', () => {
  const b = board({ cols: 5, rows: 5 });
  b.placeAt(2, 2, makeStack(0, { isBomb: true, count: 2 }));
  b.placeAt(1, 2, makeStack(1)); // 3×3 内
  b.placeAt(3, 3, makeStack(2)); // 3×3 内
  b.placeAt(0, 0, makeStack(7)); // 3×3 外，应保留
  b.placeAt(1, 1, makeStack(0, { isBomb: true }));
  const r = b.move(1, 1, 2, 2);
  assert.equal(r.detonated, true);
  assert.equal(b.tileCount, 1, '只有 3×3 外的卡应留下');
  assert.equal(b.at(0, 0)!.tier, 7);
});

test('炸弹与普通卡是交换', () => {
  const b = board();
  b.placeAt(0, 0, makeStack(0, { isBomb: true }));
  b.placeAt(1, 0, makeStack(6));
  b.move(0, 0, 1, 0);
  assert.equal(b.at(1, 0)!.isBomb, true);
  assert.equal(b.at(0, 0)!.tier, 6);
});

// ── 落点与死局 ────────────────────────────────────────
test('智能落点优先放在同档卡的四邻', () => {
  const b = board();
  b.placeAt(1, 1, makeStack(5));
  const cell = b.placeTierSmart(5)!;
  const adjacent =
    (Math.abs(cell.col - 1) === 1 && cell.row === 1) || (Math.abs(cell.row - 1) === 1 && cell.col === 1);
  assert.ok(adjacent, `应落在 (1,1) 四邻，实际 ${cell.col},${cell.row}`);
});

test('hasPossibleMove：两堆同档即可合（不看通路）', () => {
  const b = board();
  // 对角摆放，中间隔着别的车——旧实现会误判无路可走
  b.placeAt(0, 0, makeStack(3));
  b.placeAt(3, 3, makeStack(3));
  b.placeAt(1, 1, makeStack(9));
  assert.equal(b.hasPossibleMove, true);
});

test('hasPossibleMove：单堆 count=2 不能自己合自己', () => {
  const b = board();
  b.placeAt(0, 0, makeStack(3, { count: 2 }));
  assert.equal(b.hasPossibleMove, false);
});

test('冰封的车不参与可步判定', () => {
  const b = board();
  b.placeAt(0, 0, makeStack(3, { frozen: 1 }));
  b.placeAt(1, 1, makeStack(3));
  assert.equal(b.hasPossibleMove, false);
});

// ── 随机与确定性 ──────────────────────────────────────
test('同一 seed 的出牌序列完全一致（跨端可复现）', () => {
  const a = new Rng(987654);
  const c = new Rng(987654);
  const xs = Array.from({ length: 20 }, () => a.weighted([5, 8, 12]));
  const ys = Array.from({ length: 20 }, () => c.weighted([5, 8, 12]));
  assert.deepEqual(xs, ys);
});

test('weighted 只产出有效下标，且高档权重更大时占比更高', () => {
  const r = new Rng(42);
  const counts = [0, 0, 0];
  for (let i = 0; i < 3000; i++) counts[r.weighted([1, 3, 12])]++;
  assert.ok(counts[2] > counts[1] && counts[1] > counts[0], `分布异常 ${counts}`);
});

// ── 会话 ──────────────────────────────────────────────
function fakeVehicles(): VehicleDef[] {
  return Array.from({ length: 50 }, (_, i) => ({
    id: i,
    name: `车${i}`,
    icon: '🚗',
    color: '#4CAF50',
    category: 'land',
    rarity: 'common',
    rarityColor: '#9E9E9E',
    ability: 'none',
    move: 1,
    terrain: ['land'],
  }));
}

test('出牌消耗牌堆与步数', () => {
  const s = new MergeSession(lv({ stock: 5, moves: 3 }), fakeVehicles());
  assert.equal(s.deck.length, 5);
  assert.equal(s.movesLeft, 3);
  s.draw();
  assert.equal(s.deck.length, 4);
  assert.equal(s.movesLeft, 2);
});

test('达成目标立即判胜（不依赖下一帧）', () => {
  const s = new MergeSession(lv({ target: 3, count: 1, stock: 4 }), fakeVehicles());
  s.board.placeAt(0, 0, makeStack(2, { count: 2 }));
  s.board.placeAt(1, 0, makeStack(2));
  s.tapCell(1, 0);
  s.tapCell(0, 0);
  assert.equal(s.status, 'won');
});

test('步数用完且未达成判负', () => {
  const s = new MergeSession(lv({ stock: 5, moves: 1, target: 20, count: 5 }), fakeVehicles());
  s.draw();
  assert.equal(s.status, 'lost');
  assert.equal(s.failReason, 'moves');
});

test('牌堆空且无步可走判死局', () => {
  const s = new MergeSession(lv({ stock: 0, target: 20, count: 5 }), fakeVehicles());
  assert.equal(s.status, 'lost');
  assert.equal(s.failReason, 'deadEnd');
});

test('撤销恢复棋盘与牌堆', () => {
  const s = new MergeSession(lv({ stock: 3 }), fakeVehicles());
  const before = s.board.tileCount;
  s.draw();
  assert.equal(s.board.tileCount, before + 1);
  assert.equal(s.deck.length, 2);
  s.undo();
  assert.equal(s.board.tileCount, before);
  assert.equal(s.deck.length, 3);
});

test('连消：1.6s 窗口内连续合并累积', () => {
  // stock 必须 >0 建局（stock=0 会在构造时直接判死局），建完再清空牌堆
  const s = new MergeSession(lv({ stock: 2, target: 20, count: 99 }), fakeVehicles());
  s.deck.length = 0;
  s.board.placeAt(0, 0, makeStack(1, { count: 2 }));
  s.board.placeAt(1, 0, makeStack(1));
  s.board.placeAt(2, 1, makeStack(1, { count: 2 }));
  s.board.placeAt(3, 1, makeStack(1));
  s.tapCell(1, 0);
  s.tapCell(0, 0);
  assert.equal(s.combo, 1);
  s.tapCell(3, 1);
  s.tapCell(2, 1);
  assert.equal(s.combo, 2);
  // 超过窗口后归零
  s.tick(1.7);
  assert.equal(s.combo, 0);
  assert.equal(s.maxCombo, 2);
});
