import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import 'subjects.dart';

class Question {
  final String id;
  final String subject;
  final String topic;
  final int level;
  final bool isTrueFalse;
  final String text;
  final List<String> choices;
  final int answer;
  final String explanation;

  const Question({
    required this.id,
    required this.subject,
    required this.topic,
    required this.level,
    required this.isTrueFalse,
    required this.text,
    required this.choices,
    required this.answer,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'],
        subject: j['subject'],
        topic: j['topic'],
        level: j['level'],
        isTrueFalse: j['type'] == 'tf',
        text: j['question'],
        choices: List<String>.from(j['choices']),
        answer: j['answer'],
        explanation: j['explanation'],
      );

  /// 4択は選択肢の順番をシャッフルした問題を返す（○×はそのまま）
  Question shuffled(Random rnd) {
    if (isTrueFalse) return this;
    final order = List.generate(choices.length, (i) => i)..shuffle(rnd);
    return Question(
      id: id,
      subject: subject,
      topic: topic,
      level: level,
      isTrueFalse: false,
      text: text,
      choices: [for (final i in order) choices[i]],
      answer: order.indexOf(answer),
      explanation: explanation,
    );
  }
}

class QuestionBank {
  final Map<String, List<Question>> bySubject;
  final Map<String, Question> byId;
  QuestionBank(this.bySubject) : byId = {for (final l in bySubject.values) for (final q in l) q.id: q};

  List<Question> of(String subject) => bySubject[subject] ?? const [];
  bool has(String subject) => of(subject).isNotEmpty;
  int get total => byId.length;

  /// assets/questions/<科目>.json をすべて読み込む（ないファイルは空）
  static Future<QuestionBank> load(AssetBundle bundle) async {
    final map = <String, List<Question>>{};
    for (final s in subjects) {
      try {
        final raw = await bundle.loadString('assets/questions/${s.id}.json');
        map[s.id] = (jsonDecode(raw) as List).map((e) => Question.fromJson(e)).toList();
      } catch (_) {
        map[s.id] = [];
      }
    }
    return QuestionBank(map);
  }
}
