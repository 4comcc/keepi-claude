import 'package:flutter/material.dart';

import 'l10n.dart';

const _amber = Color(0xFFFFB703);
const _teal = Color(0xFF1E6F5C);

/// شاشة الإنترو: تُعرض مرة واحدة عند أول تشغيل.
class IntroView extends StatefulWidget {
  final VoidCallback onFinish; // متابعة دون تفعيل
  final VoidCallback onEnableBubble; // متابعة مع تفعيل الزر العائم
  const IntroView(
      {super.key, required this.onFinish, required this.onEnableBubble});

  @override
  State<IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends State<IntroView> {
  final _pc = PageController();
  int _page = 0;
  static const _count = 3;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _count - 1) {
      widget.onFinish();
    } else {
      _pc.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  Widget _bubble(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _teal,
          border: Border.all(color: _amber, width: size * 0.045),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 6))
          ],
        ),
        child: Icon(Icons.assignment_rounded,
            size: size * 0.5, color: Colors.white),
      );

  Widget _page1() {
    final ar = L.isAr;
    return _Slide(
      top: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: _amber, width: 3.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: Image.asset('assets/icon/icon.png', width: 110, height: 110),
        ),
      ),
      title: 'Keepi',
      subtitle: tr('احفظ كل شيء بلمسة واحدة!'),
      body: ar
          ? 'مكان واحد منظّم لكل ما تريد أن تتذكره، تجده بسرعة وقت الحاجة.'
          : 'One organized place for everything you want to remember, ready when you need it.',
      extra: Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 12,
        children: [
          for (final e in [
            [Icons.notes_rounded, ar ? 'نصوص' : 'Texts'],
            [Icons.link_rounded, ar ? 'روابط' : 'Links'],
            [Icons.image_outlined, ar ? 'صور' : 'Images'],
            [Icons.play_circle_outline_rounded, ar ? 'روابط فيديو' : 'Video links'],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Column(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(e[0] as IconData, color: Colors.white, size: 23),
                ),
                const SizedBox(height: 6),
                Text(e[1] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _page2() {
    final ar = L.isAr;
    Widget step(IconData i, String t, {bool gold = false}) => Expanded(
          child: Column(children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: gold ? _teal : Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: gold ? Border.all(color: _amber, width: 2.5) : null,
              ),
              child: Icon(i, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            Text(t,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.3)),
          ]),
        );
    Widget arrow() => Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Icon(Icons.arrow_back_rounded,
              color: Colors.white.withValues(alpha: 0.6), size: 20),
        );
    return _Slide(
      top: _bubble(112),
      title: ar ? 'الزر العائم' : 'The floating button',
      subtitle: ar ? 'احفظ أي شيء بلمسة واحدة' : 'Save anything with one touch',
      body: ar
          ? 'دائرة صغيرة تبقى فوق أي تطبيق. انسخ، المس، تم!'
          : 'A small bubble stays above any app. Copy, touch, done!',
      extra: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          step(Icons.content_copy_rounded, ar ? 'انسخ نصاً أو رابطاً' : 'Copy text or a link'),
          arrow(),
          step(Icons.touch_app_rounded, ar ? 'المس الدائرة' : 'Touch the bubble', gold: true),
          arrow(),
          step(Icons.check_circle_rounded, ar ? 'تم الحفظ!' : 'Saved!'),
        ],
      ),
    );
  }

  Widget _page3() {
    final ar = L.isAr;
    Widget row(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Icon(i, color: _amber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5)),
            ),
          ]),
        );
    return _Slide(
      top: _bubble(112),
      title: ar ? 'فعّلها الآن' : 'Turn it on now',
      subtitle: ar ? 'تأخذ ثوانٍ وتوفّر عليك الكثير' : 'It takes seconds and saves you a lot',
      body: '',
      extra: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(children: [
          row(Icons.touch_app_rounded, ar ? 'ضغطة: تحفظ ما نسخته' : 'Tap: saves what you copied'),
          row(Icons.open_in_new_rounded, ar ? 'ضغطة مطوّلة: تفتح Keepi' : 'Long press: opens Keepi'),
          row(Icons.open_with_rounded, ar ? 'اسحبها حيث تريد' : 'Drag it anywhere'),
          row(Icons.screenshot_rounded, ar ? 'تلوّن عند لقطة الشاشة لتحفظها' : 'Lights up after a screenshot to save it'),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = L.isAr;
    final last = _page == _count - 1;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2BA58A), Color(0xFF0F4A3D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: widget.onFinish,
                  child: Text(ar ? 'تخطي' : 'Skip',
                      style: const TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pc,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [_page1(), _page2(), _page3()],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? _amber
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _amber,
                          foregroundColor: const Color(0xFF3B2A00),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: last ? widget.onEnableBubble : _next,
                        child: Text(
                          last
                              ? (ar ? 'فعّل الزر العائم' : 'Turn on the floating button')
                              : (ar ? 'التالي' : 'Next'),
                          style: const TextStyle(
                              fontSize: 16.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: last
                          ? TextButton(
                              onPressed: widget.onFinish,
                              child: Text(
                                  ar ? 'ابدأ دون تفعيل' : 'Continue without it',
                                  style: const TextStyle(color: Colors.white)),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final Widget top;
  final String title, subtitle, body;
  final Widget extra;
  const _Slide(
      {required this.top,
      required this.title,
      required this.subtitle,
      required this.body,
      required this.extra});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        children: [
          const SizedBox(height: 18),
          top,
          const SizedBox(height: 22),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _amber, fontSize: 17, fontWeight: FontWeight.w700)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, height: 1.55)),
          ],
          const SizedBox(height: 24),
          extra,
        ],
      ),
    );
  }
}
