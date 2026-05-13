import 'package:flutter/foundation.dart';

enum AppCapabilityAvailability { supported, needsSetup, unsupported }

@immutable
class AppCapabilityState {
  const AppCapabilityState({
    required this.availability,
    required this.label,
    this.reason,
    this.setupActionLabel,
  });

  const AppCapabilityState.supported({required String label})
    : this(availability: AppCapabilityAvailability.supported, label: label);

  const AppCapabilityState.needsSetup({
    required String label,
    required String reason,
    String? setupActionLabel,
  }) : this(
         availability: AppCapabilityAvailability.needsSetup,
         label: label,
         reason: reason,
         setupActionLabel: setupActionLabel,
       );

  const AppCapabilityState.unsupported({
    required String label,
    required String reason,
  }) : this(
         availability: AppCapabilityAvailability.unsupported,
         label: label,
         reason: reason,
       );

  final AppCapabilityAvailability availability;
  final String label;
  final String? reason;
  final String? setupActionLabel;

  bool get isSupported => availability == AppCapabilityAvailability.supported;
  bool get needsSetup => availability == AppCapabilityAvailability.needsSetup;
  bool get isUnsupported =>
      availability == AppCapabilityAvailability.unsupported;
  bool get canShowEntry => isSupported || needsSetup;
}
