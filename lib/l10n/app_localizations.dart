import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
  _AppLocalizationsDelegate();

  // ============================================================
  // 翻译文本
  // ============================================================

  String get appName {
    switch (locale.languageCode) {
      case 'zh':
        return '我的家 AI';
      case 'ms':
        return 'MyHome AI';
      default:
        return 'MyHome AI';
    }
  }

  String get login {
    switch (locale.languageCode) {
      case 'zh':
        return '登录';
      case 'ms':
        return 'Log Masuk';
      default:
        return 'Login';
    }
  }

  String get register {
    switch (locale.languageCode) {
      case 'zh':
        return '注册';
      case 'ms':
        return 'Daftar';
      default:
        return 'Register';
    }
  }

  String get email {
    switch (locale.languageCode) {
      case 'zh':
        return '邮箱';
      case 'ms':
        return 'Emel';
      default:
        return 'Email';
    }
  }

  String get password {
    switch (locale.languageCode) {
      case 'zh':
        return '密码';
      case 'ms':
        return 'Kata Laluan';
      default:
        return 'Password';
    }
  }

  String get forgotPassword {
    switch (locale.languageCode) {
      case 'zh':
        return '忘记密码？';
      case 'ms':
        return 'Lupa Kata Laluan?';
      default:
        return 'Forgot Password?';
    }
  }

  String get welcomeBack {
    switch (locale.languageCode) {
      case 'zh':
        return '欢迎回来！';
      case 'ms':
        return 'Selamat Kembali!';
      default:
        return 'Welcome Back!';
    }
  }

  String get signInToContinue {
    switch (locale.languageCode) {
      case 'zh':
        return '登录以继续';
      case 'ms':
        return 'Log masuk untuk teruskan';
      default:
        return 'Sign in to continue';
    }
  }

  String get createAccount {
    switch (locale.languageCode) {
      case 'zh':
        return '创建账户';
      case 'ms':
        return 'Buat Akaun';
      default:
        return 'Create Account';
    }
  }

  String get signUpToGetStarted {
    switch (locale.languageCode) {
      case 'zh':
        return '注册开始使用';
      case 'ms':
        return 'Daftar untuk memulakan';
      default:
        return 'Sign up to get started';
    }
  }

  String get fullName {
    switch (locale.languageCode) {
      case 'zh':
        return '姓名';
      case 'ms':
        return 'Nama Penuh';
      default:
        return 'Full Name';
    }
  }

  String get phoneNumber {
    switch (locale.languageCode) {
      case 'zh':
        return '手机号码';
      case 'ms':
        return 'Nombor Telefon';
      default:
        return 'Phone Number';
    }
  }

  String get selectState {
    switch (locale.languageCode) {
      case 'zh':
        return '选择州属';
      case 'ms':
        return 'Pilih Negeri';
      default:
        return 'Select State';
    }
  }

  String get settings {
    switch (locale.languageCode) {
      case 'zh':
        return '设置';
      case 'ms':
        return 'Tetapan';
      default:
        return 'Settings';
    }
  }

  String get darkMode {
    switch (locale.languageCode) {
      case 'zh':
        return '夜间模式';
      case 'ms':
        return 'Mod Gelap';
      default:
        return 'Dark Mode';
    }
  }

  String get language {
    switch (locale.languageCode) {
      case 'zh':
        return '语言';
      case 'ms':
        return 'Bahasa';
      default:
        return 'Language';
    }
  }

  String get deleteAccount {
    switch (locale.languageCode) {
      case 'zh':
        return '删除账户';
      case 'ms':
        return 'Padam Akaun';
      default:
        return 'Delete Account';
    }
  }

  String get logout {
    switch (locale.languageCode) {
      case 'zh':
        return '登出';
      case 'ms':
        return 'Log Keluar';
      default:
        return 'Logout';
    }
  }

  String get profile {
    switch (locale.languageCode) {
      case 'zh':
        return '个人资料';
      case 'ms':
        return 'Profil';
      default:
        return 'Profile';
    }
  }

  String get savedProperties {
    switch (locale.languageCode) {
      case 'zh':
        return '收藏的房产';
      case 'ms':
        return 'Hartanah Disimpan';
      default:
        return 'Saved Properties';
    }
  }

  String get searchProperties {
    switch (locale.languageCode) {
      case 'zh':
        return '搜索房产';
      case 'ms':
        return 'Cari Hartanah';
      default:
        return 'Search Properties';
    }
  }

  String get home {
    switch (locale.languageCode) {
      case 'zh':
        return '首页';
      case 'ms':
        return 'Utama';
      default:
        return 'Home';
    }
  }

  String get aiAdvisor {
    switch (locale.languageCode) {
      case 'zh':
        return 'AI 顾问';
      case 'ms':
        return 'Penasihat AI';
      default:
        return 'AI Advisor';
    }
  }

  String get noPropertiesFound {
    switch (locale.languageCode) {
      case 'zh':
        return '未找到房产';
      case 'ms':
        return 'Tiada hartanah dijumpai';
      default:
        return 'No properties found';
    }
  }

  String get tryAdjustingFilters {
    switch (locale.languageCode) {
      case 'zh':
        return '尝试调整筛选条件';
      case 'ms':
        return 'Cuba laraskan penapis';
      default:
        return 'Try adjusting your filters';
    }
  }

  String get priceOnRequest {
    switch (locale.languageCode) {
      case 'zh':
        return '价格请咨询';
      case 'ms':
        return 'Harga Atas Permintaan';
      default:
        return 'Price on Request';
    }
  }

  String get bedrooms {
    switch (locale.languageCode) {
      case 'zh':
        return '卧室';
      case 'ms':
        return 'Bilik Tidur';
      default:
        return 'Bedrooms';
    }
  }

  String get bathrooms {
    switch (locale.languageCode) {
      case 'zh':
        return '浴室';
      case 'ms':
        return 'Bilik Mandi';
      default:
        return 'Bathrooms';
    }
  }

  String get builtUp {
    switch (locale.languageCode) {
      case 'zh':
        return '建筑面积';
      case 'ms':
        return 'Kawasan Binaan';
      default:
        return 'Built Up';
    }
  }

  String get propertyDetails {
    switch (locale.languageCode) {
      case 'zh':
        return '房产详情';
      case 'ms':
        return 'Butiran Hartanah';
      default:
        return 'Property Details';
    }
  }

  String get description {
    switch (locale.languageCode) {
      case 'zh':
        return '描述';
      case 'ms':
        return 'Penerangan';
      default:
        return 'Description';
    }
  }

  String get facilities {
    switch (locale.languageCode) {
      case 'zh':
        return '设施';
      case 'ms':
        return 'Kemudahan';
      default:
        return 'Facilities';
    }
  }

  String get agentInfo {
    switch (locale.languageCode) {
      case 'zh':
        return '代理信息';
      case 'ms':
        return 'Maklumat Ejen';
      default:
        return 'Agent Information';
    }
  }
}

// ============================================================
// Localizations Delegate
// ============================================================
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh', 'ms'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}