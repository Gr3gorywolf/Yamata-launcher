import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:yamata_launcher/app_theme_dark.dart';

const Color grayBorderColorLight = Color(0xFFE3E7E7);

const Color backgroundColorLight = Color(0xFFF7FAF8);
const Color surfaceColorLight = Color(0xFFFFFFFF);
const Color inverseSurfaceColorLight = Color(0xFFF0F4F2);

const Color primaryGreen = Color(0xFF66bb6a);
const Color secondaryGreen = Color(0xFF27AE60);
const Color mutedGreenLight = Color(0xFFDFF3E6);

const Color textPrimaryLight = Color(0xFF0B0F10);
const Color textSecondaryLight = Color(0xFF5D7267);

ThemeData appThemeLight = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  scaffoldBackgroundColor: backgroundColorLight,
  extensions: [
    SkeletonizerConfigData(
      containersColor: Colors.grey[200]!,
      ignoreContainers: false,
      enableSwitchAnimation: true,
      justifyMultiLineText: true,
      effect: PulseEffect(
        duration: const Duration(milliseconds: 1500),
        from: Colors.grey[300]!,
        to: Colors.grey[200]!,
      ),
    ),
  ],
  colorScheme: const ColorScheme.light(
    primary: primaryGreen,
    secondary: secondaryGreen,
    surface: surfaceColorLight,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: textPrimaryLight,
    inverseSurface: inverseSurfaceColorLight,
    outlineVariant: grayBorderColorLight,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: backgroundColorLight,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: textPrimaryLight,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: textPrimaryLight),
  ),
  cardTheme: CardThemeData(
    color: surfaceColorLight,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: grayBorderColorLight),
    ),
  ),
  iconTheme: const IconThemeData(
    color: primaryGreen,
    size: 24,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: textPrimaryLight,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textPrimaryLight,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: textSecondaryLight,
    ),
    labelLarge: TextStyle(
      fontSize: 12,
      letterSpacing: 1.2,
      fontWeight: FontWeight.bold,
      color: secondaryGreen,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: inverseSurfaceColorLight,
    helperStyle: TextStyle(color: Colors.grey[600]),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    hintStyle: TextStyle(
      color: textSecondaryLight.withOpacity(0.7),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: surfaceColorLight,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: const TextStyle(
      color: textPrimaryLight,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: grayBorderColorLight),
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: surfaceColorLight,
    selectedItemColor: primaryGreen,
    unselectedItemColor: textSecondaryLight,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: primaryGreen,
    foregroundColor: Colors.white,
    shape: StadiumBorder(),
  ),
  badgeTheme: const BadgeThemeData(
    backgroundColor: primaryGreen,
    textColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    largeSize: 26,
    smallSize: 20,
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      elevation: WidgetStateProperty.all(0),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      side: WidgetStateProperty.all(BorderSide.none),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryGreen.withOpacity(0.15);
        }
        return surfaceColorLight;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryGreen;
        }
        return textPrimaryLight.withOpacity(0.5);
      }),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
    ),
  ),
);
