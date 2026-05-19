import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/checkins_repository.dart';
import '../domain/checkin_record.dart';

final checkinsRepositoryProvider = Provider<CheckinsRepository>((ref) {
  return CheckinsRepository(ref.watch(firestoreProvider));
});

final checkinsStreamProvider = StreamProvider<List<CheckinRecord>>((ref) {
  return ref.watch(checkinsRepositoryProvider).watchCheckins();
});
