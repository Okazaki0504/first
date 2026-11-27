import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/game_rules.dart';
import '../models/subjects.dart';
import '../services/notifications.dart';
import '../state/game_state.dart';
import 'battle_screen.dart';
import 'theme.dart';
import 'widgets.dart';

const _gap = SizedBox(height: 16);

void openBattle(BuildContext context, GameState g, BattleMode mode, {String? subject}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ListenableBuilder(
      listenable: g,
      builder: (_, _) => BattleView(g: g, mode: mode, subject: subject, standalone: true),
    ),
  ));
}

// ======================= 拠点 =======================
class HomeTab extends StatefulWidget {
  final GameState g;
  const HomeTab(this.g, {super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int seg = 1;
  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final st = stageIndexFor(g.totalGold);
    final next = st + 1 < baseStages.length ? baseStages[st + 1] : null;
    final due = g.dueReviews.length;
    final subs = subjects.where((s) => s.exam == seg).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Hud(g),
      _gap,
      RpgWindow(
        title: '拠点：${baseStages[st].name}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BaseScene(st),
          const SizedBox(height: 8),
          if (next != null) ...[
            Bar(value: (g.totalGold - baseStages[st].gold) / (next.gold - baseStages[st].gold), color: C.gold),
            const SizedBox(height: 3),
            Row(children: [
              Expanded(child: Note('次は「${next.name}」')),
              Note('あと ${next.gold - g.totalGold} GOLD'),
            ]),
          ] else
            const Note('最終段階に到達！'),
          const Note('GOLDはたまる一方のスコア。累計に応じて拠点が村→街→城と育ちます。'),
        ]),
      ),
      _gap,
      RpgWindow(
        title: '復習の塔',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text.rich(TextSpan(children: [
            const TextSpan(text: '今日の復習：'),
            TextSpan(text: '$due問', style: px(15, color: due > 0 ? C.hp : C.ok)),
            TextSpan(text: '　（塔にいる問題 ${g.review.length}問）', style: const TextStyle(fontSize: 11, color: C.muted)),
          ])),
          const SizedBox(height: 8),
          GoldButton(due > 0 ? '塔にのぼる' : '今日の復習はなし', onPressed: due > 0 ? () => openBattle(context, g, BattleMode.tower) : null),
          const SizedBox(height: 6),
          const Note('間違えた問題は、忘れかけるタイミング（1→3→7→14日後）で自動出題。3回連続正解で卒業します。'),
        ]),
      ),
      _gap,
      RpgWindow(
        title: '本日のクエスト',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final q in g.quests) _QuestRow(q),
          const SizedBox(height: 6),
          Note(g.chestOpened ? '全クエスト達成！ 宝箱を開けた。' : '定番3つ＋日替わり1つ。毎朝更新、全達成でボーナス宝箱（GOLD+100）。'),
        ]),
      ),
      _gap,
      RpgWindow(
        title: 'ダンジョン（科目）',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: _Seg('1次 7科目', seg == 1, () => setState(() => seg = 1))),
            const SizedBox(width: 6),
            Expanded(child: _Seg('2次 4事例', seg == 2, () => setState(() => seg = 2))),
          ]),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [for (final s in subs) _DungeonCard(g, s)],
          ),
          const SizedBox(height: 8),
          const Note('階層＝一問一答で正解した問題数（8問で1F）。10Fでボス戦、10問中8問正解で科目クリア。'),
        ]),
      ),
    ]);
  }
}

class _QuestRow extends StatelessWidget {
  final QuestView q;
  const _QuestRow(this.q);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: q.done ? C.ok : null,
              border: Border.all(color: q.done ? C.ok : C.line, width: 2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: q.done ? const Icon(Icons.check, size: 12, color: C.night) : null,
          ),
          const SizedBox(width: 8),
          if (q.daily) Padding(padding: const EdgeInsets.only(right: 4), child: Text('日替', style: px(12, color: C.mp))),
          Expanded(
            child: Text(q.label,
                style: TextStyle(
                  fontSize: 13,
                  color: q.done ? C.muted : C.ink,
                  decoration: q.done ? TextDecoration.lineThrough : null,
                )),
          ),
          Text(q.reward, style: px(11, color: C.gold)),
        ]),
      );
}

