import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  // ── Brand Colors ──
  static const Color _primaryLight = Color(0xFF0D47A1); // Deep blue
  static const Color _primaryDark = Color(0xFF42A5F5); // Sky blue

  // ── Semantic Colors ──
  static const Color success = Color(0xFF2E7D32);
  static const Color successDark = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningDark = Color(0xFFFFA726);
  static const Color info = Color(0xFF0288D1);
  static const Color infoDark = Color(0xFF4FC3F7);

  // ─────────────────────────── LIGHT THEME ───────────────────────────

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryLight,
      brightness: Brightness.light,
      primary: _primaryLight,
      onPrimary: Colors.white,
      secondary: const Color(0xFF1565C0),
      surface: const Color(0xFFF8F9FD),
      onSurface: const Color(0xFF1A1A2E),
      surfaceContainerHighest: const Color(0xFFEEF0F6),
      error: const Color(0xFFD32F2F),
      onError: Colors.white,
    );

    final textTheme = _buildTextTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
      ),

      // ── Input Fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(120),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Elevated Button ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Text Button ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Outlined Button ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // ── FAB ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withAlpha(80),
        thickness: 1,
      ),

      // ── ListTile ──
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── Icon ──
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // ── BottomSheet ──
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ── Drawer ──
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
        ),
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // ── PopupMenu ──
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  // ─────────────────────────── DARK THEME ───────────────────────────

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryDark,
      brightness: Brightness.dark,
      primary: _primaryDark,
      onPrimary: const Color(0xFF0A0E1A),
      secondary: const Color(0xFF64B5F6),
      surface: const Color(0xFF0A0E1A),
      onSurface: const Color(0xFFF0F0F8),
      surfaceContainerHighest: const Color(0xFF1A2035),
      error: const Color(0xFFEF5350),
      onError: const Color(0xFF1A0000),
    );

    final textTheme = _buildTextTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: const Color(0xFF111827),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(50)),
        ),
      ),

      // ── Input Fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A2035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Elevated Button ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Text Button ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Outlined Button ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // ── FAB ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withAlpha(50),
        thickness: 1,
      ),

      // ── ListTile ──
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── Icon ──
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // ── BottomSheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ── Drawer ──
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF0F1420),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
        ),
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1A2035),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(50)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // ── PopupMenu ──
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  // ─────────────────────────── TYPOGRAPHY ───────────────────────────

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w800,
        fontSize: 32,
      ),
      displayMedium: base.displayMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 28,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        letterSpacing: -0.3,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: colorScheme.onSurface,
        fontSize: 16,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontSize: 14,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontSize: 12,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}
