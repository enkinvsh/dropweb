import '../symbols.g.dart';

/// Значок уведомления: `TOAST_IC` в android.js.
///
/// Вынесен из `m3e_toast.dart`, чтобы старый код (`state.dart`, `context.dart`) мог
/// указать тип сообщения, не подтягивая виджеты M3E.
enum M3eToastKind {
  /// Успех: зелёная отметка (`is-ok`, цвет `home.ok`).
  check(M3eSymbol.checkCircle),

  /// Ошибка: красный восклицательный знак (`is-bad`, роль error).
  alert(M3eSymbol.error),

  /// Открывается другое приложение или браузер.
  out(M3eSymbol.openInNew),

  /// Откроется камера.
  camera(M3eSymbol.photoCamera);

  const M3eToastKind(this.symbol);

  final M3eSymbol symbol;
}