class _Seg extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback tap;
  const _Seg(this.label, this.on, this.tap);
  @override
  Widget build(BuildContext context) => Material(
        color: on ? C.gold : C.deep,
        shape: RoundedRectangleBorder(side: BorderSide(color: on ? C.gold : C.edge), borderRadius: BorderRadius.circular(3)),
        child: InkWell(
          onTap: tap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(label, textAlign: TextAlign.center, style: px(13, color: on ? C.night : C.muted)),
          ),
        ),
      );
}

class _DungeonCard extends StatelessWidget {
  final GameState g;
  final Subject s;
  const _DungeonCard(this.g, this.s);
  @override
  Widget build(BuildContext context) {
    final has = g.bank.has(s.id);
    final floor = g.floorOf(s.id);
    final cleared = g.bossCleared.contains(s.id);
    final bossReady = floor >= maxFloor && has;
    return Material(
      color: C.deep,
      shape: RoundedRectangleBorder(side: BorderSide(color: cleared ? C.gold : C.edge), borderRadius: BorderRadius.circular(4)),
      child: InkWell(
        onTap: !has
            ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('この科目の問題は準備中です')))
            : () => openBattle(context, g, bossReady && !cleared ? BattleMode.boss : BattleMode.normal, subject: s.id),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.3), maxLines: 2),
            Row(children: [
              Expanded(
                child: Text(
                  !has ? '準備中' : cleared ? 'CLEAR' : bossReady ? 'BOSS' : 'B${floor}F / ${maxFloor}F',
                  style: px(11, color: cleared ? C.gold : bossReady ? C.hp : C.muted),
                ),
              ),
              Text('${floor * 10}%', style: px(11, color: C.muted)),
            ]),
            Bar(value: floor / maxFloor, color: C.mp, height: 8),
          ]),
        ),
      ),
    );
  }
}

// ======================= 修行（タイマー） =======================
enum TimerMode { free, pomodoro, manual }

class TrainTab extends StatefulWidget {
  final GameState g;
  const TrainTab(this.g, {super.key});
  @override
  State<TrainTab> createState() => _TrainTabState();
}

class _TrainTabState extends State<TrainTab> {
  TimerMode mode = TimerMode.free;
  String subject = 'fin';
  int manualMin = 30;
  DateTime? startedAt; // 計測中なら開始時刻
  Duration banked = Duration.zero; // 一時停止までに貯めた時間
  bool onBreak = false;
  int sets = 0;
  Timer? ticker;

  static const focus = Duration(minutes: 25), rest = Duration(minutes: 5);

  Duration get elapsed => banked + (startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!));
  bool get running => startedAt != null;

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (running) {
        banked = elapsed;
        startedAt = null;
        ticker?.cancel();
      } else {
        startedAt = DateTime.now();
        ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    });
  }

  void _tick() {
    if (mode == TimerMode.pomodoro && elapsed >= (onBreak ? rest : focus)) {
      if (!onBreak) {
        sets++;
        Haptics.big();
        showReward(context, widget.g.recordStudy(subject, 25, pomodoro: true), widget.g);
      } else {
        Haptics.success();
      }
      onBreak = !onBreak;
      banked = Duration.zero;
      startedAt = DateTime.now();
    }
    setState(() {});
  }

  void _finishFree() {
    final m = elapsed.inMinutes;
    ticker?.cancel();
    setState(() {
      startedAt = null;
      banked = Duration.zero;
    });
    if (m < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('1分以上で記録できます')));
      return;
    }
    showReward(context, widget.g.recordStudy(subject, m), widget.g);
  }

  void _setMode(TimerMode m) {
    ticker?.cancel();
    setState(() {
      mode = m;
      startedAt = null;
      banked = Duration.zero;
      onBreak = false;
    });
  }

  String _fmt(Duration d) {
    final s = d.inSeconds.clamp(0, 359999);
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final mm = m.toString().padLeft(2, '0'), ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final clock = mode == TimerMode.pomodoro ? (onBreak ? rest : focus) - elapsed : elapsed;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Hud(g),
      _gap,
      RpgWindow(
        title: '修行の間（学習タイマー）',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            for (final (m, l) in [(TimerMode.free, '自由計測'), (TimerMode.pomodoro, 'ポモドーロ'), (TimerMode.manual, '手入力')]) ...[
              if (m != TimerMode.free) const SizedBox(width: 6),
              Expanded(child: _Seg(l, mode == m, () => _setMode(m))),
            ]
          ]),
          const SizedBox(height: 10),
          const Note('修行する科目'),
          const SizedBox(height: 4),
          _Dropdown<String>(
            value: subject,
            items: {for (final s in subjects) s.id: s.name},
            onChanged: running ? null : (v) => setState(() => subject = v),
          ),
          if (mode == TimerMode.manual) ...[
            const SizedBox(height: 10),
            const Note('学習した時間'),
            const SizedBox(height: 4),
            _Dropdown<int>(
              value: manualMin,
              items: {for (final m in [15, 30, 45, 60, 90, 120, 180]) m: '$m分'},
              onChanged: (v) => setState(() => manualMin = v),
            ),
            const SizedBox(height: 12),
            GoldButton('記録する', onPressed: () => showReward(context, g.recordStudy(subject, manualMin), g)),
          ] else ...[
            if (mode == TimerMode.pomodoro)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${onBreak ? '休憩 5分' : '集中 25分'}　（$setsセット完了）',
                    textAlign: TextAlign.center, style: px(14, color: onBreak ? C.ok : C.gold)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(_fmt(clock),
                  textAlign: TextAlign.center,
                  style: px(54).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            GoldButton(running ? 'いったん休む' : '修行をはじめる', onPressed: _toggle),
            if (mode == TimerMode.free) ...[
              const SizedBox(height: 8),
              GoldButton('修行をおえる（記録する）', ghost: true, onPressed: elapsed.inSeconds > 0 ? _finishFree : null),
            ],
          ],
          const SizedBox(height: 8),
          Note('1分＝EXP 2。ポモドーロは25分ごとに自動で記録。今日の修行：${g.todayMinutes}分'),
        ]),
      ),
    ]);
  }
}

