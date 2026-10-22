import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_provider.dart';
import '../ad_types.dart';
import 'admob_config.dart';

/// AdMob 激励视频实现（Android / iOS），海外发行的主渠道。
///
/// 只做三件事：拉广告、展示、把 SDK 回调翻译成 [AdResult]。
/// **发奖判定完全交给 [AdService]**，这里不碰存档、不碰金币。
///
/// 合规顺序（顺序错了会被拒审或收不到钱）：
/// 1. iOS：先 ATT 授权（IDFA），再走 UMP 同意表单；
/// 2. UMP 返回 `canRequestAds == false` → 整个 provider 返回
///    [AdOutcome.unavailable]，**不允许再发广告请求**；
/// 3. SDK 初始化放在首帧之后（`main.dart` 里用 postFrameCallback），
///    因为同意表单需要已挂载的 Activity / ViewController。
class AdMobAdProvider extends AdProvider {
  AdMobAdProvider({AdMobConfig? config})
      : config = config ?? AdMobConfig.fromEnvironment();

  final AdMobConfig config;

  /// 已拉好、等展示的广告（按广告位缓存，避免点击后等 2-5 秒）。
  final Map<AdPlacement, RewardedAd> _ready = {};

  /// 正在拉取的 future，防止连点重复 load。
  final Map<AdPlacement, Future<void>> _inflight = {};

  bool _initialized = false;
  bool _consentAllowsAds = true;

  @override
  String get name => 'admob';

  @override
  bool get isMock => false;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      if (Platform.isIOS && config.requestAtt) {
        await _requestAtt();
      }
      if (config.requestConsent) {
        await _gatherConsent();
      }
      if (!_consentAllowsAds) return false;

