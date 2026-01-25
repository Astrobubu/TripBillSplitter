import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

final settingsServiceProvider = Provider((ref) => SettingsService());

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, String>((ref) {
  return ThemeModeNotifier(ref.read(settingsServiceProvider));
});

class ThemeModeNotifier extends StateNotifier<String> {
  final SettingsService _settingsService;

  ThemeModeNotifier(this._settingsService) : super('system') {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    state = await _settingsService.getThemeMode();
  }

  Future<void> setThemeMode(String mode) async {
    await _settingsService.setThemeMode(mode);
    state = mode;
  }
}

final defaultCurrencyProvider = StateNotifierProvider<DefaultCurrencyNotifier, AsyncValue<String>>((ref) {
  return DefaultCurrencyNotifier(ref.read(settingsServiceProvider));
});

class DefaultCurrencyNotifier extends StateNotifier<AsyncValue<String>> {
  final SettingsService _settingsService;

  DefaultCurrencyNotifier(this._settingsService) : super(const AsyncValue.loading()) {
    _loadDefaultCurrency();
  }

  Future<void> _loadDefaultCurrency() async {
    try {
      final currency = await _settingsService.getDefaultCurrency();
      state = AsyncValue.data(currency);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> setDefaultCurrency(String currency) async {
    await _settingsService.setDefaultCurrency(currency);
    state = AsyncValue.data(currency);
  }
}

final defaultParticipantsProvider = StateNotifierProvider<DefaultParticipantsNotifier, int>((ref) {
  return DefaultParticipantsNotifier(ref.read(settingsServiceProvider));
});

class DefaultParticipantsNotifier extends StateNotifier<int> {
  final SettingsService _settingsService;

  DefaultParticipantsNotifier(this._settingsService) : super(0) {
    _loadDefaultParticipants();
  }

  Future<void> _loadDefaultParticipants() async {
    state = await _settingsService.getDefaultParticipants();
  }

  Future<void> setDefaultParticipants(int count) async {
    await _settingsService.setDefaultParticipants(count);
    state = count;
  }
}
