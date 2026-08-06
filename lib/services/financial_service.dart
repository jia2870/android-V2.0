import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class FinancialService {
  final SupabaseClient _client = SupabaseService().client;

  // 创建财务档案
  Future<FinancialProfileModel> createProfile(FinancialProfileModel profile) async {
    try {
      final data = profile.toInsertJson();
      // 移除 id 字段让数据库自动生成
      data.remove('id');

      final response = await _client
          .from(SupabaseService.financialProfilesTable)
          .insert(data)
          .select()
          .single();

      return FinancialProfileModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create financial profile: $e');
    }
  }

  // 获取用户的财务档案
  Future<FinancialProfileModel?> getProfileByUserId(String userId) async {
    try {
      final response = await _client
          .from(SupabaseService.financialProfilesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return FinancialProfileModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get financial profile: $e');
    }
  }

  // 更新财务档案
  Future<FinancialProfileModel> updateProfile(FinancialProfileModel profile) async {
    try {
      // 先获取现有的 profile id
      final existing = await getProfileByUserId(profile.userId);
      if (existing == null) {
        throw Exception('Profile not found for user: ${profile.userId}');
      }

      final response = await _client
          .from(SupabaseService.financialProfilesTable)
          .update(profile.toUpdateJson())
          .eq('id', existing.id)  // 使用现有的 id
          .select()
          .single();

      return FinancialProfileModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update financial profile: $e');
    }
  }

  // 删除财务档案
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

  // 保存或更新财务档案
  Future<FinancialProfileModel> saveOrUpdateProfile(FinancialProfileModel profile) async {
    final existing = await getProfileByUserId(profile.userId);
    if (existing != null) {
      return await updateProfile(profile);
    } else {
      return await createProfile(profile);
    }
  }

  String? getCurrentUserId() {
    final session = _client.auth.currentSession;
    return session?.user.id;
  }
}