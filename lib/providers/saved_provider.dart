import 'package:flutter/material.dart';
import '../services/saved_property_service.dart';
import '../models/property_model.dart';

class SavedProvider extends ChangeNotifier {
  final SavedPropertyService _savedService = SavedPropertyService();

  List<String> _savedIds = [];
  bool _isLoading = false;
  String? _userId;

  List<String> get savedIds => _savedIds;
  bool get isLoading => _isLoading;
  int get savedCount => _savedIds.length;

  // 初始化用户的收藏列表
  Future<void> init(String userId) async {
    if (_userId == userId && _savedIds.isNotEmpty) return;

    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      _savedIds = await _savedService.getSavedListingIds(userId);
    } catch (e) {
      debugPrint('Init saved provider error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // 检查是否已收藏
  bool isSaved(String listingId) {
    return _savedIds.contains(listingId);
  }

  // 切换收藏状态
  Future<bool> toggleSave(String listingId) async {
    if (_userId == null || _userId!.isEmpty) {
      return false;
    }

    try {
      if (_savedIds.contains(listingId)) {
        // 取消收藏
        await _savedService.unsaveProperty(_userId!, listingId);
        _savedIds.remove(listingId);
        notifyListeners();
        return false; // 现在未收藏
      } else {
        // 添加收藏
        await _savedService.saveProperty(_userId!, listingId);
        _savedIds.add(listingId);
        notifyListeners();
        return true; // 现在已收藏
      }
    } catch (e) {
      debugPrint('Toggle save error: $e');
      return _savedIds.contains(listingId);
    }
  }

  // 清除数据（退出登录时调用）
  void clear() {
    _savedIds = [];
    _userId = null;
    notifyListeners();
  }
}