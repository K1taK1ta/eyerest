// EyeRest: full-screen eye-rest reminder for macOS with a menu bar icon and a settings window.
//
//   eyerest                run the menu bar app (launchd starts it at login)
//   eyerest now            ask the running instance to show a break right away
//   eyerest --interval s --duration s --long-every s --long-duration s --snooze s --idle-skip s
//                          set those settings (saved, same as the settings window) and run
//
// Every `interval` a short break covers all displays for `duration` seconds; once `long-every` has
// passed since the last long break, the break is a long one instead. Breaks are skipped when there
// has been no input for `idle-skip` seconds. Settings live in UserDefaults (com.eyerest.reminder),
// counts per day in ~/Library/Application Support/EyeRest/stats.json.
import Cocoa
import SwiftUI

let showNowNotification = Notification.Name("com.eyerest.shownow")
let applyFlagsNotification = Notification.Name("com.eyerest.applyflags")
let openSettingsNotification = Notification.Name("com.eyerest.opensettings")

func secondsIdle() -> TimeInterval {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
}

/// UI language, "ru" or "en"; set from the settings.
var uiLanguage = "ru"

/// Picks the string for the current UI language.
func L(_ ru: String, _ en: String) -> String { uiLanguage == "en" ? en : ru }

func playSound(_ name: String) {
    (NSSound(named: name)?.copy() as? NSSound)?.play()
}

// MARK: - Tips

struct Tip { let ru: String, en: String; var text: String { L(ru, en) } }

// Sources for every tip are listed in README.md (Health notes).
let shortTips = [
    Tip(ru: "Посмотри вдаль — метров на шесть — и задержи взгляд.", en: "Look about 20 feet (6 m) away and hold your gaze there."),
    Tip(ru: "Найди за окном самую дальнюю точку и рассмотри её.", en: "Find the farthest point out the window and study it."),
    Tip(ru: "Медленно поморгай 10 раз, полностью смыкая веки.", en: "Blink slowly 10 times, closing your eyelids fully."),
    Tip(ru: "Закрой глаза на несколько секунд — пусть отдохнут.", en: "Close your eyes for a few seconds and let them rest."),
    Tip(ru: "За экраном мы моргаем в 2–3 раза реже. Моргни нарочно.", en: "At a screen we blink 2–3 times less often. Blink on purpose."),
    Tip(ru: "Экран — примерно на длине вытянутой руки.", en: "Keep the screen about an arm's length away."),
    Tip(ru: "Верх экрана — на уровне глаз или чуть ниже.", en: "The top of the screen belongs at or just below eye level."),
    Tip(ru: "Блики на экране? Сдвинь монитор или прикрой штору.", en: "Glare on the screen? Move the monitor or close the blinds."),
    Tip(ru: "Яркость экрана — как в комнате, не ярче.", en: "Match screen brightness to the room, not brighter."),
    Tip(ru: "Сухость в глазах? Помогут увлажняющие капли.", en: "Dry eyes? Lubricating eye drops can help."),
    Tip(ru: "Сухой воздух сушит глаза — подумай об увлажнителе.", en: "Dry air dries the eyes — consider a humidifier."),
    Tip(ru: "Носишь линзы? Иногда давай глазам отдых в очках.", en: "Wear contacts? Give your eyes a rest in glasses now and then."),
    Tip(ru: "Бумаги держи на том же расстоянии, что и экран.", en: "Keep papers at the same distance as the screen."),
    Tip(ru: "Давно проверял зрение? Раз в 1–2 года — в самый раз.", en: "Last eye exam a while ago? Every 1–2 years is about right."),
    Tip(ru: "Расслабь плечи и опусти их вниз.", en: "Relax your shoulders and let them drop."),
]
let longTips = [
    Tip(ru: "Встань и пройдись пару минут — хоть до кухни.", en: "Stand up and walk for a couple of minutes — even to the kitchen."),
    Tip(ru: "Пройдись по коридору или по лестнице.", en: "Walk down the corridor or take the stairs."),
    Tip(ru: "Потянись вверх, затем медленно наклонись в стороны.", en: "Reach up, then slowly bend side to side."),
    Tip(ru: "Покрути плечами назад 10 раз, расслабь шею.", en: "Roll your shoulders back 10 times, relax your neck."),
    Tip(ru: "Отдохни без экрана — телефон тоже отложи.", en: "Rest away from screens — put the phone down too."),
    Tip(ru: "Налей воды и сделай пару глотков.", en: "Get some water and take a few sips."),
    Tip(ru: "Поработай немного стоя, если стол позволяет.", en: "Work standing for a while if your desk allows."),
    Tip(ru: "Созвон без экрана? Проведи его стоя или на ходу.", en: "A call without a screen? Take it standing or walking."),
    Tip(ru: "Садясь обратно: стопы на полу, спина на опоре.", en: "Sitting back down: feet flat, back supported."),
    Tip(ru: "Пусть глаза отдохнут: смотри вдаль, а не в телефон.", en: "Let your eyes rest: look far away, not at your phone."),
]

