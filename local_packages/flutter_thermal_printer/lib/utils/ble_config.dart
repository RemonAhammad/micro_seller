class BleConfig {
  const BleConfig({
    this.connectionStabilizationDelay = const Duration(seconds: 10),
  });

  final Duration connectionStabilizationDelay;

  BleConfig copyWith({
    Duration? connectionStabilizationDelay,
  }) =>
      BleConfig(
        connectionStabilizationDelay:
            connectionStabilizationDelay ?? this.connectionStabilizationDelay,
      );

  @override
  String toString() =>
      'BleConfig(connectionStabilizationDelay: $connectionStabilizationDelay)';
}
