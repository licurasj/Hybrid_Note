import 'package:flutter/material.dart';

import '../app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      fontFamily: 'Segoe UI',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.logoBlue,
        brightness: Brightness.light,
        primary: AppColors.actionBlue,
        onPrimary: Colors.white,
        primaryContainer: AppColors.selectedBlue,
        onPrimaryContainer: AppColors.darkBlue,
        surface: Colors.white,
        onSurface: AppColors.darkBlue,
      ),
      scaffoldBackgroundColor: AppColors.softBackground,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkBlue),
        bodyMedium: TextStyle(color: AppColors.darkBlue),
        bodySmall: TextStyle(color: AppColors.mutedText),
        titleLarge: TextStyle(color: AppColors.darkBlue),
        titleMedium: TextStyle(color: AppColors.darkBlue),
        titleSmall: TextStyle(color: AppColors.darkBlue),
        labelLarge: TextStyle(color: AppColors.darkBlue),
        labelMedium: TextStyle(color: AppColors.darkBlue),
        labelSmall: TextStyle(color: AppColors.mutedText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkBlue,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkBlue,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: 'Segoe UI',
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.actionBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.actionBlue,
          side: const BorderSide(
            color: AppColors.actionBlue,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: AppColors.actionBlue,
            width: 2,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.selectedBlue,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderBlue,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      fontFamily: 'Segoe UI',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.logoBlue,
        brightness: Brightness.dark,
        primary: AppColors.logoBlue,
        onPrimary: AppColors.darkBackground,
        primaryContainer: AppColors.darkSelectedBlue,
        onPrimaryContainer: AppColors.darkText,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkText),
        bodyMedium: TextStyle(color: AppColors.darkText),
        bodySmall: TextStyle(color: AppColors.darkMutedText),
        titleLarge: TextStyle(color: AppColors.darkText),
        titleMedium: TextStyle(color: AppColors.darkText),
        titleSmall: TextStyle(color: AppColors.darkText),
        labelLarge: TextStyle(color: AppColors.darkText),
        labelMedium: TextStyle(color: AppColors.darkText),
        labelSmall: TextStyle(color: AppColors.darkMutedText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkText,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: 'Segoe UI',
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.logoBlue,
          foregroundColor: AppColors.darkBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.logoBlue,
          side: const BorderSide(
            color: AppColors.logoBlue,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: AppColors.logoBlue,
            width: 2,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.darkSelectedBlue,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: AppColors.darkText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorderBlue,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkSurface,
      ),
      useMaterial3: true,
    );
  }
}
