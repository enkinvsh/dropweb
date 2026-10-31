import Flutter
import UIKit

/// Параметры стекла из Dart (`Ios27GlassParams.toMap`). Карта и обоснование выбора
/// материалов — `.omo/ios/glass-map.md`. Разбор терпимый: неизвестные и пустые поля
/// получают значения по умолчанию, а не роняют приложение.
struct DropwebGlassParams {
    enum Shape {
        case capsule
        case rect(radius: CGFloat)
    }

    /// Класс стекла доски: `glass`, `glass--md`, `glass--lg`, `glass--widget`, `glass--inactive`
    /// и `content` — матовый материал контента (`.hig-card-matte` доски карточек), не стекло.
    enum Variant: String {
        case small, md, lg, widget, inactive, content
    }

    /// Стандартные материалы iOS 13–25 (HIG: ultra-thin, thin, regular, thick).
    enum Material: String {
        case ultraThin, thin, regular, thick, chrome
    }

    var shape: Shape = .capsule
    var variant: Variant = .small
    var tint: UIColor?
    /// Плотность подложки тона на iOS 13–25 (UIBlurEffect цвета не принимает).
    var tintAlpha: CGFloat = 1
    var interactive = false
    var nested = false
    var enabled = true
    var material: Material?
    /// `nil` — следовать теме системы.
    var dark: Bool?
    /// Ползунок «Стекло» 0…100 (`--lg` доски, app.js:424). `nil` — «Как в системе»: ни системное
    /// стекло iOS 26+, ни таблица материалов iOS 13–25 не трогаются. Из Dart приходит `-1`.
    var level: Int?
    /// Стекло ушло под лист (`.home:has(~ .sheet) .joy .glass { --g-o: 0 }`, app.css:330). Материал
    /// и кромка убираются анимацией самого вида: Flutter не может сделать прозрачным предка
    /// `UIVisualEffectView`, не сломав его отрисовку (Apple: эффект с полупрозрачным предком
    /// рисуется неправильно, на экране вспышка плоских кругов).
    var away = false
    /// «Уменьшить движение»: уход и возврат идут 100 мс линейно, смена тона — мгновенно. Решает
    /// Dart (`MediaQuery.disableAnimations`), чтобы значки Flutter и материал гасли синхронно.
    var reduceMotion = false

    /// Стандартное положение ползунка доски (app.js:213, `GLASS_STD`): ниже — прозрачнее, выше — плотнее.
    static let levelStandard = 25

    /// Доля слоя размытия и блика (`--g-clear`, glass.css:99-105): ниже стандарта стекло
    /// «выцветает». Без уровня или на уровне ≥ стандарта равна 1.
    var glassClear: CGFloat {
        guard let level = level else { return 1 }
        return min(1, 0.35 + CGFloat(level) / 100 * 2.6)
    }

    /// Доля матовой подложки (`--g-frost`, glass.css:99-105): растёт от четверти шкалы к краю.
    var glassFrost: CGFloat {
        guard let level = level else { return 0 }
        return max(0, (CGFloat(level) / 100 - 0.25) / 0.75)
    }

    /// Шаг по лестнице материалов iOS 13–25 (ultraThin → thin → regular → thick). Пороги совпадают
    /// с подписями доски (`glassName`, app.js:425): < 17 «Прозрачнее», 17…33 «Стандартное»,
    /// 34…85 «Плотнее», > 85 «Тонированное»; самый край добавляет второй шаг.
    var materialStep: Int {
        guard let level = level else { return 0 }
        switch level {
        case ..<8: return -2
        case ..<17: return -1
        case ...33: return 0
        case ...85: return 1
        default: return 2
        }
    }

    /// Отличаются ли параметры тем, из чего строится итоговое состояние вида (`Surface`): класс,
    /// тон, уровень, тема, уход, интерактивность, материал. Форма и `reduceMotion` сюда не входят:
    /// форма меняет только радиус (слой зума присылает его каждый кадр), а `reduceMotion` нужен
    /// лишь при запуске перехода.
    func surfaceDiffers(from other: DropwebGlassParams) -> Bool {
        if variant != other.variant || nested != other.nested || dark != other.dark
            || away != other.away
        {
            return true
        }
        // Матовый материал контента не читает ни тон, ни уровень «Стекло», ни интерактивность,
        // ни явный материал: их смена не должна обрывать идущий уход под лист.
        if variant == .content {
            return false
        }
        return enabled != other.enabled || tint != other.tint || tintAlpha != other.tintAlpha
            || level != other.level || interactive != other.interactive
            || material != other.material
    }

