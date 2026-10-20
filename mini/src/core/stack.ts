// 棋盘上的一堆卡。字段与 Dart `StackData` 一一对应（vehicle.dart）。
export interface Stack {
  /** 车型 id，等于 VehicleType.index */
  tier: number;
  /** 同格叠放数量：够 3 张升一档 */
  count: number;
  isWildcard: boolean;
  isBomb: boolean;
  /** Boss 冰封层数：>0 不能动、不能参与合成，邻格合并一次融 1 层 */
  frozen: number;
  /** Boss 胶水剩余秒数：>0 不能动，只随时间干掉 */
  glueT: number;
}

export function makeStack(
  tier: number,
  opts: Partial<Omit<Stack, 'tier'>> = {},
): Stack {
  return {
    tier,
    count: opts.count ?? 1,
    isWildcard: opts.isWildcard ?? false,
    isBomb: opts.isBomb ?? false,
    frozen: opts.frozen ?? 0,
    glueT: opts.glueT ?? 0,
  };
}

export function copyStack(s: Stack): Stack {
  return { ...s };
}

export const isEmptyStack = (s: Stack | null): boolean => s === null || s.count <= 0;

/** 任何「当前动不了」的状态。move / 可步判定 / hint 一律用这个。 */
export const isLocked = (s: Stack): boolean => s.frozen > 0 || s.glueT > 0;

export interface Cell {
  col: number;
  row: number;
}
