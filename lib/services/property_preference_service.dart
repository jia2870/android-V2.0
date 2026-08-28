import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/connectivity_helper.dart';
import 'local_cache_service.dart';
import 'supabase_service.dart';

class PropertyPreferenceService {
  final SupabaseClient _client = SupabaseService().client;
  final LocalCacheService _cache = LocalCacheService.instance;

  Future<PropertyPreferenceModel> createPreference(PropertyPreferenceModel preference) async {
    try {
      final data = preference.toInsertJson();
      data.remove('id');

      final response = await _client
          .from(SupabaseService.propertyPreferencesTable)
          .insert(data)
          .select()
          .single();

      final created = PropertyPreferenceModel.fromJson(response);
      await _cache.savePreferences(created.userId, created);
      await _cache.markPendingPreferences(created.userId, false);
      return created;
    } catch (e) {
      await _cache.savePreferences(preference.userId, preference);
      await _cache.markPendingPreferences(preference.userId, true);
      debugPrint('createPreference offline/queued: $e');
      return preference;
    }
  }

  Future<PropertyPreferenceModel?> getPreferenceByUserId(String userId) async {
    if (!await isDeviceOnline()) {
      return _cache.getPreferences(userId);
    }
    try {
      final response = await _client
          .from(SupabaseService.propertyPreferencesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (response == null) return await _cache.getPreferences(userId);
      final preference = PropertyPreferenceModel.fromJson(response);
      await _cache.savePreferences(userId, preference);
      return preference;
    } catch (e) {
      debugPrint('getPreferenceByUserId network error, trying cache: $e');
      return _cache.getPreferences(userId);
    }
  }

  Future<PropertyPreferenceModel> updatePreference(PropertyPreferenceModel preference) async {
    await _cache.savePreferences(preference.userId, preference);
    try {
      final existing = await getPreferenceByUserId(preference.userId);
      if (existing == null) {
        throw Exception('Preference not found for user: ${preference.userId}');
      }

      final response = await _client
          .from(SupabaseService.propertyPreferencesTable)
          .update(preference.toUpdateJson())
          .eq('id', existing.id)
          .select()
          .single();

      final updated = PropertyPreferenceModel.fromJson(response);
      await _cache.savePreferences(updated.userId, updated);
      await _cache.markPendingPreferences(updated.userId, false);
      return updated;
    } catch (e) {
      await _cache.markPendingPreferences(preference.userId, true);
      debugPrint('updatePreference offline/queued: $e');
      return preference;
    }
  }

  Future<void> deletePreference(String userId) async {
    try {
      await _client
          .from(SupabaseService.propertyPreferencesTable)
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete property preference: $e');
    }
  }

  Future<PropertyPreferenceModel> saveOrUpdatePreference(PropertyPreferenceModel preference) async {
    await _cache.savePreferences(preference.userId, preference);
    try {
      final existing = await _client
          .from(SupabaseService.propertyPreferencesTable)
          .select()
          .eq('user_id', preference.userId)
          .maybeSingle();

      if (existing != null) {
        final response = await _client
            .from(SupabaseService.propertyPreferencesTable)
            .update(preference.toUpdateJson())
            .eq('id', existing['id'])
            .select()
            .single();
        final updated = PropertyPreferenceModel.fromJson(response);
        await _cache.savePreferences(updated.userId, updated);
        await _cache.markPendingPreferences(updated.userId, false);
        return updated;
      }

      return await createPreference(preference);
    } catch (e) {
      await _cache.markPendingPreferences(preference.userId, true);
      debugPrint('saveOrUpdatePreference offline/queued: $e');
      return preference;
    }
  }

  Future<void> syncPending(String userId) async {
    if (!await _cache.hasPendingPreferences(userId)) return;
    final cached = await _cache.getPreferences(userId);
    if (cached == null) {
      await _cache.markPendingPreferences(userId, false);
      return;
    }
    await saveOrUpdatePreference(cached);
  }

  String? getCurrentUserId() {
    final session = _client.auth.currentSession;
    return session?.user.id;
  }
}
