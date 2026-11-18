import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// يُستبدل أثناء البناء برقم البناء، لتتأكد أي نسخة مثبتة عندك.
const kBuildLabel = 'dev';

void main() => runApp(const QuickKeepApp());

/// هوية كويك كيب: أخضر مائل للزمردي + كهرماني.
class Brand {
  static const tealLight = Color(0xFF2BA58A);
  static const tealMid = Color(0xFF1E6F5C);
  static const tealDeep = Color(0xFF145A4A);
  static const tealDarkest = Color(0xFF0F4A3D);
  static const amber = Color(0xFFFFB703);
  static const onAmber = Color(0xFF3B2A00);
  static const mint = Color(0xFFB2D6CD);
  static const bgLight = Color(0xFFF2F8F6);
  static const bgDark = Color(0xFF0C1A16);
  static const surfaceDark = Color(0xFF15281F);
}

class QuickKeepApp extends StatelessWidget {
  const QuickKeepApp({super.key});

  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final base = ColorScheme.fromSeed(seedColor: Brand.tealMid, brightness: b);
    final scheme = base.copyWith(
      primary: dark ? const Color(0xFF5FD3B3) : Brand.tealMid,
      onPrimary: dark ? Brand.tealDarkest : Colors.white,
      secondary: Brand.amber,
      onSecondary: Brand.onAmber,
      surface: dark ? Brand.surfaceDark : Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Tajawal',
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? Brand.bgDark : Brand.bgLight,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF244036) : Brand.tealDarkest,
        contentTextStyle:
            const TextStyle(fontFamily: 'Tajawal', color: Colors.white),
        actionTextColor: Brand.amber,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keepi',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const HomePage(),
    );
  }
}

enum ItemType { text, link, image }

class Item {
  final String id;
  final ItemType type;
  final String content; // نص، رابط، أو اسم ملف الصورة
  final DateTime createdAt;
  bool pinned;

  Item({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    this.pinned = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'pinned': pinned,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'],
        type: ItemType.values.byName(j['type']),
        content: j['content'],
        createdAt: DateTime.parse(j['createdAt']),
        pinned: j['pinned'] ?? false,
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _prefsKey = 'items_v1';
  static const _suggestKey = 'suggest_clip';
  static const _lastClipKey = 'last_clip';

  final List<Item> _items = [];
  final _search = TextEditingController();
  String _query = '';
  ItemType? _filter;
  late Directory _imgDir;
  StreamSubscription? _shareSub;
  bool _ready = false;
  bool _suggest = true;
  String? _lastClip;
  String? _suggestion; // نص مقترح للحفظ من الحافظة

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready) {
      // قد تضيف عناصر خارج التطبيق (قائمة تحديد النص)، فنعيد التحميل أولاً.
      _loadItems().then((_) => _checkClipboard());
    }
  }

  Future<void> _init() async {
    final docs = await getApplicationDocumentsDirectory();
    _imgDir = Directory(p.join(docs.path, 'images'));
    await _imgDir.create(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    _suggest = prefs.getBool(_suggestKey) ?? true;
    _lastClip = prefs.getString(_lastClipKey);
    await _loadItems();
    setState(() => _ready = true);
    _checkClipboard();

    // استقبال المشاركة من التطبيقات الأخرى
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initial.isNotEmpty) {
      await _handleShared(initial);
      ReceiveSharingIntent.instance.reset();
    }
    _shareSub =
        ReceiveSharingIntent.instance.getMediaStream().listen(_handleShared);
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_prefsKey);
    final loaded = <Item>[];
    if (raw != null) {
      for (final e in jsonDecode(raw) as List) {
        loaded.add(Item.fromJson(e as Map<String, dynamic>));
      }
    }
    _items
      ..clear()
      ..addAll(loaded);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  bool _isLink(String s) {
    final u = Uri.tryParse(s.trim());
    return u != null &&
        (u.scheme == 'http' || u.scheme == 'https') &&
        u.host.isNotEmpty;
  }

