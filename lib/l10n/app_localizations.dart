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

  /// No description provided for @offlineHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours'**
  String offlineHours(String hours);

  /// No description provided for @offlineMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String offlineMinutes(String minutes);

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @offlineWelcome.
  ///
  /// In en, this message translates to:
  /// **'You were away for {duration}. Your fleet earned +{reward} 🪙. No rush — take your time.'**
  String offlineWelcome(String duration, int reward);

  /// No description provided for @takeIt.
  ///
  /// In en, this message translates to:
  /// **'Take it!'**
  String get takeIt;

  /// No description provided for @alreadyCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Already checked in today'**
  String get alreadyCheckedIn;

  /// No description provided for @signInStreakHint.
  ///
  /// In en, this message translates to:
  /// **'{streak}-day streak — keep going, the big prize lands on day 7!'**
  String signInStreakHint(int streak);

  /// No description provided for @signInJackpot.
  ///
  /// In en, this message translates to:
  /// **'Streak jackpot! +{reward} 🪙'**
  String signInJackpot(int reward);

  /// No description provided for @signInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Checked in! +{reward} 🪙'**
  String signInSuccess(int reward);

  /// No description provided for @signInCycleDone.
  ///
  /// In en, this message translates to:
  /// **'{streak}-day streak — 7-day cycle complete, jackpot unlocked! A fresh cycle starts tomorrow.'**
  String signInCycleDone(int streak);

  /// No description provided for @signInProgress.
  ///
  /// In en, this message translates to:
  /// **'{streak}-day streak, {reward} coins banked. Keep it up — day 7 brings the big prize 🎁'**
  String signInProgress(int streak, int reward);

  /// No description provided for @soundAndMusic.
  ///
  /// In en, this message translates to:
  /// **'Sound & Music'**
  String get soundAndMusic;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haptics;

  /// No description provided for @privacyAdPreferences.
  ///
  /// In en, this message translates to:
  /// **'Privacy & ad preferences'**
  String get privacyAdPreferences;

  /// No description provided for @privacyAdPreferencesSub.
  ///
  /// In en, this message translates to:
  /// **'Change or withdraw ad consent anytime'**
  String get privacyAdPreferencesSub;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @adDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Ad diagnostics'**
  String get adDiagnostics;

  /// No description provided for @privacyNotRequired.
  ///
  /// In en, this message translates to:
  /// **'Not required in your region'**
  String get privacyNotRequired;

  /// No description provided for @privacyDemoNoSdk.
  ///
  /// In en, this message translates to:
  /// **'This demo build has no real ad SDK, so no consent form appears. Once live it shows automatically wherever consent is required.'**
  String get privacyDemoNoSdk;

  /// No description provided for @privacyNonPersonalized.
  ///
  /// In en, this message translates to:
  /// **'Your region doesn\'t require consent management, so we only request non-personalized ads.'**
  String get privacyNonPersonalized;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @privacyOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open privacy settings right now'**
  String get privacyOpenFailed;

  /// No description provided for @privacyDemoForm.
  ///
  /// In en, this message translates to:
  /// **'Demo build: with the real SDK this opens the system consent form.'**
  String get privacyDemoForm;

  /// No description provided for @privacyNetworkRetry.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again. Your consent status is unchanged — your current settings still apply.'**
  String get privacyNetworkRetry;

  /// No description provided for @endlessLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Endless Leaderboard'**
  String get endlessLeaderboard;

  /// No description provided for @endlessNoScores.
  ///
  /// In en, this message translates to:
  /// **'No scores yet — play a few Endless runs and you\'ll show up here.'**
  String get endlessNoScores;

  /// No description provided for @pointsUnit.
  ///
  /// In en, this message translates to:
  /// **'{score} pts'**
  String pointsUnit(String score);

  /// No description provided for @parkingTagline.
  ///
  /// In en, this message translates to:
  /// **'Ease every car into its spot'**
  String get parkingTagline;

  /// No description provided for @claimGrandPrize.
  ///
  /// In en, this message translates to:
  /// **'Claim the grand prize!'**
  String get claimGrandPrize;

  /// No description provided for @collectionGrandPrize.
  ///
  /// In en, this message translates to:
  /// **'Full collection bonus +{reward} 🪙'**
  String collectionGrandPrize(int reward);

  /// No description provided for @collectionComplete.
  ///
  /// In en, this message translates to:
  /// **'All {count} vehicles collected — a true collector!'**
  String collectionComplete(int count);

  /// No description provided for @allLevels.
  ///
  /// In en, this message translates to:
  /// **'All Levels'**
  String get allLevels;

  /// No description provided for @levelsCleared.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} cleared'**
  String levelsCleared(int done, int total);

  /// No description provided for @dailyDoneToday.
  ///
  /// In en, this message translates to:
  /// **'Done today · {streak}-day streak'**
  String dailyDoneToday(int streak);

  /// No description provided for @dailyStreakBonus.
  ///
  /// In en, this message translates to:
  /// **'{streak}-day streak · +{reward} 🪙'**
  String dailyStreakBonus(int streak, int reward);

  /// No description provided for @dailyFinishReward.
  ///
  /// In en, this message translates to:
  /// **'Finish to earn +{reward} 🪙'**
  String dailyFinishReward(int reward);

  /// No description provided for @heroTitleNew.
  ///
  /// In en, this message translates to:
  /// **'Time to Roll'**
  String get heroTitleNew;

  /// No description provided for @heroTitleResume.
  ///
  /// In en, this message translates to:
  /// **'Keep Playing'**
  String get heroTitleResume;

  /// No description provided for @bestScore.
  ///
  /// In en, this message translates to:
  /// **'Best {best}'**
  String bestScore(String best);

  /// No description provided for @overallProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get overallProgress;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startGame;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Play a round or two, grow your fleet at your own pace'**
  String get homeTagline;

  /// No description provided for @bestChain.
  ///
  /// In en, this message translates to:
  /// **'🔥 Best chain x{combo}'**
  String bestChain(int combo);

  /// No description provided for @checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get checkIn;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'{streak}-day streak'**
  String streakDays(int streak);

  /// No description provided for @claimable.
  ///
  /// In en, this message translates to:
  /// **'Claimable!'**
  String get claimable;

  /// No description provided for @endlessMode.
  ///
  /// In en, this message translates to:
  /// **'Endless'**
  String get endlessMode;

  /// No description provided for @endlessTagline.
  ///
  /// In en, this message translates to:
  /// **'Merge without stopping'**
  String get endlessTagline;

  /// No description provided for @boosterTimeCard.
  ///
  /// In en, this message translates to:
  /// **'Time Card'**
  String get boosterTimeCard;

  /// No description provided for @boosterExtraCards.
  ///
  /// In en, this message translates to:
  /// **'Extra Cards'**
  String get boosterExtraCards;

  /// No description provided for @boosterDoubleCoins.
  ///
  /// In en, this message translates to:
  /// **'Double Coins'**
  String get boosterDoubleCoins;

  /// No description provided for @boosterUndoCard.
  ///
  /// In en, this message translates to:
  /// **'Undo Card'**
  String get boosterUndoCard;

  /// No description provided for @boosterBomb.
  ///
  /// In en, this message translates to:
  /// **'Bomb'**
  String get boosterBomb;

  /// No description provided for @boosterSpring.
  ///
  /// In en, this message translates to:
  /// **'Spring'**
  String get boosterSpring;

  /// No description provided for @boosterBalloon.
  ///
  /// In en, this message translates to:
  /// **'Balloon'**
  String get boosterBalloon;

  /// No description provided for @boosterKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get boosterKey;

  /// No description provided for @boosterHammer.
  ///
  /// In en, this message translates to:
  /// **'Hammer'**
  String get boosterHammer;

  /// No description provided for @boosterDoubleMove.
  ///
  /// In en, this message translates to:
  /// **'Double Move'**
  String get boosterDoubleMove;

  /// No description provided for @adRewardLine.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad · +{reward} 🪙'**
  String adRewardLine(int reward);

  /// No description provided for @adLeftToday.
  ///
  /// In en, this message translates to:
  /// **'{count} left today'**
  String adLeftToday(int count);

  /// No description provided for @adLeftTodayWithReward.
  ///
  /// In en, this message translates to:
  /// **'{count} left today, +{reward} 🪙 each'**
  String adLeftTodayWithReward(int count, int reward);

  /// No description provided for @adUsedUp.
  ///
  /// In en, this message translates to:
  /// **'All used for today — come back tomorrow'**
  String get adUsedUp;

  /// No description provided for @adDidNotFinish.
  ///
  /// In en, this message translates to:
  /// **'Ad didn\'t finish'**
  String get adDidNotFinish;

  /// No description provided for @chestGotItem.
  ///
  /// In en, this message translates to:
  /// **'You got {name}!'**
  String chestGotItem(String name);

  /// No description provided for @chestStockParking.
  ///
  /// In en, this message translates to:
  /// **'+1 in stock — use it in Parking'**
  String get chestStockParking;

  /// No description provided for @chestStockMerge.
  ///
  /// In en, this message translates to:
  /// **'+1 in stock — auto-applies when a Merge level starts'**
  String get chestStockMerge;

  /// No description provided for @chestCoins90.
  ///
  /// In en, this message translates to:
  /// **'+90 coins'**
  String get chestCoins90;

  /// No description provided for @chestCoins90Note.
  ///
  /// In en, this message translates to:
  /// **'A small haul — the next chest could be lucky!'**
  String get chestCoins90Note;

  /// No description provided for @chestCoins150.
  ///
  /// In en, this message translates to:
  /// **'+150 coins'**
  String get chestCoins150;

  /// No description provided for @chestCoins150Note.
  ///
  /// In en, this message translates to:
  /// **'Nice little win!'**
  String get chestCoins150Note;

  /// No description provided for @chestCoins300.
  ///
  /// In en, this message translates to:
  /// **'+300 coins!'**
  String get chestCoins300;

  /// No description provided for @chestCoins300Note.
  ///
  /// In en, this message translates to:
  /// **'Jackpot! Luck\'s on your side today!'**
  String get chestCoins300Note;

  /// No description provided for @shopTitle.
  ///
  /// In en, this message translates to:
  /// **'Sunny Shop'**
  String get shopTitle;

  /// No description provided for @shopTagline.
  ///
  /// In en, this message translates to:
  /// **'A little luck on the side — stop whenever you like'**
  String get shopTagline;

  /// No description provided for @chestTitle.
  ///
  /// In en, this message translates to:
  /// **'Coin Chest'**
  String get chestTitle;

  /// No description provided for @chestPerDraw.
  ///
  /// In en, this message translates to:
  /// **'{cost} 🪙 per chest · opens coins or a booster at random'**
  String chestPerDraw(int cost);

  /// No description provided for @chestBoosterHelp.
  ///
  /// In en, this message translates to:
  /// **'Boosters save a run when it counts: Time Card +30s, Extra Cards +3, Double Coins doubles your clear reward. Parking boosters (Bomb / Spring / Key…) only work in Parking.'**
  String get chestBoosterHelp;

  /// No description provided for @chestOpen.
  ///
  /// In en, this message translates to:
  /// **'Open chest · {cost} 🪙'**
  String chestOpen(int cost);

  /// No description provided for @chestNeedMore.
  ///
  /// In en, this message translates to:
  /// **'Need {amount} more 🪙'**
  String chestNeedMore(int amount);

  /// No description provided for @dailyPerks.
  ///
  /// In en, this message translates to:
  /// **'Daily Bonus'**
  String get dailyPerks;

  /// No description provided for @dailyPerksTagline.
  ///
  /// In en, this message translates to:
  /// **'Take it easy — no need to log in every day'**
  String get dailyPerksTagline;

  /// No description provided for @loadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingEllipsis;

  /// No description provided for @claimPlus.
  ///
  /// In en, this message translates to:
  /// **'Claim +{reward}'**
  String claimPlus(int reward);

  /// No description provided for @noPurchaseNotice.
  ///
  /// In en, this message translates to:
  /// **'All coins come from ads and clearing levels — earn as you play.'**
  String get noPurchaseNotice;

  /// No description provided for @demoAdNotice.
  ///
  /// In en, this message translates to:
  /// **'Demo build: ads play instantly and always reward.'**
  String get demoAdNotice;

  /// No description provided for @myBoosters.
  ///
  /// In en, this message translates to:
  /// **'My Boosters'**
  String get myBoosters;

  /// No description provided for @myBoostersFrom.
  ///
  /// In en, this message translates to:
  /// **'From chests and 3-star Parking rewards'**
  String get myBoostersFrom;

  /// No description provided for @mergeBoostersLabel.
  ///
  /// In en, this message translates to:
  /// **'Merge boosters · auto-apply at level start'**
  String get mergeBoostersLabel;

  /// No description provided for @parkingBoostersLabel.
  ///
  /// In en, this message translates to:
  /// **'Parking boosters · Parking mode only'**
  String get parkingBoostersLabel;

  /// No description provided for @abilityNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get abilityNone;

  /// No description provided for @abilityTurn.
  ///
  /// In en, this message translates to:
  /// **'Turning'**
  String get abilityTurn;

  /// No description provided for @abilityFlyOver.
  ///
  /// In en, this message translates to:
  /// **'Jump over'**
  String get abilityFlyOver;

  /// No description provided for @abilityBreakIce.
  ///
  /// In en, this message translates to:
  /// **'Ice breaker'**
  String get abilityBreakIce;

  /// No description provided for @abilityBreakChain.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get abilityBreakChain;

  /// No description provided for @abilityClearRock.
  ///
  /// In en, this message translates to:
  /// **'Rock breaker'**
  String get abilityClearRock;

  /// No description provided for @abilityWaterWalk.
  ///
  /// In en, this message translates to:
  /// **'Cross water'**
  String get abilityWaterWalk;

  /// No description provided for @abilityRailOnly.
  ///
  /// In en, this message translates to:
  /// **'Rail only'**
  String get abilityRailOnly;

  /// No description provided for @abilityTeleport.
  ///
  /// In en, this message translates to:
  /// **'Teleport'**
  String get abilityTeleport;

  /// No description provided for @abilityPickup.
  ///
  /// In en, this message translates to:
  /// **'Pick up'**
  String get abilityPickup;

  /// No description provided for @abilitySonar.
  ///
  /// In en, this message translates to:
  /// **'Scout'**
  String get abilitySonar;

  /// No description provided for @abilityVertical.
  ///
  /// In en, this message translates to:
  /// **'VTOL'**
  String get abilityVertical;

  /// No description provided for @abilityAmphibious.
  ///
  /// In en, this message translates to:
  /// **'Amphibious'**
  String get abilityAmphibious;

  /// No description provided for @abilityTow.
  ///
  /// In en, this message translates to:
  /// **'Tow'**
  String get abilityTow;

  /// No description provided for @abilityCarry.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get abilityCarry;

  /// No description provided for @abilityWarp.
  ///
  /// In en, this message translates to:
  /// **'Warp'**
  String get abilityWarp;

  /// No description provided for @noAbility.
  ///
  /// In en, this message translates to:
  /// **'No special ability'**
  String get noAbility;

  /// No description provided for @moveDistance.
  ///
  /// In en, this message translates to:
  /// **'Moves {n}'**
  String moveDistance(int n);

  /// No description provided for @moveDistanceTurn.
  ///
  /// In en, this message translates to:
  /// **'Moves {n} + turn'**
  String moveDistanceTurn(int n);

  /// No description provided for @listSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @hintCollectionUnlock.
  ///
  /// In en, this message translates to:
  /// **'📖 {icon} {name} added to collection +5🪙'**
  String hintCollectionUnlock(String icon, String name);

  /// No description provided for @hintMilestone.
  ///
  /// In en, this message translates to:
  /// **'🏆 Milestone! Endless tier {tier} +{reward} 🪙'**
  String hintMilestone(int tier, int reward);

  /// No description provided for @hintClearBoardIntro.
  ///
  /// In en, this message translates to:
  /// **'🎯 Use up the deck — you win with ≤{limit} groups left! Drag matching cars together; three top-tier cars launch away'**
  String hintClearBoardIntro(int limit);

  /// No description provided for @hintBossIntro.
  ///
  /// In en, this message translates to:
  /// **'👑 Boss fight! Merge {icon} {name} to hit the Boss ({hp} HP) — the red circle is its target. Watch out for ice and tow trucks!'**
  String hintBossIntro(String icon, String name, int hp);

  /// No description provided for @hintBoosterTime.
  ///
  /// In en, this message translates to:
  /// **'🕐 Time Card: +30s'**
  String get hintBoosterTime;

  /// No description provided for @hintBoosterTimeToCoins.
  ///
  /// In en, this message translates to:
  /// **'🕐 Time Card (not a timed level) → +30 🪙'**
  String get hintBoosterTimeToCoins;

  /// No description provided for @hintBoosterCards.
  ///
  /// In en, this message translates to:
  /// **'📦 Extra Cards: deck +3'**
  String get hintBoosterCards;

  /// No description provided for @hintBoosterDouble.
  ///
  /// In en, this message translates to:
  /// **'🎲 Double Coins: clear reward ×2'**
  String get hintBoosterDouble;

  /// No description provided for @winBoss.
  ///
  /// In en, this message translates to:
  /// **'👑 Boss down! Your fleet moved up a tier'**
  String get winBoss;

  /// No description provided for @winGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal reached: {goal}'**
  String winGoal(String goal);

  /// No description provided for @winEndlessRecord.
  ///
  /// In en, this message translates to:
  /// **'🌌 Endless record!'**
  String get winEndlessRecord;

  /// No description provided for @winBoardFull.
  ///
  /// In en, this message translates to:
  /// **'💥 Board full'**
  String get winBoardFull;

  /// No description provided for @winBossShort.
  ///
  /// In en, this message translates to:
  /// **'👑 Boss defeated!'**
  String get winBossShort;

  /// No description provided for @winCleared.
  ///
  /// In en, this message translates to:
  /// **'🎉 Board cleared!'**
  String get winCleared;

  /// No description provided for @winLevel.
  ///
  /// In en, this message translates to:
  /// **'🚀 Level cleared!'**
  String get winLevel;

  /// No description provided for @loseBoss.
  ///
  /// In en, this message translates to:
  /// **'👑 Boss level · so close'**
  String get loseBoss;

  /// No description provided for @loseAdGate.
  ///
  /// In en, this message translates to:
  /// **'🎬 Challenge · so close'**
  String get loseAdGate;

  /// No description provided for @loseTime.
  ///
  /// In en, this message translates to:
  /// **'⏰ So close'**
  String get loseTime;

  /// No description provided for @reviveTime.
  ///
  /// In en, this message translates to:
  /// **'🎬 Watch ad to continue · +30s'**
  String get reviveTime;

  /// No description provided for @reviveMoves.
  ///
  /// In en, this message translates to:
  /// **'🎬 Watch ad to continue · +10 moves'**
  String get reviveMoves;

  /// No description provided for @reviveDeadEnd.
  ///
  /// In en, this message translates to:
  /// **'🎬 Watch ad to continue · +2 cards, reshuffle'**
  String get reviveDeadEnd;

  /// No description provided for @reviveEndlessStuck.
  ///
  /// In en, this message translates to:
  /// **'🎬 Watch ad to continue · clear 3 groups'**
  String get reviveEndlessStuck;

  /// No description provided for @shareEndless.
  ///
  /// In en, this message translates to:
  /// **'I hit {score} points in Merge Fleet Endless! Beat me 🚀'**
  String shareEndless(int score);

  /// No description provided for @shareLevelStars.
  ///
  /// In en, this message translates to:
  /// **'I got {stars} stars on level {level} in Merge Fleet! Unlock the galaxy and beat me 🚗✨'**
  String shareLevelStars(int stars, int level);

  /// No description provided for @shareLevelTry.
  ///
  /// In en, this message translates to:
  /// **'I\'m on level {level} in Merge Fleet — come merge a fleet too 🚗'**
  String shareLevelTry(int level);

  /// No description provided for @shareCopied.
  ///
  /// In en, this message translates to:
  /// **'✅ Copied — paste it to a friend!'**
  String get shareCopied;

  /// No description provided for @pausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get pausedTitle;

  /// No description provided for @pausedTipBreak.
  ///
  /// In en, this message translates to:
  /// **'Take a breather — jump back in whenever'**
  String get pausedTipBreak;

  /// No description provided for @pausedTipThink.
  ///
  /// In en, this message translates to:
  /// **'No rush, think about your next move'**
  String get pausedTipThink;

  /// No description provided for @elapsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get elapsedLabel;

  /// No description provided for @parLabel.
  ///
  /// In en, this message translates to:
  /// **'Par'**
  String get parLabel;

  /// No description provided for @estLabel.
  ///
  /// In en, this message translates to:
  /// **'Est.'**
  String get estLabel;

  /// No description provided for @resumeGame.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeGame;

  /// No description provided for @restartRun.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restartRun;

  /// No description provided for @backHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get backHome;

  /// No description provided for @detailEndlessNext.
  ///
  /// In en, this message translates to:
  /// **'Merged up to tier {tier} — climb higher next run!'**
  String detailEndlessNext(int tier);

  /// No description provided for @detailBossAlive.
  ///
  /// In en, this message translates to:
  /// **'👑 Boss has {hp} HP left — merge the target car to hit it!'**
  String detailBossAlive(int hp);

  /// No description provided for @detailBossDead.
  ///
  /// In en, this message translates to:
  /// **'👑 Boss is down!'**
  String get detailBossDead;

  /// No description provided for @detailTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up — that was close'**
  String get detailTimeUp;

  /// No description provided for @detailClearRemain.
  ///
  /// In en, this message translates to:
  /// **'{left} groups left (goal ≤{limit})'**
  String detailClearRemain(int left, int limit);

  /// No description provided for @detailClearNearly.
  ///
  /// In en, this message translates to:
  /// **'One more nudge and it\'s clear'**
  String get detailClearNearly;

  /// No description provided for @detailTargetRemain.
  ///
  /// In en, this message translates to:
  /// **'{remain} more {icon} {name} to go'**
  String detailTargetRemain(int remain, String icon, String name);

  /// No description provided for @exitTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this level?'**
  String get exitTitle;

  /// No description provided for @exitMessage.
  ///
  /// In en, this message translates to:
  /// **'Progress in this run will be lost. Sure you want to go?'**
  String get exitMessage;

  /// No description provided for @keepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get keepPlaying;

  /// No description provided for @exitRun.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get exitRun;

  /// No description provided for @tooltipBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get tooltipBack;

  /// No description provided for @tooltipPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get tooltipPause;

  /// No description provided for @chipDeckDone.
  ///
  /// In en, this message translates to:
  /// **'📦 Deck done · {left} left'**
  String chipDeckDone(int left);

  /// No description provided for @chipClearOk.
  ///
  /// In en, this message translates to:
  /// **'✅ On target! {v} groups'**
  String chipClearOk(int v);

  /// No description provided for @chipClearProgress.
  ///
  /// In en, this message translates to:
  /// **'{v} groups / goal ≤{limit}'**
  String chipClearProgress(int v, int limit);

  /// No description provided for @chipStockLocked.
  ///
  /// In en, this message translates to:
  /// **'🔒 Locked by Boss'**
  String get chipStockLocked;

  /// No description provided for @chipStockInfinite.
  ///
  /// In en, this message translates to:
  /// **'Infinite deck'**
  String get chipStockInfinite;

  /// No description provided for @chipStockLeft.
  ///
  /// In en, this message translates to:
  /// **'Deck: {left} left'**
  String chipStockLeft(int left);

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionAddCards.
  ///
  /// In en, this message translates to:
  /// **'Add cards'**
  String get actionAddCards;

  /// No description provided for @actionShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get actionShuffle;

  /// No description provided for @headerLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {id} · {name}'**
  String headerLevel(int id, String name);

  /// No description provided for @movesBadge.
  ///
  /// In en, this message translates to:
  /// **'👟 {m} moves'**
  String movesBadge(int m);

  /// No description provided for @introEndlessTitle.
  ///
  /// In en, this message translates to:
  /// **'🌌 Endless climb: keep merging to higher tiers'**
  String get introEndlessTitle;

  /// No description provided for @introEndlessHow.
  ///
  /// In en, this message translates to:
  /// **'It ends when the board fills up'**
  String get introEndlessHow;

  /// No description provided for @introBossTitle.
  ///
  /// In en, this message translates to:
  /// **'👑 Boss fight: merge {icon} {name} to hit the Boss — empty its {hp} HP bar to win'**
  String introBossTitle(String icon, String name, int hp);

  /// No description provided for @introBossHow.
  ///
  /// In en, this message translates to:
  /// **'The Boss strikes every 9s — a colored ring means it\'s about to act: {threats}!'**
  String introBossHow(String threats);

  /// No description provided for @introClearTitle.
  ///
  /// In en, this message translates to:
  /// **'🎯 Goal: use up the deck — win with ≤{limit} groups left'**
  String introClearTitle(int limit);

  /// No description provided for @introClearHow.
  ///
  /// In en, this message translates to:
  /// **'Drag 3 matching cars together to upgrade; the top tier launches away'**
  String get introClearHow;

  /// No description provided for @introMergeHow.
  ///
  /// In en, this message translates to:
  /// **'Drag matching cars together to upgrade'**
  String get introMergeHow;

  /// No description provided for @threatFreeze.
  ///
  /// In en, this message translates to:
  /// **'freezes your key cars (merge next to them to free them)'**
  String get threatFreeze;

  /// No description provided for @threatSteal.
  ///
  /// In en, this message translates to:
  /// **'steals your highest-tier car'**
  String get threatSteal;

  /// No description provided for @threatLock.
  ///
  /// In en, this message translates to:
  /// **'locks the deck for a few seconds'**
  String get threatLock;

  /// No description provided for @threatEnrage.
  ///
  /// In en, this message translates to:
  /// **'enrages and speeds up at half HP'**
  String get threatEnrage;

  /// No description provided for @stockLockedByBoss.
  ///
  /// In en, this message translates to:
  /// **'🔒 The Boss locked the deck, hang on…'**
  String get stockLockedByBoss;

  /// No description provided for @stockInfiniteTap.
  ///
  /// In en, this message translates to:
  /// **'📦 Infinite deck · tap a card to draw'**
  String get stockInfiniteTap;

  /// No description provided for @stockLeftTap.
  ///
  /// In en, this message translates to:
  /// **'📦 {left} left · tap a card to draw'**
  String stockLeftTap(int left);

  /// No description provided for @stockEmpty.
  ///
  /// In en, this message translates to:
  /// **'📦 Deck empty'**
  String get stockEmpty;

  /// No description provided for @resultScore.
  ///
  /// In en, this message translates to:
  /// **'Score {score}  ·  +{reward} 🪙'**
  String resultScore(int score, int reward);

  /// No description provided for @resultScoreConsolation.
  ///
  /// In en, this message translates to:
  /// **'Score {score}  ·  consolation +{consolation} 🪙'**
  String resultScoreConsolation(int score, int consolation);

  /// No description provided for @doubleCoinsCta.
  ///
  /// In en, this message translates to:
  /// **'Watch ad · coins ×2 (+{reward} 🪙)'**
  String doubleCoinsCta(int reward);

  /// No description provided for @endlessRanked.
  ///
  /// In en, this message translates to:
  /// **'Cleared {tier} tiers · rank #{rank}'**
  String endlessRanked(int tier, int rank);

  /// No description provided for @endlessUnranked.
  ///
  /// In en, this message translates to:
  /// **'Cleared {tier} tiers · outside top 10'**
  String endlessUnranked(int tier);

  /// No description provided for @comboNewRecord.
  ///
  /// In en, this message translates to:
  /// **'Best chain x{combo}  ·  🔥 New record!  ·  {time}'**
  String comboNewRecord(int combo, String time);

  /// No description provided for @comboNormal.
  ///
  /// In en, this message translates to:
  /// **'Best chain x{combo}  ·  best ever x{best}  ·  {time}'**
  String comboNormal(int combo, int best, String time);

  /// No description provided for @parSuffix.
  ///
  /// In en, this message translates to:
  /// **'  ·  par {par}'**
  String parSuffix(String par);

  /// No description provided for @speedrunBadge.
  ///
  /// In en, this message translates to:
  /// **'⚡ Speedrun!'**
  String get speedrunBadge;

  /// No description provided for @shareResult.
  ///
  /// In en, this message translates to:
  /// **'Share result'**
  String get shareResult;

  /// No description provided for @nextLevelArrow.
  ///
  /// In en, this message translates to:
  /// **'Next ▶'**
  String get nextLevelArrow;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get playAgain;

  /// No description provided for @newCarBadge.
  ///
  /// In en, this message translates to:
  /// **'✨ New car unlocked'**
  String get newCarBadge;

  /// No description provided for @firstMergeBadge.
  ///
  /// In en, this message translates to:
  /// **'{category} · first merge'**
  String firstMergeBadge(String category);

  /// No description provided for @headerEndless.
  ///
  /// In en, this message translates to:
  /// **'🌌 Endless'**
  String get headerEndless;

  /// No description provided for @goalProduce.
  ///
  /// In en, this message translates to:
  /// **'Goal: merge {name} ×{count}'**
  String goalProduce(String name, int count);

  /// No description provided for @goalProduceBoss.
  ///
  /// In en, this message translates to:
  /// **'Goal: merge {name} ×{count} (hit the Boss)'**
  String goalProduceBoss(String name, int count);

  /// No description provided for @goalClearBoard.
  ///
  /// In en, this message translates to:
  /// **'Goal: use up the deck, ≤{limit} groups left'**
  String goalClearBoard(int limit);

  /// No description provided for @goalWithinMoves.
  ///
  /// In en, this message translates to:
  /// **'Within {moves} moves · {goal}'**
  String goalWithinMoves(int moves, String goal);

  /// No description provided for @goalWithinTime.
  ///
  /// In en, this message translates to:
  /// **'Within {seconds}s · {goal}'**
  String goalWithinTime(int seconds, String goal);

  /// No description provided for @bonusWildcard.
  ///
  /// In en, this message translates to:
  /// **'⭐ Wildcard×{n}'**
  String bonusWildcard(int n);

  /// No description provided for @bonusBomb.
  ///
  /// In en, this message translates to:
  /// **'💣 Bomb×{n}'**
  String bonusBomb(int n);

  /// No description provided for @bonusFog.
  ///
  /// In en, this message translates to:
  /// **'🌫 Fog×{n}'**
  String bonusFog(int n);

  /// 无尽模式这一关的名字（关卡标题栏用）
  ///
  /// In en, this message translates to:
  /// **'Endless'**
  String get levelEndlessName;

  /// 每日挑战关卡的名字
  ///
  /// In en, this message translates to:
  /// **'Daily Challenge'**
  String get dailyChallengeName;

  /// 生成关卡里 Boss 关的名字模板，chapter = 章节短名
  ///
  /// In en, this message translates to:
  /// **'👑 Boss · {chapter}'**
  String bossLevelName(String chapter);

  /// 第 1 关的名字：清晨路段
  ///
  /// In en, this message translates to:
  /// **'Morning Run'**
  String get lv01;

  /// 第 2 关的名字：早高峰
  ///
  /// In en, this message translates to:
  /// **'Rush Hour'**
  String get lv02;

  /// 第 3 关的名字：环城快线
  ///
  /// In en, this message translates to:
  /// **'Ring Express'**
  String get lv03;

  /// 第 4 关的名字：货运枢纽
  ///
  /// In en, this message translates to:
  /// **'Freight Hub'**
  String get lv04;

  /// 第 5 关的名字：钢铁干线
  ///
  /// In en, this message translates to:
  /// **'Steel Trunk Line'**
  String get lv05;

  /// 第 6 关的名字：星光清道夫
  ///
  /// In en, this message translates to:
  /// **'Starlight Sweeper'**
  String get lv06;

  /// 第 7 关的名字：午夜冲刺
  ///
  /// In en, this message translates to:
  /// **'Midnight Dash'**
  String get lv07;

  /// 第 8 关的名字：都市高速
  ///
  /// In en, this message translates to:
  /// **'City Freeway'**
  String get lv08;

  /// 第 9 关的名字：限时清道夫
  ///
  /// In en, this message translates to:
  /// **'Timed Sweeper'**
  String get lv09;

  /// 第 10 关的名字：终局冲刺
  ///
  /// In en, this message translates to:
  /// **'Final Sprint'**
  String get lv10;

  /// 第 11 关的名字：街头初段
  ///
  /// In en, this message translates to:
  /// **'Street Opener'**
  String get lv11;

  /// 第 12 关的名字：环城小巴
  ///
  /// In en, this message translates to:
  /// **'Loop Shuttle'**
  String get lv12;

  /// 第 13 关的名字：冰雪送货
  ///
  /// In en, this message translates to:
  /// **'Ice Delivery'**
  String get lv13;

  /// 第 14 关的名字：限时货运
  ///
  /// In en, this message translates to:
  /// **'Timed Freight'**
  String get lv14;

  /// 第 15 关的名字：清道夫之巅
  ///
  /// In en, this message translates to:
  /// **'Sweeper\'s Peak'**
  String get lv15;

  /// 第 16 关的名字：轨道延伸
  ///
  /// In en, this message translates to:
  /// **'Rails Extended'**
  String get lv16;

  /// 第 17 关的名字：火箭升空
  ///
  /// In en, this message translates to:
  /// **'Rocket Launch'**
  String get lv17;

  /// 第 18 关的名字：限时清盘 II
  ///
  /// In en, this message translates to:
  /// **'Timed Clear II'**
  String get lv18;

  /// 第 19 关的名字：重装集结
  ///
  /// In en, this message translates to:
  /// **'Heavy Muster'**
  String get lv19;

  /// 第 20 关的名字：终极枢纽
  ///
  /// In en, this message translates to:
  /// **'Ultimate Hub'**
  String get lv20;

  /// 第 21 关的名字：快速轨道
  ///
  /// In en, this message translates to:
  /// **'Rapid Rail'**
  String get lv21;

  /// 第 22 关的名字：油罐运输
  ///
  /// In en, this message translates to:
  /// **'Tanker Run'**
  String get lv22;

  /// 第 23 关的名字：清道夫 III
  ///
  /// In en, this message translates to:
  /// **'Sweeper III'**
  String get lv23;

  /// 第 24 关的名字：高铁提速
  ///
  /// In en, this message translates to:
  /// **'High-Speed Push'**
  String get lv24;

  /// 第 25 关的名字：地铁高峰
  ///
  /// In en, this message translates to:
  /// **'Metro Peak'**
  String get lv25;

  /// 第 26 关的名字：机场跑道
  ///
  /// In en, this message translates to:
  /// **'Airport Runway'**
  String get lv26;

  /// 第 27 关的名字：限时清盘 III
  ///
  /// In en, this message translates to:
  /// **'Timed Clear III'**
  String get lv27;

  /// 第 28 关的名字：空中走廊
  ///
  /// In en, this message translates to:
  /// **'Sky Corridor'**
  String get lv28;

  /// 第 29 关的名字：港铁枢纽
  ///
  /// In en, this message translates to:
  /// **'Rail-Sea Hub'**
  String get lv29;

  /// 第 30 关的名字：千钧一发
  ///
  /// In en, this message translates to:
  /// **'Close Call'**
  String get lv30;

  /// 第 31 关的名字：六轨立交
  ///
  /// In en, this message translates to:
  /// **'Six-Rail Interchange'**
  String get lv31;

  /// 第 32 关的名字：战机升空
  ///
  /// In en, this message translates to:
  /// **'Fighter Launch'**
  String get lv32;

  /// 第 33 关的名字：清盘极限
  ///
  /// In en, this message translates to:
  /// **'Clear Limit'**
  String get lv33;

  /// 第 34 关的名字：空中霸主
  ///
  /// In en, this message translates to:
  /// **'Sky Overlord'**
  String get lv34;

  /// 第 35 关的名字：暴风限时
  ///
  /// In en, this message translates to:
  /// **'Storm Deadline'**
  String get lv35;

  /// 第 36 关的名字：星际预演
  ///
  /// In en, this message translates to:
  /// **'Stellar Rehearsal'**
  String get lv36;

  /// 第 37 关的名字：多重拦截
  ///
  /// In en, this message translates to:
  /// **'Layered Blockade'**
  String get lv37;

  /// 第 38 关的名字：限时清盘 IV
  ///
  /// In en, this message translates to:
  /// **'Timed Clear IV'**
  String get lv38;

  /// 第 39 关的名字：重装巅峰
  ///
  /// In en, this message translates to:
  /// **'Heavy Peak'**
  String get lv39;

  /// 第 40 关的名字：终局预演
  ///
  /// In en, this message translates to:
  /// **'Final Rehearsal'**
  String get lv40;

  /// 第 41 关的名字：星辰之路
  ///
  /// In en, this message translates to:
  /// **'Road of Stars'**
  String get lv41;

  /// 第 42 关的名字：极限清盘
  ///
  /// In en, this message translates to:
  /// **'Ultimate Clear'**
  String get lv42;

  /// 第 43 关的名字：深空舰队
  ///
  /// In en, this message translates to:
  /// **'Deep-Space Fleet'**
  String get lv43;

  /// 第 44 关的名字：时空之门
  ///
  /// In en, this message translates to:
  /// **'Gate of Time'**
  String get lv44;

  /// 第 45 关的名字：群星汇聚
  ///
  /// In en, this message translates to:
  /// **'Star Convergence'**
  String get lv45;

  /// 第 46 关的名字：命运交叉
  ///
  /// In en, this message translates to:
  /// **'Fate Crossing'**
  String get lv46;

  /// 第 47 关的名字：混沌清盘
  ///
  /// In en, this message translates to:
  /// **'Chaos Clear'**
  String get lv47;

  /// 第 48 关的名字：星际舰队
  ///
  /// In en, this message translates to:
  /// **'Star Fleet'**
  String get lv48;

  /// 第 49 关的名字：破晓之辉
  ///
  /// In en, this message translates to:
  /// **'Dawnlight'**
  String get lv49;

  /// 第 50 关的名字：终极星港
  ///
  /// In en, this message translates to:
  /// **'Starport Prime'**
  String get lv50;

  /// 第 51 关的名字：星港终战
  ///
  /// In en, this message translates to:
  /// **'Starport Showdown'**
  String get lv51;

  /// 第 52 关的名字：磁浮首航
  ///
  /// In en, this message translates to:
  /// **'Maglev Maiden Run'**
  String get lv52;

  /// 第 53 关的名字：轨道穿越
  ///
  /// In en, this message translates to:
  /// **'Rail Transit'**
  String get lv53;

  /// 第 54 关的名字：彗星追迹
  ///
  /// In en, this message translates to:
  /// **'Comet Chase'**
  String get lv54;

  /// 第 55 关的名字：限步物流
  ///
  /// In en, this message translates to:
  /// **'Move-Limited Logistics'**
  String get lv55;

  /// 第 56 关的名字：限步高铁
  ///
  /// In en, this message translates to:
  /// **'Move-Limited Rail'**
  String get lv56;

  /// 第 57 关的名字：限步清盘
  ///
  /// In en, this message translates to:
  /// **'Move-Limited Clear'**
  String get lv57;

  /// 第 58 关的名字：极限清盘
  ///
  /// In en, this message translates to:
  /// **'Ultimate Clear'**
  String get lv58;

  /// 第 59 关的名字：星云迷雾
  ///
  /// In en, this message translates to:
  /// **'Nebula Fog'**
  String get lv59;

  /// 第 60 关的名字：传送枢纽
  ///
  /// In en, this message translates to:
  /// **'Portal Hub'**
  String get lv60;

  /// 第 61 关的名字：万能试炼
  ///
  /// In en, this message translates to:
  /// **'Wildcard Trial'**
  String get lv61;

  /// 第 62 关的名字：爆破拆除
  ///
  /// In en, this message translates to:
  /// **'Demolition'**
  String get lv62;

  /// 第 63 关的名字：迷雾列车
  ///
  /// In en, this message translates to:
  /// **'Fog Train'**
  String get lv63;

  /// 第 64 关的名字：双重传送
  ///
  /// In en, this message translates to:
  /// **'Double Portal'**
  String get lv64;

  /// 第 65 关的名字：万能火箭
  ///
  /// In en, this message translates to:
  /// **'Wildcard Rocket'**
  String get lv65;

  /// 第 66 关的名字：炸弹狂潮
  ///
  /// In en, this message translates to:
  /// **'Bomb Frenzy'**
  String get lv66;

  /// 第 67 关的名字：传送清盘
  ///
  /// In en, this message translates to:
  /// **'Portal Clear'**
  String get lv67;

  /// 第 68 关的名字：迷雾星港
  ///
  /// In en, this message translates to:
  /// **'Fogged Starport'**
  String get lv68;

  /// 第 69 关的名字：组合地狱
  ///
  /// In en, this message translates to:
  /// **'Combo Hell'**
  String get lv69;

  /// 第 70 关的名字：终极传送
  ///
  /// In en, this message translates to:
  /// **'Ultimate Portal'**
  String get lv70;

  /// 第 1 章标题（含章序号）：第一章 · 街区起步
  ///
  /// In en, this message translates to:
  /// **'Chapter 1 · Street Start'**
  String get ch01Title;

  /// 第 1 章短名（生成关卡名用）：街区起步
  ///
  /// In en, this message translates to:
  /// **'Street Start'**
  String get ch01Name;

  /// 第 1 章副标题：从一辆自行车开始你的车队
  ///
  /// In en, this message translates to:
  /// **'Your fleet starts with a single bicycle'**
  String get ch01Sub;

  /// 第 2 章标题（含章序号）：第二章 · 城市干线
  ///
  /// In en, this message translates to:
  /// **'Chapter 2 · City Arteries'**
  String get ch02Title;

  /// 第 2 章短名（生成关卡名用）：城市干线
  ///
  /// In en, this message translates to:
  /// **'City Arteries'**
  String get ch02Name;

  /// 第 2 章副标题：车流渐密，货运繁忙
  ///
  /// In en, this message translates to:
  /// **'Traffic thickens, freight picks up'**
  String get ch02Sub;

  /// 第 3 章标题（含章序号）：第三章 · 轨道时代
  ///
  /// In en, this message translates to:
  /// **'Chapter 3 · Rail Age'**
  String get ch03Title;

  /// 第 3 章短名（生成关卡名用）：轨道时代
  ///
  /// In en, this message translates to:
  /// **'Rail Age'**
  String get ch03Name;

  /// 第 3 章副标题：高铁地铁，四通八达
  ///
  /// In en, this message translates to:
  /// **'High-speed rail and metro, everywhere'**
  String get ch03Sub;

  /// 第 4 章标题（含章序号）：第四章 · 天空征途
  ///
  /// In en, this message translates to:
  /// **'Chapter 4 · Skybound'**
  String get ch04Title;

  /// 第 4 章短名（生成关卡名用）：天空征途
  ///
  /// In en, this message translates to:
  /// **'Skybound'**
  String get ch04Name;

  /// 第 4 章副标题：客机战机，冲向云端
  ///
  /// In en, this message translates to:
  /// **'Airliners and fighters reach for the clouds'**
  String get ch04Sub;

  /// 第 5 章标题（含章序号）：第五章 · 星际探索
  ///
  /// In en, this message translates to:
  /// **'Chapter 5 · Star Trek'**
  String get ch05Title;

  /// 第 5 章短名（生成关卡名用）：星际探索
  ///
  /// In en, this message translates to:
  /// **'Star Trek'**
  String get ch05Name;

  /// 第 5 章副标题：穿梭星辰大海
  ///
  /// In en, this message translates to:
  /// **'Threading through the sea of stars'**
  String get ch05Sub;

  /// 第 6 章标题（含章序号）：第六章 · 星港试炼
  ///
  /// In en, this message translates to:
  /// **'Chapter 6 · Starport Trial'**
  String get ch06Title;

  /// 第 6 章短名（生成关卡名用）：星港试炼
  ///
  /// In en, this message translates to:
  /// **'Starport Trial'**
  String get ch06Name;

  /// 第 6 章副标题：终极枢纽的考验
  ///
  /// In en, this message translates to:
  /// **'The test of the ultimate hub'**
  String get ch06Sub;

  /// 第 7 章标题（含章序号）：第七章 · 机关极限
  ///
  /// In en, this message translates to:
  /// **'Chapter 7 · Mechanism Limit'**
  String get ch07Title;

  /// 第 7 章短名（生成关卡名用）：机关极限
  ///
  /// In en, this message translates to:
  /// **'Mechanism Limit'**
  String get ch07Name;

  /// 第 7 章副标题：限步传送，大师关卡
  ///
  /// In en, this message translates to:
  /// **'Limited moves and portals — master ranks'**
  String get ch07Sub;

  /// 第 8 章标题（含章序号）：第八章 · 地下铁网
  ///
  /// In en, this message translates to:
  /// **'Chapter 8 · Underground Grid'**
  String get ch08Title;

  /// 第 8 章短名（生成关卡名用）：地下铁网
  ///
  /// In en, this message translates to:
  /// **'Underground Grid'**
  String get ch08Name;

  /// 第 8 章副标题：城市地下的第一条线
  ///
  /// In en, this message translates to:
  /// **'The first line beneath the streets'**
  String get ch08Sub;

  /// 第 9 章标题（含章序号）：第九章 · 磁浮干线
  ///
  /// In en, this message translates to:
  /// **'Chapter 9 · Maglev Mainline'**
  String get ch09Title;

  /// 第 9 章短名（生成关卡名用）：磁浮干线
  ///
  /// In en, this message translates to:
  /// **'Maglev Mainline'**
  String get ch09Name;

  /// 第 9 章副标题：离地一厘米的极速
  ///
  /// In en, this message translates to:
  /// **'Full speed, one centimetre above ground'**
  String get ch09Sub;

  /// 第 10 章标题（含章序号）：第十章 · 轨道遗产
  ///
  /// In en, this message translates to:
  /// **'Chapter 10 · Rail Legacy'**
  String get ch10Title;

  /// 第 10 章短名（生成关卡名用）：轨道遗产
  ///
  /// In en, this message translates to:
  /// **'Rail Legacy'**
  String get ch10Name;

  /// 第 10 章副标题：蒸汽与超回路的交响
  ///
  /// In en, this message translates to:
  /// **'Steam meets hyperloop'**
  String get ch10Sub;

  /// 第 11 章标题（含章序号）：第十一章 · 港区水道
  ///
  /// In en, this message translates to:
  /// **'Chapter 11 · Harbour Waters'**
  String get ch11Title;

  /// 第 11 章短名（生成关卡名用）：港区水道
  ///
  /// In en, this message translates to:
  /// **'Harbour Waters'**
  String get ch11Name;

  /// 第 11 章副标题：从铁轨转向水面
  ///
  /// In en, this message translates to:
  /// **'Off the rails, onto the water'**
  String get ch11Sub;

  /// 第 12 章标题（含章序号）：第十二章 · 近海航线
  ///
  /// In en, this message translates to:
  /// **'Chapter 12 · Coastal Routes'**
  String get ch12Title;

  /// 第 12 章短名（生成关卡名用）：近海航线
  ///
  /// In en, this message translates to:
  /// **'Coastal Routes'**
  String get ch12Name;

  /// 第 12 章副标题：风帆与快艇的时代
  ///
  /// In en, this message translates to:
  /// **'The age of sails and speedboats'**
  String get ch12Sub;

  /// 第 13 章标题（含章序号）：第十三章 · 远洋舰队
  ///
  /// In en, this message translates to:
  /// **'Chapter 13 · Ocean Fleet'**
  String get ch13Title;

  /// 第 13 章短名（生成关卡名用）：远洋舰队
  ///
  /// In en, this message translates to:
  /// **'Ocean Fleet'**
  String get ch13Name;

  /// 第 13 章副标题：巨轮与航母的泊位
  ///
  /// In en, this message translates to:
  /// **'Berths for giants and carriers'**
  String get ch13Sub;

  /// 第 14 章标题（含章序号）：第十四章 · 低空航线
  ///
  /// In en, this message translates to:
  /// **'Chapter 14 · Low Altitude'**
  String get ch14Title;

  /// 第 14 章短名（生成关卡名用）：低空航线
  ///
  /// In en, this message translates to:
  /// **'Low Altitude'**
  String get ch14Name;

  /// 第 14 章副标题：离开地面，扶摇直上
  ///
  /// In en, this message translates to:
  /// **'Off the ground and climbing'**
  String get ch14Sub;

  /// 第 15 章标题（含章序号）：第十五章 · 云端航道
  ///
  /// In en, this message translates to:
  /// **'Chapter 15 · Cloud Lanes'**
  String get ch15Title;

  /// 第 15 章短名（生成关卡名用）：云端航道
  ///
  /// In en, this message translates to:
  /// **'Cloud Lanes'**
  String get ch15Name;

  /// 第 15 章副标题：客机巡航的高度
  ///
  /// In en, this message translates to:
  /// **'Cruising altitude for airliners'**
  String get ch15Sub;

  /// 第 16 章标题（含章序号）：第十六章 · 高空领域
  ///
  /// In en, this message translates to:
  /// **'Chapter 16 · Upper Airspace'**
  String get ch16Title;

  /// 第 16 章短名（生成关卡名用）：高空领域
  ///
  /// In en, this message translates to:
  /// **'Upper Airspace'**
  String get ch16Name;

  /// 第 16 章副标题：战斗机与运输机
  ///
  /// In en, this message translates to:
  /// **'Fighters and heavy haulers'**
  String get ch16Sub;

  /// 第 17 章标题（含章序号）：第十七章 · 临近空间
  ///
  /// In en, this message translates to:
  /// **'Chapter 17 · Near Space'**
  String get ch17Title;

  /// 第 17 章短名（生成关卡名用）：临近空间
  ///
  /// In en, this message translates to:
  /// **'Near Space'**
  String get ch17Name;

  /// 第 17 章副标题：大气层的边缘
  ///
  /// In en, this message translates to:
  /// **'The edge of the atmosphere'**
  String get ch17Sub;

  /// 第 18 章标题（含章序号）：第十八章 · 航天港
  ///
  /// In en, this message translates to:
  /// **'Chapter 18 · Spaceport'**
  String get ch18Title;

  /// 第 18 章短名（生成关卡名用）：航天港
  ///
  /// In en, this message translates to:
  /// **'Spaceport'**
  String get ch18Name;

  /// 第 18 章副标题：火箭与航天飞机
  ///
  /// In en, this message translates to:
  /// **'Rockets and space shuttles'**
  String get ch18Sub;

  /// 第 19 章标题（含章序号）：第十九章 · 轨道空间站
  ///
  /// In en, this message translates to:
  /// **'Chapter 19 · Orbital Station'**
  String get ch19Title;

  /// 第 19 章短名（生成关卡名用）：轨道空间站
  ///
  /// In en, this message translates to:
  /// **'Orbital Station'**
  String get ch19Name;

  /// 第 19 章副标题：在轨道上组装
  ///
  /// In en, this message translates to:
  /// **'Assembled in orbit'**
  String get ch19Sub;

  /// 第 20 章标题（含章序号）：第二十章 · 月球基地
  ///
  /// In en, this message translates to:
  /// **'Chapter 20 · Lunar Base'**
  String get ch20Title;

  /// 第 20 章短名（生成关卡名用）：月球基地
  ///
  /// In en, this message translates to:
  /// **'Lunar Base'**
  String get ch20Name;

  /// 第 20 章副标题：静海的第一辆车
  ///
  /// In en, this message translates to:
  /// **'The first car in the Sea of Tranquility'**
  String get ch20Sub;

  /// 第 21 章标题（含章序号）：第二十一章 · 曲速纪元
  ///
  /// In en, this message translates to:
  /// **'Chapter 21 · Warp Era'**
  String get ch21Title;

  /// 第 21 章短名（生成关卡名用）：曲速纪元
  ///
  /// In en, this message translates to:
  /// **'Warp Era'**
  String get ch21Name;

  /// 第 21 章副标题：跨越光速的最后一跃
  ///
  /// In en, this message translates to:
  /// **'The last leap past light speed'**
  String get ch21Sub;

  /// 招牌 Boss 绰号（第 1 章尖峰战）：碎石王
  ///
  /// In en, this message translates to:
  /// **'Rubble King'**
  String get bossEp01;

  /// 招牌 Boss 绰号（第 2 章尖峰战）：回收站
  ///
  /// In en, this message translates to:
  /// **'The Scrapyard'**
  String get bossEp02;

  /// 招牌 Boss 绰号（第 3 章尖峰战）：退化射线
  ///
  /// In en, this message translates to:
  /// **'Degrade Ray'**
  String get bossEp03;

  /// 招牌 Boss 绰号（第 4 章尖峰战）：双重冻气
  ///
  /// In en, this message translates to:
  /// **'Double Freeze'**
  String get bossEp04;

  /// 招牌 Boss 绰号（第 5 章尖峰战）：毒池
  ///
  /// In en, this message translates to:
  /// **'Toxic Pool'**
  String get bossEp05;

  /// 招牌 Boss 绰号（第 6 章尖峰战）：拆迁队
  ///
  /// In en, this message translates to:
  /// **'Demolition Crew'**
  String get bossEp06;

  /// 招牌 Boss 绰号（第 7 章尖峰战）：霜寒之心
  ///
  /// In en, this message translates to:
  /// **'Frostheart'**
  String get bossEp07;

  /// 招牌 Boss 绰号（第 8 章尖峰战）：银行家
  ///
  /// In en, this message translates to:
  /// **'The Banker'**
  String get bossEp08;

  /// 招牌 Boss 绰号（第 9 章尖峰战）：崩落巨兽
  ///
  /// In en, this message translates to:
  /// **'Collapse Beast'**
  String get bossEp09;

  /// 招牌 Boss 绰号（第 10 章尖峰战）：蚀变工场
  ///
  /// In en, this message translates to:
  /// **'Corrosion Works'**
  String get bossEp10;

  /// 招牌 Boss 绰号（第 11 章尖峰战）：终焉保险
  ///
  /// In en, this message translates to:
  /// **'Final Insurance'**
  String get bossEp11;

  /// 招牌 Boss 绰号（第 12 章尖峰战）：腐败漩涡
  ///
  /// In en, this message translates to:
  /// **'Rot Vortex'**
  String get bossEp12;

  /// 招牌 Boss 绰号（第 13 章尖峰战）：铁锈君王
  ///
  /// In en, this message translates to:
  /// **'Rust Monarch'**
  String get bossEp13;

  /// 招牌 Boss 绰号（第 14 章尖峰战）：终局车王
  ///
  /// In en, this message translates to:
  /// **'Final Car King'**
  String get bossEp14;

  /// Boss 关详情标题：普通（非招牌）Boss 的兜底名
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter} · Guardian {slot}'**
  String bossGuardian(int chapter, int slot);

  /// Boss 关详情副标题：这是本章第几个 Boss
  ///
  /// In en, this message translates to:
  /// **'Slot {slot} of this chapter'**
  String bossSlotOrder(int slot);

  /// 章内第 4 个 Boss 的身份标签
  ///
  /// In en, this message translates to:
  /// **'Signature boss'**
  String get signatureBoss;

  /// 只有章序号、没有章名的短标签（Boss 徽章墙用）
  ///
  /// In en, this message translates to:
  /// **'Chapter {n}'**
  String chapterOnly(int n);

  /// 成就分组名：进度
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get achGroupProgress;

  /// 成就分组名：章节
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get achGroupChapter;

  /// 成就分组名：Boss
  ///
  /// In en, this message translates to:
  /// **'Bosses'**
  String get achGroupBoss;

  /// 成就分组名：停车
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get achGroupParking;

  /// 成就分组名：图鉴
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get achGroupCollection;

  /// 成就分组名：技巧
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get achGroupSkill;

  /// 成就分组名：日常
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get achGroupLife;

  /// 成就「初出茅庐」的标题（id=first_win）
  ///
  /// In en, this message translates to:
  /// **'First Steps'**
  String get achFirstWinTitle;

  /// 成就「初出茅庐」的描述（id=first_win）
  ///
  /// In en, this message translates to:
  /// **'Clear level 1'**
  String get achFirstWinDesc;

  /// 成就「十关先锋」的标题（id=clear_10）
  ///
  /// In en, this message translates to:
  /// **'Ten Down'**
  String get achClear10Title;

  /// 成就「十关先锋」的描述（id=clear_10）
  ///
  /// In en, this message translates to:
  /// **'Clear 10 levels in total'**
  String get achClear10Desc;

  /// 成就「马路老手」的标题（id=clear_30）
  ///
  /// In en, this message translates to:
  /// **'Road Veteran'**
  String get achClear30Title;

  /// 成就「马路老手」的描述（id=clear_30）
  ///
  /// In en, this message translates to:
  /// **'Clear 30 levels in total'**
  String get achClear30Desc;

  /// 成就「城市通途」的标题（id=clear_100）
  ///
  /// In en, this message translates to:
  /// **'City Crosser'**
  String get achClear100Title;

  /// 成就「城市通途」的描述（id=clear_100）
  ///
  /// In en, this message translates to:
  /// **'Clear 100 levels in total'**
  String get achClear100Desc;

  /// 成就「干线贯通」的标题（id=clear_200）
  ///
  /// In en, this message translates to:
  /// **'Trunk Line Open'**
  String get achClear200Title;

  /// 成就「干线贯通」的描述（id=clear_200）
  ///
  /// In en, this message translates to:
  /// **'Clear 200 levels in total'**
  String get achClear200Desc;

  /// 成就「环城大师」的标题（id=clear_300）
  ///
  /// In en, this message translates to:
  /// **'Ring Master'**
  String get achClear300Title;

  /// 成就「环城大师」的描述（id=clear_300）
  ///
  /// In en, this message translates to:
  /// **'Clear 300 levels in total'**
  String get achClear300Desc;

  /// 成就「跨越星港」的标题（id=clear_500）
  ///
  /// In en, this message translates to:
  /// **'Past the Starport'**
  String get achClear500Title;

  /// 成就「跨越星港」的描述（id=clear_500）
  ///
  /// In en, this message translates to:
  /// **'Clear 500 levels in total'**
  String get achClear500Desc;

  /// 成就「初战告捷」的标题（id=boss_first）
  ///
  /// In en, this message translates to:
  /// **'First Blood'**
  String get achBossFirstTitle;

  /// 成就「初战告捷」的描述（id=boss_first）
  ///
  /// In en, this message translates to:
  /// **'Defeat a guardian Boss for the first time'**
  String get achBossFirstDesc;

  /// 成就「猎手入场」的标题（id=boss_5）
  ///
  /// In en, this message translates to:
  /// **'Hunter\'s Entry'**
  String get achBoss5Title;

  /// 成就「猎手入场」的描述（id=boss_5）
  ///
  /// In en, this message translates to:
  /// **'Defeat 5 Bosses'**
  String get achBoss5Desc;

  /// 成就「守关者克星」的标题（id=boss_15）
  ///
  /// In en, this message translates to:
  /// **'Guardian Bane'**
  String get achBoss15Title;

  /// 成就「守关者克星」的描述（id=boss_15）
  ///
  /// In en, this message translates to:
  /// **'Defeat 15 Bosses'**
  String get achBoss15Desc;

  /// 成就「Boss 收割机」的标题（id=boss_30）
  ///
  /// In en, this message translates to:
  /// **'Boss Harvester'**
  String get achBoss30Title;

  /// 成就「Boss 收割机」的描述（id=boss_30）
  ///
  /// In en, this message translates to:
  /// **'Defeat 30 Bosses'**
  String get achBoss30Desc;

  /// 成就「初停牛刀」的标题（id=park_first）
  ///
  /// In en, this message translates to:
  /// **'First Park'**
  String get achParkFirstTitle;

  /// 成就「初停牛刀」的描述（id=park_first）
  ///
  /// In en, this message translates to:
  /// **'Clear your first parking level'**
  String get achParkFirstDesc;

  /// 成就「泊车新手」的标题（id=park_clear_5）
  ///
  /// In en, this message translates to:
  /// **'Parking Rookie'**
  String get achParkClear5Title;

  /// 成就「泊车新手」的描述（id=park_clear_5）
  ///
  /// In en, this message translates to:
  /// **'Clear 5 parking levels'**
  String get achParkClear5Desc;

  /// 成就「停车达人」的标题（id=park_clear_10）
  ///
  /// In en, this message translates to:
  /// **'Parking Pro'**
  String get achParkClear10Title;

  /// 成就「停车达人」的描述（id=park_clear_10）
  ///
  /// In en, this message translates to:
  /// **'Clear 10 parking levels'**
  String get achParkClear10Desc;

  /// 成就「车位老手」的标题（id=park_clear_100）
  ///
  /// In en, this message translates to:
  /// **'Bay Veteran'**
  String get achParkClear100Title;

  /// 成就「车位老手」的描述（id=park_clear_100）
  ///
  /// In en, this message translates to:
  /// **'Clear 100 parking levels'**
  String get achParkClear100Desc;

  /// 成就「泊车大师」的标题（id=park_master）
  ///
  /// In en, this message translates to:
  /// **'Parking Master'**
  String get achParkMasterTitle;

  /// 成就「泊车大师」的描述（id=park_master）
  ///
  /// In en, this message translates to:
  /// **'Unlock parking level 20'**
  String get achParkMasterDesc;

  /// 成就「完美泊车」的标题（id=park_star_3）
  ///
  /// In en, this message translates to:
  /// **'Perfect Park'**
  String get achParkStar3Title;

  /// 成就「完美泊车」的描述（id=park_star_3）
  ///
  /// In en, this message translates to:
  /// **'Get 3 stars on any parking level'**
  String get achParkStar3Desc;

  /// 成就「三星泊车手」的标题（id=park_star5）
  ///
  /// In en, this message translates to:
  /// **'Triple-Star Parker'**
  String get achParkStar5Title;

  /// 成就「三星泊车手」的描述（id=park_star5）
  ///
  /// In en, this message translates to:
  /// **'Get 3 stars on 5 parking levels'**
  String get achParkStar5Desc;

  /// 成就「车位精度控」的标题（id=park_star50）
  ///
  /// In en, this message translates to:
  /// **'Bay Precision'**
  String get achParkStar50Title;

  /// 成就「车位精度控」的描述（id=park_star50）
  ///
  /// In en, this message translates to:
  /// **'Get 3 stars on 50 parking levels'**
  String get achParkStar50Desc;

  /// 成就「前五章清场」的标题（id=park_chapters_5）
  ///
  /// In en, this message translates to:
  /// **'First Five Chapters'**
  String get achParkChapters5Title;

  /// 成就「前五章清场」的描述（id=park_chapters_5）
  ///
  /// In en, this message translates to:
  /// **'Clear parking chapters 1-5 (levels 1-180)'**
  String get achParkChapters5Desc;

  /// 成就「终极泊车王」的标题（id=park_clear_all）
  ///
  /// In en, this message translates to:
  /// **'Ultimate Parker'**
  String get achParkClearAllTitle;

  /// 成就「终极泊车王」的描述（id=park_clear_all）
  ///
  /// In en, this message translates to:
  /// **'Clear all 800 parking levels'**
  String get achParkClearAllDesc;

  /// 成就「铁轨轰鸣」的标题（id=train_1）
  ///
  /// In en, this message translates to:
  /// **'Rails Roaring'**
  String get achTrain1Title;

  /// 成就「铁轨轰鸣」的描述（id=train_1）
  ///
  /// In en, this message translates to:
  /// **'Merge your first high-speed train'**
  String get achTrain1Desc;

  /// 成就「冲向云霄」的标题（id=plane_1）
  ///
  /// In en, this message translates to:
  /// **'Into the Clouds'**
  String get achPlane1Title;

  /// 成就「冲向云霄」的描述（id=plane_1）
  ///
  /// In en, this message translates to:
  /// **'Merge your first airliner'**
  String get achPlane1Desc;

  /// 成就「彗星追迹者」的标题（id=comet_1）
  ///
  /// In en, this message translates to:
  /// **'Comet Chaser'**
  String get achComet1Title;

  /// 成就「彗星追迹者」的描述（id=comet_1）
  ///
  /// In en, this message translates to:
  /// **'Merge a starship'**
  String get achComet1Desc;

  /// 成就「终极造物」的标题（id=void_1）
  ///
  /// In en, this message translates to:
  /// **'Ultimate Creation'**
  String get achVoid1Title;

  /// 成就「终极造物」的描述（id=void_1）
  ///
  /// In en, this message translates to:
  /// **'Merge the top-tier warp ship'**
  String get achVoid1Desc;

  /// 成就「连消起步」的标题（id=combo_5）
  ///
  /// In en, this message translates to:
  /// **'Combo Start'**
  String get achCombo5Title;

  /// 成就「连消起步」的描述（id=combo_5）
  ///
  /// In en, this message translates to:
  /// **'Reach a 5-merge combo in one run'**
  String get achCombo5Desc;

  /// 成就「连锁反应」的标题（id=combo_10）
  ///
  /// In en, this message translates to:
  /// **'Chain Reaction'**
  String get achCombo10Title;

  /// 成就「连锁反应」的描述（id=combo_10）
  ///
  /// In en, this message translates to:
  /// **'Reach a 10-merge combo in one run'**
  String get achCombo10Desc;

  /// 成就「连消之神」的标题（id=combo_15）
  ///
  /// In en, this message translates to:
  /// **'Combo Deity'**
  String get achCombo15Title;

  /// 成就「连消之神」的描述（id=combo_15）
  ///
  /// In en, this message translates to:
  /// **'Reach a 15-merge combo in one run'**
  String get achCombo15Desc;

  /// 成就「星级收藏家」的标题（id=stars_30）
  ///
  /// In en, this message translates to:
  /// **'Star Collector'**
  String get achStars30Title;

  /// 成就「星级收藏家」的描述（id=stars_30）
  ///
  /// In en, this message translates to:
  /// **'Earn 30 stars in total'**
  String get achStars30Desc;

  /// 成就「三星猎手」的标题（id=stars_300）
  ///
  /// In en, this message translates to:
  /// **'Star Hunter'**
  String get achStars300Title;

  /// 成就「三星猎手」的描述（id=stars_300）
  ///
  /// In en, this message translates to:
  /// **'Earn 300 stars in total'**
  String get achStars300Desc;

  /// 成就「满星征途」的标题（id=stars_1000）
  ///
  /// In en, this message translates to:
  /// **'Star Marathon'**
  String get achStars1000Title;

  /// 成就「满星征途」的描述（id=stars_1000）
  ///
  /// In en, this message translates to:
  /// **'Earn 1000 stars in total'**
  String get achStars1000Desc;

  /// 成就「小有积蓄」的标题（id=coins_500）
  ///
  /// In en, this message translates to:
  /// **'Some Savings'**
  String get achCoins500Title;

  /// 成就「小有积蓄」的描述（id=coins_500）
  ///
  /// In en, this message translates to:
  /// **'Hold 500 coins'**
  String get achCoins500Desc;

  /// 成就「家财万贯」的标题（id=coins_2000）
  ///
  /// In en, this message translates to:
  /// **'Well Off'**
  String get achCoins2000Title;

  /// 成就「家财万贯」的描述（id=coins_2000）
  ///
  /// In en, this message translates to:
  /// **'Hold 2000 coins'**
  String get achCoins2000Desc;

  /// 成就「车库财主」的标题（id=coins_5000）
  ///
  /// In en, this message translates to:
  /// **'Garage Tycoon'**
  String get achCoins5000Title;

  /// 成就「车库财主」的描述（id=coins_5000）
  ///
  /// In en, this message translates to:
  /// **'Hold 5000 coins'**
  String get achCoins5000Desc;

  /// 成就「七日签到」的标题（id=signin_7）
  ///
  /// In en, this message translates to:
  /// **'Seven Days In'**
  String get achSignin7Title;

  /// 成就「七日签到」的描述（id=signin_7）
  ///
  /// In en, this message translates to:
  /// **'Check in 7 days in total'**
  String get achSignin7Desc;

  /// 成就「月度全勤」的标题（id=signin_30）
  ///
  /// In en, this message translates to:
  /// **'Full Month'**
  String get achSignin30Title;

  /// 成就「月度全勤」的描述（id=signin_30）
  ///
  /// In en, this message translates to:
  /// **'Check in 30 days in total'**
  String get achSignin30Desc;

  /// 成就「铁杆签到党」的标题（id=signin_streak_7）
  ///
  /// In en, this message translates to:
  /// **'Streak Regular'**
  String get achSigninStreak7Title;

  /// 成就「铁杆签到党」的描述（id=signin_streak_7）
  ///
  /// In en, this message translates to:
  /// **'Check in 7 days in a row'**
  String get achSigninStreak7Desc;

  /// 成就「今日挑战」的标题（id=daily_first）
  ///
  /// In en, this message translates to:
  /// **'Daily Debut'**
  String get achDailyFirstTitle;

  /// 成就「今日挑战」的描述（id=daily_first）
  ///
  /// In en, this message translates to:
  /// **'Finish a daily challenge'**
  String get achDailyFirstDesc;

  /// 成就「每日全勤」的标题（id=daily_streak_7）
  ///
  /// In en, this message translates to:
  /// **'Daily Devotion'**
  String get achDailyStreak7Title;

  /// 成就「每日全勤」的描述（id=daily_streak_7）
  ///
  /// In en, this message translates to:
  /// **'Clear 7 daily challenges in a row'**
  String get achDailyStreak7Desc;

  /// 成就「永动引擎」的标题（id=endless_1000）
  ///
  /// In en, this message translates to:
  /// **'Perpetual Engine'**
  String get achEndless1000Title;

  /// 成就「永动引擎」的描述（id=endless_1000）
  ///
  /// In en, this message translates to:
  /// **'Score 1000 in Endless'**
  String get achEndless1000Desc;

  /// 成就「永动机」的标题（id=endless_3000）
  ///
  /// In en, this message translates to:
  /// **'Perpetual Motion'**
  String get achEndless3000Title;

  /// 成就「永动机」的描述（id=endless_3000）
  ///
  /// In en, this message translates to:
  /// **'Score 3000 in Endless'**
  String get achEndless3000Desc;

  /// 成就「都市传奇」的标题（id=clear_all）
  ///
  /// In en, this message translates to:
  /// **'Urban Legend'**
  String get achClearAllTitle;

  /// 成就「都市传奇」的描述（id=clear_all）
  ///
  /// In en, this message translates to:
  /// **'Clear all {count} levels'**
  String achClearAllDesc(int count);

  /// 成就「一章节全清」的标题（id=boss_sweep）
  ///
  /// In en, this message translates to:
  /// **'Clean Sweep'**
  String get achBossSweepTitle;

  /// 成就「一章节全清」的描述（id=boss_sweep）
  ///
  /// In en, this message translates to:
  /// **'Clear all {count} Bosses of any chapter'**
  String achBossSweepDesc(int count);

  /// 成就「徽章墙圆满」的标题（id=boss_all）
  ///
  /// In en, this message translates to:
  /// **'Full Badge Wall'**
  String get achBossAllTitle;

  /// 成就「徽章墙圆满」的描述（id=boss_all）
  ///
  /// In en, this message translates to:
  /// **'Defeat all {count} Bosses'**
  String achBossAllDesc(int count);

  /// 成就「小有收藏」的标题（id=collection_25）
  ///
  /// In en, this message translates to:
  /// **'Small Collection'**
  String get achCollection25Title;

  /// 成就「小有收藏」的描述（id=collection_25）
  ///
  /// In en, this message translates to:
  /// **'Unlock {count} vehicle types'**
  String achCollection25Desc(int count);

  /// 成就「终极收藏家」的标题（id=collection_all）
  ///
  /// In en, this message translates to:
  /// **'Ultimate Collector'**
  String get achCollectionAllTitle;

  /// 成就「终极收藏家」的描述（id=collection_all）
  ///
  /// In en, this message translates to:
  /// **'Unlock all {count} vehicle types'**
  String achCollectionAllDesc(int count);

  /// 最后一章的章节成就标题
  ///
  /// In en, this message translates to:
  /// **'Finale · {name}'**
  String achFinalChapter(String name);

  /// 章节成就描述
  ///
  /// In en, this message translates to:
  /// **'Clear {chapter} (levels {start}-{end})'**
  String achChapterDesc(String chapter, int start, int end);

  /// 车系全收成就标题，cat = 车系名（陆地/重工/…）
  ///
  /// In en, this message translates to:
  /// **'{cat} Collector'**
  String achFamilyTitle(String cat);

  /// 车系全收成就描述
  ///
  /// In en, this message translates to:
  /// **'Unlock all {count} {cat} vehicles'**
  String achFamilyDesc(String cat, int count);

  /// 领取成功后弹出的标题
  ///
  /// In en, this message translates to:
  /// **'🏆 Achievement unlocked! +{reward} 🪙'**
  String achToastTitle(int reward);

  /// 领取成功后弹出的正文，title = 成就名
  ///
  /// In en, this message translates to:
  /// **'“{title}” is in the bag — keep collecting!'**
  String achToastMessage(String title);

  /// 成就页标题
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achScreenTitle;

  /// 成就页副标题
  ///
  /// In en, this message translates to:
  /// **'Small medals along the way'**
  String get achScreenSubtitle;

  /// 筛选后没有条目时的空态
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet — go clear a few levels'**
  String get achEmptyFilter;

  /// 分组小标题，group = 分组名，count = 该组总数
  ///
  /// In en, this message translates to:
  /// **'{group} · {count} medals'**
  String achGroupHeader(String group, int count);

  /// 分组小标题的第二行进度
  ///
  /// In en, this message translates to:
  /// **'Claimed {done}/{total}'**
  String achGroupClaimed(int done, int total);

  /// 筛选 chip：全部
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get achFilterAll;

  /// 筛选 chip：未达成
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get achFilterActive;

  /// 筛选 chip：已达成本可领取
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get achFilterClaimable;

  /// 筛选 chip：已领取
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get achFilterDone;

  /// 顶部进度条后缀，前面已经有一个数字
  ///
  /// In en, this message translates to:
  /// **'/{total} medals'**
  String achMedalsSuffix(int total);

  /// 顶部进度条旁的小字
  ///
  /// In en, this message translates to:
  /// **'{count} achieved'**
  String achAchieved(int count);

  /// 条目上的领取提示 chip
  ///
  /// In en, this message translates to:
  /// **'Ready +{reward} 🪙'**
  String achClaimCta(int reward);

  /// 条目右侧的已领取标记
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get achClaimedChip;

  /// 条目右侧的领取按钮
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get achClaimBtn;

  /// 无尽模式达标时棋盘中央的飘字
  ///
  /// In en, this message translates to:
  /// **'🎯 Goal up! Next tier {icon} {name}'**
  String endlessGoalFloat(String icon, String name);

  /// 无尽模式达标时底部提示
  ///
  /// In en, this message translates to:
  /// **'Goal reached! Now aiming for {icon} {name}'**
  String endlessGoalHint(String icon, String name);

  /// Boss 锁牌结束后恢复
  ///
  /// In en, this message translates to:
  /// **'🔓 Deck unlocked'**
  String get hintStockUnlocked;

  /// 胶水到期
  ///
  /// In en, this message translates to:
  /// **'🍯 Glue dried — cars can move again!'**
  String get hintGlueDry;

  /// 黑洞到期
  ///
  /// In en, this message translates to:
  /// **'🌀 The black hole closed — that cell is usable!'**
  String get hintHoleClosed;

  /// 禁合到期
  ///
  /// In en, this message translates to:
  /// **'🚫 Merge ban lifted — back to normal!'**
  String get hintBanLifted;

  /// Boss 开盾
  ///
  /// In en, this message translates to:
  /// **'🛡 Boss raised a shield — hold your merges and build up!'**
  String get hintShieldUp;

  /// Boss 盾消失
  ///
  /// In en, this message translates to:
  /// **'🛡 Shield down — full attack!'**
  String get hintShieldDown;

  /// 清盘关提前清空棋盘
  ///
  /// In en, this message translates to:
  /// **'✨ Board cleared! {left} cards left in the deck — keep drawing, finish with ≤{limit} groups'**
  String hintBoardClearedDeckLeft(int left, int limit);

  /// 限步关判负
  ///
  /// In en, this message translates to:
  /// **'⏹ Out of moves!'**
  String get hintMovesOut;

  /// 限时关判负
  ///
  /// In en, this message translates to:
  /// **'⏰ Time\'s up!'**
  String get hintTimeUp;

  /// 冰封死局：安全阀在融冰
  ///
  /// In en, this message translates to:
  /// **'☃️ No moves left… ice is thinning ({layers} layers left)'**
  String hintIceThinning(int layers);

  /// 冰封死局的冰已全融
  ///
  /// In en, this message translates to:
  /// **'☀️ All ice melted!'**
  String get hintIceMeltedAll;

  /// 冰块死局：安全阀在融冰
  ///
  /// In en, this message translates to:
  /// **'🧊 Board frozen… ice is cracking ({layers} layers left)'**
  String hintIceCracking(int layers);

  /// 冰块死局的冰已全融
  ///
  /// In en, this message translates to:
  /// **'💧 All ice gone!'**
  String get hintIceBrokenAll;

  /// 胶水死局等待
  ///
  /// In en, this message translates to:
  /// **'🍯 No moves left… glue dries in {seconds}s, hang on'**
  String hintGlueWaiting(int seconds);

  /// Boss 锁牌时的点击反馈
  ///
  /// In en, this message translates to:
  /// **'🔒 Boss locked the deck — hang on!'**
  String get hintBossLockedStock;

  /// 棋盘满时点牌堆
  ///
  /// In en, this message translates to:
  /// **'Board\'s full — merge something to free a slot'**
  String get hintBoardFull;

  /// 落子被黑洞挡住
  ///
  /// In en, this message translates to:
  /// **'🌀 A black hole is in the way — feed it a card or wait for it to close'**
  String get hintHoleBlocking;

  /// 棋盘满时自动清掉最低档车
  ///
  /// In en, this message translates to:
  /// **'Auto-cleared a {icon} {name} to free a slot'**
  String hintAutoCleared(String icon, String name);

  /// 护盾挡伤的飘字
  ///
  /// In en, this message translates to:
  /// **'🛡 Blocked'**
  String get floatBlocked;

  /// 护盾期间命中
  ///
  /// In en, this message translates to:
  /// **'🛡 The shield blocked that hit — attack once it drops!'**
  String get hintShieldBlocked;

  /// Boss 残血狂怒
  ///
  /// In en, this message translates to:
  /// **'👑 The Boss enraged! Attacks are faster!'**
  String get hintBossEnraged;

  /// Boss 血条打空
  ///
  /// In en, this message translates to:
  /// **'👑 The Boss is down!'**
  String get hintBossDown;

  /// 冰封技能命中 2 张以上
  ///
  /// In en, this message translates to:
  /// **'🧊 The Boss froze {count} ingredient cars — merge next to them to free them!'**
  String hintBossFrozeMany(int count);

  /// 冰封技能命中 1 张
  ///
  /// In en, this message translates to:
  /// **'🧊 The Boss froze your ingredient car — merge next to it to free it!'**
  String get hintBossFrozeOne;

  /// 拖车技能
  ///
  /// In en, this message translates to:
  /// **'😈 The Boss towed away your {icon} {name}!'**
  String hintBossStole(String icon, String name);

  /// 锁牌技能
  ///
  /// In en, this message translates to:
  /// **'🔒 The Boss locked the deck for {seconds}s!'**
  String hintBossLockSeconds(int seconds);

  /// 落冰技能
  ///
  /// In en, this message translates to:
  /// **'🧊 The Boss dropped an ice block and took a cell!'**
  String get hintBossIceDrop;

  /// 扣押技能
  ///
  /// In en, this message translates to:
  /// **'🚗 The Boss impounded your {icon} {name} — back in {seconds}s!'**
  String hintBossImpound(String icon, String name, int seconds);

  /// 扣押到期放回
  ///
  /// In en, this message translates to:
  /// **'✨ Your impounded {icon} is back!'**
  String hintImpoundReturn(String icon);

  /// 拆除技能
  ///
  /// In en, this message translates to:
  /// **'💥 The Boss tore down your {icon} {name}!'**
  String hintBossDemolished(String icon, String name);

  /// 退化技能
  ///
  /// In en, this message translates to:
  /// **'📉 Degrade ray: {fromIcon} {fromName} → {toIcon} {toName}!'**
  String hintBossDevolve(
    String fromIcon,
    String fromName,
    String toIcon,
    String toName,
  );

  /// 污染技能
  ///
  /// In en, this message translates to:
  /// **'☠️ The Boss poisoned the deck! The next {count} cards drop a tier!'**
  String hintBossTaint(int count);

  /// 胶水技能
  ///
  /// In en, this message translates to:
  /// **'🍯 The Boss splashed glue: {icon} {name} stuck for {seconds}s!'**
  String hintBossGlue(String icon, String name, int seconds);

  /// 黑洞技能
  ///
  /// In en, this message translates to:
  /// **'🌀 The Boss tore open a black hole! Avoid the cell — or feed it junk'**
  String get hintBossHole;

  /// 洗牌技能被冻住化解
  ///
  /// In en, this message translates to:
  /// **'🌀 The Boss wanted to shuffle, but your cars are all frozen/stuck — nothing to shuffle!'**
  String get hintBossShuffleBlocked;

  /// 洗牌技能
  ///
  /// In en, this message translates to:
  /// **'🌀 The Boss shuffled! {count} cars scrambled — find new matches!'**
  String hintBossShuffle(int count);

  /// 禁合技能
  ///
  /// In en, this message translates to:
  /// **'🚫 Merge ban: {icon} {name} can\'t merge for {seconds}s — merge something else!'**
  String hintBossBan(String icon, String name, int seconds);

  /// 抢目标技能
  ///
  /// In en, this message translates to:
  /// **'🏆 The Boss stole a target car and healed 1 HP!'**
  String get hintBossStoleTarget;

  /// 迷雾技能多张
  ///
  /// In en, this message translates to:
  /// **'🌫 The Boss dropped fog over {count} cars!'**
  String hintBossFogMany(int count);

  /// 迷雾技能单张
  ///
  /// In en, this message translates to:
  /// **'🌫 The Boss dropped fog over a car!'**
  String get hintBossFogOne;

  /// 锤子点错地方
  ///
  /// In en, this message translates to:
  /// **'No chains here — tap the cells marked 🔒'**
  String get hintNoChainHere;

  /// 锤子清掉锁链
  ///
  /// In en, this message translates to:
  /// **'🔓 Chain cleared'**
  String get hintChainCleared;

  /// 洗牌后仍死局
  ///
  /// In en, this message translates to:
  /// **'😵 Still stuck after the reshuffle — try a different plan'**
  String get hintReshuffleStuck;

  /// 洗牌成功
  ///
  /// In en, this message translates to:
  /// **'🔀 Board reshuffled — look for new matches!'**
  String get hintReshuffled;

  /// 看广告续命（限时）
  ///
  /// In en, this message translates to:
  /// **'▶️ Back in! +30s — go!'**
  String get hintReviveTime;

  /// 看广告续命（限步）
  ///
  /// In en, this message translates to:
  /// **'▶️ Back in! +10 moves — go!'**
  String get hintReviveMoves;

  /// 看广告续命（死局）
  ///
  /// In en, this message translates to:
  /// **'▶️ Back in! +2 cards and a reshuffle'**
  String get hintReviveCards;

  /// 看广告续命（无尽死局）
  ///
  /// In en, this message translates to:
  /// **'▶️ Back in! Cleared 3 groups — keep climbing!'**
  String get hintReviveClear;

  /// 死局提示（牌堆空）
  ///
  /// In en, this message translates to:
  /// **'😅 Nothing to merge — try Shuffle or Add cards'**
  String get hintNothingToMergeNoDeck;

  /// 死局提示（牌堆还有）
  ///
  /// In en, this message translates to:
  /// **'😅 Nothing to merge — tap the deck for a new card'**
  String get hintNothingToMergeDeck;

  /// 提示：两张同档车
  ///
  /// In en, this message translates to:
  /// **'💡 Drag {fromIcon} onto {toIcon} to merge!'**
  String hintDragTiers(String fromIcon, String toIcon);

  /// 提示：万能卡
  ///
  /// In en, this message translates to:
  /// **'💡 Drag {icon} onto the wildcard!'**
  String hintDragWildcard(String icon);

  /// 提示：炸弹
  ///
  /// In en, this message translates to:
  /// **'💡 Drag the bombs together — 3 makes it blow!'**
  String get hintDragBombs;

  /// 提示：通用兜底
  ///
  /// In en, this message translates to:
  /// **'💡 Drag this card onto that one!'**
  String get hintDragGeneric;

  /// 禁合期间尝试合并
  ///
  /// In en, this message translates to:
  /// **'🚫 Banned: {icon} {name} can\'t merge yet ({seconds}s left)'**
  String hintBanned(String icon, String name, int seconds);

  /// 把车喂给黑洞
  ///
  /// In en, this message translates to:
  /// **'🌀 The black hole ate your {icon} {name}!'**
  String hintHoleAte(String icon, String name);

  /// 炸弹引爆飘字
  ///
  /// In en, this message translates to:
  /// **'💥 Boom +300'**
  String get floatDetonate;

  /// 冰块自然融化
  ///
  /// In en, this message translates to:
  /// **'❄ Ice melted — cell freed up'**
  String get hintIceMelted;

  /// 破冰能力飘字
  ///
  /// In en, this message translates to:
  /// **'🔥 Ice broken!'**
  String get floatBreakIce;

  /// 解锁能力飘字
  ///
  /// In en, this message translates to:
  /// **'🔓 Unlocked!'**
  String get floatUnlock;

  /// 清石能力飘字
  ///
  /// In en, this message translates to:
  /// **'💥 Rubble crushed!'**
  String get floatRubble;

  /// 飞越能力飘字
  ///
  /// In en, this message translates to:
  /// **'✈️ Flew over!'**
  String get floatFlyOver;

  /// 传送能力飘字
  ///
  /// In en, this message translates to:
  /// **'⚡ Teleported!'**
  String get floatTeleport;

  /// 曲速能力飘字
  ///
  /// In en, this message translates to:
  /// **'🌀 Warped!'**
  String get floatWarp;

  /// 侦察能力飘字
  ///
  /// In en, this message translates to:
  /// **'📡 Scouted!'**
  String get floatSonar;

  /// 连消飘字
  ///
  /// In en, this message translates to:
  /// **'🔥 Combo x{combo}'**
  String floatCombo(int combo);

  /// 塌方技能
  ///
  /// In en, this message translates to:
  /// **'🪨 The Boss caused a landslide — {count} rocks blocked cells!'**
  String floatBossLandslide(int count);

  /// 塌方技能单块
  ///
  /// In en, this message translates to:
  /// **'🪨 The Boss dropped a rock and took a cell!'**
  String get floatBossRubbleOne;

  /// 塌方被清场化解
  ///
  /// In en, this message translates to:
  /// **'🪨 The Boss swung a rock, but you moved everyone clear!'**
  String get hintBossRubbleDodged;

  /// 迷雾被规避
  ///
  /// In en, this message translates to:
  /// **'🌫 The Boss dropped fog, but you\'d already moved the cars!'**
  String get hintBossFogDodged;

  /// 清盘关合出目标车的飘字
  ///
  /// In en, this message translates to:
  /// **'+300 cell cleared!'**
  String get floatCellCleared;

  /// 目标达成时的飘字
  ///
  /// In en, this message translates to:
  /// **'+300 goal reached!'**
  String get floatGoalHit;

  /// 目标进度飘字
  ///
  /// In en, this message translates to:
  /// **'+300 target {done}/{total}'**
  String floatGoalProgress(int done, int total);

  /// 顶级车三合一升空
  ///
  /// In en, this message translates to:
  /// **'🚀 Top tier launched — cleared 3 piles!'**
  String get floatTopTierLaunch;

  /// 目标车交付飘字
  ///
  /// In en, this message translates to:
  /// **'🚀 {name} delivered'**
  String floatDelivered(String name);

  /// 顶级车升空飘字的兜底名（拿不到具体车型时）
  ///
  /// In en, this message translates to:
  /// **'top-tier car'**
  String get floatTopTierGeneric;

  /// 选关页标题
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get levelMapTitle;

  /// 选关页副标题
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} cleared · no rush, one at a time'**
  String levelMapSubtitle(int done, int total);

  /// 大阶段末章的徽标，subtitle = 章节副标题
  ///
  /// In en, this message translates to:
  /// **'👹 Demon chapter · {subtitle}'**
  String demonChapter(String subtitle);

  /// 总星星数标签
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get totalStars;

  /// 全部通关后的鼓励语
  ///
  /// In en, this message translates to:
  /// **'Every level is lit up — impressive!'**
  String get allLevelsUnlocked;

  /// 还差几关全部解锁
  ///
  /// In en, this message translates to:
  /// **'{count} more levels to light up'**
  String levelsLeftToUnlock(int count);

  /// 广告挑战关的角标（很短，卡面放不下长词）
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get adChallengeBadge;

  /// 关卡卡头的序号徽章
  ///
  /// In en, this message translates to:
  /// **'Lv {id}'**
  String levelNumberChip(int id);

  /// 关卡卡头的最高分
  ///
  /// In en, this message translates to:
  /// **'Best {score}'**
  String bestScoreInline(int score);

  /// 未通关的关卡卡头文案
  ///
  /// In en, this message translates to:
  /// **'Not played yet'**
  String get levelNotPlayed;

  /// 未解锁的关卡卡头文案
  ///
  /// In en, this message translates to:
  /// **'Clear earlier levels first'**
  String get levelLockedHint;

  /// 节奏相位：最轻的一档
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get phaseEasy;

  /// 节奏相位：轻度加压
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get phaseSmooth;

  /// 节奏相位：第一波峰
  ///
  /// In en, this message translates to:
  /// **'Think'**
  String get phaseThink;

  /// 节奏相位：波谷（仅停车）
  ///
  /// In en, this message translates to:
  /// **'Breather'**
  String get phaseBreather;

  /// 节奏相位：第二波峰
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get phaseHard;

  /// 节奏相位：全压力（仅停车）
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get phasePeak;

  /// 停车第 1 章标题（起始关 L1）
  ///
  /// In en, this message translates to:
  /// **'Bike Blocks'**
  String get park01Title;

  /// 停车第 1 章副标题（起始关 L1）
  ///
  /// In en, this message translates to:
  /// **'First ride — slow and steady'**
  String get park01Sub;

  /// 停车第 2 章标题（起始关 L37）
  ///
  /// In en, this message translates to:
  /// **'Back Alleys'**
  String get park02Title;

  /// 停车第 2 章副标题（起始关 L37）
  ///
  /// In en, this message translates to:
  /// **'Squeeze through the narrow lanes'**
  String get park02Sub;

  /// 停车第 3 章标题（起始关 L73）
  ///
  /// In en, this message translates to:
  /// **'Downtown'**
  String get park03Title;

  /// 停车第 3 章副标题（起始关 L73）
  ///
  /// In en, this message translates to:
  /// **'The city centre, where traffic thickens'**
  String get park03Sub;

  /// 停车第 4 章标题（起始关 L109）
  ///
  /// In en, this message translates to:
  /// **'Taxi Hotspot'**
  String get park04Title;

  /// 停车第 4 章副标题（起始关 L109）
  ///
  /// In en, this message translates to:
  /// **'Taxis waiting on every corner'**
  String get park04Sub;

  /// 停车第 5 章标题（起始关 L145）
  ///
  /// In en, this message translates to:
  /// **'Bus Terminal'**
  String get park05Title;

  /// 停车第 5 章副标题（起始关 L145）
  ///
  /// In en, this message translates to:
  /// **'Even the big rigs need a spot'**
  String get park05Sub;

  /// 停车第 6 章标题（起始关 L181）
  ///
  /// In en, this message translates to:
  /// **'Freight Line'**
  String get park06Title;

  /// 停车第 6 章副标题（起始关 L181）
  ///
  /// In en, this message translates to:
  /// **'The heavy-haul test'**
  String get park06Sub;

  /// 停车第 7 章标题（起始关 L217）
  ///
  /// In en, this message translates to:
  /// **'Rail Yard'**
  String get park07Title;

  /// 停车第 7 章副标题（起始关 L217）
  ///
  /// In en, this message translates to:
  /// **'The rhythm of a train pulling in'**
  String get park07Sub;

  /// 停车第 8 章标题（起始关 L253）
  ///
  /// In en, this message translates to:
  /// **'Launch Pad'**
  String get park08Title;

  /// 停车第 8 章副标题（起始关 L253）
  ///
  /// In en, this message translates to:
  /// **'The last park before the countdown'**
  String get park08Sub;

  /// 停车第 9 章标题（起始关 L289）
  ///
  /// In en, this message translates to:
  /// **'Ferry Pier'**
  String get park09Title;

  /// 停车第 9 章副标题（起始关 L289）
  ///
  /// In en, this message translates to:
  /// **'Ferries weaving along the pier'**
  String get park09Sub;

  /// 停车第 10 章标题（起始关 L325）
  ///
  /// In en, this message translates to:
  /// **'Metro Grid'**
  String get park10Title;

  /// 停车第 10 章副标题（起始关 L325）
  ///
  /// In en, this message translates to:
  /// **'Dispatch work underground'**
  String get park10Sub;

  /// 停车第 11 章标题（起始关 L361）
  ///
  /// In en, this message translates to:
  /// **'Airport Runway'**
  String get park11Title;

  /// 停车第 11 章副标题（起始关 L361）
  ///
  /// In en, this message translates to:
  /// **'Before the climb to the clouds'**
  String get park11Sub;

  /// 停车第 12 章标题（起始关 L397）
  ///
  /// In en, this message translates to:
  /// **'Air Base'**
  String get park12Title;

  /// 停车第 12 章副标题（起始关 L397）
  ///
  /// In en, this message translates to:
  /// **'Precision parking for fighters'**
  String get park12Sub;

  /// 停车第 13 章标题（起始关 L433）
  ///
  /// In en, this message translates to:
  /// **'Space Centre'**
  String get park13Title;

  /// 停车第 13 章副标题（起始关 L433）
  ///
  /// In en, this message translates to:
  /// **'The corridor to space'**
  String get park13Sub;

  /// 停车第 14 章标题（起始关 L469）
  ///
  /// In en, this message translates to:
  /// **'Starport Freight'**
  String get park14Title;

  /// 停车第 14 章副标题（起始关 L469）
  ///
  /// In en, this message translates to:
  /// **'Interstellar courier routes'**
  String get park14Sub;

  /// 停车第 15 章标题（起始关 L505）
  ///
  /// In en, this message translates to:
  /// **'Maglev Corridor'**
  String get park15Title;

  /// 停车第 15 章副标题（起始关 L505）
  ///
  /// In en, this message translates to:
  /// **'Where levitating trains dock'**
  String get park15Sub;

  /// 停车第 16 章标题（起始关 L542）
  ///
  /// In en, this message translates to:
  /// **'Orbital Station'**
  String get park16Title;

  /// 停车第 16 章副标题（起始关 L542）
  ///
  /// In en, this message translates to:
  /// **'Rendezvous in orbit'**
  String get park16Sub;

  /// 停车第 17 章标题（起始关 L579）
  ///
  /// In en, this message translates to:
  /// **'Comet Orbit'**
  String get park17Title;

  /// 停车第 17 章副标题（起始关 L579）
  ///
  /// In en, this message translates to:
  /// **'Chasing a comet tail'**
  String get park17Sub;

  /// 停车第 18 章标题（起始关 L616）
  ///
  /// In en, this message translates to:
  /// **'Sonic Tube'**
  String get park18Title;

  /// 停车第 18 章副标题（起始关 L616）
  ///
  /// In en, this message translates to:
  /// **'A thousand kilometres in a vacuum tube'**
  String get park18Sub;

  /// 停车第 19 章标题（起始关 L653）
  ///
  /// In en, this message translates to:
  /// **'Sky Glide'**
  String get park19Title;

  /// 停车第 19 章副标题（起始关 L653）
  ///
  /// In en, this message translates to:
  /// **'Landing without an engine'**
  String get park19Sub;

  /// 停车第 20 章标题（起始关 L690）
  ///
  /// In en, this message translates to:
  /// **'Cruiser Formation'**
  String get park20Title;

  /// 停车第 20 章副标题（起始关 L690）
  ///
  /// In en, this message translates to:
  /// **'Forming up the fleet'**
  String get park20Sub;

  /// 停车第 21 章标题（起始关 L727）
  ///
  /// In en, this message translates to:
  /// **'Mech Assembly'**
  String get park21Title;

  /// 停车第 21 章副标题（起始关 L727）
  ///
  /// In en, this message translates to:
  /// **'Steel arms sliding home'**
  String get park21Sub;

  /// 停车第 22 章标题（起始关 L764）
  ///
  /// In en, this message translates to:
  /// **'Anti-Gravity Zone'**
  String get park22Title;

  /// 停车第 22 章副标题（起始关 L764）
  ///
  /// In en, this message translates to:
  /// **'The ultimate parking master'**
  String get park22Sub;

  /// 大阶段名 #1（每 3 章一个阶段）
  ///
  /// In en, this message translates to:
  /// **'Set Sail'**
  String get stage01;

  /// 大阶段名 #2（每 3 章一个阶段）
  ///
  /// In en, this message translates to:
  /// **'Charge Up'**
  String get stage02;

  /// 大阶段名 #3（每 3 章一个阶段）
  ///
  /// In en, this message translates to:
  /// **'Push On'**
  String get stage03;

  /// 大阶段名 #4（每 3 章一个阶段）
  ///
  /// In en, this message translates to:
  /// **'Mastery'**
  String get stage04;

  /// 大阶段名 #5（每 3 章一个阶段）
  ///
  /// In en, this message translates to:
  /// **'Grandmaster'**
  String get stage05;

  /// 大阶段名 #6（每 3 章一个阶段）
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get stage06;

  /// 大阶段名 #7（每 3 章一个阶段）
  ///
  /// In en, this message translates to:
  /// **'Apex'**
  String get stage07;

  /// 停车模式页标题 / 玩法说明弹窗标题
  ///
  /// In en, this message translates to:
  /// **'Parking Mode'**
  String get parkingMode;

  /// 选关页顶栏副标题：一关都没过时
  ///
  /// In en, this message translates to:
  /// **'Ease every car into its spot — no pressure'**
  String get parkingSelectSubEmpty;

  /// 选关页顶栏副标题：已有进度时
  ///
  /// In en, this message translates to:
  /// **'{cleared}/{total} parked · smoother every time'**
  String parkingSelectProgress(int cleared, int total);

  /// 停车章节卡上的魔王章徽标
  ///
  /// In en, this message translates to:
  /// **'👹 Demon'**
  String get parkingDemonBadge;

  /// 停车章节卡副行：阶段名 · 章节副标题（通关进度由右侧 chip 显示，不在这行重复）
  ///
  /// In en, this message translates to:
  /// **'{stage} · {subtitle}'**
  String parkingChapterMeta(String stage, String subtitle);

  /// 停车章节锁定时提示解锁方式
  ///
  /// In en, this message translates to:
  /// **'Collect {name} in Merge to unlock'**
  String parkingLockReason(String name);

  /// 停车选关页顶部每日挑战卡标题
  ///
  /// In en, this message translates to:
  /// **'Daily Parking Challenge'**
  String get parkingDailyTitle;

  /// 每日停车挑战已完成的说明
  ///
  /// In en, this message translates to:
  /// **'Parked for today'**
  String get parkingDailyDone;

  /// 每日停车挑战已完成 + 连胜天数后缀
  ///
  /// In en, this message translates to:
  /// **' · {streak}-day streak'**
  String parkingDailyStreakSuffix(int streak);

  /// 每日停车挑战：连胜 ≥2 时的奖励说明
  ///
  /// In en, this message translates to:
  /// **'{streak}-day streak · finish for +{reward} 🪙'**
  String parkingDailyStreakReward(int streak, int reward);

  /// 每日停车挑战：无连胜时的奖励说明
  ///
  /// In en, this message translates to:
  /// **'One run today · finish for +{reward} 🪙'**
  String parkingDailyTodayReward(int reward);

  /// 每日停车挑战卡的开始按钮
  ///
  /// In en, this message translates to:
  /// **'Park now'**
  String get parkingGo;

  /// 每日挑战完成后的状态标签
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get parkingDoneChip;

  /// 重置本关按钮
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// 停车对局棋盘工具：标记模式
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get parkingMark;

  /// 广告说明的多行版本：正文 + 今日剩余次数
  ///
  /// In en, this message translates to:
  /// **'{base}\n{count} left today'**
  String parkingAdLeft(String base, int count);

  /// 停车结算：步数与用时
  ///
  /// In en, this message translates to:
  /// **'{moves} moves · {seconds}s'**
  String parkingStats(int moves, int seconds);

  /// 停车对局顶栏的关卡标签
  ///
  /// In en, this message translates to:
  /// **'🚗 Parking #{id}'**
  String parkingLevelHeader(int id);

  /// 停车每日挑战对局顶栏的标签
  ///
  /// In en, this message translates to:
  /// **'🚗 Daily'**
  String get parkingDailyHeader;

  /// 停车对局信息条：最少步数
  ///
  /// In en, this message translates to:
  /// **'{n} moves min'**
  String parkingMinMoves(int n);

  /// 停车广告挑战关的信息条标签
  ///
  /// In en, this message translates to:
  /// **'🎬 Challenge'**
  String get parkingChallengeChip;

  /// 点了横放长车但拖错方向时的提示
  ///
  /// In en, this message translates to:
  /// **'↔️ Sideways cars only slide left or right'**
  String get parkingSidewaysOnly;

  /// 点了竖放长车但拖错方向时的提示
  ///
  /// In en, this message translates to:
  /// **'↕️ Upright cars only slide up or down'**
  String get parkingUprightOnly;

  /// 滑行被障碍挡住时的飘字
  ///
  /// In en, this message translates to:
  /// **'🚧 Something is in the way'**
  String get parkingBlocked;

  /// 撤销栈为空时的提示
  ///
  /// In en, this message translates to:
  /// **'Nothing to undo'**
  String get parkingNothingToUndo;

  /// 用撤销卡回退成功后的提示
  ///
  /// In en, this message translates to:
  /// **'↩️ Undo card · back {n} moves'**
  String parkingUndoCardApplied(int n);

  /// 看广告撤销成功后的提示
  ///
  /// In en, this message translates to:
  /// **'🎬 Ad undo · back {n} moves'**
  String parkingAdUndoApplied(int n);

  /// 撤销卡用完时的弹窗标题
  ///
  /// In en, this message translates to:
  /// **'🧯 Out of undo cards'**
  String get parkingNoUndoCards;

  /// 撤销按钮文案（带步数）
  ///
  /// In en, this message translates to:
  /// **'Undo {n} moves'**
  String parkingUndoSteps(int n);

  /// 撤销卡不足弹窗的广告说明
  ///
  /// In en, this message translates to:
  /// **'Watch an ad to step back 3 moves right away.'**
  String get parkingUndoAdBody;

  /// 提示弹窗标题
  ///
  /// In en, this message translates to:
  /// **'💡 Get a hint'**
  String get parkingHintTitle;

  /// 提示弹窗的广告说明
  ///
  /// In en, this message translates to:
  /// **'Watch an ad to reveal the best next move.'**
  String get parkingHintAdBody;

  /// 提示求解失败时的提示
  ///
  /// In en, this message translates to:
  /// **'No solution found — try undo or reset'**
  String get parkingNoSolution;

  /// 停车死局弹窗标题
  ///
  /// In en, this message translates to:
  /// **'No moves left'**
  String get parkingNoMovesTitle;

  /// 停车死局弹窗正文
  ///
  /// In en, this message translates to:
  /// **'This one is stuck — three ways out:'**
  String get parkingNoMovesBody;

  /// 死局弹窗：打开道具栏
  ///
  /// In en, this message translates to:
  /// **'Use an item'**
  String get parkingUseItem;

  /// 停车暂停弹窗标题
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get parkingPausedTitle;

  /// 停车暂停弹窗副标题
  ///
  /// In en, this message translates to:
  /// **'No rush, think about your next move'**
  String get parkingPausedTip;

  /// 停车重开确认弹窗标题
  ///
  /// In en, this message translates to:
  /// **'Restart this level?'**
  String get parkingRestartTitle;

  /// 停车重开确认弹窗正文
  ///
  /// In en, this message translates to:
  /// **'Moves and marks will be wiped.'**
  String get parkingRestartBody;

  /// 停车通关标题
  ///
  /// In en, this message translates to:
  /// **'Parked!'**
  String get parkingWin;

  /// 停车失败标题
  ///
  /// In en, this message translates to:
  /// **'Stuck this round'**
  String get parkingStuck;

  /// 停车失败时的引导文案
  ///
  /// In en, this message translates to:
  /// **'No moves left · undo a step or try a new angle'**
  String get parkingDeadEndHint;

  /// 停车结算：金币奖励行
  ///
  /// In en, this message translates to:
  /// **'+{reward} 🪙'**
  String parkingCoinLine(int reward);

  /// 停车结算：图鉴首次点亮奖励行
  ///
  /// In en, this message translates to:
  /// **'📖 Collection lit up +{reward} 🪙'**
  String parkingCollectionLine(int reward);

  /// 停车每日挑战的连胜奖励行
  ///
  /// In en, this message translates to:
  /// **'🔥 Streak +{reward} 🪙'**
  String parkingStreakLine(int reward);

  /// 挑战关失败时的高亮广告按钮
  ///
  /// In en, this message translates to:
  /// **'🎬 Challenge boost · watch an ad to step back 3'**
  String get parkingAdReviveHint;

  /// 普通关失败时的广告撤销按钮
  ///
  /// In en, this message translates to:
  /// **'Watch an ad to step back 3'**
  String get parkingAdUndoPlain;

  /// 停车玩法说明第一行
  ///
  /// In en, this message translates to:
  /// **'Goal: drive the {icon} {name} into the dashed spot'**
  String parkingHelpGoal(String icon, String name);

  /// 停车玩法说明：幽灵车提示
  ///
  /// In en, this message translates to:
  /// **'(The see-through twin sitting there is your car)'**
  String get parkingHelpGhost;

  /// 停车玩法说明：选中
  ///
  /// In en, this message translates to:
  /// **'Tap a car to select it (gold outline)'**
  String get parkingHelpTap;

  /// 停车玩法说明：滑行
  ///
  /// In en, this message translates to:
  /// **'Tap an empty cell or the spot — it slides straight over'**
  String get parkingHelpSlide;

  /// 停车玩法说明：阻挡
  ///
  /// In en, this message translates to:
  /// **'Blocks 🧱 and other cars stop it'**
  String get parkingHelpBlocked;

  /// 停车玩法说明：挪车
  ///
  /// In en, this message translates to:
  /// **'Other cars are in the way — slide them aside'**
  String get parkingHelpMoveOthers;

  /// 停车玩法说明：长车
  ///
  /// In en, this message translates to:
  /// **'Long cars only slide along their own axis'**
  String get parkingHelpLongCar;

  /// 停车玩法说明：试错成本
  ///
  /// In en, this message translates to:
  /// **'Undo or reset anytime — no fear of mistakes'**
  String get parkingHelpSafety;

  /// 停车道具条：气球（合成侧叫「气球飞越」，这里受按钮宽度限制用短名）
  ///
  /// In en, this message translates to:
  /// **'Balloon'**
  String get parkingItemBalloon;

  /// 停车道具条：双倍移动（合成侧叫「双倍移动」，这里用短名）
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get parkingItemDouble;

  /// 图鉴页标题
  ///
  /// In en, this message translates to:
  /// **'Vehicle Collection'**
  String get collectionTitle;

  /// 图鉴页副标题
  ///
  /// In en, this message translates to:
  /// **'Every one of them is worth keeping'**
  String get collectionSubtitle;

  /// 图鉴页 Boss 徽章墙小节标题
  ///
  /// In en, this message translates to:
  /// **'👑 Boss Badge Wall'**
  String get bossWallTitle;

  /// Boss 徽章墙副标题
  ///
  /// In en, this message translates to:
  /// **'Four guardians a chapter · {done}/{total} beaten'**
  String bossWallSub(int done, int total);

  /// Boss 详情：已击败状态
  ///
  /// In en, this message translates to:
  /// **'Beaten · badge lit'**
  String get bossBeatenBadge;

  /// Boss 详情：未击败状态
  ///
  /// In en, this message translates to:
  /// **'Not beaten · win the Boss of chapter {chapter}'**
  String bossUnbeaten(int chapter);

  /// 图鉴页车系小节标题（中文带「系」后缀，英文不带）
  ///
  /// In en, this message translates to:
  /// **'{icon} {family}'**
  String collectionFamilyHeader(String icon, String family);

  /// 图鉴页车系小节副标题
  ///
  /// In en, this message translates to:
  /// **'{desc} · {done}/{total} collected'**
  String collectionFamilyMeta(String desc, int done, int total);

  /// 车型详情抽屉里的车系标签
  ///
  /// In en, this message translates to:
  /// **'{family} · {desc}'**
  String collectionFamilyChip(String family, String desc);

  /// 车型详情：已收集状态与图鉴编号
  ///
  /// In en, this message translates to:
  /// **'Collected · #{index}/{total}'**
  String collectionIndex(int index, int total);

  /// 车型详情：未解锁状态
  ///
  /// In en, this message translates to:
  /// **'Undiscovered · merge or park to unlock'**
  String get collectionLocked;

  /// 图鉴卡未点亮时的一行小字
  ///
  /// In en, this message translates to:
  /// **'Undiscovered'**
  String get collectionLockedShort;

  /// 车系一句话（陆地）
  ///
  /// In en, this message translates to:
  /// **'Everyday traffic on the road'**
  String get catDescLand;

  /// 车系一句话（重装）
  ///
  /// In en, this message translates to:
  /// **'The heavyweight end of logistics'**
  String get catDescHeavy;

  /// 车系一句话（轨道）
  ///
  /// In en, this message translates to:
  /// **'Running on steel rails'**
  String get catDescRail;

  /// 车系一句话（水上）
  ///
  /// In en, this message translates to:
  /// **'Riding the waves'**
  String get catDescMaritime;

  /// 车系一句话（航空）
  ///
  /// In en, this message translates to:
  /// **'Steel wings cutting the clouds'**
  String get catDescAir;

  /// 车系一句话（太空）
  ///
  /// In en, this message translates to:
  /// **'Out to the stars'**
  String get catDescSpace;

  /// Boss 技能名：冻住关键车
  ///
  /// In en, this message translates to:
  /// **'Freeze'**
  String get attackFreeze;

  /// Boss 技能名：拖走最高档车
  ///
  /// In en, this message translates to:
  /// **'Tow'**
  String get attackSteal;

  /// Boss 技能名：落石占格
  ///
  /// In en, this message translates to:
  /// **'Rubble'**
  String get attackRubble;

  /// Boss 技能名：临时扣车
  ///
  /// In en, this message translates to:
  /// **'Impound'**
  String get attackImpound;

  /// Boss 技能名：降一档
  ///
  /// In en, this message translates to:
  /// **'Degrade'**
  String get attackDevolve;

  /// Boss 技能名：牌堆降档
  ///
  /// In en, this message translates to:
  /// **'Poison'**
  String get attackTaint;

  /// Boss 技能名：锁牌堆几秒
  ///
  /// In en, this message translates to:
  /// **'Deck Lock'**
  String get attackLock;

  /// Boss 技能名：粘住车辆
  ///
  /// In en, this message translates to:
  /// **'Glue'**
  String get attackGlue;

  /// Boss 技能名：开黑洞占格
  ///
  /// In en, this message translates to:
  /// **'Black Hole'**
  String get attackHole;

  /// Boss 技能名：某档禁合
  ///
  /// In en, this message translates to:
  /// **'Merge Ban'**
  String get attackBan;

  /// Boss 技能名：盖住车辆
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get attackFog;

  /// Boss 技能名：全场重排
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get attackShuffle;

  /// Boss 技能名：抢回目标车补血
  ///
  /// In en, this message translates to:
  /// **'Steal Target'**
  String get attackStealGoal;

  /// Boss 被动：护盾周期
  ///
  /// In en, this message translates to:
  /// **'Shield'**
  String get attackShield;

  /// Boss 技能名：冻整块冰
  ///
  /// In en, this message translates to:
  /// **'Ice Block'**
  String get attackIce;

  /// 广告结果：玩家中途关掉
  ///
  /// In en, this message translates to:
  /// **'You didn\'t finish the ad, so no reward this time'**
  String get adOutcomeSkipped;

  /// 广告结果：加载/播放失败
  ///
  /// In en, this message translates to:
  /// **'The ad didn\'t load — try again in a moment'**
  String get adOutcomeFailed;

  /// 广告结果：无 SDK / 无填充
  ///
  /// In en, this message translates to:
  /// **'Ads aren\'t available here right now'**
  String get adOutcomeUnavailable;

  /// 广告结果：达每日上限
  ///
  /// In en, this message translates to:
  /// **'That\'s all for today'**
  String get adOutcomeCapped;

  /// 广告结果：冷却中
  ///
  /// In en, this message translates to:
  /// **'Just watched one — give it a few seconds'**
  String get adOutcomeCooldown;

  /// 广告位全名：商店每日福利
  ///
  /// In en, this message translates to:
  /// **'Daily shop bonus'**
  String get adPlacementShop;

  /// 广告位全名：合成续命
  ///
  /// In en, this message translates to:
  /// **'Merge revive'**
  String get adPlacementRevive;

  /// 广告位全名：合成金币翻倍
  ///
  /// In en, this message translates to:
  /// **'Merge coin doubler'**
  String get adPlacementDouble;

  /// 广告位全名：停车撤销
  ///
  /// In en, this message translates to:
  /// **'Parking undo'**
  String get adPlacementUndo;

  /// 广告位全名：停车提示
  ///
  /// In en, this message translates to:
  /// **'Parking hint'**
  String get adPlacementHint;

  /// 广告诊断里的短名：商店
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get adPlacementShopShort;

  /// 广告诊断里的短名：续命
  ///
  /// In en, this message translates to:
  /// **'Revive'**
  String get adPlacementReviveShort;

  /// 广告诊断里的短名：翻倍
  ///
  /// In en, this message translates to:
  /// **'x2'**
  String get adPlacementDoubleShort;

  /// 广告诊断里的短名：撤销
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get adPlacementUndoShort;

  /// 广告诊断里的短名：提示
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get adPlacementHintShort;

  /// 广告诊断行标签：通道
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get adDiagChannel;

  /// 广告诊断：SDK 尚未初始化
  ///
  /// In en, this message translates to:
  /// **'Not initialised (retries on first tap)'**
  String get adDiagSdkNotInit;

  /// 广告诊断：SDK 正常
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get adDiagSdkReady;

  /// 广告诊断：SDK 初始化失败
  ///
  /// In en, this message translates to:
  /// **'Init failed — placements fall back silently'**
  String get adDiagSdkFailed;

  /// 广告诊断行标签：今日总量
  ///
  /// In en, this message translates to:
  /// **'Daily total'**
  String get adDiagGlobalTotal;

  /// 广告诊断：今日已用/上限
  ///
  /// In en, this message translates to:
  /// **'{used} / {cap}'**
  String adDiagCountLine(int used, int cap);

  /// 广告诊断：全局广告开关关闭时的后缀
  ///
  /// In en, this message translates to:
  /// **' (ads disabled globally)'**
  String get adDiagAdsOff;

  /// 广告诊断行标签：单点剩余
  ///
  /// In en, this message translates to:
  /// **'Left per placement'**
  String get adDiagSingleLeft;

  /// 广告通道三态：演示通道
  ///
  /// In en, this message translates to:
  /// **'Demo channel · no SDK, rewards instantly ({provider})'**
  String adDiagMock(String provider);

  /// 广告通道三态：测试广告
  ///
  /// In en, this message translates to:
  /// **'Test ads · real SDK, test units, zero revenue ({provider})'**
  String adDiagTest(String provider);

  /// 广告通道三态：正式广告
  ///
  /// In en, this message translates to:
  /// **'Live ads · real inventory, billed ({provider})'**
  String adDiagLive(String provider);

  /// 广告启动日志一行（调试用，同时用于通道自检）
  ///
  /// In en, this message translates to:
  /// **'[ads] {channel} · init {state}'**
  String adDiagLog(String channel, String state);

  /// 广告初始化成功
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get adDiagStateOk;

  /// 广告初始化失败
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get adDiagStateFail;

  /// Boss 抢目标技能的飘字（Boss 回血）
  ///
  /// In en, this message translates to:
  /// **'🏆 Stole 1 HP back!'**
  String get floatStealBack;
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