// MARK: - Settings

final class Prefs: ObservableObject {
    static let sounds = ["Glass", "Tink", "Purr", "Pop", "Bottle", "Ping", "Hero", "Submarine"]

    private let store = UserDefaults.standard
    /// Called when the short-break interval changes, so the schedule can restart from now.
    var onIntervalChange: (() -> Void)?

    @Published var interval: Double { didSet { store.set(interval, forKey: "interval"); onIntervalChange?() } }
    @Published var duration: Double { didSet { store.set(duration, forKey: "duration") } }
    @Published var longEnabled: Bool { didSet { store.set(longEnabled, forKey: "longEnabled") } }
    @Published var longEvery: Double { didSet { store.set(longEvery, forKey: "longEvery") } }
    @Published var longDuration: Double { didSet { store.set(longDuration, forKey: "longDuration") } }
    @Published var snooze: Double { didSet { store.set(snooze, forKey: "snooze") } }
    /// Seconds without input after which a break is skipped; 0 means never skip.
    @Published var idleSkip: Double { didSet { store.set(idleSkip, forKey: "idleSkip") } }
    /// Seconds before a break to show the heads-up panel; 0 turns it off.
    @Published var warnBefore: Double { didSet { store.set(warnBefore, forKey: "warnBefore") } }
    @Published var soundAtStart: Bool { didSet { store.set(soundAtStart, forKey: "soundAtStart") } }
    @Published var soundAtEnd: Bool { didSet { store.set(soundAtEnd, forKey: "soundAtEnd") } }
    @Published var soundName: String { didSet { store.set(soundName, forKey: "soundName") } }
    @Published var language: String { didSet { store.set(language, forKey: "language"); uiLanguage = language } }

    init() {
        store.register(defaults: [
            "interval": 1200.0, "duration": 20.0, "longEnabled": true, "longEvery": 7200.0, "longDuration": 300.0,
            "snooze": 300.0, "idleSkip": 3600.0, "warnBefore": 10.0, "soundAtStart": false, "soundAtEnd": true, "soundName": "Glass",
        ])
        interval = store.double(forKey: "interval")
        duration = store.double(forKey: "duration")
        longEnabled = store.bool(forKey: "longEnabled")
        longEvery = store.double(forKey: "longEvery")
        longDuration = store.double(forKey: "longDuration")
        snooze = store.double(forKey: "snooze")
        idleSkip = store.double(forKey: "idleSkip")
        warnBefore = store.double(forKey: "warnBefore")
        soundAtStart = store.bool(forKey: "soundAtStart")
        soundAtEnd = store.bool(forKey: "soundAtEnd")
        soundName = store.string(forKey: "soundName") ?? "Glass"
        let systemLanguage = Locale.preferredLanguages.first?.hasPrefix("ru") == true ? "ru" : "en"
        language = store.string(forKey: "language") ?? systemLanguage
        uiLanguage = language
    }

