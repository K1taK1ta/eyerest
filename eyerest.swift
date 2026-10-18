// Full-screen eye-rest reminder (20-20-20). Usage: eyerest [seconds]. Esc or click skips; idle >1h skips.
import Cocoa

let seconds = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 20 : 20

// Skip when the user has been away (no mouse/keyboard input) for over an hour.
let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
if idle > 3600 { exit(0) }

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { NSApp.terminate(nil) } }
    override func mouseDown(with event: NSEvent) { NSApp.terminate(nil) }
}

func label(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = .systemFont(ofSize: size, weight: weight)
    l.textColor = NSColor.white.withAlphaComponent(alpha)
    l.alignment = .center
    l.translatesAutoresizingMaskIntoConstraints = false
    return l
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

var windows: [OverlayWindow] = []
var counters: [NSTextField] = []

for screen in NSScreen.screens {
    let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    w.level = .screenSaver
    w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    w.backgroundColor = NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.10, alpha: 0.94)
    w.isOpaque = false
    w.alphaValue = 0

    let emoji = label("👀", size: 96, weight: .regular, alpha: 1)
    let title = label("Отвернись от экрана", size: 64, weight: .semibold, alpha: 1)
    let hint = label("Посмотри вдаль — на 6 метров и дальше. Моргни.", size: 26, weight: .regular, alpha: 0.7)
    let counter = label("\(seconds)", size: 120, weight: .thin, alpha: 0.9)
    counter.font = .monospacedDigitSystemFont(ofSize: 120, weight: .thin)
    let skip = label("Esc или клик — пропустить", size: 15, weight: .regular, alpha: 0.35)

    let stack = NSStackView(views: [emoji, title, hint, counter])
    stack.orientation = .vertical
    stack.spacing = 24
    stack.translatesAutoresizingMaskIntoConstraints = false
    let content = w.contentView!
    content.addSubview(stack)
    content.addSubview(skip)
    NSLayoutConstraint.activate([
        stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
        stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        skip.centerXAnchor.constraint(equalTo: content.centerXAnchor),
        skip.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),
    ])

    w.setFrame(screen.frame, display: true)
    w.orderFrontRegardless()
    windows.append(w)
    counters.append(counter)
}

app.activate(ignoringOtherApps: true)
windows.first?.makeKey()
NSAnimationContext.runAnimationGroup { ctx in
    ctx.duration = 0.6
    windows.forEach { $0.animator().alphaValue = 1 }
}

var left = seconds
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    left -= 1
    counters.forEach { $0.stringValue = "\(max(left, 0))" }
    if left == 0 {
        NSSound(named: "Glass")?.play()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.5
            windows.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: { NSApp.terminate(nil) })
    }
}

app.run()
