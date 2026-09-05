import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/financial_provider.dart';
import '../utils/device_layout.dart';
import '../screens/ai_advisor_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/saved_properties_screen.dart';
import '../screens/settings_screen.dart';
import '../utils/ai_access_prompt.dart';

class AppNavIndex {
  static const int home = 0;
  static const int ai = 1;
  static const int saved = 2;
  static const int profile = 3;
  static const int settings = 4;
}

Future<void> handleAppNavigation(BuildContext context, int index) async {
  switch (index) {
    case AppNavIndex.home:
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
      break;
    case AppNavIndex.ai:
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isLoggedIn) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login first')));
        return;
      }
      final financial = Provider.of<FinancialProvider>(context, listen: false);
      if (financial.monthlySalary <= 0) {
        showCompleteFinancialAssessmentPrompt(context);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AIAdvisorScreen(property: null),
        ),
      );
      break;
    case AppNavIndex.saved:
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isLoggedIn) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login first')));
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SavedPropertiesScreen()),
      );
      break;
    case AppNavIndex.profile:
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isLoggedIn) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login first')));
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      break;
    case AppNavIndex.settings:
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      break;
  }
}

class AdaptiveNavScaffold extends StatelessWidget {
  const AdaptiveNavScaffold({
    super.key,
    required this.currentIndex,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.onTap,
    this.automaticallyImplyLeading,
  });

  final int currentIndex;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final ValueChanged<int>? onTap;

  final bool? automaticallyImplyLeading;

  void _handleTap(BuildContext context, int index) {
    if (onTap != null) {
      onTap!(index);
      return;
    }
    if (index == currentIndex && index != AppNavIndex.settings) return;
    handleAppNavigation(context, index);
  }

  PreferredSizeWidget? _resolveAppBar(bool tablet) {
    if (appBar == null) return null;
    final implyLeading = automaticallyImplyLeading ?? false;
    if (appBar is! AppBar) return appBar;
    final source = appBar as AppBar;
    return AppBar(
      leading: source.leading,
      automaticallyImplyLeading: implyLeading,
      title: source.title,
      actions: source.actions,
      backgroundColor: source.backgroundColor,
      foregroundColor: source.foregroundColor,
      elevation: source.elevation,
      centerTitle: source.centerTitle,
      bottom: source.bottom,
      flexibleSpace: source.flexibleSpace,
      toolbarHeight: source.toolbarHeight,
      iconTheme: source.iconTheme,
      actionsIconTheme: source.actionsIconTheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablet = isTabletUiActive(context);
    final resolvedAppBar = _resolveAppBar(tablet);

    if (!tablet) {
      return Scaffold(
        appBar: resolvedAppBar,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: currentIndex.clamp(0, 3),
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Saved'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          onTap: (i) => _handleTap(context, i),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _TabletSideNav(
            currentIndex: currentIndex,
            onSelect: (i) => _handleTap(context, i),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Scaffold(
              appBar: resolvedAppBar,
              body: body,
              floatingActionButton: floatingActionButton,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletSideNav extends StatelessWidget {
  const _TabletSideNav({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _items = <({int index, IconData icon, String label})>[
    (index: AppNavIndex.home, icon: Icons.search, label: 'Home'),
    (index: AppNavIndex.ai, icon: Icons.smart_toy, label: 'AI'),
    (index: AppNavIndex.saved, icon: Icons.favorite_outline, label: 'Saved'),
    (index: AppNavIndex.profile, icon: Icons.person_outline, label: 'Profile'),
    (
    index: AppNavIndex.settings,
    icon: Icons.settings_outlined,
    label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final compact = MediaQuery.sizeOf(context).height < 500;

    return Material(
      color: bg,
      child: SafeArea(
        child: SizedBox(
          width: compact ? 150 : 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(12, 8, 12, 10)
                    : const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue.withValues(alpha: 0.15)
                            : const Color(0xFFE8F2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.asset(
                        'assets/images/app_logo.jpeg',
                        width: compact ? 22 : 28,
                        height: compact ? 22 : 28,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.home_work_rounded,
                          color: Colors.blue,
                          size: compact ? 22 : 28,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: Text(
                        'MyHome AI',
                        style: TextStyle(
                          fontSize: compact ? 12 : 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1B3A5F),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
                  children: [
                    for (final item in _items)
                      _SideNavTile(
                        icon: item.icon,
                        label: item.label,
                        selected: currentIndex == item.index,
                        onTap: () => onSelect(item.index),
                        compact: compact,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideNavTile extends StatelessWidget {
  const _SideNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark
        ? Colors.blue.withValues(alpha: 0.22)
        : const Color(0xFFE8F2FF);
    final color = selected
        ? Colors.blue
        : (isDark ? Colors.white70 : Colors.grey.shade700);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: selected
                ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.25),
              ),
            )
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 9 : 12,
                vertical: compact ? 7 : 11,
              ),
              child: Row(
                children: [
                  Icon(icon, size: compact ? 18 : 22, color: color),
                  SizedBox(width: compact ? 8 : 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 11 : 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