class _Dropdown<T> extends StatelessWidget {
  final T value;
  final Map<T, String> items;
  final ValueChanged<T>? onChanged;
  const _Dropdown({required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: C.deep, border: Border.all(color: C.edge), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          dropdownColor: C.panel,
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: onChanged == null ? null : (v) => v == null ? null : onChanged!(v),
        ),
      );
}

// ======================= 記録 =======================
class LogTab extends StatefulWidget {
  final GameState g;
  const LogTab(this.g, {super.key});
  @override
  State<LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<LogTab> {
  String pastSubject = 'fin';
  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final week = g.weekMinutes;
    final total = week.fold(0, (a, b) => a + b);
    final mx = [...week, 60].reduce((a, b) => a > b ? a : b);
    final todayIdx = g.now.weekday - 1;
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    final ps = subjectById(pastSubject);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RpgWindow(
        title: '今週の修行記録',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, children: [
            Chip2('合計', '${total ~/ 60}時間${total % 60}分'),
            Chip2('目標', '${g.weeklyGoalHours}時間'),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${week[i]}', style: const TextStyle(fontSize: 10, color: C.muted)),
                      const SizedBox(height: 2),
                      Container(height: 90 * week[i] / mx + 2, color: i == todayIdx ? C.gold : C.mp),
                      const SizedBox(height: 2),
                      Text(labels[i], style: const TextStyle(fontSize: 10, color: C.muted)),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
      _gap,
      RpgWindow(
        title: '過去問の戦績',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Dropdown<String>(
            value: pastSubject,
            items: {for (final s in subjects.where((s) => s.exam == 1)) s.id: s.name},
            onChanged: (v) => setState(() => pastSubject = v),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(30),
              border: TableBorder.all(color: const Color(0xFF3B4683)),
              children: [
                TableRow(children: [
                  const SizedBox(height: 28),
                  for (var n = 1; n <= ps.pastExamQuestions; n++) _cell(Text('$n', style: const TextStyle(fontSize: 10, color: C.muted))),
                ]),
                for (final y in pastExamYears)
                  TableRow(children: [
                    _cell(Text(y, style: const TextStyle(fontSize: 10, color: C.muted))),
                    for (var n = 1; n <= ps.pastExamQuestions; n++) _mark(g, y, n),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Note('マスをタップ：○→△→×→空 の順に切替。問題文は載せず、手元の過去問題集と照らして記録します。'),
        ]),
      ),
      _gap,
      RpgWindow(
        title: '実績バッジ',
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: [
            for (final b in badgeDefs)
              Opacity(
                opacity: g.badges.contains(b.key) ? 1 : 0.5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: C.deep,
                    border: Border.all(color: g.badges.contains(b.key) ? C.gold : C.edge),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(g.badges.contains(b.key) ? '★' : '？', style: px(22, color: C.gold)),
                    Text(g.badges.contains(b.key) ? b.name : '？？？',
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(b.desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: C.muted)),
                  ]),
                ),
              ),
          ],
        ),
      ),
      _gap,
      RpgWindow(
        title: '苦手論点',
        child: g.weakTopics.isEmpty
            ? const Note('同じ論点を3回以上解くと、正答率の低い論点がここに表示されます。')
            : Column(children: [
                for (final (s, t, rate) in g.weakTopics)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Container(width: 14, height: 14, color: rate < 0.4 ? C.hp : C.gold),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${subjectById(s).short}：$t', style: const TextStyle(fontSize: 13))),
                      Text('正答率${(rate * 100).round()}%', style: px(11, color: C.gold)),
                    ]),
                  ),
              ]),
      ),
    ]);
  }

  Widget _cell(Widget c) => SizedBox(height: 28, child: Center(child: c));

  Widget _mark(GameState g, String y, int n) {
    final v = g.pastMarks['$pastSubject|$y|$n'] ?? '';
    final bg = switch (v) { 'o' => const Color(0xFF173A2A), 'x' => const Color(0xFF3A1A24), 't' => const Color(0xFF3A331A), _ => null };
    return InkWell(
      onTap: () {
        Haptics.light();
        showReward(context, g.cyclePastMark(pastSubject, y, n), g);
      },
      child: Container(
        height: 28,
        color: bg,
        alignment: Alignment.center,
        child: Text(switch (v) { 'o' => '○', 't' => '△', 'x' => '×', _ => '' }, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

// ======================= 冒険の書（設定） =======================
class BookTab extends StatelessWidget {
  final GameState g;
  final VoidCallback onReplayIntro;
  const BookTab(this.g, {super.key, required this.onReplayIntro});

  Future<void> _pickDate(BuildContext context, DateTime cur, void Function(DateTime) set) async {
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2026),
      lastDate: DateTime(2032),
      locale: const Locale('ja'),
    );
    if (d != null) g.updateSettings((s) => set(d));
  }

  void _resched() => DailyNotifier.schedule(on: g.notifOn, hour: g.notifHour, minute: g.notifMinute, streak: g.streak);

  @override
  Widget build(BuildContext context) {
    String ymd(DateTime d) => '${d.year}年${d.month}月${d.day}日';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RpgWindow(
        title: '冒険の書（試験と目標）',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _row('1次試験日', ymd(g.exam1), () => _pickDate(context, g.exam1, (d) => g.exam1 = d)),
          _row('2次試験日', ymd(g.exam2), () => _pickDate(context, g.exam2, (d) => g.exam2 = d)),
          const SizedBox(height: 6),
          const Note('週の目標修行時間'),
          const SizedBox(height: 4),
          _Dropdown<int>(
            value: g.weeklyGoalHours,
            items: {for (final h in [5, 10, 15, 20, 25, 30]) h: '$h時間'},
            onChanged: (v) => g.updateSettings((s) => s.weeklyGoalHours = v),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            Chip2('1次まで', '${daysUntil(g.exam1, g.now)}日'),
            Chip2('2次まで', '${daysUntil(g.exam2, g.now)}日'),
          ]),
          const SizedBox(height: 6),
          const Note('試験日は仮の値です。試験案内の公表後に正しい日付へ変更してください。'),
        ]),
      ),
      _gap,
      RpgWindow(
        title: 'お知らせ（通知）',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('毎日のクエスト通知', style: TextStyle(fontSize: 13))),
            Switch(value: g.notifOn, onChanged: (v) {
              g.updateSettings((s) => s.notifOn = v);
              _resched();
            }),
          ]),
          _row('通知する時刻', '${g.notifHour}:${g.notifMinute.toString().padLeft(2, '0')}', g.notifOn
              ? () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: g.notifHour, minute: g.notifMinute));
                  if (t != null) {
                    g.updateSettings((s) {
                      s.notifHour = t.hour;
                      s.notifMinute = t.minute;
                    });
                    _resched();
                  }
                }
              : null),
          const Note('端末の中から通知します（サーバーへの送信なし）。'),
        ]),
      ),
      _gap,
      RpgWindow(
        title: '演出',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('振動（正解・レベルアップ時）', style: TextStyle(fontSize: 13))),
            Switch(value: g.vibration, onChanged: (v) {
              g.updateSettings((s) => s.vibration = v);
              Haptics.enabled = v;
            }),
          ]),
          const Note('効果音・BGMはありません。電車の中でも使えます。'),
          const SizedBox(height: 8),
          GoldButton('はじめの物語をもう一度見る', ghost: true, onPressed: onReplayIntro),
        ]),
      ),
      _gap,
      RpgWindow(
        title: 'セーブデータ',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Note('データはこの端末の中だけに保存されます（サーバー送信なし）。収録問題：${g.bank.total}問'),
          const SizedBox(height: 8),
          GoldButton('記録をすべて消す', ghost: true, onPressed: () => _confirmReset(context)),
          const SizedBox(height: 8),
          const Note('収録問題はすべてオリジナルです。本アプリは中小企業診断協会の公式アプリではありません。'),
        ]),
      ),
    ]);
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: Text('記録をすべて消しますか？', style: px(16)),
        content: const Text('レベル・GOLD・学習記録・過去問の記録が消えます。元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('やめる')),
          TextButton(
            onPressed: () {
              g.resetAll();
              Navigator.pop(ctx);
            },
            child: const Text('消す', style: TextStyle(color: C.hp)),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(value, style: px(14, color: onTap == null ? C.muted : C.gold)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: onTap == null ? C.edge : C.muted),
          ]),
        ),
      );
}

