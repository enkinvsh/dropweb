// Переключатель между прежней главной и новой iOS-главной.

import 'package:dropweb/enum/enum.dart';

/// Показывать ли новую iOS-главную.
///
/// Новый экран только для iPhone-раскладки: на iPad и в окнах (`laptop`, `desktop`) остаётся прежняя.
///
/// Это функция, а не условие в `home.dart`, потому что `HomePage` в тестах не поднимается: ему нужны
/// ядро, провайдеры и сервисы. Строка выбора Android-главной стоит прямо в `home.dart`, и проверить
/// её можно только на устройстве. Здесь решение чистое, и таблица истинности покрыта тестом.
bool useIos27HomeFor({required bool isIOS, required ViewMode viewMode}) =>
    isIOS && viewMode == ViewMode.mobile;
