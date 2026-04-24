import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kNavyDeep = Color(0xFF1A237E);
const kNavyMid = Color(0xFF283593);
const kNavyLight = Color(0xFF3949AB);
const kCyan = Color(0xFF29B6F6);
const kCyanDark = Color(0xFF0288D1);
const kCyanLight = Color(0xFF4FC3F7);
const kSurface = Color(0xFFF0F7FF);
const kSafeGreen = Color(0xFF00C896);
const kCautionAmb = Color(0xFFFFB020);
const kDangerRed = Color(0xFFFF4D4D);

const kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kNavyDeep, kCyanDark, kCyan],
  stops: [0.0, 0.5, 1.0],
);

ThemeData get appLightTheme {
  final cs = ColorScheme.fromSeed(
    seedColor: kCyan,
    brightness: Brightness.light,
    primary: kCyan,
    onPrimary: Colors.white,
    secondary: kNavyDeep,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: const Color(0xFF0D1B3E),
    error: kDangerRed,
    onError: Colors.white,
    primaryContainer: const Color(0xFFE8F4FD),
    secondaryContainer: const Color(0xFFE8EAF6),
    tertiaryContainer: const Color(0xFFE0F7FA),
  );

  return _buildTheme(cs);
}

ThemeData get appDarkTheme {
  final cs = ColorScheme.fromSeed(
    seedColor: kCyan,
    brightness: Brightness.dark,
    primary: kCyanLight,
    onPrimary: kNavyDeep,
    secondary: kCyanLight,
    onSecondary: kNavyDeep,
    surface: const Color(0xFF0D1420),
    onSurface: const Color(0xFFE8F4FD),
    error: kDangerRed,
  );

  return _buildTheme(cs);
}

ThemeData _buildTheme(ColorScheme cs) {
  final isDark = cs.brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: isDark ? const Color(0xFF0D1420) : kSurface,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: kNavyDeep,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF131E30) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E2D45) : kCyan.withOpacity(0.08),
          width: 1,
        ),
      ),
      shadowColor: const Color(0x1A1A237E),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? const Color(0xFF1A2540) : Colors.white,
      selectedColor: kCyan,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: kCyan.withOpacity(0.25), width: 1.5),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return kCyanDark;
          if (states.contains(WidgetState.hovered)) return kCyanLight;
          return kCyan;
        }),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        elevation: WidgetStateProperty.all(0),
        shadowColor: WidgetStateProperty.all(kCyan.withOpacity(0.4)),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kCyan,
        side: const BorderSide(color: kCyan, width: 1.5),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A2540) : kSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: kCyan.withOpacity(0.15), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: kCyan.withOpacity(0.15), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kCyan, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kDangerRed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : const Color(0xFF718096),
        fontSize: 14,
        fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
      ),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.04,
        color: isDark ? kCyanLight : kNavyDeep,
      ),
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
      bodyMedium: GoogleFonts.spaceGrotesk(
        color: isDark ? const Color(0xFFE8F4FD) : const Color(0xFF4A5568),
      ),
      bodySmall: GoogleFonts.spaceGrotesk(
        color: isDark ? Colors.white54 : const Color(0xFF718096),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? Colors.white10 : kSurface,
      thickness: 1,
    ),
    extensions: const [AlMobarmgColors()],
  );
}

class AlMobarmgColors extends ThemeExtension<AlMobarmgColors> {
  const AlMobarmgColors();

  Color get scoreColorSafe => kSafeGreen;
  Color get scoreColorLow => kCyan;
  Color get scoreColorCaution => kCautionAmb;
  Color get scoreColorDanger => kDangerRed;
  LinearGradient get brandGradient => kBrandGradient;

  @override
  AlMobarmgColors copyWith() => const AlMobarmgColors();

  @override
  AlMobarmgColors lerp(covariant ThemeExtension<AlMobarmgColors>? other, double t) => this;
}

Color scoreColor(int score) {
  if (score >= 85) return kSafeGreen;
  if (score >= 65) return kCyan;
  if (score >= 45) return kCautionAmb;
  return kDangerRed;
}

String scoreLabel(int score) {
  if (score >= 85) return 'SAFE';
  if (score >= 65) return 'LOW RISK';
  if (score >= 45) return 'CAUTION';
  if (score >= 25) return 'RISKY';
  return 'DANGEROUS';
}

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.height = kToolbarHeight + 4,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: kBrandGradient,
        boxShadow: [
          BoxShadow(
            color: Color(0x331A237E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Expanded(
                child: centerTitle ? Center(child: _titleColumn()) : _titleColumn(),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
      ],
    );
  }
}
