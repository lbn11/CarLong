import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 难度心跳：合成与停车两个模式共用的**同一套节奏语言**，但周期不同。
///
/// 心流的本质不是「越来越难」，而是**张弛交替**：连续爬坡会疲劳，
/// 一直平又会无聊。固定周期让玩家可以**预知**「再过两关就该发力了」，
/// 这种可预期的张弛本身就是心流的一部分。
///
/// # 两个模式的周期故意错开（产品硬性要求）
///
/// 局部难度曲线的关卡数**不能相同**，否则两个模式会「同时进入硬仗」，
/// 交替游玩时紧张点叠加、松弛点也叠加，节奏感互相抵消。
///
/// - 合成：**5 关一轮**（单波峰：谷-升-峰-降-尖峰）
/// - 停车：**6 关一轮**（双波峰：谷-升-峰-降-高峰-尖峰）
///
/// 相位计算各自独立：
/// - 合成 [LevelDataGenerator.rhythmPhase]：章大小 45 能被 5 整除，
///   章内偏移与全局偏移一致，章边界不打断心跳。
/// - 停车 [ParkingLevelGenerator.rhythmPhase]：按**章内偏移**取模，
///   保证每章第 1 关恒为相位 0（新车型在轻松关登场）。
enum RhythmMode {
  /// 合成模式（5 关一轮）。
  merge,

  /// 停车模式（6 关一轮）。
  parking,
}

class LevelRhythm {
  LevelRhythm._();

  // ─────────────────────────────────────────────────────────────
  //  两条轨道
  // ─────────────────────────────────────────────────────────────

  /// 合成：5 关一轮。
  static const int mergePeriod = 5;

  /// 停车：6 关一轮。
  static const int parkingPeriod = 6;

  static const List<String> _mergeNames = ['轻松', '顺手', '动脑', '顺手', '硬仗'];

  static const List<String> _parkingNames = [
    '轻松', // 0 新车型登场，点两下就过
    '顺手', // 1 轻度加压
    '动脑', // 2 第一波峰：要想一下
    '缓冲', // 3 波谷：喘口气
    '硬仗', // 4 第二波峰：更拥挤 + 更多能力车
    '尖峰', // 5 全压力：最挤 + 限时
  ];

  /// 相位色：从冷到暖递进，玩家扫一眼选关页就能看出这一轮的起伏。
  static const List<Color> _mergeColors = [
    AppColors.forest, // 轻松：绿
    AppColors.lemon, // 顺手：黄
    AppColors.melon, // 动脑：橙
    AppColors.lemon, // 顺手：黄
    AppColors.coralDeep, // 硬仗：珊瑚红
  ];

  static const List<Color> _parkingColors = [
    AppColors.forest, // 轻松：绿
    AppColors.lemon, // 顺手：黄
    AppColors.melon, // 动脑：橙
    AppColors.aqua, // 缓冲：青（唯一的冷色波谷）
    AppColors.coralDeep, // 硬仗：珊瑚红
    AppColors.taro, // 尖峰：紫罗兰（终极档）
  ];

  /// 相位图标（供 HUD chip 使用）。
  static const List<IconData> _mergeIcons = [
    Icons.sentiment_satisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.local_fire_department_rounded,
  ];

  static const List<IconData> _parkingIcons = [
    Icons.sentiment_satisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.spa_rounded, // 缓冲：深呼吸
    Icons.local_fire_department_rounded, // 硬仗
    Icons.whatshot_rounded, // 尖峰
  ];

  // ─────────────────────────────────────────────────────────────
  //  查询
  // ─────────────────────────────────────────────────────────────

  static int periodOf(RhythmMode mode) =>
      mode == RhythmMode.merge ? mergePeriod : parkingPeriod;

  static List<String> namesOf(RhythmMode mode) =>
      mode == RhythmMode.merge ? _mergeNames : _parkingNames;

  static String nameOf(RhythmMode mode, int phase) =>
      namesOf(mode)[phase % periodOf(mode)];

  static Color colorOf(RhythmMode mode, int phase) =>
      (mode == RhythmMode.merge ? _mergeColors : _parkingColors)[
          phase % periodOf(mode)];

  static IconData iconOf(RhythmMode mode, int phase) =>
      (mode == RhythmMode.merge ? _mergeIcons : _parkingIcons)[
          phase % periodOf(mode)];
}
