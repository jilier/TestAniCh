import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xs/src/utils/custom_throttle.dart';
import 'package:xs/src/utils/log.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/danmaku_settings/storage.dart';
import 'package:xs/src/widgets/ns_danmaku/danmaku_controller.dart';
import 'package:xs/src/widgets/ns_danmaku/models/danmaku_item.dart';
import 'package:xs/src/widgets/ns_danmaku/models/danmaku_option.dart';

mixin PlayerMixin {
  GlobalKey<VideoState> globalPlayerKey = GlobalKey<VideoState>();
  GlobalKey globalDanmuKey = GlobalKey();

  // 播放器实例
  late final player = Player();

  // 视频控制器
  late final videoController = VideoController(
    player,
  );
}

mixin PlayerStateMixin on PlayerMixin {
  // 音量控制条计时器
  Timer? hidevolumeTimer;

  // 是否进入桌面端小窗
  RxBool smallWindowState = false.obs;

  // 是否显示弹幕
  RxBool showDanmakuState = true.obs;

  // 是否显示弹幕发送框
  RxBool showDanmakuTextField = false.obs;

  // 是否显示控制器
  RxBool showControlsState = false.obs;

  // 是否显示设置窗口
  RxBool showSettingState = false.obs;

  // 是否显示弹幕设置窗口
  RxBool showDanmakuSettingState = false.obs;

  // 是否处于锁定控制器状态
  RxBool lockControlsState = false.obs;

  // 是否处于全屏状态
  RxBool fullScreenState = false.obs;

  // 显示手势Tip
  RxBool showGestureTip = false.obs;

  // 手势Tip文本
  RxString gestureTipText = ''.obs;

  // 显示提示底部Tip
  RxBool showBottomTip = false.obs;

  // 提示底部Tip文本
  RxString bottomTipText = ''.obs;

  // 自动隐藏控制器计时器
  Timer? hideControlsTimer;

  // 自动隐藏提示计时器
  Timer? hideSeekTipTimer;

  // 是否为竖屏直播间
  var isVertical = false.obs;

  // 画面尺寸
  RxInt scaleMode = 0.obs;
  BoxFit boxFit = BoxFit.contain;
  double? aspectRatio;

  // 播放倍速
  RxDouble playerSpeed = 1.0.obs;
  final List<double> speedsList = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  Widget? danmakuView;

  var showQualites = false.obs;
  var showLines = false.obs;

  // 是否显示哔哩哔哩弹幕
  RxBool bilibiliDanmakuState = true.obs;
  RxBool bilibiliHmtDanmakuState = true.obs;

  // 是否显示腾讯视频弹幕
  RxBool qqDanmakuState = true.obs;

  // 设置倍速
  Future setPlaybackSpeed(double rate) async {
    try {
      player.setRate(rate);
    } catch (e) {
      debugPrint(e.toString());
    }
    playerSpeed(rate);
  }

  // 获取视频分辨率文本
  String getRatioText() {
    if (player.state.width != null) {
      return ' (${player.state.width}x${player.state.height})';
    } else {
      return '';
    }
  }

  // 隐藏控制器
  void hideControls() {
    showControlsState.value = false;
    hideControlsTimer?.cancel();
  }

  void setLockState() {
    lockControlsState.value = !lockControlsState.value;
    if (lockControlsState.value) {
      showControlsState.value = false;
    } else {
      showControlsState.value = true;
    }
  }

  // 显示控制器
  void showControls() {
    showControlsState.value = true;
    resetHideControlsTimer();
  }

  // 开始隐藏控制器计时
  // - 当点击控制器上时功能时需要重新计时
  void resetHideControlsTimer() {
    hideControlsTimer?.cancel();

    hideControlsTimer = Timer(
      const Duration(
        seconds: 5,
      ),
      hideControls,
    );
  }

  void updateScaleMode(int value) {
    scaleMode(value);
    if (player.state.width != null && player.state.height != null) {
      aspectRatio = player.state.width! / player.state.height!;
    }

    if (scaleMode.value == 0) {
      boxFit = BoxFit.contain;
    } else if (scaleMode.value == 1) {
      boxFit = BoxFit.fill;
    } else if (scaleMode.value == 2) {
      boxFit = BoxFit.cover;
    } else if (scaleMode.value == 3) {
      boxFit = BoxFit.contain;
      aspectRatio = 16 / 9;
    } else if (scaleMode.value == 4) {
      boxFit = BoxFit.contain;
      aspectRatio = 4 / 3;
    }

    globalPlayerKey.currentState?.update(
      aspectRatio: aspectRatio,
      fit: boxFit,
    );
  }
}

