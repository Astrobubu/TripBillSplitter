import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../models/payment.dart';
import '../models/person.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final paymentsAsync = ref.watch(paymentsProvider);
    final peopleAsync = ref.watch(peopleProvider);
    final currentTrip = ref.watch(currentTripProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
      ),
      body: paymentsAsync.when(
        data: (payments) => peopleAsync.when(
          data: (people) {
            if (payments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No payments recorded',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Payments are tracked automatically\nwhen you settle up on the main page',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            final dateFormat = DateFormat('MMM d, h:mm a');

            // Helper to safely get person name
            String getPersonName(String personId) {
              try {
                return people.firstWhere((p) => p.id == personId).name;
              } catch (_) {
                return 'Unknown';
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                final fromName = getPersonName(payment.fromPersonId);
                final toName = getPersonName(payment.toPersonId);
                final isCompleted = payment.status == PaymentStatus.completed;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isCompleted
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      child: Icon(
                        isCompleted ? Icons.check : Icons.schedule,
                        color: isCompleted ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(fromName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Icon(Icons.arrow_forward, size: 16),
                        Text(toName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    subtitle: Text(
                      dateFormat.format(payment.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    trailing: currentTrip.when(
                      data: (trip) => Text(
                        '${trip?.currency ?? '\$'}${payment.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCompleted ? Colors.green : Colors.orange,
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading')),
      ),
    );
  }
}
