import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _primaryColor = Color(0xFF1565C0);
const Color _secondaryColor = Color(0xFF00897B);
const Color _errorColor = Color(0xFFD32F2F);
const Color _lightSurface = Colors.white;
const Color _darkSurface = Color(0xFF121212);

ThemeData lightTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _primaryColor,
    onPrimary: Colors.white,
    secondary: _secondaryColor,
    onSecondary: Colors.white,
    error: _errorColor,
    onError: Colors.white,
    surface: _lightSurface,
    onSurface: Color(0xFF1A1C1E),
    tertiary: Color(0xFF5E35B1),
    onTertiary: Colors.white,
    primaryContainer: Color(0xFFD6E4FF),
    onPrimaryContainer: Color(0xFF001C3B),
    secondaryContainer: Color(0xFFB7F1E8),
    onSecondaryContainer: Color(0xFF00201D),
    tertiaryContainer: Color(0xFFE8DDFF),
    onTertiaryContainer: Color(0xFF1E1040),
    surfaceContainerHighest: Color(0xFFE1E3E6),
    onSurfaceVariant: Color(0xFF43474C),
    outline: Color(0xFF74777F),
    outlineVariant: Color(0xFFC4C7CF),
    shadow: Color(0x33000000),
    scrim: Color(0x66000000),
    inverseSurface: Color(0xFF2F3033),
    onInverseSurface: Color(0xFFF0F0F3),
    inversePrimary: Color(0xFFA8C7FF),
    surfaceTint: _primaryColor,
  );

  return _buildTheme(colorScheme);
}

ThemeData darkTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA8C7FF),
    onPrimary: Color(0xFF003061),
    secondary: Color(0xFF7BD5C8),
    onSecondary: Color(0xFF003731),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    surface: _darkSurface,
    onSurface: Color(0xFFE3E3E6),
    tertiary: Color(0xFFD0BCFF),
    onTertiary: Color(0xFF37275A),
    primaryContainer: Color(0xFF00468A),
    onPrimaryContainer: Color(0xFFD6E4FF),
    secondaryContainer: Color(0xFF005049),
    onSecondaryContainer: Color(0xFFB7F1E8),
    tertiaryContainer: Color(0xFF4F3F73),
    onTertiaryContainer: Color(0xFFE8DDFF),
    surfaceContainerHighest: Color(0xFF44474E),
    onSurfaceVariant: Color(0xFFC4C7CF),
    outline: Color(0xFF8E9099),
    outlineVariant: Color(0xFF43474C),
    shadow: Colors.black,
    scrim: Color(0xB3000000),
    inverseSurface: Color(0xFFE3E3E6),
    onInverseSurface: Color(0xFF2F3033),
    inversePrimary: _primaryColor,
    surfaceTint: Color(0xFFA8C7FF),
  );

  return _buildTheme(colorScheme);
}

ThemeData _buildTheme(ColorScheme colorScheme) {
  const radius8 = BorderRadius.all(Radius.circular(8));
  const radius12 = BorderRadius.all(Radius.circular(12));

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: const CardThemeData(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius12),
      shadowColor: Color(0x1A000000),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const RoundedRectangleBorder(borderRadius: radius8),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const RoundedRectangleBorder(borderRadius: radius8),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: const OutlineInputBorder(
        borderRadius: radius8,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radius8,
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius8,
        borderSide: BorderSide.none,
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: radius8,
        borderSide: BorderSide.none,
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: radius8,
        borderSide: BorderSide.none,
      ),
      fillColor: colorScheme.brightness == Brightness.dark
          ? const Color(0xFF1F1F1F)
          : const Color(0xFFF3F5F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    textTheme: base.textTheme.copyWith(
      displayLarge: GoogleFonts.poppins(textStyle: base.textTheme.displayLarge),
      displayMedium: GoogleFonts.poppins(textStyle: base.textTheme.displayMedium),
      displaySmall: GoogleFonts.poppins(textStyle: base.textTheme.displaySmall),
      headlineLarge: GoogleFonts.poppins(textStyle: base.textTheme.headlineLarge),
      headlineMedium: GoogleFonts.poppins(textStyle: base.textTheme.headlineMedium),
      headlineSmall: GoogleFonts.poppins(textStyle: base.textTheme.headlineSmall),
      titleLarge: GoogleFonts.poppins(textStyle: base.textTheme.titleLarge),
      titleMedium: GoogleFonts.poppins(textStyle: base.textTheme.titleMedium),
      titleSmall: GoogleFonts.poppins(textStyle: base.textTheme.titleSmall),
    ),
  );
}

final ThemeData appLightTheme = lightTheme();
final ThemeData appDarkTheme = darkTheme();
