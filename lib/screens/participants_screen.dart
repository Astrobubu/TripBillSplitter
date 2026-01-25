import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_providers.dart';
import '../models/person.dart';
import '../models/person.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'contact_picker_screen.dart';
import '../widgets/participant_list_tile.dart';

class ParticipantsScreen extends ConsumerStatefulWidget {
  const ParticipantsScreen({super.key});

  @override
  ConsumerState<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends ConsumerState<ParticipantsScreen> {
  final _addNameController = TextEditingController();


  @override
  void dispose() {
    _addNameController.dispose();
    super.dispose();
  }


  void _addPerson() {
    if (_addNameController.text.trim().isEmpty) return;
    ref.read(peopleProvider.notifier).addPerson(_addNameController.text.trim());
    _addNameController.clear();
  }

  Future<void> _pickContact() async {
    final currentPeople = ref.read(peopleProvider).value ?? [];
    final excludedNames = currentPeople.map((p) => p.name).toList();
    final excludedPhones = currentPeople
        .map((p) => p.phoneNumber)
        .where((p) => p != null)
        .cast<String>()
        .toList();

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
      await ref.read(peopleProvider.notifier).addPeople(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Added ${result.length} participants')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peopleAsync = ref.watch(peopleProvider);
    final currentTripAsync = ref.watch(currentTripProvider);
    
    // Keep controller in sync with External updates (e.g. from provider syncs)
    // But ONLY if not currently focused to avoid typing interference
    // Better strategy: Only sync on load. Two-way binding with text field is tricky.
    // relying on onSubmitted for total count mainly.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Participants'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Global Controls Section
            // 1. Global Controls Section - Simplified to just header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.groups, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Participants: ${currentTripAsync.value?.totalParticipants ?? 0}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Add people below',
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

            // 2. Add Named Person Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addNameController,
                      decoration: InputDecoration(
                        hintText: 'Add specific name (e.g. Alice)',
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
                    tooltip: 'Add from Contacts',
                  ),
                ],
              ),
            ),
            
            // 3. Participants List
            Expanded(
              child: peopleAsync.when(
                data: (people) {
                  if (people.isEmpty) {
                    return Center(
                      child: Text(
                        'No participants',
                        style: TextStyle(color: Colors.grey[400]),
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
                          ref.read(peopleProvider.notifier).updatePerson(
                            person.copyWith(name: newName, phoneNumber: newPhone),
                          );
                        },
                        onRemove: () {
                           ref.read(peopleProvider.notifier).removePerson(person.id);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Error loading participants')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