    init() {}

    init(_ raw: Any?) {
        guard let map = raw as? [String: Any] else { return }
        if (map["shape"] as? String) == "rect" {
            shape = .rect(radius: CGFloat((map["radius"] as? NSNumber)?.doubleValue ?? 0))
        }
        if let name = map["variant"] as? String, let parsed = Variant(rawValue: name) {
            variant = parsed
        }
        if let argb = map["tint"] as? NSNumber {
            tint = Self.color(argb: argb.int64Value)
        }
        if let alpha = map["tintAlpha"] as? NSNumber {
            tintAlpha = CGFloat(alpha.doubleValue)
        }
        interactive = (map["interactive"] as? NSNumber)?.boolValue ?? false
        nested = (map["nested"] as? NSNumber)?.boolValue ?? false
        enabled = (map["enabled"] as? NSNumber)?.boolValue ?? true
        if let name = map["material"] as? String {
            material = Material(rawValue: name)
        }
        dark = (map["dark"] as? NSNumber)?.boolValue
        // Отрицательное и нечисловое значение — «как в системе»; сверху зажимается до 100.
        if let raw = map["level"] as? NSNumber, raw.intValue >= 0 {
            level = min(raw.intValue, 100)
        }
        away = (map["away"] as? NSNumber)?.boolValue ?? false
        reduceMotion = (map["reduceMotion"] as? NSNumber)?.boolValue ?? false
    }

    /// ARGB из Dart (`Color.toARGB32`) приходит как int64.
    static func color(argb: Int64) -> UIColor {
        let value = UInt32(truncatingIfNeeded: argb)
        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: CGFloat((value >> 24) & 0xFF) / 255)
    }
}

/// Сам материал: `UIVisualEffectView` на весь вид. Подкласс нужен ради `layoutSubviews`:
/// радиус капсулы на iOS 13–25 зависит от текущего размера.
final class DropwebGlassEffectView: UIVisualEffectView {
    private var params = DropwebGlassParams()
    /// `true`, когда форму держит `cornerConfiguration` (стекло iOS 26+): тогда вид не
    /// обрезается, иначе срезались бы тень и блик самого стекла.
    private var shapeByConfiguration = false
    /// Было ли уже хоть одно применение: первое (создание вида) не анимируется.
    private var hasApplied = false
    /// Текущий переход тона или ухода; новый `apply` останавливает идущий на достигнутом месте.
    private var animator: UIViewPropertyAnimator?
    /// Что сейчас задано в `effect`. Эффект пересоздаётся только при смене описания: новый
    /// экземпляр с тем же стилем заново собирает материал, а при перетаскивании ползунка «Стекло»
    /// это мигало бы на каждом шаге.
    private var effectSpec: EffectSpec = .none
    /// `false`, пока к `effectSpec` идёт переход или он оборван на полпути: тогда `effect` надо
    /// выставить заново, даже если описание совпало.
    private var effectSettled = true

    /// Подложка над материалом (тон на iOS 13–25, затемнение карточки, матовая подложка уровня
    /// «Стекло»). Отдельный вид внутри `contentView`, а не его `backgroundColor`: на iOS 26 форму
    /// стекла держит `cornerConfiguration` вида-эффекта (`clipsToBounds = false`, радиус слоя 0),
    /// и `contentView` его не наследует. Заливка прямо в `contentView` рисовалась прямоугольником
    /// вокруг круглых кнопок и карточки (баг владельца: тёмные квадраты вокруг кнопок на странице
    /// «Оформление» при ползунке «Стекло» выше стандарта). Свой радиус слоя этого вида обрезает
    /// заливку по той же форме, а `backgroundColor` вида анимируется блоком `UIView` как у любого другого.
    private let fillView = UIView()

    private static let hairlineKey = "dropweb.hairline"
    /// `--ease-out` доски (`Cubic(0.23, 1, 0.32, 1)`, tokens.g.dart): та же кривая у Dart-половины
    /// ухода, поэтому значки и материал гаснут вровень.
    private static let easeOut1 = CGPoint(x: 0.23, y: 1)
    private static let easeOut2 = CGPoint(x: 0.32, y: 1)

    /// Описание материала без самого экземпляра: экземпляры сравнивать нельзя, а описания можно.
    /// Стили не названы типами iOS 26, чтобы перечисление жило на iOS 13.
    private enum EffectSpec: Equatable {
        case none
        /// `UIGlassEffect` (iOS 26+): прозрачный или обычный стиль, тон уже с плотностью по теме.
        case glass(clear: Bool, interactive: Bool, tint: UIColor?)
        /// `UIBlurEffect` (iOS 13–25).
        case blur(UIBlurEffect.Style)

