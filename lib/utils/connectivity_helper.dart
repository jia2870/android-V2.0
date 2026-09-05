import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> isDeviceOnline() async {
  try {
    final results = await Connectivity()
        .checkConnectivity()
        .timeout(const Duration(seconds: 3));
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  } catch (_) {
    return true;
  }
}
