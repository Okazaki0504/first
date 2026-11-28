import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/game_rules.dart';
import '../state/game_state.dart';
import 'fx.dart';
import 'theme.dart';

/// RPGのメッセージウィンドウ風の枠
class RpgWindow extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsets padding;
  const RpgWindow({super.key, this.title, required this.child, this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.panel,
        border: Border.all(color: C.line, width: 3),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: C.night, spreadRadius: 3), BoxShadow(color: Color(0xFF3B4683), spreadRadius: 5)],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(children: [
              const Icon(Icons.play_arrow_rounded, color: C.gold, size: 18),
              const SizedBox(width: 4),
              Expanded(child: Text(title!, style: px(15, color: C.gold))),
            ]),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

class Bar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const Bar({super.key, required this.value, required this.color, this.height = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: C.deeper, border: Border.all(color: C.edge), borderRadius: BorderRadius.circular(2)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          widthFactor: value.clamp(0, 1),
          child: Container(color: color),
        ),
      ),
    );
  }
}

class Chip2 extends StatelessWidget {
  final String label;
  final String value;
  const Chip2(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: C.deep, border: Border.all(color: C.edge), borderRadius: BorderRadius.circular(3)),
      child: Text.rich(TextSpan(style: px(12), children: [
        TextSpan(text: '$label '),
        TextSpan(text: value, style: px(12, color: C.gold)),
      ])),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool ghost;
  const GoldButton(this.label, {super.key, this.onPressed, this.ghost = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: ghost ? Colors.transparent : (enabled ? C.gold : C.edge),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: ghost ? const BorderSide(color: C.line, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed == null
            ? null
            : () {
                Haptics.light();
                onPressed!();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: ghost || !enabled
              ? null
              : const BoxDecoration(border: Border(bottom: BorderSide(color: C.goldDark, width: 4))),
          alignment: Alignment.center,
          child: Text(label, style: px(15, color: ghost ? C.ink : C.night)),
        ),
      ),
    );
  }
}

class Note extends StatelessWidget {
  final String text;
  const Note(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 11, color: C.muted, height: 1.6));
}

// ---------- ドット絵 ----------
const _heroMap = [
  '...1111...', '..122221..', '..1d33d1..', '..133331..', '...1331...',
  '.11444411.', '1.144441.1', '..144441..', '..15..51..', '..11..11..',
];
const _slimeMap = [
  '....1111....', '..11222211..', '.1222222221.', '122322223221', '122332233221',
  '122222222221', '122244442221', '122222222221', '.1222222221.', '..11111111..',
];

class PixelSprite extends StatelessWidget {
  final List<String> map;
  final Map<String, Color> palette;
  final double pixel;
  const PixelSprite(this.map, this.palette, {super.key, this.pixel = 5});

  factory PixelSprite.hero({double pixel = 5}) => PixelSprite(_heroMap, const {
        '1': C.night, '2': C.mp, '3': Color(0xFFF5D6B4), 'd': C.night, '4': Color(0xFF3F5FD1), '5': C.night,
      }, pixel: pixel);

  factory PixelSprite.monster(Color body, {double pixel = 9}) => PixelSprite(_slimeMap, {
        '1': C.deeper, '2': body, '3': Colors.white, '4': C.deeper,
      }, pixel: pixel);

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(map[0].length * pixel, map.length * pixel),
        painter: _SpritePainter(map, palette, pixel),
      );
}

class _SpritePainter extends CustomPainter {
  final List<String> map;
  final Map<String, Color> palette;
  final double p;
  _SpritePainter(this.map, this.palette, this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < map.length; y++) {
      for (var x = 0; x < map[y].length; x++) {
        final c = palette[map[y][x]];
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(x * p, y * p, p + 0.5, p + 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) => old.map != map || old.palette != palette;
}

/// 拠点の絵（村・街・城）
class BaseScene extends StatelessWidget {
  final int stage;
  const BaseScene(this.stage, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border.all(color: C.line, width: 2), borderRadius: BorderRadius.circular(4)),
        child: AspectRatio(aspectRatio: 96 / 54, child: CustomPaint(painter: _BasePainter(stage))),
      );
}

class _BasePainter extends CustomPainter {
  final int st;
  _BasePainter(this.st);
  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 96;
    final p = Paint()..isAntiAlias = false;
    void r(double x, double y, double w, double h, int c) {
      p.color = Color(c);
      canvas.drawRect(Rect.fromLTWH(x * u, y * u, w * u, h * u), p);
    }

    r(0, 0, 96, 40, 0xFF2B2F6B);
    r(0, 40, 96, 14, 0xFF3D6B3A);
    r(0, 50, 96, 4, 0xFF2E5230);
    r(70, 6, 6, 6, 0xFFF3EFE0);
    void hut(double x) {
      r(x, 30, 12, 10, 0xFFC9A26B);
      r(x - 1, 26, 14, 4, 0xFFB5523B);
      r(x + 2, 24, 8, 2, 0xFFB5523B);
      r(x + 5, 34, 3, 6, 0xFF3B2A1A);
    }