    func apply(flags: [String]) {
        var args = flags
        while args.count >= 2 {
            let flag = args.removeFirst()
            guard let value = Double(args.removeFirst()), value >= 0 else { continue }
            switch flag {
            case "--interval" where value > 0: interval = value
            case "--duration" where value > 0: duration = value
            case "--long-every" where value > 0: longEvery = value
            case "--long-duration" where value > 0: longDuration = value
            case "--snooze" where value > 0: snooze = value
            case "--idle-skip": idleSkip = value
            case "--warn": warnBefore = value
            default: break
            }
        }
    }
}

// MARK: - Stats

final class Stats: ObservableObject {
    struct Day: Codable { var done = 0, skipped = 0, snoozed = 0 }

    @Published private(set) var days: [String: Day] = [:]
    private let url: URL
    private let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EyeRest")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("stats.json")
        if let data = try? Data(contentsOf: url) { days = (try? JSONDecoder().decode([String: Day].self, from: data)) ?? [:] }
        // "Today" and "last 7 days" move at midnight even when nothing is recorded.
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var today: Day { days[dayKey.string(from: Date())] ?? Day() }

    /// The last `count` days, newest first, including days with no breaks.
    func recent(_ count: Int) -> [(date: Date, day: Day)] {
        (0..<count).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: Date()).map { ($0, days[dayKey.string(from: $0)] ?? Day()) }
        }
    }

    func record(_ field: WritableKeyPath<Day, Int>) {
        days[dayKey.string(from: Date()), default: Day()][keyPath: field] += 1
        if let data = try? JSONEncoder().encode(days) { try? data.write(to: url, options: .atomic) }
    }
}

// MARK: - Settings window

struct SettingsView: View {
    @ObservedObject var prefs: Prefs
    @ObservedObject var stats: Stats

    private func minutes(_ s: Double) -> String {
        s >= 3600 && s.truncatingRemainder(dividingBy: 3600) == 0 ? "\(Int(s / 3600)) \(L("ч", "h"))"
            : s >= 3600 ? String(format: "%.1f \(L("ч", "h"))", s / 3600).replacingOccurrences(of: ".", with: L(",", "."))
            : "\(Int(s / 60)) \(L("мин", "min"))"
    }

    private func picker(_ title: String, _ value: Binding<Double>, _ options: [Double], _ text: @escaping (Double) -> String) -> some View {
        Picker(title, selection: value) {
            ForEach(options, id: \.self) { Text(text($0)).tag($0) }
            if !options.contains(value.wrappedValue) { Text(text(value.wrappedValue)).tag(value.wrappedValue) }
        }
    }

