import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const QuickKeepApp());

class QuickKeepApp extends StatelessWidget {
  const QuickKeepApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كويك كيب',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E6F5C),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1E6F5C),
      ),
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

class _HomePageState extends State<HomePage> {
  static const _prefsKey = 'items_v1';
  final List<Item> _items = [];
  final _search = TextEditingController();
  String _query = '';
  ItemType? _filter;
  late Directory _imgDir;
  StreamSubscription? _shareSub;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final docs = await getApplicationDocumentsDirectory();
    _imgDir = Directory(p.join(docs.path, 'images'));
    await _imgDir.create(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      _items.addAll((jsonDecode(raw) as List)
          .map((e) => Item.fromJson(e as Map<String, dynamic>)));
    }
    setState(() => _ready = true);

    // استقبال المشاركة من التطبيقات الأخرى
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initial.isNotEmpty) {
      await _handleShared(initial);
      ReceiveSharingIntent.instance.reset();
    }
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_handleShared);
  }

  @override
  void dispose() {
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
    return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
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
      } else if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
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
    _toast('تم اللصق والحفظ');
  }

  Future<void> _pickImage(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, imageQuality: 85);
    if (x != null) await _addImageFile(x.path);
  }

  Future<void> _delete(Item it) async {
    _items.removeWhere((e) => e.id == it.id);
    if (it.type == ItemType.image) {
      final f = File(p.join(_imgDir.path, it.content));
      if (await f.exists()) await f.delete();
    }
    await _save();
    setState(() {});
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
      ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  List<Item> get _visible {
    final list = _items.where((e) {
      if (_filter != null && e.type != _filter) return false;
      if (_query.isNotEmpty && e.type != ItemType.image) {
        return e.content.toLowerCase().contains(_query.toLowerCase());
      }
      if (_query.isNotEmpty && e.type == ItemType.image) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  void _showAddText() {
    final c = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: c,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                  hintText: 'اكتب نصاً أو الصق رابطاً...',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  _addText(c.text);
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.content_paste),
            title: const Text('لصق من الحافظة'),
            onTap: () {
              Navigator.pop(ctx);
              _pasteAndSave();
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('كتابة نص / رابط'),
            onTap: () {
              Navigator.pop(ctx);
              _showAddText();
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('صورة من المعرض'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('التقاط صورة'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _open(Item it) async {
    if (it.type == ItemType.link) {
      await launchUrl(Uri.parse(it.content), mode: LaunchMode.externalApplication);
    } else if (it.type == ItemType.image) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(),
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

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Scaffold(
      appBar: AppBar(
        title: const Text('كويك كيب'),
        actions: [
          IconButton(
            tooltip: 'لصق وحفظ',
            icon: const Icon(Icons.content_paste_go),
            onPressed: _pasteAndSave,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'بحث...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _chip('الكل', null),
                  _chip('نصوص', ItemType.text),
                  _chip('روابط', ItemType.link),
                  _chip('صور', ItemType.image),
                ],
              ),
            ),
          ]),
        ),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('لا توجد عناصر بعد. اضغط + للإضافة'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _card(items[i]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
    );
  }

  Widget _chip(String label, ItemType? t) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == t,
          onSelected: (_) => setState(() => _filter = t),
        ),
      );

  Widget _card(Item it) {
    final Widget body;
    switch (it.type) {
      case ItemType.image:
        body = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(p.join(_imgDir.path, it.content)),
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      case ItemType.link:
        body = Text(it.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline));
      case ItemType.text:
        body = Text(it.content, maxLines: 8, overflow: TextOverflow.ellipsis);
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(it),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              body,
              const SizedBox(height: 8),
              Row(children: [
                Icon(
                  it.type == ItemType.image
                      ? Icons.image_outlined
                      : it.type == ItemType.link
                          ? Icons.link
                          : Icons.notes,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${it.createdAt.year}/${it.createdAt.month}/${it.createdAt.day}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (it.type != ItemType.image)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: it.content));
                      _toast('تم النسخ');
                    },
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    it.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 20,
                  ),
                  onPressed: () => _togglePin(it),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _delete(it),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
