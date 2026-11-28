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

class ThemeCtl {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('theme');
    mode.value = ThemeMode.values.firstWhere((m) => m.name == v,
        orElse: () => ThemeMode.system);
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', m.name);
  }
}

/// يعيد ترجمة النص العربي حسب اللغة الحالية.
String tr(String ar) {
  if (L.isAr) return ar;
  return _en[ar] ?? ar;
}

const _en = <String, String>{
  'الزر العائم': 'Floating button',
  'ضغطة: حفظ الحافظة · مطوّلة: فتح Keepi': 'Tap: save clipboard · Long press: open Keepi',
  'لقطات الشاشة': 'Screenshots',
  'اقتراح حفظ آخر لقطة وتلوين الزر العائم': 'Suggest saving the latest screenshot and light up the button',
  'اقتراح حفظ ما نسخته عند فتح التطبيق': 'Suggest saving what you copied when the app opens',
  'تعديل': 'Edit',
  'تجاهل التعديلات؟': 'Discard changes?',
  'لديك تعديلات غير محفوظة.': 'You have unsaved changes.',
  'متابعة التحرير': 'Keep editing',
  'أو بالبريد': 'or with email',
  'محفوظاتك خاصة بك وتظهر بعد تسجيل الدخول': 'Your items are private and appear after you sign in',
  'مشاركة': 'Share',
  'تعذّرت المشاركة': 'Could not share',
  'بحث في الإنترنت': 'Search the web',
  'تعذّر فتح البحث': 'Could not open search',
  'احفظ كل شيء بلمسة واحدة!': 'Save anything with one touch!',
  'يقترح حفظ ما نسخته عند فتح التطبيق': 'Suggests saving what you copied when the app opens',
  'حساب مختلف': 'Different account',
  'هذا الهاتف يحتوي عناصر محفوظة من حساب آخر. ماذا تريد أن تفعل بها؟': 'This phone has items saved from another account. What do you want to do with them?',
  'دمجها في هذا الحساب': 'Merge them into this account',
  'مسحها وتحميل عناصر هذا الحساب': 'Delete them and load the items of this account',
  'إلغاء وتسجيل الخروج': 'Cancel and sign out',
  'مسح البحث': 'Clear search',
  'تعذّر الحفظ': 'Could not save',
  'اقتراح حفظ لقطة الشاشة': 'Suggest saving screenshots',
  'تظهر لقطتك الأخيرة للحفظ، وتلوّن النقطة العائمة': 'Shows your latest screenshot to save and highlights the bubble',
  'لقطة شاشة جديدة': 'New screenshot',
  'يلزم السماح بقراءة الصور': 'Photo access is required',
  'نقطة عائمة للحفظ السريع': 'Floating quick-save bubble',
  'ضغطة: حفظ الحافظة · ضغطة مطوّلة: فتح Keepi': 'Tap: save clipboard · Long press: open Keepi',
  'اسمح بالظهور فوق التطبيقات ثم ارجع إلى Keepi': 'Allow display over other apps, then return to Keepi',
  'تعذّر تشغيل النقطة العائمة': 'Could not start the floating bubble',
  'الإعدادات': 'Settings',
  'إغلاق': 'Close',
  'الحساب': 'Account',
  'المظهر واللغة': 'Appearance & language',
  'تلقائي': 'Auto',
  'فاتح': 'Light',
  'داكن': 'Dark',
  'اقتراح الحفظ': 'Save suggestions',
  'الحفظ': 'Saving',
  'البيانات': 'Data',
  'المساعدة': 'Help',
  'مساعدة وطريقة الاستخدام': 'Help & how to use',
  'ملاحظة': 'Note',
  'المتابعة بحساب جوجل': 'Continue with Google',
  'الحفظ السريع': 'Quick save',
  'شارك أي نص أو رابط أو صورة من أي تطبيق إلى Keepi، أو حدّد النص واختر Keepi من القائمة، أو اضغط زر اللصق في الأعلى لحفظ ما نسخته.': 'Share any text, link or image from any app to Keepi, or select text and choose Keepi from the menu, or tap the paste button at the top to save what you copied.',
  'الإضافة اليدوية': 'Manual add',
  'زر «إضافة» في الأسفل لكتابة نص أو إضافة صورة.': 'Use the Add button at the bottom to type text or add an image.',
  'الفيديو': 'Video',
  'روابط يوتيوب وتيك توك وإنستجرام وفيسبوك تظهر في تصنيف الفيديو. أيقونة الملاحظة تتيح كتابة الكابشن.': 'YouTube, TikTok, Instagram and Facebook links appear under Videos. The note icon lets you write the caption.',
  'الملاحظات والوسوم': 'Notes & tags',
  'على كل بطاقة: نسخ، مفضلة، تثبيت، ملاحظة، وسوم، نقل لمساحة، وحذف.': 'Every card has: copy, favorite, pin, note, tags, move to workspace, and delete.',
  'المساحات': 'Workspaces',
  'أنشئ مساحات (مثل عمل، دراسة) من زر المجلد، ثم انقل العناصر إليها.': 'Create workspaces (like Work, Study) with the folder button, then move items into them.',
  'البحث': 'Search',
  'ابحث في النص والوسوم والملاحظات. اضغط على وسم لعرض كل ما يحمله.': 'Search text, tags and notes. Tap a tag to see everything with it.',
  'المحذوفات تبقى 30 يوماً ويمكن استعادتها من الإعدادات.': 'Deleted items stay for 30 days and can be restored from Settings.',
  'المزامنة': 'Sync',
  'سجّل الدخول لمزامنة عناصرك (حتى 500 عنصر مجاناً). الصور تبقى على هاتفك.': 'Sign in to sync your items (up to 500 free). Images stay on your phone.',
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
  'فيديو': 'Videos',
  'تعديل الكابشن': 'Edit caption',
  'سلة المهملات': 'Trash',
  'إفراغ السلة': 'Empty trash',
  'تُحذف العناصر نهائياً بعد 30 يوماً': 'Items are permanently deleted after 30 days',
  'السلة فارغة': 'Trash is empty',
  'استعادة': 'Restore',
  'حذف نهائي': 'Delete forever',

  'سجّل الدخول لعرض محفوظاتك': 'Sign in to view your items',
  'محفوظاتك مخفية حتى تسجّل الدخول، وتختفي بعد تسجيل الخروج.': 'Your items stay hidden until you sign in, and hide again after you sign out.',
  'تسجيل الدخول': 'Sign in',
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
