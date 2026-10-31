// Провайдеры доски (canon/dropweb/app.js, коммит df156ea1, строки 66-73) для сверки цветов.
//
// Индекс в списке равен индексу в `PROVIDERS` доски: ключи `p<N>` в `test/ios27/ref/colors.json`
// называют именно его. Правка строки здесь без правки доски ломает сверку G2 намеренно.

/// Провайдер доски: имя и строка заголовка `dropweb-theme`.
class BoardProvider {
  const BoardProvider(this.name, this.theme, this.line);

  final String name;

  /// `<filter>,<accent>,<orb1>,<orb2>,<blur>`.
  final String theme;

  /// Строка в app.js, откуда взята запись.
  final int line;
}

const List<BoardProvider> kBoardProviders = [
  // Настоящий заголовок DROPWEB (cfgpull.com, 26.10), остальные на доске придуманы.
  BoardProvider('DROPWEB', 'fidelity,#29FF76,#000000,#2BFF7A,4', 67),
  BoardProvider('Голубой', 'fidelity,#38BDF8,#6366F1,#22D3EE,3', 68),
  BoardProvider('Сиреневый', 'fidelity,#A78BFA,#EC4899,#6366F1,4', 69),
  BoardProvider('Красный', 'fidelity,#EF4444,#F59E0B,#BE185D,3', 70),
  BoardProvider('Янтарный', 'fidelity,#F59E0B,#EF4444,#FACC15,4', 71),
  BoardProvider('Серый', 'fidelity,#64748B,#0EA5E9,#94A3B8,2', 72),
];
