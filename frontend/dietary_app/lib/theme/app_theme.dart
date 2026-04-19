import 'dart:math' show pi;
import 'package:flutter/material.dart';

// ── 调色板 ──────────────────────────────────────────────
class AppColors {
  // 背景
  static const bg = Color(0xFFFFF8F0);          // 奶油白
  static const bgCard = Color(0xFFFFFDF7);       // 卡片底色

  // 主色
  static const primary = Color(0xFFFF8C69);      // 蜜桃橙
  static const primaryLight = Color(0xFFFFB899); // 浅蜜桃
  static const primarySoft = Color(0xFFFFE8DF);  // 极浅蜜桃

  // 辅色
  static const green = Color(0xFF7DC87A);        // 嫩草绿
  static const greenLight = Color(0xFFB8E6B5);   // 浅草绿
  static const greenSoft = Color(0xFFE8F7E7);    // 极浅草绿

  static const yellow = Color(0xFFFFD166);       // 黄油黄
  static const yellowSoft = Color(0xFFFFF3CC);   // 极浅黄

  static const lavender = Color(0xFFC9B8E8);     // 薰衣草紫
  static const lavenderSoft = Color(0xFFF0EBFA); // 极浅紫

  static const blue = Color(0xFF8EC5E6);         // 天空蓝
  static const blueSoft = Color(0xFFE3F3FB);     // 极浅蓝

  // 文字
  static const textDark = Color(0xFF3D2C1E);     // 深棕
  static const textMid = Color(0xFF7A5C44);      // 中棕
  static const textLight = Color(0xFFB08060);    // 浅棕

  // 边框
  static const border = Color(0xFFE8D5C0);       // 暖米边框

  // 阴影 — 真正的clay立体感
  static const shadowOuter = Color(0x44C8956C);  // 右下暗阴影（加深）
  static const shadowDark = Color(0x55A0704A);   // 深色阴影
  static const shadowLight = Color(0xCCFFFFFF);  // 左上白色高光
}

// ── Clay BoxShadow 工具 ──────────────────────────────────
class ClayShadow {
  /// 标准凸起clay阴影：右下暗 + 左上亮
  static List<BoxShadow> raised({
    Color darkColor = const Color(0x55C8956C),
    Color lightColor = const Color(0xBBFFFFFF),
    double depth = 1.0,
  }) => [
    BoxShadow(color: darkColor, blurRadius: 10 * depth, offset: Offset(4 * depth, 5 * depth)),
    BoxShadow(color: lightColor, blurRadius: 6 * depth, offset: Offset(-3 * depth, -3 * depth)),
  ];

  /// 按下状态：阴影缩小
  static List<BoxShadow> pressed({
    Color darkColor = const Color(0x55C8956C),
    Color lightColor = const Color(0xBBFFFFFF),
  }) => [
    BoxShadow(color: darkColor, blurRadius: 4, offset: const Offset(2, 2)),
    BoxShadow(color: lightColor, blurRadius: 3, offset: const Offset(-1, -1)),
  ];

  /// 主色按钮阴影
  static List<BoxShadow> primaryBtn() => [
    BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 10, offset: const Offset(3, 5)),
    const BoxShadow(color: Color(0xAAFFFFFF), blurRadius: 6, offset: Offset(-2, -2)),
  ];

  /// 绿色按钮阴影
  static List<BoxShadow> greenBtn() => [
    BoxShadow(color: AppColors.green.withOpacity(0.4), blurRadius: 10, offset: const Offset(3, 5)),
    const BoxShadow(color: Color(0xAAFFFFFF), blurRadius: 6, offset: Offset(-2, -2)),
  ];
}

