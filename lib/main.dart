import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'theme/color_themes.dart';
import 'screens/trips_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: TripBillSplitterApp(),
    ),
  );
}

class TripBillSplitterApp extends StatelessWidget {
  const TripBillSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightTheme = AppTheme.buildTheme(
      brightness: Brightness.light,
      colorTheme: ColorThemeType.defaultTheme,
    );
    final darkTheme = AppTheme.buildTheme(
      brightness: Brightness.dark,
      colorTheme: ColorThemeType.defaultTheme,
    );

    return MaterialApp(
      title: 'Trip Bill Splitter',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const TripsScreen(),
    );
  }
}
