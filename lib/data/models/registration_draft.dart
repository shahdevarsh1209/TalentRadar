import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'job_title.dart';

/// In-progress candidate registration.
///
/// Held above the screen so going back to "Choose your role" and returning does
/// not lose typing, and so switching roles can warn before discarding anything.
@immutable
class CandidateDraft {
  const CandidateDraft({
    this.name = '',
    this.email = '',
    this.password = '',
    this.jobTitles = const [],
    this.experienceLevel = ExperienceLevel.fresher,
    this.workModes = const [],
    this.openToWork = OpenToWork.openToOpportunities,
    this.visibility = ProfileVisibility.recruitersOnly,
  });

  final String name;
  final String email;
  final String password;
  final List<JobTitle> jobTitles;
  final ExperienceLevel experienceLevel;
  final List<WorkMode> workModes;
  final OpenToWork openToWork;
  final ProfileVisibility visibility;

  /// Required fields per the product spec: name, email, job title, work mode.
  bool get isSubmittable =>
      name.trim().length >= 2 &&
      email.trim().isNotEmpty &&
      jobTitles.isNotEmpty &&
      workModes.isNotEmpty;

  bool get hasContent =>
      name.isNotEmpty || email.isNotEmpty || jobTitles.isNotEmpty || workModes.isNotEmpty;

  CandidateDraft copyWith({
    String? name,
    String? email,
    String? password,
    List<JobTitle>? jobTitles,
    ExperienceLevel? experienceLevel,
    List<WorkMode>? workModes,
    OpenToWork? openToWork,
    ProfileVisibility? visibility,
  }) =>
      CandidateDraft(
        name: name ?? this.name,
        email: email ?? this.email,
        password: password ?? this.password,
        jobTitles: jobTitles ?? this.jobTitles,
        experienceLevel: experienceLevel ?? this.experienceLevel,
        workModes: workModes ?? this.workModes,
        openToWork: openToWork ?? this.openToWork,
        visibility: visibility ?? this.visibility,
      );

  Map<String, dynamic> toRequest() => {
        'name': name.trim(),
        'email': email.trim(),
        if (password.isNotEmpty) 'password': password,
        'jobTitleCodes': jobTitles.map((title) => title.code).toList(),
        'experienceLevel': experienceLevel.wire,
        'workModes': workModes.map((mode) => mode.wire).toList(),
        'openToWork': openToWork.wire,
        'profileVisibility': visibility.wire,
      };
}

/// In-progress recruiter registration.
@immutable
class RecruiterDraft {
  const RecruiterDraft({
    this.companyName = '',
    this.hrName = '',
    this.email = '',
    this.password = '',
    this.designation = '',
    this.hiringProfiles = const [],
    this.hiringWorkModes = const [],
  });

  final String companyName;
  final String hrName;
  final String email;
  final String password;
  final String designation;
  final List<JobTitle> hiringProfiles;
  final List<WorkMode> hiringWorkModes;

  bool get isSubmittable =>
      companyName.trim().length >= 2 &&
      hrName.trim().length >= 2 &&
      email.trim().isNotEmpty &&
      hiringProfiles.isNotEmpty;

  bool get hasContent =>
      companyName.isNotEmpty ||
      hrName.isNotEmpty ||
      email.isNotEmpty ||
      hiringProfiles.isNotEmpty;

  RecruiterDraft copyWith({
    String? companyName,
    String? hrName,
    String? email,
    String? password,
    String? designation,
    List<JobTitle>? hiringProfiles,
    List<WorkMode>? hiringWorkModes,
  }) =>
      RecruiterDraft(
        companyName: companyName ?? this.companyName,
        hrName: hrName ?? this.hrName,
        email: email ?? this.email,
        password: password ?? this.password,
        designation: designation ?? this.designation,
        hiringProfiles: hiringProfiles ?? this.hiringProfiles,
        hiringWorkModes: hiringWorkModes ?? this.hiringWorkModes,
      );

  Map<String, dynamic> toRequest() => {
        'companyName': companyName.trim(),
        'hrName': hrName.trim(),
        'email': email.trim(),
        if (password.isNotEmpty) 'password': password,
        if (designation.trim().isNotEmpty) 'designation': designation.trim(),
        'hiringProfileCodes': hiringProfiles.map((title) => title.code).toList(),
        'hiringWorkModes': hiringWorkModes.map((mode) => mode.wire).toList(),
      };
}

/// A place the user picked, before it is sent to the API.
@immutable
class LocationChoice {
  const LocationChoice({
    required this.source,
    this.latitude,
    this.longitude,
    this.area = '',
    this.city = '',
    this.state = '',
    this.country = 'India',
    this.pincode = '',
    this.label = '',
  });

  /// 'device' when it came from a GPS fix, 'manual' when chosen from the list.
  final String source;
  final double? latitude;
  final double? longitude;
  final String area;
  final String city;
  final String state;
  final String country;
  final String pincode;
  final String label;

  String get display {
    if (label.isNotEmpty) return label;
    final parts = [area, city].where((part) => part.isNotEmpty);
    return parts.isEmpty ? 'Selected location' : parts.join(', ');
  }

  factory LocationChoice.fromSuggestion(Map<String, dynamic> json) => LocationChoice(
        source: 'manual',
        area: '${json['area'] ?? ''}',
        city: '${json['city'] ?? ''}',
        state: '${json['state'] ?? ''}',
        country: '${json['country'] ?? 'India'}',
        label: '${json['label'] ?? ''}',
        // Area centre from the directory; the server blurs it before storing.
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  LocationChoice copyWith({String? pincode}) => LocationChoice(
        source: source,
        latitude: latitude,
        longitude: longitude,
        area: area,
        city: city,
        state: state,
        country: country,
        pincode: pincode ?? this.pincode,
        label: label,
      );

  Map<String, dynamic> toRequest() => {
        'source': source,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (area.isNotEmpty) 'area': area,
        if (city.isNotEmpty) 'city': city,
        if (state.isNotEmpty) 'state': state,
        if (country.isNotEmpty) 'country': country,
        if (pincode.isNotEmpty) 'pincode': pincode,
        if (label.isNotEmpty) 'label': label,
      };
}
