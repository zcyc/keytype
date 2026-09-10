# KeyType

Native macOS menu bar app for secure credential Auto-Type.

> 简体中文：[README.zh-CN.md](README.zh-CN.md)

KeyType stores credential metadata and passwords in separate macOS login Keychain items. Browsing the picker never reads password data; a password is fetched only when an Auto-Type sequence needs it.

## Requirements

- macOS 13 or later
- Swift 6 toolchain
- Full Xcode is required for XCTest

## Quick start

Install to `~/Applications/KeyType.app`:

```sh
make install
```

Install to another directory:

```sh
make install INSTALL_DIR=/Applications
```

Install and launch:

```sh
make run
```

Select a specific Xcode installation when needed:

```sh
make install DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

The Makefile uses the checked-in `KeyType.xcodeproj` when full Xcode is available. Without full Xcode, it builds the SwiftPM executable, assembles a minimal app bundle, and signs it ad hoc for local use.

Useful targets:

```sh
make build    # Build build/KeyType.app
make install  # Install the app
make run      # Install and launch the app
make test     # Run XCTest; requires full Xcode
make clean    # Remove build artifacts
```

## Signing and Launch at Login

The app uses `SMAppService.mainApp` for Launch at Login. The Makefile signs the app ad hoc (`CODE_SIGN_IDENTITY=-`), which is the intended way to run KeyType locally. Run `make install`, then launch `~/Applications/KeyType.app`.

## Permissions

App Sandbox is intentionally disabled in `KeyType/Support/KeyType.entitlements`. Auto-Type requires user-approved Accessibility access:

**System Settings → Privacy & Security → Accessibility**

KeyType requests this permission only when needed. It uses Accessibility APIs to inspect the focused window, installs a global `CGEventTap`, and posts keyboard events. The app has no network capability.

## Security decisions

- Metadata and passwords are separate `kSecClassGenericPassword` items under `com.keytype.app.metadata` and `com.keytype.app.password`.
- Both items use the credential UUID as `kSecAttrAccount` and are stored in the user's login Keychain.
- The login Keychain protects items with the user's macOS account; this ad-hoc build does not synchronize credentials across devices.
- Passwords are fetched only while executing `{PASSWORD}`. They are not kept in picker state, UserDefaults, SwiftData, logs, or the clipboard.
- Writes use `SecItemUpdate`; create and update failures roll back the related Keychain item when possible.
- The picker records the target process before authentication, restores it afterward, and aborts if the frontmost process changed before typing.
- Auto-Type is one cancellable task. A second trigger is ignored while it is active, and Escape requests cancellation when global event monitoring is available.

## Current limitations

- The global hotkey defaults to `⌥⌘K` and can be changed in Settings. The selected combination is consumed by KeyType so it does not reach the active app.
- Matching uses a simple window-title rule plus ranking.
- The picker requires Return confirmation.
- Unicode input uses `CGEvent.keyboardSetUnicodeString`; applications that ignore Unicode payloads or enforce their own input method may behave differently.
- There is no browser extension, clipboard transport, Passwords.app extraction, telemetry, external network request, TOTP, passkey, shell execution, or private API.

## Manual verification

After launching the app and granting Accessibility access, verify:

1. Add `prod-db-01`, username `root`, a password, and `{USERNAME}{ENTER}{DELAY 500}{PASSWORD}{ENTER}`. Quit and reopen the app; metadata should remain available.
2. At `login:` in Terminal.app or a Web Terminal, press the configured shortcut (default `⌥⌘K`), select the credential, authenticate, and verify username → Return → 500 ms → password → Return.
3. In a normal login form, use `{USERNAME}{TAB}{PASSWORD}{ENTER}`.
4. In Settings, click the hotkey button and record another modifier + key combination; verify it persists after restart and does not trigger browser actions. Also test Safari, Chrome, iTerm2, xterm.js/Guacamole, special-character and Unicode passwords, Escape, repeated hotkeys, target switching, revoked Accessibility access, failed or cancelled authentication, missing Keychain passwords, and deleted credentials.
5. Confirm the clipboard is unchanged before and after every run.

Unit tests are in `Tests/KeyTypeCoreTests`. Run them with Xcode because XCTest is not provided by the Command Line Tools-only setup used for the SwiftPM fallback.