mixin PlayerDanmakuMixin on PlayerStateMixin {
  // 弹幕控制器
  DanmakuController? danmakuController;

  // 弹幕输入框控制器
  FocusNode danmakuTextFieldFocusNode = FocusNode();
  TextEditingController textEditingController = TextEditingController();

  RxDouble danmakuStrokeWidth = 1.0.obs;
  RxInt danmakuFontWeight = FontWeight.bold.index.obs;
  RxBool strokeText = true.obs;

  RxBool textFormatStatus = true.obs;
  RxString danmakuText = ''.obs;
  RxString danmakuColor = '#ffffff'.obs;
  RxInt danmakuTypeIndex = 1.obs;

  void initDanmakuController(DanmakuController e) {
    danmakuController = e;
    danmakuController?.updateOption(
      DanmakuOption(
          fontSize: DanmakuSettingsStorage.danmakuSize.value,
          area: DanmakuSettingsStorage.danmakuArea.value,
          duration: DanmakuSettingsStorage.danmakuSpeed.value,
          opacity: DanmakuSettingsStorage.danmakuOpacity.value,
          strokeWidth: danmakuStrokeWidth.value,
          fontWeight: FontWeight.values[danmakuFontWeight.value],
          strokeText: strokeText.value),
    );
  }

  void updateDanmuOption(DanmakuOption? option) {
    if (danmakuController == null || option == null) return;
    danmakuController!.updateOption(option);
  }

  void disposeDanmakuController() {
    danmakuController?.clear();
  }

  void addDanmaku(List<DanmakuItem> items) {
    if (!showDanmakuState.value) {
      return;
    }
    danmakuController?.addItems(items);
  }
}

