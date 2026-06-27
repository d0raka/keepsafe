import 'package:flutter/material.dart';

/// Apple-flavoured theme: San Francisco system font, iOS system-blue accent,
/// system grouped backgrounds, rounded controls, hairline dividers, and no
/// Material ripples (Apple UIs use a subtle highlight instead).
class AppTheme {
  AppTheme._();

  // iOS system blue.
  static const Color accent = Color(0xFF007AFF);
  static const Color accentDark = Color(0xFF0A84FF);
  // iOS system green (toggles).
  static const Color toggleGreen = Color(0xFF34C759);

  // systemGroupedBackground / secondarySystemGroupedBackground.
  static const Color groupedBgLight = Color(0xFFF2F2F7);
  static const Color groupedBgDark = Color(0xFF000000);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1C1C1E);

  // Apple resolves these dot-prefixed names to San Francisco on its platforms.
  static const String fontText = '.SF Pro Text';
  static const String fontDisplay = '.SF Pro Display';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final accentColor = isDark ? accentDark : accent;
    final scaffold = isDark ? groupedBgDark : groupedBgLight;
    final card = isDark ? cardDark : cardLight;
    final onBg = isDark ? Colors.white : Colors.black;

    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
    ).copyWith(primary: accentColor, surface: card);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: fontText,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        foregroundColor: onBg,
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: onBg,
          letterSpacing: -0.5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontFamily: fontText, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          textStyle: const TextStyle(
              fontFamily: fontText, fontSize: 17, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 2)),
        floatingLabelStyle: TextStyle(color: accentColor),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? toggleGreen
                : (isDark ? const Color(0xFF39393D) : const Color(0xFFE9E9EA))),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
        thickness: 0.5,
        space: 0.5,
      ),
      cardColor: card,
    );
  }
}

/// iOS-style inset grouped section: a rounded card holding [children] separated
/// by hairline insets, with an optional uppercase [header] above it.
class InsetSection extends StatelessWidget {
  const InsetSection({super.key, this.header, required this.children});

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 7),
            child: Text(
              header!.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
                letterSpacing: -0.1,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Divider(),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
