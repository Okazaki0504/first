import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/game_rules.dart';
import '../models/question.dart';
import '../models/subjects.dart';
import '../state/game_state.dart';
import 'fx.dart';
import 'theme.dart';
import 'widgets.dart';

enum BattleMode { normal, tower, boss }

/// 出題の順番を管理する
class BattleSession {
  final BattleMode mode;
  final String? subject; // normal: null なら全科目
  final GameState g;
  final Random rnd;
  final List<String> _queue = [];
  int asked = 0, correct = 0;

  BattleSession(this.g, this.mode, {this.subject, Random? rnd}) : rnd = rnd ?? Random() {
    if (mode == BattleMode.tower) {
      _queue.addAll(g.dueReviews.map((r) => r.qid));
    } else if (mode == BattleMode.boss) {
      final ids = g.bank.of(subject!).map((q) => q.id).toList()..shuffle(this.rnd);
      _queue.addAll(ids.take(bossQuestions));
    }
  }

  int get total => mode == BattleMode.normal ? 0 : _queue.length + asked;
  bool get finished => mode != BattleMode.normal && _queue.isEmpty;

  List<Question> get _pool => subject != null
      ? g.bank.of(subject!)
      : [for (final s in subjects) ...g.bank.of(s.id)];

  /// 次の問題（4択は選択肢をシャッフル）。出せる問題がなければ null
  Question? next() {
    Question? q;
    if (mode == BattleMode.normal) {
      final pool = _pool;
      if (pool.isEmpty) return null;
      // 7割はまだ正解していない問題から出す
      final unsolved = pool.where((q) => (g.stats[q.id]?[1] ?? 0) == 0).toList();
      final src = unsolved.isNotEmpty && rnd.nextDouble() < 0.7 ? unsolved : pool;
      q = src[rnd.nextInt(src.length)];
    } else {
      if (_queue.isEmpty) return null;
      q = g.bank.byId[_queue.removeAt(0)];
      if (q == null) return next();
    }
    asked++;
    return q.shuffled(rnd);
  }
}

class BattleView extends StatefulWidget {
  final GameState g;
  final BattleMode mode;
  final String? subject;
  final bool standalone; // 別画面として開いたとき（戻るボタンを出す）
  const BattleView({super.key, required this.g, this.mode = BattleMode.normal, this.subject, this.standalone = false});

  @override
  State<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<BattleView> with TickerProviderStateMixin {
  late BattleSession session;
  Question? q;
  int? picked;
  int monsterHp = 100;
  bool busy = false; // 撃破演出の間はボタンを押せない
  int fxId = 0; // 演出を再生するたびに増やす（新しいキーで作り直す）
  bool lastCrit = false;
  int lastDamage = 0;
  late final AnimationController hit = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  late final AnimationController shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final AnimationController dying = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  NavigatorState? _nav;

  @override
  void initState() {
    super.initState();
    _start();
    if (widget.standalone) widget.g.battleEnter();
    if (widget.mode == BattleMode.boss && q != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Haptics.big();
          showBossWarning(context);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nav = Navigator.maybeOf(context);
  }

  @override
  void didUpdateWidget(covariant BattleView old) {
    super.didUpdateWidget(old);
    if (old.subject != widget.subject || old.mode != widget.mode) _start();
  }

  void _start() {
    session = BattleSession(widget.g, widget.mode, subject: widget.subject);
    monsterHp = 100;
    picked = null;
    q = session.next();
  }

  @override
  void dispose() {
    // 別画面のバトル（塔・ボス・ダンジョン）を閉じたら、学習時間を記録する
    if (widget.standalone) {
      final r = widget.g.flushBattleStudy();
      final nav = _nav;
      if (nav != null && nav.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (nav.mounted) showReward(nav.context, r, widget.g);
        });
      }
    }
    hit.dispose();
    shake.dispose();
    dying.dispose();
    super.dispose();
  }

  String get _monsterSubject => widget.mode == BattleMode.boss ? widget.subject! : (q?.subject ?? widget.subject ?? 'fin');

  void _answer(int i) {
    if (picked != null || q == null || busy) return;
    final g = widget.g;
    final ok = i == q!.answer;
    g.battleTick(q!.subject);
    final r = g.answer(q!, ok, fromTower: widget.mode == BattleMode.tower);
    setState(() {
      picked = i;
      if (ok) {
        session.correct++;
        lastCrit = g.winStreak >= 3; // 3問連続正解から会心の一撃
        lastDamage = lastCrit ? 50 : 25;
        if (widget.mode == BattleMode.normal) monsterHp = max(0, monsterHp - lastDamage);
        fxId++;
      }
    });
    if (ok) {
      lastCrit ? Haptics.big() : Haptics.success();
      hit.forward(from: 0);
      shake.forward(from: 0);
      if (lastCrit) showFxOverlay(context, const FlashFx(), const Duration(milliseconds: 300));
    } else {
      Haptics.wrong();
    }
    showReward(context, r, g);
  }

