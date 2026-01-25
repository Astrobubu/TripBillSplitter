import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_providers.dart';
import '../models/expense.dart';
import '../models/person.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesProvider);
    final peopleAsync = ref.watch(peopleProvider);
    final total = ref.watch(totalExpenseProvider);
    final currentTripAsync = ref.watch(currentTripProvider);
    final currency = currentTripAsync.value?.currency ?? '\$';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: expensesAsync.when(
        data: (expenses) => peopleAsync.when(
          data: (people) {
            if (expenses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No expenses yet',
                      style: theme.textTheme.headlineSmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add some expenses to see analytics',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            // Calculate spending by person
            final Map<String, double> spendingByPerson = {};
            for (final person in people) {
              final personExpenses = expenses.where((e) => e.payerId == person.id);
              final personTotal = personExpenses.fold(0.0, (sum, e) => sum + e.amount);
              spendingByPerson[person.name] = personTotal;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Total Expenses Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(Icons.attach_money, size: 48, color: Colors.green),
                          const SizedBox(height: 8),
                          Text(
                            'Total Expenses',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currency${total.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Spending by Person
                  Text(
                    'Spending by Person',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        height: 250,
                        child: people.isEmpty
                            ? const Center(child: Text('No data'))
                            : BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: spendingByPerson.values.isEmpty
                                      ? 100
                                      : spendingByPerson.values.reduce((a, b) => a > b ? a : b) * 1.2,
                                  barTouchData: BarTouchData(
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        return BarTooltipItem(
                                          '$currency${rod.toY.toStringAsFixed(2)}',
                                          const TextStyle(color: Colors.white),
                                        );
                                      },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          if (value.toInt() >= 0 && value.toInt() < people.length) {
                                            final person = people[value.toInt()];
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(
                                                person.name.length > 10
                                                    ? '${person.name.substring(0, 10)}...'
                                                    : person.name,
                                                style: const TextStyle(fontSize: 10),
                                              ),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            '$currency${value.toInt()}',
                                            style: const TextStyle(fontSize: 10),
                                          );
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: people.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final person = entry.value;
                                    final amount = spendingByPerson[person.name] ?? 0;

                                    return BarChartGroupData(
                                      x: index,
                                      barRods: [
                                        BarChartRodData(
                                          toY: amount,
                                          color: Colors.blue,
                                          width: 24,
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(6),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Expense Breakdown List
                  Text(
                    'Detailed Breakdown',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...people.map((person) {
                    final personTotal = spendingByPerson[person.name] ?? 0;
                    final percentage = total > 0 ? (personTotal / total * 100) : 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(person.name[0].toUpperCase()),
                        ),
                        title: Text(
                          person.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${percentage.toStringAsFixed(1)}% of total'),
                        trailing: Text(
                          '$currency${personTotal.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
