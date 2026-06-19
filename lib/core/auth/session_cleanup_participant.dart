abstract interface class SessionCleanupParticipant {
  Future<void> clearForUser(String userId);
}
