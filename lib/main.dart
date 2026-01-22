import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'theme/color_themes.dart';
import 'screens/trips_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

  runApp(
    ProviderScope(
      child: TripBillSplitterApp(seenOnboarding: seenOnboarding),
    ),
  );
}

class TripBillSplitterApp extends ConsumerWidget {
  final bool seenOnboarding;

  const TripBillSplitterApp({super.key, required this.seenOnboarding});

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
      home: seenOnboarding ? const TripsScreen() : const OnboardingScreen(),
    );
  }
}