        func make() -> UIVisualEffect? {
            switch self {
            case .none:
                return nil
            case .blur(let style):
                return UIBlurEffect(style: style)
            case .glass(let clear, let interactive, let tint):
                guard #available(iOS 26.0, *) else { return nil }
                let glass = UIGlassEffect(style: clear ? .clear : .regular)
                glass.isInteractive = interactive
                glass.tintColor = tint
                return glass
            }
        }
    }

    /// Итоговое состояние вида для набора параметров: что показывать, когда все переходы кончились.
    private struct Surface {
        var effect: EffectSpec
        /// Подложка над материалом (тон на iOS 13–25, затемнение карточки и матовая подложка
        /// уровня «Стекло» на iOS 26+).
        var contentFill: UIColor?
        /// Плоская заливка без материала (недоступная кнопка, вложенное стекло).
        var flatFill: UIColor?
        var hairlineAlpha: CGFloat
        /// 0.5 там, где у вида есть кромка (iOS 13–25 и плоская заливка), иначе 0.
        var hairlineWidth: CGFloat
        /// Форму держит `cornerConfiguration` (стекло iOS 26+).
        var glassShape: Bool
        /// Вид совсем ушёл (`away`) и ничего не рисует: его прячут целиком, см. `settleLook`.
        var hidden: Bool
        /// Кромка светлая (белая), а не чёрная: так у матового материала контента. Цвет не зависит
        /// от `away`, чтобы при уходе менялась только прозрачность кромки, а не её оттенок.
        var hairlineLight = false
    }

    init(params: DropwebGlassParams) {
        super.init(effect: nil)
        // Вид лежит под виджетами Flutter и сам ничего не рисует, кроме материала.
        isOpaque = false
        fillView.isUserInteractionEnabled = false
        contentView.addSubview(fillView)
        apply(params)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fillView.frame = bounds
        applyFillShape()
        applyLegacyRadius()
    }

    func apply(_ next: DropwebGlassParams) {
        let before = params
        let first = !hasApplied
        // Анимируются только смена тона и уход под лист у уже показанного вида. Остальное
        // (создание, тема, уровень «Стекло») ставится сразу: ползунок ведёт значение под пальцем,
        // и плавность ему только мешала бы.
        let awayChanged = before.away != next.away
        let tintChanged = next.variant != .content
            && (before.tint != next.tint || before.enabled != next.enabled)
        let animated = !first && window != nil && (awayChanged || tintChanged)
        hasApplied = true
        params = next

        // Слой зума присылает радиус каждый кадр. Если поменялась только форма, материал,
        // подложки и идущий переход трогать нельзя: `stopMotion` обрывал бы уход на полпути,
        // а `setSurface` ставил бы его конечное состояние, и стекло пропадало бы за один кадр.
        if !first && !before.surfaceDiffers(from: next) {
            applyShape(glass: shapeByConfiguration)
            return
        }

        // Тема приложения может расходиться с системной (themeMode по умолчанию dark),
        // поэтому Dart всегда присылает `dark`.
        if let dark = next.dark {
            overrideUserInterfaceStyle = dark ? .dark : .light
        } else {
            overrideUserInterfaceStyle = .unspecified
        }

        let target = surface(for: next)
        // Спрятанный вид показывается ДО перехода, а не после него: возврат идёт с задержкой 0.15 с
        // и 0.30 с анимации (app.css:326-333), и если открыть вид позже, первые кадры
        // материала пропадут. Пока вид невидим (эффект `nil`, заливки в нулевой альфе), показ
        // ничего не рисует. Уход, наоборот, прячет вид только по окончании (`settleLook`).
        if !target.hidden {
            isHidden = false
            setNeedsLayout()
        }
        // Цвет кромки на полпути читается до `stopMotion`: он снимает анимацию слоя, и после этого
        // `presentation()` отдаёт уже конечное значение, а прерванный уход начинался бы со скачка.
        let rimFrom = layer.presentation()?.borderColor ?? layer.borderColor
        stopMotion()
        applyShape(glass: target.glassShape)
        layer.borderWidth = target.hairlineWidth

        // Тон на «Уменьшить движение» меняется сразу (glass.css:305); уход идёт 100 мс.
        guard animated, awayChanged || !next.reduceMotion else {
            setSurface(target)
            return
        }

        // Заливка идёт не от «прозрачного чёрного», а от того же цвета с нулевой альфой, иначе
        // середина перехода темнела бы.
        let content = Self.fillEnds(current: fillView.backgroundColor, target: target.contentFill)
        let flat = Self.fillEnds(current: backgroundColor, target: target.flatFill)
        fillView.backgroundColor = content.start
        backgroundColor = flat.start

        // Эффект с тем же описанием в блок не кладём: его модельное значение уже верное, а новый
        // экземпляр пересобрал бы материал посреди перехода заливок.
        let reuseEffect = effectSettled && effectSpec == target.effect
        if !reuseEffect {
            effectSpec = target.effect
            effectSettled = false
        }
        let motion = makeMotion(for: next, awayChanged: awayChanged)
        motion.animator.addAnimations { [weak self] in
            guard let self = self else { return }
            if !reuseEffect {
                self.effect = target.effect.make()
            }
            self.fillView.backgroundColor = content.end
            self.backgroundColor = flat.end
        }
        motion.animator.addCompletion { [weak self] position in
            guard position == .end, let self = self else { return }
            // К концу перехода модельное значение `effect` уже стоит: заново его не выставляем.
            self.effectSettled = true
            self.settleLook(target)
            self.animator = nil
        }
        animator = motion.animator
        if awayChanged {
            animateHairline(
                from: rimFrom, to: target.hairlineAlpha, light: target.hairlineLight,
                duration: motion.duration, delay: motion.delay, timing: motion.timing)
        } else {
            layer.borderColor = Self.hairlineColor(
                target.hairlineAlpha, light: target.hairlineLight)
        }
        motion.animator.startAnimation(afterDelay: motion.delay)
    }

