import 'dart:async';
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/controller.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// App self-update concern carved out of [AppController].
///
/// [AppController] keeps thin delegating methods with the same signatures, so
/// every existing call site (`globalState.appController.autoCheckUpdate()` /
/// `checkUpdateResultHandle(...)`) stays untouched. The pure decision helpers
/// `shouldRunAutoUpdateCheck` / `shouldHandleUpdateResult` deliberately remain
/// top-level in `controller.dart` (their tests import them from there); this
/// service calls into them.
///
/// No [BuildContext] is stored here — the moved code reaches UI exclusively via
/// `globalState` dialog helpers and `globalState.navigatorKey`.
class AppUpdateService {
  AppUpdateService(this._ref);

  final WidgetRef _ref;

  Future<void> autoCheckUpdate() async {
    if (!shouldRunAutoUpdateCheck(
      isAndroid: Platform.isAndroid,
      isPlayBuild: kIsPlayBuild,
      autoCheckUpdate: _ref.read(appSettingProvider).autoCheckUpdate,
    )) {
      return;
    }
    final res = await request.checkForUpdate();
    checkUpdateResultHandle(data: res);
  }

  /// Resolves a safe, release-specific URL from a GitHub release payload.
  /// Prefers the release's own `html_url`, falls back to a tagged URL,
  /// and finally to the generic `releases/latest` page.
  String _resolveReleaseUrl(Map<String, dynamic> data) {
    final htmlUrl = data['html_url'];
    if (htmlUrl is String && htmlUrl.isNotEmpty) {
      final parsed = Uri.tryParse(htmlUrl);
      if (parsed != null && parsed.hasScheme) {
        return htmlUrl;
      }
    }
    final tag = data['tag_name'];
    if (tag is String && tag.isNotEmpty) {
      return "https://github.com/$repository/releases/tag/$tag";
    }
    return "https://github.com/$repository/releases/latest";
  }

  Future<void> checkUpdateResultHandle({
    Map<String, dynamic>? data,
    bool handleError = false,
  }) async {
    if (!shouldHandleUpdateResult(
      isPre: globalState.isPre,
      handleError: handleError,
    )) {
      return;
    }
    if (data != null) {
      final tagName = data['tag_name'];
      final body = data['body'];
      final submits = utils.parseReleaseBody(body);
      final textTheme = globalState.navigatorKey.currentContext?.textTheme;
      if (textTheme == null) {
        return;
      }
      final res = await globalState.showMessage(
        title: appLocalizations.discoverNewVersion,
        message: TextSpan(
          text: "$tagName \n",
          style: textTheme.headlineSmall,
          children: [
            TextSpan(
              text: "\n",
              style: textTheme.bodyMedium,
            ),
            for (final submit in submits)
              TextSpan(
                text: "- $submit \n",
                style: textTheme.bodyMedium,
              ),
          ],
        ),
        confirmText: appLocalizations.goDownload,
      );
      if (res != true) {
        return;
      }
      final releaseUrl = _resolveReleaseUrl(data);
      unawaited(launchUrl(Uri.parse(releaseUrl)));
    } else if (handleError) {
      globalState.showMessage(
        title: appLocalizations.checkUpdate,
        message: TextSpan(
          text: appLocalizations.checkUpdateError,
        ),
      );
    }
  }
}
