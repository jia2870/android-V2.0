import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property_model.dart';
import 'supabase_service.dart';

class SavedPropertyService {
  final SupabaseClient _client = SupabaseService().client;

  // 保存房产到收藏
  Future<void> saveProperty(String userId, String listingId) async {
    try {
      final data = {
        'user_id': userId,
        'listing_id': listingId,
      };
      await _client
          .from(SupabaseService.savedPropertiesTable)
          .insert(data);
    } catch (e) {
      throw Exception('Failed to save property: $e');
    }
  }

  // 从收藏中移除
  Future<void> unsaveProperty(String userId, String listingId) async {
    try {
      await _client
          .from(SupabaseService.savedPropertiesTable)
          .delete()
          .eq('user_id', userId)
          .eq('listing_id', listingId);
    } catch (e) {
      throw Exception('Failed to unsave property: $e');
    }
  }

  // 检查是否已收藏
  Future<bool> isSaved(String userId, String listingId) async {
    try {
      final response = await _client
          .from(SupabaseService.savedPropertiesTable)
          .select('id')
          .eq('user_id', userId)
          .eq('listing_id', listingId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // 获取用户收藏的 listing_id 列表
  Future<List<String>> getSavedListingIds(String userId) async {
    try {
      final response = await _client
          .from(SupabaseService.savedPropertiesTable)
          .select('listing_id')
          .eq('user_id', userId)
          .order('saved_at', ascending: false);

      return response.map((item) => item['listing_id'].toString()).toList();
    } catch (e) {
      throw Exception('Failed to get saved listing IDs: $e');
    }
  }

  // 获取用户收藏的房产详情
  Future<List<PropertyModel>> getSavedProperties(String userId) async {
    try {
      final listingIds = await getSavedListingIds(userId);

      if (listingIds.isEmpty) return [];

      final response = await _client
          .from(SupabaseService.propertiesTable)
          .select()
          .inFilter('listing_id', listingIds)
          .order('scraped_at', ascending: false);

      return response.map<PropertyModel>((json) => PropertyModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get saved properties: $e');
    }
  }

  // 获取收藏数量
  Future<int> getSavedCount(String userId) async {
    try {
      final response = await _client
          .from(SupabaseService.savedPropertiesTable)
          .select('id')
          .eq('user_id', userId);

      return response.length;
    } catch (e) {
      return 0;
    }
  }
}