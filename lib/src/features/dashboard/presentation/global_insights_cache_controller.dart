import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../whereabouts/presentation/whereabouts_controller.dart';
import '../../whereabouts/domain/whereabouts_entry.dart';

DateTime? _tryParseYmd(String raw) {
  final v = raw.trim();
  if (v.length != 10) return null;
  final year = int.tryParse(v.substring(0, 4));
  final month = int.tryParse(v.substring(5, 7));
  final day = int.tryParse(v.substring(8, 10));
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isInNext7DaysInclusive(DateTime day, DateTime today) {
  final end = today.add(const Duration(days: 7));
  return !day.isBefore(today) && !day.isAfter(end);
}

class GlobalInsightsCacheState {
  const GlobalInsightsCacheState({
    required this.schedulesToday,
    required this.schedulesNext7Days,
    required this.updatedAtMillis,
    required this.isInitialized,
  });

  final int schedulesToday;
  final int schedulesNext7Days;
  final int? updatedAtMillis;
  final bool isInitialized;

  DateTime? get updatedAt => updatedAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(updatedAtMillis!);

  GlobalInsightsCacheState copyWith({
    int? schedulesToday,
    int? schedulesNext7Days,
    int? updatedAtMillis,
    bool? isInitialized,
  }) {
    return GlobalInsightsCacheState(
      schedulesToday: schedulesToday ?? this.schedulesToday,
      schedulesNext7Days: schedulesNext7Days ?? this.schedulesNext7Days,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class GlobalInsightsCacheController extends StateNotifier<GlobalInsightsCacheState> {
  GlobalInsightsCacheController(this._ref)
      : super(const GlobalInsightsCacheState(
          schedulesToday: 0,
          schedulesNext7Days: 0,
          updatedAtMillis: null,
          isInitialized: false,
        )) {
    _load();
  }

  static const _key = 'dashboard.global_insights.v1';
  final Ref _ref;

  Future<void> _load() async {
    final store = _ref.read(keyValueStoreProvider);
    final raw = await store.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      state = state.copyWith(isInitialized: true);
      return;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = GlobalInsightsCacheState(
        schedulesToday: (json['schedulesToday'] as num?)?.toInt() ?? 0,
        schedulesNext7Days: (json['schedulesNext7Days'] as num?)?.toInt() ?? 0,
        updatedAtMillis: (json['updatedAtMillis'] as num?)?.toInt(),
        isInitialized: true,
      );
    } catch (_) {
      state = state.copyWith(isInitialized: true);
    }
  }

  Future<void> _save(GlobalInsightsCacheState next) async {
    final store = _ref.read(keyValueStoreProvider);
    final payload = jsonEncode({
      'schedulesToday': next.schedulesToday,
      'schedulesNext7Days': next.schedulesNext7Days,
      'updatedAtMillis': next.updatedAtMillis,
    });
    await store.setString(_key, payload);
  }

  Future<void> updateFromLive(List<WhereaboutsEntry> entries) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var todayCount = 0;
    var next7Count = 0;
    for (final e in entries) {
      final day = _tryParseYmd(e.date);
      if (day == null) continue;
      if (_isSameDay(day, today)) todayCount++;
      if (_isInNext7DaysInclusive(day, today)) next7Count++;
    }

    final next = state.copyWith(
      schedulesToday: todayCount,
      schedulesNext7Days: next7Count,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      isInitialized: true,
    );
    state = next;
    await _save(next);
  }
}

final globalInsightsCacheControllerProvider = StateNotifierProvider<
    GlobalInsightsCacheController, GlobalInsightsCacheState>(
  (ref) => GlobalInsightsCacheController(ref),
);

/// Keeps the cache warm whenever live schedules update.
final globalInsightsCacheSyncProvider = Provider<void>((ref) {
  ref.listen(whereaboutsStreamProvider, (prev, next) {
    next.whenOrNull(
      data: (items) => ref
          .read(globalInsightsCacheControllerProvider.notifier)
          .updateFromLive(items),
    );
  });
});

