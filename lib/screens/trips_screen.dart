import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../models/trip.dart';
import 'bill_splitter_screen.dart';
import 'settings_screen.dart';

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  final _tripNameController = TextEditingController();
  bool _showArchived = false;

  @override
  void dispose() {
    _tripNameController.dispose();
    super.dispose();
  }

  void _showCreateTripDialog() async {
    _tripNameController.clear();
    
    // Get existing trips to generate next trip number
    final trips = ref.read(tripsProvider).value ?? [];
    final tripCount = trips.length + 1;
    
    showDialog(
      context: context,
      builder: (context) {
        String selectedCurrency = '\$';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Trip'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _tripNameController,
                      decoration: InputDecoration(
                        labelText: 'Trip Name (optional)',
                        hintText: 'Trip $tripCount',
                        prefixIcon: const Icon(Icons.luggage),
                      ),
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      items: const [
                        DropdownMenuItem(value: '\$', child: Text('\$ - US Dollar')),
                        DropdownMenuItem(value: '€', child: Text('€ - Euro')),
                        DropdownMenuItem(value: '£', child: Text('£ - British Pound')),
                        DropdownMenuItem(value: 'AED', child: Text('AED - UAE Dirham')),
                        DropdownMenuItem(value: '¥', child: Text('¥ - Japanese Yen')),
                        DropdownMenuItem(value: '₹', child: Text('₹ - Indian Rupee')),
                        DropdownMenuItem(value: 'CHF', child: Text('CHF - Swiss Franc')),
                        DropdownMenuItem(value: 'AUD', child: Text('AUD - Australian Dollar')),
                        DropdownMenuItem(value: 'CAD', child: Text('CAD - Canadian Dollar')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedCurrency = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = _tripNameController.text.trim().isEmpty 
                        ? 'Trip $tripCount' 
                        : _tripNameController.text.trim();
                    final trip = await ref.read(tripsProvider.notifier).createTrip(
                      name,
                      currency: selectedCurrency,
                      totalParticipants: 1, // Will auto-update when people are added
                    );
                    ref.read(currentTripIdProvider.notifier).state = trip.id;
                    if (mounted) {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const BillSplitterScreen(),
                        ),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openTrip(Trip trip) {
    ref.read(currentTripIdProvider.notifier).state = trip.id;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BillSplitterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripsAsync = ref.watch(tripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.unarchive : Icons.archive),
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
              });
            },
            tooltip: _showArchived ? 'Hide Archived' : 'Show Archived',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: tripsAsync.when(
        data: (trips) {
          final filteredTrips = trips.where((t) => t.isArchived == _showArchived).toList();

          if (filteredTrips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showArchived ? Icons.archive_outlined : Icons.luggage_outlined,
                    size: 80,
                    color: Colors.grey,
                  ).animate().scale(),
                  const SizedBox(height: 16),
                  Text(
                    _showArchived ? 'No archived trips' : 'No trips yet',
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showArchived
                        ? 'Archived trips will appear here'
                        : 'Create your first trip to get started',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  if (!_showArchived) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _showCreateTripDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Trip'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredTrips.length,
            itemBuilder: (context, index) {
              final trip = filteredTrips[index];
              final dateFormat = DateFormat('MMM d, yyyy');

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _openTrip(trip),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.luggage,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip.name,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Created ${dateFormat.format(trip.createdAt)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _TripInfoChip(
                              icon: Icons.groups,
                              label: '${trip.totalParticipants} people',
                            ),
                            const SizedBox(width: 8),
                            _TripInfoChip(
                              icon: Icons.attach_money,
                              label: trip.currency,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: (50 * index).ms).slideX();
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
              Text('Error loading trips: $error'),
            ],
          ),
        ),
      ),
      floatingActionButton: !_showArchived
          ? FloatingActionButton.extended(
              onPressed: _showCreateTripDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Trip'),
            )
          : null,
    );
  }
}

class _TripInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TripInfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
