import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PropertyPreferenceService {
  final SupabaseClient _client = SupabaseService().client;

  // 创建物业偏好
  Future<PropertyPreferenceModel> createPreference(PropertyPreferenceModel preference) async {
    try {
      final data = preference.toInsertJson();
      data.remove('id');  // 移除 id 让数据库自动生成

      final response = await _client
          .from(SupabaseService.propertyPreferencesTable)
          .insert(data)
          .select()
          .single();

      return PropertyPreferenceModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create property preference: $e');
    }
  }

  // 获取用户的物业偏好
  Future<PropertyPreferenceModel?> getPreferenceByUserId(String userId) async {
    try {
      final response = await _client
          .from(SupabaseService.propertyPreferencesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return PropertyPreferenceModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get property preference: $e');
    }
  }

  // 更新物业偏好
  Future<PropertyPreferenceModel> updatePreference(PropertyPreferenceModel preference) async {
    try {
      // 先获取现有的 preference id
      final existing = await getPreferenceByUserId(preference.userId);
      if (existing == null) {
        throw Exception('Preference not found for user: ${preference.userId}');
      }

      final response = await _client
          .from(SupabaseService.propertyPreferencesTable)
          .update(preference.toUpdateJson())
          .eq('id', existing.id)  // 使用现有的 id
          .select()
          .single();

      return PropertyPreferenceModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update property preference: $e');
    }
  }

  // 删除物业偏好
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

  // 保存或更新物业偏好
  Future<PropertyPreferenceModel> saveOrUpdatePreference(PropertyPreferenceModel preference) async {
    final existing = await getPreferenceByUserId(preference.userId);
    if (existing != null) {
      return await updatePreference(preference);
    } else {
      return await createPreference(preference);
    }
  }

  String? getCurrentUserId() {
    final session = _client.auth.currentSession;
    return session?.user.id;
  }
}