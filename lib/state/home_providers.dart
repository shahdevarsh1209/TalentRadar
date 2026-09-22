import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat.dart';
import '../data/models/hiring.dart';
import '../data/models/job.dart';
import '../data/models/people.dart';
import '../data/repositories/jobs_repository.dart';
import '../data/repositories/people_repository.dart';
import '../data/repositories/search_repository.dart';
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

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(apiClientProvider)),
);

/// Every list re-fetches when the signed-in person changes (log out / in), so
/// nothing from one account can linger on screen for the next.
String? _sessionKey(Ref ref) => ref.watch(sessionProvider.select((s) => s?.user.userId));

final jobListProvider = FutureProvider.autoDispose.family<JobList, JobQuery>((ref, query) {
  _sessionKey(ref);
  return ref.watch(jobsRepositoryProvider).list(query);
});

/// One job by id, for the chat's role banner and anywhere else that has only
/// an id. Kept separate from the lists so it caches per role.
final jobPreviewProvider = FutureProvider.autoDispose.family<Job, String>((ref, jobId) async {
  _sessionKey(ref);
  final result = await ref.watch(jobsRepositoryProvider).detail(jobId);
  return result.job;
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


final searchProvider = FutureProvider.autoDispose.family<SearchResults, SearchQuery>((ref, query) {
  _sessionKey(ref);
  return ref.watch(searchRepositoryProvider).search(query);
});

/// The recruiter profile behind every recruiter card in the app.
final recruiterProfileProvider =
    FutureProvider.autoDispose.family<RecruiterDetail, String>((ref, userId) {
  _sessionKey(ref);
  return ref.watch(searchRepositoryProvider).recruiter(userId);
});

final companyProfileProvider =
    FutureProvider.autoDispose.family<CompanyProfile, String>((ref, companyId) {
  _sessionKey(ref);
  return ref.watch(searchRepositoryProvider).company(companyId);
});

final blockedPeopleProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  _sessionKey(ref);
  return ref.watch(searchRepositoryProvider).blocked();
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
    // Hiring state is derived from open jobs, so closing or posting a role has
    // to refresh search and the profiles that show it too.
    invalidate(searchProvider);
    invalidate(recruiterProfileProvider);
    invalidate(companyProfileProvider);
  }
}
