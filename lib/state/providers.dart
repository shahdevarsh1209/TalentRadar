import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/job_title_repository.dart';
import '../data/repositories/location_repository.dart';
import '../data/services/device_location_service.dart';
import '../data/services/session_store.dart';

/// Single HTTP client so the auth token set after registration is carried by
/// every later call without being threaded through the widget tree.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final jobTitleRepositoryProvider = Provider<JobTitleRepository>(
  (ref) => JobTitleRepository(ref.watch(apiClientProvider)),
);

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepository(ref.watch(apiClientProvider)),
);

final deviceLocationServiceProvider = Provider<DeviceLocationService>(
  (ref) => DeviceLocationService(),
);

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());
