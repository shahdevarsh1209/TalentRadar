import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'job.dart';
import 'people.dart';

/// A role somebody recruits for, with its live state.
///
/// [hiringNow] and [openings] are computed by the server from open job posts,
/// never stored alongside the role — closing the last job for a title turns it
/// off on every screen at once.
@immutable
class HiringRole {
  const HiringRole({
    required this.code,
    required this.name,
    this.category = '',
    this.hiringNow = false,
    this.openings = 0,
    this.jobId,
    this.isWalkIn = false,
    this.area = '',
  });

  final String code;
  final String name;
  final String category;
  final bool hiringNow;
  final int openings;

  /// The posting a tap opens. Null when the role is declared but not live.
  final String? jobId;
  final bool isWalkIn;
  final String area;

  factory HiringRole.fromJson(Map<String, dynamic> json) => HiringRole(
        code: '${json['code'] ?? ''}',
        name: '${json['name'] ?? ''}',
        category: '${json['category'] ?? ''}',
        // A company's live-role list carries no hiringNow flag — every entry in
        // it is by definition open — so fall back to the openings count rather
        // than to merely having the field present.
        hiringNow: json.containsKey('hiringNow')
            ? json['hiringNow'] == true
            : ((json['openings'] as num?)?.toInt() ?? 0) > 0,
        openings: (json['openings'] as num?)?.toInt() ?? 0,
        jobId: json['jobId'] as String?,
        isWalkIn: json['isWalkIn'] == true,
        area: '${json['area'] ?? ''}',
      );

  String get openingsLabel => openings == 1 ? '1 opening' : '$openings openings';
}

/// A recruiter as they appear in a search result or on a radar marker.
@immutable
class RecruiterCard {
  const RecruiterCard({
    required this.userId,
    required this.name,
    required this.initials,
    required this.designation,
    required this.companyId,
    required this.companyName,
    this.area = '',
    this.distanceKm,
    this.hiringNow = false,
    this.totalOpenings = 0,
    this.openRoles = const [],
    this.saved = false,
    this.connectionStatus = ConnectionStatus.none,
  });

  final String userId;
  final String name;
  final String initials;
  final String designation;
  final String companyId;
  final String companyName;
  final String area;
  final double? distanceKm;
  final bool hiringNow;
  final int totalOpenings;
  final List<HiringRole> openRoles;
  final bool saved;
  final ConnectionStatus connectionStatus;

