import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_providers.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../services/share_service.dart';
import 'history_screen.dart';
import 'analytics_screen.dart';
import 'contact_picker_screen.dart';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'participants_screen.dart';
import '../models/trip.dart'; // Ensure Trip model is imported if not already via providers or implicit

class BillSplitterScreen extends ConsumerStatefulWidget {
  const BillSplitterScreen({super.key});

  @override
  ConsumerState<BillSplitterScreen> createState() => _BillSplitterScreenState();
}

class _BillSplitterScreenState extends ConsumerState<BillSplitterScreen> {
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  // REMOVED: _participantsController
  String? _editingExpenseId;
  bool _showAllExpenses = false;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _descController.dispose();
    // REMOVED: _participantsController.dispose
    super.dispose();
  }

  // REMOVED: _updateParticipants method entirely - moved logic to ParticipantsScreen



  void _showSettleDialog(BuildContext context, WidgetRef ref, SmartSettlement settlement, String currency) {
    // if (settlement.isPaid) return; // Removed as settled items won't appear

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settle Debt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${settlement.fromPersonName} pays ${settlement.toPersonName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '$currency${settlement.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              ref.read(paymentsProvider.notifier).addPayment(
                fromPersonId: settlement.fromPersonId,
                toPersonId: settlement.toPersonId,
                amount: settlement.amount,
                note: 'Settlement',
              );
              ref.read(tripsProvider.notifier).refresh();
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.check),
            label: const Text('Mark as Paid'),
          ),
        ],
      ),
    );
  }

  void _showCurrencySelector() async {
    final currentTrip = ref.read(currentTripProvider).value;
    if (currentTrip == null) return;

    final selectedCurrency = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _currencyOption('\$', 'US Dollar'),
            _currencyOption('€', 'Euro'),
            _currencyOption('£', 'British Pound'),
            _currencyOption('AED', 'UAE Dirham'),
            _currencyOption('¥', 'Japanese Yen'),
            _currencyOption('₹', 'Indian Rupee'),
            _currencyOption('CHF', 'Swiss Franc'),
            _currencyOption('AUD', 'Australian Dollar'),
            _currencyOption('CAD', 'Canadian Dollar'),
          ],
        ),
      ),
    );

    if (selectedCurrency != null && mounted) {
      await ref.read(tripsProvider.notifier).updateTrip(
        currentTrip.copyWith(currency: selectedCurrency),
      );
    }
  }

  Widget _currencyOption(String symbol, String name) {
    return ListTile(
      title: Text('$symbol - $name'),
      onTap: () => Navigator.of(context).pop(symbol),
    );
  }

  Widget _navButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _startEditing(Expense expense, String payerName) {
    setState(() {
      _editingExpenseId = expense.id;
      _personController.text = payerName;
      _amountController.text = expense.amount.toString();
      _descController.text = expense.description;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingExpenseId = null;
      _personController.clear();
      _amountController.clear();
      _descController.clear();
    });
  }

  void _addOrUpdateExpenseMerged() async {
    final name = _personController.text.trim();
    final amount = double.tryParse(_amountController.text);
    if (name.isEmpty || amount == null || amount <= 0) return;

    final peopleAsync = ref.read(peopleProvider);
    await peopleAsync.when(
      data: (people) async {
        final existingPerson = people.firstWhere(
          (p) => p.name.toLowerCase() == name.toLowerCase(),
          orElse: () => Person(id: '', name: '', tripId: ''),
        );

        String personId;
        if (existingPerson.id.isNotEmpty) {
          personId = existingPerson.id;
        } else {
          final newPerson = await ref.read(peopleProvider.notifier).addPerson(name);
          personId = newPerson.id;
        }

        if (_editingExpenseId != null) {
          await ref.read(expensesProvider.notifier).updateExpense(
                _editingExpenseId!,
                _descController.text.isEmpty ? 'Expense' : _descController.text,
                amount,
                personId,
              );
          _editingExpenseId = null;
        } else {
          await ref.read(expensesProvider.notifier).addExpense(
                _descController.text.isEmpty ? 'Expense' : _descController.text,
                amount,
                personId,
              );
        }

        _personController.clear();
        _amountController.clear();
        _descController.clear();
        setState(() {});
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  void _shareAsImage() async {
    final currentTrip = ref.read(currentTripProvider).value;
    final expensesAsync = ref.read(expensesProvider);
    final peopleAsync = ref.read(peopleProvider);
    final settlements = ref.read(settlementsProvider);
    final total = ref.read(totalExpenseProvider);

    if (currentTrip == null) return;

    // Extract data from AsyncValue
    final expenses = expensesAsync.value ?? [];
    final people = peopleAsync.value ?? [];

    try {
      await ShareService.shareAsImage(
        context: context,
        trip: currentTrip,
        expenses: expenses,
        people: people,
        settlements: settlements,
        totalAmount: total,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  void _showParticipantsOptions(Trip trip) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manage Participants',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(
                  icon: Icons.person_add,
                  label: 'Manual Add',
                  color: Colors.blue.shade100,
                  iconColor: Colors.blue.shade700,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ParticipantsScreen()),
                    );
                  },
                ),
                _actionButton(
                  icon: Icons.contacts,
                  label: 'From Contacts',
                  color: Colors.green.shade100,
                  iconColor: Colors.green.shade700,
                  onTap: () async {
                    Navigator.pop(context); // Close sheet first
                    await _pickContact();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
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
    final currentTripAsync = ref.watch(currentTripProvider);
    final peopleAsync = ref.watch(peopleProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final total = ref.watch(totalExpenseProvider);
    final settlements = ref.watch(settlementsProvider);

    return currentTripAsync.when(
      data: (currentTrip) {
        if (currentTrip == null) {
          return Scaffold(
            body: const Center(child: Text('No active trip')),
          );
        }

        // REMOVED: Sync participants controller logic


        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () async {
                final controller = TextEditingController(text: currentTrip.name);
                final newName = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Edit Trip Name'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Trip name',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
                if (newName != null && newName.isNotEmpty && mounted) {
                  await ref.read(tripsProvider.notifier).updateTrip(
                    currentTrip.copyWith(name: newName),
                  );
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currentTrip.name),
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.archive_outlined),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Archive Trip?'),
                      content: const Text('This will move the trip to archived. You can view it from the trips list.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive')),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await ref.read(tripsProvider.notifier).archiveTrip(currentTrip.id);
                    if (mounted) Navigator.of(context).pop();
                  }
                },
                tooltip: 'Archive Trip',
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareAsImage,
                tooltip: 'Share',
              ),
            ],
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Config Row
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.groups, color: Colors.black),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _showParticipantsOptions(currentTrip),
                                          child: Text(
                                            'Total People:',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _showParticipantsOptions(currentTrip),
                                        child: Text(
                                          currentTrip.totalParticipants.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 24, 
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: InkWell(
                                  onTap: _showCurrencySelector,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Text(
                                        currentTrip.currency,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Navigation Buttons Row
                        Row(
                          children: [

                            Expanded(
                              child: _navButton(
                                icon: Icons.history,
                                label: 'History',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            Expanded(
                              child: _navButton(
                                icon: Icons.analytics,
                                label: 'Analytics',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Add Expense Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _editingExpenseId != null ? 'Edit Expense' : 'Add Expense',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: _editingExpenseId != null ? theme.colorScheme.primary : null,
                              ),
                            ),
                            if (_editingExpenseId != null)
                              TextButton(
                                onPressed: _cancelEditing,
                                child: const Text('Cancel'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Add Expense Card
                        Card(
                          elevation: _editingExpenseId != null ? 4 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: _editingExpenseId != null
                                ? BorderSide(color: theme.colorScheme.primary, width: 2)
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: peopleAsync.when(
                                        data: (people) {
                                          if (people.isEmpty) {
                                            return const TextField(
                                              enabled: false,
                                              decoration: InputDecoration(
                                                labelText: 'Payer',
                                                hintText: 'Add participants first',
                                                prefixIcon: Icon(Icons.person_outline, size: 18),
                                              ),
                                            );
                                          }
                                            return DropdownButtonFormField<String>(
                                              value: people.any((p) => p.name == _personController.text)
                                                  ? _personController.text
                                                  : null,
                                              decoration: InputDecoration(
                                                labelText: 'Payer',
                                                prefixIcon: const Icon(Icons.person_outline, size: 18),
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 16,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: BorderSide.none,
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: BorderSide.none,
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  borderSide: BorderSide(
                                                    color: theme.colorScheme.primary,
                                                    width: 2,
                                                  ),
                                                ),
                                                filled: true,
                                                fillColor: theme.inputDecorationTheme.fillColor,
                                              ),
                                              hint: const Text('Select payer'),
                                              isExpanded: true,
                                              items: people.map((person) {
                                                return DropdownMenuItem<String>(
                                                  value: person.name,
                                                  child: Text(person.name, overflow: TextOverflow.ellipsis),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                if (value != null) {
                                                  setState(() {
                                                    _personController.text = value;
                                                  });
                                                }
                                              },
                                            );
                                        },
                                        loading: () => const TextField(
                                          enabled: false,
                                          decoration: InputDecoration(labelText: 'Loading...'),
                                        ),
                                        error: (_, __) => const TextField(
                                          decoration: InputDecoration(labelText: 'Payer Name'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _amountController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Amount',
                                          hintText: '0.0',
                                          prefixText: currentTrip.currency,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _descController,
                                        decoration: const InputDecoration(
                                          labelText: 'For what?',
                                          hintText: 'Meat, Taxi...',
                                          prefixIcon: Icon(Icons.notes, size: 18),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton.filled(
                                      onPressed: _addOrUpdateExpenseMerged,
                                      style: IconButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.all(16),
                                      ),
                                      icon: Icon(_editingExpenseId != null ? Icons.check : Icons.add),
                                      tooltip: _editingExpenseId != null
                                          ? 'Update Expense'
                                          : 'Add Expense',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // Expenses List
                expensesAsync.when(
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    final displayedExpenses = _showAllExpenses 
                        ? expenses 
                        : expenses.take(3).toList();
                    final hasMore = expenses.length > 3;

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            // Show More/Less button at the end
                            if (hasMore && index == displayedExpenses.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showAllExpenses = !_showAllExpenses;
                                    });
                                  },
                                  icon: Icon(_showAllExpenses 
                                      ? Icons.expand_less 
                                      : Icons.expand_more),
                                  label: Text(_showAllExpenses 
                                      ? 'Show Less' 
                                      : 'Show ${expenses.length - 3} More'),
                                ),
                              );
                            }

                            final expense = displayedExpenses[index];
                            return peopleAsync.when(
                              data: (people) {
                                final payerName = people
                                    .firstWhere(
                                      (p) => p.id == expense.payerId,
                                      orElse: () => Person(id: '', name: 'Unknown', tripId: ''),
                                    )
                                    .name;
                                final isEditing = expense.id == _editingExpenseId;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: InkWell(
                                    onTap: () => _startEditing(expense, payerName),
                                    borderRadius: BorderRadius.circular(16),
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: isEditing
                                            ? BorderSide(
                                                color: theme.colorScheme.primary,
                                                width: 2,
                                              )
                                            : BorderSide.none,
                                      ),
                                      tileColor: isEditing
                                          ? theme.colorScheme.primary.withValues(alpha: 0.05)
                                          : theme.cardColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            theme.colorScheme.primary.withValues(alpha: 0.1),
                                        radius: 18,
                                        child: Text(
                                          payerName.isNotEmpty ? payerName[0].toUpperCase() : '?',
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: RichText(
                                        text: TextSpan(
                                          style: theme.textTheme.bodyMedium,
                                          children: [
                                            TextSpan(
                                              text: payerName,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const TextSpan(text: ' paid '),
                                            TextSpan(
                                              text:
                                                  '${currentTrip.currency}${expense.amount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      subtitle: expense.description.isNotEmpty
                                          ? Text(expense.description)
                                          : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!isEditing)
                                            const Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                              color: Colors.grey,
                                            ),
                                            onPressed: () => ref
                                                .read(expensesProvider.notifier)
                                                .removeExpense(expense.id),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            );
                          },
                          childCount: displayedExpenses.length + (hasMore ? 1 : 0),
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
                // Settlement Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Settlement', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Cost',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${currentTrip.currency}${total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 40,
                                width: 1,
                                color: Colors.black12,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Per Person',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    () {
                                      // Always use trip's totalParticipants
                                      final effectiveCount = currentTrip.totalParticipants;
                                      final perPerson = total / (effectiveCount > 0 ? effectiveCount : 1);
                                      return '${currentTrip.currency}${perPerson.toStringAsFixed(2)}';
                                    }(),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate(target: total > 0 ? 1 : 0).fadeIn().scale(),
                        const SizedBox(height: 24),
                        // Settlement Section Header
                        Text('Who Owes Who', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        if (settlements.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No debts to settle yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              final smartSettlements = ref.watch(smartSettlementsProvider);
                              
                              if (smartSettlements.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'All settled up! ✓',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green),
                                    ),
                                  ),
                                );
                              }
                              
                              return Column(
                                children: smartSettlements.map((s) {
                                  final color = const Color(0xFFef4444); // Always red (debt)
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      onTap: () => _showSettleDialog(context, ref, s, currentTrip.currency),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      leading: CircleAvatar(
                                        backgroundColor: color.withOpacity(0.2),
                                        radius: 16,
                                        child: Icon(
                                          Icons.arrow_forward,
                                          color: color,
                                          size: 16,
                                        ),
                                      ),
                                      title: Text(
                                        '${s.fromPersonName} → ${s.toPersonName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'Tap to settle',
                                        style: TextStyle(color: Colors.grey, fontSize: 11),
                                      ),
                                      trailing: Text(
                                        '${currentTrip.currency}${s.amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}
