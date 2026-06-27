import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/mood_repository.dart';
import '../../../core/utils/date_utils.dart';

final dayMoodsProvider = StreamProvider.family<dynamic, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  
  return ref.watch(moodRepositoryProvider).watchMoods(user.uid).map((moods) {
    final key = OrbitDateUtils.dateKey(date);
    return moods.where((m) => OrbitDateUtils.dateKey(m.date) == key).toList();
  });
});

class MoodSection extends ConsumerWidget {
  final DateTime date;

  const MoodSection({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodsAsync = ref.watch(dayMoodsProvider(date));

    return moodsAsync.when(
      data: (moods) {
        if (moods == null || moods.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Mood Timeline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Wrap(
              spacing: 8.0,
              children: moods.map((m) => Chip(
                avatar: const Icon(Icons.mood, size: 16),
                label: Text('${m.timeOfDay}: ${m.value}/5'),
                backgroundColor: _getColorForMood(m.value),
              )).toList(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error: $e'),
    );
  }

  Color _getColorForMood(int value) {
    switch (value) {
      case 5: return Colors.green.shade200;
      case 4: return Colors.lightGreen.shade200;
      case 3: return Colors.yellow.shade200;
      case 2: return Colors.orange.shade200;
      case 1: return Colors.red.shade200;
      default: return Colors.grey.shade200;
    }
  }
}
