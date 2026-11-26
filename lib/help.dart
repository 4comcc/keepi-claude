import 'package:flutter/material.dart';

import 'l10n.dart';

class _Line {
  final IconData? icon;
  final String ar, en;
  const _Line(this.ar, this.en, [this.icon]);
}

class _Sec {
  final IconData icon;
  final String ar, en;
  final List<_Line> lines;
  const _Sec(this.icon, this.ar, this.en, this.lines);
}

const _secs = <_Sec>[
  _Sec(Icons.bubble_chart_rounded, 'الزر العائم: احفظ بلمسة واحدة',
      'Floating button: save with one touch', [
    _Line(
        'فعّله من الإعدادات ثم اسمح لـ Keepi بالظهور فوق التطبيقات، فتظهر دائرة صغيرة فوق أي تطبيق.',
        'Turn it on in Settings and allow Keepi to display over other apps. A small bubble then floats above any app.',
        Icons.toggle_on_rounded),
    _Line('انسخ أي نص أو رابط ثم اضغط الدائرة: يُحفظ فوراً وتومض الدائرة للتأكيد.',
        'Copy any text or link, then tap the bubble: it is saved instantly and the bubble flashes to confirm.',
        Icons.touch_app_rounded),
    _Line('ضغطة مطوّلة تفتح Keepi، وإن كانت الحافظة فارغة تفتح الضغطة العادية Keepi أيضاً.',
        'A long press opens Keepi. If the clipboard is empty, a normal tap opens Keepi too.',
        Icons.open_in_new_rounded),
    _Line('اسحبها إلى المكان الذي يريحك، وتلتصق بأقرب حافة.',
        'Drag it anywhere you like; it snaps to the nearest edge.',
        Icons.open_with_rounded),
    _Line('داخل Keepi نفسه تعيدك الضغطة إلى التطبيق السابق.',
        'Inside Keepi itself, a tap takes you back to your previous app.',
        Icons.undo_rounded),
  ]),
  _Sec(Icons.screenshot_rounded, 'لقطات الشاشة', 'Screenshots', [
    _Line('فعّل «اقتراح حفظ لقطة الشاشة» من الإعدادات.',
        'Turn on “Suggest saving screenshots” in Settings.',
        Icons.toggle_on_rounded),
    _Line('بعد أي لقطة تتحول الدائرة إلى اللون الكهرماني؛ اضغطها لتحفظ اللقطة.',
        'After a screenshot the bubble turns amber; tap it to save the screenshot.',
        Icons.bubble_chart_rounded),
    _Line('عند فتح Keepi تظهر بطاقة «لقطة شاشة جديدة» فيها احفظ أو تجاهل.',
        'When you open Keepi, a “New screenshot” card offers Save or Dismiss.',
        Icons.bookmark_add_rounded),
  ]),
  _Sec(Icons.ios_share_rounded, 'طرق الحفظ الأخرى', 'More ways to save', [
    _Line('من أي تطبيق: مشاركة ثم اختر Keepi (نصوص وروابط وصور وفيديو).',
        'From any app: Share, then choose Keepi (text, links, images, video).',
        Icons.share_rounded),
    _Line('حدّد نصاً في أي تطبيق واختر Keepi من القائمة.',
        'Select text in any app and choose Keepi from the menu.',
        Icons.text_fields_rounded),
    _Line('زر اللصق في أعلى الشاشة يحفظ ما نسخته.',
        'The paste button at the top saves what you copied.',
        Icons.content_paste_go_rounded),
    _Line('زر «إضافة» لكتابة نص أو إضافة صورة يدوياً.',
        'The Add button lets you type text or add an image manually.',
        Icons.add_rounded),
    _Line('اقتراح الحفظ: يعرض Keepi ما نسخته حديثاً لتحفظه بضغطة.',
        'Save suggestions: Keepi shows what you just copied so you can save it in one tap.',
        Icons.lightbulb_outline_rounded),
  ]),
  _Sec(Icons.grid_view_rounded, 'أنواع البطاقات', 'Card types', [
    _Line('نص: ما تكتبه أو تنسخه.', 'Text: what you type or copy.', Icons.notes_rounded),
    _Line('رابط: يعرض اسم الموقع والرابط، وبالضغط يفتح.',
        'Link: shows the site name and URL; tap to open.', Icons.link_rounded),
    _Line('صورة: محفوظة على هاتفك، وبالضغط تُعرض كاملة.',
        'Image: stored on your phone; tap to view it full size.',
        Icons.image_outlined),
    _Line('فيديو: روابط يوتيوب وتيك توك وإنستجرام وفيسبوك، مع الكابشن.',
        'Video: YouTube, TikTok, Instagram and Facebook links, with the caption.',
        Icons.play_circle_outline_rounded),
  ]),
  _Sec(Icons.touch_app_rounded, 'أيقونات البطاقة', 'Card icons', [
    _Line('نسخ المحتوى إلى الحافظة.', 'Copy the content to the clipboard.', Icons.copy_rounded),
    _Line('مفضلة: تجدها لاحقاً من تبويب المفضلة.',
        'Favorite: find it later in the Favorites tab.', Icons.star_outline_rounded),
    _Line('تثبيت: تبقى البطاقة في أعلى القائمة.',
        'Pin: keeps the card at the top of the list.', Icons.push_pin_outlined),
    _Line('ملاحظة: اكتب تعليقك الخاص (وللفيديو: تعديل الكابشن).',
        'Note: write your own comment (for videos: edit the caption).',
        Icons.edit_note_rounded),
    _Line('مشاركة: أرسل النص أو الرابط أو الصورة إلى أي تطبيق.',
        'Share: send the text, link or image to any app.', Icons.share_rounded),
    _Line('المزيد: الوسوم 🏷️ ونقل البطاقة إلى مساحة 📁.',
        'More: tags and moving the card to a workspace.', Icons.more_horiz_rounded),
    _Line('حذف: ينقل البطاقة إلى سلة المهملات، ويمكنك التراجع فوراً.',
        'Delete: moves the card to Trash, and you can undo right away.',
        Icons.delete_outline_rounded),
    _Line('السحب يميناً أو يساراً على البطاقة يحذفها أيضاً.',
        'Swiping a card left or right deletes it too.', Icons.swipe_rounded),
  ]),
  _Sec(Icons.folder_open_rounded, 'المساحات والوسوم والبحث',
      'Workspaces, tags & search', [
    _Line('المساحات (عمل، دراسة…) تنظّم بطاقاتك؛ أنشئها من زر المجلد في الأعلى.',
        'Workspaces (Work, Study…) organize your cards; create them with the folder button at the top.',
        Icons.create_new_folder_outlined),
    _Line('الوسوم #: اكتبها مفصولة بفاصلة، وبالضغط على وسم ترى كل ما يحمله.',
        'Tags #: type them separated by commas; tap a tag to see everything with it.',
        Icons.sell_outlined),
    _Line('البحث يشمل النصوص والوسوم والملاحظات. ويُمسح تلقائياً بعد غيابك 5 دقائق.',
        'Search covers text, tags and notes, and clears itself after 5 minutes away.',
        Icons.search_rounded),
  ]),
  _Sec(Icons.delete_outline_rounded, 'سلة المهملات', 'Trash', [
    _Line('المحذوفات تبقى 30 يوماً: استعدها أو احذفها نهائياً أو أفرغ السلة من الإعدادات.',
        'Deleted items stay for 30 days: restore them, delete forever, or empty the trash from Settings.',
        Icons.restore_rounded),
  ]),
  _Sec(Icons.cloud_sync_outlined, 'الحساب والمزامنة', 'Account & sync', [
    _Line('ادخل بحساب جوجل أو بالبريد لمزامنة عناصرك بين أجهزتك.',
        'Sign in with Google or email to sync your items across devices.',
        Icons.login_rounded),
    _Line('الخطة المجانية تزامن حتى 500 عنصر، والصور تبقى على الهاتف.',
        'The free plan syncs up to 500 items; images stay on the phone.',
        Icons.photo_library_outlined),
    _Line('عند تبديل الحساب يسألك Keepi: دمج عناصر الهاتف أو مسحها.',
        'When you switch accounts, Keepi asks whether to merge or clear the items on the phone.',
        Icons.swap_horiz_rounded),
  ]),
  _Sec(Icons.settings_rounded, 'المظهر والبيانات', 'Appearance & data', [
    _Line('الوضع الداكن أو الفاتح أو التلقائي، واللغة العربية أو الإنجليزية.',
        'Dark, light or automatic mode, and Arabic or English.',
        Icons.dark_mode_rounded),
    _Line('نسخ احتياطي: انسخ بياناتك إلى الحافظة واحفظها في أي مكان، واستعدها لاحقاً.',
        'Backup: copy your data to the clipboard, keep it anywhere, and restore it later.',
        Icons.upload_rounded),
  ]),
];

