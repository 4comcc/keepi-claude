import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ترجمة خفيفة: النص العربي هو المفتاح. لإضافة لغة جديدة: أضف خريطة جديدة
/// في [_maps] واسمها في [L.names].
class L {
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('ar'));
  static const names = {'ar': 'العربية', 'en': 'English'};
  static const rtl = {'ar', 'fa', 'ur', 'he'};

  static String get code => locale.value.languageCode;
  static bool get isAr => code == 'ar';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var c = prefs.getString('lang');
    if (c == null || !names.containsKey(c)) {
      final dev = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      c = names.containsKey(dev) ? dev : 'en';
    }
    locale.value = Locale(c);
  }

  static Future<void> set(String c) async {
    locale.value = Locale(c);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', c);
  }
}

/// يعيد ترجمة النص العربي حسب اللغة الحالية.
String tr(String ar) {
  if (L.isAr) return ar;
  return _en[ar] ?? ar;
}

const _en = <String, String>{
  'اقتراح الحفظ مفعّل': 'Save suggestions on',
  'اقتراح الحفظ متوقف': 'Save suggestions off',
  'تم الحفظ': 'Saved',
  'الحافظة فارغة (النص فقط)': 'Clipboard is empty (text only)',
  'تم اللصق والحفظ': 'Pasted and saved',
  'تم الحذف': 'Deleted',
  'تراجع': 'Undo',
  'الوسوم (افصل بينها بفاصلة)': 'Tags (separate with commas)',
  'تم نسخ النسخة الاحتياطية (النصوص والروابط) إلى الحافظة':
      'Backup (texts and links) copied to clipboard',
  'انسخ أولاً نص النسخة الاحتياطية ثم أعد المحاولة':
      'Copy the backup text first, then try again',
  'جارٍ المزامنة…': 'Syncing…',
  'بلغت الحد المجاني': 'Free limit reached',
  'متزامن ✓': 'Synced ✓',
  'بلغت 500 عنصر (الحد المجاني)': 'You reached 500 items (free limit)',
  'تمت المزامنة': 'Sync complete',
  'تعذّرت المزامنة': 'Sync failed',
  'تعذّرت المزامنة، تحقق من الإنترنت': 'Sync failed, check your connection',
  'وصلت للحد المجاني': 'Free limit reached',
  'الخطة المجانية تتيح مزامنة 500 عنصر. باقي عناصرك محفوظة على هذا الهاتف. الاشتراك المميز (غير محدود) سيتوفر قريباً.':
      'The free plan syncs up to 500 items. The rest stay saved on this phone. Premium (unlimited) is coming soon.',
  'حسناً': 'OK',
  'أدخل البريد وكلمة مرور (6 أحرف فأكثر)':
      'Enter your email and a password (6+ characters)',
  'أُرسلت رسالة تأكيد إلى بريدك. فعّله ثم سجّل الدخول.':
      'A confirmation email was sent. Confirm it, then sign in.',
  'الحساب والمزامنة': 'Account & sync',
  'مزامنة الآن': 'Sync now',
  'تسجيل الخروج': 'Sign out',
  'سجّل الدخول لمزامنة عناصرك بين أجهزتك':
      'Sign in to sync your items across devices',
  'البريد الإلكتروني': 'Email',
  'كلمة المرور': 'Password',
  'دخول': 'Sign in',
  'إنشاء حساب جديد': 'Create account',
  'الاستخدام دون حساب متاح دائماً، وعناصرك تبقى على هاتفك.':
      'You can always use the app without an account; items stay on your phone.',
  'الاسم': 'Name',
  'إلغاء': 'Cancel',
  'حفظ': 'Save',
  'مساحة عمل جديدة': 'New workspace',
  'إعادة تسمية': 'Rename',
  'حذف المساحة (تبقى عناصرها)': 'Delete workspace (items are kept)',
  'نقل إلى مساحة عمل': 'Move to workspace',
  'بدون مساحة': 'No workspace',
  'الكل': 'All',
  'المفضلة': 'Favorites',
  'تم النسخ': 'Copied',
  'إضافة': 'Add',
  'احفظ أي شيء بسرعة': 'Save anything, fast',
  'إيقاف اقتراح الحفظ': 'Turn off save suggestions',
  'تفعيل اقتراح الحفظ': 'Turn on save suggestions',
  'لصق وحفظ': 'Paste & save',
  'المزيد': 'More',
  'نسخ احتياطي (نسخ إلى الحافظة)': 'Backup (copy to clipboard)',
  'استعادة من الحافظة': 'Restore from clipboard',
  'اللغة': 'Language',
  'بحث': 'Search',
  'ابحث في محفوظاتك...': 'Search your items...',
  'نصوص': 'Texts',
  'روابط': 'Links',
  'صور': 'Images',
  'رابط جديد في الحافظة': 'New link in clipboard',
  'نص جديد في الحافظة': 'New text in clipboard',
  'تجاهل': 'Dismiss',
  'احفظ': 'Save',
  'لا يوجد شيء هنا بعد': 'Nothing here yet',
  'لا توجد نتائج': 'No results',
  'انسخ نصاً أو رابطاً ثم افتح التطبيق، أو حدّد أي نص واختر «Keepi» من قائمة التحديد، أو شارك محتوى إليه مباشرة.':
      'Copy a text or link then open the app, or select any text and choose “Keepi” from the selection menu, or share content to it directly.',
  'جرّب كلمة بحث أخرى أو غيّر التصنيف.':
      'Try another search term or change the filter.',
  'رابط': 'Link',
  'صورة': 'Image',
  'نص': 'Text',
  'نسخ': 'Copy',
  'إزالة من المفضلة': 'Remove from favorites',
  'مفضلة': 'Favorite',
  'إلغاء التثبيت': 'Unpin',
  'تثبيت': 'Pin',
  'وسوم': 'Tags',
  'نقل': 'Move',
  'حذف': 'Delete',
  'إضافة جديدة': 'Add new',
  'لصق': 'Paste',
  'كتابة': 'Type',
  'معرض': 'Gallery',
  'كاميرا': 'Camera',
  'نص أو رابط': 'Text or link',
  'اكتب هنا أو الصق رابطاً...': 'Type here or paste a link...',
  'البريد أو كلمة المرور غير صحيحة': 'Wrong email or password',
  'هذا البريد مسجّل مسبقاً، سجّل الدخول': 'Email already registered, sign in',
  'كلمة المرور قصيرة (6 أحرف على الأقل)': 'Password too short (6+ characters)',
  'فعّل بريدك أولاً عبر الرسالة المرسلة': 'Confirm your email first',
  'تعذّر الاتصال، تحقق من الإنترنت': 'Connection failed, check your internet',
};
