import AppKit
import ServiceManagement

// MARK: - Settings

enum Defaults {
    static let store = UserDefaults.standard

    static var showSeconds: Bool {
        get { store.object(forKey: "showSecondsV2") as? Bool ?? false }
        set { store.set(newValue, forKey: "showSecondsV2") }
    }
    static var use24Hour: Bool {
        get { store.object(forKey: "use24Hour") as? Bool ?? false }
        set { store.set(newValue, forKey: "use24Hour") }
    }
    static var showDate: Bool {
        get { store.object(forKey: "showDate") as? Bool ?? false }
        set { store.set(newValue, forKey: "showDate") }
    }
    static var fontSize: Double {
        get {
            let stored = store.object(forKey: "fontSize") as? Double ?? 36
            // Map sizes from the earlier, smaller presets onto the new ones.
            return [18: 24, 28: 36, 42: 52, 64: 72][stored] ?? stored
        }
        set { store.set(newValue, forKey: "fontSize") }
    }
    static var cycleColors: Bool {
        get { store.object(forKey: "cycleColors") as? Bool ?? true }
        set { store.set(newValue, forKey: "cycleColors") }
    }
    static var opacity: Double {
        get { store.object(forKey: "opacity") as? Double ?? 0.85 }
        set { store.set(newValue, forKey: "opacity") }
    }
    static var locked: Bool {
        get { store.bool(forKey: "locked") }
        set { store.set(newValue, forKey: "locked") }
    }
    static var origin: NSPoint? {
        get {
            guard let s = store.string(forKey: "origin") else { return nil }
            return NSPointFromString(s)
        }
        set {
            if let p = newValue { store.set(NSStringFromPoint(p), forKey: "origin") }
        }
    }
}

// MARK: - Clock view

final class ClockView: NSView {
    private let timeLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private let stack = NSStackView()
    private let row = NSStackView()
    private let timerButton = NSButton()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        layer?.borderWidth = 1

        for label in [timeLabel, dateLabel] {
            label.textColor = .white
            label.alignment = .center
            label.isSelectable = false
        }
        dateLabel.textColor = NSColor.white.withAlphaComponent(0.7)

        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .centerX
        stack.addArrangedSubview(timeLabel)
        stack.addArrangedSubview(dateLabel)
        timerButton.isBordered = false
        timerButton.imagePosition = .imageOnly
        timerButton.contentTintColor = NSColor.white.withAlphaComponent(0.75)
        timerButton.target = self
        timerButton.action = #selector(showTimerMenu)
        timerButton.toolTip = "Set a timer"

