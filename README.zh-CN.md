# KeyType

原生 macOS 菜单栏凭据自动输入应用。

KeyType 将凭据元数据与密码分别存储在 macOS 用户登录 Keychain 项目中。浏览凭据列表时不会读取密码；只有自动输入序列需要执行 `{PASSWORD}` 时才会读取密码。

## 系统要求

- macOS 13 或更高版本
- Swift 6 工具链
- 运行 XCTest 需要完整的 Xcode

## 快速开始

一键安装到 `~/Applications/KeyType.app`：

```sh
make install
```

安装到其他目录：

```sh
make install INSTALL_DIR=/Applications
```

安装并启动：

```sh
make run
```

需要指定 Xcode 路径时：

```sh
make install DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

完整 Xcode 可用时，Makefile 使用仓库中的 `KeyType.xcodeproj`。没有完整 Xcode 时，Makefile 使用 SwiftPM 构建可执行文件，组装最小 macOS App Bundle，并使用 ad-hoc 签名供本机使用。

常用目标：

```sh
make build    # 构建 build/KeyType.app
make install  # 安装应用
make run      # 安装并启动应用
make test     # 运行 XCTest，需要完整 Xcode
make clean    # 删除构建产物
```

## 签名与登录时启动

应用使用 `SMAppService.mainApp` 实现“登录时启动”。Makefile 默认使用 ad-hoc 签名（`CODE_SIGN_IDENTITY=-`），这就是本机运行 KeyType 的预期方式。执行 `make install` 后，启动 `~/Applications/KeyType.app` 即可使用。

## 权限

项目有意在 `KeyType/Support/KeyType.entitlements` 中关闭 App Sandbox。自动输入需要在以下位置手动授予辅助功能权限：

**系统设置 → 隐私与安全性 → 辅助功能**

KeyType 只在需要时请求该权限。应用通过辅助功能 API 检查当前聚焦窗口，安装全局 `CGEventTap`，并发送键盘事件。应用不包含网络能力。

## 安全设计

- 元数据和密码分别存储在 `com.keytype.app.metadata` 与 `com.keytype.app.password` 下的 `kSecClassGenericPassword` 项目中。
- 两类项目都使用凭据 UUID 作为 `kSecAttrAccount`，并存储在当前用户的登录 Keychain 中。
- 登录 Keychain 由 macOS 用户账户保护；当前 ad-hoc 版本不会在设备之间同步凭据。
- 只有执行 `{PASSWORD}` 时才读取密码。密码不会保存在列表状态、UserDefaults、SwiftData、日志或剪贴板中。
- 写入使用 `SecItemUpdate`；创建或更新失败时，会尽可能回滚相关 Keychain 项目。
- 认证前记录目标进程，认证后恢复该进程；如果输入前最前端进程发生变化，则中止自动输入。
- 自动输入使用一个可取消任务；任务执行期间会忽略第二次触发。系统支持全局事件监听时，按下 Escape 会请求取消。

## 当前限制

- 全局快捷键默认为 `⌥⌘K`，可以在“设置”中录制修改。选中的组合键会由 KeyType 消费，不会继续传递给当前应用。
- 凭据匹配目前使用简单的窗口标题规则和排序。
- 凭据选择器仍需要按 Return 确认。
- Unicode 输入使用 `CGEvent.keyboardSetUnicodeString`；忽略 Unicode payload 或使用自有输入法的应用，行为可能不同。
- 当前不包含浏览器扩展、剪贴板传输、Passwords.app 提取、遥测、外部网络请求、TOTP、Passkey、Shell 执行或私有 API。

## 手动验证

启动应用并授予辅助功能权限后，验证以下流程：

1. 添加 `prod-db-01`、用户名 `root`、密码，以及 `{USERNAME}{ENTER}{DELAY 500}{PASSWORD}{ENTER}`。退出并重新打开应用，确认元数据仍然存在。
2. 在 Terminal.app 或 Web Terminal 的 `login:` 提示符处按下已配置的快捷键（默认为 `⌥⌘K`），选择凭据并完成认证，确认输入顺序为：用户名 → Return → 500 毫秒 → 密码 → Return。
3. 在普通登录表单的用户名输入框中，使用 `{USERNAME}{TAB}{PASSWORD}{ENTER}`。
4. 在“设置”中点击快捷键按钮并录制另一个“修饰键 + 按键”组合，确认重启后仍然生效且不会触发浏览器操作；同时测试 Safari、Chrome、iTerm2、xterm.js/Guacamole，以及包含特殊字符和 Unicode 的密码，并测试 Escape、重复触发快捷键、目标切换、撤销辅助功能权限、认证失败或取消、Keychain 密码缺失和凭据删除。
5. 确认每次执行前后剪贴板内容都没有变化。

单元测试位于 `Tests/KeyTypeCoreTests`。请使用 Xcode 运行，因为仅使用 Command Line Tools 的 SwiftPM fallback 环境不提供 XCTest。
