import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/game_rules.dart';
import '../models/question.dart';
import '../models/subjects.dart';

/// 行動の結果（トースト表示やレベルアップ演出に使う）
class Reward {
  final List<String> messages = [];
  int levelUps = 0;
  void add(String m) => messages.add(m);
  bool get isEmpty => messages.isEmpty && levelUps == 0;
}

class QuestView {
  final String key;
  final String label;
  final String reward;
  final bool done;
  final bool daily;
  const QuestView(this.key, this.label, this.reward, this.done, {this.daily = false});
}

class BadgeDef {
  final String key, name, desc;
  const BadgeDef(this.key, this.name, this.desc);
}

const badgeDefs = [
  BadgeDef('s7', '一週間の旅人', '7日連続で修行'),
  BadgeDef('s30', '不屈の冒険者', '30日連続で修行'),
  BadgeDef('early', '早朝の修行者', '朝6時前に修行を記録'),
  BadgeDef('q100', '百問斬り', '一問一答で100問正解'),
  BadgeDef('boss1', 'はじめての覇者', 'いずれかの科目のボスを撃破'),
  BadgeDef('tower', '塔の踏破者', '復習の塔から50問卒業'),
  BadgeDef('km5', '過去問の番人', '過去問を5年分記録'),
  BadgeDef('all1', '七つの迷宮', '1次7科目のボスをすべて撃破'),
];

