import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_providers.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../services/share_service.dart';
import 'history_screen.dart';
import 'analytics_screen.dart';
import 'payments_screen.dart';

class BillSplitterScreen extends ConsumerStatefulWidget {
  const BillSplitterScreen({super.key});

  @override
  ConsumerState<BillSplitterScreen> createState() => _BillSplitterScreenState();
}

class _BillSplitterScreenState extends ConsumerState<BillSplitterScreen> {
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _participantsController = TextEditingController();
  String? _editingExpenseId;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _participantsController.dispose();
    super.dispose();
  }

  void _updateParticipants() async {
    final count = int.tryParse(_participantsController.text);
    if (count != null && count > 0) {
      final currentTrip = await ref.read(currentTripProvider.future);
      if (currentTrip != null) {
        await ref.read(tripsProvider.notifier).updateTrip(
              currentTrip.copyWith(totalParticipants: count),
            );
      }
    }
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
    final currentTrip = await ref.read(currentTripProvider.future);
    final expenses = await ref.read(expensesProvider.future);
    final people = await ref.read(peopleProvider.future);
    final settlements = ref.read(settlementsProvider);
    final total = ref.read(totalExpenseProvider);

    if (currentTrip == null) return;

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

        // Update participants controller when trip loads
        if (_participantsController.text.isEmpty) {
          _participantsController.text = currentTrip.totalParticipants.toString();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(currentTrip.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const HistoryScreen()),
                  );
                },
                tooltip: 'History',
              ),
              IconButton(
                icon: const Icon(Icons.analytics),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                  );
                },
                tooltip: 'Analytics',
              ),
              IconButton(
                icon: const Icon(Icons.payment),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const PaymentsScreen()),
                  );
                },
                tooltip: 'Payments',
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
                                        child: Text(
                                          'Total People:',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: TextField(
                                          controller: _participantsController,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha: 0.3),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          onChanged: (_) => _updateParticipants(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
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
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideX(),
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
                                        data: (people) => Autocomplete<String>(
                                          optionsBuilder: (v) => v.text == ''
                                              ? const Iterable<String>.empty()
                                              : people
                                                  .where((p) => p.name
                                                      .toLowerCase()
                                                      .contains(v.text.toLowerCase()))
                                                  .map((p) => p.name),
                                          optionsViewBuilder: (ctx, onSel, opts) => Align(
                                            alignment: Alignment.topLeft,
                                            child: Material(
                                              elevation: 4.0,
                                              borderRadius: BorderRadius.circular(16),
                                              color: theme.cardColor,
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(
                                                  maxHeight: 200,
                                                  maxWidth: 250,
                                                ),
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  itemCount: opts.length,
                                                  itemBuilder: (ctx, i) {
                                                    final opt = opts.elementAt(i);
                                                    return InkWell(
                                                      onTap: () => onSel(opt),
                                                      borderRadius: BorderRadius.circular(16),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(16.0),
                                                        child: Text(opt),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          onSelected: (s) => _personController.text = s,
                                          fieldViewBuilder: (ctx, ctrl, node, _) {
                                            if (_personController.text != ctrl.text) {
                                              ctrl.text = _personController.text;
                                            }
                                            ctrl.addListener(() => _personController.text = ctrl.text);
                                            return TextField(
                                              controller: ctrl,
                                              focusNode: node,
                                              decoration: const InputDecoration(
                                                labelText: 'Payer Name',
                                                hintText: 'e.g. John',
                                                prefixIcon: Icon(Icons.person_outline, size: 18),
                                              ),
                                            );
                                          },
                                        ),
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
                        ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),
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

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final expense = expenses[index];
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
                                ).animate().fadeIn().slideX(begin: 0.2, end: 0);
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            );
                          },
                          childCount: expenses.length,
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
                                    '${currentTrip.currency}${(total / (currentTrip.totalParticipants > 0 ? currentTrip.totalParticipants : 1)).toStringAsFixed(2)}',
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
                        const SizedBox(height: 16),
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
                          Column(
                            children: settlements.map((s) {
                              final isReceiving = s.amount > 0;
                              if (s.amount.abs() < 0.01) return const SizedBox.shrink();
                              Color color = isReceiving
                                  ? const Color(0xFF22c55e)
                                  : const Color(0xFFef4444);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isReceiving ? Icons.arrow_downward : Icons.arrow_upward,
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    s.personName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    isReceiving ? 'Gets back' : 'Needs to pay',
                                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                                  ),
                                  trailing: Text(
                                    '${currentTrip.currency}${s.amount.abs().toStringAsFixed(2)}',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn().slideX();
                            }).toList(),
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
