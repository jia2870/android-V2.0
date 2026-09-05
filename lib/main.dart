import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/financial_provider.dart';
import 'providers/saved_provider.dart';
import 'providers/theme_provider.dart';
import 'services/local_cache_service.dart';
import 'services/supabase_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/financial_assessment_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/debt_management_screen.dart';
import 'screens/saved_properties_screen.dart';
import 'screens/ai_advisor_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/device_layout.dart';
import 'widgets/app_loading_screen.dart';

const _systemUiChannel = MethodChannel('myhome/system_ui');

Future<void> _syncNativeSystemBars({required bool isDark}) async {
  final color = isDark ? 0xFF12121E : 0xFFFAFAFA;
  try {
    await _systemUiChannel.invokeMethod<void>('setBars', {
      'color': color,
      'lightIcons': isDark,
    });
  } catch (_) {
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService().initialize();
  await LocalCacheService.instance.init();
  await applyPreferredOrientationsForDevice(isPhone: isPhoneFromWindow());

  final connectivity = ConnectivityProvider();
  await connectivity.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connectivity),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FinancialProvider()),
        ChangeNotifierProvider(create: (_) => SavedProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isLoading = true;
  ConnectivityProvider? _connectivity;
  bool _wasOffline = false;
  bool? _lastPhoneLayout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void didChangeMetrics() {
    final ctx = _materialContext;
    if (ctx != null && ctx.mounted) {
      _syncDeviceConstraints(ctx);
    } else {
      applyPreferredOrientationsForDevice(isPhone: isPhoneFromWindow());
    }
  }

  BuildContext? _materialContext;

  Future<void> _bootstrap() async {
    final startedAt = DateTime.now();
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final saved = Provider.of<SavedProvider>(context, listen: false);
      _connectivity = Provider.of<ConnectivityProvider>(context, listen: false);
      _wasOffline = _connectivity!.isOffline;
      _connectivity!.addListener(_onConnectivityChanged);

      auth.setContext(context);
      await auth.checkAuthStatus().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          debugPrint('Auth check timed out — continuing with cache/session');
        },
      );

      if (auth.isLoggedIn && auth.userId != null) {
        await saved.init(auth.userId!).timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            debugPrint('Saved init timed out');
          },
        );
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
    } finally {
      const minSplash = Duration(seconds: 3);
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minSplash) {
        await Future.delayed(minSplash - elapsed);
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _syncDeviceConstraints(BuildContext context) {
    final phone = isPhoneLayout(context);
    if (_lastPhoneLayout != phone) {
      _lastPhoneLayout = phone;
      applyPreferredOrientationsForDevice(isPhone: phone);
    } else {
      applyPreferredOrientationsForDevice(isPhone: phone);
    }
  }

  void _onConnectivityChanged() {
    final connectivity = _connectivity;
    if (connectivity == null || !mounted) return;

    if (_wasOffline && connectivity.isOnline) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      auth.refreshWhenOnline();
    }
    _wasOffline = connectivity.isOffline;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingScreen();
    }

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'MyHome AI',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          locale: const Locale('en'),
          supportedLocales: const [
            Locale('en'),
          ],
          builder: (context, child) {
            _materialContext = context;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncDeviceConstraints(context);
            });

            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final barColor =
                isDark ? const Color(0xFF12121E) : const Color(0xFFFAFAFA);
            final overlay = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: barColor,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
              systemStatusBarContrastEnforced: false,
            );
            SystemChrome.setSystemUIOverlayStyle(overlay);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _syncNativeSystemBars(isDark: isDark);
            });

            final mediaQuery = MediaQuery.of(context);
            final compactLandscape =
                mediaQuery.orientation == Orientation.landscape &&
                    mediaQuery.size.height < 500;
            final appBarTheme = theme.appBarTheme;
            final foregroundColor =
                appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
            final content = child ?? const SizedBox.shrink();
            final responsiveContent = compactLandscape
                ? Theme(
                    data: theme.copyWith(
                      appBarTheme: appBarTheme.copyWith(
                        toolbarHeight: 40,
                        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
                          color: foregroundColor,
                          fontSize: 16,
                        ),
                        iconTheme: (appBarTheme.iconTheme ??
                                IconThemeData(color: foregroundColor))
                            .copyWith(size: 18),
                        actionsIconTheme: (appBarTheme.actionsIconTheme ??
                                IconThemeData(color: foregroundColor))
                            .copyWith(size: 18),
                      ),
                    ),
                    child: content,
                  )
                : content;

            return ColoredBox(
              color: theme.scaffoldBackgroundColor,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlay,
                child: responsiveContent,
              ),
            );
          },
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
            '/financial-assessment': (context) =>
                const FinancialAssessmentScreen(),
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
