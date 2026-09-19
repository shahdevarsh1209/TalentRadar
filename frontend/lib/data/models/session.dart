import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'job_title.dart';

/// Area-level location as published by the API. Exact coordinates never appear
/// in this model because the server never sends them.
@immutable
class LocationSummary {
  const LocationSummary({
    this.area = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.pincode = '',
    this.label = '',
    this.source = 'unset',
    this.privacyRadiusKm = 2,
    this.isSet = false,
  });

  final String area;
  final String city;
  final String state;
  final String country;
  final String pincode;
  final String label;
  final String source;
  final double privacyRadiusKm;
  final bool isSet;

  factory LocationSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LocationSummary();
    return LocationSummary(
      area: '${json['area'] ?? ''}',
      city: '${json['city'] ?? ''}',
      state: '${json['state'] ?? ''}',
      country: '${json['country'] ?? ''}',
      pincode: '${json['pincode'] ?? ''}',
      label: '${json['label'] ?? ''}',
      source: '${json['source'] ?? 'unset'}',
      privacyRadiusKm: (json['privacyRadiusKm'] as num?)?.toDouble() ?? 2,
      isSet: json['isSet'] == true,
    );
  }

  String get display {
    if (label.isNotEmpty) return label;
    final parts = [area, city].where((part) => part.isNotEmpty);
    return parts.isEmpty ? 'Location not set' : parts.join(', ');
  }
}

@immutable
class AuthUser {
  const AuthUser({
    required this.userId,
    required this.email,
    required this.role,
    required this.isEmailVerified,
    required this.onboardingStage,
  });

  final String userId;
  final String email;
  final UserRole role;
  final bool isEmailVerified;
  final OnboardingStage onboardingStage;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        userId: '${json['userId']}',
        email: '${json['email']}',
        role: UserRole.fromWire(json['role'] as String?),
        isEmailVerified: json['isEmailVerified'] == true,
        onboardingStage: OnboardingStage.fromWire(json['onboardingStage'] as String?),
      );
}

@immutable
class CandidateProfile {
  const CandidateProfile({
    required this.name,
    required this.email,
    required this.jobTitles,
    required this.experienceLevel,
    required this.workModes,
    required this.openToWork,
    required this.profileVisibility,
    required this.stealthMode,
    required this.location,
    this.headline = '',
    this.profileCompletion = 0,
    this.availableToday = false,
    this.openToConnect = true,
    this.walkInAlerts = true,
    this.skills = const [],
  });

  final String name;
  final String email;
  final String headline;
  final List<JobTitle> jobTitles;
  final ExperienceLevel experienceLevel;
  final List<WorkMode> workModes;
  final OpenToWork openToWork;
  final ProfileVisibility profileVisibility;
  final bool stealthMode;
  final LocationSummary location;
  final int profileCompletion;

  /// Set by the centre 'go live' button; true until midnight.
  final bool availableToday;
  final bool openToConnect;
  final bool walkInAlerts;
  final List<String> skills;

