import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'job_title.dart';
import 'session.dart';

@immutable
class WalkIn {
  const WalkIn({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.address = '',
    this.instructions = '',
  });

  final DateTime date;
  final String startTime; // "10:00"
  final String endTime;
  final String address;
  final String instructions;

  factory WalkIn.fromJson(Map<String, dynamic> json) => WalkIn(
        date: DateTime.tryParse('${json['date']}')?.toLocal() ?? DateTime.now(),
        startTime: '${json['startTime'] ?? ''}',
        endTime: '${json['endTime'] ?? ''}',
        address: '${json['address'] ?? ''}',
        instructions: '${json['instructions'] ?? ''}',
      );
}

/// A role as the API publishes it: area words and a rounded distance only.
@immutable
class Job {
  const Job({
    required this.jobId,
    required this.recruiterUserId,
    required this.companyName,
    required this.title,
    required this.workMode,
    required this.experienceLevel,
    required this.openings,
    required this.location,
    required this.createdAt,
    this.postedByName = '',
    this.description = '',
    this.salaryMin,
    this.salaryMax,
    this.isWalkIn = false,
    this.walkIn,
    this.walkInToday = false,
    this.closingSoon = false,
    this.distanceKm,
    this.status = 'open',
    this.interestCount = 0,
    this.saved = false,
    this.interested = false,
    this.matchesProfile = false,
  });

  final String jobId;
  final String recruiterUserId;
  final String companyName;
  final String postedByName;
  final JobTitle title;
  final String description;
  final WorkMode workMode;
  final ExperienceLevel experienceLevel;
  final int openings;
  final int? salaryMin;
  final int? salaryMax;
  final bool isWalkIn;
  final WalkIn? walkIn;
  final bool walkInToday;
  final bool closingSoon;
  final LocationSummary location;
  final double? distanceKm;
  final String status;
  final int interestCount;
  final bool saved;
  final bool interested;
  final bool matchesProfile;
  final DateTime createdAt;

  bool get isOpen => status == 'open';

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        jobId: '${json['jobId']}',
        recruiterUserId: '${json['recruiterUserId'] ?? ''}',
        companyName: '${json['companyName'] ?? ''}',
        postedByName: '${json['postedByName'] ?? ''}',
        title: JobTitle.fromJson(json['title'] as Map<String, dynamic>),
        description: '${json['description'] ?? ''}',
        workMode: WorkMode.fromWire(json['workMode'] as String?) ?? WorkMode.onsite,
        experienceLevel: ExperienceLevel.fromWire(json['experienceLevel'] as String?),
        openings: (json['openings'] as num?)?.toInt() ?? 1,
        salaryMin: (json['salaryMin'] as num?)?.toInt(),
        salaryMax: (json['salaryMax'] as num?)?.toInt(),
        isWalkIn: json['isWalkIn'] == true,
        walkIn: json['walkIn'] is Map<String, dynamic>
            ? WalkIn.fromJson(json['walkIn'] as Map<String, dynamic>)
            : null,
        walkInToday: json['walkInToday'] == true,
        closingSoon: json['closingSoon'] == true,
        location: LocationSummary.fromJson(json['location'] as Map<String, dynamic>?),
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        status: '${json['status'] ?? 'open'}',
        interestCount: (json['interestCount'] as num?)?.toInt() ?? 0,
        saved: json['saved'] == true,
        interested: json['interested'] == true,
        matchesProfile: json['matchesProfile'] == true,
        createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
      );

  Job copyWith({bool? saved, bool? interested, String? status}) => Job(
        jobId: jobId,
        recruiterUserId: recruiterUserId,
        companyName: companyName,
        postedByName: postedByName,
        title: title,
        description: description,
        workMode: workMode,
        experienceLevel: experienceLevel,
        openings: openings,
        salaryMin: salaryMin,
        salaryMax: salaryMax,
        isWalkIn: isWalkIn,
        walkIn: walkIn,
        walkInToday: walkInToday,
        closingSoon: closingSoon,
        location: location,
        distanceKm: distanceKm,
        status: status ?? this.status,
        interestCount: interestCount,
        saved: saved ?? this.saved,
        interested: interested ?? this.interested,
        matchesProfile: matchesProfile,
        createdAt: createdAt,
      );
}

