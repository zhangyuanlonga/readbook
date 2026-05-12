import 'membership_device_seat.dart';

class MembershipSeatSyncResult {
  const MembershipSeatSyncResult({
    required this.deviceStatus,
    required this.maxDevices,
    required this.activeDeviceCount,
    required this.seat,
  });

  final String deviceStatus;
  final int maxDevices;
  final int activeDeviceCount;
  final MembershipDeviceSeat? seat;

  bool get isOverLimit => deviceStatus == 'over_limit';

  factory MembershipSeatSyncResult.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    final rawSeat = json['seat'];
    final seat =
        rawSeat is Map
            ? MembershipDeviceSeat.fromJson(
              rawSeat.map((key, value) => MapEntry(key.toString(), value)),
            )
            : null;

    return MembershipSeatSyncResult(
      deviceStatus: json['device_status']?.toString().trim() ?? 'ok',
      maxDevices: readInt('max_devices', 1),
      activeDeviceCount: readInt('active_device_count', 0),
      seat: seat,
    );
  }
}