// ── Clay 卡片 Widget ─────────────────────────────────────
/// 真正有立体感的Clay卡片：厚边框 + 双向阴影 + 顶部光泽overlay
class ClayCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow>? shadows;

  const ClayCard({
    super.key,
    required this.child,
    this.color = AppColors.bgCard,
    this.borderColor = AppColors.border,
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: shadows ?? ClayShadow.raised(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 3),
        child: Stack(children: [
          Padding(padding: padding, child: child),
          // 顶部光泽overlay — 模拟内高光
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: radius * 1.2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.45),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 可按压的Clay按钮 — 按下时阴影缩小模拟下陷
class ClayButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow>? shadows;

  const ClayButton({
    super.key,
    required this.child,
    this.onTap,
    this.color = AppColors.primary,
    this.borderColor = const Color(0xFFE06040),
    this.radius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.shadows,
  });

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          _pressed ? 2 : 0,
          _pressed ? 3 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: widget.onTap == null ? AppColors.border : widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: widget.borderColor, width: 3),
          boxShadow: _pressed
              ? ClayShadow.pressed()
              : (widget.shadows ?? ClayShadow.primaryBtn()),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius - 3),
          child: Stack(children: [
            Padding(padding: widget.padding, child: widget.child),
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: widget.radius,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.35),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── 主题 ─────────────────────────────────────────────────
class AppTheme {
  static ThemeData build() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.textDark,
      secondary: AppColors.green,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.greenSoft,
      onSecondaryContainer: AppColors.textDark,
      tertiary: AppColors.yellow,
      onTertiary: AppColors.textDark,
      tertiaryContainer: AppColors.yellowSoft,
      onTertiaryContainer: AppColors.textDark,
      error: Color(0xFFE57373),
      onError: Colors.white,
      errorContainer: Color(0xFFFFEBEE),
      onErrorContainer: Color(0xFFB71C1C),
      surface: AppColors.bg,
      onSurface: AppColors.textDark,
      surfaceContainerHighest: AppColors.bgCard,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textDark,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'LXGWWenKai',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          letterSpacing: 0.5,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 2),
        ),
        shadowColor: AppColors.shadowOuter,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textMid),
        hintStyle: const TextStyle(color: AppColors.textLight),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE06040), width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        indicatorColor: AppColors.primarySoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textLight, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 11,
            color: AppColors.textLight,
          );
        }),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primarySoft,
        labelStyle: const TextStyle(color: AppColors.textDark, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1.5,
        space: 24,
      ),

      // Text
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.3, fontFamily: 'LXGWWenKai'),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark, height: 1.3, fontFamily: 'LXGWWenKai'),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark, height: 1.4, fontFamily: 'LXGWWenKai'),
        titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark, fontFamily: 'LXGWWenKai'),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark, fontFamily: 'LXGWWenKai'),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMid, fontFamily: 'LXGWWenKai'),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textDark, height: 1.6, fontFamily: 'LXGWWenKai'),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textMid, height: 1.5, fontFamily: 'LXGWWenKai'),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textLight, height: 1.5, fontFamily: 'LXGWWenKai'),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark, fontFamily: 'LXGWWenKai'),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMid, fontFamily: 'LXGWWenKai'),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textLight, fontFamily: 'LXGWWenKai'),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 手绘风格 (Sketch / Hand-drawn Style)
// ══════════════════════════════════════════════════════════════

/// 手绘风配色 — 严格对标 HTML 设计稿
class SketchColors {
  static const bg = Color(0xFFFDFAF1);           // --bg-base 暖米色纸张
  static const bgNav = Color(0xFFFFFEF0);         // 底栏底色
  static const lineBrown = Color(0xFF8D6E63);      // --line-brown 核心棕色线条
  static const pinkLight = Color(0xFFFFF5F6);      // --pink-super-light
  static const greenLight = Color(0xFFF5FAF5);     // --green-super-light
  static const textMain = Color(0xFF5D4037);        // --text-main
  static const accentSoft = Color(0xFFFFDAB9);      // --accent-soft
  static const dotColor = Color(0xFFE5E0D0);        // 背景点阵色
}

/// 虚线边框画笔 — 3px dashed brown + 不规则圆角
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final BorderRadius borderRadius;

  const DashedBorderPainter({
    this.color = const Color(0xFF8D6E63),
    this.strokeWidth = 3.0,
    this.dashWidth = 8.0,
    this.dashSpace = 5.0,
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.elliptical(40, 20),
      topRight: Radius.elliptical(15, 50),
      bottomRight: Radius.elliptical(50, 15),
      bottomLeft: Radius.elliptical(20, 40),
    ),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = borderRadius.toRRect(Offset.zero & size);
    final path = Path()..addRRect(rrect);

    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        dashedPath.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      color != old.color || borderRadius != old.borderRadius;
}

