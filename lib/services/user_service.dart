import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class UserService {
  final SupabaseClient _client = SupabaseService().client;

  // 创建用户
  Future<UserModel> createUser(UserModel user) async {
    try {
      final response = await _client
          .from(SupabaseService.usersTable)
          .insert(user.toInsertJson())
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // 获取用户
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final response = await _client
          .from(SupabaseService.usersTable)
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // 根据 ID 获取用户
  Future<UserModel?> getUserById(String id) async {
    try {
      final response = await _client
          .from(SupabaseService.usersTable)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // 更新用户
  Future<UserModel> updateUser(UserModel user) async {
    try {
      final response = await _client
          .from(SupabaseService.usersTable)
          .update(user.toUpdateJson())
          .eq('id', user.id)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // 删除用户
  Future<void> deleteUser(String userId) async {
    try {
      await _client
          .from(SupabaseService.usersTable)
          .delete()
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // 检查用户是否存在
  Future<bool> userExists(String email) async {
    try {
      final response = await _client
          .from(SupabaseService.usersTable)
          .select()
          .eq('email', email)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // 获取当前用户 ID
  String? getCurrentUserId() {
    final session = _client.auth.currentSession;
    return session?.user.id;
  }
}