    private func statsRow(_ title: String, _ days: [Stats.Day]) -> some View {
        let sum = { (field: KeyPath<Stats.Day, Int>) in days.map { $0[keyPath: field] }.reduce(0, +) }
        return HStack {
            Text(title)
            Spacer()
            Text(L("✓ \(sum(\.done))   пропущено \(sum(\.skipped))   отложено \(sum(\.snoozed))",
                   "✓ \(sum(\.done))   skipped \(sum(\.skipped))   snoozed \(sum(\.snoozed))"))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    var body: some View {
        Form {
            Section {
                Picker(L("Язык", "Language"), selection: $prefs.language) {
                    Text("Русский").tag("ru")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
            }
            Section(L("Короткий перерыв — для глаз", "Short break — for the eyes")) {
                picker(L("Каждые", "Every"), $prefs.interval, [600, 900, 1200, 1500, 1800, 2700, 3600], minutes)
                picker(L("Длительность", "Duration"), $prefs.duration, [20, 30, 45, 60]) { "\(Int($0)) \(L("с", "s"))" }
            }
            Section(L("Длинный перерыв — встать и подвигаться", "Long break — stand up and move")) {
                Toggle(L("Включён", "On"), isOn: $prefs.longEnabled)
                picker(L("Каждые", "Every"), $prefs.longEvery, [1800, 3600, 5400, 7200, 10800], minutes).disabled(!prefs.longEnabled)
                picker(L("Длительность", "Duration"), $prefs.longDuration, [120, 180, 300, 600, 900], minutes).disabled(!prefs.longEnabled)
            }
            Section(L("Поведение", "Behaviour")) {
                picker(L("Предупреждать заранее", "Heads-up before a break"), $prefs.warnBefore, [0, 5, 10, 30]) {
                    $0 == 0 ? L("не предупреждать", "off") : "\(Int($0)) \(L("с", "s"))"
                }
                picker(L("«Отложить» на", "Snooze for"), $prefs.snooze, [60, 180, 300, 600], minutes)
                picker(L("Не показывать, если не трогал компьютер", "Skip breaks after no input for"), $prefs.idleSkip, [1800, 3600, 7200, 0]) {
                    $0 == 0 ? L("показывать всегда", "never skip") : minutes($0)
                }
            }
            Section(L("Звук", "Sound")) {
                Toggle(L("В начале перерыва", "When a break starts"), isOn: $prefs.soundAtStart)
                Toggle(L("В конце перерыва", "When a break ends"), isOn: $prefs.soundAtEnd)
                HStack {
                    Picker(L("Звук", "Sound"), selection: $prefs.soundName) {
                        ForEach(Prefs.sounds, id: \.self) { Text($0).tag($0) }
                    }
                    Button("▶︎") { playSound(prefs.soundName) }.help(L("Прослушать", "Play"))
                }
                .disabled(!prefs.soundAtStart && !prefs.soundAtEnd)
            }
            Section(L("Статистика", "Stats")) {
                statsRow(L("Сегодня", "Today"), stats.recent(1).map(\.day))
                statsRow(L("За 7 дней", "Last 7 days"), stats.recent(7).map(\.day))
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onChange(of: prefs.soundName) { _, name in playSound(name) }
    }
}

// MARK: - Overlay

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class Overlay: NSObject {
    enum Outcome { case done, skipped, snoozed }

    private let prefs: Prefs
    private var windows: [OverlayWindow] = []
    private var counters: [NSTextField] = []
    private var timer: Timer?
    private var screensObserver: NSObjectProtocol?
    private var left: Int
    private var endsAt = Date()
    private let long: Bool
    private let tip: String
    private let onFinish: (Outcome) -> Void
    private var finished = false
    private var previousApp: NSRunningApplication?

    init(long: Bool, prefs: Prefs, onFinish: @escaping (Outcome) -> Void) {
        self.prefs = prefs
        self.long = long
        self.left = Int(long ? prefs.longDuration : prefs.duration)
        self.tip = (long ? longTips : shortTips).randomElement()!.text
        self.onFinish = onFinish
        super.init()
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = NSColor.white.withAlphaComponent(alpha)
        l.alignment = .center
        l.preferredMaxLayoutWidth = 900
        return l
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .large
        b.font = .systemFont(ofSize: 15)
        return b
    }

    private var countdownText: String {
        long ? String(format: "%d:%02d", left / 60, left % 60) : "\(left)"
    }

    private var snoozeTitle: String {
        prefs.snooze < 60 ? L("Ещё \(Int(prefs.snooze)) с", "\(Int(prefs.snooze)) s more")
            : L("Ещё \(Int(prefs.snooze / 60)) мин", "\(Int(prefs.snooze / 60)) min more")
    }

    // One window per display; rebuilt when displays are added, removed or change resolution.
    private func buildWindows(alpha: CGFloat) {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        counters = []
        for screen in NSScreen.screens {
            let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.level = .screenSaver
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.backgroundColor = long
                ? NSColor(calibratedRed: 0.05, green: 0.10, blue: 0.07, alpha: 0.96)
                : NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.10, alpha: 0.94)
            w.isOpaque = false
            w.alphaValue = alpha

            let emoji = label(long ? "🚶" : "👀", size: 96, weight: .regular, alpha: 1)
            let title = label(long ? L("Время для длинного перерыва", "Time for a long break") : L("Отвернись от экрана", "Look away from the screen"), size: 64, weight: .semibold, alpha: 1)
            let hint = label(tip, size: 26, weight: .regular, alpha: 0.75)
            let counter = label(countdownText, size: 120, weight: .thin, alpha: 0.9)
            counter.font = .monospacedDigitSystemFont(ofSize: 120, weight: .thin)

            let snooze = button(snoozeTitle, #selector(snoozeTapped))
            let skip = button(L("Пропустить", "Skip"), #selector(skipTapped))
            skip.keyEquivalent = "\u{1b}"
            let buttons = NSStackView(views: [snooze, skip])
            buttons.spacing = 16
            let escHint = label(L("Esc — пропустить", "Esc — skip"), size: 13, weight: .regular, alpha: 0.35)

            let stack = NSStackView(views: [emoji, title, hint, counter, buttons, escHint])
            stack.orientation = .vertical
            stack.spacing = 24
            stack.setCustomSpacing(40, after: counter)
            stack.setCustomSpacing(12, after: buttons)
            stack.translatesAutoresizingMaskIntoConstraints = false
            let content = w.contentView!
            content.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
                stack.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -80),
            ])

            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            windows.append(w)
            counters.append(counter)
        }
        windows.first?.makeKey()
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        buildWindows(alpha: 0)
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        if prefs.soundAtStart { playSound(prefs.soundName) }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            windows.forEach { $0.animator().alphaValue = 1 }
        }
        screensObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.finished else { return }
            self.buildWindows(alpha: 1)
        }

        // Count down to a fixed end time, in common modes, so holding a button or a busy run loop
        // can neither freeze nor stretch the break.
        endsAt = Date().addingTimeInterval(TimeInterval(left))
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            let remaining = max(0, Int(self.endsAt.timeIntervalSinceNow.rounded(.up)))
            if remaining != self.left {
                self.left = remaining
                self.counters.forEach { $0.stringValue = self.countdownText }
            }
            if remaining == 0 {
                if self.prefs.soundAtEnd { playSound(self.prefs.soundName) }
                self.finish(.done)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func snoozeTapped() { finish(.snoozed) }
    @objc private func skipTapped() { finish(.skipped) }

    private func stop() {
        finished = true
        timer?.invalidate()
        if let screensObserver { NotificationCenter.default.removeObserver(screensObserver) }
    }

    private func finish(_ outcome: Outcome) {
        guard !finished else { return }
        stop()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            windows.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            self.windows.forEach { $0.orderOut(nil) }
            self.windows = []
            self.restoreFocus()
            self.onFinish(outcome)
        })
    }

    // Hands focus back to the app the user was in; if that was EyeRest itself (the settings
    // window), brings that window back to the front instead of hiding the whole app.
    private func restoreFocus() {
        if let app = previousApp, app.processIdentifier != getpid(), !app.isTerminated {
            app.activate()
        } else if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.hide(nil)
        }
    }

