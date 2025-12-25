import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // About Section
          _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Trip Splitter'),
            subtitle: Text('Version 1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Developer'),
            subtitle: Text('Ahmad'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source'),
            subtitle: const Text('github.com/Astrobubu/TripBillSplitter'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('github.com/Astrobubu/TripBillSplitter')),
              );
            },
          ),
          const Divider(),
          
          // Support Section
          _SectionHeader(title: 'Support'),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report a Bug'),
            subtitle: const Text('support@example.com'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email: support@example.com')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate the App'),
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
            leading: const Icon(Icons.update),
            title: const Text('Check for Updates'),
            subtitle: const Text('Currently on latest version'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You are on the latest version!')),
              );
            },
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
              Text('Start by creating a trip with your preferred currency.\n'),
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
