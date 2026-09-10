import Foundation

public struct AutoTypeTarget: Equatable, Sendable {
    public let processIdentifier: pid_t
    public let bundleIdentifier: String?
    public let applicationName: String
    public let windowTitle: String?

    public init(
        processIdentifier: pid_t,
        bundleIdentifier: String?,
        applicationName: String,
        windowTitle: String?
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.windowTitle = windowTitle
    }
}
