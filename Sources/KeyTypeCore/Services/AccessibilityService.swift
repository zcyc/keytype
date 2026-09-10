import AppKit
import ApplicationServices

public final class AccessibilityService: Sendable {
    public init() {}

    public var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public func requestPermissionPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    public func captureTarget() -> AutoTypeTarget? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        var windowValue: CFTypeRef?
        let axApplication = AXUIElementCreateApplication(application.processIdentifier)
        let windowStatus = AXUIElementCopyAttributeValue(axApplication, kAXFocusedWindowAttribute as CFString, &windowValue)
        var windowTitle: String?
        if windowStatus == .success,
           let windowValue,
           CFGetTypeID(windowValue) == AXUIElementGetTypeID() {
            let window = unsafeBitCast(windowValue, to: AXUIElement.self)
            var titleValue: CFTypeRef?
            let titleStatus = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            if titleStatus == .success { windowTitle = titleValue as? String }
        }

        return AutoTypeTarget(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            applicationName: application.localizedName ?? application.bundleIdentifier ?? "Unknown Application",
            windowTitle: windowTitle
        )
    }

    public func activate(_ target: AutoTypeTarget) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: target.processIdentifier), !application.isTerminated else { return false }
        return application.activate(options: [.activateIgnoringOtherApps])
    }

    public func isFrontmost(_ target: AutoTypeTarget) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
    }
}
