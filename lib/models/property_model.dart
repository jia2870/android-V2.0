import 'package:flutter/material.dart';

class PropertyModel {
  final String listingId;
  final int? price;
  final String? propertyType;
  final int? bedrooms;
  final int? bathrooms;
  final String? builtUp;
  final String? fullAddress;
  final String? district;
  final String? state;
  final String? tenure;
  final String? description;
  final String? facilities;
  final String? photoUrls;
  final String? listingUrl;
  final String? agentName;
  final double? lat;
  final double? lng;
  final DateTime? scrapedAt;

  // 系统提供的图片 URL 前缀（需要过滤掉）
  static const List<String> _systemImagePrefixes = [
    'https://cdn.pgimgs.com/hive-ui/static/',
    'https://cdn.pgimgs.com/hive-ui/',
    'https://bat.bing.com/',
    'https://sp.analytics.yahoo.com/',
  ];

  PropertyModel({
    required this.listingId,
    this.price,
    this.propertyType,
    this.bedrooms,
    this.bathrooms,
    this.builtUp,
    this.fullAddress,
    this.district,
    this.state,
    this.tenure,
    this.description,
    this.facilities,
    this.photoUrls,
    this.listingUrl,
    this.agentName,
    this.lat,
    this.lng,
    this.scrapedAt,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      listingId: json['listing_id'] ?? '',
      price: json['price'] != null ? (json['price'] as num).toInt() : null,
      propertyType: json['property_type'],
      bedrooms: json['bedrooms'] != null ? (json['bedrooms'] as num).toInt() : null,
      bathrooms: json['bathrooms'] != null ? (json['bathrooms'] as num).toInt() : null,
      builtUp: json['built_up'],
      fullAddress: json['full_address'],
      district: json['district'],
      state: json['state'],
      tenure: json['tenure'],
      description: json['description'],
      facilities: json['facilities'],
      photoUrls: json['photo_urls'],
      listingUrl: json['listing_url'],
      agentName: json['agent_name'],
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
      scrapedAt: json['scraped_at'] != null ? DateTime.parse(json['scraped_at']) : null,
    );
  }

  // 获取格式化价格
  String get formattedPrice {
    if (price != null) {
      if (price! >= 1000000) {
        return 'RM ${(price! / 1000000).toStringAsFixed(1)}M';
      } else if (price! >= 1000) {
        return 'RM ${(price! / 1000).toStringAsFixed(0)}K';
      }
      return 'RM ${price!.toStringAsFixed(0)}';
    }
    return 'Price on Request';
  }

  // 获取价格显示
  String get priceDisplay {
    if (price != null) {
      return 'RM ${price!.toStringAsFixed(0)}';
    }
    return 'Price on Request';
  }

  // 获取房产类型图标
  IconData get propertyTypeIcon {
    if (propertyType == null || propertyType!.isEmpty) return Icons.home;

    final types = propertyType!.split(',').map((s) => s.trim().toLowerCase()).toList();

    // 按优先级检查
    for (final type in types) {
      if (type.contains('bungalow')) {
        return Icons.villa;
      } else if (type.contains('semi') || type.contains('semi-d')) {
        return Icons.holiday_village;
      } else if (type.contains('terrace')) {
        return Icons.house;
      } else if (type.contains('condo') || type.contains('condominium')) {
        return Icons.apartment;
      }
    }

    // 如果没有匹配，使用第一个类型匹配
    final firstType = types.first;
    if (firstType.contains('apartment')) return Icons.apartment;
    if (firstType.contains('condo')) return Icons.apartment;
    if (firstType.contains('terrace')) return Icons.house;
    if (firstType.contains('semi')) return Icons.holiday_village;
    if (firstType.contains('bungalow')) return Icons.villa;

    return Icons.home;
  }

  // 获取设施列表
  List<String> get facilityList {
    if (facilities == null || facilities!.isEmpty) return [];
    return facilities!.split('|').where((f) => f.trim().isNotEmpty).toList();
  }

  // 获取图片列表 - 过滤掉系统图片，只保留 CSV 提供的图片
  List<String> get photoUrlList {
    if (photoUrls == null || photoUrls!.isEmpty) return [];

    final urls = photoUrls!.split('|')
        .where((f) => f.trim().isNotEmpty)
        .toList();

    // 过滤掉系统图片
    return urls.where((url) {
      for (final prefix in _systemImagePrefixes) {
        if (url.startsWith(prefix)) {
          return false;
        }
      }
      // 保留真实的房产图片（通常包含 my1-cdn.pgimgs.com 或类似域名）
      return url.contains('pgimgs.com') ||
          url.contains('property') ||
          url.contains('listing');
    }).toList();
  }

  // 获取简短地址
  String get shortAddress {
    if (fullAddress != null && fullAddress!.isNotEmpty) {
      final parts = fullAddress!.split(',');
      if (parts.length >= 2) {
        return '${parts[0].trim()}, ${parts[1].trim()}';
      }
      return fullAddress!;
    }
    return state ?? 'Location not specified';
  }

  // 获取主要地址（用于标题）
  String get mainTitle {
    if (fullAddress != null && fullAddress!.isNotEmpty) {
      return fullAddress!.split(',').first.trim();
    }
    return state ?? 'Property for Sale';
  }
}