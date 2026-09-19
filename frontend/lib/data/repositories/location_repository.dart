import '../../core/network/api_client.dart';
import '../models/registration_draft.dart';
import '../models/session.dart';

class LocationRepository {
  LocationRepository(this._api);

  final ApiClient _api;

  /// City / area suggestions for the manual picker.
  Future<List<LocationChoice>> search(String query) async {
    final data = await _api.get('/locations/search', query: {'q': query.trim()});
    return (data['results'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(LocationChoice.fromSuggestion)
        .toList();
  }

  /// Candidate's own area. The server blurs it before anyone else can see it.
  Future<Session> setCandidateLocation(LocationChoice choice) async {
    final data = await _api.put('/candidates/me/location', body: choice.toRequest());
    return Session.fromJson(data);
  }

  /// The company's hiring location — deliberately not the recruiter's own.
  Future<Session> setHiringLocation(LocationChoice choice, {double? radiusKm}) async {
    final data = await _api.put('/recruiters/me/hiring-location', body: {
      ...choice.toRequest(),
      if (radiusKm != null) 'hiringRadiusKm': radiusKm,
    });
    return Session.fromJson(data);
  }
}
