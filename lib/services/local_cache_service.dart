import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/property_model.dart';
import 'supabase_service.dart';

class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  static const _userKey = 'cache_user';
  static const _financialKey = 'cache_financial';
  static const _debtsKey = 'cache_debts';
  static const _preferencesKey = 'cache_preferences';
  static const _savedIdsKey = 'cache_saved_ids';
  static const _propertiesKey = 'cache_properties';
  static const _statesKey = 'cache_property_states';
  static const _pendingFinancialKey = 'cache_pending_financial';
  static const _pendingPreferencesKey = 'cache_pending_preferences';
  static const _pendingProfileKey = 'cache_pending_profile';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String _scoped(String key, String userId) => '${key}_$userId';

  Future<void> saveUser(UserModel user) async {
    final prefs = await _prefs;
    await prefs.setString(_userKey, jsonEncode(_userToJson(user)));
  }

  Future<UserModel?> getUser() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('LocalCache getUser error: $e');
      return null;
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final user = await getUser();
    if (user == null) return null;
    if (user.email.toLowerCase() != email.trim().toLowerCase()) return null;
    return user;
  }

  Future<void> saveFinancial(String userId, FinancialProfileModel profile) async {
    final prefs = await _prefs;
    await prefs.setString(
      _scoped(_financialKey, userId),
      jsonEncode(_financialToJson(profile)),
    );
  }

  Future<FinancialProfileModel?> getFinancial(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_scoped(_financialKey, userId));
    if (raw == null) return null;
    try {
      return FinancialProfileModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('LocalCache getFinancial error: $e');
      return null;
    }
  }

  Future<void> saveDebts(String userId, List<DebtModel> debts) async {
    final prefs = await _prefs;
    final list = debts.map(_debtToJson).toList();
    await prefs.setString(_scoped(_debtsKey, userId), jsonEncode(list));
  }

  Future<List<DebtModel>> getDebts(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_scoped(_debtsKey, userId));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => DebtModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('LocalCache getDebts error: $e');
      return [];
    }
  }

  Future<void> savePreferences(
    String userId,
    PropertyPreferenceModel preference,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      _scoped(_preferencesKey, userId),
      jsonEncode(_preferenceToJson(preference)),
    );
  }

  Future<PropertyPreferenceModel?> getPreferences(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_scoped(_preferencesKey, userId));
    if (raw == null) return null;
    try {
      return PropertyPreferenceModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('LocalCache getPreferences error: $e');
      return null;
    }
  }

  Future<void> saveSavedIds(String userId, List<String> ids) async {
    final prefs = await _prefs;
    await prefs.setStringList(_scoped(_savedIdsKey, userId), ids);
  }

  Future<List<String>> getSavedIds(String userId) async {
    final prefs = await _prefs;
    return prefs.getStringList(_scoped(_savedIdsKey, userId)) ?? [];
  }

  Future<void> saveProperties(List<PropertyModel> properties) async {
    final prefs = await _prefs;
    final capped = properties.take(200).map(_propertyToJson).toList();
    await prefs.setString(_propertiesKey, jsonEncode(capped));
  }

  Future<List<PropertyModel>> getProperties() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_propertiesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('LocalCache getProperties error: $e');
      return [];
    }
  }

  Future<void> saveStates(List<String> states) async {
    final prefs = await _prefs;
    await prefs.setStringList(_statesKey, states);
  }

  Future<List<String>> getStates() async {
    final prefs = await _prefs;
    return prefs.getStringList(_statesKey) ?? [];
  }

  Future<void> markPendingFinancial(String userId, bool pending) async {
    final prefs = await _prefs;
    await prefs.setBool(_scoped(_pendingFinancialKey, userId), pending);
  }

  Future<bool> hasPendingFinancial(String userId) async {
    final prefs = await _prefs;
    return prefs.getBool(_scoped(_pendingFinancialKey, userId)) ?? false;
  }

  Future<void> markPendingPreferences(String userId, bool pending) async {
    final prefs = await _prefs;
    await prefs.setBool(_scoped(_pendingPreferencesKey, userId), pending);
  }

  Future<bool> hasPendingPreferences(String userId) async {
    final prefs = await _prefs;
    return prefs.getBool(_scoped(_pendingPreferencesKey, userId)) ?? false;
  }

  Future<void> markPendingProfile(String userId, bool pending) async {
    final prefs = await _prefs;
    await prefs.setBool(_scoped(_pendingProfileKey, userId), pending);
  }

  Future<bool> hasPendingProfile(String userId) async {
    final prefs = await _prefs;
    return prefs.getBool(_scoped(_pendingProfileKey, userId)) ?? false;
  }

  Future<void> clearUserData(String? userId) async {
    final prefs = await _prefs;
    await prefs.remove(_userKey);
    if (userId == null || userId.isEmpty) return;
    await prefs.remove(_scoped(_financialKey, userId));
    await prefs.remove(_scoped(_debtsKey, userId));
    await prefs.remove(_scoped(_preferencesKey, userId));
    await prefs.remove(_scoped(_savedIdsKey, userId));
    await prefs.remove(_scoped(_pendingFinancialKey, userId));
    await prefs.remove(_scoped(_pendingPreferencesKey, userId));
    await prefs.remove(_scoped(_pendingProfileKey, userId));
  }

  Map<String, dynamic> _userToJson(UserModel user) => {
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'phone': user.phone,
        'state': user.state,
        'photo': user.photo,
        'created_at': user.createdAt?.toIso8601String(),
        'updated_at': user.updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> _financialToJson(FinancialProfileModel p) => {
        'id': p.id,
        'user_id': p.userId,
        'monthly_salary': p.monthlySalary,
        'other_income': p.otherIncome,
        'commitments': p.commitments,
        'savings': p.savings,
        'down_payment': p.downPayment,
        'affordability_score': p.affordabilityScore,
        'recommended_budget': p.recommendedBudget,
        'risk_level': p.riskLevel,
        'created_at': p.createdAt?.toIso8601String(),
        'updated_at': p.updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> _debtToJson(DebtModel d) => {
        'id': d.id,
        'user_id': d.userId,
        'type': d.type,
        'name': d.name,
        'total_amount': d.totalAmount,
        'monthly_payment': d.monthlyPayment,
        'interest_rate': d.interestRate,
        'remaining_months': d.remainingMonths,
        'created_at': d.createdAt?.toIso8601String(),
        'updated_at': d.updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> _preferenceToJson(PropertyPreferenceModel p) => {
        'id': p.id,
        'user_id': p.userId,
        'purpose': p.purpose,
        'property_type': p.propertyType,
        'price_range': p.priceRange,
        'bedrooms': p.bedrooms,
        'preferred_state': p.preferredState,
        'important_factors': p.importantFactors,
        'created_at': p.createdAt?.toIso8601String(),
        'updated_at': p.updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> _propertyToJson(PropertyModel p) => {
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
      };
}
