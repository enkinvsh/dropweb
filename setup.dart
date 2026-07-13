// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';

enum Target {
  windows,
  linux,
  android,
  macos,
}

extension TargetExt on Target {
  String get os {
    if (this == Target.macos) {
      return "darwin";
    }
    return name;
  }

  bool get same {
    if (this == Target.android) {
      return true;
    }
    if (Platform.isWindows && this == Target.windows) {
      return true;
    }
    if (Platform.isLinux && this == Target.linux) {
      return true;
    }
    if (Platform.isMacOS && this == Target.macos) {
      return true;
    }
    return false;
  }

  String get dynamicLibExtensionName {
    final String extensionName;
    switch (this) {
      case Target.android || Target.linux:
        extensionName = ".so";
        break;
      case Target.windows:
        extensionName = ".dll";
        break;
      case Target.macos:
        extensionName = ".dylib";
        break;
    }
    return extensionName;
  }

  String get executableExtensionName {
    final String extensionName;
    switch (this) {
      case Target.windows:
        extensionName = ".exe";
        break;
      default:
        extensionName = "";
        break;
    }
    return extensionName;
  }
}

enum Mode { core, lib }

enum Arch { amd64, arm64, arm }

class BuildItem {
  Target target;
  Arch? arch;
  String? archName;

  BuildItem({
    required this.target,
    this.arch,
    this.archName,
  });

  @override
  String toString() =>
      'BuildLibItem{target: $target, arch: $arch, archName: $archName}';
}

class Build {
  static List<BuildItem> get buildItems => [
        BuildItem(
          target: Target.macos,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.macos,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.linux,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.linux,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.windows,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.windows,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.arm,
          archName: 'armeabi-v7a',
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.arm64,
          archName: 'arm64-v8a',
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.amd64,
          archName: 'x86_64',
        ),
      ];

  static String get appName => "dropweb";

  static String get coreName => "DropwebCore";

  static String get libName => "libclash";

  static String get outDir => join(current, libName);

  static String get _coreDir => join(current, "core");

  static String get _servicesDir => join(current, "services", "helper");

  static String get distPath => join(current, "dist");

  static String _getCc(BuildItem buildItem) {
    final environment = Platform.environment;
    if (buildItem.target == Target.android) {
      final ndk = environment["ANDROID_NDK"];
      assert(ndk != null);
      final prebuiltDir =
          Directory(join(ndk!, "toolchains", "llvm", "prebuilt"));
      final prebuiltDirList = prebuiltDir.listSync();
      final map = {
        "armeabi-v7a": "armv7a-linux-androideabi21-clang",
        "arm64-v8a": "aarch64-linux-android21-clang",
        "x86": "i686-linux-android21-clang",
        "x86_64": "x86_64-linux-android21-clang"
      };
      return join(
        prebuiltDirList.first.path,
        "bin",
        map[buildItem.archName],
      );
    }
    return "gcc";
  }

  static get tags => "with_gvisor";