        row.orientation = .horizontal
        row.alignment = .centerY
        row.addArrangedSubview(stack)
        row.addArrangedSubview(timerButton)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        applyStyle()
    }

    @objc func showTimerMenu() {
        guard let menu = (NSApp.delegate as? AppDelegate)?.quickTimerMenu() else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: timerButton.bounds.height + 4), in: timerButton)
    }

    required init?(coder: NSCoder) { fatalError() }

    func applyStyle() {
        let size = CGFloat(Defaults.fontSize)
        let condensed = NSFont.systemFont(ofSize: size * 1.35, weight: .semibold, width: .condensed)
        let monoDigits = condensed.fontDescriptor.addingAttributes([.featureSettings: [[
            NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
            NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
        ]]])
        timeLabel.font = NSFont(descriptor: monoDigits, size: 0) ?? condensed
        dateLabel.font = .systemFont(ofSize: max(10, size * 0.4), weight: .medium)
        dateLabel.isHidden = !Defaults.showDate
        row.spacing = size * 0.35
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.85, weight: .semibold)
        timerButton.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Set a timer")?
            .withSymbolConfiguration(config)
    }

    enum Mode { case clock, running, paused, finished(flashOn: Bool) }

    /// Bright colors that read well on the dark background. Red is left out since it means "time's up".
    static let palette: [NSColor] = [
        NSColor(srgbRed: 0.00, green: 0.90, blue: 1.00, alpha: 1), // cyan
        NSColor(srgbRed: 0.65, green: 1.00, blue: 0.00, alpha: 1), // lime
        NSColor(srgbRed: 1.00, green: 0.31, blue: 0.85, alpha: 1), // pink
        NSColor(srgbRed: 1.00, green: 0.90, blue: 0.00, alpha: 1), // yellow
        NSColor(srgbRed: 0.70, green: 0.53, blue: 1.00, alpha: 1), // violet
        NSColor(srgbRed: 0.24, green: 1.00, blue: 0.69, alpha: 1), // mint
    ]
    private var lastColorIndex = -1

    /// Same color for 22 seconds, then the next one; the first color when cycling is off.
    private func accentColor(_ now: Date) -> NSColor {
        guard Defaults.cycleColors else { return Self.palette[0] }
        let index = Int(now.timeIntervalSince1970 / 22) % Self.palette.count
        if index != lastColorIndex {
            if lastColorIndex != -1 { pulseBorder() }
            lastColorIndex = index
        }
        return Self.palette[index]
    }

    /// A quick thick-border flash on each color change, to catch the eye.
    private func pulseBorder() {
        let pulse = CABasicAnimation(keyPath: "borderWidth")
        pulse.fromValue = 4
        pulse.toValue = 1.5
        pulse.duration = 0.6
        layer?.add(pulse, forKey: "pulse")
    }

    /// Shows the clock, or a countdown with the clock underneath when `countdown` is set.
    func update(_ now: Date, countdown: String? = nil, mode: Mode = .clock) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        let hours = Defaults.use24Hour ? "HH" : "h"
        let secs = Defaults.showSeconds ? ":ss" : ""
        let ampm = Defaults.use24Hour ? "" : " a"
        f.dateFormat = "\(hours):mm\(secs)\(ampm)"
        let clock = f.string(from: now)

        var background = NSColor.black.withAlphaComponent(0.65)
        let accent = accentColor(now)
        var textColor = Defaults.cycleColors ? accent : NSColor.white
        var border = accent.withAlphaComponent(0.6)
        if let countdown {
            timeLabel.stringValue = countdown
            dateLabel.isHidden = false
            dateLabel.stringValue = clock
            switch mode {
            case .paused:
                textColor = NSColor.white.withAlphaComponent(0.5)
                border = NSColor.white.withAlphaComponent(0.15)
            case .finished(let flashOn):
                textColor = .white
                border = .white
                background = flashOn ? NSColor.systemRed.withAlphaComponent(0.9)
                                     : NSColor.black.withAlphaComponent(0.65)
            default:
                textColor = accent
            }
        } else {
            timeLabel.stringValue = clock
            dateLabel.isHidden = !Defaults.showDate
            if Defaults.showDate {
                f.dateFormat = "EEE, d MMM"
                dateLabel.stringValue = f.string(from: now)
            }
        }
        timeLabel.textColor = textColor
        timerButton.contentTintColor = textColor.withAlphaComponent(0.85)
        layer?.backgroundColor = background.cgColor
        layer?.borderColor = border.cgColor
        layer?.borderWidth = 1.5
    }

    /// Size the window needs to fit the current text.
    func fittingContentSize() -> NSSize {
        let s = row.fittingSize
        let padH = CGFloat(Defaults.fontSize) * 0.5
        let padV = CGFloat(Defaults.fontSize) * 0.4
        return NSSize(width: ceil(s.width + padH * 2), height: ceil(s.height + padV * 2))
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        (NSApp.delegate as? AppDelegate)?.buildMenu()
    }

    override func mouseDown(with event: NSEvent) {
        if (NSApp.delegate as? AppDelegate)?.handleClick(count: event.clickCount) != true {
            super.mouseDown(with: event)
        }
    }
}

// MARK: - Floating panel