// ======================= 初回起動 =======================
class OnboardingScreen extends StatefulWidget {
  final GameState g;
  final VoidCallback onDone;
  const OnboardingScreen(this.g, {super.key, required this.onDone});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const stories = [
    'ここは「中小企業の国」。\n多くの会社が、経営の悩みという霧に包まれている。',
    '霧を晴らせるのは、7つのダンジョンと4つの試練を越えた者――\n「中小企業診断士」だけだという。',
    '君はいま、はじまりの村に立っている。\n冒険の準備をしよう。',
  ];
  int step = 0;
  int target = 2;
  late DateTime exam = widget.g.exam1;
  int goal = 15;

  int get total => stories.length + 3;

  void _next() {
    Haptics.light();
    if (step == total - 1) {
      widget.g.completeOnboarding(target: target, exam1: exam, weeklyGoalHours: goal);
      widget.onDone();
    } else {
      setState(() => step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (step < stories.length) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerLeft, child: PixelSprite.hero(pixel: 6)),
        const SizedBox(height: 12),
        Text(stories[step], style: px(15).copyWith(height: 1.8)),
        const SizedBox(height: 16),
        GoldButton('つづける', onPressed: _next),
      ]);
    } else if (step == stories.length) {
      body = _choices('どの試験に挑む？', ['1次試験から', '2次試験のみ', '1次・2次ストレート'], (i) => target = i);
    } else if (step == stories.length + 1) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(target == 1 ? '2次試験日（仮）はいつ？' : '1次試験日（仮）はいつ？', style: px(15, color: C.gold)),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: exam, firstDate: DateTime(2026), lastDate: DateTime(2032));
            if (d != null) setState(() => exam = d);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.deep, border: Border.all(color: C.edge), borderRadius: BorderRadius.circular(4)),
            child: Text('${exam.year}年${exam.month}月${exam.day}日', style: px(18)),
          ),
        ),
        const SizedBox(height: 6),
        const Note('あとで「冒険の書」から変更できます。'),
        const SizedBox(height: 12),
        GoldButton('けってい', onPressed: _next),
      ]);
    } else {
      body = _choices('1週間の目標修行時間は？', ['5時間', '10時間', '15時間', '20時間'], (i) => goal = [5, 10, 15, 20][i]);
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: RpgWindow(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${step + 1} / $total', style: px(11, color: C.muted)),
                  const SizedBox(height: 6),
                  body,
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choices(String q, List<String> opts, void Function(int) pick) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(q, style: px(15, color: C.gold)),
          const SizedBox(height: 10),
          for (var i = 0; i < opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: C.deep,
                shape: RoundedRectangleBorder(side: const BorderSide(color: C.edge, width: 2), borderRadius: BorderRadius.circular(4)),
                child: InkWell(
                  onTap: () {
                    pick(i);
                    _next();
                  },
                  child: Padding(padding: const EdgeInsets.all(12), child: Text(opts[i], style: const TextStyle(fontSize: 14))),
                ),
              ),
            ),
        ],
      );
}
