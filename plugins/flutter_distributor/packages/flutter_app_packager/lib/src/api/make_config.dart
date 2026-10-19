import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_packager/src/api/make_error.dart';
import 'package:flutter_app_packager/src/api/distribute_options_base.dart';
import 'package:mustache_template/mustache.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

const _kArtifactName =
    '{{name}}{{#description}}-{{description}}{{/description}}{{#is_installer}}-setup{{/is_installer}}{{#ext}}.{{ext}}{{/ext}}';

class MakeConfig {
  late bool isInstaller = false;
  late String buildMode;
  late Directory buildOutputDirectory;
  late List<File> buildOutputFiles;
  late String platform;
  String? flavor;
  String? arch;
  String? channel;
  String? description;

  /// https://mustache.github.io/mustache.5.html
  String? artifactName;
  late String packageFormat;
  late Directory outputDirectory;

  String get appName => distributeOptionsBase.appName ?? pubspec.name;

  String get appBinaryName => distributeOptionsBase.appName ?? pubspec.name;

  Version get appVersion => pubspec.version!;

  String get appBuildName => appVersion.toString().split('+').first;

  String get appBuildNumber => appVersion.toString().split('+').last;

  Pubspec? _pubspec;
  DistributeOptionsBase? _distributeOptionsBase;
  Directory? _packagingDirectory;

  MakeConfig copyWith(MakeConfig makeConfig) {
    buildMode = makeConfig.buildMode;
    buildOutputDirectory = makeConfig.buildOutputDirectory;
    buildOutputFiles = makeConfig.buildOutputFiles;
    platform = makeConfig.platform;
    description = makeConfig.description;
    arch = makeConfig.arch;
    flavor = makeConfig.flavor;
    channel = makeConfig.channel;
    artifactName = makeConfig.artifactName;
    packageFormat = makeConfig.packageFormat;
    outputDirectory = makeConfig.outputDirectory;
    return this;
  }

  File get outputFile {
    if (packageFormat.isEmpty) {
      throw MakeError('Direct output is not a file');
    }
    return File(outputArtifactPath);
  }

  String get outputArtifactPath {
    String useArtifactName = _kArtifactName;
    if (artifactName != null) useArtifactName = artifactName!;

    Map<String, dynamic> variables = {
      'is_installer': isInstaller,
      'is_profile': buildMode == 'profile',
      'name': appName,
      'version': appVersion.toString(),
      'build_name': appBuildName,
      'build_number': appBuildNumber,
      'build_mode': buildMode,
      'platform': platform,
      'flavor': flavor,
      'channel': channel,
      'description': description,
      'ext': packageFormat.isEmpty ? null : packageFormat,
    };

    String filename = Template(useArtifactName).renderString(variables);

    Directory versionOutputDirectory = Directory(outputDirectory.path);

    if (!versionOutputDirectory.existsSync()) {
      versionOutputDirectory.createSync(recursive: true);
    }

    return '${versionOutputDirectory.path}/$filename';
  }

  List<FileSystemEntity> get outputArtifacts {
    List<FileSystemEntity> artifacts = [];
    if (packageFormat.isEmpty) {
      artifacts.add(Directory(outputArtifactPath));
    } else {
      artifacts.add(File(outputArtifactPath));
    }
    return artifacts;
  }

  Directory get packagingDirectory {
    if (_packagingDirectory == null) {
      _packagingDirectory = Directory(
        outputArtifactPath.replaceAll('.$packageFormat', '_$packageFormat'),
      );
      if (_packagingDirectory!.existsSync()) {
        _packagingDirectory!.deleteSync(recursive: true);
      }
      _packagingDirectory!.createSync(recursive: true);
    }
    return _packagingDirectory!;
  }

  Pubspec get pubspec {
    if (_pubspec == null) {
      final yamlString = File('pubspec.yaml').readAsStringSync();
      _pubspec = Pubspec.parse(yamlString);
    }
    return _pubspec!;
  }

  DistributeOptionsBase get distributeOptionsBase {
    if (_distributeOptionsBase == null) {
      File file = File('distribute_options.yaml');
      if (file.existsSync()) {
        final yamlString = File('distribute_options.yaml').readAsStringSync();
        final yamlDoc = loadYaml(yamlString);
        _distributeOptionsBase = DistributeOptionsBase.fromJson(
          json.decode(json.encode(yamlDoc)),
        );
      } else {
        _distributeOptionsBase = DistributeOptionsBase();
      }
    }
    return _distributeOptionsBase!;
  }

  Map<String, dynamic> toJson() {
    return {
      'isInstaller': isInstaller,
      'buildMode': buildMode,
      'buildOutputDirectory': buildOutputDirectory.path,
      'buildOutputFiles': buildOutputFiles.map((e) => e.path).toList(),
      'platform': platform,
      'arch': arch,
      'description': description,
      'flavor': flavor,
      'channel': channel,
      'artifactName': artifactName,
      'packageFormat': packageFormat,
      'outputDirectory': outputDirectory.path,
      'appName': appName,
      'appVersion': appVersion.toString(),
      'appBuildName': appBuildName,
      'appBuildNumber': appBuildNumber,
    }..removeWhere((key, value) => value == null);
  }
}

abstract class MakeConfigLoader {
  late String platform;
  late String packageFormat;

  MakeConfig load(
    Map<String, dynamic>? arguments,
    Directory outputDirectory, {
    required Directory buildOutputDirectory,
    required List<File> buildOutputFiles,
  });
}

class DefaultMakeConfigLoader extends MakeConfigLoader {
  @override
  MakeConfig load(
    Map<String, dynamic>? arguments,
    Directory outputDirectory, {
    required Directory buildOutputDirectory,
    required List<File> buildOutputFiles,
  }) {
    return MakeConfig()
      ..platform = platform
      ..arch = arguments?['arch']
      ..buildMode = arguments?['build_mode']
      ..buildOutputDirectory = buildOutputDirectory
      ..buildOutputFiles = buildOutputFiles
      ..flavor = arguments?['flavor']
      ..description = arguments?['description']
      ..channel = arguments?['channel']
      ..artifactName = arguments?['artifact_name']
      ..packageFormat = packageFormat
      ..outputDirectory = outputDirectory;
  }
}

class MakeLinuxPackageConfig extends MakeConfig {
  String? _appBinaryName;

  @override
  String get appBinaryName {
    if (_appBinaryName == null) {
      final cMakeListsFile = File('linux/CMakeLists.txt');
      final RegExp regex = RegExp(r'(?<=set\(BINARY_NAME\s")[^"]+(?="\))');
      final Match? match = regex.firstMatch(cMakeListsFile.readAsStringSync());

      if (match != null) {
        final String? binaryName = match.group(0);
        _appBinaryName = binaryName;
      } else {
        _appBinaryName = appName;
      }
    }
    return _appBinaryName!;
  }
}