mixin PlayerSystemMixin on PlayerMixin, PlayerStateMixin, PlayerDanmakuMixin {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final screenBrightness = ScreenBrightness();

  final pip = Floating();
  StreamSubscription<PiPStatus>? _pipSubscription;

  // 初始化一些系统状态
  void initSystem() async {
    if (Platform.isAndroid || Platform.isIOS) {
      PerfectVolumeControl.hideUI = true;
    }

    // 屏幕常亮
    WakelockPlus.enable();

    // 开始隐藏计时
    resetHideControlsTimer();
  }

  // 释放一些系统状态
  Future resetSystem() async {
    _pipSubscription?.cancel();
    // pip.dispose();
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    await setPortraitOrientation();
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // 亮度重置,桌面平台可能会报错,暂时不处理桌面平台的亮度
      try {
        await screenBrightness.resetScreenBrightness();
      } catch (e) {
        Log.logPrint(e);
      }
    }

    await WakelockPlus.disable();
  }

  // 进入全屏
  Future<void> enterFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
    await landScape();
  }

  //横屏
  Future<void> landScape() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await AutoOrientation.landscapeAutoMode(forceSensor: true);
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await const MethodChannel('com.alexmercerind/media_kit_video')
            .invokeMethod(
          'Utils.EnterNativeFullscreen',
        );
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
    fullScreenState.value = true;
    danmakuController?.clear();
  }

  //竖屏
  Future<void> verticalScreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  // 退出全屏
  Future<void> exitFull() async {
    late SystemUiMode mode = SystemUiMode.edgeToEdge;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        if (Platform.isAndroid &&
            (await DeviceInfoPlugin().androidInfo).version.sdkInt < 29) {
          mode = SystemUiMode.manual;
        }
        await SystemChrome.setEnabledSystemUIMode(
          mode,
          overlays: SystemUiOverlay.values,
        );
        await SystemChrome.setPreferredOrientations([]);
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await const MethodChannel('com.alexmercerind/media_kit_video')
            .invokeMethod(
          'Utils.ExitNativeFullscreen',
        );
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
    fullScreenState.value = false;
    danmakuController?.clear();
  }

  Size? _lastWindowSize;
  Offset? _lastWindowPosition;

  //小窗模式()
  void enterSmallWindow() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      fullScreenState.value = true;
      smallWindowState.value = true;

      // 读取窗口大小
      _lastWindowSize = await windowManager.getSize();
      _lastWindowPosition = await windowManager.getPosition();

      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      // 获取视频窗口大小
      var width = player.state.width ?? 16;
      var height = player.state.height ?? 9;

      // 横屏还是竖屏
      if (height > width) {
        var aspectRatio = width / height;
        windowManager.setSize(Size(400, 400 / aspectRatio));
      } else {
        var aspectRatio = height / width;
        windowManager.setSize(Size(280 / aspectRatio, 280));
      }

      windowManager.setAlwaysOnTop(true);
    }
  }

  //退出小窗模式()
  void exitSmallWindow() {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      fullScreenState.value = false;
      smallWindowState.value = false;
      // windowManager.setTitleBarStyle(TitleBarStyle.normal);
      windowManager.setSize(_lastWindowSize!);
      windowManager.setPosition(_lastWindowPosition!);
      windowManager.setAlwaysOnTop(false);
      //windowManager.setAlignment(Alignment.center);
    }
  }

  // 设置横屏
  Future setLandscapeOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.landscapeAutoMode();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  // 设置竖屏
  Future setPortraitOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.portraitAutoMode();
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  // 是否是IOS16以下
  Future<bool> beforeIOS16() async {
    if (Platform.isIOS) {
      var info = await deviceInfo.iosInfo;
      var version = info.systemVersion;
      var versionInt = int.tryParse(version.split('.').first) ?? 0;
      return versionInt < 16;
    } else {
      return false;
    }
  }

  Future saveScreenshot() async {
    try {
      SmartDialog.showLoading(msg: '正在保存截图');
      //检查相册权限,仅iOS需要
      var permission = await Utils.checkPhotoPermission();
      if (!permission) {
        SmartDialog.showToast('没有相册权限');
        SmartDialog.dismiss(status: SmartStatus.loading);
        return;
      }

      var imageData = await player.screenshot();
      if (imageData == null) {
        SmartDialog.showToast('截图失败,数据为空');
        SmartDialog.dismiss(status: SmartStatus.loading);
        return;
      }

      if (Platform.isIOS || Platform.isAndroid) {
        await ImageGallerySaver.saveImage(
          imageData,
        );
        SmartDialog.showToast('已保存截图至相册');
      } else {
        //选择保存文件夹
        var path = await FilePicker.platform.saveFile(
          allowedExtensions: ['jpg'],
          type: FileType.image,
          fileName: '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (path == null) {
          SmartDialog.showToast('取消保存');
          SmartDialog.dismiss(status: SmartStatus.loading);
          return;
        }
        var file = File(path);
        await file.writeAsBytes(imageData);
        SmartDialog.showToast('已保存截图至${file.path}');
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast('截图失败');
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  // 开启小窗播放前弹幕状态
  bool danmakuStateBeforePIP = false;

  Future enablePIP() async {
    if (!Platform.isAndroid) {
      return;
    }
    if (await pip.isPipAvailable == false) {
      SmartDialog.showToast('设备不支持小窗播放');
      return;
    }
    danmakuStateBeforePIP = showDanmakuState.value;
    //关闭并清除弹幕
    // if (AppSettingsController.instance.pipHideDanmu.value &&
    //     danmakuStateBeforePIP) {
    //   showDanmakuState.value = false;
    // }
    danmakuController?.clear();
    //关闭控制器
    showControlsState(false);

    await pip.enable(const ImmediatePiP(aspectRatio: Rational.landscape()));

    _pipSubscription ??= pip.pipStatusStream.listen((event) {
      if (event == PiPStatus.disabled) {
        danmakuController?.clear();
        showDanmakuState.value = danmakuStateBeforePIP;
      }
    });
  }
}

mixin PlayerGestureControlMixin
    on PlayerStateMixin, PlayerMixin, PlayerSystemMixin {
  // 单击显示/隐藏控制器
  void onTap() {
    if (showControlsState.value) {
      hideControls();
    } else {
      showControls();
    }
  }

  //桌面端操控
  void onEnter(PointerEnterEvent event) {
    if (!showControlsState.value) {
      showControls();
    }
  }

  void onExit(PointerExitEvent event) {
    if (showControlsState.value) {
      hideControls();
    }
  }

  void onHover(PointerHoverEvent event, BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) {
      return;
    }
    // final screenHeight = MediaQuery.of(context).size.height;
    // final targetPosition = screenHeight * 0.25; // 计算屏幕顶部25%的位置
    // if (event.position.dy <= targetPosition ||
    //     event.position.dy >= targetPosition * 3) {
    //   if (!showControlsState.value) {
    //     showControls();
    //   }
    // }
    if (!showControlsState.value) {
      showControls();
    }
  }

  // 双击全屏/退出全屏
  void onDoubleTap(TapDownDetails details) {
    if (lockControlsState.value || smallWindowState.value) {
      return;
    }
    if (fullScreenState.value) {
      exitFull();
    } else {
      enterFullScreen();
    }
  }

  bool verticalDragging = false;
  bool leftVerticalDrag = false;
  var _currentVolume = 0.0;
  var _currentBrightness = 1.0;
  var verStartPosition = 0.0;

  DelayedThrottle? throttle;

  // 竖向手势开始
  void onVerticalDragStart(DragStartDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }

    final dy = details.globalPosition.dy;
    // 开始位置必须是中间2/4的位置
    if (dy < Get.height * 0.25 || dy > Get.height * 0.75) {
      return;
    }

    verStartPosition = dy;
    leftVerticalDrag = details.globalPosition.dx < Get.width / 2;

    throttle = DelayedThrottle(200);

    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    verticalDragging = true;
    showGestureTip.value = true;
    if (Platform.isAndroid || Platform.isIOS) {
      _currentVolume = await PerfectVolumeControl.volume;
    }
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      _currentBrightness = await screenBrightness.current;
    }
  }

  // 竖向手势更新
  void onVerticalDragUpdate(DragUpdateDetails e) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    if (verticalDragging == false) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    //String text = '';
    //double value = 0.0;

    Log.logPrint('$verStartPosition/${e.globalPosition.dy}');

    if (leftVerticalDrag) {
      setGestureBrightness(e.globalPosition.dy);
    } else {
      setGestureVolume(e.globalPosition.dy);
    }
  }

  int lastVolume = -1; // it's ok to be -1

  void setGestureVolume(double dy) {
    double value = 0.0;
    double seek;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      seek = _currentVolume - value;
      if (seek < 0) {
        seek = 0;
      }
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      seek = value.abs() + _currentVolume;
      if (seek > 1) {
        seek = 1;
      }
    }
    int volume = _convertVolume((seek * 100).round());
    if (volume == lastVolume) {
      return;
    }
    lastVolume = volume;
    // update UI outside throttle to make it more fluent
    gestureTipText.value = '音量 $volume%';
    throttle?.invoke(() async => await _realSetVolume(volume));
  }

  // 0 to 100, 5 step each
  int _convertVolume(int volume) {
    return (volume / 5).round() * 5;
  }

  Future<void> _realSetVolume(int volume) async {
    Log.logPrint(volume);
    return await PerfectVolumeControl.setVolume(volume / 100);
  }

  void setGestureBrightness(double dy) {
    double value = 0.0;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      var seek = _currentBrightness - value;
      if (seek < 0) {
        seek = 0;
      }
      screenBrightness.setScreenBrightness(seek);

      gestureTipText.value = '亮度 ${(seek * 100).toInt()}%';
      Log.logPrint(value);
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      var seek = value.abs() + _currentBrightness;
      if (seek > 1) {
        seek = 1;
      }

      screenBrightness.setScreenBrightness(seek);
      gestureTipText.value = '亮度 ${(seek * 100).toInt()}%';
      Log.logPrint(value);
    }
  }

  // 竖向手势完成
  void onVerticalDragEnd(DragEndDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    throttle = null;
    verticalDragging = false;
    leftVerticalDrag = false;
    showGestureTip.value = false;
  }

  bool horizontalDragging = false;
  bool horizontalDrag = false;
  var horizontalStartPosition = 0.0;
  Duration _currentDuration = Duration.zero;
  double _currentPosition = 0.0;

  // 横向手势开始
  void onHorizontalDragStart(DragStartDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }

    final dx = details.globalPosition.dx;
    // if (dx < Get.width || dx > Get.width) {
    //   return;
    // }

    horizontalStartPosition = dx;
    horizontalDrag = details.globalPosition.dx < Get.width / 2;

    throttle = DelayedThrottle(200);

    horizontalDragging = true;
    showGestureTip.value = true;
    _currentDuration = player.state.duration;
    // print(
    //     'Horizontal drag start at: ${details.globalPosition} $_currentDuration');
  }

  // 横向手势更新
  void onHorizontalDragUpdate(DragUpdateDetails e) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    if (horizontalDragging == false) return;
    //String text = '';
    double value = 0.0;
    value =
        ((e.globalPosition.dx - horizontalStartPosition) / (Get.width * 0.5));
    _currentPosition = max(
        0,
        min(
            player.state.position.inSeconds +
                _currentDuration.inSeconds * (value * 0.5),
            _currentDuration.inSeconds.toDouble()));
    // Log.logPrint('$horizontalStartPosition/${e.globalPosition.dx}');
    // Log.logPrint('$_currentPosition/$value');
    gestureTipText.value =
        '${Duration(seconds: _currentPosition.toInt()).toString().split('.').first}/${_currentDuration.toString().split('.').first}';
  }

  // 横向手势完成
  void onHorizontalDragEnd(DragEndDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    throttle = null;
    horizontalDragging = false;
    horizontalDrag = false;
    showGestureTip.value = false;
    seekTo();
  }

  void seekTo() {
    player.seek(Duration(seconds: _currentPosition.toInt()));
  }
}

