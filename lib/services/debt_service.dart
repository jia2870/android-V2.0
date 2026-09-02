import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/connectivity_helper.dart';
import 'local_cache_service.dart';
import 'supabase_service.dart';

class DebtService {
  final SupabaseClient _client = SupabaseService().client;
  final LocalCacheService _cache = LocalCacheService.instance;

  Future<DebtModel> createDebt(DebtModel debt) async {
    try {
      final data = debt.toInsertJson();
      data.remove('id');

      final response = await _client
          .from(SupabaseService.debtsTable)
          .insert(data)
          .select()
          .single();

      final created = DebtModel.fromJson(response);
      final debts = await getDebtsByUserId(created.userId);
      await _cache.saveDebts(created.userId, debts);
      return created;
    } catch (e) {
      throw Exception('Failed to create debt: $e');
    }
  }

  Future<List<DebtModel>> getDebtsByUserId(String userId) async {
    if (!await isDeviceOnline()) {
      return _cache.getDebts(userId);
    }
    try {
      final response = await _client
          .from(SupabaseService.debtsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 8));

      final debts =
          response.map<DebtModel>((json) => DebtModel.fromJson(json)).toList();
      await _cache.saveDebts(userId, debts);
      return debts;
    } catch (e) {
      debugPrint('getDebtsByUserId network error, trying cache: $e');
      return _cache.getDebts(userId);
    }
  }

  Future<DebtModel> updateDebt(DebtModel debt) async {
    try {
      final response = await _client
          .from(SupabaseService.debtsTable)
          .update(debt.toUpdateJson())
          .eq('id', debt.id)
          .select()
          .single();

      final updated = DebtModel.fromJson(response);
      final debts = await getDebtsByUserId(updated.userId);
      await _cache.saveDebts(updated.userId, debts);
      return updated;
    } catch (e) {
      throw Exception('Failed to update debt: $e');
    }
  }

  Future<void> deleteDebt(String debtId) async {
    try {
      await _client
          .from(SupabaseService.debtsTable)
          .delete()
          .eq('id', debtId);
    } catch (e) {
      throw Exception('Failed to delete debt: $e');
    }
  }

  String? getCurrentUserId() {
    final session = _client.auth.currentSession;
    return session?.user.id;
  }
}
