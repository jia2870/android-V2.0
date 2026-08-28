import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/saved_provider.dart';
import '../services/supabase_service.dart';
import '../utils/device_layout.dart';
import '../widgets/adaptive_nav_scaffold.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeletingAccount = false;

  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _deleteError;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _deleteError = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isDeletingAccount = true;
      _deleteError = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.getCurrentUserId();

      if (userId == null || userId.isEmpty) {
        if (mounted) {
          setState(() {
            _deleteError = 'User not logged in';
            _isDeletingAccount = false;
          });
        }
        return;
      }

      final supabase = SupabaseService().client;
      final email = auth.email;

      if (email.isEmpty) {
        if (mounted) {
          setState(() {
            _deleteError = 'Email not found';
            _isDeletingAccount = false;
          });
        }
        return;
      }

      try {
        final signInResponse = await supabase.auth.signInWithPassword(
          email: email,
          password: _passwordController.text,
        );

        if (signInResponse.user == null) {
          if (mounted) {
            setState(() {
              _deleteError = 'Invalid password. Please try again.';
              _isDeletingAccount = false;
            });
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _deleteError = 'Invalid password. Please try again.';
            _isDeletingAccount = false;
          });
        }
        return;
      }

      try {
        await supabase
            .from('financial_profiles')
            .delete()
            .eq('user_id', userId);

        await supabase
            .from('debts')
            .delete()
            .eq('user_id', userId);

        await supabase
            .from('property_preferences')
            .delete()
            .eq('user_id', userId);

        await supabase
            .from('saved_properties')
            .delete()
            .eq('user_id', userId);

        await supabase
            .from('users')
            .delete()
            .eq('id', userId);

        try {
          final currentUser = supabase.auth.currentUser;
          if (currentUser != null) {
            await supabase.auth.signOut();

          }
        } catch (e) {
          debugPrint('Error deleting auth user: $e');
        }

        await supabase.auth.signOut();

        final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
        final savedProvider = Provider.of<SavedProvider>(context, listen: false);

        auth.isLoggedIn = false;
        auth.userName = "Guest";
        auth.email = "";
        auth.phoneNumber = "";
        auth.selectedState = "Selangor";
        auth.profilePhoto = "";
        auth.userId = null;
        auth.errorMessage = null;
        auth.notifyListeners();

        financialProvider.clearAllData();

        savedProvider.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully. You will need to register again to use the app.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        }

      } catch (e) {
        if (mounted) {
          setState(() {
            _deleteError = 'Error deleting account data: $e';
            _isDeletingAccount = false;
          });
        }
        debugPrint('Error deleting account data: $e');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleteError = 'Error: $e';
          _isDeletingAccount = false;
        });
      }
      debugPrint('Delete account error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final appBar = AppBar(
      title: const Text('Settings'),
    );

    final content = ListView(
      children: [
          _buildSectionHeader('Appearance'),

          SwitchListTile(
            key: ValueKey(themeProvider.isDarkMode),
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark theme'),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme(value);
              setState(() {});
            },
            secondary: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: themeProvider.isDarkMode ? Colors.grey : Colors.amber,
            ),
          ),

          const Divider(),

          if (auth.isLoggedIn) ...[
            _buildSectionHeader('Account'),

            ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.blue),
              title: const Text('Change Password'),
              subtitle: const Text('Update the password you use to sign in'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),

            _buildSectionHeader('Danger Zone', color: Colors.red),

            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text(
                'Permanently delete your account and all data',
                style: TextStyle(color: Colors.red),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showDeleteConfirmationDialog();
              },
            ),
          ],

          const SizedBox(height: 40),

          Center(
            child: Text(
              'MyHome AI v1.0.0',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),
      ],
    );

    if (!isTabletUiActive(context)) {
      return Scaffold(appBar: appBar, body: content);
    }

    return AdaptiveNavScaffold(
      currentIndex: AppNavIndex.settings,
      automaticallyImplyLeading: true,
      appBar: appBar,
      body: content,
    );
  }


  Widget _buildSectionHeader(String title, {Color color = Colors.blue}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    _passwordController.clear();
    _deleteError = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ This action is permanent and cannot be undone!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Deleting your account will permanently remove:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• All your saved properties\n'
                      '• Financial data and assessment\n'
                      '• Property preferences\n'
                      '• Debt records\n'
                      '• Account credentials',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You will NOT be able to login with this email again.\n'
                      'You must register a new account to use the app.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter your password to confirm:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    errorText: _deleteError,
                    errorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      _deleteError = null;
                    });
                  },
                ),
                if (_isDeletingAccount) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isDeletingAccount ? null : () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isDeletingAccount ? null : () async {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  if (mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const AlertDialog(
                        title: Text('Deleting Account...'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Please wait while we delete your account...'),
                          ],
                        ),
                      ),
                    );
                  }

                  await _deleteAccount();

                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete Forever'),
              ),
            ],
          );
        },
      ),
    );
  }
}
