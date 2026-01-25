import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../models/change_log.dart';
import '../models/payment.dart';
import '../models/settlement_info.dart';
import '../services/database_service.dart';

// -----------------------------------------------------------------------------
// CURRENT TRIP PROVIDER
// -----------------------------------------------------------------------------
final currentTripIdProvider = StateProvider<String?>((ref) => null);

// -----------------------------------------------------------------------------
// TRIPS PROVIDER
// -----------------------------------------------------------------------------
final tripsProvider = StateNotifierProvider<TripsNotifier, AsyncValue<List<Trip>>>((ref) {
  return TripsNotifier();
});

class TripsNotifier extends StateNotifier<AsyncValue<List<Trip>>> {
  TripsNotifier() : super(const AsyncValue.loading()) {
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final trips = await DatabaseService.instance.getAllTrips();
      state = AsyncValue.data(trips);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Trip> createTrip(
    String name, {
    String currency = '\$',
    int totalParticipants = 0,
    int? iconCodePoint,
    int? colorValue,
  }) async {
    final trip = Trip(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
      currency: currency,
      totalParticipants: totalParticipants,
      iconCodePoint: iconCodePoint ?? 0xe540,
      colorValue: colorValue ?? 0xFF2196F3,
    );

    await DatabaseService.instance.createTrip(trip);
    await _loadTrips();

    // Log the change
    await DatabaseService.instance.createChangeLog(
      ChangeLogEntry(
        id: const Uuid().v4(),
        tripId: trip.id,
        changeType: ChangeType.tripCreated,
        timestamp: DateTime.now(),
        description: 'Trip "${trip.name}" created',
      ),
    );

    return trip;
  }

  Future<void> updateTrip(Trip trip) async {
    await DatabaseService.instance.updateTrip(trip.copyWith(updatedAt: DateTime.now()));
    await _loadTrips();

    // Log the change
    await DatabaseService.instance.createChangeLog(
      ChangeLogEntry(
        id: const Uuid().v4(),
        tripId: trip.id,
        changeType: ChangeType.tripUpdated,
        timestamp: DateTime.now(),
        description: 'Trip "${trip.name}" updated',
      ),
    );
  }

  Future<void> deleteTrip(String tripId) async {
    await DatabaseService.instance.deleteTrip(tripId);
    await _loadTrips();
  }

  Future<void> archiveTrip(String tripId) async {
    final trip = await DatabaseService.instance.getTripById(tripId);
    if (trip != null) {
      await DatabaseService.instance.updateTrip(trip.copyWith(isArchived: !trip.isArchived, updatedAt: DateTime.now()));
      await _loadTrips();
    }
  }

  void refresh() => _loadTrips();
}

// -----------------------------------------------------------------------------
// PEOPLE PROVIDER
// -----------------------------------------------------------------------------
final peopleProvider = StateNotifierProvider<PeopleNotifier, AsyncValue<List<Person>>>((ref) {
  final currentTripId = ref.watch(currentTripIdProvider);
  final tripsNotifier = ref.read(tripsProvider.notifier);
  return PeopleNotifier(currentTripId, tripsNotifier);
});

class PeopleNotifier extends StateNotifier<AsyncValue<List<Person>>> {
  final String? tripId;
  final TripsNotifier tripsNotifier;

