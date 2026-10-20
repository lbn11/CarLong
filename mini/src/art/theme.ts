// 色板 —— 抄自 Flutter 侧 `lib/theme/app_theme.dart`（Sunny Candy 浅色基调）。
// 规则：TS 端不允许在 widget 里散写裸色值，一律从这里取。
export const C = {
  // 背景三层渐变
  bg1: '#FCF3EA',
  bg2: '#FDE7F1',
  bg3: '#E7F1FF',

  surfaceLight: '#FFFFFF',
  surfaceSoft: '#FCF6F1',

  ink1: '#2B2440',
  ink2: '#6B6480',
  ink3: '#A39DB5',

  coral: '#FF7A5C',
  coralDeep: '#FF5E7A',
  sun: '#FFC24B',
  sky: '#4CC2FF',
  mint: '#3ED598',
  grape: '#A78BFA',
  lemon: '#FFD166',
  blossom: '#FF9EC4',
  taro: '#B79BFF',
  aqua: '#64D8E6',

  hairline: '#EDE6F2',
  shadow: '#32324E',

  coinGold1: '#FFD982',
  coinGold2: '#FFB23E',
  coinText: '#7A4A12',

  danger: '#E53935',
  success: '#66BB6A',
} as const;

export interface Rgba {
  r: number;
  g: number;
  b: number;
  a: number;
}

/** 解析 #RRGGBB 或 #AARRGGBB */
export function parseColor(hex: string): Rgba {
  let h = hex.trim();
  if (h.startsWith('#')) h = h.slice(1);
  if (h.length === 6) {
    return {
      r: parseInt(h.slice(0, 2), 16),
      g: parseInt(h.slice(2, 4), 16),
      b: parseInt(h.slice(4, 6), 16),
      a: 1,
    };
  }
  if (h.length === 8) {
    // Flutter 常量是 AARRGGBB
    const a = parseInt(h.slice(0, 2), 16) / 255;
    return {
      r: parseInt(h.slice(2, 4), 16),
      g: parseInt(h.slice(4, 6), 16),
      b: parseInt(h.slice(6, 8), 16),
      a,
    };
  }
  return { r: 0, g: 0, b: 0, a: 1 };
}

const clamp255 = (v: number): number => Math.max(0, Math.min(255, Math.round(v)));

export function rgba(c: Rgba, alpha?: number): string {
  const a = alpha === undefined ? c.a : alpha;
  return `rgba(${clamp255(c.r)},${clamp255(c.g)},${clamp255(c.b)},${Math.max(0, Math.min(1, a)).toFixed(3)})`;
}

export function css(hex: string, alpha?: number): string {
  return rgba(parseColor(hex), alpha);
}

/** 与 Dart `Color.lerp(a, b, t)` 同语义 */
export function lerpColor(a: string, b: string, t: number): Rgba {
  const ca = parseColor(a);
  const cb = parseColor(b);
  return {
    r: ca.r + (cb.r - ca.r) * t,
    g: ca.g + (cb.g - ca.g) * t,
    b: ca.b + (cb.b - ca.b) * t,
    a: ca.a + (cb.a - ca.a) * t,
  };
}

/** 压深（对应 AppTheme.deepen） */
export function deepen(c: Rgba, amount: number): Rgba {
  return {
    r: c.r * (1 - amount),
    g: c.g * (1 - amount),
    b: c.b * (1 - amount),
    a: c.a,
  };
}
