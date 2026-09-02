import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/env.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = Env.supabaseUrl;
  static const String supabasePublishableKey = Env.supabasePublishableKey;

  late final SupabaseClient client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    client = Supabase.instance.client;
  }

  static const String usersTable = 'users';
  static const String financialProfilesTable = 'financial_profiles';
  static const String debtsTable = 'debts';
  static const String propertyPreferencesTable = 'property_preferences';
  static const String propertiesTable = 'properties';
  static const String savedPropertiesTable = 'saved_properties';
  static const String populationDataTable = 'population_data';
}

class FinancialProfileModel {
  final String id;
  final String userId;
  final double monthlySalary;
  final double otherIncome;
  final double commitments;
  final double savings;
  final double downPayment;
  final double affordabilityScore;
  final double recommendedBudget;
  final String riskLevel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FinancialProfileModel({
    required this.id,
    required this.userId,
    required this.monthlySalary,
    required this.otherIncome,
    required this.commitments,
    required this.savings,
    required this.downPayment,
    required this.affordabilityScore,
    required this.recommendedBudget,
    required this.riskLevel,
    this.createdAt,
    this.updatedAt,
  });

  factory FinancialProfileModel.fromJson(Map<String, dynamic> json) {
    return FinancialProfileModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      monthlySalary: (json['monthly_salary'] ?? 0).toDouble(),
      otherIncome: (json['other_income'] ?? 0).toDouble(),
      commitments: (json['commitments'] ?? 0).toDouble(),
      savings: (json['savings'] ?? 0).toDouble(),
      downPayment: (json['down_payment'] ?? 0).toDouble(),
      affordabilityScore: (json['affordability_score'] ?? 0).toDouble(),
      recommendedBudget: (json['recommended_budget'] ?? 0).toDouble(),
      riskLevel: json['risk_level'] ?? 'Low',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'monthly_salary': monthlySalary,
      'other_income': otherIncome,
      'commitments': commitments,
      'savings': savings,
      'down_payment': downPayment,
      'affordability_score': affordabilityScore,
      'recommended_budget': recommendedBudget,
      'risk_level': riskLevel,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'monthly_salary': monthlySalary,
      'other_income': otherIncome,
      'commitments': commitments,
      'savings': savings,
      'down_payment': downPayment,
      'affordability_score': affordabilityScore,
      'recommended_budget': recommendedBudget,
      'risk_level': riskLevel,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class DebtModel {
  final String id;
  final String userId;
  final String type;
  final String name;
  final double totalAmount;
  final double monthlyPayment;
  final double interestRate;
  final int remainingMonths;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DebtModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    required this.totalAmount,
    required this.monthlyPayment,
    required this.interestRate,
    required this.remainingMonths,
    this.createdAt,
    this.updatedAt,
  });

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    return DebtModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      monthlyPayment: (json['monthly_payment'] ?? 0).toDouble(),
      interestRate: (json['interest_rate'] ?? 0).toDouble(),
      remainingMonths: json['remaining_months'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'type': type,
      'name': name,
      'total_amount': totalAmount,
      'monthly_payment': monthlyPayment,
      'interest_rate': interestRate,
      'remaining_months': remainingMonths,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'type': type,
      'name': name,
      'total_amount': totalAmount,
      'monthly_payment': monthlyPayment,
      'interest_rate': interestRate,
      'remaining_months': remainingMonths,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class PropertyPreferenceModel {
  final String id;
  final String userId;
  final String purpose;
  final String propertyType;
  final String priceRange;
  final int bedrooms;
  final String preferredState;
  final List<String> importantFactors;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PropertyPreferenceModel({
    required this.id,
    required this.userId,
    required this.purpose,
    required this.propertyType,
    required this.priceRange,
    required this.bedrooms,
    required this.preferredState,
    required this.importantFactors,
    this.createdAt,
    this.updatedAt,
  });

  factory PropertyPreferenceModel.fromJson(Map<String, dynamic> json) {
    return PropertyPreferenceModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      purpose: json['purpose'] ?? 'Own Stay',
      propertyType: json['property_type'] ?? 'Apartment',
      priceRange: json['price_range'] ?? 'RM200k–300k',
      bedrooms: json['bedrooms'] ?? 3,
      preferredState: json['preferred_state'] ?? 'Selangor',
      importantFactors: json['important_factors'] != null
          ? List<String>.from(json['important_factors'])
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'purpose': purpose,
      'property_type': propertyType,
      'price_range': priceRange,
      'bedrooms': bedrooms,
      'preferred_state': preferredState,
      'important_factors': importantFactors,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'purpose': purpose,
      'property_type': propertyType,
      'price_range': priceRange,
      'bedrooms': bedrooms,
      'preferred_state': preferredState,
      'important_factors': importantFactors,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String state;
  final String? photo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.state,
    this.photo,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      state: json['state'] ?? 'Selangor',
      photo: json['photo'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'state': state,
      'photo': photo,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'phone': phone,
      'state': state,
      'photo': photo,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
