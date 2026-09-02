import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/password_rules.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  String? _currentPasswordError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateCurrent(String? value) {
    if (value == null || value.isEmpty) return 'Current password is required';
    return _currentPasswordError;
  }

  String? _validateNew(String? value) {
    final strengthError = PasswordRules.validate(
      value,
      emptyMessage: 'New password is required',
    );
    if (strengthError != null) return strengthError;
    if (value == _currentController.text) {
      return 'New password must be different from the current one';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _newController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _currentPasswordError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      await auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final message = _readableError(e);
      setState(() {
        _isSaving = false;
        if (message.toLowerCase().contains('current password is incorrect')) {
          _currentPasswordError = 'Current password is incorrect';
        }
      });
      _formKey.currentState?.validate();

      if (_currentPasswordError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  String _readableError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPasswordField(
              controller: _currentController,
              label: 'Current Password',
              obscure: _obscureCurrent,
              onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
              validator: _validateCurrent,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: (_) {
                if (_currentPasswordError == null) return;
                setState(() => _currentPasswordError = null);
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _newController,
              label: 'New Password',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: _validateNew,
              helperText: PasswordRules.helperText,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _confirmController,
              label: 'Confirm New Password',
              obscure: _obscureConfirm,
              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
              validator: _validateConfirm,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSaving ? Colors.grey : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Update Password',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required FormFieldValidator<String> validator,
    String? helperText,
    ValueChanged<String>? onChanged,
    AutovalidateMode? autovalidateMode,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      onChanged: onChanged,
      autovalidateMode: autovalidateMode,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
          tooltip: obscure ? 'Show password' : 'Hide password',
        ),
      ),
    );
  }
}