  Future<void> _next() async {
    final g = widget.g;
    if (busy) return;
    if (widget.mode == BattleMode.normal && monsterHp <= 0) {
      // 撃破：点滅して砕け散る → 宝箱
      setState(() => busy = true);
      Haptics.big();
      dying.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => fxId++);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      showChest(context, 40);
      final r = g.monsterDefeated(_monsterSubject);
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;
      showReward(context, r, g);
      dying.reset();
      monsterHp = 100;
      busy = false;
    }
    if (session.finished) {
      final nav = Navigator.of(context);
      if (widget.mode == BattleMode.boss) {
        final r = g.bossFinished(widget.subject!, session.correct);
        if (g.bossCleared.contains(widget.subject)) {
          setState(() => busy = true);
          Haptics.big();
          showVictory(context, '科目クリア　GOLD +300');
          await Future.delayed(const Duration(milliseconds: 2300));
        }
        nav.pop();
        if (nav.mounted) showReward(nav.context, r, g);
        return;
      }
      nav.pop();
      return;
    }
    setState(() {
      picked = null;
      q = session.next();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final boss = widget.mode == BattleMode.boss;
    final tower = widget.mode == BattleMode.tower;
    if (q == null) {
      return _wrap(RpgWindow(
        child: Column(children: [
          Text(tower ? '今日の復習はすべて終わった！' : 'この科目の問題は準備中です', style: px(15)),
          const SizedBox(height: 12),
          if (widget.standalone) GoldButton('もどる', onPressed: () => Navigator.of(context).pop()),
        ]),
      ));
    }
    final s = subjectById(_monsterSubject);
    final question = q!;
    final name = boss ? 'BOSS ${s.monster}王' : tower ? '復習の塔の番兵' : s.monster;
    final hpValue = boss ? max(0.0, 1 - session.correct / bossWinCorrect) : tower ? 1 - (session.asked - 1) / max(1, session.total) : monsterHp / 100;
    final hpLabel = boss
        ? '${session.asked}/$bossQuestions問　正解${session.correct}（$bossWinCorrectで撃破）'
        : tower
            ? '${session.asked}/${session.total}問'
            : 'HP $monsterHp';

    return _wrap(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnimatedBuilder(
        animation: shake,
        builder: (_, child) {
          final t = shake.value;
          final dx = (t == 0 || t == 1) ? 0.0 : sin(t * pi * 6) * 6 * (1 - t);
          return Transform.translate(offset: Offset(dx, -dx / 2), child: child);
        },
        child: Container(
        height: 170,
        decoration: BoxDecoration(
          border: Border.all(color: C.line, width: 3),
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.55, 0.55],
            colors: boss ? const [Color(0xFF4A1F3A), Color(0xFF2A1A2A)] : const [Color(0xFF2B2F6B), Color(0xFF3A3A55)],
          ),
        ),
        child: Stack(children: [
          Positioned(
            left: 10,
            right: 10,
            top: 8,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Expanded(child: Text(name, style: px(13))), Text(hpLabel, style: const TextStyle(fontSize: 10))]),
              const SizedBox(height: 3),
              Bar(value: hpValue, color: C.hp),
            ]),
          ),
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([hit, dying]),
              builder: (_, child) {
                // 撃破：点滅→少し膨らむ→縮んで消える
                final d = dying.value;
                var opacity = 1.0, scale = 1.0, angle = 0.0;
                if (d > 0) {
                  if (d < 0.5) {
                    opacity = ((d * 10).floor() % 2 == 0) ? 1.0 : 0.2;
                  } else if (d < 0.7) {
                    scale = 1 + (d - 0.5) / 0.2 * 0.15;
                  } else {
                    final k = (d - 0.7) / 0.3;
                    scale = 1.15 - k * 0.95;
                    opacity = 1 - k;
                    angle = k * 0.45;
                  }
                }
                return Opacity(
                  opacity: opacity.clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(sin(hit.value * pi * 4) * 8, 6),
                    child: Transform.rotate(angle: angle, child: Transform.scale(scale: scale, child: child)),
                  ),
                );
              },
              child: Transform.scale(scale: boss ? 1.4 : 1, child: PixelSprite.monster(s.color)),
            ),
          ),
          // 正解時の演出（斬撃・火花・ダメージ・コンボ）
          if (picked != null && picked == question.answer) ...[
            Positioned.fill(child: SlashFx(key: ValueKey('slash$fxId'))),
            Positioned.fill(
              child: ParticleBurst(
                key: ValueKey('spark$fxId'),
                colors: lastCrit ? const [C.gold, Colors.white, Color(0xFFFF9F6B)] : const [Colors.white, C.gold],
                count: lastCrit ? 50 : 24,
                duration: const Duration(milliseconds: 800),
              ),
            ),
            Positioned.fill(
              child: DamagePop(
                key: ValueKey('dmg$fxId'),
                text: lastCrit ? '会心の一撃！ -$lastDamage' : '-$lastDamage',
                crit: lastCrit,
              ),
            ),
            if (g.winStreak >= 2)
              Positioned(
                right: 10,
                bottom: 8,
                child: Text('${g.winStreak} COMBO!',
                    style: px(16, color: C.gold).copyWith(shadows: const [Shadow(color: Colors.black, offset: Offset(2, 2))])),
              ),
          ],
          // 撃破時の大きな火花
          if (busy && dying.value > 0)
            Positioned.fill(
              child: ParticleBurst(
                key: ValueKey('defeat$fxId'),
                colors: const [C.ok, Colors.white, C.mp, C.gold],
                count: 70,
                speed: 6,
                duration: const Duration(milliseconds: 1100),
              ),
            ),
        ]),
      ),
      ),
      const SizedBox(height: 16),
      RpgWindow(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Note('${subjectById(question.subject).name}・${question.topic}　連続正解 ${g.winStreak}')),
            Text('⏱ 自動記録中', style: px(11, color: C.ok)),
          ]),
          const SizedBox(height: 4),
          Text(question.text, style: px(14).copyWith(height: 1.7)),
          const SizedBox(height: 10),
          if (question.isTrueFalse)
            Row(children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _choice(i, question.choices[i], big: true)),
              ]
            ])
          else
            for (var i = 0; i < question.choices.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: _choice(i, '${'ABCD'[i]}．${question.choices[i]}')),
          if (picked != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: C.gold, width: 3))),
              child: Text('${picked == question.answer ? '会心の一撃！' : 'ダメージを受けた…'}　${question.explanation}',
                  style: const TextStyle(fontSize: 12, color: C.muted, height: 1.6)),
            ),
            const SizedBox(height: 12),
            GoldButton(
              session.finished
                  ? (boss ? 'ボス戦の結果を見る' : '塔をおりる')
                  : (widget.mode == BattleMode.normal && monsterHp <= 0 ? '宝箱をあける' : 'つぎの問題へ'),
              onPressed: busy ? null : _next,
            ),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Note(boss
          ? 'ボス戦：この科目からランダム$bossQuestions問。$bossWinCorrect問正解で科目クリア。'
          : tower
              ? '間違えた問題は1→3→7→14日後に再出題。3回連続正解で卒業。'
              : '間違えた問題は「復習の塔」に自動で積まれます。3問連続正解で会心の一撃。バトル中の時間は学習時間に自動で記録（1問あたり最大3分）。'),
    ]));
  }

  Widget _choice(int i, String label, {bool big = false}) {
    final q = this.q!;
    Color border = C.edge, bg = C.deep;
    if (picked != null) {
      if (i == q.answer) {
        border = C.ok;
        bg = const Color(0xFF173A2A);
      } else if (i == picked) {
        border = C.hp;
        bg = const Color(0xFF3A1A24);
      }
    }
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(side: BorderSide(color: border, width: 2), borderRadius: BorderRadius.circular(4)),
      child: InkWell(
        onTap: picked == null ? () => _answer(i) : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: big ? 6 : 10),
          child: Text(label,
              textAlign: big ? TextAlign.center : TextAlign.start,
              style: big ? px(28) : const TextStyle(fontSize: 13, height: 1.45)),
        ),
      ),
    );
  }

  Widget _wrap(Widget child) {
    if (!widget.standalone) return child;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.deeper,
        title: Text(widget.mode == BattleMode.boss ? 'ボス戦' : widget.mode == BattleMode.tower ? '復習の塔' : 'バトル', style: px(16)),
      ),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [child])),
    );
  }
}

/// バトルタブ：科目を選んで連続で解く
class BattleTab extends StatefulWidget {
  final GameState g;
  const BattleTab(this.g, {super.key});
  @override
  State<BattleTab> createState() => _BattleTabState();
}

class _BattleTabState extends State<BattleTab> {
  String? subject;
  @override
  Widget build(BuildContext context) {
    final avail = subjects.where((s) => widget.g.bank.has(s.id)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _pill('全科目', subject == null, () => setState(() => subject = null)),
          for (final s in avail) _pill(s.short, subject == s.id, () => setState(() => subject = s.id)),
        ]),
      ),
      const SizedBox(height: 12),
      BattleView(g: widget.g, subject: subject),
    ]);
  }

  Widget _pill(String label, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: on ? C.gold : C.deep,
          shape: RoundedRectangleBorder(side: BorderSide(color: on ? C.gold : C.edge), borderRadius: BorderRadius.circular(3)),
          child: InkWell(
            onTap: tap,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(label, style: px(13, color: on ? C.night : C.muted))),
          ),
        ),
      );
}
