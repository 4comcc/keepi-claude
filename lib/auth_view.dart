import 'package:flutter/material.dart';

import 'l10n.dart';
import 'sync.dart';

/// شاشة الدخول الكاملة (تظهر قبل عرض المحفوظات).
class AuthView extends StatefulWidget {
  final VoidCallback onLang;
  final VoidCallback onDone;
  const AuthView({super.key, required this.onLang, required this.onDone});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await SyncService.signInGoogle();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _err = r;
    });
  }

  Future<void> _go(bool signup) async {
    final e = _email.text.trim();
    if (e.isEmpty || _pw.text.length < 6) {
      setState(() => _err = tr('أدخل البريد وكلمة مرور (6 أحرف فأكثر)'));
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    String? res;
    if (signup) {
      final r = await SyncService.signUp(e, _pw.text);
      if (r == 'confirm') {
        if (mounted) {
          setState(() {
            _busy = false;
            _err = tr('أُرسلت رسالة تأكيد إلى بريدك. فعّله ثم سجّل الدخول.');
          });
        }
        return;
      }
      res = r == 'ok' ? null : r;
    } else {
      res = await SyncService.signIn(e, _pw.text);
    }
    if (!mounted) return;
    if (res != null) {
      setState(() {
        _busy = false;
        _err = res;
      });
      return;
    }
    setState(() => _busy = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const amber = Color(0xFFFFB703);

    final header = Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2BA58A), Color(0xFF145A4A)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 26),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  color: Colors.white,
                  tooltip: tr('اللغة'),
                  icon: const Icon(Icons.language_rounded),
                  onPressed: widget.onLang,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: amber, width: 2.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset('assets/icon/icon.png',
                      width: 76, height: 76),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Keepi',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(tr('احفظ كل شيء بلمسة واحدة!'),
                  style: const TextStyle(
                      color: amber, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );

    final googleBtn = SizedBox(
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF1C2B26) : Colors.white,
          side: BorderSide(color: cs.onSurface.withValues(alpha: 0.25)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _busy ? null : _google,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 22, height: 22, child: _GoogleG()),
            const SizedBox(width: 12),
            Text(tr('المتابعة بحساب جوجل'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
          ],
        ),
      ),
    );

    final divider = Row(children: [
      Expanded(child: Divider(color: cs.onSurface.withValues(alpha: 0.2))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(tr('أو بالبريد'),
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
      ),
      Expanded(child: Divider(color: cs.onSurface.withValues(alpha: 0.2))),
    ]);

    InputDecoration deco(String label, IconData icon, [Widget? suffix]) =>
        InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 21),
          suffixIcon: suffix,
          filled: true,
          fillColor: cs.primary.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        );

    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  googleBtn,
                  const SizedBox(height: 14),
                  divider,
                  const SizedBox(height: 14),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration:
                        deco(tr('البريد الإلكتروني'), Icons.mail_outline_rounded),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pw,
                    obscureText: !_show,
                    textDirection: TextDirection.ltr,
                    decoration: deco(
                      tr('كلمة المرور'),
                      Icons.lock_outline_rounded,
                      IconButton(
                        icon: Icon(_show
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(() => _show = !_show),
                      ),
                    ),
                  ),
                  if (_err != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_err!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _busy ? null : () => _go(false),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(tr('دخول'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _go(true),
                    child: Text(tr('إنشاء حساب جديد'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 15,
                          color: cs.onSurface.withValues(alpha: 0.55)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tr('محفوظاتك خاصة بك وتظهر بعد تسجيل الدخول'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شعار جوجل «G» مبسّط بألوانه الأربعة.
class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GPainter());
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final w = s * 0.2;
    final r = (s - w) / 2;
    final c = Offset(s / 2, s / 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    Paint p(Color col) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt;
    double d(double deg) => deg * 3.141592653589793 / 180;
    canvas.drawArc(rect, d(-45), d(-90 - 0), false, p(const Color(0xFFEA4335)));
    canvas.drawArc(rect, d(-135), d(-90), false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, d(135), d(-90), false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect, d(45), d(-45), false, p(const Color(0xFF4285F4)));
    // الشريط الأزرق الأفقي
    canvas.drawRect(
      Rect.fromLTWH(s / 2, s / 2 - w / 2, s / 2 - 0.5, w),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
