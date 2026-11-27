import 'package:flutter/material.dart';

class Subject {
  final String id;
  final String name;
  final String short;
  final String monster;
  final Color color;
  final int exam; // 1 = 1次, 2 = 2次
  final int pastExamQuestions; // 過去問記録用の問題数（目安）
  const Subject(this.id, this.name, this.short, this.monster, this.color, this.exam, [this.pastExamQuestions = 0]);
}

const subjects = <Subject>[
  Subject('eco', '経済学・経済政策', '経済', '需給の霧', Color(0xFF9AD0FF), 1, 25),
  Subject('fin', '財務・会計', '財務', '簿記ゴーレム', Color(0xFFC9A26B), 1, 25),
  Subject('mgt', '企業経営理論', '企業経営', '戦略の亡霊', Color(0xFFB48CFF), 1, 40),
  Subject('ops', '運営管理', '運営', '在庫スライム', Color(0xFF7EE08A), 1, 45),
  Subject('law', '経営法務', '法務', '条文ナイト', Color(0xFFFF9F6B), 1, 25),
  Subject('it', '経営情報システム', '情報', 'バグ蝙蝠', Color(0xFF6BD3C9), 1, 25),
  Subject('sme', '中小企業経営・政策', '中小', '白書の番人', Color(0xFFF2C14E), 1, 40),
  Subject('c1', '事例I 組織・人事', '事例I', '組織の迷宮', Color(0xFFE58CC0), 2),
  Subject('c2', '事例II マーケティング', '事例II', '売場の魔女', Color(0xFFFF7AA8), 2),
  Subject('c3', '事例III 生産・技術', '事例III', '工程の竜', Color(0xFFFF6B6B), 2),
  Subject('c4', '事例IV 財務・会計', '事例IV', 'CF竜王', Color(0xFFF2C14E), 2),
];

Subject subjectById(String id) => subjects.firstWhere((s) => s.id == id);

/// 過去問の記録対象年度（新しい順）
const pastExamYears = ['R7', 'R6', 'R5', 'R4', 'R3'];
