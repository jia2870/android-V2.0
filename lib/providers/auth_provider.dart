import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/user_service.dart';
import '../services/financial_service.dart';
import '../services/debt_service.dart';
import '../services/property_preference_service.dart';
import '../providers/financial_provider.dart';
import '../providers/saved_provider.dart';

class AuthProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final FinancialService _financialService = FinancialService();
  final DebtService _debtService = DebtService();
  final PropertyPreferenceService _preferenceService = PropertyPreferenceService();

  bool isLoggedIn = false;
  String userName = "Guest";
  String email = "";
  String phoneNumber = "";
  String selectedState = "Selangor";
  String profilePhoto = "";
  bool isLoading = false;
  String? errorMessage;
  String? userId;
  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  Future<void> checkAuthStatus() async {
    try {
      final session = SupabaseService().client.auth.currentSession;
      if (session != null && session.user != null) {
        final user = await _userService.getUserByEmail(session.user.email ?? '');
        if (user != null) {
          isLoggedIn = true;
          userId = user.id;
          userName = user.name;
          email = user.email;
          phoneNumber = user.phone;
          selectedState = user.state;
          profilePhoto = user.photo ?? '';

          if (_context != null) {
            await _loadUserData(user.id);
          }
          notifyListeners();
        } else {
          // ✅ User exists in auth but not in users table - force logout
          await forceLogout();
        }
      }
    } catch (e) {
      debugPrint('Check auth status error: $e');
    }
  }

  // Load user data to FinancialProvider
  Future<void> _loadUserData(String userId) async {
    try {
      if (_context == null) return;

      final financialProvider = Provider.of<FinancialProvider>(_context!, listen: false);

      // 1. Load financial data
      final profile = await _financialService.getProfileByUserId(userId);
      if (profile != null) {
        financialProvider.updateFinancialData(
          salary: profile.monthlySalary,
          otherIncome: profile.otherIncome,
          commitments: profile.commitments,
          savings: profile.savings,
          downPayment: profile.downPayment,
        );
      } else {
        financialProvider.clearAllData();
      }

      // 2. Load debt data
      final debts = await _debtService.getDebtsByUserId(userId);
      if (debts.isNotEmpty) {
        financialProvider.debts = [];
        for (var debt in debts) {
          financialProvider.addDebt(
              Debt(
                type: debt.type,
                name: debt.name,
                totalAmount: debt.totalAmount,
                monthlyPayment: debt.monthlyPayment,
                interestRate: debt.interestRate,
                remainingMonths: debt.remainingMonths,
              )
          );
        }
      }

      // 3. Load property preference
      final preference = await _preferenceService.getPreferenceByUserId(userId);
      if (preference != null) {
        financialProvider.updatePreferences(
          purpose: preference.purpose,
          propertyType: preference.propertyType,
          priceRange: preference.priceRange,
          bedrooms: preference.bedrooms,
          state: preference.preferredState,
          factors: preference.importantFactors,
        );
      }
    } catch (e) {
      debugPrint('Load user data error: $e');
    }
  }

  // ✅ Check if user exists
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      return await _userService.getUserByEmail(email);
    } catch (e) {
      debugPrint('Get user by email error: $e');
      return null;
    }
  }

  // ✅ Force logout - clears all data
  Future<void> forceLogout() async {
    try {
      await SupabaseService().client.auth.signOut();
    } catch (e) {
      debugPrint('Force logout error: $e');
    }

    isLoggedIn = false;
    userName = "Guest";
    email = "";
    phoneNumber = "";
    selectedState = "Selangor";
    profilePhoto = "";
    userId = null;
    errorMessage = null;

    if (_context != null) {
      final financialProvider = Provider.of<FinancialProvider>(_context!, listen: false);
      financialProvider.clearAllData();

      final savedProvider = Provider.of<SavedProvider>(_context!, listen: false);
      savedProvider.clear();
    }

    notifyListeners();
  }

  Future<bool> registerWithAuth({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String state,
    String photo = "",
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final response = await SupabaseService().client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userId = response.user!.id;
        this.userId = userId;

        final user = UserModel(
          id: userId,
          name: name,
          email: email,
          phone: phone,
          state: state,
          photo: photo,
        );

        await _userService.createUser(user);

        isLoggedIn = true;
        userName = name;
        this.email = email;
        phoneNumber = phone;
        selectedState = state;
        profilePhoto = photo;

        if (_context != null) {
          await _loadUserData(userId);
        }

        isLoading = false;
        notifyListeners();
        return true;
      } else {
        errorMessage = "Registration failed. Please try again.";
        isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      isLoading = false;

      if (e.toString().contains('rate limit')) {
        errorMessage = "Too many registration attempts. Please wait 5-10 minutes before trying again.";
      } else if (e.toString().contains('already registered')) {
        errorMessage = "Email already registered. Please login.";
      } else {
        errorMessage = e.toString();
      }

      notifyListeners();
      debugPrint('Auth register error: $e');
      return false;
    }
  }

  Future<bool> signInWithAuth(String email, String password) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final response = await SupabaseService().client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // ✅ Check if user exists in users table
        final user = await _userService.getUserByEmail(email);

        if (user == null) {
          // ✅ User doesn't exist - force logout and return false
          await forceLogout();
          isLoading = false;
          errorMessage = "Account not found. Please register.";
          notifyListeners();
          return false;
        }

        userId = response.user!.id;
        isLoggedIn = true;
        userName = user.name;
        this.email = user.email;
        phoneNumber = user.phone;
        selectedState = user.state;
        profilePhoto = user.photo ?? '';

        if (_context != null) {
          await _loadUserData(user.id);
        }

        isLoading = false;
        notifyListeners();
        return true;
      } else {
        isLoading = false;
        errorMessage = "Invalid email or password";
        notifyListeners();
        return false;
      }
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      debugPrint('SignIn error: $e');
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await SupabaseService().client.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      debugPrint('Reset password error: $e');
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    try {
      final response = await SupabaseService().client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response.user != null;
    } catch (e) {
      debugPrint('Update password error: $e');
      return false;
    }
  }

  Future<void> logoutWithAuth() async {
    try {
      await SupabaseService().client.auth.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    if (_context != null) {
      final savedProvider = Provider.of<SavedProvider>(_context!, listen: false);
      savedProvider.clear();

      final financialProvider = Provider.of<FinancialProvider>(_context!, listen: false);
      financialProvider.clearAllData();
    }

    isLoggedIn = false;
    userName = "Guest";
    email = "";
    phoneNumber = "";
    selectedState = "Selangor";
    profilePhoto = "";
    userId = null;
    errorMessage = null;

    notifyListeners();
  }

  String? getCurrentUserId() {
    if (userId == null || userId == '') {
      final session = SupabaseService().client.auth.currentSession;
      if (session != null) {
        userId = session.user.id;
      }
    }
    return userId;
  }

  String? getCurrentUserEmail() {
    final session = SupabaseService().client.auth.currentSession;
    return session?.user.email;
  }

  // ✅ Clear all data (used for logout)
  void clearAllData() {
    isLoggedIn = false;
    userName = "Guest";
    email = "";
    phoneNumber = "";
    selectedState = "Selangor";
    profilePhoto = "";
    userId = null;
    errorMessage = null;
    notifyListeners();
  }
}