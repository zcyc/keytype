import Carbon.HIToolbox
import CoreGraphics
import Foundation

public struct GlobalHotkey: Equatable {
    public let keyCode: CGKeyCode
    public let requiredFlags: CGEventFlags
    public let keyLabel: String

    public init(keyCode: CGKeyCode, requiredFlags: CGEventFlags, keyLabel: String) {
        self.keyCode = keyCode
        self.requiredFlags = requiredFlags
        self.keyLabel = keyLabel
    }

    public var displayString: String {
        var result = ""
        if requiredFlags.contains(.maskControl) { result += "⌃" }
        if requiredFlags.contains(.maskAlternate) { result += "⌥" }
        if requiredFlags.contains(.maskShift) { result += "⇧" }
        if requiredFlags.contains(.maskCommand) { result += "⌘" }
        return result + keyLabel
    }
}

@MainActor
public final class GlobalHotkeyService {
    public var onPress: (() -> Void)?
    public private(set) var hotkey: GlobalHotkey

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    private static let defaultsKey = "globalHotkey"
    private static let hotKeySignature = OSType(0x4B545950)
    private static let hotKeyID = UInt32(1)
    private static let supportedFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
    public static let defaultHotkey = GlobalHotkey(
        keyCode: 40,
        requiredFlags: [.maskAlternate, .maskCommand],
        keyLabel: "K"
    )

    public init() {
        hotkey = Self.loadHotkey()
    }

    public func setHotkey(_ newHotkey: GlobalHotkey) {
        guard newHotkey.keyCode <= 127,
              !newHotkey.requiredFlags.isEmpty,
              newHotkey.requiredFlags.intersection(Self.supportedFlags) == newHotkey.requiredFlags else { return }
        hotkey = newHotkey
        UserDefaults.standard.set([
            "keyCode": Int(newHotkey.keyCode),
            "flags": newHotkey.requiredFlags.rawValue,
            "keyLabel": newHotkey.keyLabel
        ], forKey: Self.defaultsKey)
    }

    public func resetHotkey() {
        setHotkey(Self.defaultHotkey)
    }

    public func start() -> Bool {
        guard hotKeyRef == nil else { return true }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        var handler: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.callback,
            1,
            &eventType,
            context,
            &handler
        )
        guard installStatus == noErr, let handler else { return false }

        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyID)
        var registeredHotKey: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            Self.carbonModifiers(for: hotkey.requiredFlags),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &registeredHotKey
        )
        guard registerStatus == noErr, let registeredHotKey else {
            RemoveEventHandler(handler)
            return false
        }

        eventHandler = handler
        hotKeyRef = registeredHotKey
        return true
    }

    public func stop() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKeyRef = nil
        eventHandler = nil
    }

    private static let callback: EventHandlerUPP = { _, event, userInfo in
        guard let userInfo, let event else { return noErr }
        let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userInfo).takeUnretainedValue()

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr,
              hotKeyID.signature == GlobalHotkeyService.hotKeySignature,
              hotKeyID.id == GlobalHotkeyService.hotKeyID else { return noErr }

        service.onPress?()
        return noErr
    }

    private static func carbonModifiers(for flags: CGEventFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.maskCommand) { result |= UInt32(cmdKey) }
        if flags.contains(.maskAlternate) { result |= UInt32(optionKey) }
        if flags.contains(.maskControl) { result |= UInt32(controlKey) }
        if flags.contains(.maskShift) { result |= UInt32(shiftKey) }
        return result
    }

    private static func loadHotkey() -> GlobalHotkey {
        guard let saved = UserDefaults.standard.dictionary(forKey: defaultsKey),
              let keyCode = saved["keyCode"] as? NSNumber,
              let flags = saved["flags"] as? NSNumber,
              let keyLabel = saved["keyLabel"] as? String else { return defaultHotkey }
        let candidate = GlobalHotkey(
            keyCode: CGKeyCode(keyCode.uint16Value),
            requiredFlags: CGEventFlags(rawValue: flags.uint64Value),
            keyLabel: keyLabel
        )
        guard candidate.keyCode <= 127,
              !candidate.requiredFlags.isEmpty,
              candidate.requiredFlags.intersection(supportedFlags) == candidate.requiredFlags,
              !candidate.keyLabel.isEmpty else { return defaultHotkey }
        return candidate
    }
}
