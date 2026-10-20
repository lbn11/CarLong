// 可复现随机数。
//
// 为什么不用 Math.random：关卡数据是确定性的，如果出牌序列在不同设备上
// 不一致，服务端就无法校验，回放/复现 bug 也不可能。mulberry32 是 32 位
// 状态的最小实现，跨引擎（V8 / JavaScriptCore）结果完全一致。
export class Rng {
  private s: number;

  constructor(seed: number) {
    // 保证 32 位无符号，且不为 0（0 也能跑，只是分布起点不同）
    this.s = seed >>> 0;
  }

  /** [0, 1) */
  next(): number {
    this.s = (this.s + 0x6d2b79f5) >>> 0;
    let t = this.s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  /** [0, n) 的整数 */
  int(n: number): number {
    if (n <= 0) return 0;
    return Math.floor(this.next() * n);
  }

  /**
   * 按权重取下标。
   *
   * **必须与 Dart 侧 `_weightedTier` 逐步等价**：先取整数 roll ∈ [0,total)，
   * 再逐个减权重、首次变负即命中。用浮点累加虽然分布相同，但序列不同，
   * 会导致两端「同一关出牌顺序不一样」，服务端校验和回放都做不了。
   */
  weighted(weights: readonly number[]): number {
    let total = 0;
    for (const w of weights) total += w > 0 ? w : 0;
    if (total <= 0) return 0;
    let roll = this.int(total);
    for (let i = 0; i < weights.length; i++) {
      roll -= weights[i] > 0 ? weights[i] : 0;
      if (roll < 0) return i;
    }
    return 0;
  }

  shuffle<T>(arr: T[]): void {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = this.int(i + 1);
      const t = arr[i];
      arr[i] = arr[j];
      arr[j] = t;
    }
  }
}

/** 由关卡 id + 用途派生的稳定种子（同名不同用途互不干扰）。 */
export function seedOf(levelId: number, salt: number): number {
  let h = Math.imul(levelId ^ 0x9e3779b9, 0x85ebca6b) >>> 0;
  h = (h ^ Math.imul(salt + 1, 0xc2b2ae35)) >>> 0;
  return h || 1;
}
