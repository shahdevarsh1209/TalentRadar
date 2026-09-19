import 'package:geolocator/geolocator.dart';

import '../models/registration_draft.dart';

/// Outcome of asking the device where it is. Every failure mode is named, so the
/// screen can offer the manual picker instead of showing a dead end.
enum LocationOutcome { granted, denied, deniedForever, serviceDisabled, failed }

class DeviceLocationResult {
  const DeviceLocationResult(this.outcome, [this.choice]);

  final LocationOutcome outcome;
  final LocationChoice? choice;

  bool get isGranted => outcome == LocationOutcome.granted && choice != null;

  /// Copy for the screen. Location is optional throughout, so none of these
  /// messages are framed as errors the user has to resolve.
  String get message => switch (outcome) {
        LocationOutcome.granted => 'Location set.',
        LocationOutcome.denied =>
          'No problem — you can choose your area manually instead.',
        LocationOutcome.deniedForever =>
          'Location is turned off for TalentRadar in your device settings. You can still choose your area manually.',
        LocationOutcome.serviceDisabled =>
          'Location services are switched off on this device. Turn them on, or choose your area manually.',
        LocationOutcome.failed =>
          'We could not read your location just now. Please choose your area manually.',
      };
}

/// Wraps geolocator so nothing above this file imports a plugin directly and
/// the whole flow stays testable with a fake.
class DeviceLocationService {
  Future<DeviceLocationResult> requestCurrentArea() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceLocationResult(LocationOutcome.serviceDisabled);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationResult(LocationOutcome.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const DeviceLocationResult(LocationOutcome.denied);
      }

      // Low accuracy is deliberate: the product only ever needs the area, and
      // asking for less precision is both faster and kinder to the battery.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return DeviceLocationResult(
        LocationOutcome.granted,
        LocationChoice(
          source: 'device',
          latitude: position.latitude,
          longitude: position.longitude,
          label: 'Your current area',
        ),
      );
    } catch (_) {
      return const DeviceLocationResult(LocationOutcome.failed);
    }
  }
}
