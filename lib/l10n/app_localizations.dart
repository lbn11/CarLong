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
  /// **'{cost} 🪙 per chest · 60% coins / 40% boosters'**
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
  /// **'Coins come only from ads and clearing levels. There is no purchase option in the game.'**
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
