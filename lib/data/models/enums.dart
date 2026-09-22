// Client-side mirror of the server vocabulary in `utils/constants.js`.
//
// The wire value is what travels and what the matching engine will compare;
// the label is presentation only. Unknown values coming back from a newer API
// degrade to a sensible default instead of crashing an older build.

enum UserRole {
  candidate('candidate', 'Candidate'),
  recruiter('recruiter', 'HR / Recruiter');

  const UserRole(this.wire, this.label);
  final String wire;
  final String label;

  static UserRole fromWire(String? value) => UserRole.values.firstWhere(
        (role) => role.wire == value,
        orElse: () => UserRole.candidate,
      );
}

enum ExperienceLevel {
  fresher('fresher', 'Fresher'),
  lessThanOne('lt_1', 'Less than 1 year'),
  oneToTwo('1_2', '1–2 years'),
  twoToThree('2_3', '2–3 years'),
  threeToFive('3_5', '3–5 years'),
  fiveToEight('5_8', '5–8 years'),
  eightToTwelve('8_12', '8–12 years'),
  twelvePlus('12_plus', '12+ years');

  const ExperienceLevel(this.wire, this.label);
  final String wire;
  final String label;

  /// Compact figure for stat tiles: "0", "<1", "2–3", "12+".
  String get short => switch (this) {
        ExperienceLevel.fresher => '0',
        ExperienceLevel.lessThanOne => '<1',
        ExperienceLevel.twelvePlus => '12+',
        _ => label.replaceAll(' years', ''),
      };

  static ExperienceLevel fromWire(String? value) => ExperienceLevel.values.firstWhere(
        (level) => level.wire == value,
        orElse: () => ExperienceLevel.fresher,
      );
}

enum WorkMode {
  remote('remote', 'Online / Remote', 'Work from anywhere'),
  onsite('onsite', 'Offline / On-site', 'Work from the office'),
  hybrid('hybrid', 'Hybrid', 'A mix of both');

  const WorkMode(this.wire, this.label, this.description);
  final String wire;
  final String label;
  final String description;

  static WorkMode? fromWire(String? value) {
    for (final mode in WorkMode.values) {
      if (mode.wire == value) return mode;
    }
    return null;
  }
}

enum OpenToWork {
  activelyLooking('actively_looking', 'Actively looking', 'Show me to recruiters first'),
  openToOpportunities(
    'open_to_opportunities',
    'Open to opportunities',
    'Happy to hear about the right role',
  ),
  notLooking('not_looking', 'Not looking currently', 'Stay hidden from hiring searches');

  const OpenToWork(this.wire, this.label, this.description);
  final String wire;
  final String label;
  final String description;

  static OpenToWork fromWire(String? value) => OpenToWork.values.firstWhere(
        (status) => status.wire == value,
        orElse: () => OpenToWork.openToOpportunities,
      );
}

enum ProfileVisibility {
  everyone('everyone', 'Everyone', 'Anyone on TalentRadar can find your profile'),
  recruitersOnly(
    'recruiters_only',
    'Recruiters only',
    'Only verified recruiters can discover you',
  ),
  connectionsOnly(
    'connections_only',
    'Connections only',
    'Only people you have accepted can see your profile',
  ),
  private('private', 'Private', 'You stay off the radar until you reach out first');

  const ProfileVisibility(this.wire, this.label, this.description);
  final String wire;
  final String label;
  final String description;

  static ProfileVisibility fromWire(String? value) => ProfileVisibility.values.firstWhere(
        (visibility) => visibility.wire == value,
        orElse: () => ProfileVisibility.recruitersOnly,
      );
}

/// Where a registration has reached, so a returning user resumes rather than
/// starting over.
enum OnboardingStage {
  registered('registered'),
  emailVerified('email_verified'),
  locationSet('location_set'),
  complete('complete');

  const OnboardingStage(this.wire);
  final String wire;

  static OnboardingStage fromWire(String? value) => OnboardingStage.values.firstWhere(
        (stage) => stage.wire == value,
        orElse: () => OnboardingStage.registered,
      );
}
