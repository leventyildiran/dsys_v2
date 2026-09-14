import 'package:flutter/material.dart';

import 'app_colors.dart';

/// DSYS tema yapılandırması.
///
/// Tüm renkler [`AppColors`](app_colors.dart) tokenlarından gelir; burada ham
/// `Color(0x...)` yazılmaz. Böylece tek yerden renk değiştirilebilir ve
/// "tek anlam = tek renk" ilkesi korunur. Kurallar: [`RENK_SISTEMI.md`](../../../RENK_SISTEMI.md:1).
class AppTheme {
  AppTheme._();

  // --- Geriye dönük uyumluluk kısayolları (mevcut ekranlar kullanıyor) -------
  static const Color sidebarColor = AppColors.sidebar;
  static const Color backgroundColor = AppColors.background;
  static const Color primaryColor = AppColors.primary;
  static const Color white = AppColors.white;

  // --- Anlamsal kısayollar (yeni kodda doğrudan AppColors de kullanılabilir) -
  static const Color surfaceColor = AppColors.surface;
  static const Color borderColor = AppColors.border;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textMuted = AppColors.textMuted;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color danger = AppColors.danger;
  static const Color info = AppColors.info;

  static const double _radius = 8;
  static BorderRadius get _radiusAll => BorderRadius.circular(_radius);

  /// Uygulamanın açık teması.
  static ThemeData get lightTheme {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.textOnDark,
      primaryContainer: AppColors.primarySubtle,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.actionSecondary,
      onSecondary: AppColors.textOnDark,
      secondaryContainer: AppColors.neutralSubtle,
      onSecondaryContainer: AppColors.textPrimary,
      error: AppColors.danger,
      onError: AppColors.textOnDark,
      errorContainer: AppColors.dangerSubtle,
      onErrorContainer: AppColors.danger,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderStrong,
      shadow: AppColors.shadow,
      scrim: AppColors.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Roboto', 'Segoe UI', 'Arial', 'sans-serif'],
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      dividerColor: AppColors.border,
      splashColor: AppColors.primarySubtle,
      highlightColor: AppColors.primarySubtle,
      disabledColor: AppColors.disabled,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
        titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: AppColors.textSecondary),
        labelSmall: TextStyle(color: AppColors.textMuted),
      ),
    );

    return base.copyWith(
      // --- Üst bar ---------------------------------------------------------
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),

      // --- Girdi alanları --------------------------------------------------
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: AppColors.primary, fontSize: 14),
        helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: _radiusAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radiusAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radiusAll,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _radiusAll,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: _radiusAll,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),

      // --- Butonlar (eylem rehberliği) ------------------------------------
      // Birincil eylem → marka rengi.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.actionPrimary,
          foregroundColor: AppColors.textOnDark,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: _radiusAll),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      // Yükseltilmiş birincil eylem.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.actionPrimary,
          foregroundColor: AppColors.textOnDark,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: _radiusAll),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      // İkincil eylem → nötr çerçeve.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: _radiusAll),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      // Üçüncül/metin eylemi.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: _radiusAll),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),

      // --- Yüzeyler --------------------------------------------------------
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        selectedColor: AppColors.primary,
        selectedTileColor: AppColors.primarySubtle,
      ),

      // --- Tablolar --------------------------------------------------------
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceVariant),
        headingTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
        dataTextStyle: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        dividerThickness: 1,
        decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // --- Sekmeler & çipler ----------------------------------------------
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.border,
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutralSubtle,
        selectedColor: AppColors.primarySubtle,
        checkmarkColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // --- Bildirim / ilerleme --------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: AppColors.textOnDark, fontSize: 14),
        actionTextColor: AppColors.textOnDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceVariant,
        circularTrackColor: AppColors.surfaceVariant,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: AppColors.textOnDark, fontSize: 12),
      ),
    );
  }
}
