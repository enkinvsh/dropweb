import 'dart:io';

/// Loads the bundled bytes for a geo asset (e.g. `GeoIP.dat`). In production
/// this reads from `rootBundle`; tests inject an in-memory loader.
typedef GeoByteLoader = Future<List<int>> Function(String assetName);

/// Writes [bytes] to the staging temp [tmp]. Overridable so tests can simulate
/// a partial/failed write; production flushes to disk.
typedef GeoTempWriter = Future<void> Function(File tmp, List<int> bytes);

/// Atomic, self-repairing installer for a bundled geo seed file.
///
/// The bundled GeoIP.dat / GeoSite.dat ship in the APK as a BOOTSTRAP SEED so
/// the app can start offline. The naive "copy if the destination doesn't exist"
/// approach has two failure modes this class removes:
///   1. It never repairs an existing-but-poisoned file (zero-length after an
///      interrupted write, truncated, or the wrong length).
///   2. It writes the ~24 MB seed directly to the final path, so a power/process
///      loss mid-write permanently poisons the destination.
///
/// The caller supplies the expected byte length as metadata
/// (`geoAssetExpectedLengths` in production), so [ensureInstalled] validates a
/// GOOD destination with a cheap stat and returns WITHOUT ever loading the
/// ~24 MB asset. Only when a repair is needed are the bytes loaded, re-checked
/// against the expected length, staged in a same-directory temp file, flushed,
/// length-validated, then atomically renamed over the destination. A crash
/// before the rename leaves the prior good destination intact; a stale temp
/// from a prior crash is replaced before writing.
class GeoAssetInstaller {
  GeoAssetInstaller({
    required this.loadAsset,
    GeoTempWriter? writeTemp,
  }) : _writeTemp = writeTemp ?? _defaultWriteTemp;

  final GeoByteLoader loadAsset;
  final GeoTempWriter _writeTemp;

  static Future<void> _defaultWriteTemp(File tmp, List<int> bytes) =>
      tmp.writeAsBytes(bytes, flush: true);

  /// Ensures [destPath] holds the bundled seed for [assetName], whose canonical
  /// size is [expectedLength] bytes.
  ///
  /// Fast path: if the destination already exists and its length matches
  /// [expectedLength], returns `false` WITHOUT loading the asset — a good file
  /// costs one stat, never a ~24 MB bundle read, and is left byte-for-byte
  /// untouched (mtime preserved; a repeated init never re-copies).
  ///
  /// Repair path (missing/zero/truncated/wrong-length): loads the asset,
  /// re-checks the loaded length against [expectedLength] (guards against
  /// asset/metadata drift), stages the bytes in a same-dir temp, flushes,
  /// length-validates the temp, then atomically renames it over the
  /// destination. Returns `true`.
  ///
  /// Throws [ArgumentError] when [expectedLength] <= 0 — an empty/unknown seed
  /// must NEVER overwrite a (possibly good) destination. Throws [StateError] on
  /// asset/metadata drift, and [Exception] when the staged temp fails length
  /// validation. In every throwing case the destination is left untouched, so a
  /// good prior file always survives a failed repair.
  Future<bool> ensureInstalled(
    String assetName,
    String destPath, {
    required int expectedLength,
  }) async {
    if (expectedLength <= 0) {
      throw ArgumentError.value(
        expectedLength,
        'expectedLength',
        'must be > 0 — refusing to (over)write a geo seed with an empty asset',
      );
    }

    final dest = File(destPath);
    // Stat FIRST: a good file is validated by length alone, so the ~24 MB asset
    // is never loaded off the hot path.
    if (dest.existsSync() && await dest.length() == expectedLength) {
      return false;
    }

    // Repair needed — load the bundled bytes now (and only now).
    final expected = await loadAsset(assetName);
    if (expected.length != expectedLength) {
      // Asset/metadata drift: the bundled asset changed without updating
      // geoAssetExpectedLengths. Abort rather than publish an unexpected body.
      throw StateError(
        'Bundled asset $assetName length ${expected.length} != declared '
        '$expectedLength — update geoAssetExpectedLengths',
      );
    }

    final tmp = File('$destPath.tmp');
    // Replace any stale temp left by a prior interrupted install so we never
    // append to or reuse partial bytes.
    if (tmp.existsSync()) {
      await tmp.delete();
    }
    await tmp.parent.create(recursive: true);
    await _writeTemp(tmp, expected);

    // Validate the staged bytes BEFORE they can replace a (possibly good)
    // destination. A short write here must abort without touching the dest.
    final tmpLen = await tmp.length();
    if (tmpLen != expectedLength) {
      try {
        await tmp.delete();
      } catch (_) {}
      throw Exception(
        'Geo temp validation failed for $assetName: $tmpLen != $expectedLength',
      );
    }

    await _atomicReplace(tmp, destPath);
    return true;
  }

  /// Atomically publishes the validated temp over the destination. On POSIX
  /// (Android/macOS/Linux — the primary targets) `rename` replaces an existing
  /// file atomically within the directory. On the rare filesystem where rename
  /// cannot overwrite, fall back to delete-then-rename — safe here because the
  /// temp is already length-validated, so a validated replacement exists before
  /// the destination is removed.
  Future<void> _atomicReplace(File tmp, String destPath) async {
    try {
      await tmp.rename(destPath);
    } on FileSystemException {
      final dest = File(destPath);
      if (dest.existsSync()) {
        await dest.delete();
      }
      await tmp.rename(destPath);
    }
  }
}
