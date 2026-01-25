import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../providers/settings_provider.dart';
import '../models/trip.dart';
import 'bill_splitter_screen.dart';
import 'settings_screen.dart';
import 'manage_frequent_contacts_screen.dart';
import 'participants_screen.dart';
import 'contact_picker_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildTripsTab(),
          const ManageFrequentContactsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage),
            label: 'My Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Frequent People',
          ),
        ],
      ),
    );
  }

  Widget _buildTripsTab() {
     final theme = Theme.of(context);
     final tripsAsync = ref.watch(tripsProvider);
     
     return Scaffold(
       appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: Icon(_showArchived ? Icons.unarchive : Icons.archive),
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
              });
            },
            tooltip: _showArchived ? 'Hide Archived' : 'Show Archived',
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
                  ),
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
                      onPressed: () => _showCreateTripDialog(context),
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
                  onLongPress: () => _showTripOptions(context, trip),
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
                                color: Color(trip.colorValue).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                IconData(trip.iconCodePoint, fontFamily: 'MaterialIcons'),
                                color: Color(trip.colorValue),
                                size: 28,
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
                            InkWell(
                              onTap: () {
                                ref.read(currentTripIdProvider.notifier).state = trip.id;
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ParticipantsScreen()),
                                );
                              },
                              child: _TripInfoChip(
                                icon: Icons.groups,
                                label: '${trip.totalParticipants} people',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
              Text('Error loading trips: $error'),
            ],
          ),
        ),
      ),
      floatingActionButton: !_showArchived
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateTripDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New Trip'),
            )
          : null,
    );
  }

  void _showCreateTripDialog(BuildContext context) {
    final nameController = TextEditingController();
    int selectedIconCode = Icons.luggage.codePoint;
    int selectedColor = Colors.blue.value;

    final defaultCurrencyAsync = ref.read(defaultCurrencyProvider);
    final defaultParticipants = ref.read(defaultParticipantsProvider);
    int totalParticipants = defaultParticipants;
    List<Map<String, String?>> selectedContacts = [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Trip'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Trip Name',
                        hintText: 'e.g., Tokyo 2024, Beach Weekend',
                        prefixIcon: Icon(Icons.edit),
                      ),
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final icon = await _showIconPicker(context);
                              if (icon != null) {
                                setState(() {
                                  selectedIconCode = icon.codePoint;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    IconData(selectedIconCode, fontFamily: 'MaterialIcons'),
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Choose Icon', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final color = await _showColorPicker(context, Color(selectedColor));
                              if (color != null) {
                                setState(() {
                                  selectedColor = color.value;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Color(selectedColor),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Choose Color', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Participants Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_outline, size: 20),
                              const SizedBox(width: 8),
                              const Text('Participants'),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: totalParticipants > 1 ? () {
                                  setState(() => totalParticipants--);
                                } : null,
                                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                padding: EdgeInsets.zero,
                              ),
                              Text(' $totalParticipants ', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  setState(() => totalParticipants++);
                                },
                                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          if (selectedContacts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: selectedContacts.map((c) => Chip(
                                label: Text(c['name'] ?? ''),
                                avatar: const CircleAvatar(child: Icon(Icons.person, size: 16)),
                                onDeleted: () {
                                  setState(() {
                                    selectedContacts.remove(c);
                                  });
                                },
                              )).toList(),
                            ),
                          ],
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push<List<Map<String, String?>>>(
                                context, 
                                MaterialPageRoute(builder: (_) => const ContactPickerScreen(
                                  excludedNames: [], 
                                  excludedPhoneNumbers: []
                                ))
                              );
                              if (result != null && result.isNotEmpty) {
                                setState(() {
                                  selectedContacts.addAll(result);
                                  if (totalParticipants < selectedContacts.length) {
                                    totalParticipants = selectedContacts.length;
                                  }
                                });
                              }
                            },
                            icon: const Icon(Icons.contacts),
                            label: const Text('Add from Contacts'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                        ],
                      ),
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
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      final currency = defaultCurrencyAsync.value ?? 'AED';
                      final trip = await ref.read(tripsProvider.notifier).createTrip(
                            name,
                            currency: currency,
                            totalParticipants: totalParticipants,
                            iconCodePoint: selectedIconCode,
                            colorValue: selectedColor,
                          );
                      
                      if (selectedContacts.isNotEmpty) {
                        try {
                           // Set current trip so addPeople knows where to add
                           // Actually addPeople might need tripId if not current?
                           // Checking addPeople... it uses currentTripIdProvider usually?
                           // Or createPerson takes tripId.
                           
                           // We set currentTripId below.
                           ref.read(currentTripIdProvider.notifier).state = trip.id;
                           // But state update might not propagate instantly to provider.read(peopleProvider) if it depends on async.
                           
                           // Using raw DatabaseService might be safer or ensuring we wait.
                           // Helper: peopleProvider uses currentTripIdProvider.
                           // Let's use the notifier which should be valid once state is set?
                           // Actually app_providers.dart: addPeople uses `tripId = ref.read(currentTripIdProvider)`.
                           
                           // So:
                           ref.read(currentTripIdProvider.notifier).state = trip.id;
                           await Future.delayed(const Duration(milliseconds: 50)); // Tiny yield
                           await ref.read(peopleProvider.notifier).addPeople(selectedContacts);
                        } catch (e) {
                          debugPrint('Error adding contacts: $e');
                        }
                      } else {
                         ref.read(currentTripIdProvider.notifier).state = trip.id;
                      }
                      ref.read(currentTripIdProvider.notifier).state = trip.id;
                      if (mounted) {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const BillSplitterScreen(),
                          ),
                        );
                      }
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

  Future<IconData?> _showIconPicker(BuildContext context) async {
    final icons = [
      Icons.luggage,
      Icons.flight,
      Icons.beach_access,
      Icons.hiking,
      Icons.directions_car,
      Icons.hotel,
      Icons.restaurant,
      Icons.camera_alt,
      Icons.sailing,
      Icons.snowboarding,
      Icons.landscape,
      Icons.park,
      Icons.castle,
      Icons.mosque,
      Icons.temple_buddhist,
      Icons.festival,
    ];

    return await showDialog<IconData>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Icon'),
          content: SizedBox(
            width: 300,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: icons.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => Navigator.of(context).pop(icons[index]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icons[index], size: 32),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<Color?> _showColorPicker(BuildContext context, Color currentColor) async {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
      Colors.lime,
    ];

    return await showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Color'),
          content: SizedBox(
            width: 300,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => Navigator.of(context).pop(colors[index]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors[index],
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showTripOptions(BuildContext context, Trip trip) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Trip'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditTripDialog(context, trip);
                },
              ),
              ListTile(
                leading: Icon(trip.isArchived ? Icons.unarchive : Icons.archive),
                title: Text(trip.isArchived ? 'Unarchive Trip' : 'Archive Trip'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(tripsProvider.notifier).archiveTrip(trip.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Trip', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, trip);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditTripDialog(BuildContext context, Trip trip) {
    final nameController = TextEditingController(text: trip.name);
    int selectedIconCode = trip.iconCodePoint;
    int selectedColor = trip.colorValue;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Trip'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Trip Name',
                        prefixIcon: Icon(Icons.edit),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final icon = await _showIconPicker(context);
                              if (icon != null) {
                                setState(() {
                                  selectedIconCode = icon.codePoint;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    IconData(selectedIconCode, fontFamily: 'MaterialIcons'),
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Change Icon', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final color = await _showColorPicker(context, Color(selectedColor));
                              if (color != null) {
                                setState(() {
                                  selectedColor = color.value;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Color(selectedColor),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Change Color', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      await ref.read(tripsProvider.notifier).updateTrip(
                            trip.copyWith(
                              name: name,
                              iconCodePoint: selectedIconCode,
                              colorValue: selectedColor,
                            ),
                          );
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Trip trip) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Trip'),
          content: Text('Are you sure you want to delete "${trip.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(tripsProvider.notifier).deleteTrip(trip.id);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
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
