import 'package:flutter/material.dart';
import '../services/saved_property_service.dart';
import '../services/local_cache_service.dart';

class SavedProvider extends ChangeNotifier {
  final SavedPropertyService _savedService = SavedPropertyService();
  final LocalCacheService _cache = LocalCacheService.instance;

  List<String> _savedIds = [];
  bool _isLoading = false;
  String? _userId;

  List<String> get savedIds => _savedIds;
  bool get isLoading => _isLoading;
  int get savedCount => _savedIds.length;

  Future<void> init(String userId, {bool force = false}) async {
    if (!force && _userId == userId && _savedIds.isNotEmpty) return;

    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      _savedIds = await _savedService.getSavedListingIds(userId);
    } catch (e) {
      debugPrint('Init saved provider error: $e');
      _savedIds = await _cache.getSavedIds(userId);
    }

    _isLoading = false;
    notifyListeners();
  }

  bool isSaved(String listingId) {
    return _savedIds.contains(listingId);
  }

  Future<bool> toggleSave(String listingId) async {
    if (_userId == null || _userId!.isEmpty) {
      return false;
    }

    try {
      if (_savedIds.contains(listingId)) {
        await _savedService.unsaveProperty(_userId!, listingId);
        _savedIds.remove(listingId);
        notifyListeners();
        return false;
      } else {
        await _savedService.saveProperty(_userId!, listingId);
        _savedIds.add(listingId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Toggle save error: $e');
      return _savedIds.contains(listingId);
    }
  }

  void clear() {
    _savedIds = [];
    _userId = null;
    notifyListeners();
  }
}
