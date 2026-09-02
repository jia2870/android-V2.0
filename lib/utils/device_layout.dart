import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double kPhoneShortestSideMax = 600;

bool isPhoneLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide < kPhoneShortestSideMax;
}

bool isTabletLayout(BuildContext context) => !isPhoneLayout(context);

bool isPhoneFromWindow() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return true;
  final view = views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  return size.shortestSide < kPhoneShortestSideMax;
}

bool isTabletUiActive(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;

Future<void> applyPreferredOrientationsForDevice({required bool isPhone}) {
  return SystemChrome.setPreferredOrientations(
    isPhone
        ? const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : DeviceOrientation.values,
  );
}
