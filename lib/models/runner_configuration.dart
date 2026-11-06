import 'package:yamata_launcher/models/contracts/json_serializable.dart';

/// Configuration owned by a game runner.
///
/// Yamata only needs to understand which runner owns the configuration. Each
/// runner owns the contents of [settings], which lets runners evolve without
/// adding runner-specific fields to [EmulatorSetting].
class RunnerConfiguration implements JsonSerializable {
  final String runnerId;
  final Map<String, dynamic> settings;

  RunnerConfiguration({
    required this.runnerId,
    Map<String, dynamic>? settings,
  }) : settings = Map<String, dynamic>.from(settings ?? const {});

  factory RunnerConfiguration.fromJson(Map<String, dynamic> json) {
    final runnerId = json['runnerId'];
    if (runnerId is! String || runnerId.isEmpty) {
      throw const FormatException('Runner configuration requires runnerId');
    }

    final rawSettings = json['settings'];
    return RunnerConfiguration(
      runnerId: runnerId,
      settings: rawSettings is Map
          ? Map<String, dynamic>.from(rawSettings)
          : const {},
    );
  }

  RunnerConfiguration copyWith({Map<String, dynamic>? settings}) {
    return RunnerConfiguration(
        runnerId: runnerId, settings: settings ?? this.settings);
  }

  @override
  Map<String, dynamic> toJson() => {
        'runnerId': runnerId,
        'settings': settings,
      };
}
