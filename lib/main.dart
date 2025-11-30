import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'theme/app_theme.dart';
import 'theme/color_themes.dart';

// -----------------------------------------------------------------------------
// MAIN ENTRY POINT
// -----------------------------------------------------------------------------
void main() {
  runApp(
    const ProviderScope(
      child: BillSplitterApp(),
    ),
  );
}

class BillSplitterApp extends StatelessWidget {
  const BillSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightTheme = AppTheme.buildTheme(
      brightness: Brightness.light,
      colorTheme: ColorThemeType.defaultTheme,
    );
    final darkTheme = AppTheme.buildTheme(
      brightness: Brightness.dark,
      colorTheme: ColorThemeType.defaultTheme,
    );

    return MaterialApp(
      title: 'Bill Splitter',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const BillSplitterScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------
class Person {
  final String id;
  final String name;
  Person({required this.id, required this.name});
}

class Expense {
  final String id;
  final String description;
  final double amount;
  final String payerId;
  Expense({required this.id, required this.description, required this.amount, required this.payerId});
}

class SettlementInfo {
  final String personName;
  final double amount;
  final bool isAnonymous;
  SettlementInfo({required this.personName, required this.amount, this.isAnonymous = false});
}

// -----------------------------------------------------------------------------
// PROVIDERS & LOGIC
// -----------------------------------------------------------------------------
final currencyProvider = StateProvider<String>((ref) => '\$');
final totalParticipantsProvider = StateProvider<int>((ref) => 2);
final peopleProvider = StateNotifierProvider<PeopleNotifier, List<Person>>((ref) => PeopleNotifier());

class PeopleNotifier extends StateNotifier<List<Person>> {
  PeopleNotifier() : super([]);
  void addPerson(String name) {
    if (name.trim().isEmpty) return;
    state = [...state, Person(id: const Uuid().v4(), name: name.trim())];
  }
  void removePerson(String id) => state = state.where((p) => p.id != id).toList();
}

final expensesProvider = StateNotifierProvider<ExpensesNotifier, List<Expense>>((ref) => ExpensesNotifier());

class ExpensesNotifier extends StateNotifier<List<Expense>> {
  ExpensesNotifier() : super([]);
  void addExpense(String description, double amount, String payerId) {
    state = [...state, Expense(id: const Uuid().v4(), description: description, amount: amount, payerId: payerId)];
  }
  void updateExpense(String id, String description, double amount, String payerId) {
    state = [for (final e in state) if (e.id == id) Expense(id: id, description: description, amount: amount, payerId: payerId) else e];
  }
  void removeExpense(String id) => state = state.where((e) => e.id != id).toList();
}

final totalExpenseProvider = Provider<double>((ref) {
  return ref.watch(expensesProvider).fold(0.0, (sum, item) => sum + item.amount);
});

final settlementsProvider = Provider<List<SettlementInfo>>((ref) {
  final people = ref.watch(peopleProvider);
  final expenses = ref.watch(expensesProvider);
  final total = ref.watch(totalExpenseProvider);
  final totalParticipants = ref.watch(totalParticipantsProvider);

  if (total == 0 || totalParticipants == 0) return [];

  final effectiveCount = totalParticipants < people.length ? people.length : totalParticipants;
  final average = total / effectiveCount;
  
  List<SettlementInfo> results = [];
  for (var person in people) {
    double paid = expenses.where((e) => e.payerId == person.id).fold(0.0, (sum, e) => sum + e.amount);
    results.add(SettlementInfo(personName: person.name, amount: paid - average));
  }
  
  int anonymousCount = effectiveCount - people.length;
  if (anonymousCount > 0) {
    results.add(SettlementInfo(personName: '$anonymousCount Others', amount: -(average * anonymousCount), isAnonymous: true));
  }

  results.sort((a, b) => b.amount.compareTo(a.amount));
  return results;
});

// -----------------------------------------------------------------------------
// UI
// -----------------------------------------------------------------------------
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
  void initState() {
    super.initState();
    _participantsController.text = ref.read(totalParticipantsProvider).toString();
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _participantsController.dispose();
    super.dispose();
  }

  void _updateParticipants() {
    final count = int.tryParse(_participantsController.text);
    if (count != null && count > 0) ref.read(totalParticipantsProvider.notifier).state = count;
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

  void _addOrUpdateExpenseMerged() {
    final name = _personController.text.trim();
    final amount = double.tryParse(_amountController.text);
    if (name.isEmpty) return;

    final people = ref.read(peopleProvider);
    final existingPerson = people.firstWhere((p) => p.name.toLowerCase() == name.toLowerCase(), orElse: () => Person(id: '', name: ''));
    String personId = existingPerson.id.isNotEmpty ? existingPerson.id : (ref.read(peopleProvider.notifier)..addPerson(name)).state.last.id;

    if (amount != null && amount > 0) {
      if (_editingExpenseId != null) {
        ref.read(expensesProvider.notifier).updateExpense(_editingExpenseId!, _descController.text.isEmpty ? 'Expense' : _descController.text, amount, personId);
        _editingExpenseId = null;
      } else {
        ref.read(expensesProvider.notifier).addExpense(_descController.text.isEmpty ? 'Expense' : _descController.text, amount, personId);
      }
    }
    _personController.clear();
    _amountController.clear();
    _descController.clear();
    setState(() {}); // Ensure UI updates
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleProvider);
    final expenses = ref.watch(expensesProvider);
    final total = ref.watch(totalExpenseProvider);
    final settlements = ref.watch(settlementsProvider);
    final totalParticipants = ref.watch(totalParticipantsProvider);
    final currency = ref.watch(currencyProvider);
    final effectiveParticipants = totalParticipants < people.length ? people.length : totalParticipants;
    final perPerson = total / (effectiveParticipants > 0 ? effectiveParticipants : 1);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Trip Bill Splitter', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                        .animate().fadeIn().moveY(begin: -10, end: 0),
                    const SizedBox(height: 24),
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
                                color: theme.colorScheme.primary, // Matching the button blue
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.groups, color: Colors.black), // Black Icon
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Total People:',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.black, // Black Label
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
                                        color: Colors.black, // Black Input Text
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.3), // Lighter fill for contrast
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
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary, // Matching the button blue
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: currency,
                                    icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black), // Black Icon
                                    isDense: true,
                                    isExpanded: true,
                                    dropdownColor: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                    items: ['\$', '€', '£', '¥', 'SAR', 'AED']
                                        .map((v) => DropdownMenuItem(
                                              value: v,
                                              child: Center(
                                                child: Text(
                                                  v,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black, // Black Text
                                                  ),
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (v) => ref.read(currencyProvider.notifier).state = v!,
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
                        Text(_editingExpenseId != null ? 'Edit Expense' : 'Add Expense', style: theme.textTheme.titleLarge?.copyWith(color: _editingExpenseId != null ? theme.colorScheme.primary : null)),
                        if (_editingExpenseId != null) TextButton(onPressed: _cancelEditing, child: const Text('Cancel')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Add Expense Card
                    Card(
                      elevation: _editingExpenseId != null ? 4 : 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: _editingExpenseId != null ? BorderSide(color: theme.colorScheme.primary, width: 2) : BorderSide.none),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Autocomplete<String>(
                                    optionsBuilder: (v) => v.text == '' ? const Iterable<String>.empty() : people.where((p) => p.name.toLowerCase().contains(v.text.toLowerCase())).map((p) => p.name),
                                    optionsViewBuilder: (ctx, onSel, opts) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4.0, borderRadius: BorderRadius.circular(16), color: theme.cardColor, child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200, maxWidth: 250), child: ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: opts.length, itemBuilder: (ctx, i) { final opt = opts.elementAt(i); return InkWell(onTap: () => onSel(opt), borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(16.0), child: Text(opt))); })))),
                                    onSelected: (s) => _personController.text = s,
                                    fieldViewBuilder: (ctx, ctrl, node, _) {
                                      if (_personController.text != ctrl.text) ctrl.text = _personController.text;
                                      ctrl.addListener(() => _personController.text = ctrl.text);
                                      return TextField(controller: ctrl, focusNode: node, decoration: const InputDecoration(labelText: 'Payer Name', hintText: 'e.g. John', prefixIcon: Icon(Icons.person_outline, size: 18)));
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(flex: 2, child: TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Amount', hintText: '0.0', prefixText: currency, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(children: [Expanded(child: TextField(controller: _descController, decoration: const InputDecoration(labelText: 'For what?', hintText: 'Meat, Taxi...', prefixIcon: Icon(Icons.notes, size: 18)))), const SizedBox(width: 12), IconButton.filled(onPressed: _addOrUpdateExpenseMerged, style: IconButton.styleFrom(backgroundColor: theme.colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(16)), icon: Icon(_editingExpenseId != null ? Icons.check : Icons.add), tooltip: _editingExpenseId != null ? 'Update Expense' : 'Add Expense')]),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Expenses List (Sliver)
            if (expenses.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final expense = expenses[index];
                      final payerName = people.firstWhere((p) => p.id == expense.payerId, orElse: () => Person(id: '', name: 'Unknown')).name;
                      final isEditing = expense.id == _editingExpenseId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => _startEditing(expense, payerName),
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: isEditing ? BorderSide(color: theme.colorScheme.primary, width: 2) : BorderSide.none),
                            tileColor: isEditing ? theme.colorScheme.primary.withValues(alpha: 0.05) : theme.cardColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            leading: CircleAvatar(backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1), radius: 18, child: Text(payerName.isNotEmpty ? payerName[0].toUpperCase() : '?', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))),
                            title: RichText(text: TextSpan(style: theme.textTheme.bodyMedium, children: [TextSpan(text: payerName, style: const TextStyle(fontWeight: FontWeight.bold)), const TextSpan(text: ' paid '), TextSpan(text: '$currency${expense.amount.toStringAsFixed(2)}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))])),
                            subtitle: expense.description.isNotEmpty ? Text(expense.description) : null,
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (!isEditing) const Icon(Icons.edit_outlined, size: 16, color: Colors.grey), const SizedBox(width: 8), IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () => ref.read(expensesProvider.notifier).removeExpense(expense.id))]),
                          ),
                        ),
                      ).animate().fadeIn().slideX(begin: 0.2, end: 0);
                    },
                    childCount: expenses.length,
                  ),
                ),
              ),
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
                        color: theme.colorScheme.primary, // Accent Color
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
                                  color: Colors.black54, // Black Font (Secondary)
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$currency${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.black, // Black Font (Primary)
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.black12, // Divider
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Per Person',
                                style: TextStyle(
                                  color: Colors.black54, // Black Font (Secondary)
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$currency${perPerson.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.black, // Black Font (Primary)
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
                      Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('No debts to settle yet.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))))
                    else
                      Column(
                        children: settlements.map((s) {
                          final isReceiving = s.amount > 0;
                          if (s.amount.abs() < 0.01) return const SizedBox.shrink();
                          Color color = isReceiving ? const Color(0xFF22c55e) : const Color(0xFFef4444);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(isReceiving ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20)),
                              title: Text(s.personName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(isReceiving ? 'Gets back' : 'Needs to pay', style: TextStyle(color: color, fontWeight: FontWeight.w500)),
                              trailing: Text('$currency${s.amount.abs().toStringAsFixed(2)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
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
  }
}