    void house(double x, double h, int c) {
      r(x, 40 - h, 14, h, c);
      r(x - 1, 36 - h, 16, 4, 0xFF3F5FD1);
      r(x + 2, 44 - h, 3, 3, 0xFFF2C14E);
      r(x + 9, 44 - h, 3, 3, 0xFFF2C14E);
      r(x + 5, 34, 4, 6, 0xFF3B2A1A);
    }

    if (st == 0) {
      hut(20);
      hut(44);
      r(66, 28, 3, 12, 0xFF5A3B22);
      r(62, 22, 11, 8, 0xFF3D8B3A);
    } else if (st == 1) {
      r(4, 32, 88, 8, 0xFF8A8FA8);
      house(10, 14, 0xFFE9E4CF);
      house(30, 18, 0xFFD9C7A0);
      house(52, 14, 0xFFE9E4CF);
      house(72, 16, 0xFFD9C7A0);
    } else {
      r(4, 30, 88, 10, 0xFF8A8FA8);
      r(30, 14, 36, 26, 0xFFD7D9E6);
      r(26, 8, 10, 32, 0xFFC4C7D8);
      r(60, 8, 10, 32, 0xFFC4C7D8);
      r(43, 2, 10, 14, 0xFFC4C7D8);
      r(26, 5, 10, 3, 0xFFB5523B);
      r(60, 5, 10, 3, 0xFFB5523B);
      r(43, 0, 10, 2, 0xFFB5523B);
      r(44, 28, 8, 12, 0xFF3B2A1A);
      r(30, 18, 3, 4, 0xFFF2C14E);
      r(63, 18, 3, 4, 0xFFF2C14E);
    }
  }

  @override
  bool shouldRepaint(covariant _BasePainter old) => old.st != st;
}

/// 画面上部のステータス表示
class Hud extends StatelessWidget {
  final GameState g;
  const Hud(this.g, {super.key});
  @override
  Widget build(BuildContext context) {
    final need = expToNext(g.lv);
    return RpgWindow(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: C.panel2, border: Border.all(color: C.line, width: 2), borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.center,
            child: PixelSprite.hero(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Expanded(child: Text('受験者', style: px(16))), Text('Lv ${g.lv}', style: px(16))]),
              Text('称号：${titleFor(g.lv)}', style: const TextStyle(fontSize: 11, color: C.muted)),
              const SizedBox(height: 4),
              Bar(value: g.exp / need, color: C.gold),
              const SizedBox(height: 3),
              Row(children: [
                const Expanded(child: Text('EXP', style: TextStyle(fontSize: 10, color: C.muted))),
                Text('${g.exp} / $need', style: const TextStyle(fontSize: 10, color: C.muted, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip2('連続', '${g.streak} 日'),
          Chip2('GOLD', '${g.totalGold}'),
          if (g.target != 1) Chip2('1次まで', '${daysUntil(g.exam1, g.now)} 日') else Chip2('2次まで', '${daysUntil(g.exam2, g.now)} 日'),
        ]),
      ]),
    );
  }
}

/// トースト・レベルアップ演出
void showReward(BuildContext context, Reward r, GameState g) {
  if (r.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  for (final m in r.messages) {
    messenger.showSnackBar(SnackBar(
      content: Text(m, style: px(14), textAlign: TextAlign.center),
      backgroundColor: C.panel,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
      shape: RoundedRectangleBorder(side: const BorderSide(color: C.gold, width: 3), borderRadius: BorderRadius.circular(6)),
    ));
  }
  if (r.levelUps > 0) {
    Haptics.big();
    showDialog(
      context: context,
      barrierColor: const Color(0xD9080A19),
      builder: (_) => Stack(children: [
        // 光の粒が舞う
        const Positioned.fill(
          child: ParticleBurst(
              colors: [C.gold, Colors.white, C.mp], count: 90, speed: 6, up: 3, duration: Duration(milliseconds: 1500)),
        ),
        Center(
        child: SizedBox(
          width: 300,
          child: Material(
            color: Colors.transparent,
            child: RpgWindow(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('LEVEL UP!', style: px(16)),
                _Bounce(child: Text('Lv ${g.lv}', style: px(34, color: C.gold))),
                Text('称号「${titleFor(g.lv)}」', style: const TextStyle(fontSize: 12, color: C.muted)),
                const SizedBox(height: 12),
                GoldButton('つづける', onPressed: () => Navigator.of(context).pop()),
              ]),
            ),
          ),
        ),
      ),
      ]),
    );
  }
}

/// 上下にふわふわ弾む
class _Bounce extends StatefulWidget {
  final Widget child;
  const _Bounce({required this.child});
  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) => Transform.translate(offset: Offset(0, -6 * sin(c.value * pi)), child: child),
        child: widget.child,
      );
}
