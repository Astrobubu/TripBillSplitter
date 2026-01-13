import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'theme/color_themes.dart';
import 'screens/trips_screen.dart';
import 'providers/settings_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: TripBillSplitterApp(),
    ),
  );
}

class TripBillSplitterApp extends ConsumerWidget {
  const TripBillSplitterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lightTheme = AppTheme.buildTheme(
      brightness: Brightness.light,
      colorTheme: ColorThemeType.defaultTheme,
    );
    final darkTheme = AppTheme.buildTheme(
      brightness: Brightness.dark,
      colorTheme: ColorThemeType.defaultTheme,
    );

    final themeModeString = ref.watch(themeModeProvider);
    final themeMode = themeModeString == 'light'
        ? ThemeMode.light
        : themeModeString == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;

    return MaterialApp(
      title: 'Trip Bill Splitter',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: const TripsScreen(),
    );
  }
}
