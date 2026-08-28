import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/connectivity_helper.dart';
import 'local_cache_service.dart';
import 'supabase_service.dart';

class FinancialService {
  final SupabaseClient _client = SupabaseService().client;
  final LocalCacheService _cache = LocalCacheService.instance;

  Future<FinancialProfileModel> createProfile(FinancialProfileModel profile) async {
    try {
      final data = profile.toInsertJson();
      data.remove('id');

      final response = await _client
          .from(SupabaseService.financialProfilesTable)
          .insert(data)
          .select()
          .single();

      final created = FinancialProfileModel.fromJson(response);
      await _cache.saveFinancial(created.userId, created);
      await _cache.markPendingFinancial(created.userId, false);
      return created;
    } catch (e) {
      await _cache.saveFinancial(profile.userId, profile);
      await _cache.markPendingFinancial(profile.userId, true);
      debugPrint('createProfile offline/queued: $e');
      return profile;
    }
  }

  Future<FinancialProfileModel?> getProfileByUserId(String userId) async {
    if (!await isDeviceOnline()) {
      return _cache.getFinancial(userId);
    }
    try {
      final response = await _client
          .from(SupabaseService.financialProfilesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (response == null) return await _cache.getFinancial(userId);
      final profile = FinancialProfileModel.fromJson(response);
      await _cache.saveFinancial(userId, profile);
      return profile;
    } catch (e) {
      debugPrint('getProfileByUserId network error, trying cache: $e');
      return _cache.getFinancial(userId);
    }
  }

  Future<FinancialProfileModel> updateProfile(FinancialProfileModel profile) async {
    await _cache.saveFinancial(profile.userId, profile);
    try {
      final existing = await getProfileByUserId(profile.userId);
      if (existing == null) {
        throw Exception('Profile not found for user: ${profile.userId}');
      }

      final response = await _client
          .from(SupabaseService.financialProfilesTable)
          .update(profile.toUpdateJson())
          .eq('id', existing.id)
          .select()
          .single();

      final updated = FinancialProfileModel.fromJson(response);
      await _cache.saveFinancial(updated.userId, updated);
      await _cache.markPendingFinancial(updated.userId, false);
      return updated;
    } catch (e) {
      await _cache.markPendingFinancial(profile.userId, true);
      debugPrint('updateProfile offline/queued: $e');
      return profile;
    }
  }

  Future<void> deleteProfile(String userId) async {
    try {
      await _client
          .from(SupabaseService.financialProfilesTable)
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete financial profile: $e');
    }
  }

  Future<FinancialProfileModel> saveOrUpdateProfile(FinancialProfileModel profile) async {
    await _cache.saveFinancial(profile.userId, profile);
    try {
      final existing = await _client
          .from(SupabaseService.financialProfilesTable)
          .select()
          .eq('user_id', profile.userId)
          .maybeSingle();

      if (existing != null) {
        final response = await _client
            .from(SupabaseService.financialProfilesTable)
            .update(profile.toUpdateJson())
            .eq('id', existing['id'])
            .select()
            .single();
        final updated = FinancialProfileModel.fromJson(response);
        await _cache.saveFinancial(updated.userId, updated);
        await _cache.markPendingFinancial(updated.userId, false);
        return updated;
      }

      return await createProfile(profile);
    } catch (e) {
      await _cache.markPendingFinancial(profile.userId, true);
      debugPrint('saveOrUpdateProfile offline/queued: $e');
      return profile;
    }
  }

  Future<void> syncPending(String userId) async {
    if (!await _cache.hasPendingFinancial(userId)) return;
    final cached = await _cache.getFinancial(userId);
    if (cached == null) {
      await _cache.markPendingFinancial(userId, false);
      return;
    }
    await saveOrUpdateProfile(cached);
  }

  String? getCurrentUserId() {
    final session = _client.auth.currentSession;
    return session?.user.id;
  }
}