  /// عند فتح التطبيق: إن وُجد نص جديد في الحافظة لم يُحفظ، نقترح حفظه.
  Future<void> _checkClipboard() async {
    if (!_suggest || !_ready || !mounted) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || text == _lastClip) return;
    _lastClip = text;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastClipKey, text);
    if (_items.any((e) => e.content == text)) return;
    if (mounted) setState(() => _suggestion = text);
  }

  Future<void> _toggleSuggest() async {
    setState(() {
      _suggest = !_suggest;
      if (!_suggest) _suggestion = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_suggestKey, _suggest);
    _toast(_suggest ? 'اقتراح الحفظ مفعّل' : 'اقتراح الحفظ متوقف');
  }

  Future<void> _addText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    _items.insert(
      0,
      Item(
        id: _newId(),
        type: _isLink(t) ? ItemType.link : ItemType.text,
        content: t,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _addImageFile(String path) async {
    final name = '${_newId()}${p.extension(path)}';
    await File(path).copy(p.join(_imgDir.path, name));
    _items.insert(
      0,
      Item(
        id: _newId(),
        type: ItemType.image,
        content: name,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _handleShared(List<SharedMediaFile> files) async {
    for (final f in files) {
      if (f.type == SharedMediaType.image) {
        await _addImageFile(f.path);
      } else if (f.type == SharedMediaType.text ||
          f.type == SharedMediaType.url) {
        await _addText(f.path);
      }
    }
    _toast('تم الحفظ');
  }

  Future<void> _pasteAndSave() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _toast('الحافظة فارغة (النص فقط)');
      return;
    }
    await _addText(text);
    setState(() => _suggestion = null);
    _toast('تم اللصق والحفظ');
  }

  Future<void> _pickImage(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, imageQuality: 85);
    if (x != null) await _addImageFile(x.path);
  }

  /// حذف مع إمكانية التراجع.
  Future<void> _deleteWithUndo(Item it) async {
    final idx = _items.indexWhere((e) => e.id == it.id);
    if (idx < 0) return;
    _items.removeAt(idx);
    setState(() {}); // متزامن: مطلوب من Dismissible
    _save();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final ctrl = messenger.showSnackBar(
      SnackBar(
        content: const Text('تم الحذف'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () async {
            _items.insert(math.min(idx, _items.length), it);
            await _save();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
    final reason = await ctrl.closed;
    if (reason != SnackBarClosedReason.action && it.type == ItemType.image) {
      final f = File(p.join(_imgDir.path, it.content));
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> _togglePin(Item it) async {
    it.pinned = !it.pinned;
    await _save();
    setState(() {});
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  List<Item> get _visible {
    final list = _items.where((e) {
      if (_filter != null && e.type != _filter) return false;
      if (_query.isNotEmpty) {
        if (e.type == ItemType.image) return false;
        return e.content.toLowerCase().contains(_query.toLowerCase());
      }
      return true;
    }).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Future<void> _open(Item it) async {
    if (it.type == ItemType.link) {
      await launchUrl(Uri.parse(it.content),
          mode: LaunchMode.externalApplication);
    } else if (it.type == ItemType.image) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
            ),
            extendBodyBehindAppBar: true,
            body: Center(
              child: InteractiveViewer(
                child: Image.file(File(p.join(_imgDir.path, it.content))),
              ),
            ),
          ),
        ),
      );
    } else {
      await Clipboard.setData(ClipboardData(text: it.content));
      _toast('تم النسخ');
    }
  }

  // ───────────────────────── الواجهة ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Column(
          children: [
            _header(),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _suggestion == null
                  ? const SizedBox(width: double.infinity)
                  : _suggestionCard(_suggestion!),
            ),
            Expanded(
              child: !_ready
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? _empty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _card(items[i]),
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddMenu,
          backgroundColor: Brand.amber,
          foregroundColor: Brand.onAmber,
          elevation: 3,
          icon: const Icon(Icons.add_rounded, size: 26),
          label: const Text('إضافة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Brand.tealLight, Brand.tealDeep],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/icon/icon.png',
                        width: 40, height: 40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Keepi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          _items.isEmpty
                              ? 'احفظ أي شيء بسرعة · $kBuildLabel'
                              : '${_items.length} عنصر محفوظ · $kBuildLabel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip:
                        _suggest ? 'إيقاف اقتراح الحفظ' : 'تفعيل اقتراح الحفظ',
                    color: Colors.white,
                    icon: Icon(_suggest
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_outlined),
                    onPressed: _toggleSuggest,
                  ),
                  IconButton(
                    tooltip: 'لصق وحفظ',
                    color: Colors.white,
                    icon: const Icon(Icons.content_paste_go_rounded),
                    onPressed: _pasteAndSave,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'ابحث في محفوظاتك...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.8)),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: Row(
                  children: [
                    _chip('الكل', Icons.apps_rounded, null),
                    _chip('نصوص', Icons.notes_rounded, ItemType.text),
                    _chip('روابط', Icons.link_rounded, ItemType.link),
                    _chip('صور', Icons.image_outlined, ItemType.image),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, ItemType? t) {
    final sel = _filter == t;
    final fg = sel ? Brand.tealDeep : Colors.white;
    return Expanded(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: GestureDetector(
          onTap: () => setState(() => _filter = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
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

  Widget _suggestionCard(String text) {
    final link = _isLink(text);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _dark ? const Color(0xFF1C3A30) : const Color(0xFFE3F3EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Brand.amber.withValues(alpha: 0.8), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(link ? Icons.link_rounded : Icons.content_paste_rounded,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                link ? 'رابط جديد في الحافظة' : 'نص جديد في الحافظة',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  height: 1.4,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _suggestion = null),
                child: const Text('تجاهل'),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.amber,
                  foregroundColor: Brand.onAmber,
                ),
                icon: const Icon(Icons.bookmark_add_rounded, size: 19),
                label: const Text('احفظ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  setState(() => _suggestion = null);
                  await _addText(text);
                  _toast('تم الحفظ');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    final noItems = _items.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Brand.tealDeep.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/icon/icon.png',
                    width: 96, height: 96),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              noItems ? 'لا يوجد شيء هنا بعد' : 'لا توجد نتائج',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              noItems
                  ? 'انسخ نصاً أو رابطاً ثم افتح التطبيق، أو حدّد أي نص واختر «Keepi» من قائمة التحديد، أو شارك محتوى إليه مباشرة.'
                  : 'جرّب كلمة بحث أخرى أو غيّر التصنيف.',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.6,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _accent(ItemType t) {
    switch (t) {
      case ItemType.link:
        return _dark ? const Color(0xFF5FD3B3) : Brand.tealLight;
      case ItemType.image:
        return Brand.amber;
      case ItemType.text:
        return _dark ? const Color(0xFF8FB8AC) : Brand.tealMid;
    }
  }

  String _typeLabel(ItemType t) {
    switch (t) {
      case ItemType.link:
        return 'رابط';
      case ItemType.image:
        return 'صورة';
      case ItemType.text:
        return 'نص';
    }
  }

  IconData _typeIcon(ItemType t) {
    switch (t) {
      case ItemType.link:
        return Icons.link_rounded;
      case ItemType.image:
        return Icons.image_outlined;
      case ItemType.text:
        return Icons.notes_rounded;
    }
  }

  String _when(DateTime utcOrLocal) {
    final d = utcOrLocal.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'اليوم $hm';
    if (diff == 1) return 'أمس $hm';
    return '${d.year}/${d.month}/${d.day}';
  }

  String _host(String url) {
    final h = Uri.tryParse(url)?.host ?? url;
    return h.startsWith('www.') ? h.substring(4) : h;
  }

  Widget _card(Item it) {
    final cs = Theme.of(context).colorScheme;
    final accent = _accent(it.type);

    final Widget body;
    switch (it.type) {
      case ItemType.image:
        body = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(p.join(_imgDir.path, it.content)),
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      case ItemType.link:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _host(it.content),
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              it.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      case ItemType.text:
        body = Text(
          it.content,
          maxLines: 7,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15.5, height: 1.55),
        );
    }

    Widget action(IconData icon, String tip, VoidCallback onTap,
        {Color? color}) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: tip,
        icon: Icon(icon, size: 21),
        color: color ?? cs.onSurface.withValues(alpha: 0.6),
        onPressed: onTap,
      );
    }

    return Dismissible(
      key: ValueKey(it.id),
      onDismissed: (_) => _deleteWithUndo(it),
      background: _swipeBg(Alignment.centerRight),
      secondaryBackground: _swipeBg(Alignment.centerLeft),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: it.pinned
                ? Brand.amber.withValues(alpha: 0.9)
                : (_dark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Brand.tealDeep.withValues(alpha: 0.08)),
            width: it.pinned ? 1.4 : 1,
          ),
          boxShadow: _dark
              ? null
              : [
                  BoxShadow(
                    color: Brand.tealDeep.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _open(it),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_typeIcon(it.type),
                                        size: 15,
                                        color: it.type == ItemType.image
                                            ? (_dark
                                                ? Brand.amber
                                                : const Color(0xFFB27F00))
                                            : accent),
                                    const SizedBox(width: 5),
                                    Text(
                                      _typeLabel(it.type),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: it.type == ItemType.image
                                            ? (_dark
                                                ? Brand.amber
                                                : const Color(0xFFB27F00))
                                            : accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (it.pinned)
                                const Padding(
                                  padding: EdgeInsetsDirectional.only(end: 6),
                                  child: Icon(Icons.push_pin_rounded,
                                      size: 18, color: Brand.amber),
                                ),
                              Text(
                                _when(it.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          body,
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (it.type != ItemType.image)
                                action(Icons.copy_rounded, 'نسخ', () {
                                  Clipboard.setData(
                                      ClipboardData(text: it.content));
                                  _toast('تم النسخ');
                                }),
                              action(
                                it.pinned
                                    ? Icons.push_pin_rounded
                                    : Icons.push_pin_outlined,
                                it.pinned ? 'إلغاء التثبيت' : 'تثبيت',
                                () => _togglePin(it),
                                color: it.pinned ? Brand.amber : null,
                              ),
                              action(Icons.delete_outline_rounded, 'حذف',
                                  () => _deleteWithUndo(it)),
                            ],
                          ),
                        ],
                      ),
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

  Widget _swipeBg(Alignment align) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: align,
      decoration: BoxDecoration(
        color: const Color(0xFFD64545),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.delete_rounded, color: Colors.white),
    );
  }

  // ─────────────────────── قوائم الإضافة ───────────────────────

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Text('إضافة جديدة',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  _addTile(ctx, Icons.content_paste_rounded, 'لصق',
                      Brand.tealLight, _pasteAndSave),
                  _addTile(ctx, Icons.edit_note_rounded, 'كتابة',
                      Brand.tealMid, _showAddText),
                  _addTile(ctx, Icons.photo_library_outlined, 'معرض',
                      const Color(0xFFE09A00),
                      () => _pickImage(ImageSource.gallery)),
                  _addTile(ctx, Icons.photo_camera_outlined, 'كاميرا',
                      const Color(0xFF3C8DAD),
                      () => _pickImage(ImageSource.camera)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addTile(BuildContext ctx, IconData icon, String label, Color color,
      VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.pop(ctx);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddText() {
    final c = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text('نص أو رابط',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            TextField(
              controller: c,
              autofocus: true,
              minLines: 4,
              maxLines: 9,
              decoration: InputDecoration(
                hintText: 'اكتب هنا أو الصق رابطاً...',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.tealMid,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.bookmark_add_rounded),
                label: const Text('حفظ',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () {
                  _addText(c.text);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
