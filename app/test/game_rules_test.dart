import 'package:flutter_test/flutter_test.dart';
import 'package:shindan_quest/logic/game_rules.dart';

void main() {
  test('EXPとレベルアップ', () {
    expect(expToNext(1), 140);
    expect(addExp(1, 130, 15), (2, 5, 1));
    expect(addExp(1, 0, 140 + 180), (3, 0, 2));
    expect(titleFor(1), '見習い診断士');
    expect(titleFor(99), 'ストレート合格の勇者');
  });

  test('拠点の成長と階層', () {
    expect(stageIndexFor(0), 0);
    expect(stageIndexFor(999), 0);
    expect(stageIndexFor(1000), 1);
    expect(stageIndexFor(5000), 2);
    expect(floorFor(7), 0);
    expect(floorFor(8), 1);
    expect(floorFor(500), 10);
    expect(bossWon(8), isTrue);
    expect(bossWon(7), isFalse);
  });

  test('復習の塔：1→3→7日後に出題し、3回連続正解で卒業', () {
    final d0 = DateTime(2027, 1, 10, 21);
    var item = onReviewWrong('fin-001', d0);
    expect(item.due, DateTime(2027, 1, 11));
    expect(isDue(item, d0), isFalse);
    expect(isDue(item, DateTime(2027, 1, 11, 7)), isTrue);
    item = onReviewCorrect(item, DateTime(2027, 1, 11))!;
    expect(item.due, DateTime(2027, 1, 14));
    item = onReviewCorrect(item, DateTime(2027, 1, 14))!;
    expect(item.due, DateTime(2027, 1, 21));
    expect(onReviewCorrect(item, DateTime(2027, 1, 21)), isNull);
  });

  test('連続日数', () {
    final mon = DateTime(2027, 1, 4, 23);
    expect(bumpStreak(0, null, mon), 1);
    expect(bumpStreak(5, mon, DateTime(2027, 1, 4, 23, 30)), 5);
    expect(bumpStreak(5, mon, DateTime(2027, 1, 5, 0, 10)), 6);
    expect(bumpStreak(5, mon, DateTime(2027, 1, 6)), 1);
    expect(normalizeStreak(5, mon, DateTime(2027, 1, 5)), 5);
    expect(normalizeStreak(5, mon, DateTime(2027, 1, 6)), 0);
  });

  test('試験日までの日数・日替わりクエスト', () {
    expect(daysUntil(DateTime(2027, 8, 7), DateTime(2027, 8, 6, 23)), 1);
    expect(daysUntil(DateTime(2027, 8, 7), DateTime(2027, 9, 1)), 0);
    final kinds = {for (var i = 0; i < 4; i++) dailyKindFor(DateTime(2027, 1, 1).add(Duration(days: i)))};
    expect(kinds.length, 4);
  });
}
