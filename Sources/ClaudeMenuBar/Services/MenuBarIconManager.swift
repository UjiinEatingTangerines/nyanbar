import AppKit
import SwiftUI

@MainActor
final class MenuBarIconManager {
    private let statusItem: NSStatusItem
    private var animationTimer: Timer?
    private var phase: CGFloat = 0
    private var rainbowPhase: CGFloat = 0
    private(set) var isShowingRainbow = false

    // Yawn state
    private var yawnProgress: CGFloat = 0       // 0 = none, 0→1 = yawning
    private var yawnCooldown: CGFloat = 0       // ticks until next yawn
    private var isYawning = false
    private(set) var currentState: IconState = .idle

    // Spinner (language-aware)
    private var spinnerIndex: Int = Int.random(in: 0..<30)
    private var spinnerTickCount: CGFloat = 0
    private static let spinnerInterval: CGFloat = 200 // ticks (10 sec at 20fps)
    private weak var settings: SettingsStore?

    private var spinnerMessages: [String] {
        let builtIn = (settings?.selectedLanguage ?? .korean).spinnerMessages
        let custom = settings?.enabledCustomMessages ?? []
        return custom.isEmpty ? builtIn : builtIn + custom
    }
    private var language: AppLanguage {
        settings?.selectedLanguage ?? .korean
    }
    private var isSleepMode: Bool {
        settings?.sleepMode ?? false
    }
    private var catColor: NSColor? {
        guard let hex = settings?.catColorHex else { return nil }
        return NSColor(hex: hex)
    }

