import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property_model.dart';
import '../utils/connectivity_helper.dart';
import 'local_cache_service.dart';
import 'supabase_service.dart';

class SavedPropertyService {
  final SupabaseClient _client = SupabaseService().client;
  final LocalCacheService _cache = LocalCacheService.instance;

  Future<void> saveProperty(String userId, String listingId) async {
    try {
      final data = {
        'user_id': userId,
        'listing_id': listingId,
      };
      await _client
          .from(SupabaseService.savedPropertiesTable)
          .insert(data);
      final ids = await _cache.getSavedIds(userId);
      if (!ids.contains(listingId)) {
        ids.insert(0, listingId);
        await _cache.saveSavedIds(userId, ids);
      }
    } catch (e) {
      throw Exception('Failed to save property: $e');
    }
  }

  Future<void> unsaveProperty(String userId, String listingId) async {
    try {
      await _client
          .from(SupabaseService.savedPropertiesTable)
          .delete()
          .eq('user_id', userId)
          .eq('listing_id', listingId);
      final ids = await _cache.getSavedIds(userId);
      ids.remove(listingId);
      await _cache.saveSavedIds(userId, ids);
    } catch (e) {
      throw Exception('Failed to unsave property: $e');
    }
  }

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

  Future<List<String>> getSavedListingIds(String userId) async {
    if (!await isDeviceOnline()) {
      return _cache.getSavedIds(userId);
    }
    try {
      final response = await _client
          .from(SupabaseService.savedPropertiesTable)
          .select('listing_id')
          .eq('user_id', userId)
          .order('saved_at', ascending: false)
          .timeout(const Duration(seconds: 8));

      final ids =
          response.map((item) => item['listing_id'].toString()).toList();
      await _cache.saveSavedIds(userId, ids);
      return ids;
    } catch (e) {
      debugPrint('getSavedListingIds network error, trying cache: $e');
      return _cache.getSavedIds(userId);
    }
  }

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
      debugPrint('getSavedProperties network error, filtering cache: $e');
      final listingIds = await _cache.getSavedIds(userId);
      if (listingIds.isEmpty) return [];
      final cached = await _cache.getProperties();
      return cached.where((p) => listingIds.contains(p.listingId)).toList();
    }
  }

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
