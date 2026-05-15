const String serverGatewaySourceIdPrefix = 'server-gateway:';

bool isServerGatewaySourceId(String sourceId) {
  return sourceId.trim().startsWith(serverGatewaySourceIdPrefix);
}

String toServerGatewaySourceId(String sourceId) {
  final normalized = sourceId.trim();
  if (normalized.isEmpty || isServerGatewaySourceId(normalized)) {
    return normalized;
  }
  return '$serverGatewaySourceIdPrefix$normalized';
}

String fromServerGatewaySourceId(String sourceId) {
  final normalized = sourceId.trim();
  if (!isServerGatewaySourceId(normalized)) {
    return normalized;
  }
  return normalized.substring(serverGatewaySourceIdPrefix.length);
}
