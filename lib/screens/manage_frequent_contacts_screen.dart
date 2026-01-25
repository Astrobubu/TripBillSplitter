import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../models/person.dart';
import '../widgets/participant_list_tile.dart';
import 'contact_picker_screen.dart';

final frequentPeopleProvider = StateNotifierProvider<FrequentPeopleNotifier, AsyncValue<List<Person>>>((ref) {
  return FrequentPeopleNotifier();
});

class FrequentPeopleNotifier extends StateNotifier<AsyncValue<List<Person>>> {
  FrequentPeopleNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final people = await DatabaseService.instance.getFrequentPeople();
      state = AsyncValue.data(people);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> add(String name, String? phone) async {
    try {
      final person = Person(
        id: const Uuid().v4(),
        name: name,
        tripId: '', // Meaningless for global
        phoneNumber: phone,
      );
      await DatabaseService.instance.addFrequentPerson(person);
      await load();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> addPeople(List<Map<String, String?>> peopleData) async {
      for (final data in peopleData) {
          final name = data['name'];
          if (name != null) {
              await add(name, data['phone']);
          }
      }
  }

  Future<void> remove(String id) async {
    await DatabaseService.instance.deleteFrequentPerson(id);
    await load();
  }

  Future<void> update(Person person) async {
      // For frequent people, we actually need an update method in DB if we want to edit them
      // But for now let's just delete and re-add or skip editing if not requested.
      // Wait, the user wants consistency. The Participants screen allows editing.
      // So we should allow editing frequent contacts.
      // But we didn't add updateFrequentPerson to DBService yet.
      // Let's implement a workaround or add it.
      // Workaround: Delete and Add (ID changes but that's fine for a template list)
      // Actually better to just do nothing or support it later. 
      // Let's Add update support via delete/add for now to keep it moving.
      await DatabaseService.instance.deleteFrequentPerson(person.id);
      await DatabaseService.instance.addFrequentPerson(person); // This enables editing
      await load();
  }
}

class ManageFrequentContactsScreen extends ConsumerStatefulWidget {
  const ManageFrequentContactsScreen({super.key});

  @override
  ConsumerState<ManageFrequentContactsScreen> createState() => _ManageFrequentContactsScreenState();
}

class _ManageFrequentContactsScreenState extends ConsumerState<ManageFrequentContactsScreen> {
  final _addNameController = TextEditingController();

  @override
  void dispose() {
    _addNameController.dispose();
    super.dispose();
  }

  void _addPerson() {
    if (_addNameController.text.trim().isEmpty) return;
    ref.read(frequentPeopleProvider.notifier).add(_addNameController.text.trim(), null);
    _addNameController.clear();
  }

  Future<void> _pickContact() async {
    // For Frequent Contacts, we don't have a "current trip" list to exclude, 
    // unless we exclude people ALREADY in the frequent list.
    final currentPeople = ref.read(frequentPeopleProvider).value ?? [];
    final excludedNames = currentPeople.map((p) => p.name).toList();
    final excludedPhones = currentPeople.map((p) => p.phoneNumber).where((p) => p != null).cast<String>().toList();

    // Use the same ContactPickerScreen
    final result = await Navigator.push<List<Map<String, String?>>>(
      context, 
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
            excludedNames: excludedNames,
            excludedPhoneNumbers: excludedPhones,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      await ref.read(frequentPeopleProvider.notifier).addPeople(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Added ${result.length} contacts')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(frequentPeopleProvider);
    final theme = Theme.of(context);

    // This screen will be embedded in a tab usually, but for now let's keep it as a widget that can be used anywhere.
    // If used as a full screen push (current state), it needs a Scaffold.
    // If used in BottomNav, it still needs a Scaffold or at least a Body. 
    // Dashboard usually puts Scaffolds in tabs.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Frequent Contacts'),
      ),
      body: Column(
        children: [
           // 1. Header (Consistency with ParticipantsScreen)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.star_outline, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Frequent People',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'These people appear first when adding to trips',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 2. Add Named Person Section (Consistency)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addNameController,
                      decoration: InputDecoration(
                        hintText: 'Add name (e.g. Bob)',
                        prefixIcon: const Icon(Icons.person_add_outlined),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _addPerson(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _addPerson,
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Person',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _pickContact, 
                    icon: const Icon(Icons.contacts),
                    tooltip: 'From Contacts',
                  ),
                ],
              ),
            ),

            // 3. List
            Expanded(
            child: peopleAsync.when(
              data: (people) {
                if (people.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No frequent contacts',
                          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final person = people[index];
                    return ParticipantListTile(
                      key: ValueKey(person.id),
                      person: person,
                      onUpdate: (newName, newPhone) {
                          ref.read(frequentPeopleProvider.notifier).update(
                              person.copyWith(name: newName, phoneNumber: newPhone)
                          );
                      },
                      onRemove: () => ref.read(frequentPeopleProvider.notifier).remove(person.id),
                      isEditable: true,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
