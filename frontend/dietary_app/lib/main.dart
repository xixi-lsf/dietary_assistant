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
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _ClayNavBar(
        selectedIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _ClayNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _ClayNavBar({required this.selectedIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: '首页'),
    _NavItem(icon: Icons.kitchen_rounded, label: '冰箱'),
    _NavItem(icon: Icons.celebration_rounded, label: '宴请'),
    _NavItem(icon: Icons.bar_chart_rounded, label: '营养'),
    _NavItem(icon: Icons.chat_bubble_rounded, label: '管家'),
    _NavItem(icon: Icons.psychology_rounded, label: '记忆'),
    _NavItem(icon: Icons.settings_rounded, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowOuter,
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final selected = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          width: selected ? 44 : 36,
                          height: selected ? 32 : 28,
                          decoration: selected
                              ? BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.primaryLight, width: 1.5),
                                )
                              : null,
                          child: Icon(
                            _items[i].icon,
                            size: selected ? 22 : 20,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textLight,
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
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
