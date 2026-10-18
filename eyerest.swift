// eyerest: full-screen eye-rest reminder for macOS (20-20-20 rule) with a menu bar icon.
//
//   eyerest [--interval s] [--duration s] [--long-every s] [--long-duration s] [--snooze s] [--idle-skip s]
//   eyerest now      ask the running instance to show a break right away
//
// Every `interval` a short break covers all displays for `duration` seconds; once `long-every` has
// passed since the last long break, the break is a long one instead. Breaks are skipped when there
// has been no input for `idle-skip` seconds. Counts per day live in stats.json next to the binary.
import Cocoa

struct Config {
    var interval: TimeInterval = 1200
    var duration: TimeInterval = 20
    var longEvery: TimeInterval = 7200
    var longDuration: TimeInterval = 300
    var snooze: TimeInterval = 300
    var idleSkip: TimeInterval = 3600
}

let showNowNotification = Notification.Name("com.eyerest.shownow")

var config = Config()
var args = Array(CommandLine.arguments.dropFirst())
if args.first == "now" {
    DistributedNotificationCenter.default().postNotificationName(showNowNotification, object: nil, userInfo: nil, deliverImmediately: true)
    exit(0)
}
while args.count >= 2 {
    let flag = args.removeFirst()
    guard let value = Double(args.removeFirst()), value > 0 else { continue }
    switch flag {
    case "--interval": config.interval = value
    case "--duration": config.duration = value
    case "--long-every": config.longEvery = value
    case "--long-duration": config.longDuration = value
    case "--snooze": config.snooze = value
    case "--idle-skip": config.idleSkip = value
    default: break
    }
}

let shortTips = [
    "Посмотри вдаль — на 6 метров и дальше.",
    "Медленно моргни 10 раз.",
    "Проведи взглядом большой круг: по часовой, потом против.",
    "Найди самый дальний предмет за окном и рассмотри детали.",
    "Закрой глаза и расслабь лоб, брови и челюсть.",
    "Переводи взгляд: близкий предмет — дальний, 5 раз.",
    "Посмотри вверх, вниз, влево, вправо — не поворачивая головы.",
    "Потри ладони и приложи тёплые ладони к закрытым глазам.",
]
let longTips = [
    "Встань, пройдись, налей воды.",
    "Разомни шею и плечи, потянись.",
    "Подойди к окну и посмотри вдаль.",
    "Сделай пару приседаний и глубоких вдохов.",
]

func secondsIdle() -> TimeInterval {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
}

// MARK: - Stats

final class Stats {
    struct Day: Codable { var done = 0, skipped = 0, snoozed = 0 }

    private var days: [String: Day] = [:]
    private let url: URL
    private let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EyeRest")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("stats.json")
        if let data = try? Data(contentsOf: url) { days = (try? JSONDecoder().decode([String: Day].self, from: data)) ?? [:] }
    }

    var today: Day { days[dayKey.string(from: Date())] ?? Day() }

    func record(_ field: WritableKeyPath<Day, Int>) {
        days[dayKey.string(from: Date()), default: Day()][keyPath: field] += 1
        if let data = try? JSONEncoder().encode(days) { try? data.write(to: url, options: .atomic) }
    }
}

// MARK: - Overlay

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class Overlay: NSObject {
    enum Outcome { case done, skipped, snoozed }

    private var windows: [OverlayWindow] = []
    private var counters: [NSTextField] = []
    private var timer: Timer?
    private var left: Int
    private let long: Bool
    private let onFinish: (Outcome) -> Void
    private var finished = false

    init(long: Bool, onFinish: @escaping (Outcome) -> Void) {
        self.long = long
        self.left = Int(long ? config.longDuration : config.duration)
        self.onFinish = onFinish
        super.init()
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = NSColor.white.withAlphaComponent(alpha)
        l.alignment = .center
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

    func show() {
        let tip = (long ? longTips : shortTips).randomElement()!
        for screen in NSScreen.screens {
            let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.level = .screenSaver
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.backgroundColor = long
                ? NSColor(calibratedRed: 0.05, green: 0.10, blue: 0.07, alpha: 0.96)
                : NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.10, alpha: 0.94)
            w.isOpaque = false
            w.alphaValue = 0

            let emoji = label(long ? "🚶" : "👀", size: 96, weight: .regular, alpha: 1)
            let title = label(long ? "Время для длинного перерыва" : "Отвернись от экрана", size: 64, weight: .semibold, alpha: 1)
            let hint = label(tip, size: 26, weight: .regular, alpha: 0.7)
            let counter = label(countdownText, size: 120, weight: .thin, alpha: 0.9)
            counter.font = .monospacedDigitSystemFont(ofSize: 120, weight: .thin)

            let snooze = button("Ещё \(Int(config.snooze / 60)) мин", #selector(snoozeTapped))
            let skip = button("Пропустить", #selector(skipTapped))
            skip.keyEquivalent = "\u{1b}"
            let buttons = NSStackView(views: [snooze, skip])
            buttons.spacing = 16
            let escHint = label("Esc — пропустить", size: 13, weight: .regular, alpha: 0.35)

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
            ])

            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            windows.append(w)
            counters.append(counter)
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            windows.forEach { $0.animator().alphaValue = 1 }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.left -= 1
            self.counters.forEach { $0.stringValue = self.countdownText }
            if self.left <= 0 {
                NSSound(named: "Glass")?.play()
                self.finish(.done)
            }
        }
    }

    @objc private func snoozeTapped() { finish(.snoozed) }
    @objc private func skipTapped() { finish(.skipped) }

    private func finish(_ outcome: Outcome) {
        guard !finished else { return }
        finished = true
        timer?.invalidate()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            windows.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            self.windows.forEach { $0.orderOut(nil) }
            self.windows = []
            NSApp.hide(nil)  // hand focus back to the app the user was in
            self.onFinish(outcome)
        })
    }
}

