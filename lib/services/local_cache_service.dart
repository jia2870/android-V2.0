import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/property_model.dart';
import 'local_database.dart';
import 'supabase_service.dart';

class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  static const _pendingFinancial = 'financial';
  static const _pendingPreferences = 'preferences';
  static const _pendingProfile = 'profile';

  Future<Database> get _db => LocalDatabase.instance.database;

  Future<void> init() async {
    await LocalDatabase.instance.init();
    await _migrateLegacyPrefsIntoTables();
  }

  Future<void> _migrateLegacyPrefsIntoTables() async {
    final db = await _db;
    final done = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['legacy_tables_hydrated_v1'],
      limit: 1,
    );
    if (done.isNotEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final userRaw = prefs.getString('cache_user');
      if (userRaw != null) {
        try {
          final user = UserModel.fromJson(
            jsonDecode(userRaw) as Map<String, dynamic>,
          );
          await saveUser(user);
        } catch (e) {
          debugPrint('SQLite migrate user: $e');
        }
      }

      final propertiesRaw = prefs.getString('cache_properties');
      if (propertiesRaw != null) {
        try {
          final list = jsonDecode(propertiesRaw) as List<dynamic>;
          final properties = list
              .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
              .toList();
          await saveProperties(properties);
        } catch (e) {
          debugPrint('SQLite migrate properties: $e');
        }
      }

      final states = prefs.getStringList('cache_property_states');
      if (states != null && states.isNotEmpty) {
        await saveStates(states);
      }

      for (final key in prefs.getKeys()) {
        if (key.startsWith('cache_financial_')) {
          final userId = key.substring('cache_financial_'.length);
          final raw = prefs.getString(key);
          if (raw == null) continue;
          try {
            final profile = FinancialProfileModel.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            );
            await saveFinancial(userId, profile);
          } catch (e) {
            debugPrint('SQLite migrate financial: $e');
          }
        } else if (key.startsWith('cache_debts_')) {
          final userId = key.substring('cache_debts_'.length);
          final raw = prefs.getString(key);
          if (raw == null) continue;
          try {
            final list = jsonDecode(raw) as List<dynamic>;
            final debts = list
                .map((e) => DebtModel.fromJson(e as Map<String, dynamic>))
                .toList();
            await saveDebts(userId, debts);
          } catch (e) {
            debugPrint('SQLite migrate debts: $e');
          }
        } else if (key.startsWith('cache_preferences_')) {
          final userId = key.substring('cache_preferences_'.length);
          final raw = prefs.getString(key);
          if (raw == null) continue;
          try {
            final preference = PropertyPreferenceModel.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            );
            await savePreferences(userId, preference);
          } catch (e) {
            debugPrint('SQLite migrate preferences: $e');
          }
        } else if (key.startsWith('cache_saved_ids_')) {
          final userId = key.substring('cache_saved_ids_'.length);
          final ids = prefs.getStringList(key) ?? [];
          await saveSavedIds(userId, ids);
        } else if (key.startsWith('cache_pending_financial_')) {
          final userId = key.substring('cache_pending_financial_'.length);
          await markPendingFinancial(userId, prefs.getBool(key) ?? false);
        } else if (key.startsWith('cache_pending_preferences_')) {
          final userId = key.substring('cache_pending_preferences_'.length);
          await markPendingPreferences(userId, prefs.getBool(key) ?? false);
        } else if (key.startsWith('cache_pending_profile_')) {
          final userId = key.substring('cache_pending_profile_'.length);
          await markPendingProfile(userId, prefs.getBool(key) ?? false);
        }
      }
    } catch (e) {
      debugPrint('SQLite hydrate from prefs: $e');
    }

    await db.insert(
      'app_meta',
      {'key': 'legacy_tables_hydrated_v1', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveUser(UserModel user) async {
    final db = await _db;
    await db.insert(
      'users',
      {
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'phone': user.phone,
        'state': user.state,
        'photo': user.photo,
        'created_at': user.createdAt?.toIso8601String(),
        'updated_at': user.updatedAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> getUser() async {
    final db = await _db;
    final rows = await db.query('users', limit: 1);
    if (rows.isEmpty) return null;
    try {
      return _userFromRow(rows.first);
    } catch (e) {
      debugPrint('LocalCache getUser error: $e');
      return null;
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return _userFromRow(rows.first);
    } catch (e) {
      debugPrint('LocalCache getUserByEmail error: $e');
      return null;
    }
  }

  Future<void> saveFinancial(String userId, FinancialProfileModel profile) async {
    final db = await _db;
    await db.insert(
      'financial_profiles',
      {
        'user_id': userId,
        'id': profile.id,
        'monthly_salary': profile.monthlySalary,
        'other_income': profile.otherIncome,
        'commitments': profile.commitments,
        'savings': profile.savings,
        'down_payment': profile.downPayment,
        'affordability_score': profile.affordabilityScore,
        'recommended_budget': profile.recommendedBudget,
        'risk_level': profile.riskLevel,
        'created_at': profile.createdAt?.toIso8601String(),
        'updated_at': profile.updatedAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<FinancialProfileModel?> getFinancial(String userId) async {
    final db = await _db;
    final rows = await db.query(
      'financial_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return _financialFromRow(rows.first);
    } catch (e) {
      debugPrint('LocalCache getFinancial error: $e');
      return null;
    }
  }

  Future<void> saveDebts(String userId, List<DebtModel> debts) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('debts', where: 'user_id = ?', whereArgs: [userId]);
      for (final d in debts) {
        await txn.insert(
          'debts',
          {
            'id': d.id,
            'user_id': userId,
            'type': d.type,
            'name': d.name,
            'total_amount': d.totalAmount,
            'monthly_payment': d.monthlyPayment,
            'interest_rate': d.interestRate,
            'remaining_months': d.remainingMonths,
            'created_at': d.createdAt?.toIso8601String(),
            'updated_at': d.updatedAt?.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<DebtModel>> getDebts(String userId) async {
    final db = await _db;
    try {
      final rows = await db.query(
        'debts',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return rows.map(_debtFromRow).toList();
    } catch (e) {
      debugPrint('LocalCache getDebts error: $e');
      return [];
    }
  }

  Future<void> savePreferences(
    String userId,
    PropertyPreferenceModel preference,
  ) async {
    final db = await _db;
    await db.insert(
      'property_preferences',
      {
        'user_id': userId,
        'id': preference.id,
        'purpose': preference.purpose,
        'property_type': preference.propertyType,
        'price_range': preference.priceRange,
        'bedrooms': preference.bedrooms,
        'preferred_state': preference.preferredState,
        'important_factors': jsonEncode(preference.importantFactors),
        'created_at': preference.createdAt?.toIso8601String(),
        'updated_at': preference.updatedAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PropertyPreferenceModel?> getPreferences(String userId) async {
    final db = await _db;
    final rows = await db.query(
      'property_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return _preferenceFromRow(rows.first);
    } catch (e) {
      debugPrint('LocalCache getPreferences error: $e');
      return null;
    }
  }

  Future<void> saveSavedIds(String userId, List<String> ids) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('saved_ids', where: 'user_id = ?', whereArgs: [userId]);
      for (final id in ids) {
        await txn.insert(
          'saved_ids',
          {'user_id': userId, 'listing_id': id},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<String>> getSavedIds(String userId) async {
    final db = await _db;
    final rows = await db.query(
      'saved_ids',
      columns: ['listing_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((r) => r['listing_id'] as String).toList();
  }

  Future<void> saveProperties(List<PropertyModel> properties) async {
    final db = await _db;
    final capped = properties.take(200).toList();
    await db.transaction((txn) async {
      await txn.delete('properties');
      for (final p in capped) {
        await txn.insert(
          'properties',
          {
            'listing_id': p.listingId,
            'price': p.price,
            'property_type': p.propertyType,
            'bedrooms': p.bedrooms,
            'bathrooms': p.bathrooms,
            'built_up': p.builtUp,
            'full_address': p.fullAddress,
            'district': p.district,
            'state': p.state,
            'tenure': p.tenure,
            'description': p.description,
            'facilities': p.facilities,
            'photo_urls': p.photoUrls,
            'listing_url': p.listingUrl,
            'agent_name': p.agentName,
            'lat': p.lat,
            'lng': p.lng,
            'scraped_at': p.scrapedAt?.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<PropertyModel>> getProperties() async {
    final db = await _db;
    try {
      final rows = await db.query('properties');
      return rows.map(_propertyFromRow).toList();
    } catch (e) {
      debugPrint('LocalCache getProperties error: $e');
      return [];
    }
  }

  Future<void> saveStates(List<String> states) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('property_states');
      for (final state in states) {
        await txn.insert(
          'property_states',
          {'state': state},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<String>> getStates() async {
    final db = await _db;
    final rows = await db.query('property_states');
    return rows.map((r) => r['state'] as String).toList();
  }

  Future<void> markPendingFinancial(String userId, bool pending) async {
    await _setPending(userId, _pendingFinancial, pending);
  }

  Future<bool> hasPendingFinancial(String userId) async {
    return _getPending(userId, _pendingFinancial);
  }

  Future<void> markPendingPreferences(String userId, bool pending) async {
    await _setPending(userId, _pendingPreferences, pending);
  }

  Future<bool> hasPendingPreferences(String userId) async {
    return _getPending(userId, _pendingPreferences);
  }

  Future<void> markPendingProfile(String userId, bool pending) async {
    await _setPending(userId, _pendingProfile, pending);
  }

  Future<bool> hasPendingProfile(String userId) async {
    return _getPending(userId, _pendingProfile);
  }

  Future<void> _setPending(String userId, String kind, bool pending) async {
    final db = await _db;
    await db.insert(
      'pending_flags',
      {
        'user_id': userId,
        'kind': kind,
        'pending': pending ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> _getPending(String userId, String kind) async {
    final db = await _db;
    final rows = await db.query(
      'pending_flags',
      where: 'user_id = ? AND kind = ?',
      whereArgs: [userId, kind],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['pending'] as int? ?? 0) == 1;
  }

  Future<void> clearUserData(String? userId) async {
    final db = await _db;
    await db.delete('users');
    if (userId == null || userId.isEmpty) return;
    await db.delete(
      'financial_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete('debts', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete(
      'property_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete('saved_ids', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('pending_flags', where: 'user_id = ?', whereArgs: [userId]);
  }

  UserModel _userFromRow(Map<String, Object?> row) {
    return UserModel(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      state: row['state'] as String? ?? 'Selangor',
      photo: row['photo'] as String?,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  FinancialProfileModel _financialFromRow(Map<String, Object?> row) {
    return FinancialProfileModel(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      monthlySalary: (row['monthly_salary'] as num?)?.toDouble() ?? 0,
      otherIncome: (row['other_income'] as num?)?.toDouble() ?? 0,
      commitments: (row['commitments'] as num?)?.toDouble() ?? 0,
      savings: (row['savings'] as num?)?.toDouble() ?? 0,
      downPayment: (row['down_payment'] as num?)?.toDouble() ?? 0,
      affordabilityScore:
          (row['affordability_score'] as num?)?.toDouble() ?? 0,
      recommendedBudget:
          (row['recommended_budget'] as num?)?.toDouble() ?? 0,
      riskLevel: row['risk_level'] as String? ?? 'Low',
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  DebtModel _debtFromRow(Map<String, Object?> row) {
    return DebtModel(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      type: row['type'] as String? ?? '',
      name: row['name'] as String? ?? '',
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
      monthlyPayment: (row['monthly_payment'] as num?)?.toDouble() ?? 0,
      interestRate: (row['interest_rate'] as num?)?.toDouble() ?? 0,
      remainingMonths: (row['remaining_months'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  PropertyPreferenceModel _preferenceFromRow(Map<String, Object?> row) {
    List<String> factors = const [];
    final rawFactors = row['important_factors'];
    if (rawFactors is String && rawFactors.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawFactors);
        if (decoded is List) {
          factors = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        factors = [];
      }
    }
    return PropertyPreferenceModel(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      purpose: row['purpose'] as String? ?? 'Own Stay',
      propertyType: row['property_type'] as String? ?? 'Apartment',
      priceRange: row['price_range'] as String? ?? 'RM200k–300k',
      bedrooms: (row['bedrooms'] as num?)?.toInt() ?? 3,
      preferredState: row['preferred_state'] as String? ?? 'Selangor',
      importantFactors: factors,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  PropertyModel _propertyFromRow(Map<String, Object?> row) {
    return PropertyModel.fromJson({
      'listing_id': row['listing_id'],
      'price': row['price'],
      'property_type': row['property_type'],
      'bedrooms': row['bedrooms'],
      'bathrooms': row['bathrooms'],
      'built_up': row['built_up'],
      'full_address': row['full_address'],
      'district': row['district'],
      'state': row['state'],
      'tenure': row['tenure'],
      'description': row['description'],
      'facilities': row['facilities'],
      'photo_urls': row['photo_urls'],
      'listing_url': row['listing_url'],
      'agent_name': row['agent_name'],
      'lat': row['lat'],
      'lng': row['lng'],
      'scraped_at': row['scraped_at'],
    });
  }

  DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
