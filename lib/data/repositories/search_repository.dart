import '../../core/network/api_client.dart';
import '../models/hiring.dart';

/// Search, public profiles and the safety actions that hang off them.
///
/// Every screen that shows a recruiter, a company or a search result reads
/// through here, so they all see the same derived "hiring now" state.
class SearchRepository {
  SearchRepository(this._api);

  final ApiClient _api;

  Future<SearchResults> search(SearchQuery query) async {
    final data = await _api.get('/search', query: query.toQuery());
    return SearchResults.fromJson(data);
  }

  Future<RecruiterDetail> recruiter(String userId) async {
    final data = await _api.get('/recruiters/$userId');
    return RecruiterDetail.fromJson(data);
  }

  Future<CompanyProfile> company(String companyId) async {
    final data = await _api.get('/companies/$companyId');
    return CompanyProfile.fromJson(data);
  }

  Future<void> setBlocked(String userId, {required bool blocked}) =>
      _api.put('/blocks', body: {'userId': userId, 'blocked': blocked});

  Future<List<Map<String, dynamic>>> blocked() async {
    final data = await _api.get('/blocks');
    return (data['blocked'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> report({
    required String subjectKind,
    required String subjectId,
    required String reason,
    String details = '',
  }) =>
      _api.post('/reports', body: {
        'subjectKind': subjectKind,
        'subjectId': subjectId,
        'reason': reason,
        'details': details,
      });
}
