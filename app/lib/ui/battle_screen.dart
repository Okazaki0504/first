import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/game_rules.dart';
import '../models/question.dart';
import '../models/subjects.dart';
import '../state/game_state.dart';
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

class _BattleViewState extends State<BattleView> with SingleTickerProviderStateMixin {
  late BattleSession session;
  Question? q;
  int? picked;
  int monsterHp = 100;
  late final AnimationController hit = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void initState() {
    super.initState();
    _start();
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
    hit.dispose();
    super.dispose();
  }

  String get _monsterSubject => widget.mode == BattleMode.boss ? widget.subject! : (q?.subject ?? widget.subject ?? 'fin');

  void _answer(int i) {
    if (picked != null || q == null) return;
    final ok = i == q!.answer;
    setState(() => picked = i);
    if (ok) {
      session.correct++;
      Haptics.success();
      hit.forward(from: 0);
      if (widget.mode == BattleMode.normal) monsterHp = max(0, monsterHp - 25);
    } else {
      Haptics.wrong();
    }
    final r = widget.g.answer(q!, ok, fromTower: widget.mode == BattleMode.tower);
    showReward(context, r, widget.g);
  }

  void _next() {
    final g = widget.g;
    if (widget.mode == BattleMode.normal && monsterHp <= 0) {
      showReward(context, g.monsterDefeated(_monsterSubject), g);
      monsterHp = 100;
    }
    if (session.finished) {
      if (widget.mode == BattleMode.boss) {
        showReward(context, g.bossFinished(widget.subject!, session.correct), g);
      }
      Navigator.of(context).pop();
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
      Container(
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
              animation: hit,
              builder: (_, child) => Transform.translate(offset: Offset(sin(hit.value * pi * 4) * 8, 6), child: child),
              child: Transform.scale(scale: boss ? 1.4 : 1, child: PixelSprite.monster(s.color)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      RpgWindow(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Note('${subjectById(question.subject).name}・${question.topic}　連続正解 ${g.winStreak}'),
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
              onPressed: _next,
            ),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Note(boss
          ? 'ボス戦：この科目からランダム$bossQuestions問。$bossWinCorrect問正解で科目クリア。'
          : tower
              ? '間違えた問題は1→3→7→14日後に再出題。3回連続正解で卒業。'
              : '間違えた問題は「復習の塔」に自動で積まれます。'),
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