const _faq = <List<String>>[
  [
    'هل بياناتي آمنة؟',
    'Is my data safe?',
    'بياناتك محفوظة على هاتفك، وإن سجّلت الدخول تُحمى في حسابك بسياسات وصول خاصة بك وحدك.',
    'Your data lives on your phone, and if you sign in it is protected in your account with access rules that are yours alone.'
  ],
  [
    'هل يعمل بلا إنترنت؟',
    'Does it work offline?',
    'نعم، الحفظ والتعديل والبحث تعمل دون إنترنت، وتتزامن عند عودته.',
    'Yes. Saving, editing and search work offline and sync when you are back online.'
  ],
  [
    'لماذا لا تظهر صوري على جهاز آخر؟',
    'Why are my images not on another device?',
    'الصور تُحفظ على هاتفك فقط حفاظاً على خصوصيتك وحجم حسابك.',
    'Images are kept on your phone only, to protect your privacy and keep your account light.'
  ],
  [
    'الزر العائم توقف عن العمل؟',
    'The floating button stopped working?',
    'على بعض الأجهزة يوقفه توفير البطارية. ثبّت Keepi في التطبيقات الأخيرة واسمح له بالعمل في الخلفية.',
    'On some phones battery saving stops it. Lock Keepi in recent apps and allow background activity.'
  ],
];

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ar = L.isAr;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark
        ? Colors.white.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.06);

    Widget secCard(_Sec s) => Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
              color: card, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: Icon(s.icon, size: 19, color: cs.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(ar ? s.ar : s.en,
                      style: const TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 8),
              for (final l in s.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(l.icon ?? Icons.circle,
                            size: l.icon == null ? 6 : 19,
                            color: cs.primary.withValues(alpha: 0.85)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(ar ? l.ar : l.en,
                            style: const TextStyle(fontSize: 14, height: 1.5)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'مساعدة وطريقة الاستخدام' : 'Help & how to use',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF2BA58A), Color(0xFF145A4A)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Keepi',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                    ar
                        ? 'احفظ كل شيء بلمسة واحدة!'
                        : 'Save anything with one touch!',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFB703))),
                const SizedBox(height: 10),
                Text(
                    ar
                        ? 'Keepi يحفظ نصوصك وروابطك وصورك وفيديوهاتك في مكان واحد منظّم، ويتيح لك العثور عليها بسرعة، وكل ذلك بلمسة واحدة من الزر العائم.'
                        : 'Keepi keeps your texts, links, images and videos in one organized place so you can find them fast, all with one touch of the floating button.',
                    style: const TextStyle(
                        fontSize: 14, height: 1.5, color: Colors.white)),
              ],
            ),
          ),
          for (final s in _secs) secCard(s),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
            child: Text(ar ? 'أسئلة شائعة' : 'FAQ',
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w800)),
          ),
          for (final f in _faq)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ar ? f[0] : f[1],
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(ar ? f[2] : f[3],
                      style: const TextStyle(fontSize: 13.5, height: 1.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