@immutable
class JobListMeta {
  const JobListMeta({
    this.total = 0,
    this.nearbyCount = 0,
    this.walkInsToday = 0,
    this.radiusKm = 10,
    this.hasLocation = false,
    this.areaLabel = '',
    this.updatedAt,
  });

  final int total;
  final int nearbyCount;
  final int walkInsToday;
  final double radiusKm;
  final bool hasLocation;
  final String areaLabel;
  final DateTime? updatedAt;

  factory JobListMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const JobListMeta();
    return JobListMeta(
      total: (json['total'] as num?)?.toInt() ?? 0,
      nearbyCount: (json['nearbyCount'] as num?)?.toInt() ?? 0,
      walkInsToday: (json['walkInsToday'] as num?)?.toInt() ?? 0,
      radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 10,
      hasLocation: json['hasLocation'] == true,
      areaLabel: '${json['areaLabel'] ?? ''}',
      updatedAt: DateTime.tryParse('${json['updatedAt']}')?.toLocal(),
    );
  }
}

@immutable
class JobList {
  const JobList({required this.jobs, required this.meta});

  final List<Job> jobs;
  final JobListMeta meta;
}

/// What the Jobs tab and Search screen ask for.
@immutable
class JobQuery {
  const JobQuery({this.filter = 'all', this.q = '', this.sort = 'nearest'});

  /// 'all', 'walkins' or 'remote'.
  final String filter;
  final String q;

  /// 'nearest' or 'newest'.
  final String sort;

  Map<String, dynamic> toQuery() => {
        'filter': filter,
        if (q.trim().isNotEmpty) 'q': q.trim(),
        'sort': sort,
      };

  @override
  bool operator ==(Object other) =>
      other is JobQuery && other.filter == filter && other.q == q && other.sort == sort;

  @override
  int get hashCode => Object.hash(filter, q, sort);
}

/// The recruiter's "Post a role" form.
@immutable
class JobDraft {
  const JobDraft({
    this.title,
    this.workMode = WorkMode.onsite,
    this.experienceLevel = ExperienceLevel.fresher,
    this.openings = 1,
    this.salaryMin,
    this.salaryMax,
    this.description = '',
    this.isWalkIn = false,
    this.walkInDate,
    this.startTime = '10:00',
    this.endTime = '16:00',
    this.address = '',
  });

  final JobTitle? title;
  final WorkMode workMode;
  final ExperienceLevel experienceLevel;
  final int openings;
  final int? salaryMin;
  final int? salaryMax;
  final String description;
  final bool isWalkIn;
  final DateTime? walkInDate;
  final String startTime;
  final String endTime;
  final String address;

  Map<String, dynamic> toRequest() => {
        'titleCode': title?.code,
        'workMode': workMode.wire,
        'experienceLevel': experienceLevel.wire,
        'openings': openings,
        if (salaryMin != null) 'salaryMin': salaryMin,
        if (salaryMax != null) 'salaryMax': salaryMax,
        if (description.trim().isNotEmpty) 'description': description.trim(),
        'isWalkIn': isWalkIn,
        if (isWalkIn && walkInDate != null)
          'walkIn': {
            'date': '${walkInDate!.year.toString().padLeft(4, '0')}-'
                '${walkInDate!.month.toString().padLeft(2, '0')}-'
                '${walkInDate!.day.toString().padLeft(2, '0')}',
            'startTime': startTime,
            'endTime': endTime,
            if (address.trim().isNotEmpty) 'address': address.trim(),
          },
      };
}
