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

  // 阴影
  static const shadowOuter = Color(0x33C8956C);  // 外阴影（暖棕）
  static const shadowInner = Color(0x1AFFFFFF);  // 内高光
}

// ── Clay 卡片装饰 ────────────────────────────────────────
class ClayDecoration extends Decoration {
  final Color color;
  final double radius;
  final Color borderColor;

  const ClayDecoration({
    this.color = AppColors.bgCard,
    this.radius = 20,
    this.borderColor = AppColors.border,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _ClayPainter(color: color, radius: radius, borderColor: borderColor);
  }
}

class _ClayPainter extends BoxPainter {
  final Color color;
  final double radius;
  final Color borderColor;

  _ClayPainter({required this.color, required this.radius, required this.borderColor});

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size ?? Size.zero;
    final rect = offset & size;
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 外阴影
    final shadowPaint = Paint()
      ..color = AppColors.shadowOuter
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rRect.shift(const Offset(3, 4)), shadowPaint);

    // 卡片底色
    final fillPaint = Paint()..color = color;
    canvas.drawRRect(rRect, fillPaint);

    // 边框
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rRect, borderPaint);

    // 内高光
    final highlightPaint = Paint()
      ..color = AppColors.shadowInner
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final innerRRect = RRect.fromRectAndRadius(
      rect.deflate(1),
      Radius.circular(radius - 1),
    );
    canvas.drawRRect(innerRRect, highlightPaint);
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
          fontFamily: 'serif',
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
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.3),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark, height: 1.3),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark, height: 1.4),
        titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMid),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textDark, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textMid, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textLight, height: 1.5),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMid),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textLight),
      ),
    );
  }
}
