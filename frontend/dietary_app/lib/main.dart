import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/banquet_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/fridge_screen.dart';
import 'screens/home_screen.dart';
import 'screens/memory_stats_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const DietaryApp());
}

class DietaryApp extends StatelessWidget {
  const DietaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '私人饮食助理',
      theme: AppTheme.build(),
      debugShowCheckedModeBanner: false,
      home: const MainShell(),
      builder: (context, child) => DefaultTextStyle(
        style: const TextStyle(fontFamily: 'LXGWWenKai'),
        child: child!,
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    FridgeScreen(),
    BanquetScreen(),
    NutritionScreen(),
    ChatScreen(),
    MemoryStatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SketchColors.bg,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _SketchNavBar(
        selectedIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// 手绘风底部导航栏 — 纸张撕裂感 + emoji 图标 + 不规则圆角
class _SketchNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _SketchNavBar({required this.selectedIndex, required this.onTap});

  static const _labels = ['首页', '冰箱', '宴请', '营养', '管家', '记忆', '设置'];
  static const _emojis = ['🏠', '❄️', '🥂', '📊', '🤖', '🧠', '⚙️'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Stack(
        children: [
          // 撕裂纸背景
          Positioned.fill(
            child: ClipPath(
              clipper: const PaperTearClipper(),
              child: Container(color: SketchColors.bgNav),
            ),
          ),
          // 顶部锯齿棕色边线
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: ZigzagLinePainter()),
            ),
          ),
          // 导航项
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Row(
                  children: List.generate(_labels.length, (i) {
                    final selected = i == selectedIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(i),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          transform: selected
                              ? (Matrix4.identity()..translate(0.0, -5.0))
                              : Matrix4.identity(),
                          transformAlignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // emoji 图标框 — 不规则圆角
                              AnimatedScale(
                                scale: selected ? 1.15 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFFD32F2F)
                                          : SketchColors.lineBrown,
                                      width: 2,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      topRight: Radius.circular(30),
                                      bottomRight: Radius.circular(15),
                                      bottomLeft: Radius.circular(25),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(_emojis[i],
                                        style: const TextStyle(fontSize: 14)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _labels[i],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'LXGWWenKai',
                                  color: selected
                                      ? const Color(0xFFD32F2F)
                                      : SketchColors.lineBrown,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
