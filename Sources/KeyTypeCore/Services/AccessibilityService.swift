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

        let window = focusedWindow(of: application.processIdentifier)
        let windowTitle: String?
        if let window {
            var titleValue: CFTypeRef?
            let titleStatus = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            windowTitle = titleStatus == .success ? titleValue as? String : nil
        } else {
            windowTitle = nil
        }

        return AutoTypeTarget(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            applicationName: application.localizedName ?? application.bundleIdentifier ?? "Unknown Application",
            windowTitle: windowTitle,
            windowElement: window
        )
    }

    public func activate(_ target: AutoTypeTarget) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: target.processIdentifier),
              !application.isTerminated,
              isSameApplication(application, as: target) else { return false }
        return application.activate(options: [.activateIgnoringOtherApps])
    }

    public func isFrontmost(_ target: AutoTypeTarget) -> Bool {
        guard let application = NSWorkspace.shared.frontmostApplication,
              isSameApplication(application, as: target) else { return false }
        guard let targetWindow = target.windowElement else { return true }
        guard let focusedWindow = focusedWindow(of: target.processIdentifier) else { return false }
        return CFEqual(targetWindow, focusedWindow)
    }

    private func focusedWindow(of processIdentifier: pid_t) -> AXUIElement? {
        var windowValue: CFTypeRef?
        let application = AXUIElementCreateApplication(processIdentifier)
        guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let windowValue,
              CFGetTypeID(windowValue) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(windowValue, to: AXUIElement.self)
    }

    private func isSameApplication(_ application: NSRunningApplication, as target: AutoTypeTarget) -> Bool {
        guard application.processIdentifier == target.processIdentifier else { return false }
        if let bundleIdentifier = target.bundleIdentifier {
            return application.bundleIdentifier == bundleIdentifier
        }
        return application.localizedName == target.applicationName
    }
}
