import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../models/payment.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  void _showAddPaymentDialog() {
    final peopleAsync = ref.read(peopleProvider);
    final settlements = ref.read(settlementsProvider);

    peopleAsync.whenData((people) {
      if (people.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add people first before recording payments')),
        );
        return;
      }

      String? fromPersonId;
      String? toPersonId;
      final amountController = TextEditingController();
      final noteController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Record Payment'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'From (Payer)',
                          prefixIcon: Icon(Icons.person),
                        ),
                        value: fromPersonId,
                        items: people
                            .where((p) => !p.id.startsWith('anonymous'))
                            .map((person) => DropdownMenuItem(
                                  value: person.id,
                                  child: Text(person.name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            fromPersonId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'To (Receiver)',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        value: toPersonId,
                        items: people
                            .where((p) => !p.id.startsWith('anonymous') && p.id != fromPersonId)
                            .map((person) => DropdownMenuItem(
                                  value: person.id,
                                  child: Text(person.name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            toPersonId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'Note (Optional)',
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 2,
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
                      if (fromPersonId != null &&
                          toPersonId != null &&
                          amountController.text.isNotEmpty) {
                        final amount = double.tryParse(amountController.text);
                        if (amount != null && amount > 0) {
                          await ref.read(paymentsProvider.notifier).addPayment(
                                fromPersonId: fromPersonId!,
                                toPersonId: toPersonId!,
                                amount: amount,
                                note: noteController.text.isEmpty ? null : noteController.text,
                              );
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      }
                    },
                    child: const Text('Record'),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paymentsAsync = ref.watch(paymentsProvider);
    final peopleAsync = ref.watch(peopleProvider);
    final currentTrip = ref.watch(currentTripProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Tracking'),
      ),
      body: paymentsAsync.when(
        data: (payments) => peopleAsync.when(
          data: (people) {
            if (payments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.payment,
                      size: 80,
                      color: Colors.grey,
                    ).animate().scale(),
                    const SizedBox(height: 16),
                    Text(
                      'No payments yet',
                      style: theme.textTheme.headlineSmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Record payments to track who has paid',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _showAddPaymentDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Record Payment'),
                    ),
                  ],
                ),
              );
            }

            final dateFormat = DateFormat('MMM d, yyyy h:mm a');

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                final fromPerson = people.firstWhere(
                  (p) => p.id == payment.fromPersonId,
                  orElse: () => throw Exception('Person not found'),
                );
                final toPerson = people.firstWhere(
                  (p) => p.id == payment.toPersonId,
                  orElse: () => throw Exception('Person not found'),
                );

                final statusColor = payment.status == PaymentStatus.completed
                    ? Colors.green
                    : payment.status == PaymentStatus.pending
                        ? Colors.orange
                        : Colors.grey;

                final statusText = payment.status == PaymentStatus.completed
                    ? 'Completed'
                    : payment.status == PaymentStatus.pending
                        ? 'Pending'
                        : 'Cancelled';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        payment.status == PaymentStatus.completed
                            ? Icons.check_circle
                            : Icons.payment,
                        color: statusColor,
                      ),
                    ),
                    title: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyLarge,
                        children: [
                          TextSpan(
                            text: fromPerson.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' paid '),
                          TextSpan(
                            text: toPerson.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(payment.createdAt),
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (payment.note != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            payment.note!,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        currentTrip.when(
                          data: (trip) => Text(
                            '${trip?.currency ?? '\$'}${payment.amount.toStringAsFixed(2)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        if (payment.status == PaymentStatus.pending)
                          TextButton(
                            onPressed: () {
                              ref.read(paymentsProvider.notifier).markAsCompleted(payment.id);
                            },
                            child: const Text('Mark Paid'),
                          ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().slideX();
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaymentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
      ),
    );
  }
}
