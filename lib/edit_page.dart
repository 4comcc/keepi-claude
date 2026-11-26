import 'package:flutter/material.dart';

import 'l10n.dart';

/// شاشة تحرير موسّعة للنص أو الرابط. تعيد النص الجديد عند الحفظ.
class EditTextPage extends StatefulWidget {
  final String initial;
  const EditTextPage({super.key, required this.initial});

  @override
  State<EditTextPage> createState() => _EditTextPageState();
}

class _EditTextPageState extends State<EditTextPage> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  bool get _changed => _c.text.trim() != widget.initial.trim();
  bool get _valid => _c.text.trim().isNotEmpty;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (!_changed) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('تجاهل التعديلات؟')),
        content: Text(tr('لديك تعديلات غير محفوظة.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('متابعة التحرير'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('تجاهل'))),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: tr('إغلاق'),
            icon: const Icon(Icons.close_rounded),
            onPressed: _close,
          ),
          title: Text(tr('تعديل'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB703),
                  foregroundColor: const Color(0xFF3B2A00),
                ),
                onPressed: _valid
                    ? () => Navigator.pop(context, _c.text.trim())
                    : null,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: Text(tr('حفظ'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            controller: _c,
            autofocus: true,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontSize: 17, height: 1.6),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: cs.primary.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
              counterText: '${_c.text.characters.length}',
            ),
          ),
        ),
      ),
    );
  }
}