    // Closes the overlay at once without reporting an outcome (the user went away mid-break).
    func cancel() {
        guard !finished else { return }
        stop()
        windows.forEach { $0.orderOut(nil) }
        windows = []
        restoreFocus()
    }
}

// MARK: - Heads-up panel

/// A small panel at the top of the screen a few seconds before a break, with Snooze and Skip.
/// It never takes focus, so typing carries on in the current app.
final class Warning: NSObject {
    let panel: NSPanel
    private let text = NSTextField(labelWithString: "")
    private let long: Bool
    private let onSnooze: () -> Void
    private let onSkip: () -> Void

    init(long: Bool, snoozeTitle: String, onSnooze: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.long = long
        self.onSnooze = onSnooze
        self.onSkip = onSkip
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true

        let emoji = NSTextField(labelWithString: long ? "🚶" : "👀")
        emoji.font = .systemFont(ofSize: 22)
        text.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        let snooze = NSButton(title: snoozeTitle, target: self, action: #selector(snoozeTapped))
        let skip = NSButton(title: L("Пропустить", "Skip"), target: self, action: #selector(skipTapped))
        [snooze, skip].forEach { $0.bezelStyle = .rounded }

        let stack = NSStackView(views: [emoji, text, snooze, skip])
        stack.spacing = 10
        stack.setCustomSpacing(18, after: text)
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])

        panel.contentView = background
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
    }

