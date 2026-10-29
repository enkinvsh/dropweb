// Порт из MCU TS bd811e4 hct/hct.ts: Hct.isBlue/isYellow/isCyan (Apache-2.0, см. LICENSE).
// В Dart-пакете material_color_utilities 0.13.0 этих проверок нет.

bool hueIsBlue(double hue) => hue >= 250 && hue < 270;

bool hueIsYellow(double hue) => hue >= 105 && hue < 125;

bool hueIsCyan(double hue) => hue >= 170 && hue < 207;
