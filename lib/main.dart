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
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'help.dart';
import 'l10n.dart';
import 'sync.dart';

/// يُستبدل أثناء البناء برقم البناء، لتتأكد أي نسخة مثبتة عندك.
const kBuildLabel = 'dev';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await L.load();
  await ThemeCtl.load();
  await SyncService.init();
  runApp(const QuickKeepApp());
}

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeCtl.mode,
      builder: (context, tm, _) => ValueListenableBuilder<Locale>(
      valueListenable: L.locale,
      builder: (context, loc, _) => MaterialApp(
      title: 'Keepi',
      debugShowCheckedModeBanner: false,
      locale: loc,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: tm,
      home: const HomePage(),
    )));
  }
}

enum ItemType { text, link, image, video }

class Item {
  final String id;
  final ItemType type;
  String content; // نص، رابط، أو اسم ملف الصورة
  final DateTime createdAt;
  DateTime updatedAt;
  bool pinned;
  bool fav;
  String? ws;
  List<String> tags;

  static const _np = '\u200bnote:';
  String get note {
    for (final t in tags) {
      if (t.startsWith(_np)) return t.substring(_np.length);
    }
    return '';
  }

  set note(String v) {
    tags.removeWhere((t) => t.startsWith(_np));
    if (v.trim().isNotEmpty) tags.add('$_np${v.trim()}');
  }

  List<String> get shownTags =>
      tags.where((t) => !t.startsWith(_np)).toList();

  Item({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    DateTime? updatedAt,
    this.pinned = false,
    this.fav = false,
    this.ws,
    List<String>? tags,
  })  : tags = tags ?? [],
        updatedAt = updatedAt ?? createdAt;

  static final _urlRe = RegExp(r'https?://[^\s]+');
  static final _videoRes = <RegExp>[
    RegExp(r'https?://(?:[\w-]+\.)*(?:youtube\.com|youtu\.be|tiktok\.com|vimeo\.com|dailymotion\.com|twitch\.tv|fb\.watch)(?:[/?#]\S*)?', caseSensitive: false),
    RegExp(r'https?://(?:[\w-]+\.)*instagram\.com/(?:reels?|tv|p)/\S*', caseSensitive: false),
    RegExp(r'https?://(?:[\w-]+\.)*facebook\.com/(?:watch|reel|share/[vr]|[^\s/]+/videos)\S*', caseSensitive: false),
  ];

  /// رابط الفيديو إن كان المحتوى يتضمن رابط منصة فيديو (يُشتق ولا يُخزَّن).
  String? get videoUrl {
    if (type == ItemType.image) return null;
    for (final m in _urlRe.allMatches(content)) {
      final u = m.group(0)!;
      if (_videoRes.any((r) => r.hasMatch(u))) return u;
    }
    return null;
  }

  /// الكابشن = النص المصاحب للرابط.
  String get caption {
    final u = videoUrl;
    return u == null ? '' : content.replaceFirst(u, '').trim();
  }

  ItemType get kind => videoUrl != null ? ItemType.video : type;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'pinned': pinned,
        'fav': fav,
        'ws': ws,
        'tags': tags,
        'updatedAt': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toRemote({bool deleted = false}) => {
        'id': id,
        'type': type.name,
        'content': content,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': (deleted ? DateTime.now() : updatedAt).toUtc().toIso8601String(),
        'pinned': pinned,
        'fav': fav,
        'ws': ws,
        'tags': tags,
        'deleted': deleted,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'],
        type: ItemType.values.byName(j['type']),
        content: j['content'],
        createdAt: DateTime.parse(j['createdAt']),
        pinned: j['pinned'] ?? false,
        fav: j['fav'] ?? false,
        ws: j['ws'] as String?,
        tags: ((j['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
        updatedAt: j['updatedAt'] == null ? null : DateTime.tryParse(j['updatedAt']),
      );
}

class Workspace {
  final String id;
  String name;
  DateTime updatedAt;
  Workspace(this.id, this.name, [DateTime? u])
      : updatedAt = u ?? DateTime.fromMillisecondsSinceEpoch(0);
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'updatedAt': updatedAt.toIso8601String()};
  Map<String, dynamic> toRemote({bool deleted = false}) => {
        'id': id,
        'name': name,
        'updated_at': (deleted || updatedAt.millisecondsSinceEpoch == 0
                ? DateTime.now()
                : updatedAt)
            .toUtc()
            .toIso8601String(),
        'deleted': deleted,
      };
  factory Workspace.fromJson(Map<String, dynamic> j) => Workspace(
      j['id'],
      j['name'],
      j['updatedAt'] == null ? null : DateTime.tryParse(j['updatedAt']));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _prefsKey = 'items_v1';
  static const _suggestKey = 'suggest_clip';
  static const _bubbleCh = MethodChannel('keepi/bubble');
  static const _bubbleKey = 'bubble_on';
  bool _bubbleOn = false;
  bool _shotOn = false;
  int? _shotId;

  Future<void> _checkShot() async {
    if (!_shotOn || !_ready || !mounted) return;
    try {
      final id = await _bubbleCh.invokeMethod<int>('latestShot');
      if (id != null && mounted) setState(() => _shotId = id);
    } catch (_) {}
  }

  Future<void> _toggleShot(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    if (on) {
      bool ok = false;
      try {
        ok = await _bubbleCh.invokeMethod<bool>('requestShotPerm') == true;
      } catch (_) {}
      if (!ok) {
        _toast(tr('يلزم السماح بقراءة الصور'));
        return;
      }
    }
    await prefs.setBool('shot_on', on);
    setState(() {
      _shotOn = on;
      if (!on) _shotId = null;
    });
    if (on) _checkShot();
  }

  Future<void> _saveShot() async {
    final id = _shotId;
    if (id == null) return;
    setState(() => _shotId = null);
    try {
      await _bubbleCh.invokeMethod('saveShot', id);
      await _loadItems();
      if (mounted) setState(() {});
      _toast(tr('تم الحفظ'));
    } catch (_) {
      _toast(tr('تعذّر الحفظ'));
    }
  }

  Future<void> _dismissShot() async {
    final id = _shotId;
    setState(() => _shotId = null);
    if (id != null) {
      try {
        await _bubbleCh.invokeMethod('dismissShot', id);
      } catch (_) {}
    }
  }

  Future<void> _bubbleSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _bubbleOn = prefs.getBool(_bubbleKey) ?? false;
      _shotOn = prefs.getBool('shot_on') ?? false;
      if (!_bubbleOn) return;
      if (await _bubbleCh.invokeMethod<bool>('canDraw') == true) {
        await _bubbleCh.invokeMethod('start');
      }
    } catch (_) {}
  }