    // MARK: - Frame Cache
    //
    // The icon redraws at 3–5 fps for hours at a time. Re-rendering ~10
    // NSBezierPath fills + strokes on every tick is the dominant CPU cost.
    // We quantize (color, swing, yawn) and memoize a baked NSBitmapImageRep
    // so subsequent ticks just hand the menu bar an already-rasterized image.
    //
    // We also remember the last image key per instance so we skip updating
    // the status item when the bucket hasn't changed (huge win at low fps).
    nonisolated private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 600       // ~per-color × swing × yawn buckets
        cache.totalCostLimit = 8 * 1024 * 1024  // 8 MB hard cap
        return cache
    }()
    private var lastImageKey: NSString?

    nonisolated private static func cacheKey(color: NSColor?, swing: CGFloat, yawn: CGFloat) -> NSString {
        let colorPart: String
        if let c = color, let rgb = c.usingColorSpace(.sRGB) {
            let r = Int((rgb.redComponent * 255).rounded())
            let g = Int((rgb.greenComponent * 255).rounded())
            let b = Int((rgb.blueComponent * 255).rounded())
            colorPart = "\(r),\(g),\(b)"
        } else {
            colorPart = "sys"
        }
        // Quantize swing into 0.05 buckets (range roughly [-1, 1] → 41 values).
        let swingBucket = Int((swing * 20).rounded())
        // Yawn is 0 most of the time; quantize to 10 buckets when active.
        let yawnBucket = yawn > 0 ? Int((yawn * 10).rounded()) : 0
        return "\(colorPart)|\(swingBucket)|\(yawnBucket)" as NSString
    }

    /// Returns a cached, pre-rasterized cat image for the given parameters.
    /// Falls back to on-the-fly rendering when bitmap allocation fails.
    nonisolated private static func cachedCatLoaf(tailSwing: CGFloat, yawn: CGFloat, customColor: NSColor?) -> NSImage {
        let key = cacheKey(color: customColor, swing: tailSwing, yawn: yawn)
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        let img = renderCatLoafBitmap(tailSwing: tailSwing, yawn: yawn, customColor: customColor)
        // Approximate cost: width × height × 4 bytes × 2× backing scale (≈6 KB).
        let cost = Int(catSize.width * catSize.height * 4 * 4)
        imageCache.setObject(img, forKey: key, cost: cost)
        return img
    }

    /// Render the cat into an NSBitmapImageRep so the cached NSImage owns a
    /// real bitmap (instead of a deferred drawing handler that re-runs each
    /// time the image is drawn).
    nonisolated private static func renderCatLoafBitmap(tailSwing: CGFloat, yawn: CGFloat, customColor: NSColor?) -> NSImage {
        let scale: CGFloat = 2.0  // retina baseline
        let pixelW = Int((catSize.width * scale).rounded())
        let pixelH = Int((catSize.height * scale).rounded())
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelW,
            pixelsHigh: pixelH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pixelW * 4,
            bitsPerPixel: 32
        ) else {
            return createCatLoaf(tailSwing: tailSwing, yawn: yawn, customColor: customColor)
        }
        rep.size = catSize  // logical points

        let drawColor = customColor ?? .black
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            drawCatLoafSilhouette(
                in: NSRect(origin: .zero, size: catSize),
                tailSwing: tailSwing, yawn: yawn, color: drawColor
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        let img = NSImage(size: catSize)
        img.addRepresentation(rep)
        img.isTemplate = (customColor == nil)
        return img
    }

    nonisolated private static let iconRainbowGradient: CGGradient? = {
        let spectrum: [CGColor] = [
            NSColor(red: 1.0, green: 0.25, blue: 0.35, alpha: 1).cgColor,
            NSColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1).cgColor,
            NSColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 1).cgColor,
            NSColor(red: 0.25, green: 0.9, blue: 0.45, alpha: 1).cgColor,
            NSColor(red: 0.2, green: 0.75, blue: 1.0, alpha: 1).cgColor,
            NSColor(red: 0.4, green: 0.4, blue: 1.0, alpha: 1).cgColor,
            NSColor(red: 0.7, green: 0.35, blue: 0.95, alpha: 1).cgColor,
        ]
        var colors: [CGColor] = []
        colors.append(contentsOf: spectrum)
        colors.append(contentsOf: spectrum)
        colors.append(spectrum[0])
        let n = colors.count
        let locs: [CGFloat] = (0..<n).map { CGFloat($0) / CGFloat(n - 1) }
        return CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray, locations: locs
        )
    }()

    enum IconState: Equatable {
        case idle
        case working(projectName: String)
        case pending(projectName: String)
        case completed
        case healthCheckDone  // brief yellow→green flash
    }

    init(statusItem: NSStatusItem, settings: SettingsStore? = nil) {
        self.statusItem = statusItem
        self.settings = settings
        if let button = statusItem.button {
            button.imagePosition = .imageLeading
        }
        update(state: .idle)
    }

    func update(state: IconState) {
        stopAnimation()
        statusItem.button?.alphaValue = 1.0  // Reset from pending pulse
        lastImageKey = nil  // force first frame after a state change
        currentState = state

        switch state {
        case .idle:
            isShowingRainbow = false
            if isSleepMode {
                startSleepAnimation()
            } else {
                scheduleNextYawn()
                startIdleAnimation()
            }

        case .working(let projectName):
            isShowingRainbow = false
            scheduleNextYawn()
            startWorkingAnimation()
            setFixedTitle(truncate(projectName, maxLength: Self.titleFixedLength))

        case .pending(let projectName):
            isShowingRainbow = false
            startPendingAnimation()
            setFixedTitle("\(language.pendingPrefix) \(truncate(projectName, maxLength: Self.titleFixedLength - 6))")

        case .completed:
            isShowingRainbow = true
            startRainbowAnimation()
            setFixedTitle(language.doneText)

        case .healthCheckDone:
            isShowingRainbow = false
            startHealthCheckFlash()
            setFixedTitle(language.healthCheckTitle)
        }
    }

    func dismissRainbow() {
        isShowingRainbow = false
        stopAnimation()
    }

    // MARK: - Yawn scheduling (3~5 second random intervals)

    private func scheduleNextYawn() {
        // Random cooldown: 3~5 seconds at 20fps = 60~100 ticks
        yawnCooldown = CGFloat.random(in: 60...100)
        isYawning = false
        yawnProgress = 0
    }

    private func tickYawn() {
        if isYawning {
            yawnProgress += 0.06  // ~0.8 sec animation at 20fps
            if yawnProgress >= 1.0 {
                isYawning = false
                yawnProgress = 0
                scheduleNextYawn()
            }
        } else {
            yawnCooldown -= 1
            if yawnCooldown <= 0 {
                isYawning = true
                yawnProgress = 0
            }
        }
    }

    // MARK: - Cat Loaf (식빵고양이)
    //
    // Reference: Purina, Hill's Pet, how2drawanimals.com
    // Key proportions:
    //   - Head:Body ≈ 1:2
    //   - Body = rounded rectangle, flat bottom, dome top (like bread 🍞)
    //   - Head sits directly on body (minimal neck)
    //   - Two triangle ears on head top
    //   - No legs visible, tail wraps from behind
    //
    // Side view (most recognizable at 18px):
    //
    //        /\  /\
    //       ( head )      ← circle, ~40% of total height
    //     ___\____/___
    //    /            \   ← loaf body, flat bottom
    //   |              |     dome top, ~55% of width
    //   |______________|
    //               ~~    ← tail from back

    // Fixed size — extra width to accommodate tail animation without jitter
    nonisolated private static let catSize = NSSize(width: 22, height: 18)

    /// Determine if a color is "light" (needs dark eyes)
    nonisolated private static func isLightColor(_ color: NSColor) -> Bool {
        guard let rgb = color.usingColorSpace(.sRGB) else { return false }
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance > 0.6
    }

    nonisolated private static func drawCatLoafSilhouette(
        in rect: NSRect,
        tailSwing: CGFloat,
        yawn: CGFloat,
        color: NSColor
    ) {
        let w = rect.width
        let h = rect.height
        color.setFill()
        color.setStroke()

        // Ground
        let ground = h * 0.05

        // === LOAF BODY: rounded rect, flat bottom, dome top ===
        // Body is the dominant shape — about 60% of width, 35% of height
        let bw = w * 0.62
        let bh = h * 0.35
        let bx = (w - bw) / 2 - w * 0.05  // slightly left to leave room for tail
        let by = ground

        let body = NSBezierPath(
            roundedRect: NSRect(x: bx, y: by, width: bw, height: bh),
            xRadius: bw * 0.2,
            yRadius: bh * 0.5  // more round on top, flatter on bottom
        )
        body.fill()
        // Extra flat bottom: fill a rect to square off the bottom corners
        NSBezierPath(rect: NSRect(x: bx, y: by, width: bw, height: bh * 0.35)).fill()

        // === HEAD: circle, sitting on body, center-left ===
        // Head is about half the body width
        let hr = w * 0.2  // head radius
        let hcx = bx + bw * 0.35  // center of head X
        let hcy = by + bh + hr * 0.4  // head overlaps body top slightly

        NSBezierPath(ovalIn: NSRect(
            x: hcx - hr, y: hcy - hr, width: hr * 2, height: hr * 2
        )).fill()

        // Fill the gap between head and body (neck area)
        let neck = NSBezierPath()
        neck.move(to: NSPoint(x: hcx - hr * 0.6, y: by + bh - 1))
        neck.line(to: NSPoint(x: hcx + hr * 0.6, y: by + bh - 1))
        neck.line(to: NSPoint(x: hcx + hr * 0.5, y: hcy - hr * 0.3))
        neck.line(to: NSPoint(x: hcx - hr * 0.5, y: hcy - hr * 0.3))
        neck.close()
        neck.fill()

        // === EARS: two solid triangles ===
        let earH = h * 0.2
        let earW = hr * 0.55

        // Left ear
        let le = NSBezierPath()
        le.move(to: NSPoint(x: hcx - hr * 0.6, y: hcy + hr * 0.5))
        le.line(to: NSPoint(x: hcx - hr * 0.35, y: hcy + hr * 0.5 + earH))
        le.line(to: NSPoint(x: hcx - hr * 0.6 + earW, y: hcy + hr * 0.75))
        le.close()
        le.fill()

        // Right ear
        let re = NSBezierPath()
        re.move(to: NSPoint(x: hcx + hr * 0.6, y: hcy + hr * 0.5))
        re.line(to: NSPoint(x: hcx + hr * 0.35, y: hcy + hr * 0.5 + earH))
        re.line(to: NSPoint(x: hcx + hr * 0.6 - earW, y: hcy + hr * 0.75))
        re.close()
        re.fill()

        // === TAIL: from right back, curves up (S-sway) ===
        let s = tailSwing
        let tail = NSBezierPath()
        let tx = bx + bw - w * 0.02
        let ty = by + bh * 0.35

        // Segment 1
        let p1x = tx + w * 0.1 + w * 0.04 * s
        let p1y = ty + h * 0.15
        tail.move(to: NSPoint(x: tx, y: ty))
        tail.curve(
            to: NSPoint(x: p1x, y: p1y),
            controlPoint1: NSPoint(x: tx + w * 0.07, y: ty),
            controlPoint2: NSPoint(x: p1x, y: p1y - h * 0.06)
        )
        // Segment 2 (S reverse)
        let p2x = p1x - w * 0.02 - w * 0.06 * s
        let p2y = p1y + h * 0.14
        tail.curve(
            to: NSPoint(x: p2x, y: p2y),
            controlPoint1: NSPoint(x: p1x + w * 0.04 + w * 0.03 * s, y: p1y + h * 0.05),
            controlPoint2: NSPoint(x: p2x + w * 0.02, y: p2y - h * 0.04)
        )
        // Tip
        let p3x = p2x + w * 0.02 + w * 0.03 * s
        let p3y = p2y + h * 0.08
        tail.curve(
            to: NSPoint(x: p3x, y: p3y),
            controlPoint1: NSPoint(x: p2x - w * 0.01 * s, y: p2y + h * 0.03),
            controlPoint2: NSPoint(x: p3x, y: p3y - h * 0.01)
        )
        tail.lineWidth = w * 0.08
        tail.lineCapStyle = .round
        tail.stroke()

        // === EYES (dark for light cats, white for dark cats) ===
        let eS = w * 0.065
        let eyeColor: NSColor = isLightColor(color) ? .black : .white
        eyeColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: hcx - hr * 0.42, y: hcy - eS * 0.3, width: eS, height: eS)).fill()
        NSBezierPath(ovalIn: NSRect(x: hcx + hr * 0.18, y: hcy - eS * 0.3, width: eS, height: eS)).fill()

        // === YAWN ===
        if yawn > 0 {
            drawYawnBurst(in: rect, cx: hcx - hr * 1.2, cy: hcy - hr * 0.2,
                          progress: yawn, color: color)
        }
    }

    nonisolated private static func drawYawnBurst(
        in rect: NSRect, cx: CGFloat, cy: CGFloat,
        progress: CGFloat, color: NSColor
    ) {
        let w = rect.width
        let alpha: CGFloat
        if progress < 0.25 { alpha = progress / 0.25 }
        else if progress < 0.55 { alpha = 1.0 }
        else { alpha = 1.0 - (progress - 0.55) / 0.45 }

        let maxLen = w * 0.15
        let rayLen = progress < 0.5
            ? maxLen * (progress / 0.5)
            : maxLen * (1.0 - (progress - 0.5) / 0.5)

        color.withAlphaComponent(alpha * 0.6).setStroke()
        let angles: [CGFloat] = [2.6, 2.85, 3.14, 3.43, 3.68]

        for (i, angle) in angles.enumerated() {
            let stagger = CGFloat(i) * 0.03
            let lp = max(0, min(1, (progress - stagger) / 0.85))
            let ll = rayLen * lp
            guard ll > 0.4 else { continue }
            let gap = w * 0.015
            let ray = NSBezierPath()
            ray.move(to: NSPoint(x: cx + cos(angle) * gap, y: cy + sin(angle) * gap))
            ray.line(to: NSPoint(x: cx + cos(angle) * (gap + ll), y: cy + sin(angle) * (gap + ll)))
            ray.lineWidth = w * 0.03
            ray.lineCapStyle = .round
            ray.stroke()
        }
    }

    nonisolated private static func drawWhiteEyes(in rect: NSRect) {
        let w = rect.width, h = rect.height
        let ground = h * 0.05
        let bw = w * 0.62
        let bx = (w - bw) / 2 - w * 0.05
        let bh = h * 0.35
        let by = ground
        let hr = w * 0.2
        let hcx = bx + bw * 0.35
        let hcy = by + bh + hr * 0.4
        let eS = w * 0.065
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: hcx - hr * 0.42, y: hcy - eS * 0.3, width: eS, height: eS)).fill()
        NSBezierPath(ovalIn: NSRect(x: hcx + hr * 0.18, y: hcy - eS * 0.3, width: eS, height: eS)).fill()
    }

    // MARK: - Image Creation

    nonisolated private static func createCatLoaf(tailSwing: CGFloat = 0, yawn: CGFloat = 0, customColor: NSColor? = nil) -> NSImage {
        let drawColor = customColor ?? .black
        let img = NSImage(size: catSize, flipped: false) { rect in
            drawCatLoafSilhouette(in: rect, tailSwing: tailSwing, yawn: yawn, color: drawColor)
            return true
        }
        img.isTemplate = (customColor == nil)  // template only when using system color
        return img
    }

    nonisolated private static func createRainbowCatLoaf(
        phase: CGFloat, tailSwing: CGFloat, yawn: CGFloat = 0
    ) -> NSImage {
        let img = NSImage(size: catSize, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext,
                  let gradient = iconRainbowGradient else { return false }

            let mask = NSImage(size: catSize, flipped: false) { mr in
                drawCatLoafSilhouette(in: mr, tailSwing: tailSwing, yawn: yawn, color: .black)
                return true
            }
            guard let maskCG = mask.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return false
            }

            ctx.saveGState()
            ctx.clip(to: rect, mask: maskCG)
            let offset = phase * rect.width
            let span = rect.width * 2
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: -offset, y: 0),
                end: CGPoint(x: span - offset, y: rect.height),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            ctx.restoreGState()

            drawWhiteEyes(in: rect)
            return true
        }
        img.isTemplate = false
        return img
    }

    // MARK: - Animations

    /// Idle: slow gentle tail sway + periodic yawn + spinner message
    private func startIdleAnimation() {
        phase = 0
        spinnerTickCount = 0
        lastImageKey = nil
        setFixedTitle(currentSpinnerMessage)
        // Idle: 0.3s interval (~3fps) — very low CPU, tail barely moves
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.phase += 0.08
                if self.phase > .pi * 2 { self.phase -= .pi * 2 }
                self.tickYawn()
                self.tickSpinner()

                let swing = sin(self.phase) * 0.4 + sin(self.phase * 1.8) * 0.2
                self.applyCatImage(swing: swing, yawn: self.yawnProgress)
            }
        }
    }

    /// Sleep mode: very slow breathing, no yawn, sleeping text
    private func startSleepAnimation() {
        phase = 0
        setFixedTitle("💤 zzZ...")
        let img = Self.createCatLoaf(customColor: catColor)
        statusItem.button?.image = img
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.phase += 0.02
                if self.phase > .pi * 2 { self.phase -= .pi * 2 }
                // Very slow, gentle breathing opacity
                let breath = 0.7 + 0.3 * sin(self.phase)
                self.statusItem.button?.alphaValue = CGFloat(breath)
            }
        }
    }

    /// Working: active tail sway + periodic yawn
    private func startWorkingAnimation() {
        phase = 0
        lastImageKey = nil
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.phase += 0.08
                if self.phase > .pi * 2 { self.phase -= .pi * 2 }
                self.tickYawn()

                let swing = sin(self.phase) * 0.7 + sin(self.phase * 2.3) * 0.3
                self.applyCatImage(swing: swing, yawn: self.yawnProgress)
            }
        }
    }

    /// Pending: slow pulse (opacity blink) + gentle tail — keeps template mode
    private func startPendingAnimation() {
        phase = 0
        lastImageKey = nil
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.phase += 0.05
                if self.phase > .pi * 2 { self.phase -= .pi * 2 }

                let swing = sin(self.phase * 0.8) * 0.3
                let pulse = 0.75 + 0.25 * sin(self.phase * 1.5)

                self.applyCatImage(swing: swing, yawn: 0)
                self.statusItem.button?.alphaValue = CGFloat(pulse)
            }
        }
    }

    /// Completed: rainbow + tail sway
    private func startRainbowAnimation() {
        rainbowPhase = 0
        phase = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.rainbowPhase += 0.012
                if self.rainbowPhase >= 1.0 { self.rainbowPhase -= 1.0 }
                self.phase += 0.06
                if self.phase > .pi * 2 { self.phase -= .pi * 2 }

                let swing = sin(self.phase) * 0.6 + sin(self.phase * 1.7) * 0.4
                self.statusItem.button?.image = Self.createRainbowCatLoaf(
                    phase: self.rainbowPhase, tailSwing: swing
                )
            }
        }
    }

    /// Health check done: yellow→green gradient flash for 3 seconds, then revert
    private func startHealthCheckFlash() {
        phase = 0
        var elapsed: CGFloat = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.phase += 0.04
                if self.phase > .pi * 2 { self.phase -= .pi * 2 }
                elapsed += 0.05

                let swing = sin(self.phase) * 0.3
                let img = Self.createHealthCheckCatLoaf(progress: elapsed / 3.0, tailSwing: swing)
                self.statusItem.button?.image = img

                // After 3 seconds, revert to idle with spinner
                if elapsed >= 3.0 {
                    self.stopAnimation()
                    self.currentState = .idle
                    self.scheduleNextYawn()
                    self.spinnerTickCount = 0
                    self.setFixedTitle(self.currentSpinnerMessage)
                    self.startIdleAnimation()
                }
            }
        }
    }

    /// Yellow → Green gradient cat for health check flash
    nonisolated private static func createHealthCheckCatLoaf(progress: CGFloat, tailSwing: CGFloat) -> NSImage {
        let img = NSImage(size: catSize, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let mask = NSImage(size: catSize, flipped: false) { mr in
                drawCatLoafSilhouette(in: mr, tailSwing: tailSwing, yawn: 0, color: .black)
                return true
            }
            guard let maskCG = mask.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return false
            }

            // Gradient: yellow → green, blending based on progress
            let yellow = NSColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 1)
            let green = NSColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1)

            // Shift colors from yellow-dominant to green-dominant
            let p = min(1.0, progress)
            let c1 = blend(yellow, green, amount: p * 0.5)
            let c2 = blend(yellow, green, amount: 0.3 + p * 0.7)

            let colors: [CGColor] = [c1.cgColor, c2.cgColor]
            let locs: [CGFloat] = [0.0, 1.0]
            guard let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locs
            ) else { return false }

            ctx.saveGState()
            ctx.clip(to: rect, mask: maskCG)
            ctx.drawLinearGradient(
                grad,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: rect.width, y: rect.height),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            ctx.restoreGState()

            // White eyes
            drawWhiteEyes(in: rect)
            return true
        }
        img.isTemplate = false
        return img
    }

    nonisolated private static func blend(_ c1: NSColor, _ c2: NSColor, amount: CGFloat) -> NSColor {
        let a = min(1.0, max(0.0, amount))
        let r1 = c1.redComponent, g1 = c1.greenComponent, b1 = c1.blueComponent
        let r2 = c2.redComponent, g2 = c2.greenComponent, b2 = c2.blueComponent
        return NSColor(
            red: r1 + (r2 - r1) * a,
            green: g1 + (g2 - g1) * a,
            blue: b1 + (b2 - b1) * a,
            alpha: 1.0
        )
    }

    // MARK: - Spinner

    // Max display width (characters) — all titles padded to this
    // Emoji takes ~2 char width, so 18 chars ≈ consistent visual width
    private static let titleFixedLength = 18

    private func tickSpinner() {
        spinnerTickCount += 1
        if spinnerTickCount >= Self.spinnerInterval {
            spinnerTickCount = 0
            let msgs = spinnerMessages
            var next = Int.random(in: 0..<msgs.count)
            if next == spinnerIndex { next = (next + 1) % msgs.count }
            spinnerIndex = next
            setFixedTitle(currentSpinnerMessage)
        }
    }

    private var currentSpinnerMessage: String {
        let msgs = spinnerMessages
        return msgs[spinnerIndex % msgs.count]
    }

    // MARK: - Helpers

    /// Set title using attributed string for better emoji rendering
    private func setFixedTitle(_ text: String) {
        guard let button = statusItem.button else { return }

        let display = " " + text.padding(toLength: Self.titleFixedLength, withPad: " ", startingAt: 0)

        let attr = NSMutableAttributedString(string: display)
        let range = NSRange(location: 0, length: attr.length)

        // Menu bar font at readable size
        attr.addAttribute(.font, value: NSFont.menuBarFont(ofSize: 12.5), range: range)

        // Baseline offset to vertically center with icon
        attr.addAttribute(.baselineOffset, value: NSNumber(value: 0.5), range: range)

        button.attributedTitle = attr
    }

    private func setTitle(_ title: String?) {
        if let title {
            setFixedTitle(title)
        } else {
            statusItem.button?.attributedTitle = NSAttributedString(string: "")
        }
    }

    private func truncate(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength { return text }
        return String(text.prefix(maxLength)) + "..."
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    /// Quantize the requested cat image and skip the menu-bar update entirely
    /// when this frame falls in the same bucket as the previous one.
    /// This is the central CPU optimization — at 3 fps the cat often stays
    /// in the same swing bucket for several ticks in a row.
    private func applyCatImage(swing: CGFloat, yawn: CGFloat) {
        let key = Self.cacheKey(color: catColor, swing: swing, yawn: yawn)
        if key == lastImageKey { return }
        statusItem.button?.image = Self.cachedCatLoaf(
            tailSwing: swing, yawn: yawn, customColor: catColor
        )
        lastImageKey = key
    }
}
