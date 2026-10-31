// Генератор таблицы названий стран для карточек главной обеих платформ (Android M3E и iOS).
//
// Запуск из корня репозитория:  swift tool/canon/gen_country_names.swift
// Пишет lib/common/country_names.g.dart.
//
// Зачем таблица, а не пакет: названия стран нужны одной строке карточки, а новая зависимость
// (R2) не оправдана. Источник — системные данные CLDR через Foundation, поэтому названия те же,
// что показывает сам iPhone, а таблица одна на обе платформы. Вывод детерминирован: коды и локали
// отсортированы, времени и путей в файле нет, повторный запуск даёт тот же shasum.

import Foundation

// Языки приложения (arb/intl_*.arb): ключ таблицы и идентификатор локали Foundation.
let locales: [(key: String, id: String)] = [
    ("en", "en"),
    ("ja", "ja"),
    ("ru", "ru"),
    ("zh_CN", "zh_CN"),
]

// Поправки поверх CLDR. CLDR даёт официальные названия («Соединенные Штаты Америки», «Республика
// Корея»), а в VPN-приложениях и у провайдеров пишут коротко и разговорно («США», «Южная Корея»).
// Решение владельца 30.10: на карточке короткие названия. Ключ — локаль таблицы, затем код региона;
// правятся только записи, которых CLDR не даёт в нужном виде, остальное остаётся как есть.
let overrides: [String: [String: String]] = [
    "ru": [
        "US": "США", "KR": "Южная Корея", "KP": "Северная Корея", "CN": "Китай",
        "ZA": "ЮАР", "CF": "ЦАР", "MM": "Мьянма", "CD": "ДР Конго", "CG": "Конго",
        "PS": "Палестина", "DO": "Доминикана", "EU": "Евросоюз", "UN": "ООН",
        "UM": "Внешние о-ва США", "VG": "Британские Виргинские о-ва",
        "VI": "Американские Виргинские о-ва",
    ],
    "en": [
        "CN": "China", "MM": "Myanmar", "CD": "DR Congo", "CG": "Congo",
        "PS": "Palestine", "AE": "UAE", "GS": "South Georgia",
    ],
    "ja": [
        "US": "アメリカ", "CN": "中国", "MM": "ミャンマー", "CD": "コンゴ民主共和国",
        "CG": "コンゴ共和国", "PS": "パレスチナ", "VA": "バチカン",
    ],
    "zh_CN": [
        "CN": "中国", "AE": "阿联酋", "PS": "巴勒斯坦", "BA": "波黑", "VA": "梵蒂冈",
    ],
]

// Общий проход для ru/en/ja: уточнение в скобках («Cocos (Keeling) Islands») и хвост « - …»
// («Конго - Киншаса») на карточку не нужны — в строке одна страна, а пояснение съедает ширину. Применяется только к тем
// названиям, что не заданы в `overrides`.
func shortened(_ name: String, key: String) -> String {
    guard key != "zh_CN" else { return name }
    let cut = name
        .replacingOccurrences(of: "\\s*[\\(（][^\\)）]*[\\)）]", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\s+-\\s+.*$", with: "", options: .regularExpression)
    return cut.isEmpty ? name : cut
}

// Только двухбуквенные коды ISO 3166-1 alpha-2: ровно их отдаёт определение страны выхода.
let codes = Locale.Region.isoRegions
    .map { $0.identifier }
    .filter { $0.count == 2 && $0.allSatisfy { $0.isASCII && $0.isLetter } }
    .sorted()

func quote(_ s: String) -> String {
    "'" + s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "'", with: "\\'")
        .replacingOccurrences(of: "$", with: "\\$") + "'"
}

var out = """
// СГЕНЕРИРОВАНО tool/canon/gen_country_names.swift. Не править руками.
//
// Названия стран по ISO 3166-1 alpha-2 для локалей приложения (CLDR через Foundation, короткие формы).

/// Название страны по языку, затем по коду региона (заглавные буквы).
const Map<String, Map<String, String>> kCountryNames = {

"""
for (key, id) in locales {
    let locale = Locale(identifier: id)
    out += "  \(quote(key)): {\n"
    for code in codes {
        guard let cldr = locale.localizedString(forRegionCode: code), !cldr.isEmpty else { continue }
        let name = overrides[key]?[code] ?? shortened(cldr, key: key)
        out += "    \(quote(code)): \(quote(name)),\n"
    }
    out += "  },\n"
}
out += "};\n"

let path = "lib/common/country_names.g.dart"
try out.write(toFile: path, atomically: true, encoding: .utf8)
print("\(codes.count) кодов, \(locales.count) локалей → \(path)")
