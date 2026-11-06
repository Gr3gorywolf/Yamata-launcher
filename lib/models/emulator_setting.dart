import 'package:yamata_launcher/models/contracts/json_serializable.dart';
import 'package:yamata_launcher/models/runner_configuration.dart';

class EmulatorSetting implements JsonSerializable {
  String console = "";
  String emulatorBinary = "";
  String launchParams = "";
  RunnerConfiguration? runnerConfig;

  EmulatorSetting(
      {required this.console,
      required this.emulatorBinary,
      this.launchParams = "",
      this.runnerConfig});

  EmulatorSetting.fromJson(Map<String, dynamic> json) {
    console = json['console'];
    emulatorBinary = json['emulatorBinary'];
    launchParams = json['launchParams'] ?? "";
    final runnerConfigJson = json['runnerConfig'];
    runnerConfig = runnerConfigJson is Map
        ? RunnerConfiguration.fromJson(
            Map<String, dynamic>.from(runnerConfigJson))
        : null;
  }

  EmulatorSetting copyWith({
    String? console,
    String? emulatorBinary,
    String? launchParams,
    RunnerConfiguration? runnerConfig,
    bool clearRunnerConfig = false,
  }) {
    return EmulatorSetting(
      console: console ?? this.console,
      emulatorBinary: emulatorBinary ?? this.emulatorBinary,
      launchParams: launchParams ?? this.launchParams,
      runnerConfig:
          clearRunnerConfig ? null : (runnerConfig ?? this.runnerConfig),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['console'] = this.console;
    data['emulatorBinary'] = this.emulatorBinary;
    data['launchParams'] = this.launchParams;
    if (runnerConfig != null) {
      data['runnerConfig'] = runnerConfig!.toJson();
    }
    return data;
  }
}
