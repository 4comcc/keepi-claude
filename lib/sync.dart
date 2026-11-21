import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n.dart';

/// مفتاح publishable عام وآمن للنشر؛ الحماية الفعلية عبر سياسات RLS.
const kSupaUrl = 'https://ktvuggfqjwpcenjnqhlh.supabase.co';
const kSupaKey = 'sb_publishable_8VykSLQRvlh_WwRjBUtrcw_Kd-srGG7';

class SyncService {
  static bool _ok = false;
  static SupabaseClient get _c => Supabase.instance.client;

  static Future<void> init() async {
    try {
      await Supabase.initialize(url: kSupaUrl, anonKey: kSupaKey);
      _ok = true;
    } catch (_) {
      _ok = false;
    }
  }

  static bool get signedIn => _ok && _c.auth.currentSession != null;
  static String? get email => _ok ? _c.auth.currentUser?.email : null;

  static String _msg(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid login')) return tr('البريد أو كلمة المرور غير صحيحة');
      if (m.contains('already')) return tr('هذا البريد مسجّل مسبقاً، سجّل الدخول');
      if (m.contains('password')) return tr('كلمة المرور قصيرة (6 أحرف على الأقل)');
      if (m.contains('confirm')) return tr('فعّل بريدك أولاً عبر الرسالة المرسلة');
      return e.message;
    }
    return tr('تعذّر الاتصال، تحقق من الإنترنت');
  }

  /// يعيد null عند النجاح، أو رسالة خطأ.
  static Future<String?> signIn(String email, String pw) async {
    try {
      await _c.auth.signInWithPassword(email: email, password: pw);
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  /// يعيد 'ok' إن دخل مباشرة، 'confirm' إن لزم تأكيد البريد، وإلا رسالة خطأ.
  static Future<String> signUp(String email, String pw) async {
    try {
      final r = await _c.auth.signUp(email: email, password: pw);
      return r.session != null ? 'ok' : 'confirm';
    } catch (e) {
      return _msg(e);
    }
  }

  static Future<void> signOut() => _c.auth.signOut();

  static Future<List<Map<String, dynamic>>> fetch(String table) async {
    final r = await _c.from(table).select().range(0, 4999);
    return List<Map<String, dynamic>>.from(r as List);
  }

  static Future<void> upsert(String table, List<Map<String, dynamic>> rows) async {
    for (var i = 0; i < rows.length; i += 100) {
      await _c.from(table).upsert(rows.sublist(i, i + 100 > rows.length ? rows.length : i + 100));
    }
  }
}