class PlayerController extends GetxController
    with
        PlayerMixin,
        PlayerStateMixin,
        PlayerDanmakuMixin,
        PlayerSystemMixin,
        PlayerGestureControlMixin {
  @override
  void onInit() {
    initSystem();
    initStream();
    //设置音量
    // player.setVolume(AppSettingsController.instance.playerVolume.value);
    super.onInit();
  }

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _widthSubscription;
  StreamSubscription? _heightSubscription;
  StreamSubscription? _logSubscription;

  void initStream() {
    _errorSubscription = player.stream.error.listen((event) {
      Log.d('播放器错误：$event');
      // 跳过无音频输出的错误
      // Could not open/initialize audio device -> no sound.
      if (event.contains('no sound.')) {
        return;
      }
      //SmartDialog.showToast(event);
      mediaError(event);
    });

    _completedSubscription = player.stream.completed.listen((event) {
      if (event) {
        mediaEnd();
      }
    });
    _logSubscription = player.stream.log.listen((event) {
      Log.d('播放器日志：$event');
    });
    _widthSubscription = player.stream.width.listen((event) {
      Log.d(
          'width:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
    });
    _heightSubscription = player.stream.height.listen((event) {
      Log.d(
          'height:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
    });
  }

  void disposeStream() {
    _errorSubscription?.cancel();
    _completedSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _logSubscription?.cancel();
    _pipSubscription?.cancel();
  }

  void mediaEnd() {}

  void mediaError(String error) {}

  void showDebugInfo() {
    Utils.showBottomSheet(
      title: '播放信息',
      child: ListView(
        children: [
          ListTile(
            title: const Text('Resolution'),
            subtitle: Text('${player.state.width}x${player.state.height}'),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      'Resolution\n${player.state.width}x${player.state.height}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('VideoParams'),
            subtitle: Text(player.state.videoParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'VideoParams\n${player.state.videoParams}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('AudioParams'),
            subtitle: Text(player.state.audioParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'AudioParams\n${player.state.audioParams}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Media'),
            subtitle: Text(player.state.playlist.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'Media\n${player.state.playlist}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('AudioTrack'),
            subtitle: Text(player.state.track.audio.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'AudioTrack\n${player.state.track.audio}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('VideoTrack'),
            subtitle: Text(player.state.track.video.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'VideoTrack\n${player.state.track.audio}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('AudioBitrate'),
            subtitle: Text(player.state.audioBitrate.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'AudioBitrate\n${player.state.audioBitrate}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Volume'),
            subtitle: Text(player.state.volume.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'Volume\n${player.state.volume}',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void onClose() async {
    Log.w('播放器关闭');
    if (smallWindowState.value) {
      exitSmallWindow();
    }
    textEditingController.dispose();
    danmakuTextFieldFocusNode.dispose();
    disposeStream();
    disposeDanmakuController();
    await resetSystem();
    await player.dispose();
    super.onClose();
  }
}
