import 'package:flutter/material.dart';

enum ColorThemeType {
  defaultTheme,
  ocean,
  forest,
  sunset,
  galaxy,
  ruby,
  emerald,
  coral,
}

class ColorThemeData {
  final String nameKey;
  final String descriptionKey;
  final Color primaryLight;
  final Color primaryDark;
  final Color accentLight;
  final Color accentDark;
  final Color backgroundLight;
  final Color backgroundDark;
  final Color cardLight;
  final Color cardDark;

  const ColorThemeData({
    required this.nameKey,
    required this.descriptionKey,
    required this.primaryLight,
    required this.primaryDark,
    required this.accentLight,
    required this.accentDark,
    required this.backgroundLight,
    required this.backgroundDark,
    required this.cardLight,
    required this.cardDark,
  });
}

class ColorThemes {
  static const Map<ColorThemeType, ColorThemeData> themes = {
    ColorThemeType.defaultTheme: ColorThemeData(
      nameKey: 'theme.default.name',
      descriptionKey: 'theme.default.description',
      primaryLight: Color(0xFF0ea5e9),
      primaryDark: Color(0xFF38bdf8),
      accentLight: Color(0xFF06b6d4),
      accentDark: Color(0xFF22d3ee),
      backgroundLight: Color(0xFFffffff),
      backgroundDark: Color(0xFF0f172a),
      cardLight: Color(0xFFf8fafc),
      cardDark: Color(0xFF1e293b),
    ),
    ColorThemeType.ocean: ColorThemeData(
      nameKey: 'theme.ocean.name',
      descriptionKey: 'theme.ocean.description',
      primaryLight: Color(0xFF0369a1),
      primaryDark: Color(0xFF0ea5e9),
      accentLight: Color(0xFF0891b2),
      accentDark: Color(0xFF22d3ee),
      backgroundLight: Color(0xFFf0f9ff),
      backgroundDark: Color(0xFF0c1929),
      cardLight: Color(0xFFe0f2fe),
      cardDark: Color(0xFF1e3a5f),
    ),
    ColorThemeType.forest: ColorThemeData(
      nameKey: 'theme.forest.name',
      descriptionKey: 'theme.forest.description',
      primaryLight: Color(0xFF166534),
      primaryDark: Color(0xFF22c55e),
      accentLight: Color(0xFF059669),
      accentDark: Color(0xFF34d399),
      backgroundLight: Color(0xFFf0fdf4),
      backgroundDark: Color(0xFF0d1f12),
      cardLight: Color(0xFFdcfce7),
      cardDark: Color(0xFF1a3d24),
    ),
    ColorThemeType.sunset: ColorThemeData(
      nameKey: 'theme.sunset.name',
      descriptionKey: 'theme.sunset.description',
      primaryLight: Color(0xFFea580c),
      primaryDark: Color(0xFFfb923c),
      accentLight: Color(0xFFf59e0b),
      accentDark: Color(0xFFfbbf24),
      backgroundLight: Color(0xFFfffbeb),
      backgroundDark: Color(0xFF1c1208),
      cardLight: Color(0xFFfef3c7),
      cardDark: Color(0xFF3d2a10),
    ),
    ColorThemeType.galaxy: ColorThemeData(
      nameKey: 'theme.galaxy.name',
      descriptionKey: 'theme.galaxy.description',
      primaryLight: Color(0xFF7c3aed),
      primaryDark: Color(0xFFa78bfa),
      accentLight: Color(0xFFa855f7),
      accentDark: Color(0xFFc084fc),
      backgroundLight: Color(0xFFfaf5ff),
      backgroundDark: Color(0xFF1a0d2e),
      cardLight: Color(0xFFf3e8ff),
      cardDark: Color(0xFF2d1b4e),
    ),
    ColorThemeType.ruby: ColorThemeData(
      nameKey: 'theme.ruby.name',
      descriptionKey: 'theme.ruby.description',
      primaryLight: Color(0xFFdc2626),
      primaryDark: Color(0xFFf87171),
      accentLight: Color(0xFFf59e0b),
      accentDark: Color(0xFFfbbf24),
      backgroundLight: Color(0xFFfef2f2),
      backgroundDark: Color(0xFF1f0a0a),
      cardLight: Color(0xFFfee2e2),
      cardDark: Color(0xFF3d1515),
    ),
    ColorThemeType.emerald: ColorThemeData(
      nameKey: 'theme.emerald.name',
      descriptionKey: 'theme.emerald.description',
      primaryLight: Color(0xFF059669),
      primaryDark: Color(0xFF34d399),
      accentLight: Color(0xFF10b981),
      accentDark: Color(0xFF6ee7b7),
      backgroundLight: Color(0xFFecfdf5),
      backgroundDark: Color(0xFF0a1f17),
      cardLight: Color(0xFFd1fae5),
      cardDark: Color(0xFF15402c),
    ),
    ColorThemeType.coral: ColorThemeData(
      nameKey: 'theme.coral.name',
      descriptionKey: 'theme.coral.description',
      primaryLight: Color(0xFFe11d48),
      primaryDark: Color(0xFFfb7185),
      accentLight: Color(0xFFec4899),
      accentDark: Color(0xFFf472b6),
      backgroundLight: Color(0xFFfdf2f8),
      backgroundDark: Color(0xFF1f0a14),
      cardLight: Color(0xFFfce7f3),
      cardDark: Color(0xFF3d1528),
    ),
  };

  static ColorThemeData getTheme(ColorThemeType type) {
    return themes[type] ?? themes[ColorThemeType.defaultTheme]!;
  }
}
