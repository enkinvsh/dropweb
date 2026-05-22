import 'package:dropweb/common/file_logger.dart';
import 'package:dropweb/common/log_redaction.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/cupertino.dart';

class CommonPrint {

  factory CommonPrint() {
    _instance ??= CommonPrint._internal();
    return _instance!;
  }

  CommonPrint._internal();
  static CommonPrint? _instance;

  void log(String? text) {
    // SECURITY: redact URL credentials/query/fragment centrally so neither
    // console (`debugPrint`), the file log, nor the in-app log buffer ever
    // emit subscription tokens or deep-link payloads in clear text.
    final payload = redactUrls("[dropweb] $text");
    debugPrint(payload);

    // Write to file log
    fileLogger.log(payload);

    if (!globalState.isInit) {
      return;
    }
    globalState.appController.addLog(
      Log.app(payload),
    );
  }
}

final commonPrint = CommonPrint();
