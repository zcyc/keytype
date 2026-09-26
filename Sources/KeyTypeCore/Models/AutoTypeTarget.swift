import ApplicationServices
import Foundation

public struct AutoTypeTarget: @unchecked Sendable, Equatable {
    public let processIdentifier: pid_t
    public let bundleIdentifier: String?
    public let applicationName: String
    public let windowTitle: String?
    // Retain the AX proxy as an opaque window identity and compare it with CFEqual.
    let windowElement: AXUIElement?

    public init(
        processIdentifier: pid_t,
        bundleIdentifier: String?,
        applicationName: String,
        windowTitle: String?,
        windowElement: AXUIElement? = nil
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.windowElement = windowElement
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.processIdentifier == rhs.processIdentifier,
              lhs.bundleIdentifier == rhs.bundleIdentifier,
              lhs.applicationName == rhs.applicationName,
              lhs.windowTitle == rhs.windowTitle else { return false }
        switch (lhs.windowElement, rhs.windowElement) {
        case (nil, nil): return true
        case let (left?, right?): return CFEqual(left, right)
        default: return false
        }
    }
}
