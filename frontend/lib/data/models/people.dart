import 'package:flutter/foundation.dart';

import 'enums.dart';

/// Compact card for anyone in a chat, request or saved list.
@immutable
class PersonSummary {
  const PersonSummary({
    required this.userId,
    required this.role,
    required this.name,
    required this.initials,
    this.headline = '',
    this.subtitle = '',
    this.companyName = '',
    this.companyId = '',
    this.area = '',
    this.availableToday = false,
  });

  final String userId;
  final UserRole role;
  final String name;
  final String initials;
  final String headline;
  final String subtitle;
  final String companyName;

  /// Set for recruiters, so any card showing one can open the company profile.
  final String companyId;
  final String area;
  final bool availableToday;

  factory PersonSummary.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    return PersonSummary(
      userId: '${data['userId'] ?? ''}',
      role: UserRole.fromWire(data['role'] as String?),
      name: '${data['name'] ?? 'TalentRadar member'}',
      initials: '${data['initials'] ?? 'TR'}',
      headline: '${data['headline'] ?? ''}',
      subtitle: '${data['subtitle'] ?? ''}',
      companyName: '${data['companyName'] ?? ''}',
      companyId: '${data['companyId'] ?? ''}',
      area: '${data['area'] ?? ''}',
      availableToday: data['availableToday'] == true,
    );
  }
}

/// A candidate on the recruiter's radar. Area words and a rounded distance only.
@immutable
class CandidateCard {
  const CandidateCard({
    required this.userId,
    required this.name,
    required this.initials,
    required this.headline,
    required this.jobTitleNames,
    required this.experienceLevel,
    required this.workModes,
    required this.openToWork,
    this.availableToday = false,
    this.area = '',
    this.distanceKm,
    this.matchesHiring = false,
    this.saved = false,
  });

  final String userId;
  final String name;
  final String initials;
  final String headline;
  final List<String> jobTitleNames;
  final ExperienceLevel experienceLevel;
  final List<WorkMode> workModes;
  final OpenToWork openToWork;
  final bool availableToday;
  final String area;
  final double? distanceKm;
  final bool matchesHiring;
  final bool saved;

  factory CandidateCard.fromJson(Map<String, dynamic> json) => CandidateCard(
        userId: '${json['userId']}',
        name: '${json['name'] ?? ''}',
        initials: '${json['initials'] ?? 'TR'}',
        headline: '${json['headline'] ?? ''}',
        jobTitleNames: (json['jobTitles'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((title) => '${title['name']}')
            .toList(),
        experienceLevel: ExperienceLevel.fromWire(json['experienceLevel'] as String?),
        workModes: (json['workModes'] as List? ?? [])
            .map((mode) => WorkMode.fromWire('$mode'))
            .whereType<WorkMode>()
            .toList(),
        openToWork: OpenToWork.fromWire(json['openToWork'] as String?),
        availableToday: json['availableToday'] == true,
        area: '${json['area'] ?? ''}',
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        matchesHiring: json['matchesHiring'] == true,
        saved: json['saved'] == true,
      );
}

enum ConnectionStatus {
  none('none'),
  pendingSent('pending_sent'),
  pendingReceived('pending_received'),
  connected('connected');

  const ConnectionStatus(this.wire);
  final String wire;

  static ConnectionStatus fromWire(String? value) => ConnectionStatus.values.firstWhere(
        (status) => status.wire == value,
        orElse: () => ConnectionStatus.none,
      );
}

/// The quick-profile sheet.
@immutable
class CandidateDetail {
  const CandidateDetail({
    required this.card,
    this.skills = const [],
    this.openToConnect = true,
    this.connectionStatus = ConnectionStatus.none,
    this.connectionId,
    this.canMessage = false,
  });

  final CandidateCard card;
  final List<String> skills;
  final bool openToConnect;
  final ConnectionStatus connectionStatus;
  final String? connectionId;
  final bool canMessage;

  factory CandidateDetail.fromJson(Map<String, dynamic> json) => CandidateDetail(
        card: CandidateCard.fromJson(json),
        skills: (json['skills'] as List? ?? []).map((skill) => '$skill').toList(),
        openToConnect: json['openToConnect'] != false,
        connectionStatus: ConnectionStatus.fromWire(json['connectionStatus'] as String?),
        connectionId: json['connectionId'] as String?,
        canMessage: json['canMessage'] == true,
      );
}

@immutable
class CandidateList {
  const CandidateList({
    required this.candidates,
    this.availableToday = 0,
    this.radiusKm = 10,
    this.hasLocation = false,
    this.areaLabel = '',
  });

  final List<CandidateCard> candidates;
  final int availableToday;
  final double radiusKm;
  final bool hasLocation;
  final String areaLabel;
}

@immutable
class CandidateQuery {
  const CandidateQuery({
    this.q = '',
    this.experience,
    this.workMode,
    this.availableToday = false,
    this.matchOnly = false,
  });

  final String q;
  final ExperienceLevel? experience;
  final WorkMode? workMode;
  final bool availableToday;
  final bool matchOnly;

  Map<String, dynamic> toQuery() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (experience != null) 'experience': experience!.wire,
        if (workMode != null) 'workMode': workMode!.wire,
        if (availableToday) 'availableToday': 'true',
        if (matchOnly) 'matchOnly': 'true',
      };

  CandidateQuery copyWith({
    String? q,
    ExperienceLevel? experience,
    bool clearExperience = false,
    WorkMode? workMode,
    bool clearWorkMode = false,
    bool? availableToday,
    bool? matchOnly,
  }) =>
      CandidateQuery(
        q: q ?? this.q,
        experience: clearExperience ? null : (experience ?? this.experience),
        workMode: clearWorkMode ? null : (workMode ?? this.workMode),
        availableToday: availableToday ?? this.availableToday,
        matchOnly: matchOnly ?? this.matchOnly,
      );

  @override
  bool operator ==(Object other) =>
      other is CandidateQuery &&
      other.q == q &&
      other.experience == experience &&
      other.workMode == workMode &&
      other.availableToday == availableToday &&
      other.matchOnly == matchOnly;

  @override
  int get hashCode => Object.hash(q, experience, workMode, availableToday, matchOnly);
}

/// Company details for the recruiter's company-profile screen.
@immutable
class CompanyDetails {
  const CompanyDetails({
    required this.name,
    this.description = '',
    this.industry = '',
    this.size = '',
    this.website = '',
    this.linkedinUrl = '',
    this.verificationStatus = 'unverified',
  });

  final String name;
  final String description;
  final String industry;
  final String size;
  final String website;
  final String linkedinUrl;
  final String verificationStatus;

  factory CompanyDetails.fromJson(Map<String, dynamic> json) => CompanyDetails(
        name: '${json['name'] ?? ''}',
        description: '${json['description'] ?? ''}',
        industry: '${json['industry'] ?? ''}',
        size: '${json['size'] ?? ''}',
        website: '${json['website'] ?? ''}',
        linkedinUrl: '${json['linkedinUrl'] ?? ''}',
        verificationStatus: '${json['verificationStatus'] ?? 'unverified'}',
      );
}
