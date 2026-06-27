import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../day/data/day_repository.dart';
import '../../day/models/day_model.dart';
import '../models/dtos/summary_dto.dart';

final daySyncServiceProvider = Provider<DaySyncService>((ref) {
  return DaySyncService(ref.read(dayRepositoryProvider));
});

class DaySyncService {
  final DayRepository _repository;

  DaySyncService(this._repository);

  Future<DayModel?> getDay(String uid, DateTime date) {
    return _repository.getDay(uid, date);
  }

  Future<void> syncDaySummary(String uid, DateTime date, SummaryDto summaryDto) async {
    var day = await getDay(uid, date);
    
    if (day == null) {
      day = DayModel(
        date: date,
        summary: summaryDto.summary,
        summaryMode: 'auto',
        reflectionCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      if (day.summaryMode == 'auto') {
        day = day.copyWith(
          summary: summaryDto.summary,
          reflectionCount: day.reflectionCount + 1,
          updatedAt: DateTime.now(),
        );
      } else {
        // If summary mode is manual, just update reflection count.
        day = day.copyWith(
          reflectionCount: day.reflectionCount + 1,
          updatedAt: DateTime.now(),
        );
      }
    }
    
    await _repository.saveDay(uid, day);
  }
}