      final status = await MobileAds.instance.initialize();
      // 接中介网络（FAN / Unity / AppLovin）后，这里能直接看到每个 adapter
      // 是否 READY——"广告没填充"最常见的原因是 adapter 没初始化成功。
      if (kDebugMode) {
        for (final entry in status.adapterStatuses.entries) {
          debugPrint('[ads] adapter ${entry.key} -> ${entry.value.state}');
        }
      }
      if (config.testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: config.testDeviceIds),
        );
      }
      _initialized = true;
      return true;
    } catch (_) {
      // 缺 App ID、无 Google Play 服务、模拟器无广告环境等：静默降级。
      return false;
    }
  }

  /// iOS 14.5+ 的 ATT 授权。未决定状态才弹窗（重复调用不会二次弹）。
  Future<void> _requestAtt() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization().timeout(
          const Duration(seconds: 30),
          onTimeout: () => TrackingStatus.notDetermined,
        );
      }
    } catch (_) {
      // 低版本系统 / 已关闭「允许 App 请求跟踪」：按非个性化继续。
    }
  }

  /// UMP 同意流程（GDPR / CCPA / DMA）。EEA/UK 会弹表单，其他地区通常
  /// 直接返回 `notRequired`，不打扰玩家。
  Future<void> _gatherConsent() async {
    final info = ConsentInformation.instance;
    final done = Completer<void>();
    info.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired(
            (FormError? error) {},
          );
        } catch (_) {
          // 表单加载失败不阻塞：SDK 会按「未同意」走非个性化广告。
        }
        if (!done.isCompleted) done.complete();
      },
      (FormError error) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    try {
      _consentAllowsAds = await info.canRequestAds();
    } catch (_) {
      // 拿不到状态时按「可以请求」处理，避免整块功能被一个异常关掉。
      _consentAllowsAds = true;
    }
  }

  @override
  Future<void> preload(AdPlacement placement) async {
    if (!_initialized || !_consentAllowsAds) return;
    await _ensureLoaded(placement);
  }

  @override
  Future<AdResult> showRewarded(AdPlacement placement) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return AdResult.unavailable;
    }
    if (!_consentAllowsAds) {
      return const AdResult(
        AdOutcome.unavailable,
        detail: 'consent: canRequestAds == false',
      );
    }

    final ad = await _take(placement);
    if (ad == null) {
      return const AdResult(AdOutcome.failed, detail: 'load failed');
    }

    final done = Completer<AdResult>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) {
          done.complete(earned ? AdResult.granted : AdResult.skipped);
        }
        // 这次用掉了，后台补拉下一条，玩家连看两次不用再等加载。
        unawaited(preload(placement));
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!done.isCompleted) {
          done.complete(AdResult(AdOutcome.failed, detail: error.message));
        }
        unawaited(preload(placement));
      },
    );

    try {
      await ad.show(onUserEarnedReward: (AdWithoutView _, RewardItem reward) {
        earned = true;
      });
    } catch (e) {
      ad.dispose();
      if (!done.isCompleted) {
        done.complete(AdResult(AdOutcome.failed, detail: e.toString()));
      }
    }

    return done.future.timeout(
      config.showTimeout,
      onTimeout: () => const AdResult(AdOutcome.skipped, detail: 'show timeout'),
    );
  }

  /// 取一条可展示的广告：优先缓存，没有就现拉，无填充时**静默重试一次**。
  ///
  /// 为什么要重试：AdMob 的 no-fill 有很大一部分是瞬时抖动（刚 init 完
  /// adapter 还没 READY、网络切换）。一次 600ms 后的重试能把这类失败吃掉，
  /// 玩家感知到的「点了没反应」会明显减少；两次都失败才是真的没填充。
  Future<RewardedAd?> _take(AdPlacement placement) async {
    final cached = _ready.remove(placement);
    if (cached != null) return cached;
    await _ensureLoaded(placement);
    final first = _ready.remove(placement);
    if (first != null) return first;

    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _ensureLoaded(placement);
    return _ready.remove(placement);
  }

  Future<void> _ensureLoaded(AdPlacement placement) {
    if (_ready.containsKey(placement)) return Future<void>.value();
    final running = _inflight[placement];
    if (running != null) return running;
    final future = _load(placement).whenComplete(() => _inflight.remove(placement));
    _inflight[placement] = future;
    return future;
  }

  Future<void> _load(AdPlacement placement) async {
    final unitId = config.unitIdFor(placement, isIOS: Platform.isIOS);
    final completer = Completer<RewardedAd?>();
    var abandoned = false;

    unawaited(
      RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (abandoned) {
              ad.dispose();
              return;
            }
            completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      ),
    );

    final ad = await completer.future.timeout(
      config.loadTimeout,
      onTimeout: () {
        // 超时后回调仍可能到达，用一个标记在回调里回收，避免泄漏原生广告对象。
        abandoned = true;
        return null;
      },
    );
    if (ad == null) return;
    _ready[placement] = ad;
  }

  // ===== 隐私设置（UMP）=====

  /// UMP 要求：`PrivacyOptionsRequirementStatus.required` 时，App 内必须
  /// 有随时可进出的隐私设置入口（GDPR 的撤回同意权）。缺这个入口是欧盟区
  /// 的明确不合规点，比「广告不够多」严重得多。
  @override
  Future<bool> privacyOptionsRequired() async {
    if (!config.requestConsent) return false;
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// 打开 UMP 隐私设置表单。
  ///
  /// 注意：**不要**在回调里再判断 `required` 然后递归调本方法——REQUIRED
  /// 的意思是「需要一个入口」，不是「需要再弹一次表单」，那样会死循环。
  @override
  Future<bool> showPrivacyOptions() async {
    if (!config.requestConsent) return false;
    final done = Completer<bool>();
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (!done.isCompleted) done.complete(error == null);
      });
    } catch (_) {
      if (!done.isCompleted) done.complete(false);
    }
    final shown = await done.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => false,
    );
    // 玩家可能在这里撤回同意：重新读一次状态，撤回后 show() 会自然降级。
    try {
      _consentAllowsAds = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      // 读不到就沿用旧值，不因为一个异常把广告整块关掉。
    }
    return shown;
  }

  @override
  Future<void> dispose() async {
    for (final ad in _ready.values) {
      ad.dispose();
    }
    _ready.clear();
    _inflight.clear();
    _initialized = false;
  }
}

/// 创建 AdMob provider（Android / iOS 版本）。
AdProvider createAdMobProvider({AdMobConfig? config}) =>
    AdMobAdProvider(config: config);