    /// Параметры перехода: уход 0.25 с `ease-out`, возврат 0.30 с с задержкой 0.15 с
    /// (app.css:326-333), на «Уменьшить движение» 0.1 с линейно; смена тона — пружина smooth
    /// доски 0.5 с без отскока (`is-tint-in`/`is-tint-out`, glass.css:221-226).
    private func makeMotion(for p: DropwebGlassParams, awayChanged: Bool) -> (
        animator: UIViewPropertyAnimator, delay: TimeInterval, duration: TimeInterval,
        timing: CAMediaTimingFunction
    ) {
        let easeOut = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
        guard awayChanged else {
            let animator = UIViewPropertyAnimator(duration: 0.5, dampingRatio: 1)
            return (animator, 0, 0.5, easeOut)
        }
        if p.reduceMotion {
            let animator = UIViewPropertyAnimator(duration: 0.1, curve: .linear)
            return (animator, 0, 0.1, CAMediaTimingFunction(name: .linear))
        }
        let duration: TimeInterval = p.away ? 0.25 : 0.30
        let delay: TimeInterval = p.away ? 0 : 0.15
        let animator = UIViewPropertyAnimator(
            duration: duration, controlPoint1: Self.easeOut1, controlPoint2: Self.easeOut2)
        return (animator, delay, duration, easeOut)
    }

