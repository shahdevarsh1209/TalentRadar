import '../../core/network/api_client.dart';
import '../models/job_title.dart';

/// Reads the job-title master. A small cache keeps repeat keystrokes and the
/// re-opened selector instant, and lets the field keep working if the service
/// blips while the user is mid-search.
class JobTitleRepository {
  JobTitleRepository(this._api);

  final ApiClient _api;
  final Map<String, List<JobTitle>> _cache = {};

  Future<List<JobTitle>> search(String query, {int limit = 20}) async {
    final key = '${query.trim().toLowerCase()}|$limit';
    final cached = _cache[key];
    if (cached != null) return cached;

    final data = await _api.get('/job-titles', query: {'q': query.trim(), 'limit': limit});
    final results = (data['results'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(JobTitle.fromJson)
        .toList();

    _cache[key] = results;
    return results;
  }

  /// Popular titles shown before anyone types.
  Future<List<JobTitle>> popular({int limit = 20}) => search('', limit: limit);

  void clearCache() => _cache.clear();
}