  static Future<void> exec(
    List<String> executable, {
    String? name,
    Map<String, String>? environment,
    String? workingDirectory,
    bool runInShell = true,
  }) async {
    if (name != null) print("run $name");
    final process = await Process.start(
      executable[0],
      executable.sublist(1),
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
    process.stdout.listen((data) {
      print(utf8.decode(data));
    });
    process.stderr.listen((data) {
      print(utf8.decode(data));
    });
    final exitCode = await process.exitCode;
    if (exitCode != 0 && name != null) throw "$name error";
  }

  static Future<String> calcSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw "File not exists";
    }
    final stream = file.openRead();
    return sha256.convert(await stream.reduce((a, b) => a + b)).toString();
  }

  static Future<String> extractCoreVersion() async {
    final versionFile =
        File(join("core", "Clash.Meta", "constant", "version.go"));
    if (!await versionFile.exists()) {
      throw "version.go file not found";
    }
    final content = await versionFile.readAsString();
    final versionRegex = RegExp(r'Version\s*=\s*"([^"]+)"');
    final match = versionRegex.firstMatch(content);
    if (match == null) {
      throw "Could not extract version from version.go";
    }
    return match.group(1)!;
  }

  static Future<List<String>> buildCore({
    required Mode mode,
    required Target target,
    Arch? arch,
  }) async {
    final isLib = mode == Mode.lib;

    final items = buildItems
        .where(
          (element) =>
              element.target == target &&
              (arch == null ? true : element.arch == arch),
        )
        .toList();

    final List<String> corePaths = [];

    final targetOutFilePath = join(outDir, target.name);
    final targetOutFile = File(targetOutFilePath);
    if (await targetOutFile.exists()) {
      await targetOutFile.delete(recursive: true);
      await Directory(targetOutFilePath).create(recursive: true);
    }

    for (final item in items) {
      final outFilePath = join(targetOutFilePath, item.archName);
      final file = File(outFilePath);
      if (file.existsSync()) {
        file.deleteSync(recursive: true);
      }

      final fileName = isLib
          ? "$libName${item.target.dynamicLibExtensionName}"
          : "$coreName${item.target.executableExtensionName}";
      final realOutPath = join(outFilePath, fileName);
      corePaths.add(realOutPath);

      // Ensure the output directory exists (libclash/ is gitignored,
      // so it won't be present on a fresh CI checkout)
      final outDirectory = Directory(dirname(realOutPath));
      if (!outDirectory.existsSync()) {
        await outDirectory.create(recursive: true);
      }

      final Map<String, String> env = {};
      env["GOOS"] = item.target.os;
      if (item.arch != null) {
        env["GOARCH"] = item.arch!.name;
      }
      if (isLib) {
        env["CGO_ENABLED"] = "1";
        env["CC"] = _getCc(item);
        env["CFLAGS"] = "-O3 -Werror";
        // Android 16KB page size alignment — required by Google Play (Nov 2025+).
        // Without this, libclash.so fails Pixel 10/9/8 page alignment check and
        // is rejected by Play Console. See developer.android.com/16kb-page-size.
        if (item.target == Target.android) {
          env["CGO_LDFLAGS"] = "-O2 -s -w -Wl,-z,max-page-size=16384";
        }
      } else {
        env["CGO_ENABLED"] = "0";
      }

      final execLines = [
        "go",
        "build",
        "-ldflags=-w -s",
        "-tags=$tags",
        if (isLib) "-buildmode=c-shared",
        "-o",
        realOutPath,
      ];
      await exec(
        execLines,
        name: "build core",
        environment: env,
        workingDirectory: _coreDir,
      );
      if (isLib && item.archName != null) {
        await adjustLibOut(
          targetOutFilePath: targetOutFilePath,
          outFilePath: outFilePath,
          archName: item.archName!,
        );
      }
    }

    return corePaths;
  }

  static Future<void> adjustLibOut({
    required String targetOutFilePath,
    required String outFilePath,
    required String archName,
  }) async {
    final includesPath = join(targetOutFilePath, "includes");
    final realOutPath = join(includesPath, archName);
    await Directory(realOutPath).create(recursive: true);
    final targetOutFiles = Directory(outFilePath).listSync();
    final coreFiles = Directory(_coreDir).listSync();
    for (final file in [...targetOutFiles, ...coreFiles]) {
      if (!file.path.endsWith('.h')) {
        continue;
      }
      final targetFilePath = join(realOutPath, basename(file.path));
      final realFile = File(file.path);
      await realFile.copy(targetFilePath);
      if (coreFiles.contains(file)) {
        continue;
      }
      await realFile.delete();
    }
  }

  static buildHelper(Target target, String token, {Arch? arch}) async {
    final List<String> buildArgs = [
      "cargo",
      "build",
      "--release",
      "--features",
      "windows-service",
    ];

    // Add target for cross-compilation
    if (arch == Arch.arm64 && target == Target.windows) {
      buildArgs.addAll(["--target", "aarch64-pc-windows-msvc"]);
    }

    await exec(
      buildArgs,
      environment: {
        "TOKEN": token,
      },
      name: "build helper",
      workingDirectory: _servicesDir,
    );

    // Determine output path based on architecture
    final String releasePath;
    if (arch == Arch.arm64 && target == Target.windows) {
      releasePath =
          join(_servicesDir, "target", "aarch64-pc-windows-msvc", "release");
    } else {
      releasePath = join(_servicesDir, "target", "release");
    }

    final outPath = join(
      releasePath,
      "helper${target.executableExtensionName}",
    );
    final targetPath = join(
      outDir,
      target.name,
      "DropwebHelperService${target.executableExtensionName}",
    );
    await File(outPath).copy(targetPath);
  }

  static List<String> getExecutable(String command) => command.split(" ");

  static getDistributor() async {
    final distributorDir = join(
      current,
      "plugins",
      "flutter_distributor",
      "packages",
      "flutter_distributor",
    );

    await exec(
      name: "clean distributor",
      Build.getExecutable("flutter clean"),
      workingDirectory: distributorDir,
    );
    await exec(
      name: "upgrade distributor",
      Build.getExecutable("flutter pub upgrade"),
      workingDirectory: distributorDir,
    );
    await exec(
      name: "get distributor",
      Build.getExecutable("dart pub global activate -s path $distributorDir"),
    );
  }

  static copyFile(String sourceFilePath, String destinationFilePath) {
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      throw "SourceFilePath not exists";
    }
    final destinationFile = File(destinationFilePath);
    final destinationDirectory = destinationFile.parent;
    if (!destinationDirectory.existsSync()) {
      destinationDirectory.createSync(recursive: true);
    }
    try {
      sourceFile.copySync(destinationFilePath);
      print("File copied successfully!");
    } catch (e) {
      print("Failed to copy file: $e");
    }
  }
}

