import 'package:flutter_app_packager/src/api/app_package_maker.dart';

class AppPackageMakerApk extends AppPackageMaker {
  @override
  String get name => 'apk';

  @override
  String get platform => 'android';

  @override
  String get packageFormat => 'apk';

  @override
  Future<MakeResult> make(MakeConfig config) {
    for (final file in config.buildOutputFiles) {
      final fileName = file.uri.pathSegments.last;
      final splits = fileName.split('-');
      final outputPath = config.outputFile.path;
      final lastDotIndex = outputPath.lastIndexOf('.');
      final firstPart = outputPath.substring(0, lastDotIndex);
      final lastPart = outputPath.substring(lastDotIndex + 1);
      
      if (splits.length > 2) {
        // Split APK (contains architecture: armeabi-v7a, arm64-v8a, x86_64)
        final sublist = splits.sublist(1, splits.length - 1);
        final output = '$firstPart-${sublist.join('-')}.${lastPart}';
        file.copySync(output);
      } else {
        // Universal APK (no architecture in filename)
        final output = '$firstPart-universal.${lastPart}';
        file.copySync(output);
      }
    }
    return Future.value(resultResolver.resolve(config));
  }
}
