import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_cache_service.dart';
import 'supabase_service.dart';

class FinancialService {
  final SupabaseClient _client = SupabaseService().client;
  final LocalCacheService _cache = LocalCacheService.instance;
  static const Duration _networkTimeout = Duration(seconds: 5);

  Future<FinancialProfileModel> createProfile(FinancialProfileModel profile) async {
    final synced = await _upsertProfile(profile);
    return synced ?? profile;
  }

  Future<FinancialProfileModel?> getProfileByUserId(String userId) async {
    try {
      final response = await _client
          .from(SupabaseService.financialProfilesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_networkTimeout);

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
    final synced = await _upsertProfile(profile);
    if (synced != null) return synced;
    await _cache.markPendingFinancial(profile.userId, true);
    return profile;
  }

  Future<void> deleteProfile(String userId) async {
    try {
      await _client
          .from(SupabaseService.financialProfilesTable)
          .delete()
          .eq('user_id', userId)
          .timeout(_networkTimeout);
    } catch (e) {
      throw Exception('Failed to delete financial profile: $e');
    }
  }

  Future<bool> saveOrUpdateProfile(FinancialProfileModel profile) async {
    await _cache.saveFinancial(profile.userId, profile);
    final synced = await _upsertProfile(profile);
    if (synced != null) {
      await _cache.markPendingFinancial(profile.userId, false);
      return true;
    }
    await _cache.markPendingFinancial(profile.userId, true);
    return false;
  }

  /// One round-trip upsert on user_id instead of select + update/insert.
  Future<FinancialProfileModel?> _upsertProfile(FinancialProfileModel profile) async {
    try {
      final data = profile.toInsertJson();
      data.remove('id');

      final response = await _client
          .from(SupabaseService.financialProfilesTable)
          .upsert(data, onConflict: 'user_id')
          .select()
          .single()
          .timeout(_networkTimeout);

      final saved = FinancialProfileModel.fromJson(response);
      await _cache.saveFinancial(saved.userId, saved);
      debugPrint(
        'SAVE supabase ok: salary=${saved.monthlySalary} '
        'budget=${saved.recommendedBudget}',
      );
      return saved;
    } catch (e, stack) {
      debugPrint(
        'SAVE supabase failed: $e | '
        'salary=${profile.monthlySalary} budget=${profile.recommendedBudget}\n$stack',
      );
      return null;
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
