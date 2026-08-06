import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/financial_provider.dart';
import 'providers/saved_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'services/supabase_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/financial_assessment_screen.dart';
import 'screens/property_preferences_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/debt_management_screen.dart';
import 'screens/property_detail_screen.dart';
import 'screens/saved_properties_screen.dart';
import 'screens/ai_advisor_screen.dart';
import 'screens/settings_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FinancialProvider()),
        ChangeNotifierProvider(create: (_) => SavedProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // ✅ Use WidgetsBinding to ensure the widget tree is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStatus();
    });
  }

  Future<void> _checkAuthStatus() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final saved = Provider.of<SavedProvider>(context, listen: false);

      auth.setContext(context);
      await auth.checkAuthStatus();

      if (auth.isLoggedIn && auth.userId != null) {
        await saved.init(auth.userId!);
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return MaterialApp(
          title: 'MyHome AI',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          locale: languageProvider.locale,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('zh'),
            Locale('ms'),
          ],
          home: Consumer<AuthProvider>(
            builder: (context, auth, child) {
              if (auth.isLoggedIn) {
                return const DashboardScreen();
              } else {
                return const LoginScreen();
              }
            },
          ),
          debugShowCheckedModeBanner: false,
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/financial-assessment': (context) => const FinancialAssessmentScreen(),
            '/property-preferences': (context) => const PropertyPreferencesScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/debts': (context) => const DebtManagementScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/saved': (context) => const SavedPropertiesScreen(),
            '/ai-advisor': (context) => const AIAdvisorScreen(property: null),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}

// ✅ Add custom theme definitions here or keep them in your theme_provider.dart
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      // ... rest of your light theme
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF12121E),
      cardColor: const Color(0xFF1E1E2E),
      // ... rest of your dark theme
    );
  }
}