final class ClockPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 160, height: 50),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        // High level so it sits above full-screen apps and slideshows.
        level = .screenSaver
        // Follow every Space (three-finger swipe) and appear over full-screen apps.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let panel = ClockPanel()
    let clockView = ClockView(frame: .zero)
    var statusItem: NSStatusItem!
    var timer: Timer?

    enum CountdownState {
        case idle
        case running(end: Date)
        case paused(remaining: TimeInterval)
        case finished(at: Date)
    }
    var countdown: CountdownState = .idle
    var countdownTotal: TimeInterval = 0
    var lastChimeSecond = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.contentView = clockView
        panel.delegate = self
        panel.alphaValue = Defaults.opacity
        panel.isMovableByWindowBackground = !Defaults.locked

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "SpaceClock")
        statusItem.menu = buildMenu()

        refresh()
        positionInitially()
        panel.orderFrontRegardless()

        // Tick several times a second so both the clock and a countdown change right on time.
        timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func tick() {
        let now = Date()
        if case .running(let end) = countdown, now >= end {
            countdown = .finished(at: end)
            lastChimeSecond = -1
            statusItem.menu = buildMenu()
        }
        render(now)
        // Re-assert being on top in case another app raised itself.
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func render(_ now: Date) {
        switch countdown {
        case .idle:
            clockView.update(now)
        case .running(let end):
            clockView.update(now, countdown: format(end.timeIntervalSince(now)), mode: .running)
        case .paused(let remaining):
            clockView.update(now, countdown: "⏸ " + format(remaining), mode: .paused)
        case .finished(let at):
            let elapsed = Int(now.timeIntervalSince(at))
            // Chime every 2 seconds for the first 10 seconds, then just keep flashing.
            if elapsed != lastChimeSecond && elapsed % 2 == 0 && elapsed < 10 {
                lastChimeSecond = elapsed
                NSSound(named: "Glass")?.play()
            }
            clockView.update(now, countdown: "Time's up!", mode: .finished(flashOn: elapsed % 2 == 0))
        }
        resizeToFit()
    }

    /// Countdown text: rounds up so it reads 0:01 until the very end, never 0:00 early.
    func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(ceil(interval)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// Single click dismisses a finished timer; double-click pauses/resumes a timer,
    /// or toggles seconds when no timer is set. Returns true if the click was used.
    func handleClick(count: Int) -> Bool {
        if case .finished = countdown {
            stopTimer()
            return true
        }
        guard count == 2 else { return false }
        switch countdown {
        case .running, .paused: togglePause()
        default: toggleSeconds()
        }
        return true
    }

    // MARK: Timer

    func startTimer(_ seconds: TimeInterval) {
        countdownTotal = seconds
        countdown = .running(end: Date().addingTimeInterval(seconds))
        refresh()
    }

    @objc func startPreset(_ sender: NSMenuItem) {
        if let minutes = sender.representedObject as? Double { startTimer(minutes * 60) }
    }

    @objc func togglePause() {
        switch countdown {
        case .running(let end): countdown = .paused(remaining: end.timeIntervalSinceNow)
        case .paused(let remaining): countdown = .running(end: Date().addingTimeInterval(remaining))
        default: return
        }
        refresh()
    }

    @objc func restartTimer() { startTimer(countdownTotal) }

    @objc func stopTimer() {
        countdown = .idle
        refresh()
    }

    @objc func customTimer() {
        let alert = NSAlert()
        alert.messageText = "Set a Timer"
        alert.informativeText = "Enter minutes (7), minutes:seconds (2:30), or units (1h 15m, 90s)."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "e.g. 5"
        alert.accessoryView = field
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let seconds = parseDuration(field.stringValue) {
            startTimer(seconds)
        } else {
            NSSound.beep()
        }
    }

    func parseDuration(_ input: String) -> TimeInterval? {
        let text = input.trimmingCharacters(in: .whitespaces).lowercased()
        if text.isEmpty { return nil }

        if text.contains(":") {
            // m:ss or h:mm:ss
            let parts = text.split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count <= 3, parts.allSatisfy({ $0 != nil }) else { return nil }
            let seconds = parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
            return seconds > 0 ? seconds : nil
        }
        if let minutes = Double(text) {
            return minutes > 0 ? minutes * 60 : nil
        }

        let regex = try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(h|hr|hrs|hours?|m|min|mins|minutes?|s|sec|secs|seconds?)\b"#)
        let range = NSRange(text.startIndex..., in: text)
        var seconds = 0.0
        for match in regex.matches(in: text, range: range) {
            guard let value = Double(text[Range(match.range(at: 1), in: text)!]) else { continue }
            switch text[Range(match.range(at: 2), in: text)!].first {
            case "h": seconds += value * 3600
            case "m": seconds += value * 60
            default: seconds += value
            }
        }
        return seconds > 0 ? seconds : nil
    }

    func refresh() {
        clockView.applyStyle()
        render(Date())
        resizeToFit()
        panel.alphaValue = Defaults.opacity
        panel.isMovableByWindowBackground = !Defaults.locked
        statusItem?.menu = buildMenu()
    }

    func resizeToFit() {
        let size = clockView.fittingContentSize()
        var frame = panel.frame
        guard frame.size != size else { return }
        // Keep the top-right corner anchored so it doesn't drift when text width changes.
        frame.origin.x += frame.width - size.width
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true)
        clockView.layer?.cornerRadius = min(14, size.height / 3)
    }

    func positionInitially() {
        if let o = Defaults.origin, NSScreen.screens.contains(where: { $0.frame.contains(o) }) {
            panel.setFrameOrigin(o)
        } else {
            moveToTopRight()
        }
    }

    func moveToTopRight() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: vf.maxX - size.width - 20, y: vf.maxY - size.height - 20))
        Defaults.origin = panel.frame.origin
    }

    @objc func screensChanged() {
        if !NSScreen.screens.contains(where: { $0.frame.intersects(panel.frame) }) { moveToTopRight() }
    }

    func windowDidMove(_ notification: Notification) {
        Defaults.origin = panel.frame.origin
    }

    // MARK: Menu

    /// Compact menu for the ⏱ button: timer controls (if one is set), then the presets.
    func quickTimerMenu() -> NSMenu {
        let full = buildMenu()
        let menu = NSMenu()
        for item in full.items {
            if let presets = item.submenu, item.title == "Start Timer" {
                if !menu.items.isEmpty { menu.addItem(.separator()) }
                let header = NSMenuItem(title: "Start a Timer", action: nil, keyEquivalent: "")
                header.isEnabled = false
                menu.addItem(header)
                for preset in presets.items {
                    presets.removeItem(preset)
                    menu.addItem(preset)
                }
                break
            }
            full.removeItem(item)
            menu.addItem(item)
        }
        return menu
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()

        func action(_ title: String, _ selector: Selector, in target: NSMenu = menu) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            target.addItem(item)
        }

        // Timer controls first, since that's the most common thing to reach for.
        switch countdown {
        case .running:
            action("Pause Timer", #selector(togglePause))
            action("Restart Timer", #selector(restartTimer))
            action("Stop Timer", #selector(stopTimer))
        case .paused:
            action("Resume Timer", #selector(togglePause))
            action("Restart Timer", #selector(restartTimer))
            action("Stop Timer", #selector(stopTimer))
        case .finished:
            action("Dismiss Timer", #selector(stopTimer))
            action("Restart Timer", #selector(restartTimer))
        case .idle:
            break
        }

        let timerMenu = NSMenu()
        for minutes in [1.0, 2, 5, 10, 15, 20, 25, 30, 45, 60] {
            let item = NSMenuItem(title: "\(Int(minutes)) min", action: #selector(startPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = minutes
            timerMenu.addItem(item)
        }
        timerMenu.addItem(.separator())
        action("Custom…", #selector(customTimer), in: timerMenu)
        let timerItem = NSMenuItem(title: "Start Timer", action: nil, keyEquivalent: "")
        timerItem.submenu = timerMenu
        menu.addItem(timerItem)
        menu.addItem(.separator())

        func toggle(_ title: String, _ on: Bool, _ action: Selector) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.state = on ? .on : .off
            menu.addItem(item)
        }

        toggle("Show Seconds", Defaults.showSeconds, #selector(toggleSeconds))
        toggle("24-Hour Time", Defaults.use24Hour, #selector(toggle24h))
        toggle("Show Date", Defaults.showDate, #selector(toggleDate))
        toggle("Lock Position", Defaults.locked, #selector(toggleLock))
        toggle("Change Color Every 22s", Defaults.cycleColors, #selector(toggleCycleColors))
        menu.addItem(.separator())

        let sizeMenu = NSMenu()
        for (name, value) in [("Small", 24.0), ("Medium", 36.0), ("Large", 52.0), ("Huge", 72.0)] {
            let item = NSMenuItem(title: name, action: #selector(setSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = Defaults.fontSize == value ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let opacityMenu = NSMenu()
        for value in [1.0, 0.85, 0.6, 0.4] {
            let item = NSMenuItem(title: "\(Int(value * 100))%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = abs(Defaults.opacity - value) < 0.01 ? .on : .off
            opacityMenu.addItem(item)
        }
        let opacityItem = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        opacityItem.submenu = opacityMenu
        menu.addItem(opacityItem)

        let reset = NSMenuItem(title: "Move to Top Right", action: #selector(resetPosition), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())
        toggle("Launch at Login", SMAppService.mainApp.status == .enabled, #selector(toggleLogin))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SpaceClock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc func toggleSeconds() { Defaults.showSeconds.toggle(); refresh() }
    @objc func toggle24h() { Defaults.use24Hour.toggle(); refresh() }
    @objc func toggleDate() { Defaults.showDate.toggle(); refresh() }
    @objc func toggleLock() { Defaults.locked.toggle(); refresh() }
    @objc func toggleCycleColors() { Defaults.cycleColors.toggle(); refresh() }
    @objc func resetPosition() { moveToTopRight() }

    @objc func setSize(_ sender: NSMenuItem) {
        if let v = sender.representedObject as? Double { Defaults.fontSize = v; refresh() }
    }

    @objc func setOpacity(_ sender: NSMenuItem) {
        if let v = sender.representedObject as? Double { Defaults.opacity = v; refresh() }
    }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nYou can add SpaceClock manually in System Settings → General → Login Items."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        refresh()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Accessory = no Dock icon; also required for the window to show over other apps' full-screen Spaces.
app.setActivationPolicy(.accessory)
app.run()
