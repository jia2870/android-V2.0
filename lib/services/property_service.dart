import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property_model.dart';
import 'supabase_service.dart';

class PropertyService {
  final SupabaseClient _client = SupabaseService().client;

  // 获取所有房产
  Future<List<PropertyModel>> getAllProperties() async {
    try {
      final response = await _client
          .from(SupabaseService.propertiesTable)
          .select()
          .order('scraped_at', ascending: false);

      return response.map<PropertyModel>((json) => PropertyModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get properties: $e');
    }
  }

  // 搜索房产 - 修复 title 列不存在的问题
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

      // 搜索关键字 - 使用 full_address 和 description 代替 title
      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or(
            'full_address.ilike.%$query%,description.ilike.%$query%'
        );
      }

      // 州属过滤
      if (state != null && state.isNotEmpty) {
        queryBuilder = queryBuilder.eq('state', state);
      }

      // 地区过滤
      if (district != null && district.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('district', '%$district%');
      }

      // 价格过滤
      if (minPrice != null) {
        queryBuilder = queryBuilder.gte('price', minPrice);
      }
      if (maxPrice != null) {
        queryBuilder = queryBuilder.lte('price', maxPrice);
      }

      // 卧室数过滤
      if (bedrooms != null) {
        queryBuilder = queryBuilder.eq('bedrooms', bedrooms);
      }

      // 房产类型过滤
      if (propertyType != null && propertyType.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('property_type', '%$propertyType%');
      }

      // 产权过滤
      if (tenure != null && tenure.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('tenure', '%$tenure%');
      }

      final response = await queryBuilder.order('scraped_at', ascending: false);

      return response.map<PropertyModel>((json) => PropertyModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search properties: $e');
    }
  }

  // 根据 listing_id 获取房产详情
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
      throw Exception('Failed to get property: $e');
    }
  }

  // 获取州属列表
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
      return states.toList()..sort();
    } catch (e) {
      throw Exception('Failed to get states: $e');
    }
  }

  // 获取地区列表（按州属）
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

  // 获取统计信息
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

  // 获取最近的房产
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