    func update(secondsLeft: Int) {
        text.stringValue = long
            ? L("Длинный перерыв через \(secondsLeft) с", "Long break in \(secondsLeft) s")
            : L("Перерыв через \(secondsLeft) с", "Break in \(secondsLeft) s")
    }

    func show(secondsLeft: Int) {
        update(secondsLeft: secondsLeft)
        let size = panel.contentView!.fittingSize
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let area = screen?.visibleFrame {
            panel.setFrame(NSRect(x: area.midX - size.width / 2, y: area.maxY - size.height - 10,
                                  width: size.width, height: size.height), display: true)
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        let panel = self.panel
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }

    @objc private func snoozeTapped() { onSnooze() }
    @objc private func skipTapped() { onSkip() }
}

// MARK: - Scheduler and menu bar

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let prefs: Prefs
    private let stats = Stats()
    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let statsLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var showNowItem: NSMenuItem!
    private var pauseHourItem: NSMenuItem!
    private var pauseTodayItem: NSMenuItem!
    private var resumeItem: NSMenuItem!
    private var settingsItem: NSMenuItem!
    private var quitItem: NSMenuItem!
    private var settingsWindow: NSWindow?

    private var nextBreak: Date
    private var lastLong = Date()
    /// No break before this moment (set by Snooze, which postpones the long break too).
    private var notBefore = Date.distantPast
    private var pausedUntil: Date?
    private var sleeping = false
    private var locked = false
    private var awaySince: Date?
    private var overlay: Overlay?
    private var warning: Warning?
    /// What the current warning was built for: break type, snooze label and language.
    private var warningKey = ""

