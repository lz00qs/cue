import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let minimumContentSize = NSSize(width: 375, height: 600)
  private var localStorageChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.contentMinSize = Self.minimumContentSize
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "top.hylcreative.cue/local_storage",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "WINDOW_CLOSED", message: "Window is closed", details: nil))
        return
      }
      self.handleLocalStorage(call, result: result)
    }
    localStorageChannel = channel

    super.awakeFromNib()

    // Let Flutter paint the full window while keeping the native traffic-light
    // controls. Apply this after nib initialization so AppKit does not restore
    // the standard title-bar presentation over these values.
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.titlebarSeparatorStyle = .none
    self.styleMask.insert(.fullSizeContentView)
  }

  private func handleLocalStorage(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let allowedKeys: Set<String> = [
      "cue_access_token", "cue_refresh_token", "cue_user_email",
      "cue_server_url", "cue_language_code", "cue_theme", "cue_startup_view"
    ]
    guard let arguments = call.arguments as? [String: Any],
          let key = arguments["key"] as? String,
          allowedKeys.contains(key) else {
      result(FlutterError(code: "INVALID_KEY", message: "Invalid local storage key", details: nil))
      return
    }

    do {
      let fileManager = FileManager.default
      let supportDirectory = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      let directory = supportDirectory.appendingPathComponent("Cue", isDirectory: true)
      try fileManager.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
      )
      try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
      let file = directory.appendingPathComponent(key, isDirectory: false)

      switch call.method {
      case "read":
        guard fileManager.fileExists(atPath: file.path) else {
          result(nil)
          return
        }
        let data = try Data(contentsOf: file)
        guard let value = String(data: data, encoding: .utf8) else {
          result(FlutterError(code: "INVALID_DATA", message: "Invalid local storage data", details: nil))
          return
        }
        result(value)
      case "write":
        guard let value = arguments["value"] as? String else {
          result(FlutterError(code: "INVALID_VALUE", message: "Invalid local storage value", details: nil))
          return
        }
        try Data(value.utf8).write(to: file, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        result(nil)
      case "delete":
        if fileManager.fileExists(atPath: file.path) {
          try fileManager.removeItem(at: file)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "LOCAL_STORAGE_ERROR", message: "Cannot access local app data", details: nil))
    }
  }
}
