typedef ImportProfileStep<ProfileT> = Future<void> Function(ProfileT profile);
typedef ImportFailureReporter = Future<void> Function(
  Object error,
  StackTrace stackTrace,
);

final class UiNotReadyException implements Exception {
  const UiNotReadyException();

  @override
  String toString() => 'ui-not-ready';
}

final class ProfileImportTransaction<ProfileT> {
  const ProfileImportTransaction({
    required this.ensureUiReady,
    required this.ensureCoreReady,
    required this.downloadAndValidate,
    required this.commitProfile,
    required this.applyHeaderSettings,
    required this.handleHwidHeaders,
    required this.applyProfile,
    required this.reportSuccess,
    required this.reportFailure,
    required this.log,
  });

  final Future<void> Function() ensureUiReady;
  final Future<bool> Function() ensureCoreReady;
  final Future<ProfileT?> Function() downloadAndValidate;
  final ImportProfileStep<ProfileT> commitProfile;
  final ImportProfileStep<ProfileT> applyHeaderSettings;
  final ImportProfileStep<ProfileT> handleHwidHeaders;
  final ImportProfileStep<ProfileT> applyProfile;
  final ImportProfileStep<ProfileT> reportSuccess;
  final ImportFailureReporter reportFailure;
  final void Function(String message) log;

  Future<void> run() async {
    try {
      await ensureUiReady();
      if (!await ensureCoreReady()) return;

      log('[import] validate');
      final profile = await downloadAndValidate();
      if (profile == null) return;

      await commitProfile(profile);
      await _runBestEffort(
        phase: 'header-settings',
        step: () => applyHeaderSettings(profile),
      );
      await _runBestEffort(
        phase: 'hwid',
        step: () => handleHwidHeaders(profile),
      );

      log('[import] profile-apply');
      await applyProfile(profile);
      await reportSuccess(profile);
    } catch (error, stackTrace) {
      await reportFailure(error, stackTrace);
    }
  }

  Future<void> _runBestEffort({
    required String phase,
    required Future<void> Function() step,
  }) async {
    try {
      await step();
    } catch (error, stackTrace) {
      log('[import] $phase failed: $error\n$stackTrace');
    }
  }
}
