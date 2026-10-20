// 平台探测。整个 TS 端只有这里和 platform/*.ts 允许碰宿主差异。

declare const wx: any;
declare const tt: any;

export type Host = 'web' | 'wechat' | 'douyin';

interface GlobalLike {
  wx?: any;
  tt?: any;
  document?: unknown;
}

const g = globalThis as unknown as GlobalLike;

export function detectHost(): Host {
  // 抖音（字节）的全局对象是 tt，且它会同时注入一个假 wx 做兼容层，
  // 所以必须先判 tt。
  if (typeof g.tt !== 'undefined') return 'douyin';
  if (typeof g.wx !== 'undefined') return 'wechat';
  return 'web';
}

export const host: Host = detectHost();

/** 当前是否小游戏运行时（无 DOM）。 */
export const isMiniGame = host !== 'web';