  Future<void> _toggleBubble(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (on) {
        if (await _bubbleCh.invokeMethod<bool>('canDraw') != true) {
          await prefs.setBool(_bubbleKey, true);
          setState(() => _bubbleOn = true);
          _toast(tr('اسمح بالظهور فوق التطبيقات ثم ارجع إلى Keepi'));
          await _bubbleCh.invokeMethod('requestPermission');
          return;
        }
        final ok = await _bubbleCh.invokeMethod<bool>('start') == true;
        if (!ok) {
          _toast(tr('تعذّر تشغيل النقطة العائمة'));
          return;
        }
      } else {
        await _bubbleCh.invokeMethod('stop');
      }
      await prefs.setBool(_bubbleKey, on);
      setState(() => _bubbleOn = on);
    } catch (_) {
      _toast(tr('تعذّر تشغيل النقطة العائمة'));
    }
  }
  static const _lastClipKey = 'last_clip';

  final List<Item> _items = [];
  final _search = TextEditingController();
  String _query = '';
  ItemType? _filter;
  final List<Workspace> _workspaces = [];
  String? _wsFilter;
  bool _favOnly = false;
  static const _wsKey = 'workspaces_v1';
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
    L.locale.addListener(_onLang);
    _authSub = SyncService.authChanges.listen((_) async {
      if (SyncService.signedIn) await _adoptOwner();
      if (mounted) setState(() {});
      if (SyncService.signedIn) _sync();
    });
    _init();
  }

  void _onLang() {
    if (mounted) setState(() {});
  }

  DateTime? _pausedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final t = _pausedAt;
      _pausedAt = null;
      if (t != null &&
          DateTime.now().difference(t).inMinutes >= 5 &&
          (_query.isNotEmpty || _searching)) {
        setState(() {
          _search.clear();
          _query = '';
          _searching = false;
        });
      }
    }
    if (state == AppLifecycleState.resumed && _ready) {
      // قد تضيف عناصر خارج التطبيق (قائمة تحديد النص)، فنعيد التحميل أولاً.
      _bubbleSync();
      _loadItems().then((_) {
        _checkClipboard();
        _checkShot();
        _sync();
      });
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
    _trashPurge();
    _bubbleSync();
    setState(() => _ready = true);
    _sync();
    _fillCaptions();
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
    try {
      final w = prefs.getString(_wsKey);
      if (w != null) {
        _workspaces
          ..clear()
          ..addAll((jsonDecode(w) as List)
              .map((e) => Workspace.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
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
    _authSub?.cancel();
    L.locale.removeListener(_onLang);
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
    _scheduleSync();
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
    _toast(_suggest ? tr('اقتراح الحفظ مفعّل') : tr('اقتراح الحفظ متوقف'));
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
        ws: _wsFilter,
      ),
    );
    await _save();
    if (mounted) setState(() {});
    _fillCaptions();
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
        ws: _wsFilter,
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
    _toast(tr('تم الحفظ'));
  }

  Future<void> _pasteAndSave() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _toast(tr('الحافظة فارغة (النص فقط)'));
      return;
    }
    await _addText(text);
    setState(() => _suggestion = null);
    _toast(tr('تم اللصق والحفظ'));
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
    _addTomb(it.id).then((_) => _save());
    await _trashAdd(it);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final ctrl = messenger.showSnackBar(
      SnackBar(
        content: Text(tr('تم الحذف')),
        action: SnackBarAction(
          label: tr('تراجع'),
          onPressed: () async {
            _items.insert(math.min(idx, _items.length), it);
            await _removeTomb(it.id);
            await _trashRemove(it.id);
            await _save();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
    await ctrl.closed;
  }

  static const _trashKey = 'trash_v1';
  static const _trashDays = 30;

  Future<List<Map<String, dynamic>>> _trashLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <Map<String, dynamic>>[];
    for (final r in prefs.getStringList(_trashKey) ?? <String>[]) {
      try {
        out.add(jsonDecode(r) as Map<String, dynamic>);
      } catch (_) {}
    }
    return out;
  }

  Future<void> _trashSave(List<Map<String, dynamic>> l) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_trashKey, l.map(jsonEncode).toList());
  }

  Future<void> _trashAdd(Item it) async {
    final l = await _trashLoad();
    l.removeWhere((e) => e['id'] == it.id);
    l.insert(0, {...it.toJson(), 'deletedAt': DateTime.now().toIso8601String()});
    await _trashSave(l);
  }

  Future<void> _trashRemove(String id) async {
    final l = await _trashLoad();
    l.removeWhere((e) => e['id'] == id);
    await _trashSave(l);
  }

  Future<void> _trashFile(Map<String, dynamic> m) async {
    if (m['type'] != 'image') return;
    final f = File(p.join(_imgDir.path, m['content'] as String));
    if (await f.exists()) await f.delete();
  }

  /// يحذف نهائياً ما مضى عليه أكثر من 30 يوماً.
  Future<void> _trashPurge() async {
    final l = await _trashLoad();
    final cut = DateTime.now().subtract(const Duration(days: _trashDays));
    final keep = <Map<String, dynamic>>[];
    for (final m in l) {
      final d = DateTime.tryParse('${m['deletedAt']}');
      if (d != null && d.isBefore(cut)) {
        await _trashFile(m);
      } else {
        keep.add(m);
      }
    }
    if (keep.length != l.length) await _trashSave(keep);
  }

  Future<void> _trashSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _trashLoad(),
          builder: (ctx, snap) {
            final l = snap.data ?? [];
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        Expanded(
                          child: Text(tr('سلة المهملات'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        if (l.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              for (final m in l) {
                                await _trashFile(m);
                              }
                              await _trashSave([]);
                              setS(() {});
                            },
                            child: Text(tr('إفراغ السلة')),
                          ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          tr('تُحذف العناصر نهائياً بعد 30 يوماً'),
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                    if (l.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(tr('السلة فارغة')),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final m in l)
                              ListTile(
                                leading: Icon(m['type'] == 'image'
                                    ? Icons.image_outlined
                                    : Icons.notes_rounded),
                                title: Text(
                                  m['type'] == 'image'
                                      ? tr('صورة')
                                      : '${m['content']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: tr('استعادة'),
                                      icon: const Icon(Icons.restore_rounded),
                                      onPressed: () async {
                                        final it = Item.fromJson(m);
                                        it.updatedAt = DateTime.now().toUtc();
                                        _items.insert(0, it);
                                        await _removeTomb(it.id);
                                        await _trashRemove(it.id);
                                        await _save();
                                        if (mounted) this.setState(() {});
                                        setS(() {});
                                      },
                                    ),
                                    IconButton(
                                      tooltip: tr('حذف نهائي'),
                                      icon: const Icon(
                                          Icons.delete_forever_rounded),
                                      onPressed: () async {
                                        await _trashFile(m);
                                        await _trashRemove('${m['id']}');
                                        setS(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Future<void> _togglePin(Item it) async {
    it.pinned = !it.pinned;
    it.updatedAt = DateTime.now().toUtc();
    await _save();
    setState(() {});
  }

  Future<void> _toggleFav(Item it) async {
    it.fav = !it.fav;
    it.updatedAt = DateTime.now().toUtc();
    await _save();
    setState(() {});
  }

  Future<void> _settingsSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final cs = Theme.of(ctx).colorScheme;
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        final cardColor = dark
            ? Colors.white.withValues(alpha: 0.07)
            : cs.primary.withValues(alpha: 0.07);
        final muted = cs.onSurface.withValues(alpha: 0.6);

        Widget tile(IconData i, String t, VoidCallback f, {String? sub}) =>
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              minLeadingWidth: 24,
              horizontalTitleGap: 12,
              leading: Icon(i, size: 22, color: cs.primary),
              title: Text(t,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w600)),
              subtitle: sub == null
                  ? null
                  : Text(sub, style: TextStyle(fontSize: 12.5, color: muted)),
              trailing: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: muted),
              onTap: () {
                Navigator.pop(ctx);
                f();
              },
            );

        Widget toggle(IconData i, String t, String sub, bool v,
                Future<void> Function(bool) f) =>
            SwitchListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              secondary: Icon(i, size: 22, color: cs.primary),
              title: Text(t,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w600)),
              subtitle:
                  Text(sub, style: TextStyle(fontSize: 12.5, color: muted)),
              value: v,
              onChanged: (x) async {
                await f(x);
                setS(() {});
              },
            );

        Widget section(String title, List<Widget> kids) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: cs.primary)),
                  ),
                  Material(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      for (var n = 0; n < kids.length; n++) ...[
                        if (n > 0)
                          Divider(
                              height: 1,
                              thickness: 0.6,
                              indent: 50,
                              color: cs.onSurface.withValues(alpha: 0.1)),
                        kids[n],
                      ],
                    ]),
                  ),
                ],
              ),
            );

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.88),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 4, 2),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Brand.tealLight, Brand.tealDeep]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Brand.amber, width: 1.6),
                      ),
                      child: const Icon(Icons.assignment_rounded,
                          size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('الإعدادات'),
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w800)),
                          Text(tr('احفظ كل شيء بلمسة واحدة!'),
                              style: TextStyle(fontSize: 12.5, color: muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr('إغلاق'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ]),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 14),
                    children: [
                      section(tr('الحساب'), [
                        tile(Icons.cloud_sync_outlined,
                            tr('الحساب والمزامنة'), _accountSheet,
                            sub: SyncService.email),
                      ]),
                      section(tr('الحفظ السريع'), [
                        toggle(
                            Icons.bubble_chart_rounded,
                            tr('نقطة عائمة للحفظ السريع'),
                            tr('ضغطة: حفظ الحافظة · ضغطة مطوّلة: فتح Keepi'),
                            _bubbleOn,
                            _toggleBubble),
                        toggle(
                            Icons.screenshot_rounded,
                            tr('اقتراح حفظ لقطة الشاشة'),
                            tr('تظهر لقطتك الأخيرة للحفظ، وتلوّن النقطة العائمة'),
                            _shotOn,
                            _toggleShot),
                        toggle(
                            Icons.lightbulb_outline_rounded,
                            tr('اقتراح الحفظ'),
                            tr('يقترح حفظ ما نسخته عند فتح التطبيق'),
                            _suggest,
                            (_) => _toggleSuggest()),
                      ]),
                      section(tr('المظهر واللغة'), [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              showSelectedIcon: false,
                              style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact),
                              segments: [
                                ButtonSegment(
                                    value: ThemeMode.system,
                                    icon: const Icon(
                                        Icons.brightness_auto_rounded,
                                        size: 18),
                                    label: Text(tr('تلقائي'))),
                                ButtonSegment(
                                    value: ThemeMode.light,
                                    icon: const Icon(Icons.light_mode_rounded,
                                        size: 18),
                                    label: Text(tr('فاتح'))),
                                ButtonSegment(
                                    value: ThemeMode.dark,
                                    icon: const Icon(Icons.dark_mode_rounded,
                                        size: 18),
                                    label: Text(tr('داكن'))),
                              ],
                              selected: {ThemeCtl.mode.value},
                              onSelectionChanged: (v) async {
                                await ThemeCtl.set(v.first);
                                setS(() {});
                              },
                            ),
                          ),
                        ),
                        tile(Icons.language_rounded, tr('اللغة'), _langDialog,
                            sub: L.names[L.code]),
                      ]),
                      section(tr('البيانات'), [
                        tile(Icons.delete_outline_rounded,
                            tr('سلة المهملات'), _trashSheet),
                        tile(Icons.upload_rounded,
                            tr('نسخ احتياطي (نسخ إلى الحافظة)'),
                            _exportBackup),
                        tile(Icons.download_rounded,
                            tr('استعادة من الحافظة'), _importBackup),
                      ]),
                      section(tr('المساعدة'), [
                        tile(Icons.help_outline_rounded,
                            tr('مساعدة وطريقة الاستخدام'), _helpSheet),
                      ]),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Center(
                          child: Text('Keepi · $kBuildLabel',
                              style: TextStyle(fontSize: 12, color: muted)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _helpSheet() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HelpPage()),
    );
  }

  Future<void> _shareItem(Item it) async {
    try {
      if (it.type == ItemType.image) {
        await Share.shareXFiles([XFile(p.join(_imgDir.path, it.content))]);
      } else {
        await Share.share(it.content);
      }
    } catch (_) {
      _toast(tr('تعذّرت المشاركة'));
    }
  }

  Future<void> _editNote(Item it) async {
    final n = await _askName(tr('ملاحظة'), it.note, true);
    if (n == null) return;
    it.note = n;
    it.updatedAt = DateTime.now().toUtc();
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _editCaption(Item it) async {
    final url = it.videoUrl;
    if (url == null) return;
    final n = await _askName(tr('تعديل الكابشن'), it.caption, true);
    if (n == null) return;
    it.content = n.isEmpty ? url : '$n $url';
    it.updatedAt = DateTime.now().toUtc();
    await _save();
    if (mounted) setState(() {});
  }

  /// يجلب عنوان الفيديو تلقائياً من oEmbed الرسمي (يوتيوب/تيك توك/فيميو).
  /// إنستغرام وفيسبوك لا يرسلان الكابشن ولا يتيحان جلبه دون حساب مطوّر.
  Future<String?> _fetchTitle(String url) async {
    final h = (Uri.tryParse(url)?.host ?? '').toLowerCase();
    String? api;
    final u = Uri.encodeComponent(url);
    if (h.contains('youtube.com') || h.contains('youtu.be')) {
      api = 'https://www.youtube.com/oembed?format=json&url=$u';
    } else if (h.contains('tiktok.com')) {
      api = 'https://www.tiktok.com/oembed?url=$u';
    } else if (h.contains('vimeo.com')) {
      api = 'https://vimeo.com/api/oembed.json?url=$u';
    }
    if (api == null) return null;
    try {
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final req = await c.getUrl(Uri.parse(api));
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final t = (jsonDecode(body) as Map)['title'];
      return t is String && t.trim().isNotEmpty ? t.trim() : null;
    } catch (_) {
      return null;
    }
  }

  bool _filling = false;
  Future<void> _fillCaptions() async {
    if (_filling) return;
    _filling = true;
    try {
      var changed = false;
      for (final it in List.of(_items).take(40)) {
        final u = it.videoUrl;
        if (u == null || it.caption.isNotEmpty) continue;
        final t = await _fetchTitle(u);
        if (t == null) continue;
        it.content = '$t $u';
        it.updatedAt = DateTime.now().toUtc();
        changed = true;
      }
      if (changed) {
        await _save();
        if (mounted) setState(() {});
      }
    } finally {
      _filling = false;
    }
  }

  Future<void> _editTags(Item it) async {
    final n = await _askName(tr('الوسوم (افصل بينها بفاصلة)'), it.shownTags.join('، '));
    if (n == null) return;
    final keepNote = it.note;
    it.tags = n
        .split(RegExp(r'[,،\n]'))
        .map((e) => e.trim().replaceFirst('#', ''))
        .where((e) => e.isNotEmpty)
        .toSet()
        .take(8)
        .toList();
    it.note = keepNote;
    it.updatedAt = DateTime.now().toUtc();
    await _save();
    setState(() {});
  }

  Future<void> _exportBackup() async {
    final data = {
      'app': 'keepi',
      'version': 1,
      'workspaces': _workspaces.map((e) => e.toJson()).toList(),
      'items': _items
          .where((e) => e.type != ItemType.image)
          .map((e) => e.toJson())
          .toList(),
    };
    await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
    _toast(tr('تم نسخ النسخة الاحتياطية (النصوص والروابط) إلى الحافظة'));
  }

  Future<void> _importBackup() async {
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    try {
      final m = jsonDecode(clip) as Map<String, dynamic>;
      if (m['app'] != 'keepi') throw 'x';
      final ids = _items.map((e) => e.id).toSet();
      final wids = _workspaces.map((e) => e.id).toSet();
      var added = 0;
      for (final w in (m['workspaces'] as List? ?? [])) {
        final ws = Workspace.fromJson(w as Map<String, dynamic>);
        if (wids.add(ws.id)) _workspaces.add(ws);
      }
      for (final e in (m['items'] as List? ?? [])) {
        final it = Item.fromJson(e as Map<String, dynamic>);
        if (it.type != ItemType.image && ids.add(it.id)) {
          _items.add(it);
          added++;
        }
      }
      await _save();
      await _saveWs();
      setState(() {});
      _toast(L.isAr ? 'تمت استعادة $added عنصر' : 'Restored $added items');
    } catch (_) {
      _toast(tr('انسخ أولاً نص النسخة الاحتياطية ثم أعد المحاولة'));
    }
  }

  // ───────────── الحساب والمزامنة ─────────────
  Timer? _syncTimer;
  StreamSubscription? _authSub;
  bool _syncing = false;
  String _syncState = '';
  String _syncErr = '';

  /// المحفوظات مرتبطة بحساب واحد على الجهاز: عند دخول حساب مختلف نمسح النسخة المحلية.
  Future<void> _adoptOwner() async {
    final uid = SyncService.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString('owner_uid');
    final hasLocal = _items.isNotEmpty || _workspaces.isNotEmpty;
    if (owner != null && owner != uid && hasLocal && mounted) {
      final c = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(tr('حساب مختلف')),
          content: Text(tr(
              'هذا الهاتف يحتوي عناصر محفوظة من حساب آخر. ماذا تريد أن تفعل بها؟')),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'merge'),
              child: Text(tr('دمجها في هذا الحساب')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'wipe'),
              child: Text(tr('مسحها وتحميل عناصر هذا الحساب')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(tr('إلغاء وتسجيل الخروج')),
            ),
          ],
        ),
      );
      if (c == 'cancel' || c == null) {
        await SyncService.signOut();
        return;
      }
      if (c == 'merge') {
        // نحتفظ بالعناصر ونسجّلها لهذا الحساب؛ نمسح فقط قائمة الحذف القديمة.
        await prefs.remove('tomb_v1');
        await prefs.setString('owner_uid', uid);
        await _loadItems();
        return;
      }
    }
    if (owner != null && owner != uid) {
      _items.clear();
      _workspaces.clear();
      _wsFilter = null;
      await prefs.remove(_prefsKey);
      await prefs.remove(_wsKey);
      await prefs.remove('tomb_v1');
      await prefs.remove(_trashKey);
    }
    await prefs.setString('owner_uid', uid);
    await _loadItems();
  }

  bool get _locked => SyncService.available && !SyncService.signedIn;

  Widget _lockScreen() {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Brand.tealLight, Brand.tealDeep],
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 14),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/icon/icon.png',
                        width: 34, height: 34),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Keepi',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    color: Colors.white,
                    tooltip: tr('اللغة'),
                    icon: const Icon(Icons.language_rounded),
                    onPressed: _langDialog,
                  ),
                ]),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 56, color: Brand.tealMid),
                    const SizedBox(height: 16),
                    Text(tr('سجّل الدخول لعرض محفوظاتك'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        tr('محفوظاتك مخفية حتى تسجّل الدخول، وتختفي بعد تسجيل الخروج.'),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _accountSheet,
                      icon: const Icon(Icons.login_rounded),
                      label: Text(tr('تسجيل الدخول')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleSync() {
    if (!SyncService.signedIn) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), _sync);
  }

  Future<void> _addTomb(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final l = (prefs.getStringList('tomb_v1') ?? []).toSet()..add(id);
    await prefs.setStringList('tomb_v1', l.toList());
  }

  Future<void> _removeTomb(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final l = (prefs.getStringList('tomb_v1') ?? []).toSet()..remove(id);
    await prefs.setStringList('tomb_v1', l.toList());
  }

  Future<void> _sync({bool manual = false}) async {
    if (!SyncService.signedIn || _syncing) return;
    _syncing = true;
    if (mounted) setState(() => _syncState = 'جارٍ المزامنة…');
    try {
      final prefs = await SharedPreferences.getInstance();
      final tomb = (prefs.getStringList('tomb_v1') ?? []).toSet();
      final now = DateTime.now().toUtc();

      // ── مساحات العمل
      final rw = {
        for (final m in await SyncService.fetch('workspaces')) m['id'] as String: m
      };
      final upW = <Map<String, dynamic>>[];
      for (final id in tomb.where((e) => e.startsWith('w:'))) {
        final r = rw[id.substring(2)];
        if (r != null && r['deleted'] != true) {
          upW.add({...r, 'updated_at': now.toIso8601String(), 'deleted': true});
        }
      }
      for (final w in List.of(_workspaces)) {
        if (tomb.contains('w:${w.id}')) continue;
        final r = rw[w.id];
        if (r == null) {
          upW.add(w.toRemote());
        } else if (r['deleted'] == true) {
          _workspaces.remove(w);
        } else {
          final ru = DateTime.parse(r['updated_at']).toUtc();
          if (w.updatedAt.isAfter(ru)) {
            upW.add(w.toRemote());
          } else if (ru.isAfter(w.updatedAt)) {
            w.name = r['name'];
            w.updatedAt = ru;
          }
        }
      }
      final localW = _workspaces.map((e) => e.id).toSet();
      for (final r in rw.values) {
        if (r['deleted'] != true &&
            !localW.contains(r['id']) &&
            !tomb.contains('w:${r['id']}')) {
          _workspaces.add(Workspace(r['id'], r['name'], DateTime.parse(r['updated_at']).toUtc()));
        }
      }
      if (upW.isNotEmpty) await SyncService.upsert('workspaces', upW);

      // ── العناصر
      final ri = {
        for (final m in await SyncService.fetch('items')) m['id'] as String: m
      };
      final up = <Map<String, dynamic>>[];
      for (final id in tomb.where((e) => !e.startsWith('w:'))) {
        final r = ri[id];
        if (r != null && r['deleted'] != true) {
          up.add({
            ...r,
            'updated_at': now.toIso8601String(),
            'deleted': true,
          });
        }
      }
      final gone = <Item>[];
      for (final it in _items) {
        if (tomb.contains(it.id)) continue;
        final r = ri[it.id];
        if (r == null) {
          if (it.type != ItemType.image) up.add(it.toRemote());
        } else if (r['deleted'] == true) {
          gone.add(it);
        } else {
          final ru = DateTime.parse(r['updated_at']).toUtc();
          final lu = it.updatedAt.toUtc();
          if (lu.isAfter(ru.add(const Duration(seconds: 1)))) {
            up.add(it.toRemote());
          } else if (ru.isAfter(lu)) {
            it.pinned = r['pinned'] ?? false;
            it.fav = r['fav'] ?? false;
            it.ws = r['ws'] as String?;
            it.tags = ((r['tags'] as List?) ?? []).map((e) => e.toString()).toList();
            it.updatedAt = ru;
          }
        }
      }
      for (final g in gone) {
        _items.remove(g);
      }
      final localI = _items.map((e) => e.id).toSet();
      for (final r in ri.values) {
        if (r['deleted'] != true &&
            !localI.contains(r['id']) &&
            !tomb.contains(r['id'])) {
          _items.add(Item(
            id: r['id'],
            type: ItemType.values.byName(r['type']),
            content: r['content'],
            createdAt: DateTime.parse(r['created_at']),
            updatedAt: DateTime.parse(r['updated_at']).toUtc(),
            pinned: r['pinned'] ?? false,
            fav: r['fav'] ?? false,
            ws: r['ws'] as String?,
            tags: ((r['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
          ));
        }
      }
      var limit = false;
      try {
        if (up.isNotEmpty) await SyncService.upsert('items', up);
      } catch (e) {
        if (e.toString().contains('FREE_LIMIT_REACHED')) {
          limit = true;
        } else {
          rethrow;
        }
      }
      await prefs.setStringList('tomb_v1', []);
      await prefs.setString(
          _prefsKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
      await prefs.setString(
          _wsKey, jsonEncode(_workspaces.map((e) => e.toJson()).toList()));
      _syncErr = '';
      if (mounted) {
        setState(() => _syncState = limit ? 'بلغت الحد المجاني' : 'متزامن ✓');
      }
      if (limit) _limitDialog();
      if (manual) _toast(limit ? tr('بلغت 500 عنصر (الحد المجاني)') : tr('تمت المزامنة'));
    } catch (e) {
      _syncErr = e.toString().replaceAll(RegExp(r'\s+'), ' ');
      if (_syncErr.length > 260) _syncErr = _syncErr.substring(0, 260);
      if (mounted) setState(() => _syncState = 'تعذّرت المزامنة');
      if (manual) _toast(tr('تعذّرت المزامنة، تحقق من الإنترنت'));
    } finally {
      _syncing = false;
    }
  }

  void _limitDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('وصلت للحد المجاني')),
        content: Text(
            tr('الخطة المجانية تتيح مزامنة 500 عنصر. باقي عناصرك محفوظة على هذا الهاتف. الاشتراك المميز (غير محدود) سيتوفر قريباً.')),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('حسناً'))),
        ],
      ),
    );
  }

  void _accountSheet() {
    final email = TextEditingController();
    final pw = TextEditingController();
    var busy = false;
    String? err;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final inn = SyncService.signedIn;
        Future<void> go(bool signup) async {
          final e = email.text.trim();
          if (e.isEmpty || pw.text.length < 6) {
            setS(() => err = tr('أدخل البريد وكلمة مرور (6 أحرف فأكثر)'));
            return;
          }
          setS(() {
            busy = true;
            err = null;
          });
          String? res;
          if (signup) {
            final r = await SyncService.signUp(e, pw.text);
            if (r == 'confirm') {
              setS(() {
                busy = false;
                err = tr('أُرسلت رسالة تأكيد إلى بريدك. فعّله ثم سجّل الدخول.');
              });
              return;
            }
            res = r == 'ok' ? null : r;
          } else {
            res = await SyncService.signIn(e, pw.text);
          }
          if (res != null) {
            setS(() {
              busy = false;
              err = res;
            });
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) setState(() {});
          _sync(manual: true);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: inn
                ? [
                    Text(tr('الحساب والمزامنة'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(SyncService.email ?? ''),
                    if (_syncErr.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        _syncErr,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 11.5, color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(L.isAr ? '${_items.where((e) => e.type != ItemType.image).length} / 500 عنصر (الخطة المجانية) · الصور تبقى على الهاتف' : '${_items.where((e) => e.type != ItemType.image).length} / 500 items (free plan) · images stay on this phone',
                        style: const TextStyle(fontSize: 12.5)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sync(manual: true);
                      },
                      icon: const Icon(Icons.sync_rounded),
                      label: Text(tr('مزامنة الآن')),
                    ),
                    TextButton(
                      onPressed: () async {
                        await SyncService.signOut();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) setState(() => _syncState = '');
                      },
                      child: Text(tr('تسجيل الخروج')),
                    ),
                  ]
                : [
                    Text(tr('سجّل الدخول لمزامنة عناصرك بين أجهزتك'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                          labelText: tr('البريد الإلكتروني'), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pw,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: tr('كلمة المرور'), border: OutlineInputBorder()),
                    ),
                    if (err != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(err!, style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: busy ? null : () => go(false),
                      child: busy
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(tr('دخول')),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : () => go(true),
                      child: Text(tr('إنشاء حساب جديد')),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final r = await SyncService.signInGoogle();
                              if (r != null) {
                                setS(() => err = r);
                              } else if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                            },
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                      label: Text(tr('المتابعة بحساب جوجل')),
                    ),
                    const SizedBox(height: 8),
                  ],
          ),
        );
      }),
    );
  }

  Future<void> _saveWs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _wsKey, jsonEncode(_workspaces.map((e) => e.toJson()).toList()));
    _scheduleSync();
  }

  String? _wsName(String? id) {
    for (final w in _workspaces) {
      if (w.id == id) return w.name;
    }
    return null;
  }

  Future<String?> _askName(String title,
      [String initial = '', bool long = false]) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: long ? 300 : 24,
          maxLines: long ? 4 : 1,
          minLines: 1,
          decoration: InputDecoration(hintText: long ? '' : tr('الاسم')),
          onSubmitted: long ? null : (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('إلغاء'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: Text(tr('حفظ'))),
        ],
      ),
    );
  }

  Future<void> _addWorkspace() async {
    final n = await _askName(tr('مساحة عمل جديدة'));
    if (n == null || n.isEmpty) return;
    final w = Workspace(_newId(), n, DateTime.now().toUtc());
    _workspaces.add(w);
    await _saveWs();
    setState(() {
      _wsFilter = w.id;
      _favOnly = false;
    });
  }

  Future<void> _wsMenu(Workspace w) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(tr('إعادة تسمية')),
              onTap: () => Navigator.pop(ctx, 'rename')),
          ListTile(
              leading: const Icon(Icons.folder_delete_outlined),
              title: Text(tr('حذف المساحة (تبقى عناصرها)')),
              onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (a == 'rename') {
      final n = await _askName(tr('إعادة تسمية'), w.name);
      if (n != null && n.isNotEmpty) {
        w.name = n;
        w.updatedAt = DateTime.now().toUtc();
        await _saveWs();
        setState(() {});
      }
    } else if (a == 'delete') {
      for (final e in _items) {
        if (e.ws == w.id) {
          e.ws = null;
          e.updatedAt = DateTime.now().toUtc();
        }
      }
      _workspaces.remove(w);
      await _addTomb('w:${w.id}');
      if (_wsFilter == w.id) _wsFilter = null;
      await _save();
      await _saveWs();
      setState(() {});
    }
  }

  Future<void> _moveItem(Item it) async {
    final res = await showModalBottomSheet<List<String?>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
              title: Text(tr('نقل إلى مساحة عمل'),
                  style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
              leading: Icon(it.ws == null
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(tr('بدون مساحة')),
              onTap: () => Navigator.pop(ctx, [null])),
          for (final w in _workspaces)
            ListTile(
                leading: Icon(it.ws == w.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text(w.name),
                onTap: () => Navigator.pop(ctx, [w.id])),
        ]),
      ),
    );
    if (res == null) return;
    it.ws = res.first;
    it.updatedAt = DateTime.now().toUtc();
    await _save();
    setState(() {});
  }

  Widget _wsBar() {
    final cs = Theme.of(context).colorScheme;
    Widget chip(String label, bool sel, VoidCallback onTap,
        {VoidCallback? onLong, IconData? icon}) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLong,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel
                  ? Brand.tealMid
                  : cs.onSurface.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16, color: sel ? Colors.white : Brand.amber),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                      color: sel ? Colors.white : cs.onSurface)),
            ]),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        children: [
          chip(tr('الكل'), _wsFilter == null && !_favOnly,
              () => setState(() {
                    _wsFilter = null;
                    _favOnly = false;
                  })),
          chip(tr('المفضلة'), _favOnly,
              () => setState(() {
                    _favOnly = !_favOnly;
                    _wsFilter = null;
                  }),
              icon: Icons.star_rounded),
          for (final w in _workspaces)
            chip(w.name, _wsFilter == w.id,
                () => setState(() {
                      _wsFilter = _wsFilter == w.id ? null : w.id;
                      _favOnly = false;
                    }),
                onLong: () => _wsMenu(w),
                icon: Icons.folder_rounded),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              onTap: _addWorkspace,
              child: Container(
                width: 36,
                decoration: const BoxDecoration(
                    color: Brand.amber, shape: BoxShape.circle),
                child: const Icon(Icons.create_new_folder_rounded,
                    size: 19, color: Brand.onAmber),
              ),
            ),
          ),
        ],
      ),
    );
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
      if (_filter != null &&
          (_filter == ItemType.video
              ? e.videoUrl == null
              : (e.type != _filter || e.videoUrl != null))) {
        return false;
      }
      if (_favOnly && !e.fav) return false;
      if (_wsFilter != null && e.ws != _wsFilter) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase().replaceFirst('#', '');
        if (e.tags.any((t) => t.toLowerCase().contains(q))) return true;
        if (e.type == ItemType.image) return false;
        return e.content.toLowerCase().contains(q);
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
    final v = it.videoUrl;
    if (v != null) {
      await launchUrl(Uri.parse(v), mode: LaunchMode.externalApplication);
    } else if (it.type == ItemType.link) {
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
      _toast(tr('تم النسخ'));
    }
  }

  // ───────────────────────── الواجهة ─────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_locked) return _lockScreen();
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
            _wsBar(),
            if (_query.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Brand.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        L.isAr
                            ? 'نتائج البحث: ${items.length} (القائمة مفلترة)'
                            : 'Search results: ${items.length} (list is filtered)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                        _searching = false;
                      }),
                      child: Text(tr('مسح البحث')),
                    ),
                  ],
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _shotId != null
                  ? _shotCard()
                  : _suggestion == null
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
        floatingActionButton: Material(
          color: Brand.amber,
          elevation: 3,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _showAddMenu,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 20, color: Brand.onAmber),
                  const SizedBox(width: 5),
                  Text(tr('إضافة'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Brand.onAmber)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _searching = false;

  Widget _header() {
    final white = Colors.white;
    final titleRow = Row(
      key: const ValueKey('title'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/icon/icon.png', width: 34, height: 34),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Keepi',
                  style: TextStyle(
                      color: white,
                      fontSize: 21,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.bold,
                      height: 1.05)),
              Text(
                _items.isEmpty
                    ? '${tr('احفظ أي شيء بسرعة')} · $kBuildLabel'
                    : '${_items.length} ${L.isAr ? 'عنصر محفوظ' : 'items'} · $kBuildLabel${_syncState.isEmpty ? '' : ' · ${tr(_syncState)}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: white.withValues(alpha: 0.75), fontSize: 11.5),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: tr('بحث'),
          color: white,
          icon: Icon(_query.isEmpty
              ? Icons.search_rounded
              : Icons.manage_search_rounded),
          onPressed: () => setState(() => _searching = true),
        ),
        IconButton(
          tooltip: tr('لصق وحفظ'),
          color: white,
          icon: const Icon(Icons.content_paste_go_rounded),
          onPressed: _pasteAndSave,
        ),
        IconButton(
          tooltip: tr('الإعدادات'),
          color: white,
          icon: const Icon(Icons.settings_rounded),
          onPressed: _settingsSheet,
        ),
      ],
    );

    final searchRow = Row(
      key: const ValueKey('search'),
      children: [
        Expanded(
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(color: white),
            cursorColor: white,
            decoration: InputDecoration(
              hintText: tr('ابحث في محفوظاتك...'),
              hintStyle: TextStyle(color: white.withValues(alpha: 0.7)),
              prefixIcon: Icon(Icons.search_rounded,
                  color: white.withValues(alpha: 0.8)),
              filled: true,
              fillColor: white.withValues(alpha: 0.16),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        IconButton(
          color: white,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(() {
            _search.clear();
            _query = '';
            _searching = false;
          }),
        ),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Brand.tealLight, Brand.tealDeep],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 6, 10),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _searching || _query.isNotEmpty ? searchRow : titleRow,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      _chip(tr('الكل'), Icons.apps_rounded, null),
                      _chip(tr('نصوص'), Icons.notes_rounded, ItemType.text),
                      _chip(tr('روابط'), Icons.link_rounded, ItemType.link),
                      _chip(tr('صور'), Icons.image_outlined, ItemType.image),
                      _chip(tr('فيديو'), Icons.play_circle_outline_rounded,
                          ItemType.video),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _langDialog() async {
    final c = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('اللغة')),
        children: [
          for (final e in L.names.entries)
            ListTile(
              title: Text(e.value),
              trailing: e.key == L.code ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ],
      ),
    );
    if (c != null) await L.set(c);
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

  Widget _shotCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _dark ? const Color(0xFF1C3A30) : const Color(0xFFE3F3EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Brand.amber.withValues(alpha: 0.8), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.screenshot_rounded,
              size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr('لقطة شاشة جديدة'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(onPressed: _dismissShot, child: Text(tr('تجاهل'))),
          const SizedBox(width: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Brand.amber,
              foregroundColor: Brand.onAmber,
            ),
            icon: const Icon(Icons.bookmark_add_rounded, size: 19),
            label: Text(tr('احفظ'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _saveShot,
          ),
        ],
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
                link ? tr('رابط جديد في الحافظة') : tr('نص جديد في الحافظة'),
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
                child: Text(tr('تجاهل')),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.amber,
                  foregroundColor: Brand.onAmber,
                ),
                icon: const Icon(Icons.bookmark_add_rounded, size: 19),
                label: Text(tr('احفظ'),
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  setState(() => _suggestion = null);
                  await _addText(text);
                  _toast(tr('تم الحفظ'));
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
              noItems ? tr('لا يوجد شيء هنا بعد') : tr('لا توجد نتائج'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              noItems
                  ? tr('انسخ نصاً أو رابطاً ثم افتح التطبيق، أو حدّد أي نص واختر «Keepi» من قائمة التحديد، أو شارك محتوى إليه مباشرة.')
                  : tr('جرّب كلمة بحث أخرى أو غيّر التصنيف.'),
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
      case ItemType.video:
        return const Color(0xFFE5484D);
      case ItemType.text:
        return _dark ? const Color(0xFF8FB8AC) : Brand.tealMid;
    }
  }

  String _typeLabel(ItemType t) {
    switch (t) {
      case ItemType.link:
        return tr('رابط');
      case ItemType.image:
        return tr('صورة');
      case ItemType.video:
        return tr('فيديو');
      case ItemType.text:
        return tr('نص');
    }
  }

  IconData _typeIcon(ItemType t) {
    switch (t) {
      case ItemType.link:
        return Icons.link_rounded;
      case ItemType.image:
        return Icons.image_outlined;
      case ItemType.video:
        return Icons.play_circle_outline_rounded;
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
    if (diff == 0) return L.isAr ? 'اليوم $hm' : 'Today $hm';
    if (diff == 1) return L.isAr ? 'أمس $hm' : 'Yesterday $hm';
    return '${d.year}/${d.month}/${d.day}';
  }

  String _host(String url) {
    final h = Uri.tryParse(url)?.host ?? url;
    return h.startsWith('www.') ? h.substring(4) : h;
  }

  Widget _card(Item it) {
    final cs = Theme.of(context).colorScheme;
    final kind = it.kind;
    final accent = _accent(kind);

    final Widget body;
    switch (kind) {
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
      case ItemType.video:
        final cap = it.caption;
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cap.isNotEmpty)
              Text(cap,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.5, height: 1.45)),
            if (cap.isNotEmpty) const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.play_circle_fill_rounded, size: 18, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _host(it.videoUrl!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ]),
            if (cap.isEmpty) ...[
              const SizedBox(height: 3),
              Text(
                it.videoUrl!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
                style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ],
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
                                    Icon(_typeIcon(kind),
                                        size: 15,
                                        color: it.type == ItemType.image
                                            ? (_dark
                                                ? Brand.amber
                                                : const Color(0xFFB27F00))
                                            : accent),
                                    const SizedBox(width: 5),
                                    Text(
                                      _typeLabel(kind),
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
                              if (_wsName(it.ws) != null) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.onSurface
                                          .withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(_wsName(it.ws)!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11.5)),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (it.fav)
                                const Padding(
                                  padding: EdgeInsetsDirectional.only(end: 6),
                                  child: Icon(Icons.star_rounded,
                                      size: 18, color: Brand.amber),
                                ),
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
                          if (it.type != ItemType.video &&
                              it.note.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Brand.amber.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.edit_note_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(it.note,
                                        style: const TextStyle(fontSize: 13.5)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (it.shownTags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final t in it.shownTags)
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _search.text = '#$t';
                                      _query = '#$t';
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Brand.tealMid
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text('#$t',
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (it.type != ItemType.image)
                                action(Icons.copy_rounded, tr('نسخ'), () {
                                  Clipboard.setData(
                                      ClipboardData(text: it.content));
                                  _toast(tr('تم النسخ'));
                                }),
                              action(
                                it.fav
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                it.fav ? tr('إزالة من المفضلة') : tr('مفضلة'),
                                () => _toggleFav(it),
                                color: it.fav ? Brand.amber : null,
                              ),
                              action(
                                it.pinned
                                    ? Icons.push_pin_rounded
                                    : Icons.push_pin_outlined,
                                it.pinned ? tr('إلغاء التثبيت') : tr('تثبيت'),
                                () => _togglePin(it),
                                color: it.pinned ? Brand.amber : null,
                              ),
                              action(
                                  Icons.edit_note_rounded,
                                  kind == ItemType.video
                                      ? tr('تعديل الكابشن')
                                      : tr('ملاحظة'),
                                  () => kind == ItemType.video
                                      ? _editCaption(it)
                                      : _editNote(it)),
                              action(Icons.share_rounded, tr('مشاركة'),
                                  () => _shareItem(it)),
                              PopupMenuButton<String>(
                                tooltip: tr('المزيد'),
                                padding: const EdgeInsets.all(8),
                                icon: Icon(Icons.more_horiz_rounded,
                                    size: 21,
                                    color: cs.onSurface.withValues(alpha: 0.6)),
                                onSelected: (v) =>
                                    v == 'tags' ? _editTags(it) : _moveItem(it),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'tags',
                                    child: Row(children: [
                                      const Icon(Icons.sell_outlined, size: 20),
                                      const SizedBox(width: 10),
                                      Text(tr('وسوم')),
                                    ]),
                                  ),
                                  PopupMenuItem(
                                    value: 'move',
                                    child: Row(children: [
                                      const Icon(Icons.folder_open_rounded,
                                          size: 20),
                                      const SizedBox(width: 10),
                                      Text(tr('نقل')),
                                    ]),
                                  ),
                                ],
                              ),
                              action(Icons.delete_outline_rounded, tr('حذف'),
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
              Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Text(tr('إضافة جديدة'),
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  _addTile(ctx, Icons.content_paste_rounded, tr('لصق'),
                      Brand.tealLight, _pasteAndSave),
                  _addTile(ctx, Icons.edit_note_rounded, tr('كتابة'),
                      Brand.tealMid, _showAddText),
                  _addTile(ctx, Icons.photo_library_outlined, tr('معرض'),
                      const Color(0xFFE09A00),
                      () => _pickImage(ImageSource.gallery)),
                  _addTile(ctx, Icons.photo_camera_outlined, tr('كاميرا'),
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
            Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(tr('نص أو رابط'),
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            TextField(
              controller: c,
              autofocus: true,
              minLines: 4,
              maxLines: 9,
              decoration: InputDecoration(
                hintText: tr('اكتب هنا أو الصق رابطاً...'),
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
                label: Text(tr('حفظ'),
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
