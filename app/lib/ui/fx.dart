import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// 1回だけ再生される火花・光の粒のエフェクト
class ParticleBurst extends StatefulWidget {
  final List<Color> colors;
  final int count;
  final double speed;
  final double up; // 上向きの初速
  final double gravity;
  final Duration duration;
  const ParticleBurst({
    super.key,
    required this.colors,
    this.count = 36,
    this.speed = 4,
    this.up = 1,
    this.gravity = 0.15,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _Particle {
  double x = 0, y = 0;
  final double vx, vy, size;
  final Color color;
  _Particle(this.vx, this.vy, this.size, this.color);
}

class _ParticleBurstState extends State<ParticleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<_Particle> ps;

  @override
  void initState() {
    super.initState();
    final r = Random();
    ps = List.generate(widget.count, (_) {
      final a = r.nextDouble() * pi * 2;
      final s = widget.speed * (0.4 + r.nextDouble());
      return _Particle(cos(a) * s, sin(a) * s - widget.up, 3 + r.nextDouble() * 4, widget.colors[r.nextInt(widget.colors.length)]);
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, _) => CustomPaint(painter: _BurstPainter(ps, c.value, widget.gravity), size: Size.infinite),
        ),
      );
}

class _BurstPainter extends CustomPainter {
  final List<_Particle> ps;
  final double t;
  final double g;
  _BurstPainter(this.ps, this.t, this.g);

  @override
  void paint(Canvas canvas, Size size) {
    final frames = t * 60; // 60フレーム分の動き
    final paint = Paint();
    for (final p in ps) {
      final x = size.width / 2 + p.vx * frames;
      final y = size.height / 2 + p.vy * frames + 0.5 * g * frames * frames;
      paint.color = p.color.withValues(alpha: (1 - t).clamp(0, 1));
      canvas.drawRect(Rect.fromLTWH(x, y, p.size, p.size), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}

/// 画面全体に一定時間だけ演出を重ねる
void showFxOverlay(BuildContext context, Widget child, Duration duration) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => IgnorePointer(child: child));
  overlay.insert(entry);
  Future.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
}

/// 画面が白く光る
class FlashFx extends StatefulWidget {
  const FlashFx({super.key});
  @override
  State<FlashFx> createState() => _FlashFxState();
}

class _FlashFxState extends State<FlashFx> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))..forward();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: c, builder: (_, _) => Container(color: Colors.white.withValues(alpha: 0.7 * (1 - c.value))));
}

/// 文字などを「出現→強調→消える」で見せる共通アニメーション
class PopInOut extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double startScale;
  final bool blink;
  const PopInOut({super.key, required this.child, required this.duration, this.startScale = 3, this.blink = false});
  @override
  State<PopInOut> createState() => _PopInOutState();
}

class _PopInOutState extends State<PopInOut> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: widget.duration)..forward();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final t = c.value;
          final scale = t < 0.15 ? widget.startScale + (1 - widget.startScale) * (t / 0.15) : 1.0;
          var opacity = t < 0.12 ? t / 0.12 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
          if (widget.blink && t > 0.2 && t < 0.7 && ((t * 10).floor() % 2 == 1)) opacity *= 0.35;
          return Opacity(opacity: opacity.clamp(0, 1), child: Transform.scale(scale: scale, child: child));
        },
        child: widget.child,
      );
}

/// ボス戦の開始時に表示する「WARNING」
void showBossWarning(BuildContext context) {
  showFxOverlay(
    context,
    Center(
      child: PopInOut(
        duration: const Duration(milliseconds: 1600),
        startScale: 1.4,
        blink: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0x8C500014),
            border: Border.symmetric(horizontal: BorderSide(color: C.hp, width: 3)),
          ),
          child: Text('⚠ WARNING ⚠',
              textAlign: TextAlign.center,
              style: px(40, color: C.hp).copyWith(
                letterSpacing: 4,
                decoration: TextDecoration.none,
                shadows: const [Shadow(color: C.hp, blurRadius: 16), Shadow(color: Colors.black, offset: Offset(3, 3))],
              )),
        ),
      ),
    ),
    const Duration(milliseconds: 1600),
  );
}