  factory CandidateProfile.fromJson(Map<String, dynamic> json) => CandidateProfile(
        name: '${json['name'] ?? ''}',
        email: '${json['email'] ?? ''}',
        headline: '${json['headline'] ?? ''}',
        jobTitles: (json['jobTitles'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(JobTitle.fromJson)
            .toList(),
        experienceLevel: ExperienceLevel.fromWire(json['experienceLevel'] as String?),
        workModes: (json['workModes'] as List? ?? [])
            .map((mode) => WorkMode.fromWire('$mode'))
            .whereType<WorkMode>()
            .toList(),
        openToWork: OpenToWork.fromWire(json['openToWork'] as String?),
        profileVisibility: ProfileVisibility.fromWire(json['profileVisibility'] as String?),
        stealthMode: json['stealthMode'] == true,
        location: LocationSummary.fromJson(json['location'] as Map<String, dynamic>?),
        profileCompletion: (json['profileCompletion'] as num?)?.toInt() ?? 0,
        availableToday: json['availableToday'] == true,
        openToConnect: json['openToConnect'] != false,
        walkInAlerts: json['walkInAlerts'] != false,
        skills: (json['skills'] as List? ?? []).map((skill) => '$skill').toList(),
      );

  String get initials => _initialsOf(name);
}

@immutable
class RecruiterProfile {
  const RecruiterProfile({
    required this.companyName,
    required this.hrName,
    required this.email,
    required this.hiringProfiles,
    required this.hiringLocations,
    this.designation = '',
    this.isOfficialEmailDomain = false,
    this.hiringWorkModes = const [],
    this.hiringRadiusKm = 10,
    this.profileCompletion = 0,
  });

  final String companyName;
  final String hrName;
  final String email;
  final String designation;
  final bool isOfficialEmailDomain;
  final List<JobTitle> hiringProfiles;
  final List<WorkMode> hiringWorkModes;
  final List<LocationSummary> hiringLocations;
  final double hiringRadiusKm;
  final int profileCompletion;

  factory RecruiterProfile.fromJson(Map<String, dynamic> json) => RecruiterProfile(
        companyName: '${json['companyName'] ?? ''}',
        hrName: '${json['hrName'] ?? ''}',
        email: '${json['email'] ?? ''}',
        designation: '${json['designation'] ?? ''}',
        isOfficialEmailDomain: json['isOfficialEmailDomain'] == true,
        hiringProfiles: (json['hiringProfiles'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(JobTitle.fromJson)
            .toList(),
        hiringWorkModes: (json['hiringWorkModes'] as List? ?? [])
            .map((mode) => WorkMode.fromWire('$mode'))
            .whereType<WorkMode>()
            .toList(),
        hiringLocations: (json['hiringLocations'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(LocationSummary.fromJson)
            .toList(),
        hiringRadiusKm: (json['hiringRadiusKm'] as num?)?.toDouble() ?? 10,
        profileCompletion: (json['profileCompletion'] as num?)?.toInt() ?? 0,
      );

  String get initials => _initialsOf(hrName);

  LocationSummary? get primaryHiringLocation =>
      hiringLocations.isEmpty ? null : hiringLocations.first;
}

/// What a registration, verification or login returns.
@immutable
class Session {
  const Session({
    required this.user,
    this.token,
    this.candidate,
    this.recruiter,
    this.companyName,
  });

  final AuthUser user;
  final String? token;
  final CandidateProfile? candidate;
  final RecruiterProfile? recruiter;
  final String? companyName;

  bool get isCandidate => user.role == UserRole.candidate;

  /// Name to greet this person by, whichever role they signed up as.
  String get displayName => candidate?.name ?? recruiter?.hrName ?? '';

  String get initials => candidate?.initials ?? recruiter?.initials ?? _initialsOf(displayName);

  bool get hasLocation =>
      candidate?.location.isSet ?? (recruiter?.hiringLocations.isNotEmpty ?? false);

  factory Session.fromJson(Map<String, dynamic> json, {String? fallbackToken}) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final user = AuthUser.fromJson(json['user'] as Map<String, dynamic>);
    return Session(
      user: user,
      token: json['token'] as String? ?? fallbackToken,
      candidate: user.role == UserRole.candidate && profile != null
          ? CandidateProfile.fromJson(profile)
          : null,
      recruiter: user.role == UserRole.recruiter && profile != null
          ? RecruiterProfile.fromJson(profile)
          : null,
      companyName: (json['company'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  Session copyWith({String? token}) => Session(
        user: user,
        token: token ?? this.token,
        candidate: candidate,
        recruiter: recruiter,
        companyName: companyName,
      );
}

/// Metadata about an outstanding verification code.
@immutable
class VerificationChallenge {
  const VerificationChallenge({
    required this.resendAfterSeconds,
    this.expiresAt,
    this.devCode,
  });

  final int resendAfterSeconds;
  final DateTime? expiresAt;

  /// Present only while the backend runs with EXPOSE_OTP enabled.
  final String? devCode;

  factory VerificationChallenge.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VerificationChallenge(resendAfterSeconds: 45);
    return VerificationChallenge(
      resendAfterSeconds: (json['resendAfterSeconds'] as num?)?.toInt() ?? 45,
      expiresAt: DateTime.tryParse('${json['expiresAt'] ?? ''}'),
      devCode: json['devCode'] as String?,
    );
  }
}

String _initialsOf(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'TR';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