class BuildCommand extends Command {
  Target target;

  BuildCommand({
    required this.target,
  }) {
    if (target == Target.android || target == Target.linux) {
      argParser.addOption(
        "arch",
        valueHelp: arches.map((e) => e.name).join(','),
        help: 'The $name build desc',
      );
    } else {
      argParser.addOption(
        "arch",
        help: 'The $name build archName',
      );
    }
    argParser.addOption(
      "out",
      valueHelp: [
        if (target.same) "app",
        "core",
      ].join(','),
      help: 'The $name build arch',
    );
    argParser.addOption(
      "env",
      valueHelp: [
        "pre",
        "stable",
      ].join(','),
      help: 'The $name build env',
    );
    // Android APK builds always use split-per-abi and never package universal APKs.
  }

  @override
  String get description => "build $name application";

  @override
  String get name => target.name;

  List<Arch> get arches => Build.buildItems
      .where((element) => element.target == target && element.arch != null)
      .map((e) => e.arch!)
      .toList();

  _getLinuxDependencies(Arch arch) async {
    await Build.exec(
      Build.getExecutable("sudo apt update -y"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y ninja-build libgtk-3-dev libsecret-1-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y libayatana-appindicator3-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt-get install -y libkeybinder-3.0-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y locate"),
    );
    if (arch == Arch.amd64) {
      await Build.exec(
        Build.getExecutable("sudo apt install -y rpm patchelf"),
      );
      await Build.exec(
        Build.getExecutable("sudo apt install -y libfuse2"),
      );

      final downloadName = arch == Arch.amd64 ? "x86_64" : "aarch64";
      await Build.exec(
        Build.getExecutable(
          "wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$downloadName.AppImage",
        ),
      );
      await Build.exec(
        Build.getExecutable(
          "chmod +x appimagetool",
        ),
      );
      await Build.exec(
        Build.getExecutable(
          "sudo mv appimagetool /usr/local/bin/",
        ),
      );
    }
  }

  // Map dart [Arch] → the Mach-O slice name understood by `lipo`.
  static const _lipoArch = {Arch.amd64: "x86_64", Arch.arm64: "arm64"};

  /// Thin one Mach-O file down to [sliceArch], in place. Returns true if the
  /// file was fat and got thinned, false if it was skipped (not a Mach-O or
  /// already single-arch).
  ///
  /// `lipo` refuses to rewrite its own input, so we thin into a sibling temp
  /// file and copy the bytes back over the original with `writeAsBytes` — that
  /// truncates the existing inode rather than recreating it, so the file keeps
  /// its permission bits (a plain rename would drop the executable's +x mode to
  /// 0644 and break launch). [failLoud] throws on any lipo failure — used for
  /// the main executable, where a broken thin must NEVER ship silently;
  /// per-framework thinning warns-and-continues (some frameworks are thin).
  Future<bool> _thinMachO(
    String path,
    String sliceArch, {
    required bool failLoud,
  }) async {
    final info = await Process.run("lipo", ["-info", path]);
    if (info.exitCode != 0) {
      return false; // not a Mach-O (plist, asset, dead symlink, …)
    }
    // Only fat binaries carry this banner; "Non-fat file:" means already thin.
    if (!info.stdout.toString().contains("Architectures in the fat file")) {
      return false;
    }
    final tmpPath = "$path.thin-tmp";
    final thin = await Process.run(
      "lipo",
      [path, "-thin", sliceArch, "-output", tmpPath],
    );
    if (thin.exitCode != 0) {
      final tmpFile = File(tmpPath);
      if (tmpFile.existsSync()) tmpFile.deleteSync();
      final msg = "lipo -thin $sliceArch failed for $path: ${thin.stderr}";
      if (failLoud) throw msg;
      print("⚠️  $msg (skipping)");
      return false;
    }
    final bytes = await File(tmpPath).readAsBytes();
    await File(path).writeAsBytes(bytes, flush: true);
    await File(tmpPath).delete();
    return true;
  }

  _buildMacosApp({
    required Arch arch,
    required String env,
    required String coreVersion,
  }) async {
    await Build.exec(
      name: "flutter build macos",
      [
        "flutter",
        "build",
        "macos",
        "--release",
        "--dart-define=APP_ENV=$env",
        "--dart-define=CORE_VERSION=$coreVersion",
      ],
    );

    final appName = Build.appName;
    final appPath = join(current, "build", "macos", "Build", "Products",
        "Release", "$appName.app");

    // ── ARCH-HONEST DMG ─────────────────────────────────────────────────────
    // Field incident (Intel Mac, Monterey, pre.7): `flutter build macos` ALWAYS
    // emits UNIVERSAL Mach-O (the main app AND every bundled framework), but the
    // DropwebCore helper that Xcode's CopyFiles brings in is SINGLE-ARCH (built
    // per --arch). So an arm64 dmg opened on an Intel Mac still LAUNCHED (the
    // universal main simply ran its native x86_64 slice), then copied its
    // arm64-only core into Application Support as root+setuid. That poisoned
    // core then survived every later correct install — the old mtime heuristic
    // saw the bundle core as "not newer" and never re-copied it → helper died
    // `bad CPU type in executable` → the main app wrote to the dead helper
    // socket → SIGPIPE, exit 141, tray icon a single-frame flash. Fix: thin the
    // main binary and frameworks down to THIS dmg's target arch, so an arm64 dmg
    // simply CANNOT open on an Intel Mac (macOS shows a clear "app can't be
    // opened on this Mac" message) instead of silently poisoning it — and the
    // dmgs shrink too.
    // The `codesign --deep --force` below runs AFTER this, so the ad-hoc
    // signatures over the now-thinned Mach-Os stay valid.
    final sliceArch = _lipoArch[arch]!;

    final mainExecPath = join(appPath, "Contents", "MacOS", appName);
    print("Thinning main executable → $sliceArch");
    // failLoud: a broken main thin must abort the build, never ship.
    await _thinMachO(mainExecPath, sliceArch, failLoud: true);

    final frameworksDir = Directory(join(appPath, "Contents", "Frameworks"));
    if (frameworksDir.existsSync()) {
      var thinnedCount = 0;
      // Walk every regular file under Frameworks — handles the
      // X.framework/Versions/A/X layout plus any loose .dylibs. followLinks
      // is false so the Versions/Current aliases aren't thinned twice.
      for (final entity
          in frameworksDir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (await _thinMachO(entity.path, sliceArch, failLoud: false)) {
          thinnedCount++;
        }
      }
      print("Thinned $thinnedCount framework Mach-O file(s) → $sliceArch");
    }
    // ─────────────────────────────────────────────────────────────────────────

    // Re-sign entire bundle so all frameworks share the same ad-hoc identity.
    // Without this, CocoaPods/SPM frameworks may have mismatched Team IDs
    // and macOS refuses to load them at runtime.
    await Build.exec(
      name: "ad-hoc codesign",
      ["codesign", "-s", "-", "--deep", "--force", appPath],
    );

    final distDir = Directory(Build.distPath);
    if (!distDir.existsSync()) {
      distDir.createSync(recursive: true);
    }

    // Stage a folder holding just the .app. The create-dmg branch adds the
    // Applications drop-link itself (--app-drop-link); only the hdiutil
    // fallback needs a manual symlink, so it's created there.
    final stagingPath = join(current, "build", "macos", "dmg-staging");
    final stagingDir = Directory(stagingPath);
    if (stagingDir.existsSync()) {
      stagingDir.deleteSync(recursive: true);
    }
    stagingDir.createSync(recursive: true);

    await Build.exec(
      name: "copy app to staging",
      ["cp", "-R", appPath, stagingPath],
    );

    final targetDmgName = "$appName-${arch.name}.dmg";
    final targetDmgPath = join(Build.distPath, targetDmgName);

    // Prefer the Homebrew `create-dmg` formula
    // (github.com/create-dmg/create-dmg) when present: it produces a styled
    // installer window with our branded background, positioned icons and a
    // drag-to-Applications arrow. CI installs it on the macOS runners; local
    // builds that lack it fall back to a plain hdiutil image so the macos
    // target keeps working without brew.
    final createDmg = await Process.run("which", ["create-dmg"]);
    if (createDmg.exitCode == 0) {
      print("Creating styled DMG with create-dmg...");

      final targetDmgFile = File(targetDmgPath);
      if (targetDmgFile.existsSync()) {
        // create-dmg refuses to overwrite an existing image.
        targetDmgFile.deleteSync();
      }

      final process = await Process.start(
        "create-dmg",
        [
          "--volname", appName,
          "--volicon",
          join(appPath, "Contents", "Resources", "AppIcon.icns"),
          "--background", join("assets", "dmg", "background.png"),
          "--window-pos", "200", "120",
          "--window-size", "660", "400",
          "--icon-size", "128",
          "--text-size", "13",
          "--icon", "$appName.app", "165", "200",
          "--app-drop-link", "495", "200",
          "--hide-extension", "$appName.app",
          "--no-internet-enable",
          targetDmgPath,
          stagingPath,
        ],
        runInShell: true,
      );
      process.stdout.listen((data) => print(utf8.decode(data)));
      process.stderr.listen((data) => print(utf8.decode(data)));
      final exitCode = await process.exitCode;

      // create-dmg can exit non-zero when no code-signing identity is
      // available (it still writes a valid image), so the real success
      // signal is the presence of the output file, not the exit code.
      if (!targetDmgFile.existsSync()) {
        throw "create-dmg error (exit $exitCode): $targetDmgPath not produced";
      }
      if (exitCode != 0) {
        print("create-dmg exited $exitCode but DMG was written; continuing.");
      }
    } else {
      print("create-dmg not found; falling back to hdiutil...");

      // Plain image: add the Applications symlink manually for drag-to-install.
      await Build.exec(
        name: "create Applications symlink",
        ["ln", "-s", "/Applications", join(stagingPath, "Applications")],
      );

      await Build.exec(
        name: "create-dmg",
        [
          "hdiutil",
          "create",
          "-volname",
          appName,
          "-srcfolder",
          stagingPath,
          "-ov",
          "-format",
          "UDZO",
          targetDmgPath,
        ],
      );
    }

    stagingDir.deleteSync(recursive: true);
    print("✅ DMG created: $targetDmgPath");
  }

  _buildDistributor({
    required Target target,
    required String targets,
    String args = '',
    required String env,
  }) async {
    await Build.getDistributor();
    // Run the just-activated package through `dart pub global run` instead of
    // a bare `flutter_distributor` executable: activation only shims binaries
    // into ~/.pub-cache/bin, which is NOT guaranteed to be on PATH (pub itself
    // warns about it). A bare invocation reproduces as `command not found` on
    // any clean machine/CI runner — the build must not depend on shell rc
    // files having exported that directory.
    await Build.exec(
      name: name,
      Build.getExecutable(
        "dart pub global run flutter_distributor:main package --skip-clean --platform ${target.name} --targets $targets --flutter-build-args=verbose$args --build-dart-define=APP_ENV=$env",
      ),
    );
  }

  Future<String?> get systemArch async {
    if (Platform.isWindows) {
      return Platform.environment["PROCESSOR_ARCHITECTURE"];
    } else if (Platform.isLinux || Platform.isMacOS) {
      final result = await Process.run('uname', ['-m']);
      return result.stdout.toString().trim();
    }
    return null;
  }

  @override
  Future<void> run() async {
    final mode = target == Target.android ? Mode.lib : Mode.core;
    final String out = argResults?["out"] ?? (target.same ? "app" : "core");
    final archName = argResults?["arch"];
    final env = argResults?["env"] ?? "pre";
    final currentArches =
        arches.where((element) => element.name == archName).toList();
    final arch = currentArches.isEmpty ? null : currentArches.first;

    if (arch == null && target != Target.android) {
      throw "Invalid arch parameter";
    }

    final corePaths = await Build.buildCore(
      target: target,
      arch: arch,
      mode: mode,
    );

    if (out != "app") {
      return;
    }

    final coreVersion = await Build.extractCoreVersion();

    switch (target) {
      case Target.windows:
        final token = target != Target.android
            ? await Build.calcSha256(corePaths.first)
            : null;
        await Build.buildHelper(target, token!, arch: arch);
        await _buildDistributor(
          target: target,
          targets: "exe,zip",
          args:
              " --description $archName --build-dart-define=CORE_SHA256=$token --build-dart-define=CORE_VERSION=$coreVersion",
          env: env,
        );
        return;
      case Target.linux:
        final targetMap = {
          Arch.arm64: "linux-arm64",
          Arch.amd64: "linux-x64",
        };
        final targets = [
          "deb",
          if (arch == Arch.amd64) "appimage",
          if (arch == Arch.amd64) "rpm",
        ].join(",");
        final defaultTarget = targetMap[arch];
        await _getLinuxDependencies(arch!);
        await _buildDistributor(
          target: target,
          targets: targets,
          args:
              " --description $archName --build-target-platform $defaultTarget --build-dart-define=CORE_VERSION=$coreVersion",
          env: env,
        );
        return;
      case Target.android:
        final targetMap = {
          Arch.arm: "android-arm",
          Arch.arm64: "android-arm64",
          Arch.amd64: "android-x64",
        };
        final allTargets = targetMap.values.join(",");
        final defaultTarget = arch == null ? allTargets : targetMap[arch];

        await _buildDistributor(
          target: target,
          targets: "apk",
          args:
              ",split-per-abi --build-target-platform $defaultTarget --build-dart-define=CORE_VERSION=$coreVersion",
          env: env,
        );

        // When building every ABI (release CI, no --arch), ALSO emit a single
        // universal APK (all ABIs in one file). The per-ABI split APKs above
        // stay for the per-arch / Play paths; this universal is what the site's
        // "Android (universal)" download and the update.json `android-universal`
        // slot point at, so a device of any ABI can install it. Plain
        // `flutter build apk` (no split) defaults to all ABIs and reuses the
        // same gradle signing + dart-defines as the split build above.
        if (arch == null) {
          await Build.exec(
            name: "flutter build apk (universal)",
            [
              "flutter",
              "build",
              "apk",
              "--release",
              "--dart-define=APP_ENV=$env",
              "--dart-define=CORE_VERSION=$coreVersion",
            ],
          );
          Build.copyFile(
            join(current, "build", "app", "outputs", "flutter-apk",
                "app-release.apk"),
            join(Build.distPath, "${Build.appName}-universal.apk"),
          );
        }

        return;
      case Target.macos:
        await _buildMacosApp(
          arch: arch!,
          env: env,
          coreVersion: coreVersion,
        );
        return;
    }
  }
}

main(args) async {
  final runner = CommandRunner("setup", "build Application");
  runner.addCommand(BuildCommand(target: Target.android));
  runner.addCommand(BuildCommand(target: Target.linux));
  runner.addCommand(BuildCommand(target: Target.windows));
  runner.addCommand(BuildCommand(target: Target.macos));
  runner.run(args);
}