  factory RecruiterCard.fromJson(Map<String, dynamic> json) => RecruiterCard(
        userId: '${json['userId'] ?? ''}',
        name: '${json['name'] ?? ''}',
        initials: '${json['initials'] ?? 'TR'}',
        designation: '${json['designation'] ?? 'Recruiter'}',
        companyId: '${json['companyId'] ?? ''}',
        companyName: '${json['companyName'] ?? ''}',
        area: '${json['area'] ?? ''}',
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        hiringNow: json['hiringNow'] == true,
        totalOpenings: (json['totalOpenings'] as num?)?.toInt() ?? 0,
        openRoles: (json['openRoles'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(HiringRole.fromJson)
            .toList(),
        saved: json['saved'] == true,
        connectionStatus: ConnectionStatus.fromWire(json['connectionStatus'] as String?),
      );

  PersonSummary get asPerson => PersonSummary(
        userId: userId,
        role: UserRole.recruiter,
        name: name,
        initials: initials,
        headline: designation,
        subtitle: [designation, companyName].where((part) => part.isNotEmpty).join(' · '),
        companyName: companyName,
        companyId: companyId,
      );
}

/// The full recruiter profile screen.
@immutable
class RecruiterDetail {
  const RecruiterDetail({
    required this.card,
    this.companyIndustry = '',
    this.companySize = '',
    this.verifiedEmailDomain = false,
    this.companyVerification = 'unverified',
    this.city = '',
    this.hiringWorkModes = const [],
    this.memberSince,
    this.roles = const [],
    this.openJobCount = 0,
    this.canMessage = true,
    this.isSelf = false,
    this.connectionId,
  });

  final RecruiterCard card;
  final String companyIndustry;
  final String companySize;

  /// The email address is on a company domain rather than a free provider.
  /// Advisory only — it is not an identity check, and the UI says so.
  final bool verifiedEmailDomain;
  final String companyVerification;
  final String city;
  final List<WorkMode> hiringWorkModes;
  final DateTime? memberSince;

  /// Every role they recruit for; [HiringRole.hiringNow] marks the live ones.
  final List<HiringRole> roles;
  final int openJobCount;
  final bool canMessage;
  final bool isSelf;
  final String? connectionId;

  List<HiringRole> get liveRoles => roles.where((role) => role.hiringNow).toList();

  factory RecruiterDetail.fromJson(Map<String, dynamic> json) {
    final recruiter = json['recruiter'] as Map<String, dynamic>? ?? const {};
    return RecruiterDetail(
      card: RecruiterCard.fromJson({
        ...recruiter,
        'hiringNow': json['hiringNow'],
        'totalOpenings': json['totalOpenings'],
        'connectionStatus': json['connectionStatus'],
      }),
      companyIndustry: '${recruiter['companyIndustry'] ?? ''}',
      companySize: '${recruiter['companySize'] ?? ''}',
      verifiedEmailDomain: recruiter['verifiedEmailDomain'] == true,
      companyVerification: '${recruiter['companyVerification'] ?? 'unverified'}',
      city: '${recruiter['city'] ?? ''}',
      hiringWorkModes: (recruiter['hiringWorkModes'] as List? ?? [])
          .map((mode) => WorkMode.fromWire('$mode'))
          .whereType<WorkMode>()
          .toList(),
      memberSince: DateTime.tryParse('${recruiter['memberSince'] ?? ''}'),
      roles: (json['roles'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(HiringRole.fromJson)
          .toList(),
      openJobCount: (json['openJobCount'] as num?)?.toInt() ?? 0,
      canMessage: json['canMessage'] != false,
      isSelf: recruiter['isSelf'] == true,
      connectionId: json['connectionId'] as String?,
    );
  }
}

/// A company in a search result.
@immutable
class CompanyCard {
  const CompanyCard({
    required this.companyId,
    required this.name,
    required this.initials,
    this.industry = '',
    this.size = '',
    this.verificationStatus = 'unverified',
    this.area = '',
    this.distanceKm,
    this.hiringNow = false,
    this.totalOpenings = 0,
    this.openRoles = const [],
  });

  final String companyId;
  final String name;
  final String initials;
  final String industry;
  final String size;
  final String verificationStatus;
  final String area;
  final double? distanceKm;
  final bool hiringNow;
  final int totalOpenings;
  final List<HiringRole> openRoles;

  factory CompanyCard.fromJson(Map<String, dynamic> json) => CompanyCard(
        companyId: '${json['companyId'] ?? ''}',
        name: '${json['name'] ?? ''}',
        initials: '${json['initials'] ?? 'TR'}',
        industry: '${json['industry'] ?? ''}',
        size: '${json['size'] ?? ''}',
        verificationStatus: '${json['verificationStatus'] ?? 'unverified'}',
        area: '${json['area'] ?? ''}',
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        hiringNow: json['hiringNow'] == true,
        totalOpenings: (json['totalOpenings'] as num?)?.toInt() ?? 0,
        openRoles: (json['openRoles'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(HiringRole.fromJson)
            .toList(),
      );
}

/// The public company profile screen: who they are, what is open, who to ask.
@immutable
class CompanyProfile {
  const CompanyProfile({
    required this.card,
    this.description = '',
    this.website = '',
    this.linkedinUrl = '',
    this.jobs = const [],
    this.recruiters = const [],
  });

  final CompanyCard card;
  final String description;
  final String website;
  final String linkedinUrl;
  final List<Job> jobs;
  final List<PersonSummary> recruiters;

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    final company = json['company'] as Map<String, dynamic>? ?? const {};
    return CompanyProfile(
      card: CompanyCard.fromJson({
        ...company,
        'hiringNow': json['hiringNow'],
        'totalOpenings': json['totalOpenings'],
        'openRoles': json['roles'],
      }),
      description: '${company['description'] ?? ''}',
      website: '${company['website'] ?? ''}',
      linkedinUrl: '${company['linkedinUrl'] ?? ''}',
      jobs: (json['jobs'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Job.fromJson)
          .toList(),
      recruiters: (json['recruiters'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PersonSummary.fromJson)
          .toList(),
    );
  }
}

/// What the search screen is currently asking for.
///
/// One object drives the request, the filter sheet and the provider key, so a
/// filter cannot be applied on screen without changing the query that runs.
@immutable
class SearchQuery {
  const SearchQuery({
    this.q = '',
    this.type = 'jobs',
    this.recruiterId,
    this.companyId,
    this.titleCode,
    this.experience,
    this.workMode,
    this.openToWork,
    this.skill,
    this.maxDistanceKm,
    this.minOpenings,
    this.postedWithinDays,
    this.activeWithinDays,
    this.hiringNow = false,
    this.walkIn = false,
    this.remote = false,
    this.availableToday = false,
    this.openToFreshers = false,
    this.sort = 'nearest',
  });

  final String q;

  /// One of jobs, companies, recruiters, candidates — the tab in view.
  final String type;

  /// Pins the results to one recruiter or company ("View jobs" on a profile).
  final String? recruiterId;
  final String? companyId;
  final String? titleCode;
  final ExperienceLevel? experience;
  final WorkMode? workMode;
  final OpenToWork? openToWork;
  final String? skill;
  final double? maxDistanceKm;
  final int? minOpenings;
  final int? postedWithinDays;
  final int? activeWithinDays;
  final bool hiringNow;
  final bool walkIn;
  final bool remote;
  final bool availableToday;
  final bool openToFreshers;
  final String sort;

  Map<String, dynamic> toQuery() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        'type': type,
        if (recruiterId != null) 'recruiterId': recruiterId,
        if (companyId != null) 'companyId': companyId,
        if (titleCode != null) 'titleCode': titleCode,
        if (experience != null) 'experience': experience!.wire,
        if (workMode != null) 'workMode': workMode!.wire,
        if (openToWork != null) 'openToWork': openToWork!.wire,
        if (skill != null && skill!.isNotEmpty) 'skill': skill,
        if (maxDistanceKm != null) 'maxDistanceKm': '$maxDistanceKm',
        if (minOpenings != null) 'minOpenings': '$minOpenings',
        if (postedWithinDays != null) 'postedWithinDays': '$postedWithinDays',
        if (activeWithinDays != null) 'activeWithinDays': '$activeWithinDays',
        if (hiringNow) 'hiringNow': 'true',
        if (walkIn) 'walkIn': 'true',
        if (remote) 'remote': 'true',
        if (availableToday) 'availableToday': 'true',
        if (openToFreshers) 'openToFreshers': 'true',
        'sort': sort,
      };

  /// Filters beyond the text and the tab — what the "Filters" button counts.
  int get activeFilterCount => [
        titleCode != null,
        experience != null,
        workMode != null,
        openToWork != null,
        skill != null && skill!.isNotEmpty,
        maxDistanceKm != null,
        minOpenings != null,
        postedWithinDays != null,
        activeWithinDays != null,
        hiringNow,
        walkIn,
        remote,
        availableToday,
        openToFreshers,
      ].where((active) => active).length;

  SearchQuery copyWith({
    String? q,
    String? type,
    String? titleCode,
    bool clearTitleCode = false,
    ExperienceLevel? experience,
    bool clearExperience = false,
    WorkMode? workMode,
    bool clearWorkMode = false,
    OpenToWork? openToWork,
    bool clearOpenToWork = false,
    String? skill,
    bool clearSkill = false,
    double? maxDistanceKm,
    bool clearDistance = false,
    int? minOpenings,
    bool clearMinOpenings = false,
    int? postedWithinDays,
    bool clearPostedWithin = false,
    int? activeWithinDays,
    bool clearActiveWithin = false,
    bool? hiringNow,
    bool? walkIn,
    bool? remote,
    bool? availableToday,
    bool? openToFreshers,
    String? sort,
  }) =>
      SearchQuery(
        q: q ?? this.q,
        type: type ?? this.type,
        // A pinned scope survives every filter change and "clear all".
        recruiterId: recruiterId,
        companyId: companyId,
        titleCode: clearTitleCode ? null : (titleCode ?? this.titleCode),
        experience: clearExperience ? null : (experience ?? this.experience),
        workMode: clearWorkMode ? null : (workMode ?? this.workMode),
        openToWork: clearOpenToWork ? null : (openToWork ?? this.openToWork),
        skill: clearSkill ? null : (skill ?? this.skill),
        maxDistanceKm: clearDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
        minOpenings: clearMinOpenings ? null : (minOpenings ?? this.minOpenings),
        postedWithinDays: clearPostedWithin ? null : (postedWithinDays ?? this.postedWithinDays),
        activeWithinDays: clearActiveWithin ? null : (activeWithinDays ?? this.activeWithinDays),
        hiringNow: hiringNow ?? this.hiringNow,
        walkIn: walkIn ?? this.walkIn,
        remote: remote ?? this.remote,
        availableToday: availableToday ?? this.availableToday,
        openToFreshers: openToFreshers ?? this.openToFreshers,
        sort: sort ?? this.sort,
      );

  /// Keeps the text, tab and pinned scope, drops every filter — "Clear all".
  SearchQuery cleared() =>
      SearchQuery(q: q, type: type, sort: sort, recruiterId: recruiterId, companyId: companyId);

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.q == q &&
      other.type == type &&
      other.recruiterId == recruiterId &&
      other.companyId == companyId &&
      other.titleCode == titleCode &&
      other.experience == experience &&
      other.workMode == workMode &&
      other.openToWork == openToWork &&
      other.skill == skill &&
      other.maxDistanceKm == maxDistanceKm &&
      other.minOpenings == minOpenings &&
      other.postedWithinDays == postedWithinDays &&
      other.activeWithinDays == activeWithinDays &&
      other.hiringNow == hiringNow &&
      other.walkIn == walkIn &&
      other.remote == remote &&
      other.availableToday == availableToday &&
      other.openToFreshers == openToFreshers &&
      other.sort == sort;

  @override
  int get hashCode => Object.hashAll([
        q,
        type,
        recruiterId,
        companyId,
        titleCode,
        experience,
        workMode,
        openToWork,
        skill,
        maxDistanceKm,
        minOpenings,
        postedWithinDays,
        activeWithinDays,
        hiringNow,
        walkIn,
        remote,
        availableToday,
        openToFreshers,
        sort,
      ]);
}

/// Whatever the current tab asked for, plus the counts the other tabs show.
@immutable
class SearchResults {
  const SearchResults({
    this.jobs = const [],
    this.companies = const [],
    this.recruiters = const [],
    this.candidates = const [],
    this.counts = const {},
    this.hasLocation = false,
    this.areaLabel = '',
    this.radiusKm = 10,
  });

  final List<Job> jobs;
  final List<CompanyCard> companies;
  final List<RecruiterCard> recruiters;
  final List<CandidateCard> candidates;
  final Map<String, int> counts;
  final bool hasLocation;
  final String areaLabel;
  final double radiusKm;

  int get total => counts.values.fold(0, (sum, count) => sum + count);

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    final results = json['results'] as Map<String, dynamic>? ?? const {};
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) build) =>
        (results[key] as List? ?? []).whereType<Map<String, dynamic>>().map(build).toList();

    return SearchResults(
      jobs: parse('jobs', Job.fromJson),
      companies: parse('companies', CompanyCard.fromJson),
      recruiters: parse('recruiters', RecruiterCard.fromJson),
      candidates: parse('candidates', CandidateCard.fromJson),
      counts: (json['counts'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0)),
      hasLocation: meta['hasLocation'] == true,
      areaLabel: '${meta['areaLabel'] ?? ''}',
      radiusKm: (meta['radiusKm'] as num?)?.toDouble() ?? 10,
    );
  }
}