String _dayKey(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

class GameState extends ChangeNotifier {
  static const _prefsKey = 'save_v1';
  final SharedPreferences? _prefs;
  final QuestionBank bank;
  DateTime Function() clock;

  GameState(this._prefs, this.bank, {DateTime Function()? clock}) : clock = clock ?? DateTime.now {
    final raw = _prefs?.getString(_prefsKey);
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw));
      } catch (_) {/* 壊れたデータは初期状態で開始 */}
    }
    _rollover();
    streak = normalizeStreak(streak, lastActive, this.clock());
    // 前回の終了時点で条件を満たしていたクエストを反映する（報酬は起動時に付与）
    final r = Reward();
    _checkQuests(r);
    if (!r.isEmpty) save();
  }

  // ---- 設定 ----
  bool onboarded = false;
  int target = 2; // 0:1次から 1:2次のみ 2:ストレート
  DateTime exam1 = DateTime(2027, 8, 7);
  DateTime exam2 = DateTime(2027, 10, 24);
  int weeklyGoalHours = 15;
  bool notifOn = true;
  int notifHour = 20, notifMinute = 30;
  bool vibration = true;

  // ---- 進行 ----
  int lv = 1, exp = 0, totalGold = 0, streak = 0;
  DateTime? lastActive;
  int totalCorrect = 0, towerGraduated = 0, winStreak = 0;
  Map<String, Map<String, int>> studyLog = {}; // 日付 -> 科目 -> 分
  Map<String, List<int>> stats = {}; // 問題ID -> [解答数, 正解数]
  List<ReviewItem> review = [];
  Map<String, String> pastMarks = {}; // "科目|年度|番号" -> o / t / x
  Set<String> bossCleared = {};
  Set<String> badges = {};

  // ---- 今日の進み具合（日付が変わるとリセット） ----
  String todayKey = '';
  int todayCorrect = 0, todayTf = 0, todayWeak = 0, todayPomodoro = 0, todayPastMarks = 0;
  Set<String> questsDone = {};
  bool chestOpened = false;

  // ================= 参照系 =================
  DateTime get now => clock();
  int get todayMinutes => (studyLog[_dayKey(now)] ?? {}).values.fold(0, (a, b) => a + b);

  /// 月曜はじまりの今週7日分の学習分数
  List<int> get weekMinutes {
    final today = dateOnly(now);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return [
      for (var i = 0; i < 7; i++) (studyLog[_dayKey(monday.add(Duration(days: i)))] ?? {}).values.fold(0, (a, b) => a + b)
    ];
  }

  int uniqueCorrectIn(String subject) =>
      stats.entries.where((e) => e.value[1] > 0 && bank.byId[e.key]?.subject == subject).length;
  int floorOf(String subject) => floorFor(uniqueCorrectIn(subject));

  List<ReviewItem> get dueReviews => review.where((r) => isDue(r, now)).toList();

  /// 正答率が最も低い科目（問題がある科目のみ。未回答は対象外。なければ最初の科目）
  String get weakSubject {
    String? best;
    double bestRate = 2;
    for (final s in subjects.where((s) => bank.has(s.id))) {
      var a = 0, c = 0;
      for (final q in bank.of(s.id)) {
        final st = stats[q.id];
        if (st != null) {
          a += st[0];
          c += st[1];
        }
      }
      if (a == 0) continue;
      final r = c / a;
      if (r < bestRate) {
        bestRate = r;
        best = s.id;
      }
    }
    return best ?? subjects.firstWhere((s) => bank.has(s.id), orElse: () => subjects[1]).id;
  }

  /// 苦手論点（3回以上解いた論点のうち正答率が低い順）
  List<(String subject, String topic, double rate)> get weakTopics {
    final agg = <String, List<int>>{};
    stats.forEach((id, st) {
      final q = bank.byId[id];
      if (q == null) return;
      final k = '${q.subject}|${q.topic}';
      final v = agg.putIfAbsent(k, () => [0, 0]);
      v[0] += st[0];
      v[1] += st[1];
    });
    final list = [
      for (final e in agg.entries)
        if (e.value[0] >= 3) (e.key.split('|')[0], e.key.split('|')[1], e.value[1] / e.value[0])
    ]..sort((a, b) => a.$3.compareTo(b.$3));
    return list.take(3).toList();
  }

  DailyKind get dailyKind => dailyKindFor(now);

  List<QuestView> get quests {
    final weak = subjectById(weakSubject).short;
    final daily = switch (dailyKind) {
      DailyKind.weakSubject => ('苦手な「$weak」で3問正解', todayWeak >= 3),
      DailyKind.pastExam => ('過去問の○×を12問ぶん記録', todayPastMarks >= 12),
      DailyKind.pomodoro => ('ポモドーロを2セット', todayPomodoro >= 2),
      DailyKind.trueFalse => ('○×問題で10問正解', todayTf >= 10),
    };
    return [
      QuestView('q5', '一問一答バトルで5問正解', 'EXP+30', questsDone.contains('q5')),
      QuestView('t30', '修行（学習）を30分', 'EXP+40', questsDone.contains('t30')),
      QuestView('tw', '復習の塔：今日の復習を完了', 'EXP+30',
          questsDone.contains('tw')),
      QuestView('daily', daily.$1, 'GOLD+50', questsDone.contains('daily'), daily: true),
    ];
  }

  // ================= 更新系 =================
  void _rollover() {
    final k = _dayKey(now);
    if (todayKey == k) return;
    todayKey = k;
    todayCorrect = todayTf = todayWeak = todayPomodoro = todayPastMarks = 0;
    questsDone = {};
    chestOpened = false;
  }

  void _markActive(Reward r) {
    final n = now;
    streak = bumpStreak(streak, lastActive, n);
    lastActive = n;
  }

  void _gainExp(int n, Reward r) {
    final (l, e, ups) = addExp(lv, exp, n);
    lv = l;
    exp = e;
    r.levelUps += ups;
  }

  void _checkQuests(Reward r) {
    void done(String k, String msg, void Function() give) {
      if (questsDone.contains(k)) return;
      questsDone.add(k);
      give();
      r.add('クエスト達成！ $msg');
    }

    if (todayCorrect >= 5) done('q5', 'EXP+30', () => _gainExp(30, r));
    if (todayMinutes >= 30) done('t30', 'EXP+40', () => _gainExp(40, r));
    if (dueReviews.isEmpty && (todayCorrect > 0 || todayMinutes > 0)) done('tw', 'EXP+30', () => _gainExp(30, r));
    if (_dailyMet) {
      done('daily', 'GOLD+50', () => totalGold += 50);
    }
    if (questsDone.length >= 4 && !chestOpened) {
      chestOpened = true;
      totalGold += 100;
      r.add('全クエスト達成！ 宝箱から GOLD+100');
    }
  }

  bool get _dailyMet => switch (dailyKind) {
        DailyKind.weakSubject => todayWeak >= 3,
        DailyKind.pastExam => todayPastMarks >= 12,
        DailyKind.pomodoro => todayPomodoro >= 2,
        DailyKind.trueFalse => todayTf >= 10,
      };

  void _checkBadges(Reward r) {
    void give(String k, bool cond) {
      if (cond && badges.add(k)) r.add('実績「${badgeDefs.firstWhere((b) => b.key == k).name}」を手に入れた！');
    }

    give('s7', streak >= 7);
    give('s30', streak >= 30);
    give('q100', totalCorrect >= 100);
    give('boss1', bossCleared.isNotEmpty);
    give('tower', towerGraduated >= 50);
    final years = <String, Set<String>>{};
    pastMarks.forEach((k, v) {
      final p = k.split('|');
      years.putIfAbsent(p[0], () => {}).add(p[1]);
    });
    give('km5', years.values.any((y) => y.length >= 5));
    give('all1', subjects.where((s) => s.exam == 1).every((s) => bossCleared.contains(s.id)));
  }

  Reward _finish(Reward r) {
    _checkQuests(r);
    _checkBadges(r);
    save();
    notifyListeners();
    return r;
  }

  /// 一問一答に回答したとき
  Reward answer(Question q, bool correct, {bool fromTower = false}) {
    _rollover();
    final r = Reward();
    final st = stats.putIfAbsent(q.id, () => [0, 0]);
    st[0]++;
    final idx = review.indexWhere((x) => x.qid == q.id);
    if (correct) {
      st[1]++;
      totalCorrect++;
      todayCorrect++;
      winStreak++;
      if (q.isTrueFalse) todayTf++;
      if (q.subject == weakSubject) todayWeak++;
      _gainExp(15, r);
      if (idx >= 0 && (fromTower || isDue(review[idx], now))) {
        final next = onReviewCorrect(review[idx], now);
        if (next == null) {
          review.removeAt(idx);
          towerGraduated++;
          r.add('復習の塔から卒業！');
        } else {
          review[idx] = next;
        }
      }
    } else {
      winStreak = 0;
      final item = onReviewWrong(q.id, now);
      if (idx >= 0) {
        review[idx] = item;
      } else {
        review.add(item);
      }
    }
    _markActive(r);
    return _finish(r);
  }

  Reward monsterDefeated(String subject) {
    final r = Reward();
    totalGold += 40;
    r.add('${subjectById(subject).monster}をたおした！ GOLD+40');
    return _finish(r);
  }

  Reward bossFinished(String subject, int correct) {
    final r = Reward();
    if (bossWon(correct)) {
      bossCleared.add(subject);
      totalGold += 300;
      _gainExp(100, r);
      r.add('ボス撃破！「${subjectById(subject).short}」クリア GOLD+300');
    } else {
      r.add('正解$correct/10…あと${bossWinCorrect - correct}問で撃破だった');
    }
    return _finish(r);
  }

  /// 学習時間を記録（タイマー・手入力共通）
  Reward recordStudy(String subject, int minutes, {bool pomodoro = false}) {
    _rollover();
    final r = Reward();
    if (minutes <= 0) return r;
    final day = studyLog.putIfAbsent(_dayKey(now), () => {});
    day[subject] = (day[subject] ?? 0) + minutes;
    if (pomodoro) todayPomodoro++;
    if (now.hour < 6 && badges.add('early')) r.add('実績「早朝の修行者」を手に入れた！');
    _gainExp(minutes * 2, r);
    r.add('$minutes分の修行を記録 EXP+${minutes * 2}');
    _markActive(r);
    return _finish(r);
  }

  /// 過去問の○△×を切り替える（空→○→△→×→空）
  Reward cyclePastMark(String subject, String year, int no) {
    _rollover();
    final k = '$subject|$year|$no';
    const next = {'': 'o', 'o': 't', 't': 'x', 'x': ''};
    final cur = pastMarks[k] ?? '';
    final nv = next[cur]!;
    if (nv.isEmpty) {
      pastMarks.remove(k);
    } else {
      pastMarks[k] = nv;
      if (cur.isEmpty) todayPastMarks++;
    }
    return _finish(Reward());
  }

  void completeOnboarding({required int target, required DateTime exam1, required int weeklyGoalHours}) {
    this.target = target;
    this.exam1 = exam1;
    this.weeklyGoalHours = weeklyGoalHours;
    onboarded = true;
    save();
    notifyListeners();
  }

  void updateSettings(void Function(GameState s) f) {
    f(this);
    save();
    notifyListeners();
  }

  void resetAll() {
    final keepOnboarded = onboarded;
    _fromJson({});
    onboarded = keepOnboarded;
    todayKey = '';
    _rollover();
    save();
    notifyListeners();
  }

  // ================= 保存 =================
  void save() => _prefs?.setString(_prefsKey, jsonEncode(toJson()));

  Map<String, dynamic> toJson() => {
        'onb': onboarded,
        'target': target,
        'e1': exam1.toIso8601String(),
        'e2': exam2.toIso8601String(),
        'goal': weeklyGoalHours,
        'nOn': notifOn,
        'nH': notifHour,
        'nM': notifMinute,
        'vib': vibration,
        'lv': lv,
        'exp': exp,
        'gold': totalGold,
        'streak': streak,
        'last': lastActive?.toIso8601String(),
        'tc': totalCorrect,
        'tg': towerGraduated,
        'log': studyLog,
        'stats': stats,
        'rev': [for (final r in review) r.toJson()],
        'past': pastMarks,
        'boss': bossCleared.toList(),
        'badges': badges.toList(),
        'today': todayKey,
        'tC': todayCorrect,
        'tTf': todayTf,
        'tW': todayWeak,
        'tP': todayPomodoro,
        'tK': todayPastMarks,
        'qd': questsDone.toList(),
        'chest': chestOpened,
      };

  void _fromJson(Map<String, dynamic> j) {
    onboarded = j['onb'] ?? false;
    target = j['target'] ?? 2;
    exam1 = j['e1'] != null ? DateTime.parse(j['e1']) : DateTime(2027, 8, 7);
    exam2 = j['e2'] != null ? DateTime.parse(j['e2']) : DateTime(2027, 10, 24);
    weeklyGoalHours = j['goal'] ?? 15;
    notifOn = j['nOn'] ?? true;
    notifHour = j['nH'] ?? 20;
    notifMinute = j['nM'] ?? 30;
    vibration = j['vib'] ?? true;
    lv = j['lv'] ?? 1;
    exp = j['exp'] ?? 0;
    totalGold = j['gold'] ?? 0;
    streak = j['streak'] ?? 0;
    lastActive = j['last'] != null ? DateTime.parse(j['last']) : null;
    totalCorrect = j['tc'] ?? 0;
    towerGraduated = j['tg'] ?? 0;
    studyLog = {
      for (final e in ((j['log'] ?? {}) as Map).entries) e.key as String: Map<String, int>.from(e.value as Map)
    };
    stats = {for (final e in ((j['stats'] ?? {}) as Map).entries) e.key as String: List<int>.from(e.value as List)};
    review = [for (final r in (j['rev'] ?? []) as List) ReviewItem.fromJson(Map<String, dynamic>.from(r))];
    pastMarks = Map<String, String>.from(j['past'] ?? {});
    bossCleared = Set<String>.from(j['boss'] ?? []);
    badges = Set<String>.from(j['badges'] ?? []);
    todayKey = j['today'] ?? '';
    todayCorrect = j['tC'] ?? 0;
    todayTf = j['tTf'] ?? 0;
    todayWeak = j['tW'] ?? 0;
    todayPomodoro = j['tP'] ?? 0;
    todayPastMarks = j['tK'] ?? 0;
    questsDone = Set<String>.from(j['qd'] ?? []);
    chestOpened = j['chest'] ?? false;
    winStreak = 0;
  }

  @visibleForTesting
  static GameState inMemory(QuestionBank bank, {DateTime Function()? clock}) => GameState(null, bank, clock: clock);
}
