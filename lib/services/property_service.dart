import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property_model.dart';
import '../utils/connectivity_helper.dart';
import 'local_cache_service.dart';
import 'supabase_service.dart';

class PropertyService {
  final SupabaseClient _client = SupabaseService().client;
  final LocalCacheService _cache = LocalCacheService.instance;

  Future<List<PropertyModel>> getAllProperties() async {
    if (!await isDeviceOnline()) {
      final cached = await _cache.getProperties();
      if (cached.isNotEmpty) return cached;
      throw Exception('No cached properties available offline');
    }
    try {
      final response = await _client
          .from(SupabaseService.propertiesTable)
          .select()
          .order('scraped_at', ascending: false)
          .timeout(const Duration(seconds: 12));

      final properties =
          response.map<PropertyModel>((json) => PropertyModel.fromJson(json)).toList();
      await _cache.saveProperties(properties);
      return properties;
    } catch (e) {
      debugPrint('getAllProperties network error, trying cache: $e');
      final cached = await _cache.getProperties();
      if (cached.isNotEmpty) return cached;
      throw Exception('Failed to get properties: $e');
    }
  }

  Future<List<PropertyModel>> searchProperties({
    String? query,
    String? state,
    String? district,
    int? minPrice,
    int? maxPrice,
    int? bedrooms,
    String? propertyType,
    String? tenure,
  }) async {
    try {
      var queryBuilder = _client
          .from(SupabaseService.propertiesTable)
          .select();

      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or(
            'full_address.ilike.%$query%,description.ilike.%$query%'
        );
      }

      if (state != null && state.isNotEmpty) {
        queryBuilder = queryBuilder.eq('state', state);
      }

      if (district != null && district.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('district', '%$district%');
      }

      if (minPrice != null) {
        queryBuilder = queryBuilder.gte('price', minPrice);
      }
      if (maxPrice != null) {
        queryBuilder = queryBuilder.lte('price', maxPrice);
      }

      if (bedrooms != null) {
        queryBuilder = queryBuilder.eq('bedrooms', bedrooms);
      }

      if (propertyType != null && propertyType.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('property_type', '%$propertyType%');
      }

      if (tenure != null && tenure.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('tenure', '%$tenure%');
      }

      final response = await queryBuilder.order('scraped_at', ascending: false);

      return response.map<PropertyModel>((json) => PropertyModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('searchProperties network error, filtering cache: $e');
      return _filterCachedProperties(
        query: query,
        state: state,
        district: district,
        minPrice: minPrice,
        maxPrice: maxPrice,
        bedrooms: bedrooms,
        propertyType: propertyType,
        tenure: tenure,
      );
    }
  }

  Future<List<PropertyModel>> _filterCachedProperties({
    String? query,
    String? state,
    String? district,
    int? minPrice,
    int? maxPrice,
    int? bedrooms,
    String? propertyType,
    String? tenure,
  }) async {
    final cached = await _cache.getProperties();
    return cached.where((p) {
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        final haystack =
            '${p.fullAddress ?? ''} ${p.description ?? ''}'.toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      if (state != null && state.isNotEmpty && p.state != state) return false;
      if (district != null &&
          district.isNotEmpty &&
          !(p.district ?? '').toLowerCase().contains(district.toLowerCase())) {
        return false;
      }
      if (minPrice != null && (p.price == null || p.price! < minPrice)) {
        return false;
      }
      if (maxPrice != null && (p.price == null || p.price! > maxPrice)) {
        return false;
      }
      if (bedrooms != null && p.bedrooms != bedrooms) return false;
      if (propertyType != null &&
          propertyType.isNotEmpty &&
          !(p.propertyType ?? '')
              .toLowerCase()
              .contains(propertyType.toLowerCase())) {
        return false;
      }
      if (tenure != null &&
          tenure.isNotEmpty &&
          !(p.tenure ?? '').toLowerCase().contains(tenure.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<PropertyModel?> getPropertyById(String listingId) async {
    try {
      final response = await _client
          .from(SupabaseService.propertiesTable)
          .select()
          .eq('listing_id', listingId)
          .maybeSingle();

      if (response == null) return null;
      return PropertyModel.fromJson(response);
    } catch (e) {
      debugPrint('getPropertyById network error, trying cache: $e');
      final cached = await _cache.getProperties();
      try {
        return cached.firstWhere((p) => p.listingId == listingId);
      } catch (_) {
        return null;
      }
    }
  }

  Future<List<String>> getStates() async {
    try {
      final response = await _client
          .from(SupabaseService.propertiesTable)
          .select('state')
          .not('state', 'is', null)
          .not('state', 'eq', '');

      final states = <String>{};
      for (var item in response) {
        final state = item['state']?.toString();
        if (state != null && state.isNotEmpty) {
          states.add(state);
        }
      }
      final list = states.toList()..sort();
      await _cache.saveStates(list);
      return list;
    } catch (e) {
      debugPrint('getStates network error, trying cache: $e');
      final cached = await _cache.getStates();
      if (cached.isNotEmpty) return cached;
      final fromProperties = await _cache.getProperties();
      final states = fromProperties
          .map((p) => p.state)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return states;
    }
  }

  Future<List<String>> getDistrictsByState(String state) async {
    try {
      final response = await _client
          .from(SupabaseService.propertiesTable)
          .select('district')
          .eq('state', state)
          .not('district', 'is', null)
          .not('district', 'eq', '');

      final districts = <String>{};
      for (var item in response) {
        final district = item['district']?.toString();
        if (district != null && district.isNotEmpty) {
          districts.add(district);
        }
      }
      return districts.toList()..sort();
    } catch (e) {
      throw Exception('Failed to get districts: $e');
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final countResponse = await _client
          .from(SupabaseService.propertiesTable)
          .select('listing_id');

      final totalCount = countResponse.length;

      final priceResponse = await _client
          .from(SupabaseService.propertiesTable)
          .select('price')
          .not('price', 'is', null)
          .order('price', ascending: true);

      final prices = priceResponse
          .map((p) => p['price'] as int?)
          .where((p) => p != null)
          .cast<int>()
          .toList();

      return {
        'total': totalCount,
        'minPrice': prices.isNotEmpty ? prices.first : 0,
        'maxPrice': prices.isNotEmpty ? prices.last : 0,
        'avgPrice': prices.isNotEmpty ? prices.reduce((a, b) => a + b) ~/ prices.length : 0,
      };
    } catch (e) {
      return {'total': 0, 'minPrice': 0, 'maxPrice': 0, 'avgPrice': 0};
    }
  }

  Future<List<PropertyModel>> getRecentProperties({int limit = 5}) async {
    try {
      final response = await _client
          .from(SupabaseService.propertiesTable)
          .select()
          .order('scraped_at', ascending: false)
          .limit(limit);

      return response.map<PropertyModel>((json) => PropertyModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get recent properties: $e');
    }
  }
}