/// 手绘风卡片 — 虚线边框 + 不规则圆角 + 微倾斜 + 偏移阴影
class HandDrawnCard extends StatefulWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double rotation;      // degrees, 默认状态角度
  final double hoverRotation; // degrees, hover 时角度
  final BorderRadius? borderRadius;

  const HandDrawnCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(25),
    this.rotation = 0,
    this.hoverRotation = 0,
    this.borderRadius,
  });

  @override
  State<HandDrawnCard> createState() => _HandDrawnCardState();
}

class _HandDrawnCardState extends State<HandDrawnCard> {
  bool _hovered = false;

  static const _defaultRadius = BorderRadius.only(
    topLeft: Radius.elliptical(40, 20),
    topRight: Radius.elliptical(15, 50),
    bottomRight: Radius.elliptical(50, 15),
    bottomLeft: Radius.elliptical(20, 40),
  );

  @override
  Widget build(BuildContext context) {
    final br = widget.borderRadius ?? _defaultRadius;
    final angle = _hovered
        ? widget.hoverRotation * pi / 180
        : widget.rotation * pi / 180;
    final scale = _hovered ? 1.02 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        transform: Matrix4.identity()
          ..scale(scale, scale)
          ..rotateZ(angle),
        transformAlignment: Alignment.center,
        child: CustomPaint(
          foregroundPainter: DashedBorderPainter(borderRadius: br),
          child: Container(
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: br,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A8D6E63), // rgba(141,110,99,0.1)
                  offset: Offset(10, 10),
                  blurRadius: 0,
                ),
              ],
            ),
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 果冻动效按钮 — jelly-anim + 点击位移反馈
class JellyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const JellyButton({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<JellyButton> createState() => _JellyButtonState();
}

class _JellyButtonState extends State<JellyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          double sx = 1.0, sy = 1.0;
          if (!_pressed && widget.onTap != null) {
            final t = _ctrl.value;
            if (t < 0.3) {
              final p = t / 0.3;
              sx = 1.0 + 0.1 * p;
              sy = 1.0 - 0.1 * p;
            } else if (t < 0.4) {
              final p = (t - 0.3) / 0.1;
              sx = 1.1 - 0.2 * p;
              sy = 0.9 + 0.2 * p;
            } else if (t < 0.5) {
              final p = (t - 0.4) / 0.1;
              sx = 0.9 + 0.15 * p;
              sy = 1.1 - 0.15 * p;
            } else {
              final p = (t - 0.5) / 0.5;
              sx = 1.05 - 0.05 * p;
              sy = 0.95 + 0.05 * p;
            }
          }
          return AnimatedOpacity(
            opacity: widget.onTap == null ? 0.5 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Transform(
              transform: Matrix4.identity()
                ..translate(_pressed ? 4.0 : 0.0, _pressed ? 4.0 : 0.0)
                ..scale(sx, sy),
              alignment: Alignment.center,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border.all(color: SketchColors.lineBrown, width: 3),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: SketchColors.lineBrown,
                      offset:
                          _pressed ? const Offset(1, 1) : const Offset(5, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
        child: DefaultTextStyle(
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: SketchColors.lineBrown,
            fontFamily: 'LXGWWenKai',
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 平滑波浪裁剪器 — 用于底部导航栏顶部
class PaperTearClipper extends CustomClipper<Path> {
  const PaperTearClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    const waveH = 12.0;
    const baseY = waveH;
    const numWaves = 8;
    final segW = size.width / (numWaves * 2);

    path.moveTo(0, baseY);
    for (int i = 0; i < numWaves * 2; i++) {
      path.quadraticBezierTo(
        segW * i + segW / 2,
        i.isEven ? 0.0 : baseY * 2,
        segW * (i + 1),
        baseY,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 平滑波浪线画笔 — 绘制底栏顶部棕色波浪线
class ZigzagLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SketchColors.lineBrown
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const waveH = 12.0;
    const baseY = waveH;
    const numWaves = 8;
    final segW = size.width / (numWaves * 2);

    final path = Path()..moveTo(0, baseY);
    for (int i = 0; i < numWaves * 2; i++) {
      path.quadraticBezierTo(
        segW * i + segW / 2,
        i.isEven ? 0.0 : baseY * 2,
        segW * (i + 1),
        baseY,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 纸张纹理背景点阵 — radial-gradient(#e5e0d0 1px, transparent 1px) 24px
class PaperDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SketchColors.dotColor
      ..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