    private let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    init(prefs: Prefs) {
        self.prefs = prefs
        nextBreak = Date().addingTimeInterval(prefs.interval)
        super.init()
        prefs.onIntervalChange = { [weak self] in
            guard let self else { return }
            self.nextBreak = Date().addingTimeInterval(self.prefs.interval)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusLine.isEnabled = false
        statsLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(statsLine)
        menu.addItem(.separator())
        showNowItem = item(#selector(showNow))
        pauseHourItem = item(#selector(pauseHour))
        pauseTodayItem = item(#selector(pauseToday))
        resumeItem = item(#selector(resume))
        settingsItem = item(#selector(openSettings), key: ",")
        quitItem = item(#selector(quit))
        [showNowItem, pauseHourItem, pauseTodayItem, resumeItem, .separator(), settingsItem, quitItem].forEach(menu.addItem)
        statusItem.menu = menu
        updateIcon()

        // Common modes: keep ticking while the status menu or a settings picker is open.
        RunLoop.main.add(Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }, forMode: .common)

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = true
            self?.awayChanged()
        }
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = false
            self?.awayChanged()
        }
        let dn = DistributedNotificationCenter.default()
        dn.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.locked = true
            self?.awayChanged()
        }
        dn.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.locked = false
            self?.awayChanged()
        }
        dn.addObserver(forName: showNowNotification, object: nil, queue: .main) { [weak self] _ in self?.showNow() }
        dn.addObserver(forName: openSettingsNotification, object: nil, queue: .main) { [weak self] _ in self?.openSettings() }
        dn.addObserver(forName: applyFlagsNotification, object: nil, queue: .main) { [weak self] note in
            if let flags = note.userInfo?["flags"] as? [String] { self?.prefs.apply(flags: flags) }
        }
    }

    // Finder, Spotlight or `open` on the running app sends a reopen event rather than starting a
    // second process: show the settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    private func item(_ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: "", action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func updateIcon() {
        let name = pausedUntil == nil ? "eye" : "eye.slash"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "EyeRest")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    /// Whether a break starting at `date` is the long one.
    private func isLong(at date: Date) -> Bool {
        prefs.longEnabled && date.timeIntervalSince(lastLong) >= prefs.longEvery
    }

    /// When the next break is due: the short-break deadline or the long-break one, whichever comes
    /// first, but never before a snooze ends.
    private var nextDue: Date {
        let longDue = prefs.longEnabled ? lastLong.addingTimeInterval(prefs.longEvery) : .distantFuture
        return max(notBefore, min(nextBreak, longDue))
    }

    private func tick() {
        guard overlay == nil, awaySince == nil else { return hideWarning() }
        let now = Date()
        if let until = pausedUntil {
            hideWarning()
            guard now >= until else { return }
            pausedUntil = nil
            restartSchedule()
            updateIcon()
            return
        }
        let due = nextDue
        let idle = secondsIdle()
        let idleSkip = prefs.idleSkip > 0 && idle > prefs.idleSkip
        if now >= due {
            hideWarning()
            if idleSkip {
                if idle >= prefs.longDuration { lastLong = now }
                restartSchedule()
                return
            }
            startBreak()
            return
        }
        // Heads-up panel for the last few seconds before the break.
        let left = due.timeIntervalSince(now)
        guard prefs.warnBefore > 0, left <= prefs.warnBefore, !idleSkip else { return hideWarning() }
        let seconds = Int(left.rounded(.up))
        let long = isLong(at: due)
        let key = "\(long)|\(snoozeTitle)|\(uiLanguage)"
        if let warning, key == warningKey {
            warning.update(secondsLeft: seconds)
            return
        }
        hideWarning()
        warningKey = key
        let warning = Warning(long: long, snoozeTitle: snoozeTitle, onSnooze: { [weak self] in
            self?.hideWarning()
            self?.breakEnded(.snoozed, long: long)
        }, onSkip: { [weak self] in
            self?.hideWarning()
            self?.breakEnded(.skipped, long: long)
        })
        self.warning = warning
        warning.show(secondsLeft: seconds)
    }

    private var snoozeTitle: String {
        prefs.snooze < 60 ? L("Отложить на \(Int(prefs.snooze)) с", "Snooze \(Int(prefs.snooze)) s")
            : L("Отложить на \(Int(prefs.snooze / 60)) мин", "Snooze \(Int(prefs.snooze / 60)) min")
    }

    /// Starts the schedule over from now. Both deadlines wait for the next short break, so an
    /// already expired long-break deadline cannot fire straight away.
    private func restartSchedule() {
        nextBreak = Date().addingTimeInterval(prefs.interval)
        notBefore = nextBreak
    }

    private func hideWarning() {
        warning?.close()
        warning = nil
    }

    private func startBreak() {
        hideWarning()
        let long = isLong(at: Date())
        let overlay = Overlay(long: long, prefs: prefs) { [weak self] outcome in
            self?.overlay = nil
            self?.breakEnded(outcome, long: long)
        }
        self.overlay = overlay
        overlay.show()
    }

    private func breakEnded(_ outcome: Overlay.Outcome, long: Bool) {
        let now = Date()
        switch outcome {
        case .snoozed:
            stats.record(\.snoozed)
            nextBreak = now.addingTimeInterval(prefs.snooze)
            notBefore = nextBreak
        case .done, .skipped:
            stats.record(outcome == .done ? \.done : \.skipped)
            nextBreak = now.addingTimeInterval(prefs.interval)
            notBefore = now
            if long { lastLong = now }
        }
    }

    // Sleep or a locked screen is a break in itself: a running overlay is dropped, the schedule
    // restarts once the Mac is both awake and unlocked, and a long enough absence counts as the long break.
    private func awayChanged() {
        let away = sleeping || locked
        if away {
            guard awaySince == nil else { return }
            awaySince = Date()
            hideWarning()
            overlay?.cancel()
            overlay = nil
        } else if let since = awaySince {
            awaySince = nil
            let now = Date()
            if now.timeIntervalSince(since) >= prefs.longDuration { lastLong = now }
            restartSchedule()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        let now = Date()
        if let until = pausedUntil {
            statusLine.title = Calendar.current.isDateInToday(until)
                ? L("Пауза до \(clock.string(from: until))", "Paused until \(clock.string(from: until))")
                : L("Выключено до завтра", "Off until tomorrow")
        } else {
            let minutes = max(0, Int(nextDue.timeIntervalSince(now) / 60 + 0.5))
            statusLine.title = isLong(at: nextDue)
                ? L("Длинный перерыв через \(minutes) мин", "Long break in \(minutes) min")
                : L("Следующий перерыв через \(minutes) мин", "Next break in \(minutes) min")
        }
        let t = stats.today
        statsLine.title = L("Сегодня: \(t.done) выполнено · \(t.skipped) пропущено · \(t.snoozed) отложено",
                            "Today: \(t.done) done · \(t.skipped) skipped · \(t.snoozed) snoozed")
        showNowItem.title = L("Показать сейчас", "Show now")
        pauseHourItem.title = L("Пауза на час", "Pause for an hour")
        pauseTodayItem.title = L("Выключить до завтра", "Off until tomorrow")
        resumeItem.title = L("Возобновить", "Resume")
        settingsItem.title = L("Настройки…", "Settings…")
        quitItem.title = L("Выйти до следующего входа", "Quit until next login")
        pauseHourItem.isHidden = pausedUntil != nil
        pauseTodayItem.isHidden = pausedUntil != nil
        resumeItem.isHidden = pausedUntil == nil
    }

    @objc private func showNow() {
        guard overlay == nil, awaySince == nil else { return }
        pausedUntil = nil
        updateIcon()
        startBreak()
    }

    @objc private func pauseHour() {
        hideWarning()
        pausedUntil = Date().addingTimeInterval(3600)
        updateIcon()
    }

    @objc private func pauseToday() {
        hideWarning()
        pausedUntil = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        updateIcon()
    }

    @objc private func resume() {
        pausedUntil = nil
        restartSchedule()
        updateIcon()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            // A grouped Form scrolls and has no height of its own, so size the window from the
            // content's fitting size (capped to the screen) instead of letting it collapse to zero.
            let content = NSHostingView(rootView: SettingsView(prefs: prefs, stats: stats))
            var size = content.fittingSize
            if let screen = NSScreen.main { size.height = min(size.height, screen.visibleFrame.height - 80) }
            let w = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable],
                             backing: .buffered, defer: false)
            w.contentView = content
            w.title = "EyeRest"
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: - Main

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "now" {
    DistributedNotificationCenter.default().postNotificationName(showNowNotification, object: nil, userInfo: nil, deliverImmediately: true)
    exit(0)
}
#if !PREVIEW
// One instance at a time: launching the app again (e.g. from Finder) opens the running instance's
// settings, or hands it the settings flags given on the command line.
if NSRunningApplication.runningApplications(withBundleIdentifier: "com.eyerest.reminder")
    .contains(where: { $0.processIdentifier != getpid() }) {
    let flags = arguments.filter { !$0.hasPrefix("-psn_") }
    DistributedNotificationCenter.default().postNotificationName(
        flags.isEmpty ? openSettingsNotification : applyFlagsNotification, object: nil,
        userInfo: flags.isEmpty ? nil : ["flags": flags], deliverImmediately: true)
    exit(0)
}
#endif

let app = NSApplication.shared
let prefs = Prefs()
prefs.apply(flags: arguments)

#if PREVIEW
// Debug build only (swiftc -D PREVIEW): render the settings window to PNGs and exit.
for language in ["ru", "en"] {
    prefs.language = language
    let view = NSHostingView(rootView: SettingsView(prefs: prefs, stats: Stats()))
    view.frame = NSRect(origin: .zero, size: view.fittingSize)
    let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = view
    view.layoutSubtreeIfNeeded()
    let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "settings-\(language).png"))

    let warning = Warning(long: false, snoozeTitle: L("Отложить на 5 мин", "Snooze 5 min"), onSnooze: {}, onSkip: {})
    warning.update(secondsLeft: 10)
    let content = warning.panel.contentView!
    content.frame = NSRect(origin: .zero, size: content.fittingSize)
    content.layoutSubtreeIfNeeded()
    let warningRep = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
    content.cacheDisplay(in: content.bounds, to: warningRep)
    try! warningRep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "warning-\(language).png"))
}
exit(0)
#endif

app.setActivationPolicy(.accessory)
let delegate = App(prefs: prefs)
app.delegate = delegate
app.run()
