// constants/env.dart
class Env {
  // ============================================================
  // Supabase Configuration
  // 从 Supabase Project Settings → API 获取
  // ============================================================
  static const String supabaseUrl = 'https://mfzwqmyqosvnhbdadbjp.supabase.co';
  static const String supabasePublishableKey = 'sb_publishable_KEdUSCYs67CoR0P00U_nhQ__KdmJXEK';

  // ============================================================
  // OpenAI Configuration
  // 从 OpenAI Platform → API Keys 获取
  // Put your real key here locally — never commit it to GitHub.
  // ============================================================
  static const String openAiApiKey = 'YOUR_OPENAI_API_KEY_HERE';
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const String gptModel = 'gpt-4o-mini';

// ============================================================
// 可选: 其他配置
// ============================================================
// static const String appName = 'MyHome AI';
// static const String appVersion = '1.0.0';
}
