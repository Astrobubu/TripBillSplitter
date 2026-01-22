import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_providers.dart';
import '../models/person.dart';

class ParticipantsScreen extends ConsumerStatefulWidget {
  const ParticipantsScreen({super.key});

  @override
  ConsumerState<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends ConsumerState<ParticipantsScreen> {
  final _totalCountController = TextEditingController();
  final _addNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controller with current trip data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trip = ref.read(currentTripProvider).value;
      if (trip != null) {
        _totalCountController.text = trip.totalParticipants.toString();
      }
    });

    // Listen to changes in trip to update the controller if it changes externally
    // or if we need to sync initial state when data loads
  }

  @override
  void dispose() {
    _totalCountController.dispose();
    _addNameController.dispose();
    super.dispose();
  }

  void _updateTotalCount(String value) {
    if (value.isEmpty) return;
    final int? newCount = int.tryParse(value);
    if (newCount != null && newCount > 0) {
      ref.read(peopleProvider.notifier).setParticipantCount(newCount);
    }
  }

  void _addPerson() {
    if (_addNameController.text.trim().isEmpty) return;
    
    // Adding a named person should increase the total count if it's already full?
    // Or just add them? The provider logic now syncs totalParticipants >= people.length
    // so we can just add.
    ref.read(peopleProvider.notifier).addPerson(_addNameController.text.trim());
    _addNameController.clear();
    
    // Also update the UI controller to reflect potential new count
    // Wait a bit for the provider to update state and DB
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        final trip = ref.read(currentTripProvider).value;
        if (trip != null) {
          _totalCountController.text = trip.totalParticipants.toString();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peopleAsync = ref.watch(peopleProvider);
    final currentTripAsync = ref.watch(currentTripProvider);
    
    // Keep controller in sync with External updates (e.g. from provider syncs)
    // But ONLY if not currently focused to avoid typing interference
    /*
    currentTripAsync.whenData((trip) {
      if (trip != null && !FocusScope.of(context).hasFocus) {
         if (_totalCountController.text != trip.totalParticipants.toString()) {
           _totalCountController.text = trip.totalParticipants.toString();
         }
      }
    });
    */
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
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Participants',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Auto-generates "Person X"',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _totalCountController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.cardColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: _updateTotalCount,
                          onTapOutside: (_) {
                            FocusManager.instance.primaryFocus?.unfocus();
                            // Trigger update on blur
                            _updateTotalCount(_totalCountController.text);
                          },
                        ),
                      ),
                    ],
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
                      return _ParticipantListItem(
                        key: ValueKey(person.id),
                        person: person,
                        onUpdate: (newName) {
                          ref.read(peopleProvider.notifier).updatePerson(
                            person.copyWith(name: newName),
                          );
                        },
                        onRemove: () {
                           ref.read(peopleProvider.notifier).removePerson(person.id);
                           // Update controller after removal
                           Future.delayed(const Duration(milliseconds: 100), () {
                              if (context.mounted) {
                                final trip = ref.read(currentTripProvider).value;
                                if (trip != null) {
                                  _totalCountController.text = trip.totalParticipants.toString();
                                }
                              }
                           });
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

class _ParticipantListItem extends StatefulWidget {
  final Person person;
  final Function(String) onUpdate;
  final VoidCallback onRemove;

  const _ParticipantListItem({
    super.key,
    required this.person,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_ParticipantListItem> createState() => _ParticipantListItemState();
}

class _ParticipantListItemState extends State<_ParticipantListItem> {
  late TextEditingController _nameController;
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.person.name);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _save();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.person.name) {
      widget.onUpdate(newName);
    } else {
      _nameController.text = widget.person.name; // Revert if empty or same
    }
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.person.name != _nameController.text && !_isEditing) {
        _nameController.text = widget.person.name;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Text(
            widget.person.name.isNotEmpty ? widget.person.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: _isEditing
            ? TextField(
                controller: _nameController,
                focusNode: _focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _save(),
              )
            : GestureDetector(
                onTap: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
                child: Text(
                  widget.person.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                onPressed: () {
                   setState(() {
                    _isEditing = true;
                  });
                },
              ),
            if (_isEditing)
               IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: _save,
              ),
              
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
