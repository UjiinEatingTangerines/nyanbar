import AppKit
import SwiftUI

// MARK: - Manager (handles multiple screens)

@MainActor
final class RainbowOverlayManager {
    static let shared = RainbowOverlayManager()

    private var windows: [RainbowOverlayWindow] = []
    private var animationTimer: Timer?
    private var phase: CGFloat = 0
    private var currentHeight: CGFloat = 2
    private let targetHeight: CGFloat = 6
    private var fadeStage: FadeStage = .idle
    private var fadeProgress: CGFloat = 0
    private var screenObserver: Any?

    private enum FadeStage {
        case idle, fadeIn, flowing
    }

    private init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.fadeStage != .idle else { return }
                self.recreateWindows()
            }
        }
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func showRainbow() {
        recreateWindows()
        fadeStage = .fadeIn
        fadeProgress = 0
        phase = 0
        currentHeight = 2

        for window in windows {
            window.alphaValue = 0
            window.orderFrontRegardless()
        }

        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func hideRainbow() {
        fadeStage = .idle
        animationTimer?.invalidate()
        animationTimer = nil

        for window in windows {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                window.animator().alphaValue = 0
            }, completionHandler: { [weak window] in
                window?.orderOut(nil)
            })
        }
    }

    // MARK: - Private

    private func recreateWindows() {
        for window in windows { window.orderOut(nil) }
        windows.removeAll()

        for screen in NSScreen.screens {
            windows.append(RainbowOverlayWindow(for: screen, targetHeight: targetHeight))
        }
    }

    private func tick() {
        switch fadeStage {
        case .idle:
            return

        case .fadeIn:
            fadeProgress += 1.0 / 9.0 // ~300ms at 30fps
            let alpha = min(1.0, CGFloat(fadeProgress))
            currentHeight = 2 + (targetHeight - 2) * min(1.0, fadeProgress * 2)
            phase += 0.016
            if phase >= 1.0 { phase -= 1.0 }

            for window in windows { window.alphaValue = alpha }

            if fadeProgress >= 1.0 {
                fadeStage = .flowing
                fadeProgress = 0
            }

        case .flowing:
            phase += 0.016
            if phase >= 1.0 { phase -= 1.0 }
            let breath = sin(fadeProgress * .pi * 2) * 0.5
            currentHeight = targetHeight + CGFloat(breath)
            fadeProgress += 1.0 / 120.0
            if fadeProgress >= 1.0 { fadeProgress = 0 }
        }

        for window in windows {
            window.drawRainbow(phase: phase, barHeight: currentHeight)
        }
    }
}

// MARK: - Single Screen Window

final class RainbowOverlayWindow: NSWindow {
    private let cachedGradient: CGGradient?
    private let cachedGlowGradient: CGGradient?

    init(for screen: NSScreen, targetHeight: CGFloat) {
        // Pre-create gradients (cached, never reallocated)
        let spectrum: [CGColor] = [
            NSColor(red: 1.0, green: 0.2, blue: 0.3, alpha: 1).cgColor,
            NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1).cgColor,
            NSColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 1).cgColor,
            NSColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1).cgColor,
            NSColor(red: 0.2, green: 0.8, blue: 0.9, alpha: 1).cgColor,
            NSColor(red: 0.3, green: 0.4, blue: 1.0, alpha: 1).cgColor,
            NSColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1).cgColor,
        ]
        var colors: [CGColor] = []
        colors.append(contentsOf: spectrum)
        colors.append(contentsOf: spectrum)
        colors.append(spectrum[0])

        let colorCount = colors.count
        let locations: [CGFloat] = (0..<colorCount).map {
            CGFloat($0) / CGFloat(colorCount - 1)
        }
        cachedGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: locations
        )

        let glowColors: [CGColor] = [
            NSColor.white.withAlphaComponent(0.3).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        cachedGlowGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: glowColors as CFArray,
            locations: [0.0, 1.0]
        )

        let visibleFrame = screen.visibleFrame
        let screenFrame = screen.frame
        let menuBarBottom = visibleFrame.maxY

        let frame = NSRect(
            x: screenFrame.origin.x,
            y: menuBarBottom - targetHeight,
            width: screenFrame.width,
            height: targetHeight + 4
        )

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.level = .statusBar
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenNone]
        self.alphaValue = 0
        self.contentView?.wantsLayer = true
    }

    func drawRainbow(phase: CGFloat, barHeight: CGFloat) {
        guard let layer = contentView?.layer,
              let gradient = cachedGradient else { return }

        let width = frame.width
        let height = barHeight

        let image = NSImage(size: NSSize(width: width, height: frame.height), flipped: true) { [weak self] rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            // Rainbow bar
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: width, height: height))
            let offset = phase * width
            let span = width * 2
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: -offset, y: 0),
                end: CGPoint(x: span - offset, y: 0),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            ctx.restoreGState()

            // Glow
            if let glow = self?.cachedGlowGradient {
                ctx.saveGState()
                ctx.clip(to: CGRect(x: 0, y: height, width: width, height: 4))
                ctx.drawLinearGradient(
                    glow,
                    start: CGPoint(x: 0, y: height),
                    end: CGPoint(x: 0, y: height + 4),
                    options: []
                )
                ctx.restoreGState()
            }

            return true
        }

        layer.contents = image
    }
}
