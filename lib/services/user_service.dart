import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/connectivity_helper.dart';
import 'local_cache_service.dart';
import 'supabase_service.dart';

class UserService {
  final SupabaseClient _client = SupabaseService().client;
  final LocalCacheService _cache = LocalCacheService.instance;

  Future<UserModel> createUser(UserModel user) async {
    try {
      final response = await _client
          .from(SupabaseService.usersTable)
          .insert(user.toInsertJson())
          .select()
          .single();

      final created = UserModel.fromJson(response);
      await _cache.saveUser(created);
      return created;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    if (!await isDeviceOnline()) {
      return _cache.getUserByEmail(email);
    }
    try {
      final response = await _client
          .from(SupabaseService.usersTable)
          .select()
          .eq('email', email)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (response == null) return null;
      final user = UserModel.fromJson(response);
      await _cache.saveUser(user);
      return user;
    } catch (e) {
      debugPrint('getUserByEmail network error, trying cache: $e');
      return _cache.getUserByEmail(email);
    }
  }

  Future<UserModel?> getUserById(String id) async {
    if (!await isDeviceOnline()) {
      final cached = await _cache.getUser();
      if (cached != null && cached.id == id) return cached;
      return null;
    }
    try {
      final response = await _client
          .from(SupabaseService.usersTable)
          .select()
          .eq('id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (response == null) return null;
      final user = UserModel.fromJson(response);
      await _cache.saveUser(user);
      return user;
    } catch (e) {
      debugPrint('getUserById network error, trying cache: $e');
      final cached = await _cache.getUser();
      if (cached != null && cached.id == id) return cached;
      return null;
    }
  }

  Future<UserModel> updateUser(UserModel user) async {
    try {
      final response = await _client
          .from(SupabaseService.usersTable)
          .update(user.toUpdateJson())
          .eq('id', user.id)
          .select()
          .single();

      final updated = UserModel.fromJson(response);
      await _cache.saveUser(updated);
      await _cache.markPendingProfile(user.id, false);
      return updated;
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> updateProfileDetails({
    required String userId,
    required String name,
    required String phone,
    required String state,
  }) async {
    final cached = await _cache.getUser();
    final localUser = UserModel(
      id: userId,
      name: name,
      email: cached?.email ?? '',
      phone: phone,
      state: state,
      photo: cached?.photo,
      createdAt: cached?.createdAt,
      updatedAt: DateTime.now(),
    );
    await _cache.saveUser(localUser);

    try {
      await _client.from(SupabaseService.usersTable).update({
        'name': name,
        'phone': phone,
        'state': state,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      await _cache.markPendingProfile(userId, false);
    } catch (e) {
      await _cache.markPendingProfile(userId, true);
      debugPrint('updateProfileDetails offline/queued: $e');
    }
  }

  Future<void> updatePhoto(String userId, String photoUrl) async {
    try {
      await _client.from(SupabaseService.usersTable).update({
        'photo': photoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      final cached = await _cache.getUser();
      if (cached != null) {
        await _cache.saveUser(UserModel(
          id: cached.id,
          name: cached.name,
          email: cached.email,
          phone: cached.phone,
          state: cached.state,
          photo: photoUrl,
          createdAt: cached.createdAt,
          updatedAt: DateTime.now(),
        ));
      }
    } catch (e) {
      throw Exception('Failed to update photo: $e');
    }
  }

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

  String? getCurrentUserId() {
    final session = _client.auth.currentSession;
    return session?.user.id;
  }
}
