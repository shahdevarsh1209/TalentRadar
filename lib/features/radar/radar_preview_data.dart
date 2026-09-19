// Preview content for the radar until the discovery API lands.
//
// Registration is the scope of this module; the nearby-search endpoint is not
// built yet. Everything the radar renders from here is isolated in this one
// file so replacing it with a repository call touches nothing else.

class NearbyOpening {
  const NearbyOpening({
    required this.companyCode,
    required this.title,
    required this.company,
    required this.distanceKm,
    required this.openings,
    required this.tags,
    this.isWalkIn = false,
  });

  final String companyCode;
  final String title;
  final String company;
  final double distanceKm;
  final int openings;
  final List<String> tags;
  final bool isWalkIn;
}

class NearbyCandidate {
  const NearbyCandidate({
    required this.initials,
    required this.name,
    required this.title,
    required this.years,
    required this.distanceKm,
    this.availableToday = false,
  });

  final String initials;
  final String name;
  final String title;
  final String years;
  final double distanceKm;
  final bool availableToday;
}

abstract final class RadarPreviewData {
  static const List<NearbyOpening> openings = [
    NearbyOpening(
      companyCode: 'ZOM',
      title: 'Support Executive',
      company: 'Zomato',
      distanceKm: 0.9,
      openings: 4,
      tags: ['0–2 yrs'],
      isWalkIn: true,
    ),
    NearbyOpening(
      companyCode: 'RZP',
      title: 'UX Researcher',
      company: 'Razorpay',
      distanceKm: 4.1,
      openings: 1,
      tags: ['Hybrid', '2 mutuals'],
    ),
    NearbyOpening(
      companyCode: 'MYN',
      title: 'Support Trainee',
      company: 'Myntra',
      distanceKm: 5.0,
      openings: 3,
      tags: ['Fresher ok'],
    ),
  ];

  static const List<NearbyCandidate> candidates = [
    NearbyCandidate(
      initials: 'PK',
      name: 'Priya Kulkarni',
      title: 'Support Executive',
      years: '2.5 yrs',
      distanceKm: 1.8,
      availableToday: true,
    ),
    NearbyCandidate(
      initials: 'NT',
      name: 'Nikhil Tandon',
      title: 'Tele-support',
      years: '1 yr',
      distanceKm: 3.2,
    ),
    NearbyCandidate(
      initials: 'AM',
      name: 'Ananya Mehta',
      title: 'ERP Functional Consultant',
      years: '3 yrs',
      distanceKm: 4.6,
      availableToday: true,
    ),
  ];
}
