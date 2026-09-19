import 'package:flutter_test/flutter_test.dart';
import 'package:talentradar/core/utils/validators.dart';
import 'package:talentradar/data/models/enums.dart';
import 'package:talentradar/data/models/job_title.dart';
import 'package:talentradar/data/models/registration_draft.dart';
import 'package:talentradar/data/models/session.dart';

void main() {
  group('Validators.name', () {
    test('rejects blank, single letters and meaningless values', () {
      expect(Validators.name(''), isNotNull);
      expect(Validators.name('A'), isNotNull);
      expect(Validators.name('aaaa'), isNotNull);
      expect(Validators.name('12345'), isNotNull);
      expect(Validators.name('....'), isNotNull);
    });

    test('accepts real names', () {
      expect(Validators.name('Aditi Sharma'), isNull);
      expect(Validators.name('  Riya  Joshi '), isNull);
    });

    test('tidy collapses whitespace', () {
      expect(Validators.tidy('  Aditi   Sharma '), 'Aditi Sharma');
    });
  });

  group('Validators.email', () {
    test('validates format', () {
      expect(Validators.email(''), 'Please enter your email address.');
      expect(Validators.email('aditi@'), 'Please enter a valid email address.');
      expect(Validators.email('aditi.sharma@gmail.com'), isNull);
      expect(Validators.email('hr+jobs@abc-tech.co.in'), isNull);
    });
  });

  group('Validators.otp and password', () {
    test('otp must be exactly six digits', () {
      expect(Validators.otp('12345'), isNotNull);
      expect(Validators.otp('12a456'), isNotNull);
      expect(Validators.otp('123456'), isNull);
    });

    test('password is optional but must be 8+ when given', () {
      expect(Validators.password(''), isNull);
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('longenough'), isNull);
    });
  });

  group('CandidateDraft', () {
    const title = JobTitle(code: 'JT_040', name: 'Software Support Executive');

    test('requires name, email, job title and work mode', () {
      const empty = CandidateDraft();
      expect(empty.isSubmittable, isFalse);

      final full = empty.copyWith(
        name: 'Aditi Sharma',
        email: 'aditi@example.com',
        jobTitles: [title],
        workModes: [WorkMode.hybrid],
      );
      expect(full.isSubmittable, isTrue);
      expect(full.copyWith(workModes: []).isSubmittable, isFalse);
      expect(full.copyWith(jobTitles: []).isSubmittable, isFalse);
    });

    test('sends title codes, not free text, with privacy-conscious defaults', () {
      final request = const CandidateDraft()
          .copyWith(
            name: ' Aditi ',
            email: 'aditi@example.com',
            jobTitles: [title],
            workModes: [WorkMode.remote, WorkMode.hybrid],
          )
          .toRequest();

      expect(request['name'], 'Aditi');
      expect(request['jobTitleCodes'], ['JT_040']);
      expect(request['workModes'], ['remote', 'hybrid']);
      expect(request['profileVisibility'], 'recruiters_only');
      expect(request['experienceLevel'], 'fresher');
      expect(request.containsKey('password'), isFalse);
    });
  });

  group('RecruiterDraft', () {
    test('requires company, HR name, email and a hiring profile', () {
      final draft = const RecruiterDraft().copyWith(
        companyName: 'ABC Technologies',
        hrName: 'Riya Joshi',
        email: 'riya@abctech.com',
      );
      expect(draft.isSubmittable, isFalse);
      expect(
        draft.copyWith(
          hiringProfiles: const [JobTitle(code: 'JT_001', name: 'Software Engineer')],
        ).isSubmittable,
        isTrue,
      );
    });
  });

  group('JobTitle', () {
    test('explains an alias match', () {
      const title = JobTitle(
        code: 'JT_001',
        name: 'Software Engineer',
        aliases: ['SDE', 'Programmer'],
      );
      expect(title.matchedAlias('sde'), 'SDE');
      expect(title.matchedAlias('software'), isNull);
    });
  });

  group('Session parsing', () {
    test('reads a candidate session and tolerates unknown values', () {
      final session = Session.fromJson({
        'token': 't',
        'user': {
          'userId': 'u1',
          'email': 'aditi@example.com',
          'role': 'candidate',
          'isEmailVerified': true,
          'onboardingStage': 'location_set',
        },
        'profile': {
          'name': 'Aditi Sharma',
          'email': 'aditi@example.com',
          'jobTitles': [
            {'code': 'JT_040', 'name': 'Software Support Executive', 'category': 'Support'},
          ],
          'experienceLevel': '1_2',
          'workModes': ['hybrid', 'unknown_future_mode'],
          'openToWork': 'actively_looking',
          'profileVisibility': 'recruiters_only',
          'stealthMode': false,
          'location': {'area': 'HSR Layout', 'city': 'Bengaluru', 'isSet': true},
        },
      });

      expect(session.isCandidate, isTrue);
      expect(session.candidate!.initials, 'AS');
      expect(session.candidate!.experienceLevel, ExperienceLevel.oneToTwo);
      // A mode added by a newer server is dropped rather than crashing.
      expect(session.candidate!.workModes, [WorkMode.hybrid]);
      expect(session.candidate!.location.display, 'HSR Layout, Bengaluru');
      expect(session.user.onboardingStage, OnboardingStage.locationSet);
    });
  });
}
