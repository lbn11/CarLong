import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// App 名。MaterialApp.title 与商店名都用它。
  ///
  /// In en, this message translates to:
  /// **'Merge Fleet'**
  String get appName;

  /// 通用确认按钮
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// 通用取消按钮
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// 通用关闭按钮
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// 返回
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// 下一步 / 下一关
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// 重玩本关
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// 开始
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// 暂停
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// 继续（从暂停恢复）
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// 继续。不用 continue——Dart 关键字，gen-l10n 会生成非法 getter。
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// 放弃本关
  ///
  /// In en, this message translates to:
  /// **'Give Up'**
  String get giveUp;

  /// 领取奖励
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// 看广告。
  ///
  /// In en, this message translates to:
  /// **'Watch Ad'**
  String get watchAd;

  /// 解锁
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// 未解锁状态
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// 设置
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// 免费
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// 合成（动词/名词）。全项目统一，不要写成 combine / fuse。
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// 关卡（单数）
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// 关卡（复数）
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get levels;

  /// 章节
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get chapter;

  /// 棋盘
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get board;

  /// 牌堆
  ///
  /// In en, this message translates to:
  /// **'Deck'**
  String get deck;

  /// 金币（单数）
  ///
  /// In en, this message translates to:
  /// **'Coin'**
  String get coin;

  /// 金币（复数）
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get coins;

  /// 撤销一步。广告位之一，与 AdPlacement.undo 同名。
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// 提示。广告位之一。
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hint;

  /// 步数（单数）
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// 步数（复数）
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get moves;

  /// 时间 / 限时
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// 目标（要合成出的车）
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// 分数
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// 历史最佳
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get best;

  /// 连击
  ///
  /// In en, this message translates to:
  /// **'Combo'**
  String get combo;

  /// 奖励
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get reward;

  /// 宝箱（商店里用金币抽）
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get chest;

  /// 道具。不要写成 item / prop。
  ///
  /// In en, this message translates to:
  /// **'Booster'**
  String get booster;

  /// 商店
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// 车辆图鉴
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// 成就
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// 停车模式
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get parking;

  /// 无尽模式
  ///
  /// In en, this message translates to:
  /// **'Endless'**
  String get endless;

  /// 每日挑战
  ///
  /// In en, this message translates to:
  /// **'Daily Challenge'**
  String get dailyChallenge;

  /// 每日签到奖励
  ///
  /// In en, this message translates to:
  /// **'Daily Bonus'**
  String get dailyBonus;

  /// Boss 关的首领。专有名词，不翻译。
  ///
  /// In en, this message translates to:
  /// **'Boss'**
  String get boss;

  /// 冰块障碍
  ///
  /// In en, this message translates to:
  /// **'Ice'**
  String get ice;

  /// 胶水障碍（冻住车不能动）
  ///
  /// In en, this message translates to:
  /// **'Glue'**
  String get glue;

  /// 黑洞障碍
  ///
  /// In en, this message translates to:
  /// **'Black Hole'**
  String get blackHole;

  /// Boss 护盾
  ///
  /// In en, this message translates to:
  /// **'Shield'**
  String get shield;

  /// Boss 狂怒状态
  ///
  /// In en, this message translates to:
  /// **'Enraged'**
  String get enraged;

  /// 稀有度：普通
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get rarityCommon;

  /// 稀有度：稀有
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get rarityRare;

  /// 稀有度：史诗
  ///
  /// In en, this message translates to:
  /// **'Epic'**
  String get rarityEpic;

  /// 稀有度：传说
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get rarityLegendary;

  /// 车型分类：陆地
  ///
  /// In en, this message translates to:
  /// **'Land'**
  String get catLand;

  /// 车型分类：重工
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get catHeavy;

  /// 车型分类：轨道
  ///
  /// In en, this message translates to:
  /// **'Rail'**
  String get catRail;

  /// 车型分类：船舶
  ///
  /// In en, this message translates to:
  /// **'Maritime'**
  String get catMaritime;

  /// 车型分类：航空
  ///
  /// In en, this message translates to:
  /// **'Air'**
  String get catAir;

  /// 车型分类：星际
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get catSpace;

  /// 车型名。图鉴/目标车/合成方块都显示它，要短且地道。
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get vehicleBicycle;

  /// No description provided for @vehicleScooter.
  ///
  /// In en, this message translates to:
  /// **'Scooter'**
  String get vehicleScooter;

  /// No description provided for @vehicleSedan.
  ///
  /// In en, this message translates to:
  /// **'Sedan'**
  String get vehicleSedan;

  /// No description provided for @vehicleTaxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get vehicleTaxi;

  /// No description provided for @vehicleBus.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get vehicleBus;

  /// No description provided for @vehicleMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get vehicleMotorcycle;

  /// No description provided for @vehicleSuv.
  ///
  /// In en, this message translates to:
  /// **'SUV'**
  String get vehicleSuv;

  /// No description provided for @vehicleVan.
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get vehicleVan;

  /// No description provided for @vehicleAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Ambulance'**
  String get vehicleAmbulance;

  /// No description provided for @vehiclePolice.
  ///
  /// In en, this message translates to:
  /// **'Police Car'**
  String get vehiclePolice;

  /// No description provided for @vehicleFiretruck.
  ///
  /// In en, this message translates to:
  /// **'Fire Truck'**
  String get vehicleFiretruck;

  /// No description provided for @vehicleLimousine.
  ///
  /// In en, this message translates to:
  /// **'Limousine'**
  String get vehicleLimousine;

  /// No description provided for @vehicleTruck.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get vehicleTruck;

  /// No description provided for @vehicleTanker.
  ///
  /// In en, this message translates to:
  /// **'Tanker'**
  String get vehicleTanker;

  /// No description provided for @vehicleBulldozer.
  ///
  /// In en, this message translates to:
  /// **'Bulldozer'**
  String get vehicleBulldozer;

  /// No description provided for @vehicleCrane.
  ///
  /// In en, this message translates to:
  /// **'Crane'**
  String get vehicleCrane;

  /// No description provided for @vehicleExcavator.
  ///
  /// In en, this message translates to:
  /// **'Excavator'**
  String get vehicleExcavator;

  /// No description provided for @vehicleDumptruck.
  ///
  /// In en, this message translates to:
  /// **'Dump Truck'**
  String get vehicleDumptruck;

  /// No description provided for @vehicleForklift.
  ///
  /// In en, this message translates to:
  /// **'Forklift'**
  String get vehicleForklift;

  /// No description provided for @vehicleCementmixer.
  ///
  /// In en, this message translates to:
  /// **'Cement Mixer'**
  String get vehicleCementmixer;

  /// No description provided for @vehicleTram.
  ///
  /// In en, this message translates to:
  /// **'Tram'**
  String get vehicleTram;

  /// No description provided for @vehicleLightrail.
  ///
  /// In en, this message translates to:
  /// **'Light Rail'**
  String get vehicleLightrail;

  /// No description provided for @vehicleSubway.
  ///
  /// In en, this message translates to:
  /// **'Subway'**
  String get vehicleSubway;

  /// No description provided for @vehicleHighspeed.
  ///
  /// In en, this message translates to:
  /// **'High-Speed Rail'**
  String get vehicleHighspeed;

  /// No description provided for @vehicleMaglev.
  ///
  /// In en, this message translates to:
  /// **'Maglev'**
  String get vehicleMaglev;

  /// No description provided for @vehicleMonorail.
  ///
  /// In en, this message translates to:
  /// **'Monorail'**
  String get vehicleMonorail;

  /// No description provided for @vehicleSteam.
  ///
  /// In en, this message translates to:
  /// **'Steam Train'**
  String get vehicleSteam;

  /// No description provided for @vehicleHyperloop.
  ///
  /// In en, this message translates to:
  /// **'Hyperloop'**
  String get vehicleHyperloop;

  /// No description provided for @vehicleDinghy.
  ///
  /// In en, this message translates to:
  /// **'Dinghy'**
  String get vehicleDinghy;

  /// No description provided for @vehicleFishing.
  ///
  /// In en, this message translates to:
  /// **'Fishing Boat'**
  String get vehicleFishing;

  /// No description provided for @vehicleFerry.
  ///
  /// In en, this message translates to:
  /// **'Ferry'**
  String get vehicleFerry;

  /// No description provided for @vehicleSailboat.
  ///
  /// In en, this message translates to:
  /// **'Sailboat'**
  String get vehicleSailboat;

  /// No description provided for @vehicleSpeedboat.
  ///
  /// In en, this message translates to:
  /// **'Speedboat'**
  String get vehicleSpeedboat;

  /// No description provided for @vehicleBarge.
  ///
  /// In en, this message translates to:
  /// **'Barge'**
  String get vehicleBarge;

  /// No description provided for @vehicleWarship.
  ///
  /// In en, this message translates to:
  /// **'Warship'**
  String get vehicleWarship;

  /// No description provided for @vehicleCarrier.
  ///
  /// In en, this message translates to:
  /// **'Aircraft Carrier'**
  String get vehicleCarrier;

  /// No description provided for @vehicleGlider.
  ///
  /// In en, this message translates to:
  /// **'Glider'**
  String get vehicleGlider;

  /// No description provided for @vehicleHelicopter.
  ///
  /// In en, this message translates to:
  /// **'Helicopter'**
  String get vehicleHelicopter;

  /// No description provided for @vehicleDrone.
  ///
  /// In en, this message translates to:
  /// **'Drone'**
  String get vehicleDrone;

  /// No description provided for @vehicleAirliner.
  ///
  /// In en, this message translates to:
  /// **'Airliner'**
  String get vehicleAirliner;

  /// No description provided for @vehicleFighter.
  ///
  /// In en, this message translates to:
  /// **'Fighter Jet'**
  String get vehicleFighter;

  /// No description provided for @vehicleCargo.
  ///
  /// In en, this message translates to:
  /// **'Cargo Plane'**
  String get vehicleCargo;

  /// No description provided for @vehicleSeaplane.
  ///
  /// In en, this message translates to:
  /// **'Seaplane'**
  String get vehicleSeaplane;

  /// No description provided for @vehicleStealth.
  ///
  /// In en, this message translates to:
  /// **'Stealth Jet'**
  String get vehicleStealth;

  /// No description provided for @vehicleRocket.
  ///
  /// In en, this message translates to:
  /// **'Rocket'**
  String get vehicleRocket;

  /// No description provided for @vehicleSpaceShuttle.
  ///
  /// In en, this message translates to:
  /// **'Space Shuttle'**
  String get vehicleSpaceShuttle;

  /// No description provided for @vehicleSpaceStation.
  ///
  /// In en, this message translates to:
  /// **'Space Station'**
  String get vehicleSpaceStation;

  /// No description provided for @vehicleLunar.
  ///
  /// In en, this message translates to:
  /// **'Lunar Rover'**
  String get vehicleLunar;

  /// No description provided for @vehicleStarship.
  ///
  /// In en, this message translates to:
  /// **'Starship'**
  String get vehicleStarship;

  /// No description provided for @vehicleWarpShip.
  ///
  /// In en, this message translates to:
  /// **'Warp Ship'**
  String get vehicleWarpShip;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
