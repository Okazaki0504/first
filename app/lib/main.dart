import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/question.dart';
import 'services/notifications.dart';
import 'state/game_state.dart';
import 'ui/battle_screen.dart';
import 'ui/screens.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bank = await QuestionBank.load(rootBundle);
  final g = GameState(prefs, bank);
  Haptics.enabled = g.vibration;
  runApp(ShindanApp(g));
  if (g.onboarded) {
    DailyNotifier.schedule(on: g.notifOn, hour: g.notifHour, minute: g.notifMinute, streak: g.streak);
  }
}

class ShindanApp extends StatelessWidget {
  final GameState g;
  const ShindanApp(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '中小企業診断士 学習アプリ',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ListenableBuilder(
        listenable: g,
        builder: (context, _) => g.onboarded ? RootScreen(g) : OnboardingScreen(g, onDone: _afterOnboarding),
      ),
    );
  }

  void _afterOnboarding() =>
      DailyNotifier.schedule(on: g.notifOn, hour: g.notifHour, minute: g.notifMinute, streak: g.streak);
}

class RootScreen extends StatefulWidget {
  final GameState g;
  const RootScreen(this.g, {super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 日付をまたいで復帰したときに表示を更新
    if (state == AppLifecycleState.resumed) {
      widget.g.battleResume();
      widget.g.updateSettings((_) {});
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      widget.g.battlePause(); // アプリを閉じている間は学習時間に数えない
    }
  }

  static const _tabs = [
    (Icons.home_outlined, '拠点'),
    (Icons.sports_martial_arts_outlined, 'バトル'),
    (Icons.timer_outlined, '修行'),
    (Icons.bar_chart, '記録'),
    (Icons.menu_book_outlined, '冒険の書'),
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final pages = [
      HomeTab(g),
      BattleTab(g),
      TrainTab(g),
      LogTab(g),
      BookTab(g, onReplayIntro: () => g.updateSettings((s) => s.onboarded = false)),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: tab,
          children: [
            for (final p in pages)
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: p))],
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: C.deeper, border: Border(top: BorderSide(color: C.line, width: 3))),
        child: SafeArea(
          top: false,
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () {
                    Haptics.light();
                    // バトルタブを離れたら、たまった学習時間を記録する
                    if (tab == 1 && i != 1) showReward(context, g.flushBattleStudy(), g);
                    if (i == 1 && tab != 1) g.battleEnter();
                    setState(() => tab = i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_tabs[i].$1, color: tab == i ? C.gold : C.muted, size: 22),
                      const SizedBox(height: 2),
                      Text(_tabs[i].$2, style: px(11, color: tab == i ? C.gold : C.muted)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
