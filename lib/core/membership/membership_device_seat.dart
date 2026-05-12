class MembershipDeviceSeat {
  const MembershipDeviceSeat({
    required this.id,
    required this.installId,
    required this.deviceUid,
    required this.deviceFingerprint,
    required this.seatStatus,
    required this.boundAt,
    required this.lastSeenAt,
    required this.releasedAt,
    required this.releaseReason,
  });

  final String id;
  final String installId;
  final String? deviceUid;
  final String? deviceFingerprint;
  final String seatStatus;
  final DateTime? boundAt;
  final DateTime? lastSeenAt;
  final DateTime? releasedAt;
  final String? releaseReason;

  bool get isActive => seatStatus == 'active';

  factory MembershipDeviceSeat.fromJson(Map<String, dynamic> json) {
    DateTime? readTime(String key) {
      final raw = json[key]?.toString().trim() ?? '';
      if (raw.isEmpty) {
        return null;
      }
      return DateTime.tryParse(raw)?.toUtc();
    }

    String? readOptionalString(String key) {
      final raw = json[key]?.toString().trim() ?? '';
      return raw.isEmpty ? null : raw;
    }

    return MembershipDeviceSeat(
      id: json['id']?.toString().trim() ?? '',
      installId: json['install_id']?.toString().trim() ?? '',
      deviceUid: readOptionalString('device_uid'),
      deviceFingerprint: readOptionalString('device_fingerprint'),
      seatStatus: json['seat_status']?.toString().trim() ?? 'released',
      boundAt: readTime('bound_at'),
      lastSeenAt: readTime('last_seen_at'),
      releasedAt: readTime('released_at'),
      releaseReason: readOptionalString('release_reason'),
    );
  }
}
