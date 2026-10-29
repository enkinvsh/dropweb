import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/m3e_theme_source.dart';
import 'm3e_widget_payload.dart';

/// Куда уходит готовый JSON стиля виджета. Вынесено в провайдер, чтобы тест
/// подменял канал и проверял отправки.
typedef M3eWidgetSink = Future<void> Function(String json);

/// Отправка в нативную часть. `app` равен null вне Android, а на устройстве без
/// нативного плагина (тесты, хот-рестарт без пересборки) ошибка канала не должна
/// ронять экран: виджет остаётся на прошлом стиле.
final m3eWidgetSinkProvider = Provider<M3eWidgetSink>((ref) => _sendToNative);

Future<void> _sendToNative(String json) async {
  try {
    await app?.updateWidgetStyle(json);
  } on MissingPluginException {
    // Нативного метода нет: нечего обновлять.
  } on PlatformException {
    // Нативная сторона отказала: следующий пуш попробует снова.
  }
}

/// Держит стиль виджета рабочего стола в актуальном состоянии: шлёт JSON при старте
/// и при смене источника темы, имени сервиса или языка. Ничего не рисует.
class M3eWidgetStyleSync extends ConsumerStatefulWidget {
  const M3eWidgetStyleSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<M3eWidgetStyleSync> createState() => _M3eWidgetStyleSyncState();
}

class _M3eWidgetStyleSyncState extends ConsumerState<M3eWidgetStyleSync> {
  /// Последняя отправленная строка: повторные перестроения не шлют одно и то же.
  String? _last;

  @override
  void initState() {
    super.initState();
    ref
      ..listenManual(m3eThemeSourceProvider, (_, __) => _push())
      ..listenManual(
        currentProfileProvider.select((p) => p?.serviceName),
        (_, __) => _push(),
      );
  }

  /// Смена языка приходит сюда: `AppLocalizations.of` подписывает на `Localizations`.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _push();
  }

  void _push() {
    if (!mounted) return;
    final json = m3eWidgetPayloadJson(
      source: ref.read(m3eThemeSourceProvider),
      serviceName: ref.read(currentProfileProvider)?.serviceName ?? '',
      l10n: AppLocalizations.of(context),
    );
    if (json == _last) return;
    _last = json;
    ref.read(m3eWidgetSinkProvider)(json);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
