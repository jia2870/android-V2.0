import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class DebtService {
  final SupabaseClient _client = SupabaseService().client;

  // 创建债务
  Future<DebtModel> createDebt(DebtModel debt) async {
    try {
      final data = debt.toInsertJson();
      data.remove('id');  // 移除 id 让数据库自动生成

      final response = await _client
          .from(SupabaseService.debtsTable)
          .insert(data)
          .select()
          .single();

      return DebtModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create debt: $e');
    }
  }

  // 获取用户的所有债务
  Future<List<DebtModel>> getDebtsByUserId(String userId) async {
    try {
      final response = await _client
          .from(SupabaseService.debtsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map<DebtModel>((json) => DebtModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get debts: $e');
    }
  }

  // 更新债务
  Future<DebtModel> updateDebt(DebtModel debt) async {
    try {
      final response = await _client
          .from(SupabaseService.debtsTable)
          .update(debt.toUpdateJson())
          .eq('id', debt.id)  // 使用 id
          .select()
          .single();

      return DebtModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update debt: $e');
    }
  }

  // 删除债务
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

  // 获取当前用户 ID
  String? getCurrentUserId() {
    final session = _client.auth.currentSession;
    return session?.user.id;
  }
}