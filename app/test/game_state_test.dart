import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shindan_quest/models/question.dart';
import 'package:shindan_quest/models/subjects.dart';
import 'package:shindan_quest/state/game_state.dart';

QuestionBank loadBank() {
  final map = <String, List<Question>>{};
  for (final f in Directory('assets/questions').listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
    final list = (jsonDecode(f.readAsStringSync()) as List).map((e) => Question.fromJson(e)).toList();
    map[list.first.subject] = list;
  }
  return QuestionBank(map);
}

void main() {
  final bank = loadBank();

  test('収録問題の整合性（全科目）', () {
    expect(bank.bySubject.keys, containsAll(['fin', 'eco']));
    expect(bank.byId.length, bank.bySubject.values.fold<int>(0, (a, l) => a + l.length), reason: 'IDの重複');
    for (final q in bank.byId.values) {
      expect(subjects.any((s) => s.id == q.subject), isTrue, reason: q.id);
      expect(q.answer, inInclusiveRange(0, q.choices.length - 1), reason: q.id);
      expect(q.choices.length, q.isTrueFalse ? 2 : 4, reason: q.id);
    }
  });

  test('選択肢をシャッフルしても正解の中身は同じ', () {
    final rnd = Random(1);
    for (final q in bank.byId.values) {
      final s = q.shuffled(rnd);
      expect(s.choices[s.answer], q.choices[q.answer]);
    }
  });

  test('回答・クエスト・復習の塔の流れ', () {
    var now = DateTime(2027, 1, 4, 9);
    final g = GameState.inMemory(bank, clock: () => now);
    final qs = bank.of('fin');
    // 1問まちがえる → 塔に入る（翌日から）
    g.answer(qs[0], false);
    expect(g.review.length, 1);
    expect(g.dueReviews, isEmpty);
    // 5問正解 → q5クエスト達成
    for (var i = 1; i <= 5; i++) {
      g.answer(qs[i], true);
    }
    expect(g.quests.firstWhere((q) => q.key == 'q5').done, isTrue);
    expect(g.streak, 1);
    // 30分学習 → t30達成
    final r = g.recordStudy('fin', 30);
    expect(r.messages.any((m) => m.contains('クエスト達成')), isTrue);
    expect(g.todayMinutes, 30);
    // 翌日：塔に1問、連続日数2
    now = DateTime(2027, 1, 5, 8);
    expect(g.dueReviews.length, 1);
    g.answer(qs[0], true, fromTower: true);
    expect(g.dueReviews, isEmpty);
    expect(g.streak, 2);
    expect(g.quests.firstWhere((q) => q.key == 'q5').done, isFalse); // 日付が変わってリセット
  });

  test('ボス戦と保存・復元', () {
    final g = GameState.inMemory(bank, clock: () => DateTime(2027, 2, 1, 10));
    g.bossFinished('fin', 8);
    expect(g.bossCleared, contains('fin'));
    expect(g.badges, contains('boss1'));
    expect(g.totalGold, 300);
    final g2 = GameState.inMemory(bank);
    // toJson -> 新しいインスタンスへ復元できるか（キーの往復）
    final json = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(json['boss'], ['fin']);
    expect(g2.totalGold, 0);
  });

  test('過去問の記録は 空→○→△→×→空', () {
    final g = GameState.inMemory(bank, clock: () => DateTime(2027, 2, 1, 10));
    for (final expected in ['o', 't', 'x', null]) {
      g.cyclePastMark('fin', 'R7', 1);
      expect(g.pastMarks['fin|R7|1'], expected);
    }
    expect(g.todayPastMarks, 1);
  });

  test('バトル中の学習時間の自動記録（1問あたり最大3分、閉じていた時間は除外）', () {
    var now = DateTime(2027, 3, 1, 9, 0, 0);
    final g = GameState.inMemory(bank, clock: () => now);
    final q = bank.of('fin').first;
    g.battleEnter();
    now = now.add(const Duration(seconds: 90)); // 1問目に90秒
    g.battleTick(q.subject);
    now = now.add(const Duration(minutes: 10)); // 2問目は放置して10分 → 3分だけ数える
    g.battleTick(q.subject);
    g.battlePause();
    now = now.add(const Duration(minutes: 30)); // アプリを閉じていた30分は数えない
    g.battleResume();
    now = now.add(const Duration(seconds: 60));
    g.battleTick(q.subject);
    final r = g.flushBattleStudy(); // 90+180+60=330秒 → 5分
    expect(g.todayMinutes, 5);
    expect(r.messages.any((m) => m.contains('5分を自動で記録')), isTrue);
    // 端数の30秒は次回に持ち越し
    g.battleEnter();
    now = now.add(const Duration(seconds: 30));
    g.battleTick(q.subject);
    g.flushBattleStudy();
    expect(g.todayMinutes, 6);
  });
}
