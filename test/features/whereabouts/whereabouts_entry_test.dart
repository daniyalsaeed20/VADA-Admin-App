import 'package:flutter_test/flutter_test.dart';
import 'package:vada_admin_app/src/features/whereabouts/domain/whereabouts_entry.dart';

WhereaboutsEntry _entry({
  String recurrence = 'weekly',
  String? seriesId = 's1',
  List<int> weekdays = const [],
  String? start,
  String? end,
  int? months,
}) {
  return WhereaboutsEntry(
    id: 'e1',
    fighterId: 'f1',
    date: '2026-12-01',
    startTime: '13:00',
    endTime: '15:00',
    locationId: '',
    locationName: '',
    contactId: '',
    notes: '',
    recurrence: recurrence,
    createdAt: null,
    updatedAt: null,
    seriesId: seriesId,
    seriesWeekdays: weekdays,
    seriesStartDate: start,
    seriesEndDate: end,
    seriesMonths: months,
  );
}

void main() {
  test('normalizeRecurrence keeps none and defaults legacy to daily', () {
    expect(normalizeRecurrence('none'), 'none');
    expect(normalizeRecurrence(' Weekly '), 'weekly');
    expect(normalizeRecurrence(''), 'daily');
    expect(recurrenceDisplay('none'), 'Only once');
  });

  test('seriesSummary describes a weekly series', () {
    final e = _entry(
      weekdays: const [4, 2],
      start: '2026-12-01',
      end: '2026-12-31',
    );
    expect(seriesSummary(e), 'Weekly · Tue, Thu · 2026-12-01 to 2026-12-31');
  });

  test('seriesSummary describes a monthly series', () {
    final e = _entry(recurrence: 'monthly', start: '2026-11-20', months: 3);
    expect(seriesSummary(e), 'Monthly · day 20 · 3 months · from 2026-11-20');
  });

  test('single entries have no summary', () {
    expect(seriesSummary(_entry(seriesId: null)), '');
  });
}
