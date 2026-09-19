import '../../core/network/api_client.dart';
import '../models/enums.dart';
import '../models/job_title.dart';
import '../models/people.dart';
import '../models/session.dart';

class PeopleRepository {
  PeopleRepository(this._api);

  final ApiClient _api;

  /// Recruiter radar: discoverable candidates around the hiring location.
  Future<CandidateList> nearby(CandidateQuery query) async {
    final data = await _api.get('/candidates/nearby', query: query.toQuery());
    final meta = data['meta'] as Map<String, dynamic>? ?? const {};
    return CandidateList(
      candidates: (data['candidates'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CandidateCard.fromJson)
          .toList(),
      availableToday: (meta['availableToday'] as num?)?.toInt() ?? 0,
      radiusKm: (meta['radiusKm'] as num?)?.toDouble() ?? 10,
      hasLocation: meta['hasLocation'] == true,
      areaLabel: '${meta['areaLabel'] ?? ''}',
    );
  }

  Future<CandidateDetail> candidate(String userId) async {
    final data = await _api.get('/candidates/$userId');
    return CandidateDetail.fromJson(data['candidate'] as Map<String, dynamic>);
  }

  /// The centre "go live" button.
  Future<Session> setAvailability({required bool available}) async {
    final data = await _api.put('/candidates/me/availability', body: {'available': available});
    return Session.fromJson(data);
  }

  Future<Session> updatePrivacy({
    bool? stealthMode,
    ProfileVisibility? visibility,
    OpenToWork? openToWork,
    bool? openToConnect,
    bool? walkInAlerts,
  }) async {
    final data = await _api.put('/candidates/me/privacy', body: {
      if (stealthMode != null) 'stealthMode': stealthMode,
      if (visibility != null) 'profileVisibility': visibility.wire,
      if (openToWork != null) 'openToWork': openToWork.wire,
      if (openToConnect != null) 'openToConnect': openToConnect,
      if (walkInAlerts != null) 'walkInAlerts': walkInAlerts,
    });
    return Session.fromJson(data);
  }

  Future<Session> updateCandidateProfile({
    String? name,
    String? headline,
    List<String>? skills,
    List<JobTitle>? jobTitles,
    ExperienceLevel? experienceLevel,
    List<WorkMode>? workModes,
  }) async {
    final data = await _api.put('/candidates/me/profile', body: {
      if (name != null) 'name': name,
      if (headline != null) 'headline': headline,
      if (skills != null) 'skills': skills,
      if (jobTitles != null) 'jobTitleCodes': jobTitles.map((title) => title.code).toList(),
      if (experienceLevel != null) 'experienceLevel': experienceLevel.wire,
      if (workModes != null) 'workModes': workModes.map((mode) => mode.wire).toList(),
    });
    return Session.fromJson(data);
  }

  Future<Session> updateRecruiterProfile({
    String? hrName,
    String? designation,
    List<JobTitle>? hiringProfiles,
    List<WorkMode>? hiringWorkModes,
    double? hiringRadiusKm,
  }) async {
    final data = await _api.put('/recruiters/me/profile', body: {
      if (hrName != null) 'hrName': hrName,
      if (designation != null) 'designation': designation,
      if (hiringProfiles != null)
        'hiringProfileCodes': hiringProfiles.map((title) => title.code).toList(),
      if (hiringWorkModes != null)
        'hiringWorkModes': hiringWorkModes.map((mode) => mode.wire).toList(),
      if (hiringRadiusKm != null) 'hiringRadiusKm': hiringRadiusKm,
    });
    return Session.fromJson(data);
  }

  Future<CompanyDetails> myCompany() async {
    final data = await _api.get('/companies/mine');
    return CompanyDetails.fromJson(data['company'] as Map<String, dynamic>);
  }

  Future<({Session session, CompanyDetails company})> updateCompany({
    required String description,
    required String industry,
    required String size,
    required String website,
    required String linkedinUrl,
  }) async {
    final data = await _api.put('/companies/mine', body: {
      'description': description,
      'industry': industry,
      'size': size,
      'website': website,
      'linkedinUrl': linkedinUrl,
    });
    return (
      session: Session.fromJson(data),
      company: CompanyDetails.fromJson(data['companyDetails'] as Map<String, dynamic>),
    );
  }

  /// "N recruiters viewed you in the last 3 days".
  Future<int> recruitersViewedMe() async {
    final data = await _api.get('/candidates/me/insights');
    return (data['recruitersViewedLast3Days'] as num?)?.toInt() ?? 0;
  }
}
