// ゲームのルール（UIに依存しない純粋なロジック。テスト対象）

/// レベル lv から次のレベルに必要なEXP
int expToNext(int lv) => 100 + lv * 40;

const titles = ['見習い診断士', '駆け出しの冒険者', '論点ハンター', '過去問の騎士', '白書の賢者', 'ストレート合格の勇者'];

/// レベルに応じた称号（3レベルごとに昇格）
String titleFor(int lv) => titles[(lv ~/ 3).clamp(0, titles.length - 1)];

/// EXPを加算し、(新レベル, 新EXP, 上がったレベル数) を返す
(int, int, int) addExp(int lv, int exp, int gain) {
  var l = lv, e = exp + gain, ups = 0;
  while (e >= expToNext(l)) {
    e -= expToNext(l);
    l++;
    ups++;
  }
  return (l, e, ups);
}

// ---- 拠点の成長（累計GOLDで決まる。GOLDは消費しない） ----
class BaseStage {
  final String name;
  final int gold;
  const BaseStage(this.name, this.gold);
}

const baseStages = [BaseStage('はじまりの村', 0), BaseStage('にぎわいの街', 1000), BaseStage('合格の城', 3000)];

int stageIndexFor(int totalGold) {
  var idx = 0;
  for (var i = 0; i < baseStages.length; i++) {
    if (totalGold >= baseStages[i].gold) idx = i;
  }
  return idx;
}

// ---- ダンジョン階層 ----
const maxFloor = 10;
const correctPerFloor = 8;

/// 科目内で一度でも正解した問題数から階層を決める（8問ごとに1F、最大10F）
int floorFor(int uniqueCorrect) => (uniqueCorrect ~/ correctPerFloor).clamp(0, maxFloor);

// ---- ボス戦 ----
const bossQuestions = 10;
const bossWinCorrect = 8;
bool bossWon(int correct) => correct >= bossWinCorrect;

// ---- 復習の塔（忘却曲線） ----
/// 間違えた問題の出題間隔（日）。連続正解の回数ごとに伸びる
const reviewIntervals = [1, 3, 7, 14];
const reviewGraduateStreak = 3;

class ReviewItem {
  final String qid;
  final int streak; // 塔での連続正解数
  final DateTime due; // 次に出題する日（日付のみ）
  const ReviewItem(this.qid, this.streak, this.due);

  Map<String, dynamic> toJson() => {'q': qid, 's': streak, 'd': due.toIso8601String()};
  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(j['q'], j['s'], DateTime.parse(j['d']));
}

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// 誤答時：連続正解をリセットし、翌日に出題
ReviewItem onReviewWrong(String qid, DateTime now) => ReviewItem(qid, 0, dateOnly(now).add(const Duration(days: 1)));

/// 塔で正解時：卒業なら null、そうでなければ次の出題日へ
ReviewItem? onReviewCorrect(ReviewItem item, DateTime now) {
  final s = item.streak + 1;
  if (s >= reviewGraduateStreak) return null;
  return ReviewItem(item.qid, s, dateOnly(now).add(Duration(days: reviewIntervals[s])));
}

bool isDue(ReviewItem item, DateTime now) => !item.due.isAfter(dateOnly(now));

// ---- 連続日数 ----
/// 最終学習日と今日から、連続日数を補正する（休んだ日があれば0に戻す）
int normalizeStreak(int streak, DateTime? lastActive, DateTime now) {
  if (lastActive == null) return 0;
  final diff = dateOnly(now).difference(dateOnly(lastActive)).inDays;
  return diff <= 1 ? streak : 0;
}

/// 今日はじめて学習したときに呼ぶ。新しい連続日数を返す
int bumpStreak(int streak, DateTime? lastActive, DateTime now) {
  if (lastActive == null) return 1;
  final diff = dateOnly(now).difference(dateOnly(lastActive)).inDays;
  if (diff == 0) return streak;
  if (diff == 1) return streak + 1;
  return 1;
}

// ---- 日替わりクエスト ----
enum DailyKind { weakSubject, pastExam, pomodoro, trueFalse }

/// 日付から日替わりクエストの種類を決める（毎日同じ結果になる）
DailyKind dailyKindFor(DateTime day) {
  final d = dateOnly(day);
  final n = d.difference(DateTime(2026, 1, 1)).inDays;
  return DailyKind.values[n % DailyKind.values.length];
}

/// 試験日までの日数（当日は0）
int daysUntil(DateTime exam, DateTime now) {
  final d = dateOnly(exam).difference(dateOnly(now)).inDays;
  return d < 0 ? 0 : d;
}
