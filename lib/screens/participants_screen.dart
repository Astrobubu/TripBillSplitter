import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_providers.dart';

class ParticipantsScreen extends ConsumerStatefulWidget {
  const ParticipantsScreen({super.key});

  @override
  ConsumerState<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends ConsumerState<ParticipantsScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addPerson() {
    if (_nameController.text.trim().isEmpty) return;
    
    ref.read(peopleProvider.notifier).addPerson(_nameController.text.trim());
    _nameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peopleAsync = ref.watch(peopleProvider);
    final currentTripAsync = ref.watch(currentTripProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Participants'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Add Participant Form
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Add participant name',
                        prefixIcon: const Icon(Icons.person_add_outlined),
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
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
            
            // Info about total count
            currentTripAsync.when(
              data: (trip) => trip != null ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total people set to ${trip.totalParticipants}. Add named participants below.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ) : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            
            const SizedBox(height: 16),
            
            // Participants List
            Expanded(
              child: peopleAsync.when(
                data: (people) {
                  if (people.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No participants yet',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add people who are part of this trip',
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: people.length,
                    itemBuilder: (context, index) {
                      final person = people[index];
                      
                      // Get this person's expense total
                      final expensesAsync = ref.watch(expensesProvider);
                      double personTotal = 0;
                      expensesAsync.whenData((expenses) {
                        personTotal = expenses
                            .where((e) => e.payerId == person.id)
                            .fold(0.0, (sum, e) => sum + e.amount);
                      });
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                            child: Text(
                              person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            personTotal > 0 ? 'Paid: \$${personTotal.toStringAsFixed(2)}' : 'No expenses yet',
                            style: TextStyle(
                              color: personTotal > 0 ? Colors.green : Colors.grey,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove Participant'),
                                  content: Text('Remove ${person.name} from this trip?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        ref.read(peopleProvider.notifier).removePerson(person.id);
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Remove', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
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
