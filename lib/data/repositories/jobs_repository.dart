import '../../core/network/api_client.dart';
import '../models/job.dart';
import '../models/people.dart';

class JobsRepository {
  JobsRepository(this._api);

  final ApiClient _api;

  Future<JobList> list(JobQuery query) async {
    final data = await _api.get('/jobs', query: query.toQuery());
    return JobList(
      jobs: (data['jobs'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Job.fromJson)
          .toList(),
      meta: JobListMeta.fromJson(data['meta'] as Map<String, dynamic>?),
    );
  }

  Future<({Job job, PersonSummary postedBy})> detail(String jobId) async {
    final data = await _api.get('/jobs/$jobId');
    return (
      job: Job.fromJson(data['job'] as Map<String, dynamic>),
      postedBy: PersonSummary.fromJson(data['postedBy'] as Map<String, dynamic>?),
    );
  }

  /// "I'm interested" / "Meet in person". Returns the chat it opened.
  Future<String> expressInterest(String jobId) async {
    final data = await _api.post('/jobs/$jobId/interest');
    return '${data['conversationId']}';
  }

  Future<Job> create(JobDraft draft) async {
    final data = await _api.post('/jobs', body: draft.toRequest());
    return Job.fromJson(data['job'] as Map<String, dynamic>);
  }

  Future<List<Job>> mine() async {
    final data = await _api.get('/recruiters/me/jobs');
    return (data['jobs'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Job.fromJson)
        .toList();
  }

  Future<Job> setStatus(String jobId, {required bool open}) async {
    final data = await _api.patch('/jobs/$jobId/status', body: {'status': open ? 'open' : 'closed'});
    return Job.fromJson(data['job'] as Map<String, dynamic>);
  }

  /// Candidates who raised their hand for one of my roles.
  Future<List<({PersonSummary person, DateTime? at})>> interests(String jobId) async {
    final data = await _api.get('/jobs/$jobId/interests');
    return (data['candidates'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) => (
              person: PersonSummary.fromJson(item),
              at: DateTime.tryParse('${item['interestedAt']}')?.toLocal(),
            ))
        .toList();
  }
}
