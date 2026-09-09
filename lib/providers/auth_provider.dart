import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/user_service.dart';
import '../services/financial_service.dart';
import '../services/debt_service.dart';
import '../services/property_preference_service.dart';
import '../services/local_cache_service.dart';
import '../providers/financial_provider.dart';
import '../providers/saved_provider.dart';

class AuthProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final FinancialService _financialService = FinancialService();
  final DebtService _debtService = DebtService();
  final PropertyPreferenceService _preferenceService = PropertyPreferenceService();
  final LocalCacheService _cache = LocalCacheService.instance;

  bool isLoggedIn = false;
  String userName = "Guest";
  String email = "";
  String phoneNumber = "";
  String selectedState = "Selangor";
  String profilePhoto = "";
  bool isLoading = false;
  bool isRefreshing = false;
  String? errorMessage;
  String? userId;
  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  void _applyUser(UserModel user) {
    isLoggedIn = true;
    userId = user.id;
    userName = user.name;
    email = user.email;
    phoneNumber = user.phone;
    selectedState = user.state;
    profilePhoto = user.photo ?? '';
  }

  Future<void> checkAuthStatus() async {
    try {
      final session = SupabaseService().client.auth.currentSession;
      if (session == null) {
        return;
      }

      final sessionEmail = session.user.email ?? '';
      UserModel? user;

      try {
        user = await _userService.getUserByEmail(sessionEmail);
      } catch (e) {
        debugPrint('checkAuthStatus network lookup failed: $e');
      }

      user ??= await _cache.getUserByEmail(sessionEmail);
      user ??= await _cache.getUser();

      if (user != null) {
        _applyUser(user);
        await _cache.saveUser(user);
        if (_context != null) {
          await _loadUserData(user.id);
        }
        notifyListeners();
        return;
      }

      isLoggedIn = true;
      userId = session.user.id;
      email = sessionEmail;
      userName = sessionEmail.isNotEmpty ? sessionEmail.split('@').first : 'User';
      notifyListeners();
    } catch (e) {
      debugPrint('Check auth status error: $e');
      final cached = await _cache.getUser();
      if (cached != null &&
          SupabaseService().client.auth.currentSession != null) {
        _applyUser(cached);
        if (_context != null) {
          await _loadUserData(cached.id);
        }
        notifyListeners();
      }
    }
  }

  Future<void> refreshWhenOnline() async {
    if (!isLoggedIn || userId == null || isRefreshing) return;
    isRefreshing = true;
    notifyListeners();
    try {
      await _syncPendingWrites(userId!);
      await checkAuthStatus();
      if (_context != null && userId != null) {
        final savedProvider =
            Provider.of<SavedProvider>(_context!, listen: false);
        await savedProvider.init(userId!, force: true);
      }
    } catch (e) {
      debugPrint('refreshWhenOnline error: $e');
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _syncPendingWrites(String uid) async {
    try {
      if (await _cache.hasPendingProfile(uid)) {
        final cached = await _cache.getUser();
        if (cached != null && cached.id == uid) {
          await _userService.updateProfileDetails(
            userId: uid,
            name: cached.name,
            phone: cached.phone,
            state: cached.state,
          );
        }
      }
      await _financialService.syncPending(uid);
      await _preferenceService.syncPending(uid);
    } catch (e) {
      debugPrint('syncPendingWrites error: $e');
    }
  }

  Future<void> _loadUserData(String userId) async {
    try {
      if (_context == null) return;

      final financialProvider =
          Provider.of<FinancialProvider>(_context!, listen: false);

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

      final debts = await _debtService.getDebtsByUserId(userId);
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
          ),
        );
      }

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

  Future<UserModel?> getUserByEmail(String email) async {
    try {
      return await _userService.getUserByEmail(email);
    } catch (e) {
      debugPrint('Get user by email error: $e');
      return _cache.getUserByEmail(email);
    }
  }

  Future<void> forceLogout() async {
    final previousUserId = userId;
    try {
      await SupabaseService().client.auth.signOut();
    } catch (e) {
      debugPrint('Force logout error: $e');
    }

    await _cache.clearUserData(previousUserId);

    isLoggedIn = false;
    userName = "Guest";
    email = "";
    phoneNumber = "";
    selectedState = "Selangor";
    profilePhoto = "";
    userId = null;
    errorMessage = null;

    if (_context != null) {
      final financialProvider =
          Provider.of<FinancialProvider>(_context!, listen: false);
      financialProvider.clearAllData();

      final savedProvider =
          Provider.of<SavedProvider>(_context!, listen: false);
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
        await _cache.saveUser(user);

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
        errorMessage =
            "Too many registration attempts. Please wait 5-10 minutes before trying again.";
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
        final user = await _userService.getUserByEmail(email);

        if (user == null) {
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
        await _cache.saveUser(user);

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

  Future<void> updateProfileDetails({
    required String name,
    required String phone,
    required String state,
  }) async {
    final id = getCurrentUserId();
    if (id == null || id.isEmpty) {
      throw Exception('Not logged in');
    }

    await _userService.updateProfileDetails(
      userId: id,
      name: name,
      phone: phone,
      state: state,
    );

    userName = name;
    phoneNumber = phone;
    selectedState = state;
    notifyListeners();
  }

  Future<void> updateProfilePhoto(String photoUrl) async {
    final id = getCurrentUserId();
    if (id == null || id.isEmpty) {
      throw Exception('Not logged in');
    }

    await _userService.updatePhoto(id, photoUrl);
    profilePhoto = photoUrl;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    try {
      await SupabaseService().client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      debugPrint('Reset password error: ${e.message}');
      throw Exception(_resetPasswordErrorMessage(e.message));
    } catch (e) {
      debugPrint('Reset password error: $e');
      throw Exception(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  String _resetPasswordErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('rate') || lower.contains('too many')) {
      return 'Too many attempts. Please try again later.';
    }
    if (lower.contains('invalid') && lower.contains('email')) {
      return 'Invalid email address';
    }
    if (lower.contains('network') || lower.contains('timeout')) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return message.isEmpty
        ? 'Failed to send reset email. Please try again.'
        : message;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final client = SupabaseService().client;
    final currentEmail = client.auth.currentSession?.user.email ?? email;
    if (currentEmail.isEmpty) {
      throw Exception('Not logged in');
    }

    try {
      await client.auth.signInWithPassword(
        email: currentEmail,
        password: currentPassword,
      );
    } on AuthException {
      throw Exception('Current password is incorrect');
    }

    final response = await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    if (response.user == null) {
      throw Exception('Password update failed, please try again');
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
    final previousUserId = userId;
    try {
      await SupabaseService().client.auth.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    await _cache.clearUserData(previousUserId);

    if (_context != null) {
      final savedProvider =
          Provider.of<SavedProvider>(_context!, listen: false);
      savedProvider.clear();

      final financialProvider =
          Provider.of<FinancialProvider>(_context!, listen: false);
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
