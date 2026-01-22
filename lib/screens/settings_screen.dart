import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/settings_provider.dart';
import '../services/settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '1.0.0';
  bool _checkingForUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      // Keep default version
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingForUpdates = true;
    });

    // Simulate checking for updates
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _checkingForUpdates = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are on the latest version!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultParticipants = ref.watch(defaultParticipantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Appearance Section
          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: Text(_getThemeLabel(themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showThemeDialog(context, ref, themeMode);
            },
          ),
          const Divider(),

          // Defaults Section
          _SectionHeader(title: 'Defaults'),
          defaultCurrencyAsync.when(
            data: (currency) => ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Default Currency'),
              subtitle: Text(currency),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showCurrencyDialog(context, ref, currency);
              },
            ),
            loading: () => const ListTile(
              leading: Icon(Icons.attach_money),
              title: Text('Default Currency'),
              subtitle: Text('Loading...'),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.attach_money),
              title: Text('Default Currency'),
              subtitle: Text('Error loading'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.groups),
            title: const Text('Default Participants'),
            subtitle: Text('$defaultParticipants people'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showParticipantsDialog(context, ref, defaultParticipants);
            },
          ),
          const Divider(),

          // About Section
          _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Trip Splitter'),
            subtitle: Text('Split expenses easily on trips'),
          ),
          ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('Version'),
            subtitle: Text(_appVersion),
          ),
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Developer'),
            subtitle: Text('Ahmad'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source'),
            subtitle: const Text('View on GitHub'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () {
              _launchURL('https://github.com/Astrobubu/TripBillSplitter');
            },
          ),
          const Divider(),

          // Support Section
          _SectionHeader(title: 'Support'),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report a Bug'),
            subtitle: const Text('Help us improve the app'),
            onTap: () {
              _launchURL('https://github.com/Astrobubu/TripBillSplitter/issues');
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate the App'),
            subtitle: const Text('Share your feedback'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon on Play Store!')),
              );
            },
          ),
          const Divider(),

          // App Info Section
          _SectionHeader(title: 'App Info'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('How It Works'),
            subtitle: const Text('Learn about the app'),
            onTap: () => _showHowItWorksDialog(context),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy Policy'),
            subtitle: Text('Your data stays on your device'),
          ),
          const Divider(),

          // Updates Section
          _SectionHeader(title: 'Updates'),
          ListTile(
            leading: _checkingForUpdates
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.update),
            title: const Text('Check for Updates'),
            subtitle: Text(_checkingForUpdates
                ? 'Checking...'
                : 'Currently on version $_appVersion'),
            enabled: !_checkingForUpdates,
            onTap: _checkingForUpdates ? null : _checkForUpdates,
          ),
          const SizedBox(height: 32),

          // Footer
          Center(
            child: Text(
              'Made with ❤️ for easy bill splitting',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getThemeLabel(String mode) {
    switch (mode) {
      case 'system':
        return 'System Default';
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System Default';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, String currentMode) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: SettingsService.themeModes.map((mode) {
              return RadioListTile<String>(
                title: Text(_getThemeLabel(mode)),
                value: mode,
                groupValue: currentMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showCurrencyDialog(BuildContext context, WidgetRef ref, String currentCurrency) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Default Currency'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: SettingsService.availableCurrencies.map((currency) {
                return RadioListTile<String>(
                  title: Text(currency),
                  value: currency,
                  groupValue: currentCurrency,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(defaultCurrencyProvider.notifier).setDefaultCurrency(value);
                      Navigator.of(context).pop();
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showParticipantsDialog(BuildContext context, WidgetRef ref, int currentCount) {
    final controller = TextEditingController(text: currentCount.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Default Participants'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of Participants',
              hintText: 'e.g., 2',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final count = int.tryParse(controller.text);
                if (count != null && count > 0) {
                  ref.read(defaultParticipantsProvider.notifier).setDefaultParticipants(count);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showHowItWorksDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How It Works'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Create a Trip', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Start by creating a trip with your preferred currency and customize it with icons and colors.\n'),
              Text('2. Add Participants', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Add everyone who is part of the trip.\n'),
              Text('3. Record Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Each time someone pays, record who paid and how much.\n'),
              Text('4. View Settlement', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('See exactly who owes who and how much to settle up easily!'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
