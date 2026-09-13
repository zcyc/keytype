# KeyType

<p align="center">
  <img src="docs/images/keytype-icon.png" alt="KeyType icon" width="128">
</p>

Secure credential Auto-Type for macOS, available from the menu bar.

[简体中文](README.zh-CN.md)

KeyType keeps credential metadata and passwords in separate items in the macOS login Keychain. Passwords are read only when an Auto-Type sequence needs them and are never copied to the clipboard.

## Features

- Native menu bar workflow with a keyboard-first credential picker.
- Optional window-title matching to rank the most likely credentials.
- Custom fields such as email, tenant, or OTP can be referenced from Auto-Type sequences.
- Editable Auto-Type presets and custom sequences.
- Global shortcut recording with a reset button; the shortcut is consumed by KeyType instead of the active app.
- Optional Launch at Login using macOS `SMAppService`.
- No network requests, browser extension, telemetry, or clipboard transport.

## Screenshot

### Add Credential

<p align="center">
  <img src="docs/images/add-credential.png" alt="KeyType Add Credential window" width="560">
</p>

## Requirements

- macOS 13 or later.
- `make`, Swift, and `codesign` (the macOS Command Line Tools are enough to install and run the app).
- Full Xcode is optional and is only needed for XCTest.

## Install

From the project directory, run:

```sh
make install
open ~/Applications/KeyType.app
```

`make install` builds the app, assembles the app bundle when necessary, signs it ad hoc for local use, and installs it to `~/Applications/KeyType.app`.

Useful commands:

```sh
make build                         # Build build/KeyType.app
make install                       # Build and install the app
make run                           # Build, install, and launch the app
make install INSTALL_DIR=/Applications
make test                          # Run XCTest; requires full Xcode
make clean                         # Remove build artifacts
```

When full Xcode is available, the Makefile builds `KeyType.xcodeproj`. Otherwise it uses the SwiftPM fallback and still produces the same locally signed app bundle.

## First use

1. Launch KeyType from `~/Applications/KeyType.app`.
2. Choose **Add Credential** and enter a title, username, and password. The title is also the credential’s display name.
3. Optionally set **Window title contains** to improve matching for a particular application or login page.
4. Keep the default **Password + Enter** preset, choose another preset, or edit the sequence directly.
5. Press the default shortcut `⌥⌘K`, select a credential, and press Return to start Auto-Type.

When editing an existing credential, leave the password field empty to keep the current password. Enter a new value to replace it.

## Matching and selection

When the picker opens, KeyType captures the current frontmost application and window title when macOS makes that information available. It then ranks credentials using the target window, the optional window-title rule, and the credential title.

The search field filters by credential title or username. It does not hide the other saved credentials when no search text is entered, so multiple candidates can be reviewed manually. Use ↑/↓ to select a row, Return to confirm, or Escape to cancel.

Before typing, KeyType verifies that the original target application is still frontmost. If focus changed, Auto-Type stops instead of typing into the wrong application.

## Auto-Type sequences

Sequences are made from these tokens:

| Token | Action |
| --- | --- |
| `{USERNAME}` | Type the username |
| `{PASSWORD}` | Read and type the password |
| `{FIELD:NAME}` | Type the custom field named `NAME` |
| `{TAB}` | Press Tab |
| `{ENTER}` | Press Return |
| `{DELAY 500}` | Wait 500 ms; values from 0 to 30,000 ms are supported |

Examples:

```text
{PASSWORD}{ENTER}
{USERNAME}{TAB}{PASSWORD}{ENTER}
{USERNAME}{ENTER}{DELAY 500}{PASSWORD}{ENTER}
{FIELD:EMAIL}{TAB}{PASSWORD}{ENTER}
```

Add custom fields in the credential editor. Field names use letters, numbers, and underscores and are case-insensitive; values are typed exactly as saved, including spaces. Spaces written directly in a sequence are also typed literally.

For a new credential, the preset defaults to **Password + Enter** (`{PASSWORD}{ENTER}`). Selecting a preset replaces the sequence with that preset’s value. Editing the sequence changes the preset to **Custom**.

## Keyboard shortcut

The default shortcut is `⌥⌘K`. To change it, open **Settings**, click the shortcut control, and press at least one modifier key plus a key. Use the reset icon to restore the default.

The shortcut is registered natively with macOS and is consumed by KeyType, so it should not also trigger actions such as printing in a browser. If the selected combination is already in use, choose another combination.

## Permissions and security

Auto-Type requires Accessibility access. The global shortcut and opening the picker do not require this permission.

Enable it in:

**System Settings → Privacy & Security → Accessibility**

KeyType uses Accessibility APIs to inspect the focused window, restore focus, verify the target, and send keyboard events. App Sandbox is intentionally disabled because this is a local menu bar utility.

Credentials are stored as two separate login Keychain items:

- Metadata: `com.keytype.app.metadata`
- Password: `com.keytype.app.password`

When a sequence contains `{PASSWORD}`, the password is fetched during Auto-Type preparation, before focus returns to the target app. It is not stored in picker state, UserDefaults, SwiftData, logs, or the clipboard. KeyType has no network capability.

Custom fields are stored with credential metadata in the login Keychain and are available to Auto-Type when their `{FIELD:NAME}` token is executed.

## Troubleshooting

### “Unable to identify the target application.”

Grant KeyType Accessibility access, keep the intended application frontmost, and retry. This check prevents credentials from being typed into a different application.

### The shortcut does not work

Open **Settings**, record a new modifier + key combination, and make sure no other app owns it. The reset icon restores `⌥⌘K`.

### Keychain errors

Launch the installed bundle at `~/Applications/KeyType.app` instead of a raw executable under `.build/`, then retry. KeyType stores data in the current user’s login Keychain.

## Development

```sh
make build
make test    # Requires full Xcode
make clean
```

Unit tests are in [`Tests/KeyTypeCoreTests`](Tests/KeyTypeCoreTests). A typical manual check is to add a credential, use it in Terminal or a browser login form, restart KeyType, and confirm that the credential and custom sequence remain available.
