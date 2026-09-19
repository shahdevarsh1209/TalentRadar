import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat.dart';
import '../data/models/job.dart';
import '../data/models/people.dart';
import '../data/repositories/jobs_repository.dart';
import '../data/repositories/people_repository.dart';
import '../data/repositories/social_repository.dart';
import 'providers.dart';
import 'session_controller.dart';

final jobsRepositoryProvider = Provider<JobsRepository>(
  (ref) => JobsRepository(ref.watch(apiClientProvider)),
);

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => PeopleRepository(ref.watch(apiClientProvider)),
);

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(apiClientProvider)),
);

/// Every list re-fetches when the signed-in person changes (log out / in), so
/// nothing from one account can linger on screen for the next.
String? _sessionKey(Ref ref) => ref.watch(sessionProvider.select((s) => s?.user.userId));

final jobListProvider = FutureProvider.autoDispose.family<JobList, JobQuery>((ref, query) {
  _sessionKey(ref);
  return ref.watch(jobsRepositoryProvider).list(query);
});

final myJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) {
  _sessionKey(ref);
  return ref.watch(jobsRepositoryProvider).mine();
});

final nearbyCandidatesProvider =
    FutureProvider.autoDispose.family<CandidateList, CandidateQuery>((ref, query) {
  _sessionKey(ref);
  return ref.watch(peopleRepositoryProvider).nearby(query);
});

final savedProvider =
    FutureProvider.autoDispose<({List<Job> jobs, List<PersonSummary> people})>((ref) {
  _sessionKey(ref);
  return ref.watch(socialRepositoryProvider).saved();
});

final connectionsProvider = FutureProvider.autoDispose<ConnectionsOverview>((ref) {
  _sessionKey(ref);
  return ref.watch(socialRepositoryProvider).connections();
});

final conversationsProvider = FutureProvider.autoDispose<List<ConversationSummary>>((ref) {
  _sessionKey(ref);
  return ref.watch(socialRepositoryProvider).conversations();
});

final recruitersViewedProvider = FutureProvider.autoDispose<int>((ref) {
  _sessionKey(ref);
  return ref.watch(peopleRepositoryProvider).recruitersViewedMe();
});

/// Nav badges, refreshed every 20 seconds while the home screen is open.
/// A failed poll keeps the last value rather than flashing an error.
final badgesProvider = StreamProvider.autoDispose<Badges>((ref) {
  _sessionKey(ref);
  final repository = ref.watch(socialRepositoryProvider);
  final controller = StreamController<Badges>();
  Badges last = const Badges();

  Future<void> poll() async {
    try {
      last = await repository.badges();
    } catch (_) {
      // Keep the last known counts.
    }
    if (!controller.isClosed) controller.add(last);
  }

  poll();
  final timer = Timer.periodic(const Duration(seconds: 20), (_) => poll());
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Call after anything that changes what the lists show — saving, applying,
/// posting — so every tab that displays it is fresh next time it is read.
extension RefreshHome on WidgetRef {
  void refreshHome() {
    invalidate(jobListProvider);
    invalidate(myJobsProvider);
    invalidate(savedProvider);
    invalidate(nearbyCandidatesProvider);
    invalidate(conversationsProvider);
    invalidate(connectionsProvider);
    invalidate(badgesProvider);
  }
}