    /// Состояние вида для параметров. При уходе материал, подложки и кромка пропадают, а форма
    /// не меняется: иначе `cornerConfiguration` переключался бы вместе с уходом.
    private func surface(for p: DropwebGlassParams) -> Surface {
        // Материал контента не окрашивают: серый вторичный текст карточки на цветной подложке
        // снова стал бы нечитаемым (решение владельца 30.10).
        let tint = (p.enabled && p.variant != .content) ? p.tint : nil
        if p.variant == .content {
            // Одинаково на всех iOS, в том числе 26+: карточка контента это системный толстый
            // материал (HIG materials.md: контенту — материалы, жидкое стекло — функциональному
            // слою), а не `UIGlassEffect`. Ползунок «Стекло», тон и затемнение `widget` на неё не
            // действуют, подложек нет. Форму держит радиус слоя с обрезкой, как у размытия
            // iOS 13–25. Вложенность (`nested`) на неё не действует: «стекло на стекло» запрещено
            // для Liquid Glass, а матовый материал контента стеклом не является. Внешней тени нет: `clipsToBounds` срезал бы её вместе с углами, а без
            // неё толстый материал читается на фоне (тень `0 1 3` рисует только Dart-заглушка).
            return Surface(
                effect: p.away ? .none : .blur(Self.blurStyle(p)),
                contentFill: nil, flatFill: nil,
                hairlineAlpha: p.away ? 0 : hairlineAlpha(p),
                hairlineWidth: 0.5, glassShape: false, hidden: p.away,
                hairlineLight: true)
        }
        if p.variant == .inactive || p.nested {
            // «Стекло на стекло» запрещено (learn/02 §5), а blur поверх размытого листа
            // неразличим: вместо эффекта плоская заливка.
            return Surface(
                effect: .none, contentFill: nil,
                flatFill: p.away ? nil : flatFill(p, tint: tint),
                hairlineAlpha: p.away ? 0 : hairlineAlpha(p),
                hairlineWidth: 0.5, glassShape: false, hidden: p.away)
        }
        if #available(iOS 26.0, *) {
            if p.away {
                return Surface(
                    effect: .none, contentFill: nil, flatFill: nil,
                    hairlineAlpha: 0, hairlineWidth: 0, glassShape: true, hidden: true)
            }
            // Без уровня стекло системное: приложение ничего не навязывает. С уровнем плавной шкалы
            // у UIGlassEffect нет: у прозрачного края берём `.clear` (там, где доска гасит слой
            // размытия, `--g-clear` < 0.75), дальше `.regular` и растущая матовая подложка
            // (`--g-frost`).
            let clear = p.level != nil && p.glassClear < 0.75
            // Плотность тона по теме, как на доске (светлая 96 %, тёмная 50 %, glass.css:203-217):
            // непрозрачный акцент давал белому значку 1.3:1 и расходился с эталоном.
            let glass = EffectSpec.glass(
                clear: clear, interactive: p.interactive && p.enabled,
                tint: tint?.withAlphaComponent(p.tintAlpha))
            // Кромку и тень рисует система.
            return Surface(
                effect: glass, contentFill: glassFill(p, tint: tint), flatFill: nil,
                hairlineAlpha: 0, hairlineWidth: 0, glassShape: true, hidden: false)
        }
        return Surface(
            effect: p.away ? .none : .blur(Self.blurStyle(p)),
            contentFill: p.away ? nil : legacyFill(p, tint: tint), flatFill: nil,
            hairlineAlpha: p.away ? 0 : hairlineAlpha(p),
            hairlineWidth: 0.5, glassShape: false, hidden: p.away)
    }

    private func setSurface(_ s: Surface) {
        // Тот же материал не пересоздаём: смена только густоты меняет подложку, а не эффект.
        if !(effectSettled && effectSpec == s.effect) {
            effect = s.effect.make()
            effectSpec = s.effect
            effectSettled = true
        }
        settleLook(s)
    }

    /// Конечный вид: заливки, цвет кромки и видимость самого вида.
    ///
    /// Ушедшее под лист стекло (`away`) прячется через `isHidden`, а не остаётся живым видом с
    /// эффектом `nil`: пока лист открыт, пять стёкол главной плюс стекло листа и вложенная кнопка
    /// закрытия давали семь `UIVisualEffectView`, и все семь участвовали в композитинге каждого
    /// кадра зума (`.omo/ios/g6/lag/report.md`, причина 1; на устройстве не мерили). Скрытый вид
    /// выпадает из рендера целиком, вместе с поддеревом слоёв. Одного снятия эффекта мало: оно уже
    /// сделано уходом (`Surface.effect == .none`), а сам вид с его слоями остаётся в сцене.
    /// Скрытие не меняет `effectSpec` и `effectSettled`: материал и так снят, возврат выставит его
    /// заново обычным путём. Показ перед возвратом — в начале `apply`.
    private func settleLook(_ s: Surface) {
        fillView.backgroundColor = s.contentFill
        backgroundColor = s.flatFill ?? .clear
        layer.borderColor = Self.hairlineColor(s.hairlineAlpha, light: s.hairlineLight)
        isHidden = s.hidden
    }

    /// Останавливает идущий переход на достигнутом месте: следующий начнётся оттуда, без скачка.
    private func stopMotion() {
        if let running = animator, running.state == .active {
            running.stopAnimation(true)
            // Эффект оборван на полпути: следующему применению надо выставить его заново.
            effectSettled = false
        }
        animator = nil
        layer.removeAnimation(forKey: Self.hairlineKey)
    }

    /// Начало и конец перехода заливки. Появление идёт от того же цвета с нулевой альфой, угасание —
    /// к нулевой альфе текущего цвета; сам `nil` выставляет `setSurface` по окончании.
    private static func fillEnds(
        current: UIColor?, target: UIColor?
    ) -> (start: UIColor?, end: UIColor?) {
        switch (current, target) {
        case (nil, nil):
            return (nil, nil)
        case (let from?, nil):
            return (from, from.withAlphaComponent(0))
        case (nil, let to?):
            return (to.withAlphaComponent(0), to)
        case (let from?, let to?):
            let alpha = from.cgColor.alpha
            return alpha == 0 ? (to.withAlphaComponent(0), to) : (from, to)
        }
    }

    private static func hairlineColor(_ alpha: CGFloat, light: Bool = false) -> CGColor {
        (light ? UIColor.white : UIColor.black).withAlphaComponent(alpha).cgColor
    }

    /// Цвет кромки идёт отдельной анимацией слоя: UIKit цвет рамки внутри блока `UIView` не ведёт.
    private func animateHairline(
        from: CGColor?, to alpha: CGFloat, light: Bool, duration: TimeInterval,
        delay: TimeInterval, timing: CAMediaTimingFunction
    ) {
        let to = Self.hairlineColor(alpha, light: light)
        let animation = CABasicAnimation(keyPath: "borderColor")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.beginTime = CACurrentMediaTime() + delay
        animation.fillMode = .backwards
        animation.timingFunction = timing
        layer.add(animation, forKey: Self.hairlineKey)
        layer.borderColor = to
    }

    /// Цвет матовой подложки доски (`--g-frost-c`): светлая #F7F7F9, тёмная #232325; у стекла
    /// с тоном (`.glass--tint`) это сам тон.
    private func frostColor(_ p: DropwebGlassParams, tint: UIColor?) -> UIColor {
        if let tint = tint {
            return tint
        }
        let dark = p.dark ?? (traitCollection.userInterfaceStyle == .dark)
        return dark
            ? UIColor(red: 0x23 / 255, green: 0x23 / 255, blue: 0x25 / 255, alpha: 1)
            : UIColor(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF9 / 255, alpha: 1)
    }

    /// Подложка стекла iOS 26+: затемнение карточки, поверх него матовая подложка уровня «Стекло».
    /// Порядок слоёв как у `::before` доски (glass.css:113): `linear-gradient(frost) , var(--g-bg)`.
    private func glassFill(_ p: DropwebGlassParams, tint: UIColor?) -> UIColor? {
        Self.over(frostFill(p, tint: tint), widgetDim(p, tint: tint))
    }

    /// Затемнение под текстом карточки главной (`.glass--widget`, glass.css:154-161:
    /// `--g-bg: light-dark(#FFFFFF66, #00000047)`). Системное `.regular` не затемняет фон, а
    /// осветляет: замер владельца с устройства, фон (24,23,50) → карточка (43,42,74)
    /// (`.omo/ios/g6/diag-bg-power.md:184`), то есть `native ≈ 1.19 × фон + 14`. Вторичный текст
    /// карточки (`--glass-label-2`, #8A8A8A тёмной темы, tokens.css:71) на таком стекле даёт
    /// ≈ 2.4:1 против 4.4:1 на доске (расчёт: `.omo/ios/g6/glass3/contrast.py`).
    ///
    /// Светлая тема берёт значение доски как есть: белый 40 %, светлее стекло только читаемее для
    /// #727272. Тёмная берёт не 28 % доски, а 50 %: доска затемняет «голый» фон, а здесь затемнять
    /// надо уже осветлённое системой стекло. При 50 % оценка контраста подписи 4.4:1, как на
    /// доске; 28 % давали бы 3.4:1. Для тонированного стекла `--g-bg` заменён цветом тона
    /// (`.glass--tint`, glass.css:204), поэтому затемнения у него нет.
    ///
    /// Как и весь слой `::before` доски, затемнение гаснет вместе с `--g-clear` (glass.css:115):
    /// у прозрачного края ползунка стекло не должно темнеть сильнее, чем светлеет само.
    private func widgetDim(_ p: DropwebGlassParams, tint: UIColor?) -> UIColor? {
        guard p.variant == .widget, tint == nil else { return nil }
        let dark = p.dark ?? (traitCollection.userInterfaceStyle == .dark)
        let base = dark
            ? UIColor(white: 0, alpha: Self.widgetDimDark)
            : UIColor(white: 1, alpha: Self.widgetDimLight)
        return base.withAlphaComponent(base.cgColor.alpha * p.glassClear)
    }

    /// Плотность затемнения карточки: тёмная тема 0.50 (на доске 0.28, см. `widgetDim`), светлая
    /// 0.40 (`#FFFFFF66`, glass.css:161).
    private static let widgetDimDark: CGFloat = 0.5
    private static let widgetDimLight: CGFloat = 0x66 / 255

    /// Один цвет из двух слоёв: `top` поверх `bottom` обычным наложением (как CSS-слои `background`).
    private static func over(_ top: UIColor?, _ bottom: UIColor?) -> UIColor? {
        guard let top = top else { return bottom }
        guard let bottom = bottom else { return top }
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        guard top.getRed(&tr, green: &tg, blue: &tb, alpha: &ta),
            bottom.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        else { return top }
        let alpha = ta + ba * (1 - ta)
        guard alpha > 0 else { return nil }
        return UIColor(
            red: (tr * ta + br * ba * (1 - ta)) / alpha,
            green: (tg * ta + bg * ba * (1 - ta)) / alpha,
            blue: (tb * ta + bb * ba * (1 - ta)) / alpha,
            alpha: alpha)
    }

    /// Матовая подложка поверх стекла iOS 26+: только при заданном уровне выше стандарта
    /// (`color-mix(frost-c, frost × 90 %)`, glass.css:99-105). Системное стекло и уровень ≤ 25
    /// остаются без подложки.
    private func frostFill(_ p: DropwebGlassParams, tint: UIColor?) -> UIColor? {
        guard p.level != nil, p.glassFrost > 0 else { return nil }
        return frostColor(p, tint: tint).withAlphaComponent(p.glassFrost * 0.9)
    }

    /// Подложка поверх материала iOS 13–25: подложка тона (`UIBlurEffect` цвета не принимает), а при
    /// уровне выше стандарта ещё и матовая подложка; у тонированного стекла плотность тона только растёт.
    private func legacyFill(_ p: DropwebGlassParams, tint: UIColor?) -> UIColor? {
        let base = tint?.withAlphaComponent(p.tintAlpha)
        guard p.level != nil, p.glassFrost > 0 else { return base }
        let frostAlpha = p.glassFrost * 0.9
        if let tint = tint {
            return tint.withAlphaComponent(max(p.tintAlpha, frostAlpha))
        }
        return frostColor(p, tint: nil).withAlphaComponent(frostAlpha)
    }

    /// Плоская заливка вместо стекла: недоступная кнопка и вложенное стекло.
    private func flatFill(_ p: DropwebGlassParams, tint: UIColor?) -> UIColor {
        if let tint = tint {
            return tint.withAlphaComponent(p.tintAlpha)
        }
        let dark = p.dark ?? (traitCollection.userInterfaceStyle == .dark)
        if p.variant == .inactive {
            // `.glass--inactive`: светлая #00000005, тёмная #7676803D.
            return dark
                ? UIColor(red: 0x76 / 255, green: 0x76 / 255, blue: 0x80 / 255, alpha: 0x3D / 255)
                : UIColor(white: 0, alpha: 5.0 / 255)
        }
        // Вложенное стекло: светлая белый 40 %, тёмная #9999992B (база `.glass` доски).
        return dark
            ? UIColor(white: 0x99 / 255, alpha: 0x2B / 255)
            : UIColor(white: 1, alpha: 0x66 / 255)
    }

    /// На iOS 13–25 у материала нет кромки, а на доске она есть (`--g-shadow-out`): прозрачность
    /// чёрной полосы 0.5 по классу и теме.
    private func hairlineAlpha(_ p: DropwebGlassParams) -> CGFloat {
        let dark = p.dark ?? (traitCollection.userInterfaceStyle == .dark)
        switch p.variant {
        case .inactive: return dark ? 0x1A / 255 : 0x14 / 255
        case .md, .lg, .widget: return dark ? 0x80 / 255 : 0x24 / 255
        case .small: return dark ? 0x40 / 255 : 0x24 / 255
        // Белая кромка матового материала: `inset 0 0 0 .5px rgba(255,255,255,.65 / .09)`
        // (`.hig-card-matte`, canon/.omo/hig-cards/index.html).
        case .content: return dark ? 0x17 / 255 : 0xA6 / 255
        }
    }

    private func applyShape(glass: Bool) {
        shapeByConfiguration = glass
        if glass {
            if #available(iOS 26.0, *) {
                layer.cornerRadius = 0
                clipsToBounds = false
                switch params.shape {
                case .capsule:
                    cornerConfiguration = .capsule()
                case .rect(let radius):
                    cornerConfiguration = .corners(radius: .fixed(Double(radius)))
                }
            }
        } else {
            clipsToBounds = true
            layer.cornerCurve = .continuous
            applyLegacyRadius()
        }
        applyFillShape()
        setNeedsLayout()
    }

    /// Форма заливки совпадает с формой стекла: капсула — круглые концы, прямоугольник — радиус
    /// `cornerConfiguration` (непрерывная кривая). Радиус не больше половины короткой стороны, как
    /// у системной формы. Без `masksToBounds`: цвет слоя и так обрезается по `cornerRadius`.
    private func applyFillShape() {
        let layer = fillView.layer
        switch params.shape {
        case .capsule:
            layer.cornerCurve = .circular
            layer.cornerRadius = min(bounds.width, bounds.height) / 2
        case .rect(let radius):
            layer.cornerCurve = .continuous
            layer.cornerRadius = min(radius, min(bounds.width, bounds.height) / 2)
        }
    }

    private func applyLegacyRadius() {
        guard !shapeByConfiguration else { return }
        switch params.shape {
        case .capsule:
            layer.cornerRadius = min(bounds.width, bounds.height) / 2
        case .rect(let radius):
            layer.cornerRadius = radius
        }
    }

    /// Сдвиг по лестнице толщины с упором в края. Материал, заданный из Dart явно, и тон не сдвигаются:
    /// их выбрал вызывающий. `chrome` вне лестницы.
    private static func shifted(
        _ material: DropwebGlassParams.Material, by step: Int
    ) -> DropwebGlassParams.Material {
        let ladder: [DropwebGlassParams.Material] = [.ultraThin, .thin, .regular, .thick]
        guard step != 0, let index = ladder.firstIndex(of: material) else { return material }
        return ladder[min(max(index + step, 0), ladder.count - 1)]
    }

    /// Материал iOS 13–25 по классу доски (`glass-map.md`, раздел 2).
    static func blurStyle(_ p: DropwebGlassParams) -> UIBlurEffect.Style {
        // Матовая карточка контента всегда `systemThickMaterial` (iOS 13+): ни класс, ни явный
        // материал, ни тон, ни уровень «Стекло» его не сдвигают.
        if p.variant == .content {
            return style(.thick, dark: p.dark)
        }
        var material: DropwebGlassParams.Material
        if let forced = p.material {
            material = forced
        } else if p.tint != nil && p.enabled {
            material = .thin
        } else {
            switch p.variant {
            case .small: material = .ultraThin
            case .md: material = .regular
            case .lg: material = .thick
            case .widget: material = .thin
            case .inactive: material = .ultraThin
            case .content: material = .thick
            }
            material = shifted(material, by: p.materialStep)
        }
        return style(material, dark: p.dark)
    }

    /// Стиль `UIBlurEffect` для материала и темы: явные `Light`/`Dark`, когда тему задал Dart.
    private static func style(
        _ material: DropwebGlassParams.Material, dark: Bool?
    ) -> UIBlurEffect.Style {
        switch (material, dark) {
        case (.ultraThin, nil): return .systemUltraThinMaterial
        case (.ultraThin, true?): return .systemUltraThinMaterialDark
        case (.ultraThin, false?): return .systemUltraThinMaterialLight
        case (.thin, nil): return .systemThinMaterial
        case (.thin, true?): return .systemThinMaterialDark
        case (.thin, false?): return .systemThinMaterialLight
        case (.regular, nil): return .systemMaterial
        case (.regular, true?): return .systemMaterialDark
        case (.regular, false?): return .systemMaterialLight
        case (.thick, nil): return .systemThickMaterial
        case (.thick, true?): return .systemThickMaterialDark
        case (.thick, false?): return .systemThickMaterialLight
        case (.chrome, nil): return .systemChromeMaterial
        case (.chrome, true?): return .systemChromeMaterialDark
        case (.chrome, false?): return .systemChromeMaterialLight
        }
    }
}

/// Обёртка для Flutter: платформенный вид `dropweb/glass` плюс канал
/// `dropweb/glass_<id>` для `updateParams` без пересоздания вида.
final class DropwebGlassPlatformView: NSObject, FlutterPlatformView {
    private let glassView: DropwebGlassEffectView
    private let channel: FlutterMethodChannel

    init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
        glassView = DropwebGlassEffectView(params: DropwebGlassParams(arguments))
        glassView.frame = frame
        channel = FlutterMethodChannel(name: "dropweb/glass_\(viewId)", binaryMessenger: messenger)
        super.init()
        // Читать нечего: текст и значки рисует Flutter, а слой доступности дублировал бы их.
        glassView.isAccessibilityElement = false
        glassView.accessibilityElementsHidden = true
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }

    func view() -> UIView {
        glassView
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "updateParams":
            glassView.apply(DropwebGlassParams(call.arguments))
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
