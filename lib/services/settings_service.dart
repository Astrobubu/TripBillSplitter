import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class SettingsService {
  static const String _themeKey = 'theme_mode';
  static const String _defaultCurrencyKey = 'default_currency';
  static const String _defaultParticipantsKey = 'default_participants';

  // Theme mode: 'system', 'light', 'dark'
  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  // Default currency
  Future<String> getDefaultCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedCurrency = prefs.getString(_defaultCurrencyKey);

    if (savedCurrency != null) {
      return savedCurrency;
    }

    // Try to get location-based currency
    try {
      String locationCurrency = await _getLocationBasedCurrency();
      await setDefaultCurrency(locationCurrency);
      return locationCurrency;
    } catch (e) {
      // Default to AED if location fails
      await setDefaultCurrency('AED');
      return 'AED';
    }
  }

  Future<String> _getLocationBasedCurrency() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'AED';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'AED';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return 'AED';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // Map coordinates to currency (simplified)
      return _getCurrencyByCoordinates(position.latitude, position.longitude);
    } catch (e) {
      return 'AED';
    }
  }

  String _getCurrencyByCoordinates(double lat, double lng) {
    // UAE region
    if (lat >= 22.0 && lat <= 26.5 && lng >= 51.0 && lng <= 56.5) {
      return 'AED';
    }
    // Saudi Arabia region
    if (lat >= 16.0 && lat <= 32.0 && lng >= 34.0 && lng <= 56.0) {
      return 'SAR';
    }
    // Europe
    if (lat >= 35.0 && lat <= 71.0 && lng >= -10.0 && lng <= 40.0) {
      return '€';
    }
    // USA/Canada
    if (lat >= 25.0 && lat <= 72.0 && lng >= -170.0 && lng <= -50.0) {
      return '\$';
    }
    // UK
    if (lat >= 49.0 && lat <= 61.0 && lng >= -8.0 && lng <= 2.0) {
      return '£';
    }
    // Japan
    if (lat >= 24.0 && lat <= 46.0 && lng >= 122.0 && lng <= 154.0) {
      return '¥';
    }

    // Default to AED for Middle East region
    return 'AED';
  }

  Future<void> setDefaultCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultCurrencyKey, currency);
  }

  // Default participants
  Future<int> getDefaultParticipants() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultParticipantsKey) ?? 0;
  }

  Future<void> setDefaultParticipants(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultParticipantsKey, count);
  }

  // Available currencies
  static const List<String> availableCurrencies = [
    'AED', // UAE Dirham (default)
    '\$',  // US Dollar
    '€',   // Euro
    '£',   // British Pound
    '¥',   // Japanese Yen
    'SAR', // Saudi Riyal
  ];

  // Available theme modes
  static const List<String> themeModes = [
    'system',
    'light',
    'dark',
  ];
}