  PeopleNotifier(this.tripId, this.tripsNotifier) : super(const AsyncValue.loading()) {
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    if (tripId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final peopleRaw = await DatabaseService.instance.getPeopleByTripId(tripId!);
      // Filter out internal "ghost" users used for anonymous payments
      final people = peopleRaw.where((p) => !p.id.startsWith('anonymous_')).toList();
      state = AsyncValue.data(people);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Person> addPerson(String name, {String? phoneNumber}) async {
    if (name.trim().isEmpty || tripId == null) {
      throw Exception('Invalid name or trip ID');
    }

    // 1. Create the person
    final person = Person(
      id: const Uuid().v4(),
      name: name.trim(),
      tripId: tripId!,
      phoneNumber: phoneNumber,
    );

    await DatabaseService.instance.createPerson(person);
    
    // 2. Update Trip participant count
    final trip = await DatabaseService.instance.getTripById(tripId!);
    if (trip != null) {
      await DatabaseService.instance.updateTrip(
        trip.copyWith(totalParticipants: trip.totalParticipants + 1)
      );
      // Notify trips provider to reload
      tripsNotifier.refresh();
    }

    await _loadPeople();

    // Log the change
    await DatabaseService.instance.createChangeLog(
      ChangeLogEntry(
        id: const Uuid().v4(),
        tripId: tripId!,
        changeType: ChangeType.personAdded,
        timestamp: DateTime.now(),
        description: 'Added person: ${person.name}',
      ),
    );

    return person;
  }

  Future<void> addPeople(List<Map<String, String?>> peopleData) async {
    if (tripId == null || peopleData.isEmpty) return;

    // Batch insertion could be optimized with a transaction, but loop is fine for <100 contacts
    for (final data in peopleData) {
      final name = data['name'];
      if (name == null || name.isEmpty) continue;

      final person = Person(
        id: const Uuid().v4(),
        name: name,
        tripId: tripId!,
        phoneNumber: data['phone'],
      );
      await DatabaseService.instance.createPerson(person);
    }

    // Update total count once
    final trip = await DatabaseService.instance.getTripById(tripId!);
    if (trip != null) {
      await DatabaseService.instance.updateTrip(
        trip.copyWith(totalParticipants: trip.totalParticipants + peopleData.length)
      );
      tripsNotifier.refresh();
    }

    await _loadPeople();
  }

  Future<void> addPersonFromContact(String name, String? phoneNumber) async {
    // Check if phone number already exists in this trip to avoid duplicates (optional but good UX)
    // For now, just add.
    await addPerson(name, phoneNumber: phoneNumber);
  }

  Future<void> removePerson(String id) async {
    final person = await DatabaseService.instance.getPersonById(id);
    await DatabaseService.instance.deletePerson(id);
    
    // Decrease trip count if possible
    final trip = await DatabaseService.instance.getTripById(tripId!);
    if (trip != null && trip.totalParticipants > 0) {
       await DatabaseService.instance.updateTrip(
        trip.copyWith(totalParticipants: trip.totalParticipants - 1)
      );
      tripsNotifier.refresh();
    }

    await _loadPeople();

    // Log the change
    if (person != null && tripId != null) {
      await DatabaseService.instance.createChangeLog(
        ChangeLogEntry(
          id: const Uuid().v4(),
          tripId: tripId!,
          changeType: ChangeType.personRemoved,
          timestamp: DateTime.now(),
          description: 'Removed person: ${person.name}',
        ),
      );
    }
  }

  Future<void> updatePerson(Person person) async {
    await DatabaseService.instance.updatePerson(person);
    await _loadPeople();
    
    // Log the change
    if (tripId != null) {
      await DatabaseService.instance.createChangeLog(
        ChangeLogEntry(
          id: const Uuid().v4(),
          tripId: tripId!,
          changeType: ChangeType.personUpdated, 
          timestamp: DateTime.now(),
          description: 'Updated person: ${person.name}',
        ),
      );
    }
  }
  
  Future<void> setParticipantCount(int targetCount) async {
    if (tripId == null || targetCount < 0) return;
    
    // 1. Get current state
    final currentTrip = await DatabaseService.instance.getTripById(tripId!);
    final currentPeople = await DatabaseService.instance.getPeopleByTripId(tripId!);
    final currentPeopleCount = currentPeople.length;
    
    // 2. Update the Trip's totalParticipants
    if (currentTrip != null) {
      await DatabaseService.instance.updateTrip(
        currentTrip.copyWith(totalParticipants: targetCount)
      );
      tripsNotifier.refresh();
    }
    
    // 3. Adjust people list to match targetCount
    if (targetCount > currentPeopleCount) {
      // Add generic people directly (bypass addPerson to avoid any side effects)
      for (int i = currentPeopleCount + 1; i <= targetCount; i++) {
        final person = Person(
          id: const Uuid().v4(),
          name: 'Person $i',
          tripId: tripId!,
        );
        await DatabaseService.instance.createPerson(person);
      }
    } else if (targetCount < currentPeopleCount) {
      // Remove excess people from the end
      final toRemove = currentPeopleCount - targetCount;
      for (int i = 0; i < toRemove; i++) {
        final personToRemove = currentPeople[currentPeople.length - 1 - i];
        await DatabaseService.instance.deletePerson(personToRemove.id);
      }
    }
    
    // 4. Reload the people list to update UI
    await _loadPeople();
  }

  void refresh() => _loadPeople();
}

// -----------------------------------------------------------------------------
// EXPENSES PROVIDER
// -----------------------------------------------------------------------------
final expensesProvider = StateNotifierProvider<ExpensesNotifier, AsyncValue<List<Expense>>>((ref) {
  final currentTripId = ref.watch(currentTripIdProvider);
  return ExpensesNotifier(currentTripId);
});

class ExpensesNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final String? tripId;

  ExpensesNotifier(this.tripId) : super(const AsyncValue.loading()) {
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    if (tripId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final expenses = await DatabaseService.instance.getExpensesByTripId(tripId!);
      state = AsyncValue.data(expenses);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Expense> addExpense(String description, double amount, String payerId) async {
    if (tripId == null) {
      throw Exception('No active trip');
    }

    final expense = Expense(
      id: const Uuid().v4(),
      description: description,
      amount: amount,
      payerId: payerId,
      tripId: tripId!,
      createdAt: DateTime.now(),
    );

    await DatabaseService.instance.createExpense(expense);
    await _loadExpenses();

    // Log the change
    final trip = await DatabaseService.instance.getTripById(tripId!);
    final currency = trip?.currency ?? '';
    await DatabaseService.instance.createChangeLog(
      ChangeLogEntry(
        id: const Uuid().v4(),
        tripId: tripId!,
        changeType: ChangeType.expenseAdded,
        timestamp: DateTime.now(),
        description: 'Added expense: $description - $currency${amount.toStringAsFixed(2)}',
        metadata: {'expenseId': expense.id},
      ),
    );

    return expense;
  }

  Future<void> updateExpense(String id, String description, double amount, String payerId) async {
    if (tripId == null) return;

    final expenses = state.value ?? [];
    final existingExpense = expenses.firstWhere(
      (e) => e.id == id, 
      orElse: () => Expense(
        id: id, 
        description: '', 
        amount: 0, 
        payerId: '', 
        tripId: tripId!, 
        createdAt: DateTime.now()
      )
    );

    final expense = Expense(
      id: id,
      description: description,
      amount: amount,
      payerId: payerId,
      tripId: tripId!,
      createdAt: existingExpense.createdAt,
      updatedAt: DateTime.now(),
    );

    await DatabaseService.instance.updateExpense(expense);
    await _loadExpenses();

    // Log the change
    final trip = await DatabaseService.instance.getTripById(tripId!);
    final currency = trip?.currency ?? '';
    await DatabaseService.instance.createChangeLog(
      ChangeLogEntry(
        id: const Uuid().v4(),
        tripId: tripId!,
        changeType: ChangeType.expenseUpdated,
        timestamp: DateTime.now(),
        description: 'Updated expense: $description - $currency${amount.toStringAsFixed(2)}',
        metadata: {'expenseId': id},
      ),
    );
  }

  Future<void> removeExpense(String id) async {
    await DatabaseService.instance.deleteExpense(id);
    await _loadExpenses();

    // Log the change
    if (tripId != null) {
      await DatabaseService.instance.createChangeLog(
        ChangeLogEntry(
          id: const Uuid().v4(),
          tripId: tripId!,
          changeType: ChangeType.expenseDeleted,
          timestamp: DateTime.now(),
          description: 'Deleted expense',
          metadata: {'expenseId': id},
        ),
      );
    }
  }

  void refresh() => _loadExpenses();
}

// -----------------------------------------------------------------------------
// PAYMENTS PROVIDER
// -----------------------------------------------------------------------------
final paymentsProvider = StateNotifierProvider<PaymentsNotifier, AsyncValue<List<Payment>>>((ref) {
  final currentTripId = ref.watch(currentTripIdProvider);
  return PaymentsNotifier(currentTripId);
});

class PaymentsNotifier extends StateNotifier<AsyncValue<List<Payment>>> {
  final String? tripId;

  PaymentsNotifier(this.tripId) : super(const AsyncValue.loading()) {
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    if (tripId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final payments = await DatabaseService.instance.getPaymentsByTripId(tripId!);
      state = AsyncValue.data(payments);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Payment> addPayment({
    required String fromPersonId,
    required String toPersonId,
    required double amount,
    String? note,
  }) async {
    if (tripId == null) {
      throw Exception('No active trip');
    }

    // 1. Handle "Ghost" users for anonymous payments
    // If we are settling with "Others", we need a real DB entity to satisfy Foreign Keys
    if (fromPersonId.startsWith('anonymous_') || toPersonId.startsWith('anonymous_')) {
      final ghostId = fromPersonId.startsWith('anonymous_') ? fromPersonId : toPersonId;
      final ghostExists = await DatabaseService.instance.getPersonById(ghostId);
      
      if (ghostExists == null) {
        // Create the ghost "Others" user silently
        await DatabaseService.instance.createPerson(Person(
          id: ghostId,
          name: 'Others',
          tripId: tripId!,
        ));
      }
    }

    final payment = Payment(
      id: const Uuid().v4(),
      tripId: tripId!,
      fromPersonId: fromPersonId,
      toPersonId: toPersonId,
      amount: amount,
      createdAt: DateTime.now(),
      status: PaymentStatus.completed,
      note: note,
    );

    await DatabaseService.instance.createPayment(payment);
    await _loadPayments();

    // Log the change
    final trip = await DatabaseService.instance.getTripById(tripId!);
    final currency = trip?.currency ?? '';
    await DatabaseService.instance.createChangeLog(
      ChangeLogEntry(
        id: const Uuid().v4(),
        tripId: tripId!,
        changeType: ChangeType.paymentAdded,
        timestamp: DateTime.now(),
        description: 'Payment recorded: $currency${amount.toStringAsFixed(2)}',
      ),
    );

    return payment;
  }

  Future<void> markAsCompleted(String paymentId) async {
    final payments = state.value ?? [];
    final payment = payments.firstWhere((p) => p.id == paymentId);

    final updatedPayment = payment.copyWith(
      status: PaymentStatus.completed,
      completedAt: DateTime.now(),
    );

    await DatabaseService.instance.updatePayment(updatedPayment);
    await _loadPayments();

    // Log the change
    // Log the change
    final trip = await DatabaseService.instance.getTripById(tripId!);
    final currency = trip?.currency ?? '';
    await DatabaseService.instance.createChangeLog(
      ChangeLogEntry(
        id: const Uuid().v4(),
        tripId: tripId!,
        changeType: ChangeType.paymentUpdated,
        timestamp: DateTime.now(),
        description: 'Payment marked as completed for $currency${payment.amount.toStringAsFixed(2)}',
      ),
    );
  }

  void refresh() => _loadPayments();
}

// -----------------------------------------------------------------------------
// CHANGE LOG PROVIDER
// -----------------------------------------------------------------------------
final changeLogsProvider = FutureProvider.family<List<ChangeLogEntry>, String>((ref, tripId) async {
  return await DatabaseService.instance.getChangeLogsByTripId(tripId, limit: 50);
});

// -----------------------------------------------------------------------------
// COMPUTED PROVIDERS
// -----------------------------------------------------------------------------
final currentTripProvider = Provider<AsyncValue<Trip?>>((ref) {
  final tripsAsync = ref.watch(tripsProvider);
  final currentId = ref.watch(currentTripIdProvider);

  return tripsAsync.whenData((trips) {
    if (currentId == null) return null;
    try {
      return trips.firstWhere((t) => t.id == currentId);
    } catch (_) {
      return null;
    }
  });
});

final totalExpenseProvider = Provider<double>((ref) {
  final expensesAsync = ref.watch(expensesProvider);
  return expensesAsync.when(
    data: (expenses) => expenses.fold(0.0, (sum, item) => sum + item.amount),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

final settlementsProvider = Provider<List<SettlementInfo>>((ref) {
  final peopleAsync = ref.watch(peopleProvider);
  final expensesAsync = ref.watch(expensesProvider);
  final paymentsAsync = ref.watch(paymentsProvider);
  final total = ref.watch(totalExpenseProvider);
  final currentTrip = ref.watch(currentTripProvider);

  return peopleAsync.when(
    data: (people) => expensesAsync.when(
      data: (expenses) => paymentsAsync.when(
        data: (payments) => currentTrip.when(
          data: (trip) {
            if (trip == null || total == 0 || trip.totalParticipants == 0) return [];

            // Always use the trip's totalParticipants, never auto-increase it
            final effectiveCount = trip.totalParticipants;
            final average = total / effectiveCount;

            List<SettlementInfo> results = [];

            for (var person in people) {
              double paid = expenses
                  .where((e) => e.payerId == person.id)
                  .fold(0.0, (sum, e) => sum + e.amount);

              // Adjust for completed payments
              double paymentsReceived = payments
                  .where((p) => p.toPersonId == person.id && p.status == PaymentStatus.completed)
                  .fold(0.0, (sum, p) => sum + p.amount);

              double paymentsMade = payments
                  .where((p) => p.fromPersonId == person.id && p.status == PaymentStatus.completed)
                  .fold(0.0, (sum, p) => sum + p.amount);

              // Corrected Math:
              // - Expenses paid (Credit)
              // - Fair share (Debit)
              // - Payments Received (Reduces Credit - I got my money back)
              // - Payments Made (Reduces Debt - I paid my dues)
              double netAmount = paid - average - paymentsReceived + paymentsMade;

              results.add(SettlementInfo(
                personName: person.name,
                personId: person.id,
                amount: netAmount,
              ));
            }

            int anonymousCount = effectiveCount - people.length;
            if (anonymousCount > 0) {
              final anonId = 'anonymous_${trip.id}';
              
              double anonymousPaymentsMade = payments
                  .where((p) => p.fromPersonId == anonId && p.status == PaymentStatus.completed)
                  .fold(0.0, (sum, p) => sum + p.amount);

              // We don't usually track payments RECEIVED by anonymous (unless they overpaid?), 
              // but for symmetry/correctness we could. 
              // For now, let's just assume they are paying off their debt.
              
              results.add(SettlementInfo(
                personName: '$anonymousCount Others',
                personId: anonId,
                amount: -(average * anonymousCount) + anonymousPaymentsMade,
                isAnonymous: true,
              ));
            }

            results.sort((a, b) => b.amount.compareTo(a.amount));
            return results;
          },
          loading: () => [],
          error: (_, __) => [],
        ),
        loading: () => [],
        error: (_, __) => [],
      ),
      loading: () => [],
      error: (_, __) => [],
    ),
    loading: () => [],
    error: (_, __) => [],
  );
});

// -----------------------------------------------------------------------------
// SMART SETTLEMENT (Who pays whom)
// -----------------------------------------------------------------------------
class SmartSettlement {
  final String fromPersonId;
  final String fromPersonName;
  final String toPersonId;
  final String toPersonName;
  final double amount;
  final bool isAnonymous;

  SmartSettlement({
    required this.fromPersonId,
    required this.fromPersonName,
    required this.toPersonId,
    required this.toPersonName,
    required this.amount,
    this.isAnonymous = false,
  });
}

final smartSettlementsProvider = Provider<List<SmartSettlement>>((ref) {
  final settlements = ref.watch(settlementsProvider);
  final paymentsAsync = ref.watch(paymentsProvider);
  
  if (settlements.isEmpty) return [];
  
  final payments = paymentsAsync.value ?? [];
  
  // Separate creditors (positive balance) and debtors (negative balance)
  List<SettlementInfo> creditors = settlements.where((s) => s.amount > 0.01).toList();
  List<SettlementInfo> debtors = settlements.where((s) => s.amount < -0.01).toList();
  
  if (creditors.isEmpty || debtors.isEmpty) return [];
  
  // Create a copy of balances to work with
  Map<String, double> creditBalances = {
    for (var c in creditors) c.personId: c.amount
  };
  Map<String, double> debtBalances = {
    for (var d in debtors) d.personId: d.amount.abs()
  };
  
  List<SmartSettlement> transactions = [];
  
  // Match debtors to creditors (greedy approach)
  for (var debtor in debtors) {
    double remainingDebt = debtBalances[debtor.personId] ?? 0;
    
    for (var creditor in creditors) {
      if (remainingDebt < 0.01) break;
      
      double availableCredit = creditBalances[creditor.personId] ?? 0;
      if (availableCredit < 0.01) continue;
      
      double transferAmount = remainingDebt < availableCredit 
          ? remainingDebt 
          : availableCredit;
      
      transactions.add(SmartSettlement(
        fromPersonId: debtor.personId,
        fromPersonName: debtor.personName,
        toPersonId: creditor.personId,
        toPersonName: creditor.personName,
        amount: transferAmount,
        isAnonymous: debtor.isAnonymous,
      ));
      
      remainingDebt -= transferAmount;
      creditBalances[creditor.personId] = availableCredit - transferAmount;
    }
  }
  
  return transactions;
});

