import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../models/change_log.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  IconData _getIconForChangeType(ChangeType type) {
    switch (type) {
      case ChangeType.expenseAdded:
        return Icons.add_circle;
      case ChangeType.expenseUpdated:
        return Icons.edit;
      case ChangeType.expenseDeleted:
        return Icons.remove_circle;
      case ChangeType.personAdded:
        return Icons.person_add;
      case ChangeType.personRemoved:
        return Icons.person_remove;
      case ChangeType.tripCreated:
        return Icons.luggage;
      case ChangeType.tripUpdated:
        return Icons.update;
      case ChangeType.paymentAdded:
        return Icons.payment;
      case ChangeType.paymentUpdated:
        return Icons.check_circle;
    }
  }

  Color _getColorForChangeType(ChangeType type) {
    switch (type) {
      case ChangeType.expenseAdded:
      case ChangeType.personAdded:
      case ChangeType.tripCreated:
      case ChangeType.paymentAdded:
        return Colors.green;
      case ChangeType.expenseUpdated:
      case ChangeType.tripUpdated:
      case ChangeType.paymentUpdated:
        return Colors.blue;
      case ChangeType.expenseDeleted:
      case ChangeType.personRemoved:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentTripId = ref.watch(currentTripIdProvider);

    if (currentTripId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('History'),
        ),
        body: const Center(
          child: Text('No active trip'),
        ),
      );
    }

    final changeLogsAsync = ref.watch(changeLogsProvider(currentTripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(changeLogsProvider(currentTripId));
            },
          ),
        ],
      ),
      body: changeLogsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey,
                  ).animate().scale(),
                  const SizedBox(height: 16),
                  Text(
                    'No history yet',
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activity will appear here as you use the app',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final dateFormat = DateFormat('MMM d, yyyy');
          final timeFormat = DateFormat('h:mm a');

          // Group logs by date
          final Map<String, List<ChangeLogEntry>> groupedLogs = {};
          for (final log in logs) {
            final dateKey = dateFormat.format(log.timestamp);
            groupedLogs.putIfAbsent(dateKey, () => []).add(log);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedLogs.length,
            itemBuilder: (context, index) {
              final dateKey = groupedLogs.keys.elementAt(index);
              final dayLogs = groupedLogs[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      dateKey,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  ...dayLogs.map((log) {
                    final icon = _getIconForChangeType(log.changeType);
                    final color = _getColorForChangeType(log.changeType);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(log.description),
                        subtitle: Text(timeFormat.format(log.timestamp)),
                      ),
                    ).animate().fadeIn().slideX();
                  }),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading history: $error'),
            ],
          ),
        ),
      ),
    );
  }
}
