import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_log_in/providers/auth_provider.dart';

// Example state providers for track page
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final trackItemsProvider = StateProvider<List<String>>((ref) => []);

class TrackPage extends ConsumerWidget {
  const TrackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the states
    final selectedDate = ref.watch(selectedDateProvider);
    final trackItems = ref.watch(trackItemsProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                ref.read(selectedDateProvider.notifier).state = picked;
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Track Page', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Text(
              'Selected Date: ${selectedDate.toString().split(' ')[0]}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            // Add your track page widgets here
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new tracking item functionality will be implemented here
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
