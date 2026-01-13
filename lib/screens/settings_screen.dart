import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Appearance Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Defaults',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'About',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Trip Bill Splitter'),
            subtitle: const Text('Split expenses with friends on trips'),
          ),
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
          content: Column(
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
}