/// ボス撃破時の「VICTORY!」
void showVictory(BuildContext context, String sub) {
  showFxOverlay(context, const FlashFx(), const Duration(milliseconds: 300));
  showFxOverlay(
    context,
    Stack(children: [
      const Positioned.fill(
          child: ParticleBurst(
              colors: [C.gold, Colors.white, Color(0xFFFF7AA8), C.mp], count: 120, speed: 7, up: 2, duration: Duration(milliseconds: 1600))),
      Center(
        child: PopInOut(
          duration: const Duration(milliseconds: 2200),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('VICTORY!',
                style: px(44, color: C.gold).copyWith(
                    decoration: TextDecoration.none,
                    shadows: const [Shadow(color: C.gold, blurRadius: 18), Shadow(color: Colors.black, offset: Offset(3, 3))])),
            Text(sub, style: px(16).copyWith(decoration: TextDecoration.none)),
          ]),
        ),
      ),
    ]),
    const Duration(milliseconds: 2200),
  );
}

/// モンスター撃破後の宝箱
void showChest(BuildContext context, int gold) {
  showFxOverlay(
    context,
    Stack(children: [
      Center(
        child: PopInOut(
          duration: const Duration(milliseconds: 2000),
          startScale: 0.3,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const _ChestBox(),
            const SizedBox(height: 8),
            Text('宝箱を手に入れた！', style: px(18).copyWith(decoration: TextDecoration.none)),
            Text('GOLD +$gold', style: px(20, color: C.gold).copyWith(decoration: TextDecoration.none)),
          ]),
        ),
      ),
      const Positioned.fill(
        child: Padding(
          padding: EdgeInsets.only(bottom: 120),
          child: ParticleBurst(
              colors: [C.gold, Color(0xFFFFE08A)], count: 40, up: 4, gravity: 0.25, duration: Duration(milliseconds: 1400)),
        ),
      ),
    ]),
    const Duration(milliseconds: 2000),
  );
}

class _ChestBox extends StatefulWidget {
  const _ChestBox();
  @override
  State<_ChestBox> createState() => _ChestBoxState();
}

class _ChestBoxState extends State<_ChestBox> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) c.forward();
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 80,
        height: 76,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 4,
            right: 4,
            bottom: 0,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFB5523B),
                  border: Border.all(color: C.gold, width: 4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2))),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 44,
            height: 22,
            child: AnimatedBuilder(
              animation: c,
              builder: (_, child) =>
                  Transform.rotate(angle: -0.6 * c.value, alignment: Alignment.bottomLeft, child: child),
              child: Container(
                decoration: BoxDecoration(
                    color: const Color(0xFFC9683F),
                    border: Border.all(color: C.gold, width: 4),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
              ),
            ),
          ),
        ]),
      );
}

/// 斬撃（2本の光の線）
class SlashFx extends StatefulWidget {
  const SlashFx({super.key});
  @override
  State<SlashFx> createState() => _SlashFxState();
}

class _SlashFxState extends State<SlashFx> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Widget _line(double angle, double delay) {
    final t = ((c.value - delay) / (1 - delay)).clamp(0.0, 1.0);
    final scaleX = t < 0.6 ? t / 0.6 * 1.2 : 1.2 + (t - 0.6) * 0.25;
    final opacity = t == 0 ? 0.0 : (t < 0.6 ? 1.0 : (1 - t) / 0.4);
    return Opacity(
      opacity: opacity.clamp(0, 1),
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scaleX: scaleX,
          child: Container(
            width: 180,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(colors: [Colors.transparent, Colors.white, C.gold, Colors.transparent]),
              boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 12)],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, _) => Center(child: Stack(alignment: Alignment.center, children: [_line(-0.52, 0), _line(0.52, 0.2)])),
        ),
      );
}

/// ダメージの数字（ポップして上に消える）
class DamagePop extends StatefulWidget {
  final String text;
  final bool crit;
  const DamagePop({super.key, required this.text, this.crit = false});
  @override
  State<DamagePop> createState() => _DamagePopState();
}

class _DamagePopState extends State<DamagePop> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, _) {
            final t = c.value;
            final scale = t < 0.2 ? 0.6 + t / 0.2 * 0.65 : (t < 0.35 ? 1.25 - (t - 0.2) / 0.15 * 0.25 : 1.0);
            final dy = t < 0.35 ? 10 * (1 - t / 0.35) : -40 * (t - 0.35) / 0.65;
            final opacity = t < 0.2 ? t / 0.2 : (t > 0.6 ? (1 - t) / 0.4 : 1.0);
            return Align(
              alignment: const Alignment(0, -0.15),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Opacity(
                  opacity: opacity.clamp(0, 1),
                  child: Transform.scale(
                    scale: scale,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(widget.text,
                          style: px(widget.crit ? 28 : 30, color: widget.crit ? C.gold : Colors.white).copyWith(shadows: const [
                            Shadow(color: Colors.black, offset: Offset(3, 3)),
                            Shadow(color: C.gold, blurRadius: 10),
                          ])),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}