// MARK: - Scheduler and menu bar

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let stats = Stats()
    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let statsLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var pauseHourItem: NSMenuItem!
    private var pauseTodayItem: NSMenuItem!
    private var resumeItem: NSMenuItem!

    private var nextBreak = Date().addingTimeInterval(config.interval)
    private var lastLong = Date()
    private var pausedUntil: Date?
    private var awaySince: Date?
    private var overlay: Overlay?

    private let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

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
        menu.addItem(item("Показать сейчас", #selector(showNow)))
        pauseHourItem = item("Пауза на час", #selector(pauseHour))
        pauseTodayItem = item("Выключить до завтра", #selector(pauseToday))
        resumeItem = item("Возобновить", #selector(resume))
        menu.addItem(pauseHourItem)
        menu.addItem(pauseTodayItem)
        menu.addItem(resumeItem)
        menu.addItem(.separator())
        menu.addItem(item("Выйти до следующего входа", #selector(quit)))
        statusItem.menu = menu
        updateIcon()

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.wentAway() }
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.cameBack() }
        let dn = DistributedNotificationCenter.default()
        dn.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in self?.wentAway() }
        dn.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in self?.cameBack() }
        dn.addObserver(forName: showNowNotification, object: nil, queue: .main) { [weak self] _ in self?.showNow() }
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    private func updateIcon() {
        let name = pausedUntil == nil ? "eye" : "eye.slash"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "eyerest")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private var nextIsLong: Bool { Date().timeIntervalSince(lastLong) >= config.longEvery }

    private func tick() {
        guard overlay == nil, awaySince == nil else { return }
        let now = Date()
        if let until = pausedUntil {
            guard now >= until else { return }
            pausedUntil = nil
            nextBreak = now.addingTimeInterval(config.interval)
            updateIcon()
            return
        }
        guard now >= nextBreak else { return }
        if secondsIdle() > config.idleSkip {
            nextBreak = now.addingTimeInterval(config.interval)
            return
        }
        startBreak()
    }

    private func startBreak() {
        let long = nextIsLong
        let overlay = Overlay(long: long) { [weak self] outcome in
            guard let self else { return }
            self.overlay = nil
            let now = Date()
            switch outcome {
            case .snoozed:
                self.stats.record(\.snoozed)
                self.nextBreak = now.addingTimeInterval(config.snooze)
            case .done, .skipped:
                self.stats.record(outcome == .done ? \.done : \.skipped)
                self.nextBreak = now.addingTimeInterval(config.interval)
                if long { self.lastLong = now }
            }
        }
        self.overlay = overlay
        overlay.show()
    }

    private func wentAway() {
        if awaySince == nil { awaySince = Date() }
    }

    // Sleep or a locked screen is a break in itself: restart the schedule, and count a long enough
    // absence as the long break.
    private func cameBack() {
        guard let since = awaySince else { return }
        awaySince = nil
        let now = Date()
        if now.timeIntervalSince(since) >= config.longDuration { lastLong = now }
        nextBreak = now.addingTimeInterval(config.interval)
    }

    func menuWillOpen(_ menu: NSMenu) {
        let now = Date()
        if let until = pausedUntil {
            statusLine.title = Calendar.current.isDateInToday(until)
                ? "Пауза до \(clock.string(from: until))"
                : "Выключено до завтра"
        } else {
            let minutes = max(0, Int(nextBreak.timeIntervalSince(now) / 60 + 0.5))
            statusLine.title = "Следующий \(nextIsLong ? "длинный " : "")перерыв через \(minutes) мин"
        }
        let t = stats.today
        statsLine.title = "Сегодня: \(t.done) выполнено · \(t.skipped) пропущено · \(t.snoozed) отложено"
        pauseHourItem.isHidden = pausedUntil != nil
        pauseTodayItem.isHidden = pausedUntil != nil
        resumeItem.isHidden = pausedUntil == nil
    }

    @objc private func showNow() {
        guard overlay == nil else { return }
        pausedUntil = nil
        updateIcon()
        startBreak()
    }

    @objc private func pauseHour() {
        pausedUntil = Date().addingTimeInterval(3600)
        updateIcon()
    }

    @objc private func pauseToday() {
        pausedUntil = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        updateIcon()
    }

    @objc private func resume() {
        pausedUntil = nil
        nextBreak = Date().addingTimeInterval(config.interval)
        updateIcon()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
