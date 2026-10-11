import 'package:flutter/material.dart';

/// Paleta de colores minimalista inspirada en "Apple Finance / Stocks".
class AppColors {
  // Fondos y superficies
  static const Color background = Color(0xFF000000); // Negro OLED absoluto
  static const Color cardSurface = Color(0xFF1C1C1E); // Gris oscuro de tarjetas iOS
  static const Color surfaceSecondary = Color(0xFF2C2C2E); // Superficie secundaria / hover
  static const Color cardBorder = Color(0xFF38383A); // Bordes sutiles

  // Acentos de mercado
  static const Color bullish = Color(0xFF30D158); // Verde alcista iOS
  static const Color bullishSoft = Color(0x2630D158); // Verde translúcido para badges
  static const Color bearish = Color(0xFFFF453A); // Rojo bajista iOS
  static const Color bearishSoft = Color(0x26FF453A); // Rojo translúcido para badges
  static const Color neutral = Color(0xFF8E8E93); // Gris neutral iOS
  static const Color neutralSoft = Color(0x268E8E93);

  // Tipografía y textos
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF636366);

  // Indicador de IA / Destello
  static const Color aiAccent = Color(0xFF0A84FF); // Azul Apple para IA / analítica
  static const Color aiAccentSoft = Color(0x1F0A84FF);
}
