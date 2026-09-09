import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool _initialized = false;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _hasConnection(results);
    } catch (e) {
      debugPrint('Connectivity init error: $e');
      _isOnline = true;
    }

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online == _isOnline) return;
      _isOnline = online;
      notifyListeners();
    });

    _initialized = true;
    notifyListeners();
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
